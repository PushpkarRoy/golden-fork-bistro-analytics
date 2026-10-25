-- Delivey Manager
-- ===================================================================================  

-- KPI's 

-- 1. What is the on-time delivery rate across all partners?
SELECT 
    CASE 
        WHEN delivery_partner = 'Inhouse' THEN 'In-House Fleet'
        ELSE delivery_partner 
    END AS standardized_partner,
    COUNT(delivery_id) AS total_deliveries,
    SUM(CASE WHEN delivery_duration_mins <= 40 THEN 1 ELSE 0 END) AS on_time_deliveries,
    ROUND((SUM(CASE WHEN delivery_duration_mins <= 40 THEN 1 ELSE 0 END) * 100.0) / COUNT(delivery_id), 2) AS on_time_rate_percentage
FROM delivery
WHERE delivery_status = 'Delivered'
GROUP BY 
    CASE 
        WHEN delivery_partner = 'Inhouse' THEN 'In-House Fleet'
        ELSE delivery_partner 
    END
ORDER BY on_time_rate_percentage DESC;

-- BUSINESS INSIGHT: 
-- The on-time delivery rate (under 40 minutes) is critically low, hovering at just ~21% across ALL partners. 
-- Since both our high-volume In-House Fleet and third-party vendors (Dunzo, Porter) are struggling at the exact same rate, the delivery drivers are NOT the problem. 
-- The root cause is a severe internal bottleneck—food preparation is taking too long at the outlets, causing delayed handoffs to the riders.
-- =========================================================================================================================================================================

-- 2. What is the average delivery duration in minutes per partner?
SELECT 
    CASE 
        WHEN delivery_partner = 'Inhouse' THEN 'In-House Fleet'
        ELSE delivery_partner 
    END AS standardized_partner,
    COUNT(delivery_id) AS total_deliveries,
    ROUND(AVG(delivery_duration_mins), 2) AS avg_delivery_time_mins
FROM delivery
WHERE delivery_status = 'Delivered'
GROUP BY 
    CASE 
        WHEN delivery_partner = 'Inhouse' THEN 'In-House Fleet'
        ELSE delivery_partner 
    END
ORDER BY avg_delivery_time_mins ASC;


-- BUSINESS INSIGHT: 
-- The average delivery time is startlingly consistent across ALL partners, tightly clustered around ~51 minutes. 
-- Since no single vendor is significantly faster or slower, this conclusively proves that external logistics are not the bottleneck. 
-- Management must look internally to reduce kitchen preparation time, or re-evaluate if the 40-minute delivery promise is actually realistic for the current operational setup.
-- =================================================================================================================================================================================

-- 3. What is the delivery success rate — Delivered vs Failed vs Cancelled?
SELECT 
    delivery_status,
    COUNT(delivery_id) AS total_orders,
    ROUND((COUNT(delivery_id) * 100.0) / (SELECT COUNT(*) FROM delivery), 2) AS percentage_of_total
FROM delivery
GROUP BY delivery_status
ORDER BY total_orders DESC;


-- BUSINESS INSIGHT: 
-- At first glance, our logistics performance looks outstanding with a 96.87% successful delivery completion rate.
-- However, there is a massive tracking blind spot: the system formally tags only 1.02% of orders as 'Delayed'. 
-- Since we already proved mathematically that nearly 80% of deliveries take over 40 minutes, this means the official 'status' column is severely misleading. Management cannot rely on this column alone to measure true on-time performance.
-- ===================================================================================================================================================================================================================================================
 
 
 
 -- 4. What is the average delivery distance in km per city?
 SELECT 
    outlets.city,
    COUNT(d.delivery_id) AS total_deliveries,
    ROUND(AVG(d.delivery_distance_km), 2) AS avg_delivery_distance_km
FROM delivery d
JOIN orders ord ON d.order_id = ord.order_id
JOIN outlets ON ord.outlet_id = outlets.outlet_id
WHERE d.delivery_status = 'Delivered'
GROUP BY outlets.city
ORDER BY avg_delivery_distance_km DESC;


-- BUSINESS INSIGHT: 
-- Delivery distance is very consistent, staying between 7.5 and 8 km in every city.
-- High order volumes do not change this average distance.
-- ===============================================================================

-- 5. What is the average delivery rating per partner?
SELECT 
    CASE 
        WHEN delivery_partner = 'Inhouse' THEN 'In-House Fleet'
        ELSE delivery_partner 
    END AS delivery_partner,
    COUNT(*) AS total_deliveries,
    ROUND(AVG(delivery_rating), 2) AS avg_delivery_rating
FROM delivery
WHERE delivery_rating IS NOT NULL
GROUP BY 
    CASE 
        WHEN delivery_partner = 'Inhouse' THEN 'In-House Fleet'
        ELSE delivery_partner 
    END
ORDER BY avg_delivery_rating DESC;

-- BUSINESS INSIGHT: 
-- Delivery ratings are extremely consistent across all partners, averaging around 3.92.
-- Our In-House Fleet handles three times more volume than third-party partners without any drop in quality.
-- ===============================================================================


-- ==================================================================================
-- EDA Questions
-- ===================================================================================


-- 1. Which delivery partner has the best on-time delivery rate?
SELECT 
    CASE 
        WHEN delivery_partner = 'Inhouse' THEN 'In-House Fleet'
        ELSE delivery_partner 
    END AS delivery_partner,
    COUNT(*) AS total_deliveries,
    ROUND(AVG(delivery_duration_mins), 2) AS avg_delivery_time_mins,
    ROUND(
        SUM(CASE WHEN delivery_duration_mins <= 45 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 
        2
    ) AS on_time_percentage
FROM delivery
WHERE delivery_status = 'Delivered' 
  AND delivery_duration_mins IS NOT NULL
GROUP BY 
    CASE 
        WHEN delivery_partner = 'Inhouse' THEN 'In-House Fleet'
        ELSE delivery_partner 
    END
ORDER BY on_time_percentage DESC;

-- BUSINESS INSIGHT: 
-- Less than 30% of orders meet the 45-minute SLA, with average delivery times hovering around 51 minutes for all partners.
-- Since performance is identical across the board, delays are likely caused by internal bottlenecks like kitchen prep rather than the delivery drivers.
-- ===============================================================================

-- 2. Which delivery partner has the most failed deliveries?
SELECT 
    CASE 
        WHEN delivery_partner = 'Inhouse' THEN 'In-House Fleet'
        ELSE delivery_partner 
    END AS delivery_partner,
    COUNT(*) AS total_assigned_orders,
    SUM(CASE WHEN delivery_status = 'Cancelled' THEN 1 ELSE 0 END) AS failed_deliveries,
    ROUND(
        SUM(CASE WHEN delivery_status = 'Cancelled' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 
        2
    ) AS failure_rate_percentage
FROM delivery
GROUP BY 
    CASE 
        WHEN delivery_partner = 'Inhouse' THEN 'In-House Fleet'
        ELSE delivery_partner 
    END
ORDER BY failed_deliveries DESC;

-- BUSINESS INSIGHT: 
-- While In-House Fleet has the most cancelled orders by volume, they actually have the lowest failure rate (0.88%).
-- Dunzo has the highest failure rate at 1.23%.
-- Overall, delivery failures are extremely rare across all partners, staying around 1%.
-- ===============================================================================

-- 3. Which city has the longest average delivery time?
SELECT 
    o.city,
    COUNT(d.delivery_id) AS total_deliveries,
    ROUND(AVG(d.delivery_duration_mins), 2) AS avg_delivery_time_mins
FROM delivery d
JOIN orders ord ON d.order_id = ord.order_id
JOIN outlets o ON ord.outlet_id = o.outlet_id
WHERE d.delivery_status = 'Delivered' 
  AND d.delivery_duration_mins IS NOT NULL
GROUP BY o.city
ORDER BY avg_delivery_time_mins DESC;

-- BUSINESS INSIGHT: 
-- Kolkata has the longest average delivery time at 51.60 minutes, while Surat is the fastest at 50.81 minutes.
-- The difference between the fastest and slowest city is less than one minute, showing highly consistent operations everywhere.
-- ===============================================================================


-- 4. How does delivery time vary between weekdays and weekends?
SELECT 
    o.week_type,
    COUNT(d.delivery_id) AS total_deliveries,
    ROUND(AVG(d.delivery_duration_mins), 2) AS avg_delivery_time_mins
FROM delivery d
JOIN orders o ON d.order_id = o.order_id
WHERE d.delivery_status = 'Delivered' 
  AND d.delivery_duration_mins IS NOT NULL
GROUP BY o.week_type
ORDER BY total_deliveries DESC;

-- BUSINESS INSIGHT: 
-- Delivery times are identical on both weekends and weekdays, averaging about 51 minutes.
-- This shows our operations are highly stable and unaffected by the day of the week.
-- ===============================================================================


-- 5. What is the distribution of delivery duration — most deliveries in which time range?
SELECT 
    CASE 
        WHEN delivery_duration_mins <= 30 THEN '0-30 mins'
        WHEN delivery_duration_mins > 30 AND delivery_duration_mins <= 45 THEN '31-45 mins'
        WHEN delivery_duration_mins > 45 AND delivery_duration_mins <= 60 THEN '46-60 mins'
        WHEN delivery_duration_mins > 60 AND delivery_duration_mins <= 75 THEN '61-75 mins'
        ELSE '75+ mins'
    END AS duration_range,
    COUNT(*) AS total_deliveries
FROM delivery
WHERE delivery_status = 'Delivered' 
  AND delivery_duration_mins IS NOT NULL
GROUP BY 
    CASE 
        WHEN delivery_duration_mins <= 30 THEN '0-30 mins'
        WHEN delivery_duration_mins > 30 AND delivery_duration_mins <= 45 THEN '31-45 mins'
        WHEN delivery_duration_mins > 45 AND delivery_duration_mins <= 60 THEN '46-60 mins'
        WHEN delivery_duration_mins > 60 AND delivery_duration_mins <= 75 THEN '61-75 mins'
        ELSE '75+ mins'
    END
ORDER BY total_deliveries DESC;


-- BUSINESS INSIGHT: 
-- The vast majority of our deliveries (over 70%) take between 46 and 60 minutes to complete.
-- Very few orders arrive in under 45 minutes, highlighting a clear area where we can improve speed.
-- ===============================================================================



