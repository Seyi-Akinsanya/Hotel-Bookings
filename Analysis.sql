	-- Analysis
--- How do bookings fluctuate over time?
SELECT 
    d.year, 
    d.month_name, 
    COUNT(fb.booking_id) AS total_bookings,
    LAG(COUNT(fb.booking_id)) OVER (PARTITION BY d.year ORDER BY d.month) AS previous_month_bookings,
    ROUND(
        (COUNT(fb.booking_id) - LAG(COUNT(fb.booking_id)) OVER (PARTITION BY d.year ORDER BY d.month)) * 100.0 / 
        NULLIF(LAG(COUNT(fb.booking_id)) OVER (PARTITION BY d.year ORDER BY d.month), 0), 2
    ) AS monthly_growth_rate
FROM Fact_Bookings fb
JOIN Dim_Date d ON fb.booking_date_id = d.date_id
GROUP BY d.year, d.month, d.month_name, d.month
ORDER BY 3;

--- Months with the highest revenue
SELECT 
    d.year, 
    d.month_name, 
    ROUND(SUM(fb.adr * fb.stays_in_week_nights), 2) AS total_revenue,
    ROUND(SUM(fb.adr * fb.stays_in_week_nights)/SUM(fb.stays_in_week_nights), 2) AS avg_daily_rate,
    RANK() OVER (ORDER BY SUM(fb.adr * fb.stays_in_week_nights) DESC) AS revenue_rank
FROM Fact_Bookings fb
JOIN Dim_Date d ON fb.arrival_date_id = d.date_id
WHERE fb.is_canceled = 0  -- Exclude canceled bookings
GROUP BY d.year, d.month, d.month_name
ORDER BY 5;


---Meal Popularity and Revenue
SELECT 
    m.meal, 
    COUNT(fb.booking_id) AS total_bookings,
    ROUND(SUM(fb.adr * fb.stays_in_week_nights), 2) AS total_revenue,
    ROUND(SUM(fb.adr * fb.stays_in_week_nights)/SUM(fb.stays_in_week_nights), 2) AS avg_daily_rate
FROM Fact_Bookings fb
JOIN Dim_Meals m ON fb.meal_id = m.meal_id
WHERE fb.is_canceled = 0  -- Exclude canceled bookings
GROUP BY m.meal
ORDER BY 4 DESC;


--- Cancellation Rate by Customer Type
SELECT 
    ct.customer_type, 
    COUNT(fb.booking_id) AS total_bookings,
    SUM(CASE WHEN fb.is_canceled = 1 THEN 1 ELSE 0 END) AS canceled_bookings,
    ROUND(SUM(CASE WHEN fb.is_canceled = 1 THEN fb.adr ELSE 0 END), 2) AS revenue_loss,
    ROUND(SUM(CASE WHEN fb.is_canceled = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(fb.booking_id), 2) AS cancellation_rate
FROM Fact_Bookings fb
JOIN Dim_Customer_Type ct ON fb.customer_type_id = ct.customer_type_id
GROUP BY ct.customer_type
ORDER BY cancellation_rate DESC;


--- Effect of lead times on cancellation rates
SELECT 
    CASE 
        WHEN fb.lead_time <= 7 THEN '0-7 Days'
        WHEN fb.lead_time BETWEEN 8 AND 30 THEN '8-30 Days'
        WHEN fb.lead_time BETWEEN 31 AND 90 THEN '31-90 Days'
        ELSE '90+ Days'
    END AS lead_time_bucket,
    COUNT(fb.booking_id) AS total_bookings,
    SUM(CASE WHEN fb.is_canceled = 1 THEN 1 ELSE 0 END) AS canceled_bookings,
    ROUND(SUM(CASE WHEN fb.is_canceled = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(fb.booking_id), 2) AS cancellation_rate,
    ROUND(SUM(fb.adr * fb.stays_in_week_nights)/SUM(fb.stays_in_week_nights), 2) AS avg_daily_rate
FROM Fact_Bookings fb
GROUP BY 
    CASE 
        WHEN fb.lead_time <= 7 THEN '0-7 Days'
        WHEN fb.lead_time BETWEEN 8 AND 30 THEN '8-30 Days'
        WHEN fb.lead_time BETWEEN 31 AND 90 THEN '31-90 Days'
        ELSE '90+ Days'
    END
ORDER BY cancellation_rate DESC;


--- High-Value Customers vs High-Risk Customers
SELECT 
    cp.market_segment, 
    cp.distribution_channel, 
    COUNT(fb.booking_id) AS total_bookings,
    ROUND(SUM(fb.adr * fb.stays_in_week_nights), 2) AS total_revenue,
    SUM(CASE WHEN fb.is_canceled = 1 THEN 1 ELSE 0 END) AS canceled_bookings,
    ROUND(SUM(CASE WHEN fb.is_canceled = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(fb.booking_id), 2) AS cancellation_rate
FROM Fact_Bookings fb
JOIN Dim_Customer_Properties cp ON fb.customer_properties_id = cp.customer_properties_id
GROUP BY cp.market_segment, cp.distribution_channel
ORDER BY total_revenue DESC;
