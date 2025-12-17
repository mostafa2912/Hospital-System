CREATE OR ALTER PROCEDURE sp_InsertReward
    @emp_id INT,
    @reward_type NVARCHAR(100),
    @amount DECIMAL(18,2),
    @reward_date DATE = NULL,  
    @Message NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM Employee WHERE emp_id = @emp_id)
    BEGIN
        SET @Message = N'Employee not found';
        RETURN;
    END

    IF @amount <= 0
    BEGIN
        SET @Message = N'Reward amount must be greater than zero';
        RETURN;
    END

    IF @reward_date IS NULL
        SET @reward_date = CAST(GETDATE() AS DATE);

    INSERT INTO Reward (emp_id, reward_type, date, amount)
    VALUES (@emp_id, @reward_type, @reward_date, @amount);

    SET @Message = N'Reward added successfully';
END;




