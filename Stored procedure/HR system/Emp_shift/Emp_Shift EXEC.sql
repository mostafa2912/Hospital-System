--Exec InsertEmpShift
DECLARE @msg NVARCHAR(200);
EXEC sp_InsertEmpShift 
    @emp_id = 98,
    @shift_id = 3,
    @Message = @msg OUTPUT;
SELECT @msg AS ResultMessage;
---------------------------------------------------------------------------------------------------------------------------
--Exec for update 
DECLARE @msg NVARCHAR(200);
EXEC sp_UpdateEmpShift 
    @emp_id = 98,
    @new_shift_id = 3,
    @Message = @msg OUTPUT;
SELECT @msg AS Result;
-----------------------------------------------------------------------------------------------------
--Exec for delete
DECLARE @msg NVARCHAR(200);
EXEC sp_DeleteEmpShift
    @emp_id = 1,
    @shift_id = 2,
    @Message = @msg OUTPUT;
SELECT @msg AS DeleteMessage;
