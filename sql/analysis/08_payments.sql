-- =====================================================================
-- 08 · Payment behaviour
-- Question: How do customers pay, and do installments enable bigger
--           baskets?
-- Skills: joining a one-to-many table safely, bucketing, ratio analysis
-- =====================================================================
SET search_path TO olist;

-- 8a. Payment method mix (by value)
SELECT
    p.payment_type,
    COUNT(DISTINCT p.order_id)                                   AS orders,
    ROUND(SUM(p.payment_value), 0)                               AS paid_brl,
    ROUND(100.0 * SUM(p.payment_value) / SUM(SUM(p.payment_value)) OVER (), 1) AS pct_value
FROM order_payments p
JOIN v_sales s ON s.order_id = p.order_id
GROUP BY p.payment_type
ORDER BY paid_brl DESC;

-- 8b. Credit card installments vs order value
--     (orders paid with a single credit-card payment, to keep it clean)
WITH cc AS (
    SELECT p.order_id, p.payment_installments, s.items_value
    FROM order_payments p
    JOIN v_sales s ON s.order_id = p.order_id
    WHERE p.payment_type = 'credit_card'
      AND p.order_id IN (SELECT order_id FROM order_payments
                         GROUP BY order_id HAVING COUNT(*) = 1)
)
SELECT
    CASE
        WHEN payment_installments <= 1 THEN '1. Paid in full'
        WHEN payment_installments <= 3 THEN '2. 2-3 installments'
        WHEN payment_installments <= 6 THEN '3. 4-6 installments'
        ELSE                                '4. 7+ installments'
    END                                                    AS installment_plan,
    COUNT(*)                                               AS orders,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)     AS pct_orders,
    ROUND(AVG(items_value), 2)                             AS avg_order_value,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY items_value)::numeric, 2) AS median_order_value
FROM cc
GROUP BY 1
ORDER BY 1;
