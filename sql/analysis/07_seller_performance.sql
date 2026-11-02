-- =====================================================================
-- 07 · Seller concentration & quality
-- Question: How dependent are we on a few sellers? Which high-volume
--           sellers are damaging the customer experience?
-- Skills: PERCENT_RANK / NTILE buckets, HAVING thresholds,
--         flagging outliers against the platform average
-- =====================================================================
SET search_path TO olist;

-- 7a. Seller concentration: GMV share by seller percentile
WITH seller_gmv AS (
    SELECT oi.seller_id, SUM(oi.price) AS gmv
    FROM order_items oi
    JOIN v_sales s ON s.order_id = oi.order_id
    GROUP BY oi.seller_id
),
bucketed AS (
    SELECT *,
        CASE
            WHEN PERCENT_RANK() OVER (ORDER BY gmv DESC) < 0.01 THEN '1. Top 1%'
            WHEN PERCENT_RANK() OVER (ORDER BY gmv DESC) < 0.10 THEN '2. Next 9% (top 10%)'
            WHEN PERCENT_RANK() OVER (ORDER BY gmv DESC) < 0.50 THEN '3. Next 40%'
            ELSE                                                     '4. Bottom 50%'
        END AS seller_tier
    FROM seller_gmv
)
SELECT
    seller_tier,
    COUNT(*)                                             AS sellers,
    ROUND(SUM(gmv), 0)                                   AS gmv_brl,
    ROUND(100.0 * SUM(gmv) / SUM(SUM(gmv)) OVER (), 1)   AS pct_gmv
FROM bucketed
GROUP BY seller_tier
ORDER BY seller_tier;

-- 7b. Problem sellers: 100+ delivered orders and a review average
--     well below the platform. These are the accounts to manage first.
WITH seller_orders AS (
    SELECT DISTINCT oi.seller_id, d.order_id, d.review_score, d.is_late, d.items_value
    FROM order_items oi
    JOIN v_delivered d ON d.order_id = oi.order_id
    WHERE d.n_sellers = 1                -- attribute the review to one seller
      AND d.review_score IS NOT NULL
),
platform AS (
    SELECT AVG(review_score) AS avg_review FROM seller_orders
)
SELECT
    so.seller_id,
    s.seller_state,
    COUNT(*)                                          AS orders,
    ROUND(AVG(so.review_score), 2)                    AS avg_review,
    ROUND(AVG(so.review_score) - p.avg_review, 2)     AS vs_platform,
    ROUND(100.0 * AVG((so.review_score <= 2)::int), 1) AS pct_negative,
    ROUND(100.0 * AVG(so.is_late::int), 1)            AS pct_late
FROM seller_orders so
JOIN sellers s USING (seller_id)
CROSS JOIN platform p
GROUP BY so.seller_id, s.seller_state, p.avg_review
HAVING COUNT(*) >= 100
   AND AVG(so.review_score) < p.avg_review - 0.4
ORDER BY orders DESC;

-- 7c. Category dependence on a single seller
--     For each category (300+ orders): how much of it does the biggest
--     seller handle, and is that seller better or worse than the rest?
WITH cat_seller AS (
    SELECT
        COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category,
        oi.seller_id,
        COUNT(DISTINCT d.order_id)  AS orders,
        AVG(d.review_score)         AS avg_review
    FROM order_items oi
    JOIN products p     ON p.product_id = oi.product_id
    LEFT JOIN category_translation t ON t.product_category_name = p.product_category_name
    JOIN v_delivered d  ON d.order_id = oi.order_id
    WHERE d.review_score IS NOT NULL
    GROUP BY 1, 2
),
ranked AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY category ORDER BY orders DESC) AS rn,
        SUM(orders)  OVER (PARTITION BY category)                      AS cat_orders,
        -- review average of everyone EXCEPT this seller
        (SUM(avg_review * orders) OVER (PARTITION BY category) - avg_review * orders)
          / NULLIF(SUM(orders) OVER (PARTITION BY category) - orders, 0) AS others_avg_review
    FROM cat_seller
)
SELECT
    category,
    cat_orders,
    seller_id                                   AS top_seller,
    ROUND(100.0 * orders / cat_orders, 1)       AS top_seller_share_pct,
    ROUND(avg_review, 2)                        AS top_seller_review,
    ROUND(others_avg_review, 2)                 AS rest_of_category_review
FROM ranked
WHERE rn = 1 AND cat_orders >= 300
ORDER BY top_seller_share_pct DESC
LIMIT 10;
