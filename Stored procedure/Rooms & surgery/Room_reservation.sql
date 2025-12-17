-------------------------------------------
-- ✅ Room Status Table
-------------------------------------------
CREATE TABLE Room_Status (
    room_id INT PRIMARY KEY,
    status NVARCHAR(20) CHECK (status IN ('Available', 'Reserved', 'Maintenance')) DEFAULT 'Available',
    FOREIGN KEY (room_id) REFERENCES Room(room_id)
);

INSERT INTO Room_Status (room_id, status)
SELECT room_id, 'Available'
FROM Room;

-------------------------------------------
-- ✅ Set Default Prices Based on Room Type
-------------------------------------------
UPDATE Room
SET price_per_day =
    CASE 
        WHEN LOWER(room_type) = 'normal' THEN 1500
        WHEN LOWER(room_type) = 'vip' THEN 3000
        WHEN LOWER(room_type) = 'emergency' THEN 1500
        WHEN LOWER(room_type) = 'icu' THEN 5000
        WHEN LOWER(room_type) = 'surgery' THEN 10000
        ELSE NULL
    END;

-------------------------------------------
-- ✅ Room Reservation Table
-------------------------------------------
CREATE TABLE Room_reservation (
    reservation_id INT IDENTITY(1,1) PRIMARY KEY,
    paid_money DECIMAL(10,2) DEFAULT 0 CHECK (paid_money >= 0),
    checkin DATE NOT NULL,
    checkout DATE,
    p_id INT NOT NULL,
    room_id INT NOT NULL,
    emp_id INT NOT NULL,
    FOREIGN KEY (p_id) REFERENCES Patient(p_id),
    FOREIGN KEY (room_id) REFERENCES Room(room_id),
    FOREIGN KEY (emp_id) REFERENCES Employee(emp_id),
    CONSTRAINT chk_room_dates CHECK (checkout > checkin)
);

-------------------------------------------
-- ✅ Procedure: Insert Room
-------------------------------------------
CREATE OR ALTER PROCEDURE sp_insert_room
    @room_type NVARCHAR(50),
    @price_per_day DECIMAL(10,2) = NULL,
    @Message NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @existing_price DECIMAL(10,2);
        DECLARE @room_id INT;

        -- Try to fetch existing price if room type already exists
        SELECT TOP 1 @existing_price = price_per_day
        FROM Room
        WHERE LOWER(room_type) = LOWER(@room_type);

        -- If the type already exists, use its existing price
        IF @existing_price IS NOT NULL
            SET @price_per_day = @existing_price;
        ELSE
        BEGIN
            -- New room type must include a price
            IF @price_per_day IS NULL OR @price_per_day <= 0
            BEGIN
                SET @Message = N'❌ Error: New room type detected. Please provide a valid price_per_day value.';
                RETURN;
            END;
        END;

        -- Generate a new room ID
        SELECT @room_id = ISNULL(MAX(room_id), 0) + 1 FROM Room;

        -- Insert new room
        INSERT INTO Room (room_id, room_type, price_per_day)
        VALUES (@room_id, @room_type, @price_per_day);

        -- Insert default status
        INSERT INTO Room_Status (room_id, status)
        VALUES (@room_id, 'Available');

        SET @Message = CONCAT(N'✅ Room "', @room_type, N'" inserted successfully with price ', @price_per_day, N'.');
    END TRY
    BEGIN CATCH
        SET @Message = CONCAT(N'⚠ Error: ', ERROR_MESSAGE());
    END CATCH
END;
GO

-------------------------------------------
-- ✅ Procedure: Update Room
-------------------------------------------
CREATE OR ALTER PROCEDURE sp_update_room
    @room_id INT,
    @new_type NVARCHAR(50),
    @Message NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM Room WHERE room_id = @room_id)
        BEGIN
            SET @Message = N'❌ Room not found.';
            RETURN;
        END;

        DECLARE @new_price DECIMAL(10,2);

        SELECT TOP 1 @new_price = price_per_day
        FROM Room
        WHERE LOWER(room_type) = LOWER(@new_type);

        IF @new_price IS NULL
        BEGIN
            SET @Message = N'⚠ Room type not found. Please insert a room with this type first.';
            RETURN;
        END;

        UPDATE Room
        SET room_type = @new_type,
            price_per_day = @new_price
        WHERE room_id = @room_id;

        SET @Message = N'✅ Room type and price updated successfully.';
    END TRY
    BEGIN CATCH
        SET @Message = CONCAT(N'⚠ Error: ', ERROR_MESSAGE());
    END CATCH
END;
GO

-------------------------------------------
-- ✅ Procedure: Reserve Room
-------------------------------------------
CREATE OR ALTER PROCEDURE sp_room_reservation
    @p_id INT,
    @room_type NVARCHAR(50),
    @Message NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @receptionist_id INT;
    DECLARE @room_id INT;
    DECLARE @checkin_date DATE = GETDATE();

    BEGIN TRY
        -- Validate Patient
    -- Validate Patient
	IF NOT EXISTS (SELECT 1 FROM Patient WHERE p_id = @p_id)
	BEGIN
		SET @Message = N'❌ Invalid patient ID.';
		RETURN;
	END;

	-- ❗ Prevent patient from reserving another room without checkout
	IF EXISTS (
		SELECT 1
		FROM Room_reservation
		WHERE p_id = @p_id
		  AND checkout IS NULL
	)
	BEGIN
		SET @Message = N'This Patient Is Reserved In Another Room Cant Reserve new Room';
		RETURN;
	END;


        -- Find available receptionist on duty
        SELECT TOP 1 @receptionist_id = e.emp_id
        FROM Employee e
        JOIN Emp_shift es ON e.emp_id = es.emp_id
        JOIN Shift_appointment sa ON es.shift_id = sa.shift_id
        WHERE e.type = 'Receptionist'
          AND CAST(GETDATE() AS TIME) BETWEEN sa.start_time AND sa.end_time;

        IF @receptionist_id IS NULL
        BEGIN
            SET @Message = N'❌ No receptionist available now.';
            RETURN;
        END;

        -- Find the first available room of the requested type
        SELECT TOP 1 @room_id = r.room_id 
        FROM Room r
        INNER JOIN Room_Status s ON r.room_id = s.room_id
        WHERE LOWER(r.room_type) = LOWER(@room_type) AND LOWER(s.status) = 'available'
        ORDER BY r.room_id;

        IF @room_id IS NULL
        BEGIN
            SET @Message = N'⚠ No available rooms of the selected type , All Reserved.';
            RETURN;
        END;

        -- Insert reservation
        INSERT INTO Room_reservation (p_id, room_id, emp_id, checkin)
        VALUES (@p_id, @room_id, @receptionist_id, @checkin_date);

        DECLARE @reservation_id INT;
        SELECT TOP 1 @reservation_id = reservation_id
        FROM Room_reservation
        WHERE room_id = @room_id
        ORDER BY reservation_id DESC;

        -- Update room status
        UPDATE Room_Status
        SET status = 'Reserved'
        WHERE room_id = @room_id;

        SET @Message = N'✅ Reservation added successfully. Room ID: ' 
            + CAST(@room_id AS NVARCHAR(10)) 
            + N', Reservation ID: ' + CAST(@reservation_id AS NVARCHAR(10));
    END TRY
    BEGIN CATCH
        SET @Message = N'⚠ Error: ' + ERROR_MESSAGE();
    END CATCH
END;
GO


-------------------------------------------
-- ✅ Function: Calculate Room Payment
-------------------------------------------
CREATE OR ALTER FUNCTION fn_calculate_room_payment
(
    @checkin DATETIME,
    @checkout DATETIME,
    @price_per_day DECIMAL(10,2)
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @num_days INT;

    SET @num_days = DATEDIFF(DAY, @checkin, @checkout);
    IF @num_days < 1 SET @num_days = 1;

    RETURN @num_days * @price_per_day;
END;
GO

-------------------------------------------
-- ✅ Procedure: Checkout
-------------------------------------------
CREATE OR ALTER PROCEDURE sp_room_checkout
    @reservation_id INT,
    @checkout DATE,
    @payment_method NVARCHAR(50),
    @Message NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @room_id INT,
            @checkin DATE,
            @price_per_day DECIMAL(10,2),
            @paid_money DECIMAL(10,2),
            @p_id INT,
            @room_type NVARCHAR(50),
            @receptionist_id INT,
			@num_days int,
		    @new_invoice_id INT;


    BEGIN TRY
        -- Receptionist validation
        SELECT TOP 1 @receptionist_id = e.emp_id
        FROM Employee e
        JOIN Emp_shift es ON e.emp_id = es.emp_id
        JOIN Shift_appointment sa ON es.shift_id = sa.shift_id
        WHERE e.type = 'Receptionist'
          AND CAST(GETDATE() AS TIME) BETWEEN sa.start_time AND sa.end_time;

        IF @receptionist_id IS NULL
        BEGIN
            SET @Message = N'❌ No receptionist available now.';
            RETURN;
        END;

        -- Fetch reservation details
        SELECT 
            @room_id = rr.room_id,
            @checkin = rr.checkin,
            @price_per_day = r.price_per_day,
            @p_id = rr.p_id,
            @room_type = r.room_type
        FROM Room_reservation rr
        INNER JOIN Room r ON rr.room_id = r.room_id
        WHERE rr.reservation_id = @reservation_id;

        IF @room_id IS NULL
        BEGIN
            SET @Message = N'⚠ Reservation not found.';
            RETURN;
        END;

        IF @checkout < @checkin
        BEGIN
            SET @Message = N'⚠ Checkout date cannot be earlier than checkin date.';
            RETURN;
        END;
		SET @num_days = DATEDIFF(DAY, @checkin, @checkout);
        IF @num_days < 1 SET @num_days = 1;

        SET @paid_money = dbo.fn_calculate_room_payment(@checkin, @checkout, @price_per_day);

        UPDATE Room_reservation
        SET checkout = @checkout,
            paid_money = @paid_money
        WHERE reservation_id = @reservation_id;

        UPDATE Room_Status
        SET status = 'Available'
        WHERE room_id = @room_id;

		SELECT @new_invoice_id = ISNULL(MAX(invoice_id), 0) + 1
        FROM Invoice;

        INSERT INTO Invoice (invoice_id, date, payment_method, paid_money, p_id, emp_id)
        VALUES (
		    @new_invoice_id,
            GETDATE(),
            @payment_method,
            @paid_money,
            @p_id,
            @receptionist_id
        );

	    INSERT INTO Invoice_Details ( invoice_id,reservation_id, reservation_type, Process_id, unit_price, quantity, total,dept_id)
        VALUES (
		    @new_invoice_id,
            @reservation_id,
            'Room',
            @room_id,
            @price_per_day,
            @num_days,
            @paid_money,
			17
        );

        SET @Message = N'✅ Checkout completed successfully. Total Paid = ' + CAST(@paid_money AS NVARCHAR(20));
    END TRY
    BEGIN CATCH
        SET @Message = N'⚠ Error: ' + ERROR_MESSAGE();
    END CATCH
END;
GO

