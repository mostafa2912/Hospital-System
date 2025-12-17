--Employee 
--Sp for insert new employee to the system
CREATE OR ALTER PROCEDURE sp_InsertNewEmployee
    @fname NVARCHAR(50),
    @lname NVARCHAR(50),
    @ssn NVARCHAR(20),
    @gender NVARCHAR(10),
    @birth_date DATE,
    @phone NVARCHAR(20),
    @email NVARCHAR(100),
    @salary DECIMAL(18,2),
    @type NVARCHAR(50),
    @dept_id INT,
    @start_job DATE = NULL,
    @end_job DATE = NULL,
    @status NVARCHAR(10) = 'Active',
    @Message NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @new_emp_id INT;
    DECLARE @existing_status NVARCHAR(10);

    IF @start_job IS NULL
        SET @start_job = CAST(GETDATE() AS DATE);

    -- check if ssn available before or not
    SELECT @existing_status = status
    FROM Employee
    WHERE ssn = @ssn;

    IF @existing_status IS NOT NULL
    BEGIN
        IF @existing_status = 'Inactive'
        BEGIN
            SET @Message = N'This Employee cannot be re-hired because he/she is inactive';
            RETURN;
        END
        ELSE IF @existing_status = 'Active'
        BEGIN
            SET @Message = N'This Employee is already working with us';
            RETURN;
        END
    END

    -- check phone duplication
    IF EXISTS (SELECT 1 FROM Employee WHERE phone = @phone)
    BEGIN
        SET @Message = N'This phone number is already used by another employee';
        RETURN;
    END

    -- check email duplication
    IF EXISTS (SELECT 1 FROM Employee WHERE email = @email)
    BEGIN
        SET @Message = N'This email address is already used by another employee';
        RETURN;
    END

    -- check department availability
    IF NOT EXISTS (SELECT 1 FROM Department WHERE dept_id = @dept_id)
    BEGIN
        SET @Message = N'This department does not exist';
        RETURN;
    END

    -- generate new emp_id
    SELECT @new_emp_id = ISNULL(MAX(emp_id), 0) + 1 FROM Employee;

    INSERT INTO Employee
        (emp_id, fname, lname, ssn, gender, birth_date, phone, email, salary, type, dept_id, start_job, end_job, status)
    VALUES
        (@new_emp_id, @fname, @lname, @ssn, @gender, @birth_date, @phone, @email, @salary, @type, @dept_id, @start_job, @end_job, @status);

    SET @Message = N'Employee Added Successfully';
END;
go

-------------------------------------------------------------------------------------------------------------------------------------------
--Sp for update employee data on the system
CREATE OR ALTER PROCEDURE sp_UpdateEmployee
  @emp_id INT,
  @phone NVARCHAR(20),
  @email NVARCHAR(100),
  @salary DECIMAL(18,2),
  @type NVARCHAR(50),
  @dept_id INT,
  @end_job DATE = NULL,
  @status NVARCHAR(10) = 'Active',
  @Message NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    --  check emoloyee available or not
    IF NOT EXISTS (SELECT 1 FROM Employee WHERE emp_id = @emp_id)
    BEGIN
        SET @Message = N'This employee does not exist';
        RETURN;
    END


    -- check department available or not
    IF NOT EXISTS (SELECT 1 FROM Department WHERE dept_id = @dept_id)
    BEGIN
        SET @Message = N'This department does not exist';
        RETURN;
    END

    -- check phone duplication
    IF EXISTS (SELECT 1 FROM Employee WHERE phone = @phone AND emp_id <> @emp_id)
    BEGIN
        SET @Message = N'This phone number is already used by another employee';
        RETURN;
    END
	

    -- check email duplication
    IF EXISTS (SELECT 1 FROM Employee WHERE email = @email AND emp_id <> @emp_id)
    BEGIN
        SET @Message = N'This email address is already used by another employee';
        RETURN;
    END

    -- update employee information except ssn
    UPDATE Employee
    SET 
	    phone = @phone,
        email = @email,
        salary = @salary,
        type = @type,
        dept_id = @dept_id,
        end_job = @end_job,
        status = @status
    WHERE emp_id = @emp_id;

    SET @Message = N'Employee Updated Successfully';
END;
go
---------------------------------------------------------------------------------------------------
--sp for change the status of the employee from active to in active (soft delete) without removing him from the system
CREATE OR ALTER PROCEDURE sp_DeleteEmployee
  @emp_id INT,
  @Message NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM Employee WHERE emp_id = @emp_id)
    BEGIN
        SET @Message = N'This employee does not exist';
        RETURN;
    END

    IF EXISTS (SELECT 1 FROM Employee WHERE emp_id = @emp_id AND status = 'Inactive')
    BEGIN
        SET @Message = N'This employee is already inactive';
        RETURN;
    END

    UPDATE Employee
    SET status = 'Inactive',
        end_job = GETDATE()
    WHERE emp_id = @emp_id;

    SET @Message = N'Employee deleted (status set to Inactive) successfully';
END;