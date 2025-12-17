                       ---------------------------------------------------
                               -- SP to insert, update a test in lab_tests
                           ---------------------------------------------------

CREATE OR ALTER PROCEDURE sp_manage_lab_tests
    @Action NVARCHAR(10),               -- 'INSERT', 'UPDATE'
    @test_id INT = null,
    @test_name NVARCHAR(100),
    @delivery_duration NVARCHAR(50),
    @price DECIMAL(10,2),
    @msg NVARCHAR(200) OUTPUT     

AS
BEGIN
 set nocount on;

    -- INSERT
    IF @Action = 'INSERT'
    BEGIN
        IF EXISTS (SELECT 1 FROM Lab_Tests WHERE test_name = @test_name)
        BEGIN
            SET @msg = 'Test name already exists.';
            RETURN;
        END

        IF @price < 0
        BEGIN
            SET @msg = 'Price cannot be negative.';
            RETURN;
        END

		    SELECT @test_id = ISNULL(MAX(test_id), 0) + 1
            FROM Lab_tests;

        INSERT INTO Lab_Tests (test_id,test_name, delivery_duration, price)
        VALUES (@test_id, @test_name, @delivery_duration, @price);

        SET @msg = 'New lab test added successfully.';
    END

    -- UPDATE
    ELSE IF @Action = 'UPDATE'
    BEGIN
        IF @test_id IS NULL
        BEGIN
            SET @msg = 'test_id is required for update.';
            RETURN;
        END

        IF @test_name IS NOT NULL AND EXISTS (
            SELECT 1 FROM Lab_Tests WHERE test_name = @test_name AND test_id <> @test_id
        )
        BEGIN
            SET @msg = 'Another test with this name already exists.';
            RETURN;
        END

        UPDATE Lab_Tests
        SET
            test_name = ISNULL(@test_name, test_name),
            delivery_duration = ISNULL(@delivery_duration, delivery_duration),
            price = ISNULL(@price, price)
        WHERE test_id = @test_id;

        IF @@ROWCOUNT = 0
            SET @msg = 'No test found with the given ID.';
        ELSE
            SET @msg = 'Test updated successfully.';
    END

 

    -- Invalid
    ELSE
    BEGIN
        SET @msg = 'Invalid action. Use INSERT, UPDATE, or DELETE.';
    END
END;
GO
					   

					   -------------------------------------------
                                -- SP to DELETE test from Lab_tests
                            -------------------------------------------
GO
CREATE OR ALTER PROCEDURE sp_delete_lab_tests
    @Action NVARCHAR(10),               
    @test_id INT,
    @msg NVARCHAR(200) OUTPUT     

AS
BEGIN
 -- DELETE
    IF @Action = 'DELETE'
    BEGIN
        DELETE FROM Lab_Tests WHERE test_id = @test_id;

        IF @@ROWCOUNT = 0
            SET @msg = 'No test found with the given ID.';
        ELSE
            SET @msg = 'Test deleted successfully.';
        END
   ELSE
    BEGIN
        SET @msg = 'Invalid action. Use DELETE only.';
    END
END;
GO


                        ------------------------------------------------------
                            -- SP to insert, update a record in Radiology
                        ------------------------------------------------------
GO
CREATE OR ALTER PROCEDURE sp_manage_radiology
    @Action NVARCHAR(10),               -- 'INSERT', 'UPDATE'
    @rad_id INT=null,
    @rad_name NVARCHAR(100),
    @delivery_duration NVARCHAR(50),
    @price DECIMAL(10,2),
    @msg NVARCHAR(200) OUTPUT     

AS
BEGIN

    -- INSERT
    IF @Action = 'INSERT'
    BEGIN
        IF EXISTS (SELECT 1 FROM Radiology WHERE rad_name = @rad_name)
        BEGIN
            SET @msg = 'Radiology name already exists.';
            RETURN;
        END

        IF @price < 0
        BEGIN
            SET @msg = 'Price cannot be negative.';
            RETURN;
        END

		SELECT @rad_id = ISNULL(MAX(rad_id), 0) + 1
        FROM Radiology;

        INSERT INTO Radiology (rad_id, rad_name, delivery_duration, price)
        VALUES (@rad_id, @rad_name, @delivery_duration, @price);

        SET @msg = 'New radiology record added successfully.';
    END

    -- UPDATE
    ELSE IF @Action = 'UPDATE'
    BEGIN
        IF @rad_id IS NULL
        BEGIN
            SET @msg = 'rad_id is required for update.';
            RETURN;
        END

        IF @rad_name IS NOT NULL AND EXISTS (
            SELECT 1 FROM Radiology WHERE rad_name = @rad_name AND rad_id <> @rad_id
        )
        BEGIN
            SET @msg = 'Another radiology record with this name already exists.';
            RETURN;
        END

        UPDATE Radiology
        SET
            rad_name = ISNULL(@rad_name, rad_name),
            delivery_duration = ISNULL(@delivery_duration, delivery_duration),
            price = ISNULL(@price, price)
        WHERE rad_id = @rad_id;

        IF @@ROWCOUNT = 0
            SET @msg = 'No radiology record found with the given ID.';
        ELSE
            SET @msg = 'Radiology record updated successfully.';
    END

    -- Invalid
    ELSE
    BEGIN
        SET @msg = 'Invalid action. Use INSERT or UPDATE only.';
    END
END;
GO


                            -------------------------------------------
                                -- SP to DELETE record from Radiology
                            -------------------------------------------
GO
CREATE OR ALTER PROCEDURE sp_delete_radiology
    @Action NVARCHAR(10),               
    @rad_id INT,
    @msg NVARCHAR(200) OUTPUT     
AS
BEGIN
    -- DELETE
    IF @Action = 'DELETE'
    BEGIN
        DELETE FROM Radiology WHERE rad_id = @rad_id;

        IF @@ROWCOUNT = 0
            SET @msg = 'No radiology record found with the given ID.';
        ELSE
            SET @msg = 'Radiology record deleted successfully.';
    END
    ELSE
    BEGIN
        SET @msg = 'Invalid action. Use DELETE only.';
    END
END;
GO



					   ----------------------------------------
                           --SP to add new reservation in lab
                        ----------------------------------------
GO
CREATE OR ALTER PROCEDURE sp_AddLabReservation
    @p_id INT,
    @Tests TestListType READONLY,   
    @paid_money DECIMAL(10,2) = NULL,   
    @payment_method NVARCHAR(50) = null,
    @msg NVARCHAR(200) OUTPUT     
AS
BEGIN
SET NOCOUNT ON;
    DECLARE @reservation_id INT;
    DECLARE @invoice_id INT;
    DECLARE @Today NVARCHAR(20) = DATENAME(WEEKDAY, GETDATE());
    DECLARE @Receptionist_ID NVARCHAR(25);
    DECLARE @lab_doctorID INT;
    DECLARE @total_price DECIMAL(10,2) = 0;
    DECLARE @AllTests NVARCHAR(MAX);   -- ****** NEW ******


    ------------------------------------------------------
    -- 1) Validate all tests exist
    ------------------------------------------------------
    IF EXISTS (
        SELECT t.test_name
        FROM @Tests t
        LEFT JOIN Lab_tests lt ON lt.test_name = t.test_name
        WHERE lt.test_name IS NULL
    )
    BEGIN
        SET @msg = N'One or more tests do not exist.';
        RETURN;
    END;


    ------------------------------------------------------
    -- 2) Calculate total price automatically
    ------------------------------------------------------
    SELECT @total_price = SUM(lt.price)
    FROM @Tests t
    JOIN Lab_tests lt ON t.test_name = lt.test_name;


    ------------------------------------------------------
    -- 3) Auto-calc money if NULL
    ------------------------------------------------------
    IF @paid_money IS NULL
        SET @paid_money = @total_price;


    ------------------------------------------------------
    -- 4) Validate provided paid money
    ------------------------------------------------------
    IF @paid_money <> @total_price
    BEGIN
        SET @msg = N'Incorrect paid amount. Total required = ' + CAST(@total_price AS NVARCHAR(20));
        RETURN;
    END;


    ------------------------------------------------------
    -- 5) Choose available Lab Doctor
    ------------------------------------------------------
    SELECT TOP 1 @lab_doctorID = E.emp_id
    FROM Employee E
    JOIN Doctor_appointments DA ON E.dept_id = 13 AND DA.[day] = @Today;


    ------------------------------------------------------
    -- 6) Choose receptionist in shift
    ------------------------------------------------------
    SELECT TOP 1 @Receptionist_ID = e.emp_id
    FROM Employee e
    JOIN Emp_shift es ON e.emp_id = es.emp_id
    JOIN Shift_appointment sa ON es.shift_id = sa.shift_id
    WHERE e.type = 'Receptionist'
      AND CAST(GETDATE() AS TIME) BETWEEN sa.start_time AND sa.end_time;


    ------------------------------------------------------
    -- 7) Create reservation_id
    ------------------------------------------------------
    SELECT @reservation_id = ISNULL(MAX(reservation_id), 0) + 1
    FROM Lab_reservation;


    ------------------------------------------------------
    -- 8) Build combined test names (NEW)
    ------------------------------------------------------
    SELECT @AllTests = STRING_AGG(t.test_name, ' , ')
    FROM @Tests t;


    ------------------------------------------------------
    -- 9) Insert main reservation
    ------------------------------------------------------
    INSERT INTO Lab_reservation (reservation_id, date, paid_money, p_id, Doctor_ID, test_name, Receptionist_ID)
    VALUES (@reservation_id, GETDATE(), @paid_money, @p_id, @lab_doctorID, @AllTests, @Receptionist_ID);


    ------------------------------------------------------
    -- 10) Generate invoice_id
    ------------------------------------------------------
    SELECT @invoice_id = ISNULL(MAX(invoice_id), 0) + 1
    FROM Invoice;


    ------------------------------------------------------
    -- 11) Insert invoice
    ------------------------------------------------------
    INSERT INTO Invoice (invoice_id, date, payment_method, paid_money, p_id, emp_id)
    VALUES (@invoice_id, GETDATE(), @payment_method, @total_price, @p_id, @lab_doctorID);


    ------------------------------------------------------
    -- 12) Insert each test into Test_reserve & Invoice_Details
    ------------------------------------------------------
    DECLARE 
        @test_name NVARCHAR(100),
        @price DECIMAL(10,2),
        @test_id INT;

    DECLARE cur CURSOR FOR
        SELECT t.test_name, lt.price, lt.test_id
        FROM @Tests t
        JOIN Lab_tests lt ON lt.test_name = t.test_name;

    OPEN cur;
    FETCH NEXT FROM cur INTO @test_name, @price, @test_id;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        INSERT INTO Test_reserve (test_id, reservation_id, test_result)
        VALUES (@test_id, @reservation_id, NULL);

        INSERT INTO Invoice_Details (invoice_id, reservation_id, reservation_type, Process_id, unit_price, quantity, total, dept_id)
        VALUES (@invoice_id, @reservation_id, 'lab', @test_id, @price, 1, @price, 13);

        FETCH NEXT FROM cur INTO @test_name, @price, @test_id;
    END;

    CLOSE cur;
    DEALLOCATE cur;
    ------------------------------------------------------
    -- 13) Success message
    ------------------------------------------------------
    SET @msg = N'Lab reservation added successfully. Reservation ID = ' + CAST(@reservation_id AS NVARCHAR(10));

END;
GO

                      -----------------------------------------------------------
                        --SP to update test_result column in Test_reserve Table
                      -----------------------------------------------------------
GO
CREATE TYPE LabResultUpdateType AS TABLE
(
    test_name NVARCHAR(100),
    test_result NVARCHAR(255)
);
go
CREATE OR ALTER PROCEDURE sp_UpdateLabResult
    @reservation_id INT,
    @Results LabResultUpdateType READONLY
AS
BEGIN
    SET NOCOUNT ON;

    -- update all test results automatically by matching test_name
    UPDATE tr
    SET tr.test_result = r.test_result
    FROM Test_reserve tr
    JOIN Lab_tests lt ON tr.test_id = lt.test_id
    JOIN @Results r   ON lt.test_name = r.test_name
    WHERE tr.reservation_id = @reservation_id;
END;
GO


                        --------------------------------------------  
                         --SP to add new reservation in Radiology
                        --------------------------------------------

---------------------------------------------------------
-- TYPE
---------------------------------------------------------
CREATE TYPE RadioListType AS TABLE
(
    rad_name NVARCHAR(100)
);
GO

---------------------------------------------------------
-- PROCEDURE
---------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_AddRadioReservation
    @p_id INT,
    @payment_method NVARCHAR(50) = 'Cash',
    @Rads RadioListType READONLY,
    @msg NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE 
        @Today NVARCHAR(20) = DATENAME(WEEKDAY, GETDATE()),
        @Receptionist_ID INT,
        @radio_doctorID INT,
        @invoice_id INT,
        @reservation_id INT,
        @TotalPrice DECIMAL(10,2),
        @AllTests NVARCHAR(MAX);

    ---------------------------------------------------
    -- Validate Patient
    ---------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Patient WHERE p_id = @p_id)
    BEGIN
        SET @msg = N'Invalid patient ID.';
        RETURN;
    END;

    ---------------------------------------------------
    -- Select Radiology Doctor on Duty
    ---------------------------------------------------
    SELECT TOP 1 @radio_doctorID = E.emp_id
    FROM Employee E
    JOIN Doctor_appointments DA ON E.dept_id = 14 AND DA.[day] = @Today;


    IF @radio_doctorID IS NULL
    BEGIN
        SET @msg = N'No radiology doctor available today.';
        RETURN;
    END;

    ---------------------------------------------------
    -- Select Receptionist in current shift
    ---------------------------------------------------
    SELECT TOP 1 @Receptionist_ID = e.emp_id
    FROM Employee e
    JOIN Emp_shift es ON e.emp_id = es.emp_id
    JOIN Shift_appointment sa ON es.shift_id = sa.shift_id
    WHERE e.type = 'Receptionist'
      AND (
            (sa.start_time < sa.end_time AND CAST(GETDATE() AS TIME) BETWEEN sa.start_time AND sa.end_time)
            OR
            (sa.start_time > sa.end_time AND (CAST(GETDATE() AS TIME) >= sa.start_time OR CAST(GETDATE() AS TIME) <= sa.end_time))
          );

    IF @Receptionist_ID IS NULL
    BEGIN
        SET @msg = N'No receptionist available in the current shift.';
        RETURN;
    END;

    ---------------------------------------------------
    -- Validate radiology names exist
    ---------------------------------------------------
    IF EXISTS (
        SELECT r.rad_name
        FROM @Rads r
        LEFT JOIN Radiology ra ON ra.rad_name = r.rad_name
        WHERE ra.rad_name IS NULL
    )
    BEGIN
        SET @msg = N'One or more radiology names are invalid.';
        RETURN;
    END;

    ---------------------------------------------------
    -- Check Duplicate Tests Today
    ---------------------------------------------------
    IF EXISTS (
        SELECT 1
        FROM @Rads r
        JOIN Radio_reservation rr 
            ON rr.p_id = @p_id AND rr.rad_name = r.rad_name
        WHERE CAST(rr.date AS DATE) = CAST(GETDATE() AS DATE)
    )
    BEGIN
        SET @msg = N'Patient already booked one or more of these tests today.';
        RETURN;
    END;

    ---------------------------------------------------
    -- Calculate Total Price
    ---------------------------------------------------
    SELECT @TotalPrice = SUM(ra.price)
    FROM @Rads r
    JOIN Radiology ra ON ra.rad_name = r.rad_name;

    ---------------------------------------------------
    -- Build Combined Test Names
    ---------------------------------------------------
    SELECT @AllTests = STRING_AGG(rad_name, ', ')
    FROM @Rads;

    ---------------------------------------------------
    -- Generate new invoice_id
    ---------------------------------------------------
    SELECT @invoice_id = ISNULL(MAX(invoice_id), 0) + 1
    FROM Invoice;

    ---------------------------------------------------
    -- Insert Invoice header
    ---------------------------------------------------
    INSERT INTO Invoice (invoice_id, date, paid_money, payment_method, p_id, emp_id)
    VALUES (@invoice_id, GETDATE(), @TotalPrice, @payment_method, @p_id, @Receptionist_ID);

    ---------------------------------------------------
    -- Generate reservation_id (ONE for all tests)
    ---------------------------------------------------
    SELECT @reservation_id = ISNULL(MAX(reservation_id), 0) + 1
    FROM Radio_reservation;

    ---------------------------------------------------
    -- Insert Radio_reservation (1 row only)
    ---------------------------------------------------
    INSERT INTO Radio_reservation (reservation_id, date, paid_money, p_id, rad_name, Doctor_id, receptionist_id)
    VALUES (@reservation_id, GETDATE(), @TotalPrice, @p_id, @AllTests, @radio_doctorID, @Receptionist_ID);

    ---------------------------------------------------
    -- Insert each test into Rad_reserve + Invoice_Details
    ---------------------------------------------------
    INSERT INTO Rad_reserve (rad_id, reservation_id, test_result)
    SELECT ra.rad_id, @reservation_id, NULL
    FROM @Rads r
    JOIN Radiology ra ON ra.rad_name = r.rad_name;

    INSERT INTO Invoice_Details (invoice_id, reservation_id, reservation_type, Process_id, unit_price, quantity, Total, dept_id)
    SELECT 
        @invoice_id,
        @reservation_id,
        'Radiology',
        ra.rad_id,
        ra.price,
        1,
        ra.price,
        14
    FROM @Rads r
    JOIN Radiology ra ON ra.rad_name = r.rad_name;

    ---------------------------------------------------
    -- Success Message
    ---------------------------------------------------
    SET @msg = N'Radiology reservation completed. Total = ' 
               + CAST(@TotalPrice AS NVARCHAR(20))
               + N' | Reservation ID = ' + CAST(@reservation_id AS NVARCHAR(20))
               + N' | Invoice = ' + CAST(@invoice_id AS NVARCHAR(20));

END;
GO

                    ---------------------------------------------------------------
                        -- SP to update test_result column in Rad_reserve Table
                    ---------------------------------------------------------------
GO
CREATE TYPE RadioResultUpdateType AS TABLE
(
    rad_name NVARCHAR(100),
    test_result NVARCHAR(255)
);
GO
CREATE OR ALTER PROCEDURE sp_UpdateRadiologyResult
    @reservation_id INT,
    @Results RadioResultUpdateType READONLY
AS
BEGIN
    SET NOCOUNT ON;

    -- Update radiology results automatically by matching rad_name
    UPDATE rr
    SET rr.test_result = r.test_result
    FROM Rad_reserve rr
    JOIN Radiology ra ON rr.rad_id = ra.rad_id
    JOIN @Results r ON ra.rad_name = r.rad_name
    WHERE rr.reservation_id = @reservation_id;
END;
GO


