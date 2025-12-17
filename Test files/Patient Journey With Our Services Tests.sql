-- Add New Patient to the system

DECLARE @p_id_out INT, @message NVARCHAR(200);
EXEC sp_add_or_get_patient_by_ssn
    @fname = N'hepa',
    @lname = N'mohamed',
    @email = N'heba.mohamed@example.com',
    @birth_date = '2003-05-20',
    @gender = N'female',
    @phone = N'01091165987',
    @ssn = N'22235544455539',
    @out_p_id = @p_id_out OUTPUT,
    @msg = @message OUTPUT;
SELECT @p_id_out AS p_id_result, @message AS message_result;
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Patient Reserve Appointment With A Doctor In A Clinic

DECLARE @msg NVARCHAR(200);
EXEC sp_add_doctor_reservation
     @p_id = 15000,
     @dept_id = 3,
     @payment_method = N'visa',
     @msg = @msg OUTPUT;
SELECT @msg AS ResultMessage;
-----------------------------------------------------------------------------------
-----------------------------------------------------------------------------------
-- The Doctor Write The Diagnose of Patient Disease to Make Diagnose history To All patients

DECLARE @res_msg NVARCHAR(200);
EXEC sp_add_diagnose_by_reservation
    @reservation_id = 91676,
    @dig_description = N'Patient shows mild symptoms',
    @msg = @res_msg OUTPUT;
SELECT @res_msg AS ResultMessage;
------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------
-- Doctor Write Prescription To The Patient To Buy Drugs From The Pharmacy

DECLARE @presc_msg NVARCHAR(200);
EXEC sp_add_prescription_by_reservation
    @reservation_id = 91676,
    @notes = N' twice daily',
    @msg = @presc_msg OUTPUT,
    @drug_name='Doxycycline 100mg capsule , Amlodipine 10mg tablet'
-----------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------
-- The Pharmacist Sell Drugs To Patient And Make An Invoice To The Process

DECLARE @Msg NVARCHAR(2000);
DECLARE @Drugs AS PrescriptionDrugInput;
INSERT INTO @Drugs (drug_name, req_qty)
VALUES 
    ('Doxycycline 100mg capsule',3) , ('Amlodipine 10mg tablet',3)

EXEC sp_ProcessPrescriptionSale 
     @PrescriptionID = 91654,
	 @payment_method = 'visa',
     @Drugs = @Drugs,
     @Message = @Msg OUTPUT,
     @emp_id=60
SELECT @Msg AS ResultMessage;
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
-- Buying Low Stock Drugs In Repository

DECLARE @msg NVARCHAR(2000);
EXEC sp_PurchaseAllLowStock @Message = @msg OUTPUT;
SELECT @msg AS Result;
-----------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------
-- When I Want to Know Drugs About to Be Expired 
EXEC sp_ExpiryAlert;
----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
-- Adding New Drug To The System

DECLARE @msg NVARCHAR(500);
EXEC sp_AddDrugPurchase
    @Drug_Name = N'dimra',
	@barcode=6408716337999,
    @Quantity = 100,
    @Unit_Cost = 80,
    @prod_date='2025-10-20',
    @exp_date= '2027-10-23',
    @Message = @msg OUTPUT;
PRINT @msg; 
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
--Reserve Surgery automatically System Handle All Appointments , Rooms And Staffs All Days Except Fridays
-- And Add The Cost , Operating roo and Surgery room In one Invoice

DECLARE @Message NVARCHAR(400);
EXEC sp_surgery_reservation_auto
    @p_id = 11,                 
    @doc_id = 85,               
    @surgery_name = N'Stent',  
	@surgery_date = '2025-12-15',
    @payment_method = N'visa',       
    @Message = @Message OUTPUT;
SELECT @Message AS Result;
-----------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------
-- reserve surgery manually If I Have Emergency Situation

DECLARE @ResultMessage NVARCHAR(400);
EXEC sp_surgery_reservation_manual
    @p_id = 8,                              
    @doc_id = 90,                             
    @surgery_name = N'Appendectomy',
	@surgery_date='2025-12-13',
    @start_time = ' 18:30',       
    @payment_method = N'Cash',              
    @stuff_id = 1,                  
    @Message = @ResultMessage OUTPUT;       
SELECT @ResultMessage AS Message;
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
-- If Patient Cancele The Surgery He Reserved

DECLARE @reservation_id INT = 11031;  
DECLARE @Message NVARCHAR(400);
EXEC sp_cancel_surgery @reservation_id, @Message OUTPUT;
SELECT @Message AS ResultMessage;
-----------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------
-- Room Reservation 

DECLARE @ResultMessage NVARCHAR(200);
EXEC sp_room_reservation     
    @p_id = 30,
    @room_type = 'vip',
    @Message = @ResultMessage OUTPUT;
SELECT @ResultMessage AS Message;
------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------
-- Room Check Out And Calculating Days Of Stay

DECLARE @ResultMessage NVARCHAR(200);
exec sp_room_checkout
   @reservation_id =61121,
    @checkout = '2025-12-15',
    @payment_method = 'visa',
    @Message = @ResultMessage OUTPUT;
SELECT @ResultMessage AS Message;
-------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------
-- patient Reserve Lab Test In Laboratory

DECLARE @msg NVARCHAR(100);
DECLARE @Tests TestListType;

INSERT INTO @Tests (test_name)
VALUES  ('ABG') , ('CBC')

EXEC sp_AddLabReservation
    @p_id = 20,
    @Tests = @Tests,
	@payment_method='visa',
    @msg = @msg OUTPUT;
SELECT @msg AS ResultMessage;
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------
-- Add Result To Lab Tests

DECLARE @R LabResultUpdateType;
INSERT INTO @R (test_name, test_result)
VALUES
    ('CBC', 'Negative'),
    ('ABG', 'Positive');

EXEC sp_UpdateLabResult
    @reservation_id = 38606,
    @Results = @R;
-------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------
---- patient Reserve Rad Test In Radiology

DECLARE @Rads RadioListType;
INSERT INTO @Rads (rad_name)
VALUES ('CAT Scan'), ('MRI'), ('Chest X-ray');

DECLARE @msg NVARCHAR(500);

EXEC sp_AddRadioReservation
    @p_id = 100,
    @payment_method = 'Cash',
    @Rads = @Rads,
    @msg = @msg OUTPUT;
SELECT @msg AS ResultMessage;
---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
-- Add Result To Rad Tests

DECLARE @R RadioResultUpdateType;

INSERT INTO @R (rad_name, test_result)
VALUES
    ('CAT Scan', 'Normal'),
    ('MRI', 'No Bleeding'),
	('Chest X-ray', 'No Bleeding')

EXEC sp_UpdateRadiologyResult
    @reservation_id = 16784,
    @Results = @R;

