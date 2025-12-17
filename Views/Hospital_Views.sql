
--------------------------------------------------
--  View 1: Patient Basic Info
--------------------------------------------------
CREATE OR ALTER VIEW vw_PatientBasicInfo AS
SELECT 
    p.p_id,
    p.fname + ' ' + p.lname AS full_name,
    p.email,
    p.phone,
    p.gender,
    p.birth_date,
    p.ssn
FROM Patient p;
GO

-- Test
SELECT TOP 10 * FROM vw_PatientBasicInfo;
GO

--------------------------------------------------
--  View 2: Doctor Schedule
--------------------------------------------------
CREATE OR ALTER VIEW vw_DoctorSchedule AS
SELECT 
    d.id AS doctor_appointment_id,
    e.emp_id AS doctor_id,
    e.fname + ' ' + e.lname AS doctor_name,
    d.day,
    d.shift_start,
    d.shift_end,
    d.examination_price,
    dept.dept_id,
    dept.dept_name
FROM Doctor_appointments d
JOIN Employee e ON d.emp_id = e.emp_id
JOIN Department dept ON d.dept_id = dept.dept_id;
GO

-- Test
SELECT TOP 10 * FROM vw_DoctorSchedule;
GO

--------------------------------------------------
--  View 3: Reservations Full
--------------------------------------------------
CREATE OR ALTER VIEW vw_ReservationsFull AS
SELECT 
    r.reservation_id,
    r.date_time,
    p.fname + ' ' + p.lname AS patient_name,
    d.fname + ' ' + d.lname AS doctor_name,
    rec.fname + ' ' + rec.lname AS receptionist_name,
    dept.dept_name,
    r.paid_money
FROM appointment_reservation r
JOIN Patient p ON r.p_id = p.p_id
JOIN Employee d ON r.doctor_id = d.emp_id
JOIN Employee rec ON r.receptionist_id = rec.emp_id
JOIN Department dept ON r.dept_id = dept.dept_id;
GO

-- Test
SELECT TOP 10 * FROM vw_ReservationsFull;
GO

--------------------------------------------------
--  View 4: Invoices Full
--------------------------------------------------
CREATE OR ALTER VIEW vw_InvoicesFull AS
SELECT 
    i.invoice_id,
    i.reservation_id,
    i.reservation_type,
    i.date,
    i.payment_method,
    i.paid_money,
    p.fname + ' ' + p.lname AS patient_name,
    e.fname + ' ' + e.lname AS employee_name
FROM Invoice i
JOIN Patient p ON i.p_id = p.p_id
JOIN Employee e ON i.emp_id = e.emp_id;
GO

-- Test
SELECT TOP 10 * FROM vw_InvoicesFull;
GO

--------------------------------------------------
-- View 5: Revenue By Department
--------------------------------------------------
CREATE OR ALTER VIEW vw_RevenueByDepartment AS
SELECT 
    dept.dept_name,
    SUM(i.paid_money) AS total_revenue
FROM Invoice i
JOIN Employee e ON i.emp_id = e.emp_id
JOIN Department dept ON e.dept_id = dept.dept_id
GROUP BY dept.dept_name;
GO

-- Test
SELECT * FROM vw_RevenueByDepartment;
GO

--------------------------------------------------
--  View 6: Top Doctors
--------------------------------------------------
CREATE VIEW vw_TopDoctors AS
SELECT TOP 5
    e.emp_id,
    e.fname + ' ' + e.lname AS doctor_name,
    d.dept_name,
    COUNT(r.reservation_id) AS total_appointments,
    SUM(i.paid_money) AS total_revenue
FROM employee e
JOIN department d ON e.dept_id = d.dept_id
JOIN appointment_reservation r ON e.emp_id = r.doctor_id
JOIN invoice i ON r.reservation_id = i.reservation_id
WHERE e.type = 'Doctor'
GROUP BY e.emp_id, e.fname, e.lname, d.dept_name
ORDER BY total_appointments DESC;


-- Test
SELECT TOP 5 * FROM vw_TopDoctors
GO

--------------------------------------------------
--  View 7: Monthly New Patients
--------------------------------------------------

CREATE OR ALTER VIEW vw_MonthlyNewPatients AS
SELECT TOP 5
    FORMAT(r.date_time, 'yyyy-MM') AS month,
    COUNT(DISTINCT r.p_id) AS new_patients
FROM appointment_reservation r
GROUP BY FORMAT(r.date_time, 'yyyy-MM')
ORDER BY new_patients DESC;  -- ترتيب تنازلي حسب عدد المرضى الجدد
GO

-- Test
SELECT * FROM vw_MonthlyNewPatients;
GO
