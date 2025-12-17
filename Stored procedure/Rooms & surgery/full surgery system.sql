CREATE OR ALTER PROCEDURE sp_surgery_reservation_auto
    @p_id INT,               
    @doc_id INT,             
    @surgery_name NVARCHAR(100),
    @surgery_date DATE,        
    @payment_method NVARCHAR(50) = N'Cash',
    @stuff_id_input INT = NULL,  
    @Message NVARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    ----------------------------
    -- Validation
    ----------------------------
    -- Verify If The Doctor Selected Is "Consultant Doctor Or Not"
    IF NOT EXISTS (
        SELECT 1 
        FROM Employee 
        WHERE emp_id = @doc_id
          AND type = 'consultant_doctor'
    )
    BEGIN
        SET @Message = N'? The selected doctor is either not found or not a consultant doctor.';
        RETURN;
    END

    -- Prevent To Add Date In The Past
    IF @surgery_date < CAST(GETDATE() AS DATETime)
    BEGIN
        SET @Message = N'? Cannot schedule surgery in the past.';
        RETURN;
    END

    -- Prevent to add operations in fridays
    IF DATENAME(WEEKDAY, @surgery_date) = 'Friday'
    BEGIN
        SET @Message = N'? Cannot schedule surgery on Friday. Staff is unavailable.';
        RETURN;
    END

    BEGIN TRY
        BEGIN TRAN;

        DECLARE 
            @surgery_id INT,
            @duration_minutes INT,
            @surgery_price DECIMAL(12,2),
            @or_room_id INT = NULL,
            @recovery_room_id INT = NULL,
            @or_room_price DECIMAL(12,2) = 0,
            @recovery_room_price DECIMAL(12,2) = 0,
            @start_time TIME = NULL,
            @end_time TIME = NULL,
            @stuff_id INT = NULL,
            @receptionist_id INT = NULL,
            @reservation_id INT = NULL,
            @invoice_id INT = NULL,
            @paid_total DECIMAL(14,2) = 0,
            @prep_minutes INT = 60,
            @recovery_minutes INT = 60;

        -- A) Validate receptionist availablity
        SELECT TOP 1 @receptionist_id = e.emp_id
        FROM Employee e
        JOIN Emp_shift es ON e.emp_id = es.emp_id
        JOIN Shift_appointment sa ON es.shift_id = sa.shift_id
        WHERE e.type = 'Receptionist'
          AND CAST(GETDATE() AS TIME) BETWEEN sa.start_time AND sa.end_time;

        IF @receptionist_id IS NULL
        BEGIN
            SET @Message = N'? No receptionist available now.';
            ROLLBACK TRAN;
            RETURN;
        END

        -- B) operation duration and price details
        SELECT TOP 1
            @surgery_id = surgery_id,
            @duration_minutes = duration ,
            @surgery_price = price
        FROM Surgery
        WHERE surgery_name = @surgery_name;

        IF @surgery_id IS NULL
        BEGIN
            SET @Message = N'? Surgery not found.';
            ROLLBACK TRAN;
            RETURN;
        END

        -- C)Handling available room to be reserved automatically
        ;WITH RoomLoad AS (
            SELECT 
                r.room_id,
                ISNULL(
                    (
                      SELECT CONVERT(TIME, DATEADD(MINUTE, @prep_minutes, MAX(CONVERT(DATETIME, sr.end_time))))
                      FROM Surgery_reservation sr
                      WHERE sr.surgery_date = @surgery_date
                        AND sr.room_id = r.room_id
                    ),
                    CONVERT(TIME, '07:00')
                ) AS next_available_time
            FROM Room r
            WHERE LOWER(r.room_type) = 'surgery'
        )
        SELECT TOP 1
            @or_room_id = room_id,
            @start_time = next_available_time
        FROM RoomLoad
        ORDER BY next_available_time ASC, room_id;

        IF @or_room_id IS NULL
        BEGIN
            SET @Message = N'? No available operating rooms for the selected date.';
            ROLLBACK TRAN;
            RETURN;
        END

        -- D) Calculate operation terminaation according to normal time in surgery table
        SET @end_time = CONVERT(TIME, DATEADD(MINUTE, @duration_minutes, CONVERT(DATETIME, @start_time)));

        -- E) prevent reserve same doctor or patient at the same time
        IF EXISTS (
            SELECT 1 FROM Surgery_reservation sr
            WHERE sr.surgery_date = @surgery_date
              AND (sr.doctor_id = @doc_id OR sr.p_id = @p_id)
              AND (
                   (@start_time BETWEEN sr.start_time AND sr.end_time)
                OR (@end_time BETWEEN sr.start_time AND sr.end_time)
                OR (sr.start_time BETWEEN @start_time AND @end_time)
              )
        )
        BEGIN
            SET @Message = N'? Patient or doctor already have a surgery at this time.';
            ROLLBACK TRAN;
            RETURN;
        END

        -- F) Stuff is available all week days except fridays
        IF @stuff_id_input IS NOT NULL
            SET @stuff_id = @stuff_id_input;
        ELSE
            SELECT TOP 1 @stuff_id = s.stuff_id
            FROM Stuff_emp s
            WHERE NOT EXISTS (
                SELECT 1 FROM Surgery_reservation sr
                WHERE sr.surgery_date = @surgery_date
                  AND sr.stuff_id = s.stuff_id
                  AND (
                        (@start_time BETWEEN sr.start_time AND sr.end_time)
                        OR (@end_time BETWEEN sr.start_time AND sr.end_time)
                        OR (sr.start_time BETWEEN @start_time AND @end_time)
                      )
            );

        IF @stuff_id IS NULL
        BEGIN
            SET @Message = N'? No available staff for the selected date/time.';
            ROLLBACK TRAN;
            RETURN;
        END

        -- G) Rooms price
        SELECT @or_room_price = ISNULL(price_per_day, 0) FROM Room WHERE room_id = @or_room_id;

        ;WITH RecoveryLoad AS (
            SELECT 
                r.room_id,
                ISNULL(
                  (SELECT COUNT(1) 
                   FROM Room_reservation rr 
                   WHERE rr.checkin <= DATEADD(MINUTE, @recovery_minutes, CAST(@surgery_date AS DATETIME))
                     AND rr.checkout >= CAST(@surgery_date AS DATETIME)
                     AND rr.room_id = r.room_id
                  ), 0) AS reservations_count
            FROM Room r
            WHERE LOWER(r.room_type) = 'recovery'
        )
        SELECT TOP 1 @recovery_room_id = room_id
        FROM RecoveryLoad
        ORDER BY reservations_count ASC, room_id;

        IF @recovery_room_id IS NULL
        BEGIN
            SET @Message = N'? No available recovery rooms for the selected date.';
            ROLLBACK TRAN;
            RETURN;
        END

        SELECT @recovery_room_price = ISNULL(price_per_day, 0) FROM Room WHERE room_id = @recovery_room_id;

        ------------------------------
        -- H) Add new reservation_id
        ------------------------------
        SET @reservation_id = ISNULL((SELECT MAX(reservation_id) FROM Surgery_reservation), 0) + 1;

        -- 1) INSERT Surgery_reservation 
        INSERT INTO Surgery_reservation (
           reservation_id, surgery_date, start_time, end_time, paid_money, 
           p_id, doctor_id, receptionist_id, surgery_id, room_id, stuff_id, status
        )
        VALUES (
            @reservation_id, @surgery_date, @start_time, @end_time, @surgery_price, 
            @p_id, @doc_id, @receptionist_id, @surgery_id, @or_room_id, @stuff_id, 'scheduled'
        );

        -- 2) INSERT room reservation for surgery
        INSERT INTO Room_reservation (paid_money, checkin, checkout, p_id, room_id, emp_id, status)
        VALUES (
            @or_room_price,
            CAST(@surgery_date AS DATETIME),
            DATEADD(MINUTE, @duration_minutes + @prep_minutes, CAST(@surgery_date AS DATETIME)),
            @p_id, @or_room_id, @receptionist_id, 'reserved_for_surgery'
        );

        -- 3) INSERT room reservation for recovery after surgery
        INSERT INTO Room_reservation (paid_money, checkin, checkout, p_id, room_id, emp_id, status)
        VALUES (
            @recovery_room_price,
            DATEADD(MINUTE, @duration_minutes + @prep_minutes, CAST(@surgery_date AS DATETIME)),
            DATEADD(MINUTE, @duration_minutes + @prep_minutes + @recovery_minutes, CAST(@surgery_date AS DATETIME)),
            @p_id, @recovery_room_id, @receptionist_id, 'reserved_for_recovery'
        );

        -- update room status to reserved
        UPDATE Room_Status SET status = 'reserved' WHERE room_id IN (@or_room_id, @recovery_room_id);

        -------------------------------------
        -- I) Add new invoice for all reservations (surgery - surgery_room - recovery_room)
        -------------------------------------
        -- Calculate total price to be added in invoice and invoice_details table
        SET @paid_total = ISNULL(@surgery_price,0) + ISNULL(@or_room_price,0) + ISNULL(@recovery_room_price,0);

        -- Add all details in invoice and invoice_details tables
        SET @invoice_id = ISNULL((SELECT MAX(invoice_id) FROM Invoice), 0) + 1;

        INSERT INTO Invoice (invoice_id, paid_money, date, payment_method, p_id, emp_id)
        VALUES (@invoice_id, @paid_total, GETDATE(), @payment_method, @p_id, @receptionist_id);

        INSERT INTO Invoice_Details (invoice_id, reservation_id, reservation_type, Process_id, unit_price, quantity, total,dept_id)
        VALUES (
            @invoice_id,
            @reservation_id,
            'Surgery',
            @surgery_id,
            @surgery_price,
            1,
            @surgery_price,
			11
        );

        INSERT INTO Invoice_Details (invoice_id, reservation_id, reservation_type, Process_id, unit_price, quantity, total,dept_id)
        VALUES (
            @invoice_id,
            @reservation_id,
            'Operating Room',
            @or_room_id,
            @or_room_price,
            1,
            @or_room_price,
			17
        );

        INSERT INTO Invoice_Details (invoice_id, reservation_id, reservation_type, Process_id, unit_price, quantity, total,dept_id)
        VALUES (
            @invoice_id,
            @reservation_id,
            'Recovery Room',
            @recovery_room_id,
            @recovery_room_price,
            1,
            @recovery_room_price,
			17
        );

        COMMIT TRAN;

        SET @Message = CONCAT(N'? Surgery scheduled: ', CONVERT(VARCHAR(10), @surgery_date, 120),
                              N' from ', CONVERT(VARCHAR(5), @start_time, 108),
                              N' to ', CONVERT(VARCHAR(5), @end_time, 108),
                              N'. OR Room: ', CAST(@or_room_id AS NVARCHAR(10)),
                              N', Recovery Room: ', CAST(@recovery_room_id AS NVARCHAR(10)),
                              N'. Reservation ID: ', CAST(@reservation_id AS NVARCHAR(10)));

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        SET @Message = N'? Error: ' + ERROR_MESSAGE();
    END CATCH
END;
GO
-------------------------------------------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_surgery_reservation_manual
(
    @p_id INT,                    
    @doc_id INT, 
	@stuff_id int,
    @surgery_name NVARCHAR(100),  
    @surgery_date date,
    @start_time TIME,         
    @payment_method NVARCHAR(50) = N'Cash', 
    @Message NVARCHAR(400) OUTPUT
) 
AS
BEGIN
    SET NOCOUNT ON;

    ----------------------------
    -- Validation
    ----------------------------
    -- Verify If The Doctor Selected Is "Consultant Doctor Or Not"
    IF NOT EXISTS (
        SELECT 1 
        FROM Employee 
        WHERE emp_id = @doc_id
          AND type = 'consultant_doctor'
    )
    BEGIN
        SET @Message = N'? The selected doctor is either not found or not a consultant doctor.';
        RETURN;
    END

    -- Prevent To Add Date In The Past
    IF @surgery_date < CAST(GETDATE() AS DATE)
    BEGIN
        SET @Message = N'? Cannot schedule surgery in the past.';
        RETURN;
    END


    BEGIN TRY
        BEGIN TRAN;

        DECLARE 
            @surgery_id INT,
            @duration_minutes INT,
            @surgery_price DECIMAL(12,2),
            @or_room_id INT = NULL,
            @recovery_room_id INT = NULL,
            @or_room_price DECIMAL(12,2) = 0,
            @recovery_room_price DECIMAL(12,2) = 0,
            @end_time TIME = NULL,
            @receptionist_id INT = NULL,
            @reservation_id INT = NULL,
            @invoice_id INT = NULL,
            @paid_total DECIMAL(14,2) = 0,
            @prep_minutes INT = 60,
            @recovery_minutes INT = 60;

        -- A) Validate receptionist availablity
        SELECT TOP 1 @receptionist_id = e.emp_id
        FROM Employee e
        JOIN Emp_shift es ON e.emp_id = es.emp_id
        JOIN Shift_appointment sa ON es.shift_id = sa.shift_id
        WHERE e.type = 'Receptionist'
          AND CAST(GETDATE() AS TIME) BETWEEN sa.start_time AND sa.end_time;

        IF @receptionist_id IS NULL
        BEGIN
            SET @Message = N'? No receptionist available now.';
            ROLLBACK TRAN;
            RETURN;
        END

        -- B) operation duration and price details
        SELECT TOP 1
            @surgery_id = surgery_id,
            @duration_minutes = duration ,
            @surgery_price = price
        FROM Surgery
        WHERE surgery_name = @surgery_name;

        IF @surgery_id IS NULL
        BEGIN
            SET @Message = N'? Surgery not found.';
            ROLLBACK TRAN;
            RETURN;
        END
		IF @start_time IS NOT NULL
BEGIN
    -- choose first available room
    SELECT TOP 1 @or_room_id = room_id
    FROM Room r
    WHERE LOWER(r.room_type) = 'surgery'
      AND NOT EXISTS (
          SELECT 1 
          FROM Surgery_reservation sr
          WHERE sr.surgery_date = @surgery_date
            AND sr.room_id = r.room_id
            AND (
                 (@start_time BETWEEN sr.start_time AND sr.end_time)
              OR (@end_time BETWEEN sr.start_time AND sr.end_time)
              OR (sr.start_time BETWEEN @start_time AND @end_time)
            )
      )
    ORDER BY room_id;
END
ELSE
begin
        -- C)Handling available room to be reserved automatically
        ;WITH RoomLoad AS (
            SELECT 
                r.room_id,
                ISNULL(
                    (
                      SELECT CONVERT(TIME, DATEADD(MINUTE, @prep_minutes, MAX(CONVERT(DATETIME, sr.end_time))))
                      FROM Surgery_reservation sr
                      WHERE sr.surgery_date = @surgery_date
                        AND sr.room_id = r.room_id
                    ),

                    CONVERT(TIME, '07:00')
                ) AS next_available_time
            FROM Room r
            WHERE LOWER(r.room_type) = 'surgery'
        )
        SELECT TOP 1
            @or_room_id = room_id,
            @start_time = next_available_time
        FROM RoomLoad
        ORDER BY next_available_time ASC, room_id;
	end

        IF @or_room_id IS NULL
        BEGIN
            SET @Message = N'? No available operating rooms for the selected date.';
            ROLLBACK TRAN;
            RETURN;
        END
        -- D) Calculate operation termination according to normal time in surgery table
        SET @end_time = CONVERT(TIME, DATEADD(MINUTE, @duration_minutes, CONVERT(DATETIME, @start_time)));

        -- E) prevent same doctor or patient reserve same operation at same time
        IF EXISTS (
    SELECT 1 
    FROM Surgery_reservation sr
    WHERE sr.surgery_date = @surgery_date
      AND (@doc_id = sr.doctor_id OR @p_id = sr.p_id)
      AND (
           (@start_time BETWEEN sr.start_time AND sr.end_time)
        OR (@end_time BETWEEN sr.start_time AND sr.end_time)
        OR (sr.start_time BETWEEN @start_time AND @end_time)
      )
	)
	BEGIN
		SET @Message = N'❌ Doctor or Patient already has a surgery at this time.';
		ROLLBACK TRAN; RETURN;
	END

	-- prevent same stuff reserve more than one operation at the same time
	IF EXISTS (
		SELECT 1 
		FROM Surgery_reservation sr
		WHERE sr.surgery_date = @surgery_date
		  AND sr.stuff_id = @stuff_id
		  AND (
			   (@start_time BETWEEN sr.start_time AND sr.end_time)
			OR (@end_time BETWEEN sr.start_time AND sr.end_time)
			OR (sr.start_time BETWEEN @start_time AND @end_time)
		  )
	)
	BEGIN
		SET @Message = N'❌ Staff already assigned to another surgery at this time.';
		ROLLBACK TRAN; RETURN;
	END


        -- G) Rooms price
        SELECT @or_room_price = ISNULL(price_per_day, 0) FROM Room WHERE room_id = @or_room_id;

        ;WITH RecoveryLoad AS (
            SELECT 
                r.room_id,
                ISNULL(
                  (SELECT COUNT(1) 
                   FROM Room_reservation rr 
                   WHERE rr.checkin <= DATEADD(MINUTE, @recovery_minutes, CAST(@surgery_date AS DATETIME))
                     AND rr.checkout >= CAST(@surgery_date AS DATETIME)
                     AND rr.room_id = r.room_id
                  ), 0) AS reservations_count
            FROM Room r
            WHERE LOWER(r.room_type) = 'recovery'
        )
        SELECT TOP 1 @recovery_room_id = room_id
        FROM RecoveryLoad
        ORDER BY reservations_count ASC, room_id;

        IF @recovery_room_id IS NULL
        BEGIN
            SET @Message = N'? No available recovery rooms for the selected date.';
            ROLLBACK TRAN;
            RETURN;
        END

        SELECT @recovery_room_price = ISNULL(price_per_day, 0) FROM Room WHERE room_id = @recovery_room_id;

        ------------------------------
        -- H) Add new reservation_id
        ------------------------------
        SET @reservation_id = ISNULL((SELECT MAX(reservation_id) FROM Surgery_reservation), 0) + 1;

        -- 1) INSERT Surgery_reservation 
        INSERT INTO Surgery_reservation (
           reservation_id, surgery_date, start_time, end_time, paid_money, 
           p_id, doctor_id, receptionist_id, surgery_id, room_id, stuff_id, status
        )
        VALUES (
            @reservation_id, @surgery_date, @start_time, @end_time, @surgery_price, 
            @p_id, @doc_id, @receptionist_id, @surgery_id, @or_room_id, @stuff_id, 'scheduled'
        );

        -- 2) INSERT room reservation for surgery
        INSERT INTO Room_reservation (paid_money, checkin, checkout, p_id, room_id, emp_id, status)
        VALUES (
            @or_room_price,
            CAST(@surgery_date AS DATETIME),
            DATEADD(MINUTE, @duration_minutes + @prep_minutes, CAST(@surgery_date AS DATETIME)),
            @p_id, @or_room_id, @receptionist_id, 'reserved_for_surgery'
        );

        -- 3) INSERT room reservation for recovery after surgery
        INSERT INTO Room_reservation (paid_money, checkin, checkout, p_id, room_id, emp_id, status)
        VALUES (
            @recovery_room_price,
            DATEADD(MINUTE, @duration_minutes + @prep_minutes, CAST(@surgery_date AS DATETIME)),
            DATEADD(MINUTE, @duration_minutes + @prep_minutes + @recovery_minutes, CAST(@surgery_date AS DATETIME)),
            @p_id, @recovery_room_id, @receptionist_id, 'reserved_for_recovery'
        );

        -- update room status to reserved
        UPDATE Room_Status SET status = 'reserved' WHERE room_id IN (@or_room_id, @recovery_room_id);

        -------------------------------------
        -- I) Add new invoice for all reservations (surgery - surgery_room - recovery_room)
        -------------------------------------
        -- Calculate total price to be added in invoice and invoice_details table
        SET @paid_total = ISNULL(@surgery_price,0) + ISNULL(@or_room_price,0) + ISNULL(@recovery_room_price,0);

        -- Add all details in invoice and invoice_details tables
        SET @invoice_id = ISNULL((SELECT MAX(invoice_id) FROM Invoice), 0) + 1;

        INSERT INTO Invoice (invoice_id, paid_money, date, payment_method, p_id, emp_id)
        VALUES (@invoice_id, @paid_total, GETDATE(), @payment_method, @p_id, @receptionist_id);

        INSERT INTO Invoice_Details (invoice_id, reservation_id, reservation_type, Process_id, unit_price, quantity, total,dept_id)
        VALUES (
            @invoice_id,
            @reservation_id,
            'Surgery',
            @surgery_id,
            @surgery_price,
            1,
            @surgery_price,
			11
        );

        INSERT INTO Invoice_Details (invoice_id, reservation_id, reservation_type, Process_id, unit_price, quantity, total,dept_id)
        VALUES (
            @invoice_id,
            @reservation_id,
            'Operating Room',
            @or_room_id,
            @or_room_price,
            1,
            @or_room_price,
			17
        );

        INSERT INTO Invoice_Details (invoice_id, reservation_id, reservation_type, Process_id, unit_price, quantity, total,dept_id)
        VALUES (
            @invoice_id,
            @reservation_id,
            'Recovery Room',
            @recovery_room_id,
            @recovery_room_price,
            1,
            @recovery_room_price,
			17
        );

        COMMIT TRAN;

        SET @Message = CONCAT(N'? Surgery scheduled: ', CONVERT(VARCHAR(10), @surgery_date, 120),
                              N' from ', CONVERT(VARCHAR(5), @start_time, 108),
                              N' to ', CONVERT(VARCHAR(5), @end_time, 108),
                              N'. OR Room: ', CAST(@or_room_id AS NVARCHAR(10)),
                              N', Recovery Room: ', CAST(@recovery_room_id AS NVARCHAR(10)),
                              N'. Reservation ID: ', CAST(@reservation_id AS NVARCHAR(10)));

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        SET @Message = N'? Error: ' + ERROR_MESSAGE();
    END CATCH
END;
go
--------------------------------------------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_cancel_surgery
    @reservation_id INT,
    @Message NVARCHAR(400) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @surgery_date DATE, 
                @start_time TIME, 
                @p_id INT,
                @invoice_id INT;

        -- 🔹 Operation details
        SELECT 
            @surgery_date = surgery_date,
            @start_time = start_time,
            @p_id = p_id
        FROM Surgery_reservation
        WHERE reservation_id = @reservation_id;

        IF @surgery_date IS NULL
        BEGIN
            SET @Message = N'❌ Reservation not found.';
            ROLLBACK TRAN;
            RETURN;
        END;

        -- 1️⃣ update operation status to be canceled and traverse money
        UPDATE Surgery_reservation
        SET status = 'canceled',
            paid_money = 0
        WHERE reservation_id = @reservation_id;

        -- 2️⃣ update room status to be canceled and traverse money
        UPDATE rr
        SET rr.status = 'canceled',
            rr.paid_money = 0
        FROM Room_reservation rr
        WHERE rr.p_id = @p_id
          AND rr.checkin >= @surgery_date
          AND rr.status IN ('reserved_for_surgery','reserved_for_recovery');

        -- 3️⃣ make room status available
        IF (@surgery_date > CAST(GETDATE() AS DATE)
           OR (@surgery_date = CAST(GETDATE() AS DATE) AND @start_time > CAST(GETDATE() AS TIME)))
        BEGIN
            UPDATE Room_Status
            SET status = 'available'
            WHERE room_id IN (
                SELECT room_id
                FROM Room_reservation
                WHERE p_id = @p_id
                  AND checkin >= @surgery_date
                  AND status = 'canceled'
            );
        END;

        -- 4️⃣ remove the datails of the invoice from invoice_details table
        DELETE FROM Invoice_Details
        WHERE reservation_id = @reservation_id;

        -- 5️⃣ remove the datails of the invoice from invoice table
        DELETE FROM Invoice
        WHERE invoice_id NOT IN (SELECT DISTINCT invoice_id FROM Invoice_Details);

        COMMIT TRAN;

        SET @Message = N'✅ Surgery reservation canceled successfully. Related rooms freed, invoice details deleted, and paid money set to 0.';
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        SET @Message = N'❌ Error: ' + ERROR_MESSAGE();
    END CATCH;
END;
GO


