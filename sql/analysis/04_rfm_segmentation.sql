-- =====================================================================
-- 04 · RFM customer segmentation
-- Question: Who are our most valuable customers, and who are we losing?
-- Skills: NTILE() scoring, CASE-based segmentation, share-of-total
--         with SUM() OVER ()
--
-- Note: with ~97% one-time buyers, Frequency has little spread, so it is
-- scored as 1 (one order) / 3 (two orders) / 5 (three+) instead of NTILE.
-- =====================================================================
SET search_path TO olist;

WITH snapshot AS (
    SELECT MAX(purchased_at)::date + 1 AS as_of FROM v_sales
),
rfm AS (
    SELECT
        customer_id,
        (SELECT as_of FROM snapshot) - MAX(purchased_at)::date AS recency_days,
        COUNT(*)                                               AS frequency,
        SUM(items_value)                                       AS monetary
    FROM v_sales
    GROUP BY customer_id
),
scored AS (
    SELECT
        *,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,   -- recent = 5
        CASE WHEN frequency = 1 THEN 1
             WHEN frequency = 2 THEN 3
             ELSE 5 END                            AS f_score,
        NTILE(5) OVER (ORDER BY monetary)          AS m_score    -- high spend = 5
    FROM rfm
),
segmented AS (
    SELECT
        *,
        CASE
            WHEN f_score >= 3 AND r_score >= 4                 THEN 'Champions'
            WHEN f_score >= 3                                  THEN 'Loyal - slipping'
            WHEN r_score >= 4 AND m_score >= 4                 THEN 'New big spenders'
            WHEN r_score >= 4                                  THEN 'New customers'
            WHEN r_score <= 2 AND m_score >= 4                 THEN 'High-value at risk'
            WHEN r_score <= 2                                  THEN 'Lost low-value'
            ELSE 'Needs attention'
        END AS segment
    FROM scored
)
SELECT
    segment,
    COUNT(*)                                                    AS customers,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)          AS pct_customers,
    ROUND(SUM(monetary), 0)                                     AS gmv_brl,
    ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 1) AS pct_gmv,
    ROUND(AVG(monetary), 2)                                     AS avg_spend,
    ROUND(AVG(recency_days), 0)                                 AS avg_recency_days
FROM segmented
GROUP BY segment
ORDER BY gmv_brl DESC;
