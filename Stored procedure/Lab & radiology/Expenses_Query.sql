CREATE TABLE Expenses (
    id INT IDENTITY(1,1) PRIMARY KEY,
    [date] DATE NOT NULL,
    Expense_id int ,
    amount DECIMAL(10,2) CHECK (amount >= 0),
    FOREIGN KEY (Expense_id) REFERENCES Expenses_Type (Expense_id)
);

------------------------

GO
CREATE PROCEDURE sp_InsertExpenses
    @date DATE,
    @expense_type NVARCHAR(100),
    @amount DECIMAL(10,2),
    @msg NVARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Expense_id INT;

    -- verify expenses type available or not
    SELECT @Expense_id = Expense_id 
    FROM Expenses_Type 
    WHERE Expense_type = @expense_type;

    IF @Expense_id IS NULL
    BEGIN
        SET @msg = N'Invalid expense type.';
        RETURN;
    END

    -- Check if this expense type already exists in the same month/year
    IF EXISTS (
        SELECT 1 
        FROM Expenses
        WHERE Expense_id = @Expense_id
          AND DATEPART(YEAR, [date]) = DATEPART(YEAR, @date)
          AND DATEPART(MONTH, [date]) = DATEPART(MONTH, @date)
    )
    BEGIN
        SET @msg = N'Expense for this type already exists this month.';
        RETURN;
    END

    -- Insert new expense record for this type
    INSERT INTO Expenses ([date], Expense_id, amount)
    VALUES (@date, @Expense_id, @amount);

    SET @msg = N'Expense added successfully.';
END;
GO
