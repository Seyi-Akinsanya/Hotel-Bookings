USE PortfolioProjects

DROP PROCEDURE IF EXISTS Create_Hotel_Bookings_Star_Schema
GO

CREATE PROCEDURE Create_Hotel_Bookings_Star_Schema
AS
BEGIN

    -- Source table cleaning and preparation

--- Add arrival and booking date fields for future analysis

ALTER TABLE hotel_bookings 
DROP COLUMN arrival_date, booking_date;

ALTER TABLE hotel_bookings
ADD arrival_date DATE;

ALTER TABLE hotel_bookings
ADD booking_date DATE;

UPDATE hotel_bookings
SET arrival_date = CAST(
    CAST(arrival_date_year AS VARCHAR) + '-' + 
    CASE arrival_date_month
        WHEN 'January' THEN '01'
        WHEN 'February' THEN '02'
        WHEN 'March' THEN '03'
        WHEN 'April' THEN '04'
        WHEN 'May' THEN '05'
        WHEN 'June' THEN '06'
        WHEN 'July' THEN '07'
        WHEN 'August' THEN '08'
        WHEN 'September' THEN '09'
        WHEN 'October' THEN '10'
        WHEN 'November' THEN '11'
        WHEN 'December' THEN '12'
    END + '-' + 
    RIGHT('0' + CAST(arrival_date_day_of_month AS VARCHAR), 2) 
    AS DATE);

UPDATE hotel_bookings
SET booking_date = DATEADD(DAY, -lead_time, arrival_date);

--- Clean Agent and Company columns
UPDATE hotel_bookings
SET agent = NULL
WHERE agent = 'NULL';

UPDATE hotel_bookings
SET company = NULL
WHERE company = 'NULL';

ALTER TABLE hotel_bookings 
ALTER COLUMN agent INT;

ALTER TABLE hotel_bookings 
ALTER COLUMN company INT;

    -- Drop Fact Table First to Avoid Foreign Key Conflicts
    DROP TABLE IF EXISTS dbo.Fact_Bookings;

    -- Drop Dimension Tables
    DROP TABLE IF EXISTS dbo.Dim_Meals;
    DROP TABLE IF EXISTS dbo.Dim_Customer_Properties;
    DROP TABLE IF EXISTS dbo.Dim_Customer_Type;
    DROP TABLE IF EXISTS dbo.Dim_Country;

    -- Create Dim_Meals Table
    CREATE TABLE dbo.Dim_Meals (
        meal_id INT IDENTITY(1,1) PRIMARY KEY,
        meal VARCHAR(255) UNIQUE
    );

    -- Insert Distinct Meals
    INSERT INTO dbo.Dim_Meals (meal)
    SELECT DISTINCT meal FROM dbo.hotel_bookings WHERE meal IS NOT NULL;

    -- Create Dim_Customer_Properties Table
    CREATE TABLE dbo.Dim_Customer_Properties (
        customer_properties_id INT IDENTITY(1,1) PRIMARY KEY,
        market_segment VARCHAR(255),
        distribution_channel VARCHAR(255),
        UNIQUE (market_segment, distribution_channel)
    );

    -- Insert Distinct Customer Properties
    INSERT INTO dbo.Dim_Customer_Properties (market_segment, distribution_channel)
    SELECT DISTINCT market_segment, distribution_channel 
    FROM dbo.hotel_bookings 
    WHERE market_segment IS NOT NULL AND distribution_channel IS NOT NULL;

    -- Create Dim_Customer_Type Table
    CREATE TABLE dbo.Dim_Customer_Type (
        customer_type_id INT IDENTITY(1,1) PRIMARY KEY,
        customer_type VARCHAR(255) UNIQUE
    );

    -- Insert Distinct Customer Types
    INSERT INTO dbo.Dim_Customer_Type (customer_type)
    SELECT DISTINCT customer_type FROM dbo.hotel_bookings WHERE customer_type IS NOT NULL;

    -- Create Dim_Country Table
    CREATE TABLE dbo.Dim_Country (
        country_id INT IDENTITY(1,1) PRIMARY KEY,
        country VARCHAR(255) UNIQUE
    );

    -- Insert Distinct Countries
    INSERT INTO dbo.Dim_Country (country)
    SELECT DISTINCT country FROM dbo.hotel_bookings WHERE country IS NOT NULL;

   --- Create Date Table
DROP TABLE IF EXISTS Dim_Date;

CREATE TABLE Dim_Date (
    date_id INT IDENTITY(1,1) PRIMARY KEY,
    full_date DATE UNIQUE,
    year INT,
    month INT,
    month_name VARCHAR(20),
	week INT,
    day INT,
    day_of_week INT,
    day_name VARCHAR(20),
    is_weekend INT
);

-- Populate Dim_Date with Date Ranges
DECLARE @StartDate DATE = (SELECT MIN(booking_date) FROM hotel_bookings);
DECLARE @EndDate DATE = (SELECT MAX(arrival_date) FROM hotel_bookings);

WHILE @StartDate <= @EndDate
BEGIN
    INSERT INTO Dim_Date (full_date, year, month, month_name, week, day, day_of_week, day_name, is_weekend)
    VALUES (
        @StartDate,
        YEAR(@StartDate),
        MONTH(@StartDate),
        DATENAME(MONTH, @StartDate),
		DATEPART(WEEK, @StartDate),
        DAY(@StartDate),
        DATEPART(WEEKDAY, @StartDate),
        DATENAME(WEEKDAY, @StartDate),
        CASE WHEN DATEPART(WEEKDAY, @StartDate) IN (1,7) THEN 1 ELSE 0 END
    );

    SET @StartDate = DATEADD(DAY, 1, @StartDate);
END;


    -- Create Fact_Bookings Table
    CREATE TABLE dbo.Fact_Bookings (
        booking_id INT IDENTITY(1,1) PRIMARY KEY,
        hotel VARCHAR(255),
        is_canceled INT,
        lead_time INT,
        stays_in_weekend_nights INT,
        stays_in_week_nights INT,
        adults INT,
        children INT,
        babies INT,
        meal_id INT,
        country_id INT,
        customer_properties_id INT,
        customer_type_id INT,
        is_repeated_guest INT,
        previous_cancellations INT,
        previous_bookings_not_canceled INT,
        reserved_room_type VARCHAR(5),
        assigned_room_type VARCHAR(5),
        booking_changes INT,
        deposit_type VARCHAR(255),
        agent VARCHAR(50),
        company VARCHAR(50),
        days_in_waiting_list INT,
        adr DECIMAL(10,2),
        required_car_parking_spaces INT,
        total_of_special_requests INT,
        reservation_status VARCHAR(50),
        reservation_status_date DATE,
		booking_date DATE,
		arrival_date DATE,
		booking_date_id INT,
		arrival_date_id INT,
		reservation_status_date_id INT,
        FOREIGN KEY (meal_id) REFERENCES dbo.Dim_Meals(meal_id),
        FOREIGN KEY (country_id) REFERENCES dbo.Dim_Country(country_id),
        FOREIGN KEY (customer_properties_id) REFERENCES dbo.Dim_Customer_Properties(customer_properties_id),
        FOREIGN KEY (customer_type_id) REFERENCES dbo.Dim_Customer_Type(customer_type_id)
    );

    -- Insert Data into Fact_Bookings
    INSERT INTO dbo.Fact_Bookings (
        hotel, is_canceled, lead_time, stays_in_weekend_nights, stays_in_week_nights, adults, children, babies, meal_id, country_id, customer_properties_id, 
        customer_type_id, is_repeated_guest, previous_cancellations, previous_bookings_not_canceled, reserved_room_type, 
        assigned_room_type, booking_changes, deposit_type, agent, company, days_in_waiting_list, adr, required_car_parking_spaces, 
        total_of_special_requests, reservation_status, reservation_status_date, booking_date, arrival_date, booking_date_id, arrival_date_id, reservation_status_date_id
    )
    SELECT 
        hb.hotel, hb.is_canceled, hb.lead_time, hb.stays_in_weekend_nights, hb.stays_in_week_nights, hb.adults, hb.children, hb.babies, 
        m.meal_id, c.country_id, cp.customer_properties_id, ct.customer_type_id,
        hb.is_repeated_guest, hb.previous_cancellations, hb.previous_bookings_not_canceled, hb.reserved_room_type, 
        hb.assigned_room_type, hb.booking_changes, hb.deposit_type, hb.agent, hb.company, hb.days_in_waiting_list, 
        hb.adr, hb.required_car_parking_spaces, hb.total_of_special_requests, hb.reservation_status, hb.reservation_status_date,
		hb.booking_date, hb.arrival_date,
		d1.date_id AS booking_date_id,
		d2.date_id AS arrival_date_id,
		d3.date_id AS reservation_status_date_id
    FROM dbo.hotel_bookings hb
    LEFT JOIN dbo.Dim_Meals m ON hb.meal = m.meal
    LEFT JOIN dbo.Dim_Country c ON hb.country = c.country
    LEFT JOIN dbo.Dim_Customer_Properties cp ON hb.market_segment = cp.market_segment AND hb.distribution_channel = cp.distribution_channel
    LEFT JOIN dbo.Dim_Customer_Type ct ON hb.customer_type = ct.customer_type
	LEFT JOIN dbo.Dim_Date d1 ON hb.booking_date = d1.full_date
	LEFT JOIN dbo.Dim_Date d2 ON hb.arrival_date = d2.full_date
	LEFT JOIN dbo.Dim_Date d3 ON hb.reservation_status_date = d3.full_date;


END;




EXEC Create_Hotel_Bookings_Star_Schema;
