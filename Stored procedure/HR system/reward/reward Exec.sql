--Exec reward
DECLARE @msg NVARCHAR(200);

EXEC sp_InsertReward
    @emp_id = 4,
    @reward_type = N'Complete his job fast and perfect',
    @amount = 1000,
    @Message = @msg OUTPUT;
SELECT @msg AS Result;
