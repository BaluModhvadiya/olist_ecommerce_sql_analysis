-- =====================================================================
-- 03 · Customer retention & cohorts
-- Question: Do customers come back after their first purchase?
-- Skills: first-touch attribution with MIN() OVER, cohort indexing with
--         AGE(), pivoting with FILTER, retention percentages
-- =====================================================================
SET search_path TO olist;

-- 3a. Overall repeat-purchase rate
WITH per_customer AS (
    SELECT customer_id, COUNT(*) AS n_orders, SUM(items_value) AS spend
    FROM v_sales
    GROUP BY customer_id
)
SELECT
    COUNT(*)                                                       AS customers,
    COUNT(*) FILTER (WHERE n_orders > 1)                           AS repeat_customers,
    ROUND(100.0 * COUNT(*) FILTER (WHERE n_orders > 1) / COUNT(*), 2) AS repeat_rate_pct,
    ROUND(100.0 * SUM(spend) FILTER (WHERE n_orders > 1) / SUM(spend), 2) AS gmv_share_from_repeaters_pct
FROM per_customer;

-- 3b. Monthly cohort retention matrix (months 0-6)
--     % of each first-purchase cohort that ordered again N months later
WITH orders_with_cohort AS (
    SELECT
        customer_id,
        order_month,
        MIN(order_month) OVER (PARTITION BY customer_id) AS cohort_month
    FROM v_sales
),
indexed AS (
    SELECT DISTINCT
        customer_id,
        cohort_month,
        (EXTRACT(YEAR  FROM AGE(order_month, cohort_month)) * 12
       + EXTRACT(MONTH FROM AGE(order_month, cohort_month)))::int AS month_n
    FROM orders_with_cohort
),
cohort_size AS (
    SELECT cohort_month, COUNT(DISTINCT customer_id) AS size
    FROM indexed WHERE month_n = 0
    GROUP BY cohort_month
)
SELECT
    i.cohort_month,
    s.size AS cohort_customers,
    ROUND(100.0 * COUNT(DISTINCT customer_id) FILTER (WHERE month_n = 1) / s.size, 2) AS m1,
    ROUND(100.0 * COUNT(DISTINCT customer_id) FILTER (WHERE month_n = 2) / s.size, 2) AS m2,
    ROUND(100.0 * COUNT(DISTINCT customer_id) FILTER (WHERE month_n = 3) / s.size, 2) AS m3,
    ROUND(100.0 * COUNT(DISTINCT customer_id) FILTER (WHERE month_n = 4) / s.size, 2) AS m4,
    ROUND(100.0 * COUNT(DISTINCT customer_id) FILTER (WHERE month_n = 5) / s.size, 2) AS m5,
    ROUND(100.0 * COUNT(DISTINCT customer_id) FILTER (WHERE month_n = 6) / s.size, 2) AS m6
FROM indexed i
JOIN cohort_size s USING (cohort_month)
GROUP BY i.cohort_month, s.size
ORDER BY i.cohort_month;

-- 3c. Does first-order experience predict coming back?
--     Repeat rate by the review score a customer gave on their FIRST order
WITH ranked AS (
    SELECT
        customer_id,
        review_score,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY purchased_at) AS rn,
        COUNT(*)     OVER (PARTITION BY customer_id)                        AS n_orders
    FROM v_sales
)
SELECT
    review_score                                                    AS first_order_review,
    COUNT(*)                                                        AS customers,
    ROUND(100.0 * AVG((n_orders > 1)::int), 2)                      AS repeat_rate_pct
FROM ranked
WHERE rn = 1 AND review_score IS NOT NULL
GROUP BY review_score
ORDER BY review_score;
