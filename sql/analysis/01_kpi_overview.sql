-- =====================================================================
-- 01 · Business KPI overview
-- Question: How big is the business and how healthy is it at a glance?
-- Skills: aggregation, FILTER clause, conditional averages
-- =====================================================================
SET search_path TO olist;

SELECT
    COUNT(*)                                            AS orders,
    COUNT(DISTINCT customer_id)                         AS customers,
    ROUND(SUM(items_value), 0)                          AS gmv_brl,          -- product sales
    ROUND(SUM(freight_value), 0)                        AS freight_brl,
    ROUND(AVG(items_value), 2)                          AS avg_order_value,
    ROUND(SUM(freight_value) / SUM(items_value) * 100, 1) AS freight_pct_of_gmv,
    ROUND(AVG(n_items), 2)                              AS avg_items_per_order,
    ROUND(AVG(review_score), 2)                         AS avg_review_score,
    ROUND(100.0 * COUNT(*) FILTER (WHERE review_score <= 2)
          / COUNT(review_score), 1)                     AS pct_negative_reviews,
    ROUND(100.0 * AVG(is_late::int)
          FILTER (WHERE order_status = 'delivered'), 1) AS pct_delivered_late
FROM v_sales;
