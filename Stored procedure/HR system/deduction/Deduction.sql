CREATE OR ALTER PROCEDURE sp_CalculateAttendanceDeduction
    @emp_id INT,
    @attend_date DATE,
    @Message NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @emp_type NVARCHAR(20),
            @shift_start TIME,
            @shift_end TIME,
            @checkin DATETIME,
            @checkout DATETIME,
            @monthly_salary DECIMAL(18,2),
            @daily_salary DECIMAL(18,2),
            @delay_minutes INT = 0,
            @early_minutes INT = 0,
            @deduction_amount DECIMAL(18,2) = 0,
            @deduction_type NVARCHAR(200) = N'';

    SELECT @emp_type = [type], @monthly_salary = salary
    FROM Employee
    WHERE emp_id = @emp_id;

    IF @emp_type IS NULL
    BEGIN
        SET @Message = N'Employee not found';
        RETURN;
    END

    SET @daily_salary = @monthly_salary / 30.0;

    IF @emp_type = 'Doctor'
    BEGIN
        SELECT TOP 1 
            @shift_start = shift_start, 
            @shift_end = shift_end
        FROM Doctor_appointments
        WHERE emp_id = @emp_id 
          AND [day] = DATENAME(WEEKDAY, @attend_date);  
    END
    ELSE
    BEGIN
        SELECT TOP 1 
            @shift_start = start_time, 
            @shift_end = end_time
        FROM Shift_appointment
        WHERE [date] = @attend_date;  
    END

    IF @shift_start IS NULL OR @shift_end IS NULL
    BEGIN
        SET @Message = N'No shift found for this date';
        RETURN;
    END

    SELECT @checkin = checkin, @checkout = checkout
    FROM Attendance
    WHERE emp_id = @emp_id AND attend_date = @attend_date;

    IF @checkin IS NULL
    BEGIN
        SET @Message = N'No attendance record found for this date';
        RETURN;
    END

    IF @checkout IS NULL
    BEGIN
        SET @Message = N'Employee did not check out';
        RETURN;
    END

    SET @delay_minutes = DATEDIFF(MINUTE, @shift_start, CAST(@checkin AS TIME));
    IF @delay_minutes < 0 SET @delay_minutes = 0;

    SET @early_minutes = DATEDIFF(MINUTE, CAST(@checkout AS TIME), @shift_end);
    IF @early_minutes < 0 SET @early_minutes = 0;

    IF @delay_minutes = 0 AND @early_minutes = 0
    BEGIN
        SET @Message = N'No deduction — employee was on time';
        RETURN;
    END

    IF @delay_minutes > 0 AND @early_minutes > 0
    BEGIN
        SET @deduction_amount = @daily_salary;
        SET @deduction_type = CONCAT('Full day deduction: Delay (', @delay_minutes, ' min) & Early Leave (', @early_minutes, ' min)');
    END
    ELSE IF @delay_minutes > 0
    BEGIN
        IF @delay_minutes < 60
        BEGIN
            SET @deduction_amount = @daily_salary * 0.1;
            SET @deduction_type = CONCAT('Delay < 1h (', @delay_minutes, ' min)');
        END
        ELSE
        BEGIN
            SET @deduction_amount = @daily_salary * 0.5;
            SET @deduction_type = CONCAT('Delay >= 1h (', @delay_minutes, ' min)');
        END
    END
    ELSE IF @early_minutes > 0
    BEGIN
        SET @deduction_amount = @daily_salary * 0.5;
        SET @deduction_type = CONCAT('Early Leave (', @early_minutes, ' min)');
    END

    DELETE FROM Deduction
    WHERE emp_id = @emp_id AND [date] = @attend_date;

    INSERT INTO Deduction (emp_id, Ded_type, [date], amount)
    VALUES (@emp_id, @deduction_type, @attend_date, @deduction_amount);

    SET @Message = CONCAT('Deduction applied: ', @deduction_type, ' - Amount: ', @deduction_amount);
END;
--executed after employee do checkout automatically
----------------------------------------------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_HandleMissingCheckout_SetBased
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @now DATETIME = GETDATE(),
            @grace_minutes INT = 30;

    -- حذف الجدول المؤقت لو موجود
    IF OBJECT_ID('tempdb..#MissingCheckout') IS NOT NULL 
        DROP TABLE #MissingCheckout;

    -- استخراج الموظفين اللي ماعملوش تسجيل خروج بعد انتهاء الشيفت + مدة السماح
    SELECT 
        A.emp_id,
        A.attend_date,
        E.salary AS monthly_salary,
        CASE 
            WHEN E.[type] = 'Doctor' THEN 
                CASE 
                    WHEN CAST(DA.shift_end AS TIME) = '00:00:00' 
                        THEN DATEADD(SECOND, -60, DATEADD(DAY, 1, CAST(A.attend_date AS DATETIME))) -- 23:59
                    WHEN CAST(DA.shift_end AS TIME) < CAST(DA.shift_start AS TIME)
                        THEN DATEADD(DAY, 1, CAST(A.attend_date AS DATETIME) + CAST(DA.shift_end AS DATETIME))
                    ELSE CAST(A.attend_date AS DATETIME) + CAST(DA.shift_end AS DATETIME)
                END
            ELSE 
                CASE 
                    WHEN CAST(SA.end_time AS TIME) = '00:00:00' 
                        THEN DATEADD(SECOND, -60, DATEADD(DAY, 1, CAST(A.attend_date AS DATETIME))) -- 23:59
                    WHEN CAST(SA.end_time AS TIME) < CAST(SA.start_time AS TIME)
                        THEN DATEADD(DAY, 1, CAST(A.attend_date AS DATETIME) + CAST(SA.end_time AS DATETIME))
                    ELSE CAST(A.attend_date AS DATETIME) + CAST(SA.end_time AS DATETIME)
                END
        END AS shift_end
    INTO #MissingCheckout
    FROM Attendance A
    JOIN Employee E ON A.emp_id = E.emp_id
    LEFT JOIN Doctor_appointments DA
        ON E.[type] = 'Doctor'
        AND DA.emp_id = A.emp_id
        AND DA.[day] = DATENAME(WEEKDAY, A.attend_date)
    LEFT JOIN Emp_shift ES
        ON E.[type] <> 'Doctor'
        AND ES.emp_id = A.emp_id
    LEFT JOIN Shift_appointment SA
        ON ES.shift_id = SA.shift_id
        AND SA.[date] = A.attend_date
    WHERE A.checkout IS NULL
      AND DATEADD(MINUTE, @grace_minutes,
            CASE 
                WHEN E.[type] = 'Doctor' THEN 
                    CASE 
                        WHEN CAST(DA.shift_end AS TIME) = '00:00:00' 
                            THEN DATEADD(SECOND, -60, DATEADD(DAY, 1, CAST(A.attend_date AS DATETIME)))
                        WHEN CAST(DA.shift_end AS TIME) < CAST(DA.shift_start AS TIME)
                            THEN DATEADD(DAY, 1, CAST(A.attend_date AS DATETIME) + CAST(DA.shift_end AS DATETIME))
                        ELSE CAST(A.attend_date AS DATETIME) + CAST(DA.shift_end AS DATETIME)
                    END
                ELSE 
                    CASE 
                        WHEN CAST(SA.end_time AS TIME) = '00:00:00' 
                            THEN DATEADD(SECOND, -60, DATEADD(DAY, 1, CAST(A.attend_date AS DATETIME)))
                        WHEN CAST(SA.end_time AS TIME) < CAST(SA.start_time AS TIME)
                            THEN DATEADD(DAY, 1, CAST(A.attend_date AS DATETIME) + CAST(SA.end_time AS DATETIME))
                        ELSE CAST(A.attend_date AS DATETIME) + CAST(SA.end_time AS DATETIME)
                    END
            END) < @now;

    -- تحديث checkout الوهمي
    UPDATE A
    SET checkout = MC.shift_end
    FROM Attendance A
    INNER JOIN #MissingCheckout MC
        ON A.emp_id = MC.emp_id
        AND A.attend_date = MC.attend_date;

    -- حذف أي خصومات سابقة لنفس اليوم لتفادي التكرار
    DELETE D
    FROM Deduction D
    INNER JOIN #MissingCheckout MC
        ON D.emp_id = MC.emp_id
        AND D.[date] = MC.attend_date;

    -- إضافة الخصم اليومي
    INSERT INTO Deduction (emp_id, ded_type, [date], amount)
    SELECT 
        emp_id,
        'No checkout - Full day deduction',
        attend_date,
        monthly_salary / 30.0 AS daily_salary
    FROM #MissingCheckout;

    DROP TABLE #MissingCheckout;
END;

-- it works with SQL Agent Job excute every 30 minutes all days
----------------------------------------------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_InsertManualDeduction
    @emp_id INT,
    @deduction_type NVARCHAR(100),
    @amount DECIMAL(18,2),
    @deduction_date DATE = NULL,  
    @Message NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM Employee WHERE emp_id = @emp_id)
    BEGIN
        SET @Message = N'Employee not found';
        RETURN;
    END

	   IF EXISTS (SELECT 1 FROM Employee WHERE emp_id = @emp_id AND status = 'Inactive')
    BEGIN
        SET @Message = N'Employee is inactive and cannot add deduction';
        RETURN;
    END

    IF @amount <= 0
    BEGIN
        SET @Message = N'Deduction amount must be greater than zero';
        RETURN;
    END

    IF @deduction_date IS NULL
        SET @deduction_date = CAST(GETDATE() AS DATE);

    INSERT INTO Deduction (emp_id, Ded_type, [date], amount)
    VALUES (@emp_id, CONCAT('Manual - ', @deduction_type), @deduction_date, @amount);

    SET @Message = N'Manual deduction added successfully';
END;


