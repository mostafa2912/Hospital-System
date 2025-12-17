CREATE OR ALTER PROCEDURE sp_InsertAndUpdateMonthlySalary
    @SalaryMonth DATE
AS
BEGIN
    SET NOCOUNT ON;

    -- 1️⃣ add salary to all active employees at the beggining of every month
    INSERT INTO Salary (date, salary, Total_reward, Total_deduction, emp_id)
    SELECT 
        @SalaryMonth,
        e.salary,  -- الراتب الأساسي من جدول Employee
        0,
        0,
        e.emp_id
    FROM Employee e
    WHERE e.status = 'Active'
      AND NOT EXISTS (
          SELECT 1 
          FROM Salary s 
          WHERE s.emp_id = e.emp_id 
            AND s.date = @SalaryMonth
      );

    -- 2️⃣ calculate total rewards
    ;WITH RewardsCTE AS (
        SELECT emp_id, SUM(amount) AS TotalReward
        FROM Reward
        WHERE MONTH(date) = MONTH(@SalaryMonth)
          AND YEAR(date) = YEAR(@SalaryMonth)
        GROUP BY emp_id
    ),
    -- 3️⃣ calculate total deductions
    DeductionsCTE AS (
        SELECT emp_id, SUM(amount) AS TotalDeduction
        FROM Deduction
        WHERE MONTH(date) = MONTH(@SalaryMonth)
          AND YEAR(date) = YEAR(@SalaryMonth)
        GROUP BY emp_id
    )
    -- 4️⃣ set salary = salary + total rewards - total deductions
    UPDATE s
    SET 
        Total_reward = ISNULL(r.TotalReward, 0),
        Total_deduction = ISNULL(d.TotalDeduction, 0),
        salary = e.salary + ISNULL(r.TotalReward, 0) - ISNULL(d.TotalDeduction, 0)
    FROM Salary s
    INNER JOIN Employee e ON s.emp_id = e.emp_id
    LEFT JOIN RewardsCTE r ON s.emp_id = r.emp_id
    LEFT JOIN DeductionsCTE d ON s.emp_id = d.emp_id
    WHERE s.date = @SalaryMonth;
END;
