CREATE OR ALTER PROCEDURE sp_RepeatShiftAppointments
    @Message NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LastYear INT, @LastMonth INT;
    DECLARE @NewYear INT, @NewMonth INT;
    DECLARE @OldDays INT, @NewDays INT;
    DECLARE @ExtraDay INT;
    DECLARE @SecondLastDay INT;

    -- bring data from last month
    SELECT TOP 1 
           @LastYear = YEAR([date]),
           @LastMonth = MONTH([date])
    FROM Shift_appointment
    ORDER BY [date] DESC;

    IF @LastYear IS NULL OR @LastMonth IS NULL
    BEGIN
        SET @Message = N'No previous shifts found to copy.';
        RETURN;
    END

    -- calculate next month and year automatically
    SET @NewMonth = @LastMonth + 1;
    SET @NewYear = @LastYear;

    IF @NewMonth > 12
    BEGIN
        SET @NewMonth = 1;
        SET @NewYear = @LastYear + 1;
    END

    SET @OldDays = DAY(EOMONTH(DATEFROMPARTS(@LastYear, @LastMonth, 1)));
    SET @NewDays = DAY(EOMONTH(DATEFROMPARTS(@NewYear, @NewMonth, 1)));

    -- remove duplicates in shifts if available
    DELETE FROM Shift_appointment
    WHERE YEAR([date]) = @NewYear AND MONTH([date]) = @NewMonth;

    -- add shifts to days same to previous month
    INSERT INTO Shift_appointment (shift_id, shift_type, [date], start_time, end_time)
    SELECT 
        shift_id,
        shift_type,
        DATEFROMPARTS(@NewYear, @NewMonth, DAY([date])),
        start_time,
        end_time
    FROM Shift_appointment
    WHERE YEAR([date]) = @LastYear 
      AND MONTH([date]) = @LastMonth
      AND DAY([date]) <= @NewDays;

    --handle difference in month days along the year
    IF @NewDays > @OldDays
    BEGIN
        SET @ExtraDay = @OldDays + 1;
        SET @SecondLastDay = @OldDays - 1;

        INSERT INTO Shift_appointment (shift_id, shift_type, [date], start_time, end_time)
        SELECT 
            shift_id,
            shift_type,
            DATEFROMPARTS(@NewYear, @NewMonth, @ExtraDay),
            start_time,
            end_time
        FROM Shift_appointment
        WHERE YEAR([date]) = @LastYear 
          AND MONTH([date]) = @LastMonth
          AND DAY([date]) = @SecondLastDay;
    END

    SET @Message = N'Shift appointments have been repeated successfully for the next month.';
END



