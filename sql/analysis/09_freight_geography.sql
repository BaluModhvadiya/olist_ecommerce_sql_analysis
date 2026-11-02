-- =====================================================================
-- 09 · Freight cost by region
-- Question: Is shipping cost a barrier for customers far from the
--           seller hub in São Paulo?
-- Skills: grouping into business regions with CASE, ratio metrics,
--         comparing to a baseline region
-- =====================================================================
SET search_path TO olist;

WITH regional AS (
    SELECT
        CASE
            WHEN customer_state IN ('SP')                              THEN '1. São Paulo state'
            WHEN customer_state IN ('RJ','MG','ES')                    THEN '2. Rest of Southeast'
            WHEN customer_state IN ('PR','SC','RS')                    THEN '3. South'
            WHEN customer_state IN ('DF','GO','MT','MS')               THEN '4. Center-West'
            WHEN customer_state IN ('BA','PE','CE','MA','PB','RN','AL','PI','SE') THEN '5. Northeast'
            ELSE                                                            '6. North'
        END AS region,
        *
    FROM v_delivered
)
SELECT
    region,
    COUNT(*)                                                         AS orders,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)               AS pct_orders,
    ROUND(AVG(items_value), 2)                                       AS avg_basket,
    ROUND(AVG(freight_value), 2)                                     AS avg_freight,
    ROUND(100.0 * SUM(freight_value) / SUM(items_value), 1)          AS freight_pct_of_basket,
    ROUND(AVG(delivery_days), 1)                                     AS avg_delivery_days,
    ROUND(100.0 * AVG(is_late::int), 1)                              AS pct_late,
    ROUND(AVG(review_score), 2)                                      AS avg_review
FROM regional
GROUP BY region
ORDER BY region;
