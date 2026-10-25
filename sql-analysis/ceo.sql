-- ===================================================================================
-- CEO
-- ===================================================================================  

-- KPI 
-- 1. What is the total revenue generated across all outlets in 2022, 2023, and 2024?

SELECT 
    YEAR(order_date) AS year,
    SUM(final_amount) AS total_revenue,
    COUNT(*) AS total_orders
FROM orders
WHERE order_status = 'Delivered'
GROUP BY YEAR(order_date)
ORDER BY year;

-- INSIGHT: Revenue has remained remarkably stable across 2023, 2024, and 2025, 
-- hovering consistently between 14.2M and 14.4M with no meaningful year-over-year 
-- growth. This signals a business that has plateaued rather than one that is 
-- scaling -- a key flag for the CEO. (Note: a small volume of orders carry a 
-- NULL or corrupted 2027 order_date, indicating a residual data quality issue 
-- that was excluded from year-over-year comparisons.)
-- ===========================================================================================================

-- 2. What is the month-over-month revenue growth rate?

WITH monthly_revenue AS (
    SELECT 
        DATE_FORMAT(order_date, '%Y-%m') AS month,
        SUM(final_amount) AS revenue
    FROM orders
    WHERE order_status = 'Delivered' AND order_date IS NOT NULL
    GROUP BY DATE_FORMAT(order_date, '%Y-%m')
)
SELECT 
    month,
    revenue,
    LAG(revenue) OVER (ORDER BY month) AS previous_month_revenue,
    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY month)) 
        / LAG(revenue) OVER (ORDER BY month) * 100, 2
    ) AS mom_growth_pct
FROM monthly_revenue
ORDER BY month;

-- INSIGHT: MoM growth oscillates in a tight +/-7% band month after month, with 
-- no sustained upward or downward streak across the 3-year period. This confirms 
-- the revenue plateau seen in the yearly view -- the business is operationally 
-- stable and predictable, but not growing organically month-over-month.
-- ===========================================================================================================

-- 3. What is the overall order cancellation rate across all outlets?

SELECT 
    COUNT(*) AS total_orders,
    SUM(CASE WHEN order_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled_orders,
    ROUND(
        SUM(CASE WHEN order_status = 'Cancelled' THEN 1 ELSE 0 END) 
        / COUNT(*) * 100, 2
    ) AS cancellation_rate_pct
FROM orders;

-- INSIGHT: 12.42% of all orders (9,910 of 79,812) are cancelled -- an identical 
-- rate to Refunded orders (also 12.42%), which together account for ~25% of all 
-- orders never converting into completed revenue. This is a material leakage 
-- point worth investigating at the outlet/order-type level.
-- ===========================================================================================================

-- 4. What is the average order value (AOV) across all cities?

SELECT 
    ot.city,
    ROUND(AVG(o.final_amount), 2) AS avg_order_value,
    COUNT(*) AS total_orders
FROM orders o
JOIN outlets ot ON o.outlet_id = ot.outlet_id
WHERE o.order_status = 'Delivered'
GROUP BY ot.city
ORDER BY avg_order_value DESC;

-- INSIGHT: Delhi has the highest AOV (887.65) despite operating only 2 outlets, 
-- while Ahmedabad has the lowest (816.37). The spread between the highest and 
-- lowest city AOV is under 9%, suggesting customer spending behavior is fairly 
-- consistent nationwide rather than being city-specific.
-- ===========================================================================================================

-- 5. What percentage of customers are repeat buyers vs one-time buyers?

WITH customer_order_counts AS (
    SELECT customer_id, COUNT(*) AS order_count
    FROM orders
    WHERE order_status = 'Delivered'
    GROUP BY customer_id
)
SELECT 
    SUM(CASE WHEN order_count = 1 THEN 1 ELSE 0 END) AS one_time_buyers,
    SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) AS repeat_buyers,
    ROUND(SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS repeat_buyer_pct
FROM customer_order_counts;

-- INSIGHT: 75.30% of customers (9,076 of 12,053) are repeat buyers, indicating 
-- strong underlying customer loyalty. This is a positive counter-signal to the 
-- flat revenue trend -- the business isn't losing customers, it simply isn't 
-- acquiring enough new ones to drive growth on top of a loyal existing base.


-- =============================================================================================
-- EDA Questions 
-- ============================================================================================

-- 1. Which year had the highest total revenue?

SELECT 
    YEAR(order_date) AS year,
    SUM(final_amount) AS total_revenue
FROM orders
WHERE order_status = 'Delivered' AND order_date IS NOT NULL
GROUP BY YEAR(order_date)
ORDER BY total_revenue DESC;

-- INSIGHT: 2024 recorded the highest revenue at 14.38M, narrowly ahead of 2023 
-- (14.22M) and 2025 (14.20M) -- a gap of less than 1.5% between the top and 
-- bottom year, reinforcing that performance has been flat rather than trending 
-- in either direction across the 3-year window.
-- ===================================================================================================

-- 2. What is the revenue trend -- is it growing, stable, or declining?

SELECT 
    qtr AS quarter,
    COUNT(DISTINCT yr) AS years_present,
    SUM(quarterly_revenue) AS total_revenue_all_years,
    ROUND(AVG(quarterly_revenue), 2) AS avg_revenue_per_year
FROM (
    SELECT 
        YEAR(order_date) AS yr,
        QUARTER(order_date) AS qtr,
        SUM(final_amount) AS quarterly_revenue
    FROM orders
    WHERE order_status = 'Delivered' AND order_date IS NOT NULL
    GROUP BY YEAR(order_date), QUARTER(order_date)
) yearly_quarters
GROUP BY qtr
ORDER BY avg_revenue_per_year DESC;

-- INSIGHT: The revenue trend is STABLE, not growing or declining. Quarter-on-quarter 
-- swings stay mostly within a single-digit percentage band across 2023-2025, with 
-- no sustained multi-quarter upward or downward streak. The business has reached 
-- a steady-state and needs a deliberate growth intervention (new markets, 
-- acquisition campaigns) rather than relying on organic momentum.
-- ===================================================================================================

-- 3. Which city contributes the most to total revenue?

SELECT 
    ot.city,
    SUM(o.final_amount) AS city_revenue,
    ROUND(SUM(o.final_amount) * 100.0 / SUM(SUM(o.final_amount)) OVER (), 2) AS pct_of_total_revenue
FROM orders o
JOIN outlets ot ON o.outlet_id = ot.outlet_id
WHERE o.order_status = 'Delivered'
GROUP BY ot.city
ORDER BY city_revenue DESC;

-- INSIGHT: Kochi is the single largest revenue contributor at 15.74% of total 
-- revenue (8.16M), roughly 50% ahead of the #2 city, Bengaluru (10.29%). This 
-- concentration is explained primarily by outlet count (Kochi has the most 
-- outlets), not by superior per-outlet efficiency -- Kochi actually has one of 
-- the lower AOVs among major cities.
-- ===================================================================================================

-- 4. What is the revenue split between Dine-In, Takeaway, and Online Delivery?

SELECT 
    order_type,
    COUNT(*) AS total_orders,
    SUM(final_amount) AS total_revenue,
    ROUND(SUM(final_amount) * 100.0 / SUM(SUM(final_amount)) OVER (), 2) AS revenue_share_pct
FROM orders
WHERE order_status = 'Delivered'
GROUP BY order_type
ORDER BY total_revenue DESC;

-- INSIGHT: Online Delivery is the dominant channel, generating 68.23% of total 
-- revenue (35.3M) from 51% of order volume proportionally similar, confirming 
-- Delivery is both the highest-volume and highest-revenue channel. Dine-In 
-- (16.71%) and Takeaway (15.06%) contribute roughly equal, smaller shares.
-- ===================================================================================================

-- 5. What is the total discount given vs total revenue earned?

SELECT 
    SUM(total_amount) AS gross_revenue_before_discount,
    SUM(discount_applied) AS total_discount_given,
    SUM(final_amount) AS net_revenue_after_discount,
    ROUND(SUM(discount_applied) * 100.0 / SUM(total_amount), 2) AS discount_pct_of_gross
FROM orders
WHERE order_status = 'Delivered';

-- INSIGHT: Total discounts given (373K) represent just 0.71% of gross revenue 
-- (52.17M) -- an unusually low discount burden. This suggests promotions are not 
-- a meaningful lever currently being used to drive volume, and there may be 
-- significant untapped headroom to use discounting more strategically to 
-- reignite growth without materially hurting margins.
-- ===================================================================================================

-- 6. How many unique customers placed orders each year?

SELECT 
    YEAR(order_date) AS year,
    COUNT(DISTINCT customer_id) AS unique_customers
FROM orders
WHERE order_status = 'Delivered' AND order_date IS NOT NULL
GROUP BY YEAR(order_date)
ORDER BY year;

-- INSIGHT: Unique customers held steady at ~7,345-7,350 in both 2023 and 2024, 
-- then declined to 5,591 by 2026 (partial year). Combined with the new-vs-returning 
-- customer trend below, this indicates the active customer base is starting to 
-- shrink even though per-customer loyalty (repeat rate) remains strong.
-- ===================================================================================================

-- 7. What is the ratio of new customers to returning customers each year?

WITH customer_first_order AS (
    SELECT customer_id, MIN(YEAR(order_date)) AS first_order_year
    FROM orders
    WHERE order_status = 'Delivered' AND order_date IS NOT NULL
    GROUP BY customer_id
)
SELECT 
    o.year,
    SUM(CASE WHEN cfo.first_order_year = o.year THEN 1 ELSE 0 END) AS new_customers,
    SUM(CASE WHEN cfo.first_order_year < o.year THEN 1 ELSE 0 END) AS returning_customers
FROM (
    SELECT DISTINCT customer_id, YEAR(order_date) AS year
    FROM orders
    WHERE order_status = 'Delivered' AND order_date IS NOT NULL
) o
JOIN customer_first_order cfo ON o.customer_id = cfo.customer_id
GROUP BY o.year
ORDER BY o.year;

-- INSIGHT: This is the most important trend for the CEO to see. New customer 
-- acquisition has collapsed year after year -- from 7,345 new customers in 2023 
-- down to just 570 by 2026 -- while the returning-customer base has correspondingly 
-- grown to dominate the order mix (90%+ of 2026 activity is returning customers). 
-- The business has effectively transitioned from a growth phase to a pure 
-- retention phase, which directly explains the flat revenue trend seen above.
-- ===================================================================================================

-- 8. How many orders were Completed vs Cancelled vs Pending vs Refunded?

SELECT 
    order_status,
    COUNT(*) AS total_orders,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_all_orders
FROM orders
GROUP BY order_status
ORDER BY total_orders DESC;

-- INSIGHT: 75.16% of orders are successfully Delivered, while Refunded (12.42%) 
-- and Cancelled (12.42%) split the remaining quarter almost exactly evenly. No 
-- "Pending" status was present in the current dataset, suggesting order 
-- fulfillment is fully resolved (no long-running open orders) at any given time.
-- ===================================================================================================

-- 9. Which payment method generates the highest total revenue?

SELECT 
    payment_method,
    COUNT(*) AS total_orders,
    SUM(final_amount) AS total_revenue,
    ROUND(AVG(final_amount), 2) AS avg_order_value
FROM orders
WHERE order_status = 'Delivered'
GROUP BY payment_method
ORDER BY total_revenue DESC;

-- INSIGHT: UPI is the clear leader, generating 21.26M in revenue from 24,682 
-- orders (~41% of all order volume) -- more than double the next-highest method 
-- (Credit Card at 8.18M). This reflects the broader shift toward UPI as the 
-- default digital payment rail in the Indian market and should inform any 
-- payment-partner negotiation or checkout-flow prioritization.
-- ===================================================================================================

-- 10. Which quarter generates the most revenue consistently?

SELECT 
    qtr AS quarter,
    COUNT(DISTINCT yr) AS years_present,
    SUM(quarterly_revenue) AS total_revenue_all_years,
    ROUND(AVG(quarterly_revenue), 2) AS avg_revenue_per_year
FROM (
    SELECT 
        YEAR(order_date) AS yr,
        QUARTER(order_date) AS qtr,
        SUM(final_amount) AS quarterly_revenue
    FROM orders
    WHERE order_status = 'Delivered' AND order_date IS NOT NULL
    GROUP BY YEAR(order_date), QUARTER(order_date)
) yearly_quarters
GROUP BY qtr
ORDER BY avg_revenue_per_year DESC;

-- INSIGHT: Q2 (Apr-Jun) is the strongest quarter on average (3.54M/year), 
-- followed closely by Q3 (3.13M) and Q1 (2.85M), with Q4 the weakest (2.70M). 
-- The gap between the best and worst quarter is under 30%, indicating mild but 
-- not dramatic seasonality -- not enough to justify aggressive seasonal staffing 
-- swings, but worth a modest Q2 promotional push and Q4 demand-generation focus.


