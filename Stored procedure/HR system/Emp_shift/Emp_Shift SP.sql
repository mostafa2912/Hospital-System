--sp to insert employee to a shift
CREATE OR ALTER PROCEDURE sp_InsertEmpShift
  @emp_id INT,
  @shift_id INT,
  @Message NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -----------------------------------------
    --check if the employee available or not
    -----------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE emp_id = @emp_id)
    BEGIN
        SET @Message = N'This employee does not exist';
        RETURN;
    END

    -----------------------------------------
    -- check employee satatus
    -----------------------------------------
    IF EXISTS (SELECT 1 FROM Employee WHERE emp_id = @emp_id AND status = 'inactive')
    BEGIN
        SET @Message = N'This employee is inactive and cannot be assigned to a shift';
        RETURN;
    END

    -----------------------------------------
    -- check shift availability
    -----------------------------------------
    IF NOT EXISTS (SELECT 1 FROM Shift WHERE shift_id = @shift_id)
    BEGIN
        SET @Message = N'This shift does not exist';
        RETURN;
    END

    -----------------------------------------
    -- check if the employee in a shift or not
    -----------------------------------------
    DECLARE @existing_shift_id INT;

    SELECT TOP 1 @existing_shift_id = shift_id
    FROM Emp_shift
    WHERE emp_id = @emp_id
    ORDER BY shift_id;  

    IF @existing_shift_id IS NOT NULL
    BEGIN
        SET @Message = 
            N'This employee is already assigned to shift number ' 
            + CAST(@existing_shift_id AS NVARCHAR(10)) 
            + N' and cannot be assigned to another shift.';
        RETURN;
    END

    -----------------------------------------
    -- assign the employee to the new shift
    -----------------------------------------
    INSERT INTO Emp_shift (emp_id, shift_id)
    VALUES (@emp_id, @shift_id);

    SET @Message = N'✅ Employee assigned to shift successfully';
END;
go
----------------------------------------------------------------------------------------------------------------------
-- sp for update employee shift
CREATE OR ALTER PROCEDURE sp_UpdateEmpShift
  @emp_id INT,
 -- @old_shift_id INT,
  @new_shift_id INT,
  @Message NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM Employee WHERE emp_id = @emp_id)
    BEGIN
        SET @Message = N'This employee does not exist';
        RETURN;
    END
	    -----------------------------------------
    -- check employee satatus
    -----------------------------------------
    IF EXISTS (SELECT 1 FROM Employee WHERE emp_id = @emp_id AND status = 'inactive')
    BEGIN
        SET @Message = N'This employee is inactive and cannot be assigned to a shift';
        RETURN;
    END

    IF NOT EXISTS (SELECT 1 FROM Shift WHERE shift_id = @new_shift_id)
    BEGIN
        SET @Message = N'The new shift does not exist';
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM Emp_shift WHERE emp_id = @emp_id AND shift_id = @new_shift_id)
    BEGIN
        SET @Message = N'This employee already exists in this shift';
        RETURN;
    END

    UPDATE Emp_shift
    SET shift_id = @new_shift_id
    WHERE emp_id = @emp_id 

    SET @Message = N'Shift has been modified successfully';
END;
go
--------------------------------------------------------------------------------------------------------------------
-- sp to delete employee from a shift
CREATE OR ALTER PROCEDURE sp_DeleteEmpShift
  @emp_id INT,
  @shift_id INT,
  @Message NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM Emp_shift WHERE emp_id = @emp_id AND shift_id = @shift_id)
    BEGIN
        SET @Message = N'Emp_id and shift_id mismatched';
        RETURN;
    END

    DELETE FROM Emp_shift
    WHERE emp_id = @emp_id AND shift_id = @shift_id;

    SET @Message = N'Employee has been deleted from the shift successfully';
END;


