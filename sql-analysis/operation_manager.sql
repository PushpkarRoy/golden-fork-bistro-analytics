USE rap2


-- ===================================================================================
-- Operations Manager
-- ===================================================================================  

-- KPI 
-- 1. What is the revenue ranking of all 50+ outlets?

SELECT 
    o.outlet_id,
    o.city,
    o.outlet_type,
    SUM(ord.final_amount) AS total_revenue,
    RANK() OVER (ORDER BY SUM(ord.final_amount) DESC) AS revenue_rank
FROM outlets o
JOIN orders ord ON o.outlet_id = ord.outlet_id
GROUP BY o.outlet_id, o.city, o.outlet_type
ORDER BY revenue_rank;

-- INSIGHT: Delhi's 'Dine-In Only' outlet (OUT010) is the top performer with the highest revenue (1.5M).
-- Kochi and Bengaluru's 'Delivery Only' outlets hold the 2nd and 3rd ranks.
-- ===========================================================================================================

-- 2. What is the cancellation rate per outlet?
SELECT 
    o.outlet_id,
    o.city,
    o.outlet_type,
    COUNT(ord.order_id) AS total_orders,
    SUM(CASE WHEN ord.order_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled_orders,
    ROUND((SUM(CASE WHEN ord.order_status = 'Cancelled' THEN 1 ELSE 0 END) * 100.0) / COUNT(ord.order_id), 2) AS cancellation_rate_pct
FROM outlets o
JOIN orders ord ON o.outlet_id = ord.outlet_id
GROUP BY o.outlet_id, o.city, o.outlet_type
ORDER BY cancellation_rate_pct DESC; 

-- INSIGHT: Chennai's Cloud Kitchen (OUT049) has the highest cancellation rate at ~14.0%.
-- Surat and Pune outlets follow closely at ~13.8%, requiring immediate operational review.
-- ======================================================================================================

-- 3. What is the average order value per outlet?
SELECT 
    o.outlet_id,
    o.city,
    o.outlet_type,
    ROUND(AVG(ord.final_amount), 2) AS avg_order_value
FROM outlets o
JOIN orders ord ON o.outlet_id = ord.outlet_id
GROUP BY o.outlet_id, o.city, o.outlet_type
ORDER BY avg_order_value DESC;

-- INSIGHT: Indore's 'Dine-In Only' outlet (OUT005) leads with the highest Average Order Value at 905.44.
-- 'Dine-In' formats dominate the top spots, indicating higher per-order spending by visiting customers.
-- =============================================================================================================


-- 4. Which outlets are underperforming below the 70th percentile?
WITH OutletRevenue AS (
    SELECT 
        o.outlet_id,
        o.city,
        o.outlet_type,
        SUM(ord.final_amount) AS total_revenue
    FROM outlets o
    JOIN orders ord ON o.outlet_id = ord.outlet_id
    GROUP BY o.outlet_id, o.city, o.outlet_type
),
RankedOutlets AS (
    SELECT 
        outlet_id,
        city,
        outlet_type,
        total_revenue,
        PERCENT_RANK() OVER(ORDER BY total_revenue) AS percentile_rank
    FROM OutletRevenue
)
SELECT 
    outlet_id,
    city,
    outlet_type,
    total_revenue,
    ROUND(percentile_rank * 100, 2) AS percentile
FROM RankedOutlets
WHERE percentile_rank < 0.70 -- 70th percentile se neeche wale (bottom 70%)
ORDER BY total_revenue ASC;

-- INSIGHT: Hyderabad's Cloud Kitchen (OUT039) is the most underperforming outlet (0th percentile).
-- It is closely followed by 'Delivery Only' outlets in Kochi (OUT026) and Indore (OUT034), needing urgent strategy review.
-- ================================================================================================================================

-- 5. What is the average number of orders per outlet per month?
SELECT 
    o.outlet_id,
    o.city,
    o.outlet_type,
    COUNT(ord.order_id) AS total_orders,
    COUNT(DISTINCT DATE_FORMAT(ord.order_date, '%Y-%m')) AS active_months,
    ROUND(COUNT(ord.order_id) / COUNT(DISTINCT DATE_FORMAT(ord.order_date, '%Y-%m')), 0) AS avg_orders_per_month
FROM outlets o
JOIN orders ord ON o.outlet_id = ord.outlet_id
GROUP BY o.outlet_id, o.city, o.outlet_type
ORDER BY avg_orders_per_month DESC;

-- INSIGHT: Bengaluru's 'Dine-In Only' outlet (OUT006) slightly leads with 37 average monthly orders.
-- Overall, top outlets across various cities maintain a highly consistent volume of ~36 orders per month.
-- ================================================================================================================

-- =============================================================================================
-- EDA Questions 
-- ============================================================================================

-- 1. Which outlets are in the top 10 by revenue?
SELECT 
    o.outlet_id,
    o.city,
    o.outlet_type,
    SUM(ord.final_amount) AS total_revenue,
    DENSE_RANK() OVER(ORDER BY SUM(ord.final_amount) DESC) AS revenue_rank
FROM outlets o
JOIN orders ord ON o.outlet_id = ord.outlet_id
GROUP BY o.outlet_id, o.city, o.outlet_type
ORDER BY total_revenue DESC
LIMIT 10;

-- INSIGHT: Delhi's 'Dine-In Only' (OUT010) leads the Top 10 with ~1.5M in total revenue.
-- Bengaluru dominates with 3 outlets in the list, while Indore impressively secures the 4th rank.
-- ===================================================================================================


-- 2. Which outlets have the highest cancellation rate?
SELECT 
    o.outlet_id,
    o.city,
    o.outlet_type,
    COUNT(ord.order_id) AS total_orders,
    SUM(CASE WHEN ord.order_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled_orders,
    ROUND((SUM(CASE WHEN ord.order_status = 'Cancelled' THEN 1 ELSE 0 END) * 100.0) / COUNT(ord.order_id), 2) AS cancellation_rate_pct
FROM outlets o
JOIN orders ord ON o.outlet_id = ord.outlet_id
GROUP BY o.outlet_id, o.city, o.outlet_type
ORDER BY cancellation_rate_pct DESC
LIMIT 10;

-- INSIGHT: Chennai's Cloud Kitchen (OUT049) has the highest cancellation rate at 13.99%.
-- Surat also needs urgent attention, having two outlets (OUT041, OUT018) in the top 4 with ~13.7% cancellations
-- ===================================================================================================================


-- 3. How does outlet performance differ by city and region?
SELECT 
    o.city,
    COUNT(DISTINCT o.outlet_id) AS total_outlets,
    COUNT(ord.order_id) AS total_orders,
    SUM(ord.final_amount) AS total_revenue,
    ROUND(AVG(ord.final_amount), 2) AS avg_order_value
FROM outlets o
JOIN orders ord ON o.outlet_id = ord.outlet_id
GROUP BY o.city
ORDER BY total_revenue DESC;

-- INSIGHT: Kochi dominates total revenue (~10.8M) driven by its large footprint of 8 outlets.
-- Despite having only 2 outlets, Delhi holds the highest Average Order Value (880.60), while Bengaluru, Surat, and Indore firmly secure the top tier spots.
-- ============================================================================================================================================================

-- 4. How does revenue differ between active and inactive outlets?
SELECT 
    o.is_active AS outlet_status,
    COUNT(DISTINCT o.outlet_id) AS total_outlets,
    COUNT(ord.order_id) AS total_orders,
    SUM(ord.final_amount) AS total_revenue,
    ROUND(AVG(ord.final_amount), 2) AS avg_order_value
FROM outlets o
JOIN orders ord ON o.outlet_id = ord.outlet_id
WHERE ord.order_status = 'Delivered' -- Sahi revenue ke liye sirf successful orders filter kiye hain
GROUP BY o.is_active
ORDER BY total_revenue DESC;

-- INSIGHT: While 46 active outlets drive the majority of the revenue (~47.7M), 
-- the Average Order Value (AOV) for both active and inactive outlets remains virtually identical (~863). 
-- This indicates that the closure of the 4 inactive outlets was likely driven by operational inefficiencies 
-- or high fixed costs, rather than a lack of customer willingness to spend.
-- ====================================================================================================================

-- 5. What is the average order value across different outlet types?
SELECT 
    o.outlet_type,
    COUNT(DISTINCT o.outlet_id) AS outlet_count,
    COUNT(ord.order_id) AS total_orders,
    SUM(ord.final_amount) AS total_revenue,
    ROUND(AVG(ord.final_amount), 2) AS avg_order_value
FROM outlets o
JOIN orders ord ON o.outlet_id = ord.outlet_id
WHERE ord.order_status = 'Delivered'
GROUP BY o.outlet_type
ORDER BY avg_order_value DESC;

-- BUSINESS INSIGHT: 
-- 1. 'Dine-In Only' outlets yield the highest Average Order Value (870.39), likely driven by experiential dining and upselling (beverages/desserts).
-- 2. However, 'Delivery Only' is the primary revenue engine, driving maximum volume (18.9K orders) and total revenue (16.4M).
-- 3. 'Dine-In + Delivery' hybrids have the lowest AOV (852.50), suggesting potential operational friction in managing dual channels simultaneously.


