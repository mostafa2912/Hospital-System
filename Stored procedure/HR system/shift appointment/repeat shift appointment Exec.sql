DECLARE @Msg NVARCHAR(200);
EXEC sp_RepeatShiftAppointments @Message = @Msg OUTPUT;
SELECT @Msg AS ResultMessage;
