-- =====================================================================
-- 05 · Delivery performance vs customer satisfaction
-- Question: What drives bad reviews? How much does late delivery hurt?
-- Skills: bucketing with CASE, comparing groups, ranking states
-- =====================================================================
SET search_path TO olist;

-- 5a. Review score by delivery outcome
SELECT
    CASE
        WHEN days_late <= -10 THEN '1. 10+ days early'
        WHEN days_late <= -1  THEN '2. 1-9 days early'
        WHEN days_late =  0   THEN '3. On the promised day'
        WHEN days_late <= 3   THEN '4. 1-3 days late'
        WHEN days_late <= 7   THEN '5. 4-7 days late'
        ELSE                       '6. 8+ days late'
    END                                                         AS delivery_outcome,
    COUNT(*)                                                    AS orders,
    ROUND(AVG(review_score), 2)                                 AS avg_review,
    ROUND(100.0 * AVG((review_score = 1)::int), 1)              AS pct_1_star,
    ROUND(100.0 * AVG((review_score = 5)::int), 1)              AS pct_5_star
FROM v_delivered
WHERE review_score IS NOT NULL
GROUP BY 1
ORDER BY 1;

-- 5b. On-time vs late, headline comparison
SELECT
    CASE WHEN is_late THEN 'Late' ELSE 'On time / early' END    AS status,
    COUNT(*)                                                    AS orders,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)          AS pct_orders,
    ROUND(AVG(review_score), 2)                                 AS avg_review,
    ROUND(100.0 * AVG((review_score <= 2)::int), 1)             AS pct_negative
FROM v_delivered
WHERE review_score IS NOT NULL
GROUP BY 1;

-- 5c. Share of ALL negative reviews (1-2 stars) explained by lateness
SELECT
    COUNT(*) FILTER (WHERE review_score <= 2)                    AS negative_reviews,
    COUNT(*) FILTER (WHERE review_score <= 2 AND is_late)        AS negative_and_late,
    ROUND(100.0 * COUNT(*) FILTER (WHERE review_score <= 2 AND is_late)
               / COUNT(*) FILTER (WHERE review_score <= 2), 1)  AS pct_negative_that_were_late
FROM v_delivered;

-- 5d. Late-delivery rate by customer state (states with 1,000+ orders)
SELECT
    customer_state,
    COUNT(*)                                             AS orders,
    ROUND(AVG(delivery_days), 1)                         AS avg_delivery_days,
    ROUND(AVG(promised_days), 1)                         AS avg_promised_days,
    ROUND(100.0 * AVG(is_late::int), 1)                  AS pct_late,
    ROUND(AVG(review_score), 2)                          AS avg_review,
    RANK() OVER (ORDER BY AVG(is_late::int) DESC)        AS lateness_rank
FROM v_delivered
GROUP BY customer_state
HAVING COUNT(*) >= 1000
ORDER BY pct_late DESC;
