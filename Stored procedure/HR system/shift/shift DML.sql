CREATE OR ALTER PROCEDURE sp_AddShift
	@shift_name NVARCHAR(100),
    @Message NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
		DECLARE @new_shift_id INT;

    IF EXISTS (SELECT 1 FROM Shift WHERE shift_name = @shift_name)
    BEGIN
        SET @Message = N'Shift name already exists';
        RETURN;
    END

	SELECT @new_shift_id = ISNULL(MAX(shift_id), 0) + 1 FROM shift;

    INSERT INTO Shift (shift_id,shift_name)
    VALUES (@new_shift_id, @shift_name);

    SET @Message = N'Shift added successfully';
END;
go
------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_UpdateShift
    @shift_id INT,
    @shift_name NVARCHAR(100),
    @Message NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM Shift WHERE shift_id = @shift_id)
    BEGIN
        SET @Message = N'Shift not found';
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM Shift WHERE shift_name = @shift_name AND shift_id <> @shift_id)
    BEGIN
        SET @Message = N'Shift name already exists for another shift';
        RETURN;
    END

    UPDATE Shift
    SET shift_name = @shift_name
    WHERE shift_id = @shift_id;

    SET @Message = N'Shift updated successfully';
END;
go
--------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_DeleteShift
    @shift_id INT,
    @Message NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM Shift WHERE shift_id = @shift_id)
    BEGIN
        SET @Message = N'Shift not found';
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM Emp_shift WHERE shift_id = @shift_id)
    BEGIN
        SET @Message = N'Cannot delete shift assigned to employees';
        RETURN;
    END

    DELETE FROM Shift WHERE shift_id = @shift_id;

    SET @Message = N'Shift deleted successfully';
END;
