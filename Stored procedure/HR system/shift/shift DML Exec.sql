--insert new shift exec
DECLARE @Msg NVARCHAR(200);
EXEC sp_AddShift 
    @shift_name = N'aya',
    @Message = @Msg OUTPUT;
SELECT @Msg AS Result;
---------------------------------------------------------------------------
--update shift Exec
DECLARE @Msg NVARCHAR(200);
EXEC sp_UpdateShift 
    @shift_id = 4, 
    @shift_name = N'mostafa',
    @Message = @Msg OUTPUT;
SELECT @Msg AS Result;
------------------------------------------------------------------
--delete shift Exec
DECLARE @Msg NVARCHAR(200);
EXEC sp_DeleteShift 
    @shift_id = 4,
    @Message = @Msg OUTPUT;
SELECT @Msg AS Result;