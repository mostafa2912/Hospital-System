--Exec add doctor reservation
DECLARE @msg NVARCHAR(200);
EXEC sp_add_doctor_reservation
     @p_id = 160,
     @dept_id = 1,
     @payment_method = N'visa',
     @msg = @msg OUTPUT;
SELECT @msg AS ResultMessage;

select * from Appointment_reservation
--------------------------------------------------
--Exec add prescreption to reservation
DECLARE @presc_msg NVARCHAR(200);
EXEC sp_add_prescription_by_reservation
    @reservation_id = 91674,
    @notes = N' twice daily',
    @msg = @presc_msg OUTPUT,
    @drug_name='Amlodipine 10mg tablet'

	select * from Prescription_drugs
------------------------------------------------------
DECLARE @Msg NVARCHAR(2000);
DECLARE @Drugs AS PrescriptionDrugInput;
INSERT INTO @Drugs (drug_name, req_qty)
VALUES 
    ('Amlodipine 10mg tablet',3) 

EXEC sp_ProcessPrescriptionSale 
     @PrescriptionID = 91652,
	 @payment_method = 'visa',
     @Drugs = @Drugs,
     @Message = @Msg OUTPUT,
     @emp_id=60
SELECT @Msg AS ResultMessage;

select * from Prescription_drugs
select * from Invoice_details
select * from Drug_Purchases
---------------------------------------------------------------------
DECLARE @msg NVARCHAR(2000);
EXEC sp_PurchaseAllLowStock @Message = @msg OUTPUT;
SELECT @msg AS Result;
---------------------------------------------------------------------
-- Exec sp_AddDrugPurchase
DECLARE @msg NVARCHAR(500);

EXEC sp_AddDrugPurchase
    @Drug_Name = N'sulfax',
	@barcode=6408716337145,
    @Quantity = 20,
    @Unit_Cost = 180,
    @prod_date='2025-10-20',
    @exp_date= '2027-10-23',
    @Message = @msg OUTPUT;
PRINT @msg; 

select * from Pharmacy_drugs
where drug_name='sulfax'
----------------------------------------------------------------------------
EXEC sp_ExpiryAlert;
