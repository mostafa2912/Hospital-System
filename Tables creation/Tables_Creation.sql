
-- Patient
CREATE TABLE Patient (
    p_id INT IDENTITY(1,1) PRIMARY KEY,
    fname NVARCHAR(50) NOT NULL,
    lname NVARCHAR(50) NOT NULL,
    email NVARCHAR(100) UNIQUE,
    birth_date DATE NOT NULL,
    gender varCHAR(10) NOT NULL CHECK (gender IN ('male','female')),
    phone NVARCHAR(15) UNIQUE,
	ssn varchar(15) unique
)

-- Employee
CREATE TABLE Employee (
    emp_id INT PRIMARY KEY,
    fname NVARCHAR(50) NOT NULL,
    lname NVARCHAR(50) NOT NULL,
	email NVARCHAR(100) UNIQUE,
	birth_date DATE NOT NULL,
    gender varCHAR(10) NOT NULL CHECK (gender IN ('male','female')),
    phone NVARCHAR(15) UNIQUE,
	ssn varchar(15) unique,
	job_title varchar(30) ,
    start_job DATE NOT NULL DEFAULT GETDATE(),
    end_job DATE NULL,
	status varchar(20) NOT NULL DEFAULT 'active',
    salary DECIMAL(10,2) NOT NULL CHECK (salary >= 0), type NVARCHAR(50) NOT NULL,
    dept_id INT NULL,
    FOREIGN KEY (dept_id) REFERENCES Department(dept_id) ON DELETE SET NULL,
)
alter table employee
add end_job DATE NULL
alter table employee
drop column type
ALTER TABLE Employee
ADD 
    start_job DATE NOT NULL DEFAULT GETDATE(),
    end_job DATE NULL,
    status VARCHAR(10) NOT NULL DEFAULT 'active';


alter EmpCTE
WITH EmpCTE AS (
    SELECT emp_id,
           ROW_NUMBER() OVER (ORDER BY emp_id) AS rn
    FROM Employee
)
UPDATE e
SET start_job = DATEADD(DAY, -((rn - 1) % 10), CAST(GETDATE() AS DATE))
FROM Employee e
INNER JOIN EmpCTE cte ON e.emp_id = cte.emp_id;

WITH EmpCTE AS (
    SELECT emp_id,
           ROW_NUMBER() OVER (ORDER BY emp_id) AS rn
    FROM Employee
)
UPDATE e
SET start_job = DATEADD(DAY, -((rn - 1) % 10), CAST(GETDATE() AS DATE))
FROM Employee e
INNER JOIN EmpCTE cte ON e.emp_id = cte.emp_id;




-- Department
CREATE TABLE Department (
    dept_id INT PRIMARY KEY,
    dept_name NVARCHAR(100) NOT NULL
)
alter table department 
add manager_id  int
add constraint manager_id  FOREIGN KEY (manager_id) REFERENCES Employee(emp_id) 

-- Surgery
CREATE TABLE Surgery (
    surgery_id INT PRIMARY KEY,
    surgery_name NVARCHAR(100) NOT NULL,
    duration INT NOT NULL CHECK (duration > 0),
    price DECIMAL(10,2) NOT NULL CHECK (price >= 0)
)

-- Surgery_reservation

CREATE TABLE Surgery_reservation (
    reservation_id INT IDENTITY(1,1) PRIMARY KEY,
    surgery_date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    paid_money DECIMAL(10,2) DEFAULT 0 CHECK (paid_money >= 0),
    p_id INT NOT NULL,
    doctor_id INT NOT NULL,
    receptionist_id INT NOT NULL,
    surgery_id INT NOT NULL,
    room_id INT NOT NULL,
    stuff_id INT NOT NULL,
    FOREIGN KEY (p_id) REFERENCES Patient(p_id),
    FOREIGN KEY (doctor_id) REFERENCES Employee(emp_id),
    FOREIGN KEY (receptionist_id) REFERENCES Employee(emp_id),
    FOREIGN KEY (surgery_id) REFERENCES Surgery(surgery_id),
    FOREIGN KEY (room_id) REFERENCES Room(room_id),
    FOREIGN KEY (stuff_id) REFERENCES Stuff(stuff_id)
);

CREATE TABLE Stuff (
    Stuff_ID INT IDENTITY(1,1) PRIMARY KEY,
    Stuff_Name NVARCHAR(100) NOT NULL,
);

CREATE TABLE Stuff_emp (
    stuff_id INT,
    emp_id INT,
    PRIMARY KEY (stuff_id, emp_id),
    FOREIGN KEY (stuff_id) REFERENCES Employee(emp_id),
    FOREIGN KEY (emp_id) REFERENCES Employee(emp_id)
)

INSERT INTO Stuff (Stuff_Name)
VALUES 
('Surgery Team 1'),
('Surgery Team 2'),
('Surgery Team 3'),
('Surgery Team 4'),
('Surgery Team 5'),
('Surgery Team 6')

-- Room
CREATE TABLE Room (
    room_id INT IDENTITY(1,1) PRIMARY KEY,
    room_type NVARCHAR(50) NOT NULL CHECK (room_type IN ('ICU','Normal','Emergency','Surgery')),
    price_per_day DECIMAL(10,2) NOT NULL CHECK (price_per_day >= 0)
)
-- Room_reservation
CREATE TABLE Room_reservation (
    reservation_id INT IDENTITY(1,1) PRIMARY KEY,
    paid_money DECIMAL(10,2) DEFAULT 0 CHECK (paid_money >= 0),
    checkin DATE NULL,
    checkout DATE  NULL,
    p_id INT NOT NULL,
    room_id INT NOT NULL,
    emp_id INT NOT NULL,
    FOREIGN KEY (p_id) REFERENCES Patient(p_id),
    FOREIGN KEY (room_id) REFERENCES Room(room_id),
    FOREIGN KEY (emp_id) REFERENCES Employee(emp_id),
    CONSTRAINT chk_room_dates CHECK (checkout > checkin)
)
alter table Room_reservation
drop constraint chk_room_dates

ALTER TABLE Room_reservation
ALTER COLUMN checkin DATETIME;
ALTER TABLE Room_reservation
ALTER COLUMN checkout DATETIME;


CREATE TABLE Room_Status (
    room_id INT PRIMARY KEY,
    status NVARCHAR(20) CHECK (status IN ('Available', 'Reserved', 'Maintenance')) DEFAULT 'Available',
    FOREIGN KEY (room_id) REFERENCES Room(room_id)
);

INSERT INTO Room_Status (room_id, status)
SELECT room_id, 'available'
FROM Room
------------------------------------------------------------------------------------------------------------------------------------------------
-- Lab_tests
CREATE TABLE Lab_tests (
    test_id INT PRIMARY KEY,
    test_name NVARCHAR(100) NOT NULL,
    delivery_duration INT NOT NULL,
    price DECIMAL(10,2) NOT NULL CHECK (price >= 0)
)


-- Lab_reservation
CREATE TABLE Lab_reservation (
    reservation_id INT IDENTITY(1,1) PRIMARY KEY,
	test_name varchar(50),
    date DATE NOT NULL DEFAULT GETDATE(),
    paid_money DECIMAL(10,2) DEFAULT 0 CHECK (paid_money >= 0),
    p_id INT NOT NULL,
    lab_doctor_id INT NOT NULL,
    emp_id INT NOT NULL,
    FOREIGN KEY (p_id) REFERENCES Patient(p_id),
    FOREIGN KEY (emp_id) REFERENCES Employee(emp_id),
	FOREIGN KEY (lab_doctor_id) REFERENCES Employee(emp_id)
)

CREATE TABLE Test_reserve (
    test_id INT,
    reservation_id INT,
    test_result NVARCHAR(255),
    PRIMARY KEY (test_id, reservation_id),
    FOREIGN KEY (test_id) REFERENCES Lab_tests(test_id) ,
    FOREIGN KEY (reservation_id) REFERENCES Lab_reservation(reservation_id) on delete cascade on update cascade
)

-- Radiology
CREATE TABLE Radiology (
    rad_id INT PRIMARY KEY,
    rad_name NVARCHAR(100) NOT NULL,
    delivery_duration INT NOT NULL CHECK (delivery_duration > 0),
    price DECIMAL(10,2) NOT NULL CHECK (price >= 0)
)

-- Radio_reservation
CREATE TABLE Radio_reservation (
    reservation_id INT IDENTITY(1,1) PRIMARY KEY,
	rad_name varchar(50),
    date DATE NOT NULL DEFAULT GETDATE(),
    paid_money DECIMAL(10,2) DEFAULT 0 CHECK (paid_money >= 0),
    p_id INT NOT NULL,
    emp_id INT NOT NULL,
    rad_doctor_id int NOT NULL,
    FOREIGN KEY (p_id) REFERENCES Patient(p_id),
    FOREIGN KEY (emp_id) REFERENCES Employee(emp_id),
	FOREIGN KEY (rad_doctor_id) REFERENCES Employee(emp_id)
)

CREATE TABLE Rad_reserve (
    rad_id INT,
    reservation_id INT,
    test_result NVARCHAR(255),
    PRIMARY KEY (rad_id, reservation_id),
    FOREIGN KEY (rad_id) REFERENCES Radiology(rad_id),
    FOREIGN KEY (reservation_id) REFERENCES Radio_reservation(reservation_id) on delete cascade on update cascade
)

-- Doctor_appointments
CREATE TABLE Doctor_appointments (
    id INT PRIMARY KEY,
    examination_price int NOT NULL CHECK (examination_price >= 0),
    day NVARCHAR(20) NOT NULL,
    shift_start TIME NOT NULL,
    shift_end TIME NOT NULL,
    emp_id INT NOT NULL,
    dept_id INT NOT NULL,
	max_patients_perday int ,
    FOREIGN KEY (dept_id) REFERENCES Department(dept_id),
    FOREIGN KEY (emp_id) REFERENCES Employee(emp_id),
    CONSTRAINT chk_shift_time CHECK (shift_end > shift_start)
)
alter table Doctor_appointments 
drop column max_patients_perday

update Doctor_appointments
set examination_price = 1000
where dept_id in (8,9) 

update Doctor_appointments
set examination_price = 500
where dept_id in (2,3,5,6) 

update Doctor_appointments
set examination_price = 800
where dept_id in (1,4,7) 


-- Appointment_reservation
CREATE TABLE Appointment_reservation (
    reservation_id  INT IDENTITY(1,1) PRIMARY KEY,
    date_time DATETIME NOT NULL DEFAULT GETDATE(),
    paid_money DECIMAL(10,2) DEFAULT 0 CHECK (paid_money >= 0),
	payment_method varchar(20),
    p_id INT NOT NULL,
    dept_id INT NOT NULL,
    emp_id INT NOT NULL,
    id int not null,
    FOREIGN KEY (p_id) REFERENCES Patient(p_id),
    FOREIGN KEY (dept_id) REFERENCES Department(dept_id),
    FOREIGN KEY (id) REFERENCES Doctor_appointments(id)
);

--shift
CREATE TABLE shift (
    shift_id INT primary key,
    shift_name varchar(30)
    
)

-- Shift_appointment
CREATE TABLE Shift_appointment (
    shift_id INT ,
    shift_type NVARCHAR(50) NOT NULL,
	date date NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
	primary key( shift_id , date)
)


-- Diagnose_history
CREATE TABLE Diagnose_history (
    dig_id INT identity(1,1) PRIMARY KEY,
    dig_description NVARCHAR(MAX) NOT NULL,
    p_id INT NOT NULL,
    emp_id INT NOT NULL,
    FOREIGN KEY (p_id) REFERENCES Patient(p_id),
    FOREIGN KEY (emp_id) REFERENCES Employee(emp_id)
)

-- Prescription
CREATE TABLE Prescription (
    prescription_id INT identity(1,1)  PRIMARY KEY,
    date DATE NOT NULL DEFAULT GETDATE(),
    notes NVARCHAR(MAX),
    p_id INT NOT NULL,
    reservation_id INT NOT NULL,
    FOREIGN KEY (p_id) REFERENCES Patient(p_id),
    FOREIGN KEY (reservation_id) REFERENCES Appointment_reservation(reservation_id)
)



-- Pharmacy_drugs
CREATE TABLE Pharmacy_drugs (
    drug_id INT PRIMARY KEY,
    drug_name NVARCHAR(100) NOT NULL,
    barcode NVARCHAR(50) UNIQUE,
    quantity INT NOT NULL CHECK (quantity >= 0),
    exp_date DATE NOT NULL,
    prod_date DATE NOT NULL,
    price DECIMAL(10,2) NOT NULL CHECK (price >= 0),
    CONSTRAINT chk_dates CHECK (exp_date > prod_date)
)

CREATE TABLE Prescription_drugs (
    prescription_id INT,
    drug_id INT,
	quantity int,
	total_price int,
    FOREIGN KEY (prescription_id) REFERENCES Prescription(prescription_id),
    FOREIGN KEY (drug_id) REFERENCES Pharmacy_drugs(drug_id)
)
update Doctor_appointments
set examination_price = 1000
where dept_id in (8,9) 

update Doctor_appointments
set examination_price = 500
where dept_id in (2,3,5,6) 

update Doctor_appointments
set examination_price = 800
where dept_id in (1,4,7) 

-- Invoice
CREATE TABLE Invoice (
   invoice_id INT PRIMARY KEY,
    date DATE NOT NULL DEFAULT GETDATE(),
    paid_money DECIMAL(10,2) DEFAULT 0 CHECK (paid_money >= 0),
    payment_method NVARCHAR(50) NOT NULL,
    p_id INT NOT NULL,
    emp_id INT NOT NULL,
    FOREIGN KEY (p_id) REFERENCES Patient(p_id),
    FOREIGN KEY (emp_id) REFERENCES Employee(emp_id)
)
-- Invoice details
CREATE TABLE Invoice_details (
    invoice_details_id INT PRIMARY KEY,
    invoice_id int not null,
    reservation_id INT NOT NULL,
    reservation_type NVARCHAR(50) NOT NULL,
    Process_id int not null ,
    unit_price decimal(10,2),
    quantity int ,
    FOREIGN KEY (invoice_id) REFERENCES Invoice(invoice_id)
)





CREATE TABLE Emp_shift (
    emp_id INT,
    shift_id INT,
    PRIMARY KEY (emp_id, shift_id),
    FOREIGN KEY (emp_id) REFERENCES Employee(emp_id),
    FOREIGN KEY (shift_id) REFERENCES Shift(shift_id)
)


-- Attendance

create table Attendance (
  attend_id INT IDENTITY(1,1) PRIMARY KEY,
  emp_id INT NOT NULL,
  checkin DATETIME not null,
  checkout DATETIME DEFAULT NULL,
  attend_date DATE NOT NULL,
  CONSTRAINT chk_checkout CHECK (checkout IS NULL OR checkout > checkin),            
  CONSTRAINT UQ_Attendance UNIQUE (emp_id, attend_date),
  CONSTRAINT FK_Attendance_Employee FOREIGN KEY (emp_id) REFERENCES Employee(emp_id)

)


--salary
CREATE TABLE Salary (
    id INT IDENTITY(1,1) PRIMARY KEY,
    emp_id INT NOT NULL,
    salary DECIMAL(18,2) NOT NULL,
    Total_reward DECIMAL(18,2) DEFAULT 0,
    Total_deduction DECIMAL(18,2) DEFAULT 0,
    date DATE NOT NULL,  -- يمثل بداية الشهر
    CONSTRAINT FK_Salary_Employee FOREIGN KEY (emp_id) REFERENCES Employee(emp_id),
    CONSTRAINT UQ_Salary_Emp_Date UNIQUE (emp_id, date)  -- لضمان تسجيل كل موظف مرة واحدة لكل شهر
);


--duduction
CREATE TABLE Deduction (
    Ded_id INT IDENTITY(1,1) PRIMARY KEY,
    emp_id INT NOT NULL,
    Ded_type NVARCHAR(100) NOT NULL,  -- نوع الخصم مثل تأخير، غياب، إلخ
    date DATE NOT NULL,               -- تاريخ الخصم
    amount DECIMAL(18,2) NOT NULL CHECK (amount >= 0),  -- مبلغ الخصم، لا يمكن أن يكون سالب
    CONSTRAINT FK_Deduction_Employee FOREIGN KEY (emp_id) REFERENCES Employee(emp_id)
);


--reward
CREATE TABLE Reward (
    Reward_id INT IDENTITY(1,1) PRIMARY KEY,
    emp_id INT NOT NULL,
    Reward_type NVARCHAR(100) NOT NULL,  -- نوع المكافأة مثل مكافأة أداء، حوافز، إلخ
    date DATE NOT NULL,                  -- تاريخ المكافأة
    amount DECIMAL(18,2) NOT NULL CHECK (amount >= 0),  -- مبلغ المكافأة، لا يمكن أن يكون سالب
    CONSTRAINT FK_Reward_Employee FOREIGN KEY (emp_id) REFERENCES Employee(emp_id)
);

--Expenses
CREATE TABLE Expenses (
    id INT IDENTITY(1,1) PRIMARY KEY,
    [date] DATE NOT NULL,
    Expense_id int ,
    FOREIGN KEY (Expense_id) REFERENCES Expenses_Type (Expense_id)

);

CREATE TABLE Expenses_Type(
    Expense_id INT IDENTITY(1,1) PRIMARY KEY,
    Expense_type NVARCHAR(100) NOT NULL
    )

 insert into Expenses_Type ( Expense_type)
 values ('gas'),
 ('water'),
 ('electricity'),
 ('internet'),
 ('lab_tools'),
 ('rad_tools'),
 ('room_tools'),
 ('Pharmacy')
 


--Drug_Purchases
CREATE TABLE Drug_Purchases (
    Purchase_ID INT IDENTITY PRIMARY KEY,
    Drug_Name NVARCHAR(100) NOT NULL,
    Quantity INT NOT NULL,
    Unit_Cost DECIMAL(10,2) NOT NULL,
    Purchase_Date DATE DEFAULT GETDATE()
);
