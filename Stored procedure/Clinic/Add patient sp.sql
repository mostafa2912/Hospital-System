CREATE OR ALTER PROCEDURE sp_add_or_get_patient_by_ssn
    @fname NVARCHAR(50),
    @lname NVARCHAR(50),
    @email NVARCHAR(100),
    @birth_date DATE,
    @gender NVARCHAR(10),
    @phone NVARCHAR(20),
    @ssn NVARCHAR(20),
    @out_p_id INT OUTPUT,
    @msg NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT @out_p_id = p_id
    FROM Patient
    WHERE ssn = @ssn;

    IF @out_p_id IS NOT NULL
    BEGIN
        SET @msg = N'Patient already exists. Returned existing p_id.';
        RETURN;
    END

    SELECT @out_p_id = ISNULL(MAX(p_id), 0) + 1
    FROM Patient;

    INSERT INTO Patient (p_id, fname, lname, email, birth_date, gender, phone, ssn)
    VALUES (@out_p_id, @fname, @lname, @email, @birth_date, @gender, @phone, @ssn);

    SET @msg = N'Patient inserted successfully.';
END;
GO








