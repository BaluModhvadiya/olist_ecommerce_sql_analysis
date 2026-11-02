-- =====================================================================
-- 02_load.sql
-- Loads the raw CSVs into the schema. Run with psql from the repo root:
--   psql -d olist -f sql/02_load.sql
-- Parents are loaded before children so foreign keys are satisfied.
-- =====================================================================
SET search_path TO olist;

\copy customers            FROM 'data/olist_customers_dataset.csv'             WITH (FORMAT csv, HEADER true)
\copy sellers              FROM 'data/olist_sellers_dataset.csv'               WITH (FORMAT csv, HEADER true)
\copy category_translation FROM 'data/product_category_name_translation.csv'   WITH (FORMAT csv, HEADER true)
\copy products             FROM 'data/olist_products_dataset.csv'              WITH (FORMAT csv, HEADER true)
\copy orders               FROM 'data/olist_orders_dataset.csv'                WITH (FORMAT csv, HEADER true)
\copy order_items          FROM 'data/olist_order_items_dataset.csv'           WITH (FORMAT csv, HEADER true)
\copy order_payments       FROM 'data/olist_order_payments_dataset.csv'        WITH (FORMAT csv, HEADER true)
\copy order_reviews        FROM 'data/olist_order_reviews_dataset.csv'         WITH (FORMAT csv, HEADER true)
\copy geolocation          FROM 'data/olist_geolocation_dataset.csv'           WITH (FORMAT csv, HEADER true)

ANALYZE;

-- Row-count check
SELECT 'customers' AS table_name, COUNT(*) FROM customers
UNION ALL SELECT 'sellers',        COUNT(*) FROM sellers
UNION ALL SELECT 'products',       COUNT(*) FROM products
UNION ALL SELECT 'orders',         COUNT(*) FROM orders
UNION ALL SELECT 'order_items',    COUNT(*) FROM order_items
UNION ALL SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL SELECT 'order_reviews',  COUNT(*) FROM order_reviews
UNION ALL SELECT 'geolocation',    COUNT(*) FROM geolocation;
