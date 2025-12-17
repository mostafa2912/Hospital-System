-- insert Exec example
DECLARE @ResultMessage NVARCHAR(200);
EXEC sp_InsertNewEmployee
    @fname = 'mstafa',
    @lname = 'Mohamed',
    @ssn = '30012291800952',
    @gender = 'Male',
    @birth_date = '1990-01-01',
    @phone = '01019654789',
    @email = 'mstafa@example.com',
    @salary = 15000,
    @type = 'nurse',
    @dept_id = 10,
    @Message = @ResultMessage OUTPUT;
SELECT @ResultMessage AS Message;

-----------------------------------------------------------------------------------------------------------------
-- Exec for update 
DECLARE @msg NVARCHAR(200);
EXEC sp_UpdateEmployee
    @emp_id = 101,
    @phone = '01019654766',
    @email = 'mstafa@example.com',
    @salary = 21000,
    @type = 'nurse',
    @dept_id = 12,
    @Message = @msg OUTPUT;
SELECT @msg AS UpdateMessage;
--------------------------------------------------------------------------------------------------------
-- Exec for delete 
DECLARE @msg NVARCHAR(200);
EXEC sp_DeleteEmployee
    @emp_id = 101,
    @Message = @msg OUTPUT;
SELECT @msg AS DeleteMessage;
