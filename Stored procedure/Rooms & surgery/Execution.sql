--Reserve Surgery automatically EXEC
DECLARE @Message NVARCHAR(400);
EXEC sp_surgery_reservation_auto
    @p_id = 10,                 
    @doc_id = 84,               
    @surgery_name = N'Ocular foreign body removal',  
	@surgery_date = '2025-12-10',
    @payment_method = N'visa',       
    @Message = @Message OUTPUT;
SELECT @Message AS Result;
-------------------------------------------------------------------------------------------------------------
-- reserve surgery manually EXEC
DECLARE @ResultMessage NVARCHAR(400);
EXEC sp_surgery_reservation_manual
    @p_id = 8,                              
    @doc_id = 90,                             
    @surgery_name = N'Appendectomy',
	@surgery_date='2025-12-08',
    @start_time = ' 18:30',       
    @payment_method = N'Cash',              
    @stuff_id = 1,                  
    @Message = @ResultMessage OUTPUT;       
SELECT @ResultMessage AS Message;


--------------------------------------------------------------------------------------------------------------
--Cancel Surgery EXEC

DECLARE @reservation_id INT = 11016;  
DECLARE @Message NVARCHAR(400);
EXEC sp_cancel_surgery @reservation_id, @Message OUTPUT;
SELECT @Message AS ResultMessage;

-------------------------------------------
-- ✅ exec Procedure: sp_insert_room
-------------------------------------------
DECLARE @ResultMessage NVARCHAR(200);
exec sp_insert_room   
    @room_type ='icu',
    @Message = @ResultMessage OUTPUT;
SELECT @ResultMessage AS Message;

-----------------------------------------------------------------------------------------------------------------------------
-------------------------------------------
-- ✅ test Procedure: sp_update_room
-------------------------------------------
go
DECLARE @ResultMessage NVARCHAR(200);
exec  sp_update_room 20,'Normal' ,
    @Message = @ResultMessage OUTPUT;
SELECT @ResultMessage AS Message;

---------------------------------------------------------------------------------------------------------------------
-------------------------------------------
-- ✅ test procedure : sp_room_reservation
-------------------------------------------
go
DECLARE @ResultMessage NVARCHAR(200);
EXEC sp_room_reservation     
    @p_id = 30,
    @room_type = 'normal',
    @Message = @ResultMessage OUTPUT;
SELECT @ResultMessage AS Message;

select * from Room_reservation
select * from Invoice_details

-----------------------------------------------------------------------------------------------------------------
-------------------------------------------
-- ✅ test Procedure: sp_room_checkout
-------------------------------------------
go
DECLARE @ResultMessage NVARCHAR(200);
exec sp_room_checkout
   @reservation_id =61097,
    @checkout = '2025-12-10',
    @payment_method = 'visa',
    @Message = @ResultMessage OUTPUT;
SELECT @ResultMessage AS Message;