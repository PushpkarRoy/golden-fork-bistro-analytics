-- ===================================================================================
-- Marketing Manager
-- ===================================================================================  

-- KPI 
-- 1. What is the Customer Lifetime Value (CLV) by loyalty tier?

SELECT 
    loyalty_tier,
    COUNT(*) AS num_customers,
    ROUND(AVG(total_lifetime_value), 2) AS avg_clv,
    SUM(total_lifetime_value) AS total_tier_revenue
FROM customers
GROUP BY loyalty_tier
ORDER BY avg_clv DESC;

-- INSIGHT: CLV scales dramatically by tier -- Platinum customers average 24,735.50 
-- lifetime value versus just 271.58 for Bronze, a ~91x difference. Despite Platinum 
-- being only 6.39% of the customer base, this tier alone generates 24.1M in lifetime 
-- revenue, nearly matching Gold's 25.1M from 3x as many customers. This is the single 
-- strongest argument for prioritizing retention investment on top-tier customers.
-- ===========================================================================================================

-- 2. What is the customer churn rate -- customers inactive for 90+ days?

WITH ref_date AS (
    SELECT MAX(order_date) AS max_date 
    FROM orders 
    WHERE order_status = 'Delivered' 
    AND order_date <= '2026-08-31'
)
SELECT 
    COUNT(*) AS total_customers,
    SUM(CASE WHEN days_since_last_order > 90 THEN 1 ELSE 0 END) AS churned_customers,
    ROUND(SUM(CASE WHEN days_since_last_order > 90 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS churn_rate_pct
FROM (
    SELECT 
        c.customer_id,
        DATEDIFF((SELECT max_date FROM ref_date), MAX(o.order_date)) AS days_since_last_order
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'Delivered'
    AND o.order_date <= '2026-08-31'
    GROUP BY c.customer_id
) customer_recency;

-- INSIGHT: 74.82% of customers show no order in the trailing 90 days as of the 
-- dataset's latest transaction date. This number looks alarming in isolation, but 
-- is explained by purchase frequency: customers order on average once every ~255 
-- days (see avg_orders_per_customer below), so a 90-day window will naturally flag 
-- most customers as "inactive" at any single point-in-time snapshot for an 
-- infrequent-purchase category like restaurant dining. This is NOT the same as 
-- "lost" customers -- it reflects natural reorder cadence, not attrition. A 
-- 180-270 day inactivity window would be a more actionable churn definition for 
-- this business and is recommended for the next iteration of this KPI.
-- ===========================================================================================================

-- 3. What is the promo code redemption rate and ROI?

SELECT 
    COUNT(*) AS total_orders,
    SUM(CASE WHEN promo_id IS NOT NULL THEN 1 ELSE 0 END) AS orders_with_promo,
    ROUND(SUM(CASE WHEN promo_id IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS redemption_rate_pct,
    SUM(CASE WHEN promo_id IS NOT NULL THEN discount_applied ELSE 0 END) AS total_discount_cost,
    SUM(CASE WHEN promo_id IS NOT NULL THEN final_amount ELSE 0 END) AS revenue_from_promo_orders,
    ROUND(
        SUM(CASE WHEN promo_id IS NOT NULL THEN final_amount ELSE 0 END) 
        / NULLIF(SUM(CASE WHEN promo_id IS NOT NULL THEN discount_applied ELSE 0 END), 0), 2
    ) AS roi_ratio
FROM orders
WHERE order_status = 'Delivered';

-- INSIGHT: 35.05% of all delivered orders redeem a promo code, generating 17.98M 
-- in revenue against just 373K in discount cost -- an overall ROI ratio of 48.20 
-- (every 1 rupee of discount drives ~48 rupees of order revenue). This is a very 
-- healthy ROI on paper, though it should be read alongside the "with vs without 
-- promo" AOV comparison below, which tells a more nuanced story.
-- ===========================================================================================================

-- 4. How many new customers were acquired each month?

WITH customer_first_order AS (
    SELECT 
        customer_id, 
        MIN(order_date) AS first_order_date
    FROM orders
    WHERE order_status = 'Delivered' AND order_date IS NOT NULL
    GROUP BY customer_id
)
SELECT 
    DATE_FORMAT(first_order_date, '%Y-%m') AS acquisition_month,
    COUNT(*) AS new_customers_acquired
FROM customer_first_order
GROUP BY DATE_FORMAT(first_order_date, '%Y-%m')
ORDER BY acquisition_month;

-- INSIGHT: New customer acquisition has declined sharply and consistently since 
-- launch -- from 1,195 new customers in Jan 2023 down to under 90/month by late 
-- 2025, and under 35/month through mid-2026. This is the root cause of the flat 
-- revenue trend the CEO is seeing: the business has stopped acquiring new 
-- customers at a meaningful rate and is now almost entirely dependent on its 
-- existing base. This should be the #1 priority finding for the marketing team.
-- ===========================================================================================================

-- 5. What is the repeat purchase rate -- how many customers ordered more than once?

WITH customer_order_counts AS (
    SELECT customer_id, COUNT(*) AS order_count
    FROM orders
    WHERE order_status = 'Delivered'
    GROUP BY customer_id
)
SELECT 
    COUNT(*) AS total_customers,
    SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) AS repeat_customers,
    ROUND(SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS repeat_purchase_rate_pct
FROM customer_order_counts;

-- INSIGHT: 75.30% of customers (9,076 of 12,053) have ordered more than once. 
-- Combined with the acquisition trend above, this paints a clear picture: the 
-- product/experience itself retains customers well once acquired -- the growth 
-- problem is entirely on the top-of-funnel (acquisition) side, not retention.


-- =============================================================================================
-- EDA Questions 
-- ============================================================================================

-- 1. How are customers distributed across Bronze, Silver, Gold, Platinum tiers?

SELECT 
    loyalty_tier,
    COUNT(*) AS num_customers,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_customers
FROM customers
GROUP BY loyalty_tier
ORDER BY num_customers DESC;

-- INSIGHT: The base is bottom-heavy, as expected -- Silver (44.94%) and Bronze 
-- (29.59%) together make up ~75% of all customers, while Gold (19.08%) and 
-- Platinum (6.39%) form the smaller, high-value tail. This distribution shape is 
-- healthy and typical for a loyalty program, but reinforces that most growth 
-- opportunity lies in moving Silver/Bronze customers up-tier, not just acquiring more.
-- ===================================================================================================

-- 2. Which loyalty tier spends the most on average per order?

SELECT 
    c.loyalty_tier,
    ROUND(AVG(o.final_amount), 2) AS avg_order_value
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'Delivered'
GROUP BY c.loyalty_tier
ORDER BY avg_order_value DESC;

-- INSIGHT: Platinum customers post the highest AOV (934.06), roughly double 
-- Bronze's AOV (458.31). Notably, the jump from Bronze to Silver (458 -> 807) is 
-- far larger than the jump from Silver to Gold to Platinum -- suggesting Bronze 
-- is a structurally distinct, low-engagement segment rather than simply "early-stage" 
-- Silver customers.
-- ===================================================================================================

-- 3. Which promo code was used the most?

SELECT 
    p.promo_code,
    COUNT(*) AS times_used
FROM orders o
JOIN promotions p ON o.promo_id = p.promo_id
GROUP BY p.promo_code
ORDER BY times_used DESC
LIMIT 10;

-- INSIGHT: WEEKEND200 is the most-used code (748 redemptions), but the top 10 
-- codes are tightly clustered between 718 and 748 uses -- no single promotion is 
-- a runaway outlier. This suggests promo performance is fairly evenly spread 
-- across the current campaign set rather than being driven by one exceptional offer.
-- ===================================================================================================

-- 4. Which promo type (Flat, Percentage, BOGO, Cashback) gave the best ROI?

SELECT 
    p.promo_type,
    COUNT(*) AS times_used,
    SUM(o.discount_applied) AS total_discount_cost,
    SUM(o.final_amount) AS total_revenue,
    ROUND(SUM(o.final_amount) / NULLIF(SUM(o.discount_applied), 0), 2) AS roi_ratio
FROM orders o
JOIN promotions p ON o.promo_id = p.promo_id
WHERE o.order_status = 'Delivered'
GROUP BY p.promo_type
ORDER BY roi_ratio DESC;

-- INSIGHT: Cashback delivers the strongest ROI (97.89), more than double Flat 
-- Discount (46.89) and over 7x Percentage Off (13.42) -- Percentage Off is the 
-- least capital-efficient promo type and a candidate for scaling back. BOGO and 
-- Free Delivery show a NULL ROI because their true cost (free item / delivery 
-- cost) isn't captured as a monetary discount_applied value in this dataset -- 
-- their real ROI cannot be assessed without cost data for the free item/delivery 
-- itself, which is a known data gap to flag for future tracking.
-- ===================================================================================================

-- 5. How much revenue was generated with promo vs without promo?

SELECT 
    CASE WHEN promo_id IS NOT NULL THEN 'With Promo' ELSE 'Without Promo' END AS promo_flag,
    COUNT(*) AS total_orders,
    SUM(final_amount) AS total_revenue,
    ROUND(AVG(final_amount), 2) AS avg_order_value
FROM orders
WHERE order_status = 'Delivered'
GROUP BY promo_flag;

-- INSIGHT: Counter-intuitively, orders WITHOUT a promo have a slightly HIGHER AOV 
-- (868.02) than orders with one (855.25). This suggests promos are being used 
-- primarily by price-sensitive, lower-basket-size customers rather than driving 
-- incremental large baskets -- promos may be functioning more as a discount 
-- given away on orders that would have happened anyway, rather than a true 
-- basket-size growth lever. Worth testing with a control-group approach going forward.
-- ===================================================================================================

-- 6. Which city has the most loyal customers (highest repeat orders)?

SELECT 
    c.city,
    COUNT(DISTINCT o.customer_id) AS unique_customers,
    COUNT(o.order_id) AS total_orders,
    ROUND(COUNT(o.order_id) * 1.0 / COUNT(DISTINCT o.customer_id), 2) AS avg_orders_per_customer
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'Delivered'
GROUP BY c.city
ORDER BY avg_orders_per_customer DESC;

-- INSIGHT: Mumbai customers are the most loyal by order frequency (5.24 orders/ 
-- customer on average), while Chandigarh is the lowest (4.58). The spread across 
-- all cities is narrow (4.58-5.24), indicating loyalty behavior is fairly 
-- consistent nationwide rather than being concentrated in a few standout markets.
-- ===================================================================================================

-- 7. What is the average number of orders per customer?

SELECT 
    COUNT(order_id) * 1.0 / COUNT(DISTINCT customer_id) AS avg_orders_per_customer
FROM orders
WHERE order_status = 'Delivered';

-- INSIGHT: The average customer places 4.98 orders over the ~3.5-year dataset 
-- window -- roughly one order every 8-9 months. This low frequency is the key 
-- context needed to correctly interpret the 90-day churn metric above: infrequent 
-- ordering is normal behavior for this customer base, not a sign of disengagement.
-- ===================================================================================================

-- 8. How many customers placed only 1 order and never returned?

SELECT COUNT(*) AS one_time_customers
FROM (
    SELECT customer_id
    FROM orders
    WHERE order_status = 'Delivered'
    GROUP BY customer_id
    HAVING COUNT(*) = 1
) t;

-- INSIGHT: 2,977 customers (~24.7% of the base) have ordered exactly once and 
-- never returned -- this is the direct complement of the 75.30% repeat-purchase 
-- rate. Converting even a modest share of this one-time segment into repeat 
-- customers (e.g. via a targeted second-order incentive) represents a clear, 
-- low-risk growth opportunity given the acquisition slowdown seen elsewhere.
-- ===================================================================================================

-- 9. Which age group orders the most?

SELECT 
    c.age_band,
    COUNT(o.order_id) AS total_orders,
    SUM(o.final_amount) AS total_revenue
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'Delivered'
GROUP BY c.age_band
ORDER BY total_orders DESC;

-- INSIGHT: The 25-34 age band leads both order volume (10,023 orders) and revenue 
-- (8.58M), followed closely by 45-54 and 55-64 -- order volume is fairly evenly 
-- spread across the 25-64 range rather than being concentrated in a single 
-- "young professional" segment, suggesting broad-based appeal across working-age 
-- adults rather than a niche demographic skew.
-- ===================================================================================================

-- 10. What percentage of total revenue comes from Gold and Platinum customers?

SELECT 
    SUM(CASE WHEN c.loyalty_tier IN ('Gold', 'Platinum') THEN o.final_amount ELSE 0 END) AS gold_platinum_revenue,
    SUM(o.final_amount) AS total_revenue,
    ROUND(
        SUM(CASE WHEN c.loyalty_tier IN ('Gold', 'Platinum') THEN o.final_amount ELSE 0 END) * 100.0 
        / SUM(o.final_amount), 2
    ) AS gold_platinum_pct
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'Delivered';

-- INSIGHT: Gold and Platinum customers -- just 25.47% of the customer base -- 
-- generate 72.36% of total revenue. This is a strong 80/20-style concentration 
-- and the single clearest business case for the marketing team to prioritize 
-- retention and upsell programs for top-tier customers over broad, undifferentiated 
-- acquisition spend.
