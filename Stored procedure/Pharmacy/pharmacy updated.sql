CREATE TABLE LowStockAlerts (
    alert_id INT IDENTITY PRIMARY KEY,
    drug_id INT,
    drug_name NVARCHAR(200),
    current_qty INT,
    alert_date DATETIME
);
---------------------------------------------------------------
go
CREATE OR ALTER PROCEDURE sp_ProcessPrescriptionSale
    @PrescriptionID INT,
    @Drugs PrescriptionDrugInput READONLY,
    @payment_method VARCHAR(10) = NULL,
    @Message NVARCHAR(2000) OUTPUT,
    @emp_id INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @Warnings NVARCHAR(MAX) = N'';
        DECLARE @TotalInvoice MONEY = 0;
        DECLARE @invoice_id INT;

        ------------------------------------------------------------------
        -- Checks
        ------------------------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM Prescription WHERE prescription_id = @PrescriptionID)
        BEGIN
            SET @Message = N'Prescription not found.';
            ROLLBACK TRAN;
            RETURN;
        END;

        IF EXISTS (SELECT 1 FROM Prescription_drugs WHERE prescription_id = @PrescriptionID)
        BEGIN
            SET @Message = N'This prescription has already been processed.';
            ROLLBACK TRAN;
            RETURN;
        END;

        ------------------------------------------------------------------
        -- Temp Table
        ------------------------------------------------------------------
        DECLARE @Temp TABLE (
            drug_id INT,
            drug_name NVARCHAR(200),
            req_qty INT,
            orig_qty INT,
            sold_qty INT,
            price MONEY,
            total_price MONEY
        );

        INSERT INTO @Temp (drug_name, req_qty)
        SELECT drug_name, req_qty FROM @Drugs;

        UPDATE T
        SET 
            T.drug_id = P.drug_id,
            T.price = P.price,
            T.orig_qty = P.quantity
        FROM @Temp T
        LEFT JOIN Pharmacy_drugs P 
            ON LOWER(LTRIM(RTRIM(T.drug_name))) = LOWER(LTRIM(RTRIM(P.drug_name)));

        IF EXISTS (SELECT 1 FROM @Temp WHERE drug_id IS NULL)
        BEGIN
            SET @Message = N'One or more drugs not found in inventory.';
            ROLLBACK TRAN;
            RETURN;
        END;

        ------------------------------------------------------------------
        -- Calculate sold quantities
        ------------------------------------------------------------------
        UPDATE T
        SET 
            T.sold_qty = CASE 
                            WHEN orig_qty >= req_qty THEN req_qty
                            WHEN orig_qty > 0 THEN orig_qty
                            ELSE 0 END,
            T.total_price = price * 
                            CASE 
                                WHEN orig_qty >= req_qty THEN req_qty
                                WHEN orig_qty > 0 THEN orig_qty
                                ELSE 0 END
        FROM @Temp T;

        ------------------------------------------------------------------
        -- Insert into Prescription_drugs
        ------------------------------------------------------------------
        INSERT INTO Prescription_drugs (Prescription_id, drug_id, quantity, total_price)
        SELECT @PrescriptionID, drug_id, sold_qty, total_price
        FROM @Temp
        WHERE sold_qty > 0;

        ------------------------------------------------------------------
        -- Deduct from inventory
        ------------------------------------------------------------------
        UPDATE P
        SET P.quantity = P.quantity - T.sold_qty
        FROM Pharmacy_drugs P
        JOIN @Temp T ON P.drug_id = T.drug_id
        WHERE T.sold_qty > 0;

        ------------------------------------------------------------------
        -- UPDATE LowStockAlerts so it stays up-to-date
        ------------------------------------------------------------------
        -- Build source set: only drugs from this sale (use current quantities after deduction)
        ;WITH LowSrc AS (
            SELECT 
                P.drug_id,
                P.drug_name,
                P.quantity AS new_qty
            FROM Pharmacy_drugs P
            WHERE P.drug_id IN (SELECT drug_id FROM @Temp)
        )
        MERGE INTO LowStockAlerts AS L
        USING LowSrc AS S
        ON L.drug_id = S.drug_id
        WHEN MATCHED THEN
            UPDATE SET 
                L.current_qty = S.new_qty,
                L.alert_date = GETDATE()
        WHEN NOT MATCHED THEN
            INSERT (drug_id, drug_name, current_qty, alert_date)
            VALUES (S.drug_id, S.drug_name, S.new_qty, GETDATE());

        -- Remove any alerts for items that are no longer low (qty >= 10)
        DELETE FROM LowStockAlerts
        WHERE drug_id IN (SELECT drug_id FROM @Temp)
          AND drug_id IN (SELECT drug_id FROM Pharmacy_drugs WHERE quantity >= 10);

        ------------------------------------------------------------------
        -- Invoice
        ------------------------------------------------------------------
        SELECT @TotalInvoice = SUM(total_price)
        FROM @Temp WHERE sold_qty > 0;

        IF @TotalInvoice > 0
        BEGIN
            SET @invoice_id = ISNULL((SELECT MAX(invoice_id) FROM Invoice), 0) + 1;

            INSERT INTO Invoice (invoice_id, date, payment_method, paid_money, p_id, emp_id)
            SELECT @invoice_id, GETDATE(), @payment_method, @TotalInvoice, p_id, @emp_id
            FROM Prescription WHERE prescription_id = @PrescriptionID;

            INSERT INTO Invoice_Details (invoice_id, reservation_id, reservation_type, Process_id, unit_price, quantity, total, dept_id)
            SELECT
                @invoice_id,
                @PrescriptionID,
                'Pharmacy',
                drug_id,
                price,
                sold_qty,
                total_price,
                12
            FROM @Temp
            WHERE sold_qty > 0;
        END;

        ------------------------------------------------------------------
        -- Build final message
        ------------------------------------------------------------------
        DECLARE @StockInfo NVARCHAR(MAX) = N'';

        SELECT @StockInfo += 
               N'• ' + T.drug_name + N': ' + CAST(P.quantity AS NVARCHAR) + CHAR(13)
        FROM @Temp T
        JOIN Pharmacy_drugs P ON T.drug_id = P.drug_id;

        SET @Message =
            N'Sale completed successfully.' + CHAR(13) +
            N'Total Invoice Amount: ' + CAST(ISNULL(@TotalInvoice, 0) AS NVARCHAR) + CHAR(13) +
            N'Remaining Stock:' + CHAR(13) + @StockInfo;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        SET @Message = N'Error: ' + ERROR_MESSAGE();
    END CATCH
END;
GO

--------------------------------------------------------
------------------------------------------------------
---------------------------------------------------
---------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_PurchaseAllLowStock
    @Message NVARCHAR(2000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        -- Table variable to capture purchases for reporting
        DECLARE @PurchaseLog TABLE (
            drug_name NVARCHAR(200),
            added_qty INT,
            unit_cost MONEY,
            total MONEY
        );

        --------------------------------------------------------------------
        -- 1) جلب كل الأدوية اللي مخزونها منخفض (<10)
        --------------------------------------------------------------------
        IF NOT EXISTS (SELECT 1 FROM LowStockAlerts)
        BEGIN
            SET @Message = N'No low-stock drugs found. Nothing to purchase.';
            ROLLBACK TRAN;
            RETURN;
        END;

        --------------------------------------------------------------------
        -- 2) تنفيذ عملية الشراء + التحديث في جدول المخزون
        --------------------------------------------------------------------
        INSERT INTO drug_purchases (drug_name, quantity, unit_cost, purchase_date, total)
        OUTPUT inserted.drug_name, inserted.quantity, inserted.unit_cost, inserted.total
        INTO @PurchaseLog (drug_name, added_qty, unit_cost, total)
        SELECT 
            L.drug_name,
            50 AS quantity,
            ROUND(P.price * 0.7, 2) AS unit_cost,
            GETDATE() AS purchase_date,
            50 * ROUND(P.price * 0.7, 2) AS total
        FROM LowStockAlerts L
        JOIN Pharmacy_drugs P ON L.drug_id = P.drug_id;

        --------------------------------------------------------------------
        -- 3) تحديث كمية المخزون في Pharmacy_drugs
        --------------------------------------------------------------------
        UPDATE P
        SET P.quantity = P.quantity + 50
        FROM Pharmacy_drugs P
        JOIN LowStockAlerts L ON P.drug_id = L.drug_id;

        --------------------------------------------------------------------
        -- 4) مسح جدول LowStockAlerts بالكامل
        --------------------------------------------------------------------
        DELETE FROM LowStockAlerts;

        --------------------------------------------------------------------
        -- 5) إعادة ترقيم الـ Identity ليبدأ من 1
        --------------------------------------------------------------------
        DBCC CHECKIDENT ('LowStockAlerts', RESEED, 0);

        --------------------------------------------------------------------
        -- 6) تجهيز رسالة نهائية
        --------------------------------------------------------------------
        DECLARE @Msg NVARCHAR(MAX) = N'Purchase completed successfully:' + CHAR(13) + CHAR(13);

        SELECT 
            @Msg += N'• ' + drug_name
                + N' | Purchased: 50'
                + N' | Unit Cost: ' + CAST(unit_cost AS NVARCHAR)
                + N' | Total: ' + CAST(total AS NVARCHAR)
                + CHAR(13)
        FROM @PurchaseLog;

        SET @Message = @Msg;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        SET @Message = N'Error: ' + ERROR_MESSAGE();
    END CATCH
END;
GO
---------------------------------------------------------------------------------
--------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_AddDrugPurchase
    @Drug_Name NVARCHAR(100),
	@barcode NVARCHAR(50),
    @Quantity INT,
    @Unit_Cost MONEY,
    @prod_date date,
    @exp_date DATE,
    @Message NVARCHAR(2000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- ✅ لو الدواء موجود بالفعل في الصيدلية
    IF EXISTS (SELECT 1 FROM Pharmacy_drugs WHERE LOWER(drug_name) = LOWER(@Drug_Name))
    BEGIN
        SET @Message = N'⚠ The drug "' + @Drug_Name + N'" already exists in the pharmacy.';
        RETURN;
    END;

    -- ✅ إدخال في جدول المشتريات بتاريخ اليوم تلقائيًا
    INSERT INTO Drug_Purchases (Drug_Name, Quantity, Unit_Cost, Purchase_Date,total)
    VALUES (@Drug_Name, @Quantity, @Unit_Cost, GETDATE(),@Quantity*@Unit_Cost);

    -- ✅ إدخال الدواء في جدول الصيدلية
    DECLARE @NewDrugID INT;
    SELECT @NewDrugID = ISNULL(MAX(drug_id), 0) + 1 FROM Pharmacy_drugs;

    INSERT INTO Pharmacy_drugs (drug_id, drug_name,barcode, quantity, price ,prod_date , exp_date)
    VALUES (@NewDrugID, @Drug_Name,@barcode, @Quantity, @Unit_Cost * 1.3 , @prod_date, @exp_date);

    SET @Message = 
        N'✅ Drug "' + @Drug_Name + N'" added successfully.' + CHAR(13) +
        N'Quantity: ' + CAST(@Quantity AS NVARCHAR) + CHAR(13) +
        N'Purchase Price: ' + CAST(@Unit_Cost AS NVARCHAR) + CHAR(13) +
        N'Selling Price (approx): ' + CAST(@Unit_Cost * 1.3 AS NVARCHAR) + CHAR(13) +
        N'Purchase Date: ' + CONVERT(NVARCHAR(20), GETDATE(), 103); -- 📅 عرض التاريخ
END;
GO 
-------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE sp_ExpiryAlert
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        drug_id,
        drug_name,
        quantity,
        exp_date,
        DATEDIFF(DAY, GETDATE(), exp_date) AS Days_to_Expire
    FROM Pharmacy_drugs
    WHERE exp_date <= DATEADD(MONTH, 3, GETDATE())
          AND exp_date >= GETDATE()
    ORDER BY exp_date;
END

