-- Add new employee to the system

DECLARE @ResultMessage NVARCHAR(200);
EXEC sp_InsertNewEmployee
    @fname = 'mostafa',
    @lname = 'Ahmed',
    @ssn = '30012291800974',
    @gender = 'Male',
    @birth_date = '1990-01-01',
    @phone = '01019654777',
    @email = 'mstafa9@example.com',
    @salary = 15000,
    @type = 'nurse',
    @dept_id = 10,
    @Message = @ResultMessage OUTPUT;
SELECT @ResultMessage AS Message;
------------------------------------------------------------
------------------------------------------------------------
-- upate Active employees data

DECLARE @msg NVARCHAR(200);
EXEC sp_UpdateEmployee
    @emp_id = 102,
    @phone = '01219654799',
    @email = 'mstafa4@example.com',
    @salary = 21000,
    @type = 'nurse',
    @dept_id = 12,
    @Message = @msg OUTPUT;
SELECT @msg AS UpdateMessage;
------------------------------------------------------------------
------------------------------------------------------------------
-- change employee to inactive when finishing work with us And Add End Job Date

DECLARE @msg NVARCHAR(200);
EXEC sp_DeleteEmployee
    @emp_id = 102,
    @Message = @msg OUTPUT;
SELECT @msg AS DeleteMessage;
--------------------------------------------------------------------
--------------------------------------------------------------------
-- Assign the new employees to a shift

DECLARE @msg NVARCHAR(200);
EXEC sp_InsertEmpShift 
    @emp_id = 103,
    @shift_id = 3,
    @Message = @msg OUTPUT;
SELECT @msg AS ResultMessage;
----------------------------------------------------------------------
----------------------------------------------------------------------
-- update employee shift to another shift

DECLARE @msg NVARCHAR(200);
EXEC sp_UpdateEmpShift 
    @emp_id = 103,
    @new_shift_id = 2,
    @Message = @msg OUTPUT;
SELECT @msg AS Result;
-----------------------------------------------------------------------------------
-----------------------------------------------------------------------------------
-- Remove employee from a shift

DECLARE @msg NVARCHAR(200);
EXEC sp_DeleteEmpShift
    @emp_id = 103,
    @shift_id = 2,
    @Message = @msg OUTPUT;
SELECT @msg AS DeleteMessage;
----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------
-- Handle Employee Shifts Every Month Automatically

DECLARE @Msg NVARCHAR(200);
EXEC sp_RepeatShiftAppointments @Message = @Msg OUTPUT;
SELECT @Msg AS ResultMessage;
-- Handeled by Job Schedule at day 1 every month
------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------
-- Employee Attendence And Auto Adding Deductions In Late Arrival Or Early Leave

--Exec for checkin

DECLARE @ResultMessage NVARCHAR(200);
EXEC sp_CheckInEmployee
    @emp_id = 21,
    @Message = @ResultMessage OUTPUT;
SELECT @ResultMessage AS Message;

------------------------------------------------------------------------------------------------------
--Exec for checkout
DECLARE @ResultMessage NVARCHAR(200);
EXEC sp_CheckOutEmployee
    @emp_id = 21,
    @Message = @ResultMessage OUTPUT;
SELECT @ResultMessage AS Message;
-------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------
-- Add Monthly Expenses

DECLARE @msg NVARCHAR(200);
EXEC sp_InsertExpenses
    @date = '2025-12-08',
    @expense_type = 'water',
    @amount = 25000,
    @msg = @msg OUTPUT;
SELECT @msg AS [Result_Message];
