-- =====================================================================
-- 03_views.sql
-- Analytical layer: one clean, order-level fact view that every
-- analysis query builds on. Keeps business logic in ONE place.
--
-- Analysis window: 2017-01-01 to 2018-08-31 (20 complete months).
-- 2016 has only ~330 orders (platform launch / test data) and
-- Sep-Oct 2018 has 20 orders (dataset cut-off), so both are excluded
-- to avoid distorting trends.
-- =====================================================================
SET search_path TO olist;

-- Item-level aggregates per order
CREATE OR REPLACE VIEW v_order_items_agg AS
SELECT
    order_id,
    COUNT(*)                    AS n_items,
    COUNT(DISTINCT seller_id)   AS n_sellers,
    SUM(price)                  AS items_value,
    SUM(freight_value)          AS freight_value
FROM order_items
GROUP BY order_id;

-- A handful of orders have more than one review: keep the latest one
CREATE OR REPLACE VIEW v_order_review AS
SELECT DISTINCT ON (order_id)
    order_id,
    review_score,
    (review_comment_message IS NOT NULL) AS has_comment
FROM order_reviews
ORDER BY order_id, review_answer_timestamp DESC NULLS LAST;

-- Main fact view: one row per order
CREATE OR REPLACE VIEW v_orders AS
SELECT
    o.order_id,
    c.customer_unique_id                                 AS customer_id,
    c.customer_state,
    o.order_status,
    o.order_purchase_timestamp                           AS purchased_at,
    DATE_TRUNC('month', o.order_purchase_timestamp)::date AS order_month,
    i.n_items,
    i.n_sellers,
    i.items_value,
    i.freight_value,
    i.items_value + i.freight_value                      AS order_value,
    -- delivery metrics (only meaningful for delivered orders)
    o.order_delivered_customer_date::date
        - o.order_purchase_timestamp::date               AS delivery_days,
    o.order_estimated_delivery_date::date
        - o.order_purchase_timestamp::date               AS promised_days,
    o.order_delivered_customer_date::date
        - o.order_estimated_delivery_date::date          AS days_late,     -- >0 = late
    (o.order_delivered_customer_date::date
        > o.order_estimated_delivery_date::date)         AS is_late,
    r.review_score,
    r.has_comment
FROM orders o
JOIN customers c          ON c.customer_id = o.customer_id
LEFT JOIN v_order_items_agg i ON i.order_id = o.order_id
LEFT JOIN v_order_review r    ON r.order_id = o.order_id
WHERE o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01';

-- Revenue-bearing orders: excludes canceled/unavailable and orders
-- with no items (these never generated sales)
CREATE OR REPLACE VIEW v_sales AS
SELECT *
FROM v_orders
WHERE order_status NOT IN ('canceled', 'unavailable')
  AND items_value IS NOT NULL;

-- Delivered orders with a known delivery date (for logistics analysis)
CREATE OR REPLACE VIEW v_delivered AS
SELECT *
FROM v_sales
WHERE order_status = 'delivered'
  AND delivery_days IS NOT NULL;
