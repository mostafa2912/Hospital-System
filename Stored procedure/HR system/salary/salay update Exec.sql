EXEC sp_UpdateEmployeeSalary_ByID @emp_id = 1, @increase_percent = 20;
--------------------------------------------------------------------------
EXEC sp_UpdateEmployeeSalary_ByDept @dept_id = 1, @increase_percent = 10;
--------------------------------------------------------------------------
EXEC sp_AnnualSalaryIncrease;
-- run by job schedule