CREATE OR ALTER PROCEDURE sp_add_doctor_reservation
    @p_id INT,
    @dept_id INT,
    @payment_method NVARCHAR(50),
    @msg NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @today NVARCHAR(20) = DATENAME(WEEKDAY, GETDATE());
    DECLARE @doctor_id INT;
    DECLARE @receptionist_id INT;
    DECLARE @doctor_price DECIMAL(10,2);
    DECLARE @current_reservations INT;
    DECLARE @new_reservation_id INT;
    DECLARE @new_invoice_id INT;

    -----------------------------------------------------
    -- ✅ 1) Validate department has registered doctors
    -----------------------------------------------------
    IF NOT EXISTS (
        SELECT 1 FROM Doctor_appointments WHERE dept_id = @dept_id
    )
    BEGIN
        SET @msg = N'❌ This department has no registered doctors.';
        RETURN;
    END;

    -----------------------------------------------------
    -- ✅ 2) Select the currently available doctor (same department)
    -----------------------------------------------------
    SELECT TOP 1
        @doctor_id = da.emp_id,
        @doctor_price = da.examination_price
    FROM Doctor_appointments da
    WHERE da.dept_id = @dept_id
      AND da.day = @today
      AND CAST(GETDATE() AS TIME) BETWEEN da.shift_start AND da.shift_end;

    IF @doctor_id IS NULL
    BEGIN
        SET @msg = N'❌ No doctors available now for this department.';
        RETURN;
    END;

    -----------------------------------------------------
    -- ✅ 3) Get the receptionist who is currently on shift
    -----------------------------------------------------
    SELECT TOP 1
        @receptionist_id = e.emp_id
    FROM Employee e
    JOIN Emp_shift es ON e.emp_id = es.emp_id
    JOIN Shift_appointment sa ON es.shift_id = sa.shift_id
    WHERE e.type = 'Receptionist'
      AND CAST(GETDATE() AS TIME) BETWEEN sa.start_time AND sa.end_time
      AND CAST(sa.date AS DATE) = CAST(GETDATE() AS DATE);

    IF @receptionist_id IS NULL
    BEGIN
        SET @msg = N'❌ No receptionist available now.';
        RETURN;
    END;

    -----------------------------------------------------
    -- ✅ 4) Check the doctor's daily reservation limit
    -----------------------------------------------------
    SELECT @current_reservations = COUNT(*)
    FROM appointment_reservation
    WHERE doctor_id = @doctor_id
      AND CAST(date_time AS DATE) = CAST(GETDATE() AS DATE);

    IF @current_reservations >= 20
    BEGIN
        SET @msg = N'❌ Maximum daily reservations reached for this doctor.';
        RETURN;
    END;

    -----------------------------------------------------
    -- ✅ 5) Generate new reservation and invoice IDs
    -----------------------------------------------------
    SELECT @new_reservation_id = ISNULL(MAX(reservation_id), 0) + 1
    FROM appointment_reservation;

    SELECT @new_invoice_id = ISNULL(MAX(invoice_id), 0) + 1
    FROM Invoice;

    -----------------------------------------------------
    -- ✅ 6) Insert the new reservation
    -----------------------------------------------------
    INSERT INTO appointment_reservation
        (reservation_id, date_time, paid_money, p_id, dept_id, doctor_id, receptionist_id)
    VALUES
        (@new_reservation_id, GETDATE(), @doctor_price, @p_id, @dept_id, @doctor_id, @receptionist_id);

    -----------------------------------------------------
    -- ✅ 7) Create invoice for this reservation
    -----------------------------------------------------
    INSERT INTO Invoice (invoice_id, paid_money, date, payment_method, p_id, emp_id)
    VALUES (@new_invoice_id, @doctor_price, GETDATE(), @payment_method, @p_id, @receptionist_id);

    INSERT INTO Invoice_Details (invoice_id, reservation_id, reservation_type, Process_id, unit_price, quantity, total, dept_id)
    VALUES (
        @new_invoice_id,
        @new_reservation_id,
        'Clinic',
        @doctor_id,
        @doctor_price,
        1,
        @doctor_price,
        @dept_id
    );

    -----------------------------------------------------
    -- ✅ 8) Success message
    -----------------------------------------------------
    SET @msg = 
    N'✔ Reservation completed successfully. Reservation ID = ' 
    + CAST(@new_reservation_id AS NVARCHAR)
    + N', Assigned Doctor ID = ' 
    + CAST(@doctor_id AS NVARCHAR);

END;
GO









