-- Product Manager
-- =================================================================================== 


-- KPI's 

-- 1. What are the top 10 best-selling menu items by quantity sold?
SELECT 
    m.item_name,
    m.category,
    SUM(oi.quantity) AS total_quantity_sold,
    ROUND(SUM(oi.subtotal), 2) AS total_revenue
FROM order_items oi
JOIN menu_items m ON oi.item_id = m.item_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'Delivered'
GROUP BY m.item_id, m.item_name, m.category
ORDER BY total_quantity_sold DESC
LIMIT 10; 

-- BUSINESS INSIGHT: 
-- Chicken Biryani is our #1 best-seller, driving both the highest order volume and the most revenue.
-- Sales numbers are incredibly even across the entire top 10 list, which shows our menu is highly balanced and customers enjoy a wide variety of categories.
-- ===============================================================================

-- 2. What is the profit margin per item — (price - cost) / price × 100?
SELECT 
    item_name,
    category,
    price,
    cost_price,
    ROUND(((price - cost_price) / price) * 100, 2) AS profit_margin_percentage
FROM menu_items
ORDER BY profit_margin_percentage DESC;

-- BUSINESS INSIGHT: 
-- Gajar Ka Halwa and Farmhouse Pizza are our most profitable items, yielding margins close to 65%.
-- Overall, profitability is exceptionally strong and stable, with almost all menu items maintaining healthy margins around 60%.
-- ===============================================================================

-- 3. Which food category generates the most revenue?
SELECT 
    m.category,
    ROUND(SUM(oi.subtotal), 2) AS total_revenue
FROM order_items oi
JOIN menu_items m ON oi.item_id = m.item_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'Delivered'
GROUP BY m.category
ORDER BY total_revenue DESC;

-- BUSINESS INSIGHT: 
-- "Main Course" is our absolute powerhouse, generating over ₹1.5 crore (15M) and nearly doubling the revenue of the second-place category.
-- "Starters," "Pizza," and "Rice & Biryani" make up a very strong middle tier, each bringing in between ₹6.9M and ₹8.1M.
-- ===============================================================================

-- 4. Which items are the bottom 5 by sales — candidates for removal?
SELECT 
    m.item_name,
    m.category,
    SUM(oi.quantity) AS total_quantity_sold,
    ROUND(SUM(oi.subtotal), 2) AS total_revenue
FROM order_items oi
JOIN menu_items m ON oi.item_id = m.item_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'Delivered'
GROUP BY m.item_id, m.item_name, m.category
ORDER BY total_quantity_sold ASC
LIMIT 5;

-- BUSINESS INSIGHT: 
-- Even our bottom 5 items sell nearly 5,000 units each, meaning we have no true "dead weight" on the menu.
-- We must be careful not to cut based on volume alone: Hyderabadi Biryani is in the bottom 5 for quantity but still brings in massive revenue (₹1.47M).
-- ===============================================================================

-- 5. What is the average order value per food category?
SELECT 
    m.category,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    ROUND(SUM(oi.subtotal) / COUNT(DISTINCT oi.order_id), 2) AS avg_order_value
FROM order_items oi
JOIN menu_items m ON oi.item_id = m.item_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'Delivered'
GROUP BY m.category
ORDER BY avg_order_value DESC;

-- BUSINESS INSIGHT: 
-- Pizza drives the highest Average Order Value at ₹608, making it a prime candidate for premium promotions.
-- Main Course remains our strongest anchor, combining massive volume (27k+ orders) with a very healthy AOV (₹553).
-- Consider creating combo meals with lower-ticket items like Beverages and Sides to increase their transaction value.
-- ===============================================================================

-- ==============================================================
-- EDA Questions 
-- ======================================================

-- 1. Which menu item is ordered the most across all outlets?
SELECT 
    m.item_name,
    m.category,
    SUM(oi.quantity) AS total_quantity_ordered,
    COUNT(DISTINCT o.outlet_id) AS outlets_sold_at
FROM order_items oi
JOIN menu_items m ON oi.item_id = m.item_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'Delivered'
GROUP BY m.item_id, m.item_name, m.category
ORDER BY total_quantity_ordered DESC
LIMIT 5;

-- BUSINESS INSIGHT: 
-- Chicken Biryani is our universal top performer, though it barely edges out Hakka Noodles by just two orders.
-- Impressively, all of our top 5 items have 100% menu penetration, being successfully sold across all 50 outlets.
-- This confirms our core menu has broad, consistent appeal regardless of the specific outlet or geographic location.
-- ===============================================================================

-- 2. Which category — Starters, Mains, Drinks, Desserts — sells the most?
SELECT 
    m.category,
    SUM(oi.quantity) AS total_quantity_sold,
    ROUND(SUM(oi.subtotal), 2) AS total_revenue
FROM order_items oi
JOIN menu_items m ON oi.item_id = m.item_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'Delivered'
GROUP BY m.category
ORDER BY total_quantity_sold DESC;

-- BUSINESS INSIGHT: 
-- Main Course is the absolute core of the business, moving over 63,000 units and vastly outperforming all other categories.
-- Starters and South Indian form a solid second tier in volume (~36k units each), though Starters yield nearly double the revenue.
-- With Beverages sitting near the bottom, there is a clear opportunity for the Product Manager to boost volume by bundling drinks with the top-selling Mains.
-- ===============================================================================

-- 3. Which item has the highest profit margin?
SELECT 
    item_name,
    category,
    price,
    cost_price,
    ROUND(((price - cost_price) / price) * 100, 2) AS profit_margin_percentage
FROM menu_items
ORDER BY profit_margin_percentage DESC
LIMIT 1;

-- BUSINESS INSIGHT: 
-- Gajar Ka Halwa is our most profitable item, boasting an impressive 64.82% profit margin.
-- With a low production cost of ₹35.18 and a selling price of ₹100, this dessert is a highly efficient bottom-line driver.
-- We should aggressively promote this as a checkout add-on to maximize overall order profitability.
-- ===============================================================================

-- 4. Which items are frequently ordered together in the same order?
SELECT 
    m1.item_name AS item_1,
    m2.item_name AS item_2,
    COUNT(*) AS times_ordered_together
FROM order_items oi1
JOIN order_items oi2 ON oi1.order_id = oi2.order_id AND oi1.item_id < oi2.item_id
JOIN menu_items m1 ON oi1.item_id = m1.item_id
JOIN menu_items m2 ON oi2.item_id = m2.item_id
JOIN orders o ON oi1.order_id = o.order_id
WHERE o.order_status = 'Delivered'
GROUP BY m1.item_name, m2.item_name
ORDER BY times_ordered_together DESC
LIMIT 10;

-- BUSINESS INSIGHT: 
-- Cross-category pairings dominate our top combinations, such as pairing a Main Course with a Dessert (Paneer Butter Masala & Rasmalai) or a Wrap (Dal Makhani & Egg Roll).
-- Since these top pairs all have very similar order volumes (~125 times), implementing a "Frequently Bought Together" recommendation carousel at checkout using these exact matches will highly convert.
-- Packaging these specific pairs into named "Combo Meals" is a straightforward strategy to drive up our overall Average Order Value.
-- ===============================================================================

-- 5. How does item popularity differ between Dine-In, Takeaway, and Online?
WITH RankedItems AS (
    SELECT 
        o.order_type,
        m.item_name,
        m.category,
        SUM(oi.quantity) AS total_quantity_sold,
        ROUND(SUM(oi.subtotal), 2) AS total_revenue,
        DENSE_RANK() OVER (
            PARTITION BY o.order_type 
            ORDER BY SUM(oi.quantity) DESC
        ) AS rank_in_channel
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN menu_items m ON oi.item_id = m.item_id
    WHERE o.order_status = 'Delivered'
    GROUP BY o.order_type, m.item_id, m.item_name, m.category
)
SELECT 
    order_type,
    rank_in_channel,
    item_name,
    category,
    total_quantity_sold,
    total_revenue
FROM RankedItems
WHERE rank_in_channel <= 5
ORDER BY order_type, rank_in_channel;


-- BUSINESS INSIGHT: 
-- Customer preferences shift dramatically by channel: Delivery is dominated by heavy Main Courses, while Dine-In drives our Beverage and quick-bite sales (Masala Chai, Idli Sambar).
-- Takeaway has a highly unique profile, led surprisingly by a dessert (Rasmalai) alongside heavy rice comfort foods (Biryani, Rajma Chawal).
-- We should customize our digital and physical menus to prominently feature these specific channel-winners based on how the customer is ordering.
-- ===============================================================================

