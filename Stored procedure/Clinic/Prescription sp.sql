CREATE OR ALTER PROCEDURE sp_add_prescription_by_reservation
    @reservation_id INT,
    @notes NVARCHAR(500),
    @msg NVARCHAR(200) OUTPUT,
    @drug_name nvarchar(max)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @p_id INT;
    DECLARE  @doctor_id INT;
    DECLARE @app_date DATETIME;
    DECLARE @day NVARCHAR(20);
    DECLARE @shift_start TIME;
    DECLARE @shift_end TIME;
    DECLARE @new_prescription_id INT;


    -- جلب بيانات الحجز
    SELECT @p_id = p_id, @doctor_id = doctor_id, @app_date = date_time
    FROM appointment_reservation
    WHERE reservation_id = @reservation_id;

    IF @p_id IS NULL
    BEGIN
        SET @msg = 'Invalid reservation id.';
        SELECT @msg AS Message;
        RETURN;
    END

   

	
	 IF EXISTS (SELECT 1 FROM prescription WHERE  @reservation_id = reservation_id)
    BEGIN
        SET @msg = N' This reservation already have a prescription '
         SELECT @msg AS Message;
        RETURN;
    END


    SELECT @new_prescription_id = ISNULL(MAX(prescription_id), 0) + 1
    FROM prescription;

    -- إدخال الروشتة (prescription_id و date تلقائي)
    INSERT INTO Prescription ( prescription_id,date, notes, p_id, reservation_id,drug_name)
    VALUES ( @new_prescription_id,CONVERT(date, GETDATE()), @notes, @p_id, @reservation_id,@drug_name)

    SET @msg = 'Prescription added successfully. Prescription ID = ' 
    + CAST(@new_prescription_id AS NVARCHAR)
     SELECT @msg AS Message

END

GO



