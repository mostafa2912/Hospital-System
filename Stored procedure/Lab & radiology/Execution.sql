                         -----------------------------
                            -- The  Execution of add new reservation in lab
                         -----------------------------
GO
DECLARE @msg NVARCHAR(100);
DECLARE @Tests TestListType;

INSERT INTO @Tests (test_name)
VALUES  ('ABG')

EXEC sp_AddLabReservation
    @p_id = 18,
    @Tests = @Tests,
	@payment_method='visa',
    @msg = @msg OUTPUT;
SELECT @msg AS ResultMessage;

SELECT * 
FROM Lab_reservation  

------------------------------------------------------------------------------------------------------------------------------
                             -----------------------------
                                -- The  Execution of update test_result column in Test_reserve Table
                             -----------------------------
GO
EXEC sp_UpdateLabResult 
    @reservation_id = 38602, 
    @test_result = 'Negative';

-- To show table after updating Test Result
SELECT * FROM Test_reserve WHERE reservation_id = 38602;
-----------------------------------------------------------------------------------------------------------------------------------
                            ----------------------------
                              -- The  Execution of add new reservation in Radiology
                            ----------------------------

DECLARE @Rads RadioListType;
INSERT INTO @Rads (rad_name)
VALUES ('CAT Scan'), ('MRI'), ('Chest X-ray');

DECLARE @msg NVARCHAR(500);

EXEC sp_AddRadioReservation_Multi
    @p_id = 100,
    @payment_method = 'Cash',
    @Rads = @Rads,
    @msg = @msg OUTPUT;
SELECT @msg AS ResultMessage;
--------------------------------------------------------------------------------------------------------------------------------------
                            ---------------------------------
                                -- The  Execution of update test_result column in Rad_reserve Table
                            ---------------------------------
EXEC sp_UpdateRadiologyResult 
    @reservation_id = 16780, 
    @test_result = 'Normal Chest X-Ray';

SELECT * 
FROM Rad_reserve
WHERE reservation_id = 16780;
---------------------------------------------------------------------------------------

-- Exec to insert and update lab_tests
DECLARE @msg NVARCHAR(50);
EXEC sp_manage_lab_tests
    @action = 'insert',
    @test_name = 'cbc Test',
    @delivery_duration = 3,
    @price = 150,
    @msg = @msg OUTPUT;         
SELECT @msg AS [Result_Message];

SELECT * 
FROM Lab_tests   
-----------------------------------------------------------------------------------------------
-- Exec to delete lab_tests
DECLARE @msg NVARCHAR(50);
EXEC sp_delete_lab_tests
    @action = 'delete',
    @test_id = 112,
    @msg = @msg OUTPUT;         

SELECT @msg AS [Result_Message];

SELECT * 
FROM Lab_tests  
--------------------------------------------------------------------------------------------------------
-- Exec to insert and update radiology
DECLARE @msg NVARCHAR(50);

EXEC sp_manage_radiology
    @action = 'insert',
    @rad_name = 'CT_Scan',
    @delivery_duration = 2,
    @price = 400,
    @msg = @msg OUTPUT;
SELECT @msg AS [Result_Message];

SELECT * FROM Radiology;
---------------------------------------------------------------------------------------------------------
-- Exec to delete radiology
DECLARE @msg NVARCHAR(50);
EXEC sp_delete_radiology
    @action = 'delete',
    @rad_id = 132,
    @msg = @msg OUTPUT;
SELECT @msg AS [Result_Message];

SELECT * FROM Radiology;
---------------------------------------------------------------------------------
--Expenses EXEC
DECLARE @msg NVARCHAR(200);

EXEC sp_InsertExpenses
    @date = '2025-12-08',
    @expense_type = 'water',
    @amount = 25000,
    @msg = @msg OUTPUT;
SELECT @msg AS [Result_Message];
