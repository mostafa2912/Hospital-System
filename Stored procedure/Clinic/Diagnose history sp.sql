CREATE OR ALTER PROCEDURE sp_add_diagnose_by_reservation
    @reservation_id INT,
    @dig_description NVARCHAR(300),
    @msg NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
	
	DECLARE @DigID INT;
    DECLARE @p_id INT;
    DECLARE @doctor_id INT;
	declare @new_dig_id int

    -- الحصول على p_id و doctor_id من الحجز
    SELECT @p_id = p_id, @doctor_id = doctor_id
    FROM appointment_reservation
    WHERE reservation_id = @reservation_id;

    IF @p_id IS NULL
    BEGIN
        SET @msg = 'Invalid reservation_id.';
        RETURN;
    END


SELECT @new_dig_id = ISNULL(MAX(dig_id), 0) + 1
FROM Diagnose_history;

    -- إدخال التشخيص (dig_id افتراضي Identity)
    INSERT INTO Diagnose_history (dig_id,dig_description, p_id, emp_id)
    VALUES (@new_dig_id,@dig_description, @p_id, @doctor_id);

    SET @msg = 'Diagnosis inserted successfully.';

END;
GO



