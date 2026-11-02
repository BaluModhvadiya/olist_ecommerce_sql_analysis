-- =====================================================================
-- 02 · Monthly growth trend
-- Question: Is the business growing, and is growth slowing down?
-- Skills: CTEs, LAG() for month-over-month, rolling average window,
--         self-comparison for year-over-year
-- =====================================================================
SET search_path TO olist;

WITH monthly AS (
    SELECT
        order_month,
        COUNT(*)                    AS orders,
        COUNT(DISTINCT customer_id) AS customers,
        SUM(items_value)            AS gmv
    FROM v_sales
    GROUP BY order_month
)
SELECT
    order_month,
    orders,
    customers,
    ROUND(gmv, 0)                                             AS gmv_brl,
    ROUND(gmv / orders, 2)                                    AS aov,
    ROUND(100.0 * (gmv / LAG(gmv) OVER w - 1), 1)             AS gmv_mom_pct,
    ROUND(AVG(gmv) OVER (w ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 0)
                                                              AS gmv_3m_rolling_avg,
    ROUND(100.0 * (gmv / LAG(gmv, 12) OVER w - 1), 1)         AS gmv_yoy_pct
FROM monthly
WINDOW w AS (ORDER BY order_month)
ORDER BY order_month;

-- Year-over-year on the comparable window (Jan-Aug 2018 vs Jan-Aug 2017)
SELECT
    ROUND(SUM(items_value) FILTER (WHERE order_month BETWEEN '2018-01-01' AND '2018-08-01'), 0) AS gmv_2018_jan_aug,
    ROUND(SUM(items_value) FILTER (WHERE order_month BETWEEN '2017-01-01' AND '2017-08-01'), 0) AS gmv_2017_jan_aug,
    ROUND(100.0 * (
        SUM(items_value) FILTER (WHERE order_month BETWEEN '2018-01-01' AND '2018-08-01')
      / SUM(items_value) FILTER (WHERE order_month BETWEEN '2017-01-01' AND '2017-08-01') - 1), 1) AS yoy_growth_pct
FROM v_sales;
