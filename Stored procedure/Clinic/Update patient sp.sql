CREATE OR ALTER PROCEDURE sp_update_patient_by_ssn
    @ssn NVARCHAR(20),
    @email NVARCHAR(100) = NULL,
    @phone NVARCHAR(20) = NULL,
    @msg NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- ?????? ?? ???? ?????? ?????
    IF NOT EXISTS (SELECT 1 FROM Patient WHERE ssn = @ssn)
    BEGIN
        SET @msg = 'Patient with provided SSN not found.';
        RETURN;
    END

    -- ????? ??????? ???? ?????? ???
    UPDATE Patient
    SET 
        email = COALESCE(@email, email),
        phone = COALESCE(@phone, phone)
    WHERE ssn = @ssn;

    SET @msg = 'Patient email and phone updated successfully.';
END;
GO





