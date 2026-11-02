-- =====================================================================
-- 06 · Category performance & Pareto
-- Question: Which categories drive revenue, and which hurt satisfaction?
-- Skills: multi-table joins at item grain, COALESCE for missing
--         translations, cumulative share with running SUM() OVER
-- =====================================================================
SET search_path TO olist;

-- 6a. Revenue Pareto: how concentrated is GMV across categories?
WITH cat AS (
    SELECT
        COALESCE(t.product_category_name_english,
                 p.product_category_name, 'unknown')   AS category,
        SUM(oi.price)                                  AS gmv,
        COUNT(DISTINCT oi.order_id)                    AS orders
    FROM order_items oi
    JOIN v_sales s           ON s.order_id = oi.order_id
    JOIN products p          ON p.product_id = oi.product_id
    LEFT JOIN category_translation t
                             ON t.product_category_name = p.product_category_name
    GROUP BY 1
)
SELECT
    category,
    orders,
    ROUND(gmv, 0)                                                     AS gmv_brl,
    ROUND(100.0 * gmv / SUM(gmv) OVER (), 1)                          AS pct_gmv,
    ROUND(100.0 * SUM(gmv) OVER (ORDER BY gmv DESC) / SUM(gmv) OVER (), 1) AS cumulative_pct_gmv,
    ROW_NUMBER() OVER (ORDER BY gmv DESC)                             AS gmv_rank
FROM cat
ORDER BY gmv DESC;

-- 6b. Satisfaction by category (top 20 by orders): where are the problems?
--     Single-category orders only, so a review is attributed cleanly.
WITH single_cat_orders AS (
    SELECT oi.order_id,
           MIN(COALESCE(t.product_category_name_english, p.product_category_name, 'unknown')) AS category
    FROM order_items oi
    JOIN products p ON p.product_id = oi.product_id
    LEFT JOIN category_translation t ON t.product_category_name = p.product_category_name
    GROUP BY oi.order_id
    HAVING COUNT(DISTINCT COALESCE(p.product_category_name, 'unknown')) = 1
)
SELECT
    sc.category,
    COUNT(*)                                            AS orders,
    ROUND(AVG(d.review_score), 2)                       AS avg_review,
    ROUND(100.0 * AVG((d.review_score <= 2)::int), 1)   AS pct_negative,
    ROUND(100.0 * AVG(d.is_late::int), 1)               AS pct_late,
    ROUND(AVG(d.freight_value / NULLIF(d.items_value, 0)) * 100, 1) AS freight_pct_of_price
FROM v_delivered d
JOIN single_cat_orders sc ON sc.order_id = d.order_id
WHERE d.review_score IS NOT NULL
GROUP BY sc.category
ORDER BY COUNT(*) DESC
LIMIT 20;
