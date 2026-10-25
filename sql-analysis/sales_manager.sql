-- ===================================================================================
-- Sales Manager
-- ===================================================================================  

-- KPI 
-- 1. What is the total revenue by order type (Dine-In, Takeaway, Online Delivery)?

SELECT 
    order_type,
    COUNT(*) AS total_orders,
    SUM(final_amount) AS total_revenue
FROM orders
WHERE order_status = 'Delivered'
GROUP BY order_type
ORDER BY total_revenue DESC;

-- INSIGHT: Delivery is the dominant channel by a wide margin -- 35.35M in revenue 
-- from 40,875 orders, more than 4x Dine-In (8.66M) and Takeaway (7.80M) combined. 
-- Any sales strategy or promotional budget should be weighted primarily toward 
-- protecting and growing the Delivery channel, since it carries the majority of 
-- the business's revenue base.
-- ===========================================================================================================

-- 2. What is the average order value per order type?

SELECT 
    order_type,
    ROUND(AVG(final_amount), 2) AS avg_order_value,
    COUNT(*) AS total_orders
FROM orders
WHERE order_status = 'Delivered'
GROUP BY order_type
ORDER BY avg_order_value DESC;

-- INSIGHT: AOV is remarkably consistent across channels -- Takeaway (868.81), 
-- Delivery (864.71), and Dine-In (854.20) sit within a 15-rupee band of each other. 
-- This means Delivery's revenue dominance comes purely from order VOLUME, not from 
-- customers spending more per order on that channel -- a useful distinction when 
-- setting channel-specific sales targets.
-- ===========================================================================================================

-- 3. What is the daily and weekly sales trend?

-- Daily trend
SELECT 
    order_date,
    SUM(final_amount) AS daily_revenue,
    COUNT(*) AS daily_orders
FROM orders
WHERE order_status = 'Delivered' AND order_date IS NOT NULL
GROUP BY order_date
ORDER BY order_date;

-- Weekly trend
SELECT 
    YEAR(order_date) AS year,
    WEEK(order_date) AS week_number,
    SUM(final_amount) AS weekly_revenue,
    COUNT(*) AS weekly_orders
FROM orders
WHERE order_status = 'Delivered' AND order_date IS NOT NULL
GROUP BY YEAR(order_date), WEEK(order_date)
ORDER BY year, week_number;

-- INSIGHT: Both daily and weekly views show steady, low-volatility sales with no 
-- sharp spikes or crashes -- early-2023 weekly revenue moves in a tight 240K-310K 
-- band. This consistency is operationally healthy (predictable staffing/inventory 
-- needs) but, combined with the flat yearly trend seen at the CEO level, confirms 
-- there is no organic day-to-day momentum currently driving growth.
-- ===========================================================================================================

-- 4. What is the total discount given and what percentage of gross revenue is it?

SELECT 
    SUM(total_amount) AS gross_revenue,
    SUM(discount_applied) AS total_discount,
    ROUND(SUM(discount_applied) * 100.0 / SUM(total_amount), 2) AS discount_pct_of_gross
FROM orders
WHERE order_status = 'Delivered';

-- INSIGHT: Discounts represent only 0.71% of gross revenue (373K of 52.17M) -- an 
-- unusually light discount load for a restaurant business. Sales has significant 
-- headroom to run more aggressive, targeted discount campaigns (e.g. on Takeaway/ 
-- Dine-In, the lower-revenue channels) without materially eroding overall margin.
-- ===========================================================================================================

-- 5. Which payment method is most used and generates the most revenue?

SELECT 
    payment_method,
    COUNT(*) AS total_orders,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS usage_pct,
    SUM(final_amount) AS total_revenue
FROM orders
WHERE order_status = 'Delivered'
GROUP BY payment_method
ORDER BY total_orders DESC;

-- INSIGHT: UPI leads decisively on both dimensions -- 41.15% of order volume and 
-- 21.26M in revenue, more than double the next-highest method (Credit Card at 
-- 15.80% / 8.18M). Cash and COD together account for only ~11.4% of orders, 
-- confirming the customer base has largely moved to digital-first payment 
-- behavior -- checkout flow and payment-partner investment should prioritize UPI reliability.
-- ===========================================================================================================


-- =============================================================================================
-- EDA Questions 
-- ============================================================================================

-- 1. Which order type (Dine-In, Takeaway, Online) has the highest order volume?

SELECT 
    order_type,
    COUNT(*) AS total_orders,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_total_orders
FROM orders
WHERE order_status = 'Delivered'
GROUP BY order_type
ORDER BY total_orders DESC;

-- INSIGHT: Delivery accounts for 68.14% of all order volume, versus 16.90% for 
-- Dine-In and 14.96% for Takeaway. Order-volume share (68.14%) and revenue share 
-- (68.23%, from KPI 1) are almost identical -- reconfirming that no channel is 
-- disproportionately more or less valuable per order than its volume share suggests.
-- ===================================================================================================

-- 2. Which order type generates the most revenue?
-- (Answered directly by KPI 1 above -- Delivery: 35.35M, the clear revenue leader.)
-- ===================================================================================================

-- 3. Which day of the week has the highest sales?

SELECT 
    DAYNAME(order_date) AS day_of_week,
    COUNT(*) AS total_orders,
    SUM(final_amount) AS total_revenue
FROM orders
WHERE order_status = 'Delivered' AND order_date IS NOT NULL
GROUP BY DAYNAME(order_date), DAYOFWEEK(order_date)
ORDER BY DAYOFWEEK(order_date);

-- INSIGHT: Friday narrowly edges out other days in order volume (8,674) and 
-- Tuesday leads slightly in revenue (7.46M), but the spread across all 7 days is 
-- under 2% start to finish. There is no strong "best day" to concentrate marketing 
-- spend around -- demand is essentially flat across the entire week.
-- ===================================================================================================

-- 4. What are the peak sales hours based on order time?

SELECT 
    HOUR(order_time) AS hour_of_day,
    COUNT(*) AS total_orders,
    SUM(final_amount) AS total_revenue
FROM orders
WHERE order_status = 'Delivered' AND order_time IS NOT NULL
GROUP BY HOUR(order_time)
ORDER BY hour_of_day;

-- INSIGHT: Order volume stays flat between ~2,400 and ~2,830 across all 24 hours 
-- of the day, with only a mild bump around hour 10. This is an atypical pattern 
-- for a restaurant business, which would normally show clear lunch (12-2pm) and 
-- dinner (7-9pm) peaks -- this flatness should be validated against real-world 
-- order-time expectations before being used to drive staffing decisions, as it 
-- may reflect a data-generation artifact rather than genuine customer behavior.
-- ===================================================================================================

-- 5. How does revenue differ between weekdays and weekends?

SELECT 
    CASE WHEN DAYOFWEEK(order_date) IN (1,7) THEN 'Weekend' ELSE 'Weekday' END AS day_type,
    COUNT(*) AS total_orders,
    SUM(final_amount) AS total_revenue,
    ROUND(AVG(final_amount), 2) AS avg_order_value
FROM orders
WHERE order_status = 'Delivered' AND order_date IS NOT NULL
GROUP BY day_type;

-- INSIGHT: Weekend orders (16,958) make up ~28.3% of total volume -- almost exactly 
-- proportional to weekends being 2 of 7 days (28.6%) -- so weekends are not 
-- disproportionately busier. Weekend AOV is marginally higher (871.14 vs 860.56), 
-- suggesting slightly larger baskets on weekends rather than more frequent, smaller orders.
-- ===================================================================================================

-- 6. Which payment method is most popular -- UPI, Cash, Card, Net Banking, Wallet?
-- (Answered directly by KPI 5 above -- UPI leads with 41.15% of order volume.)
-- ===================================================================================================

-- 7. What is the average discount per order type?

SELECT 
    order_type,
    ROUND(AVG(discount_applied), 2) AS avg_discount,
    COUNT(*) AS total_orders
FROM orders
WHERE order_status = 'Delivered'
GROUP BY order_type
ORDER BY avg_discount DESC;

-- INSIGHT: Delivery orders receive the highest average discount (6.36) versus 
-- Dine-In (5.99) and Takeaway (5.83) -- a modest but consistent pattern showing 
-- discounting effort is already weighted toward the highest-revenue channel, 
-- which is a reasonable allocation of promotional spend.
-- ===================================================================================================

-- 8. How many orders used a promo code vs no promo code?

SELECT 
    CASE WHEN promo_id IS NOT NULL THEN 'Used Promo' ELSE 'No Promo' END AS promo_usage,
    COUNT(*) AS total_orders,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_orders
FROM orders
WHERE order_status = 'Delivered'
GROUP BY promo_usage;

-- INSIGHT: 35.05% of orders (21,023) used a promo code, while the majority 
-- (64.95%) paid full price. Given the very low overall discount burden (0.71% of 
-- gross revenue from KPI 4), this confirms that even among promo-using orders the 
-- individual discount amounts are small -- promos are being used broadly but lightly, 
-- rather than as deep, high-cost incentives.
-- ===================================================================================================

-- 9. What is the revenue before discount vs after discount each month?

SELECT 
    DATE_FORMAT(order_date, '%Y-%m') AS month,
    SUM(total_amount) AS revenue_before_discount,
    SUM(final_amount) AS revenue_after_discount,
    SUM(discount_applied) AS total_discount
FROM orders
WHERE order_status = 'Delivered' AND order_date IS NOT NULL
GROUP BY DATE_FORMAT(order_date, '%Y-%m')
ORDER BY month;

-- INSIGHT: The gap between gross and net revenue is small and stable every month 
-- (typically 5K-11K on ~1.15-1.28M monthly revenue, i.e. well under 1%) -- 
-- discounting has been applied with remarkable month-to-month consistency rather 
-- than being used as a lever for specific promotional pushes, reinforcing the 
-- opportunity flagged earlier to use discounting more deliberately and strategically.
-- ===================================================================================================

-- 10. Which months have the highest and lowest sales?

SELECT 
    DATE_FORMAT(order_date, '%Y-%m') AS month,
    SUM(final_amount) AS monthly_revenue
FROM orders
WHERE order_status = 'Delivered' AND order_date IS NOT NULL
GROUP BY DATE_FORMAT(order_date, '%Y-%m')
ORDER BY monthly_revenue DESC;

-- INSIGHT: The highest-revenue month on record is July 2026 (1.29M), followed by 
-- July 2024 (1.27M) and January 2025 (1.26M) -- July appears twice near the top, 
-- a mild signal worth monitoring for a potential mid-year seasonal uptick, though 
-- the overall spread between top and bottom months remains modest (consistent 
-- with the low week-to-week volatility seen earlier), so this should be treated 
-- as a soft signal rather than a strong seasonal pattern.