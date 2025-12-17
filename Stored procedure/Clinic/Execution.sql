--Exec update patien by ssn
DECLARE @up_msg NVARCHAR(200);

EXEC sp_update_patient_by_ssn
    @ssn = N'25401240818289',
    @email = N'walid.new@gmail.com',
    @phone = N'01121304955',
    @msg = @up_msg OUTPUT;

SELECT @up_msg AS ResultMessage;
-----------------------------------------------------------------------------
--Exec add prescreption to reservation
DECLARE @presc_msg NVARCHAR(200);
EXEC sp_add_prescription_by_reservation
    @reservation_id = 91622,
    @notes = N' twice daily',
    @msg = @presc_msg OUTPUT,
    @drug_name='Doxycycline 100mg capsule'


	select * from Prescription
		select * from Invoice_details


-----------------------------------------------------------------------------------
--Exec add doctor reservation
DECLARE @msg NVARCHAR(200);
EXEC sp_add_doctor_reservation
     @p_id = 1000,
     @dept_id = 3,
     @payment_method = N'visa',
     @msg = @msg OUTPUT;
SELECT @msg AS ResultMessage;

select * from Appointment_reservation

------------------------------------------------------------------------------------
--Exec add diagnose to reservation

DECLARE @res_msg NVARCHAR(200);
EXEC sp_add_diagnose_by_reservation
    @reservation_id = 91617,
    @dig_description = N'Patient shows mild symptoms',
    @msg = @res_msg OUTPUT;
SELECT @res_msg AS ResultMessage;
---------------------------------------------------------------------------------------------
--Exec add new patient
DECLARE @p_id_out INT, @message NVARCHAR(200);
EXEC sp_add_or_get_patient_by_ssn
    @fname = N'Ali',
    @lname = N'mohamed',
    @email = N'ali.mohamed@example.com',
    @birth_date = '1995-05-20',
    @gender = N'male',
    @phone = N'01091165432',
    @ssn = N'22235544455566',
    @out_p_id = @p_id_out OUTPUT,
    @msg = @message OUTPUT;
SELECT @p_id_out AS p_id_result, @message AS message_result;