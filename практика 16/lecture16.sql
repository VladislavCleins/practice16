-- A. Зерно
SELECT COUNT(*) AS facts, COUNT(DISTINCT order_id) AS orders FROM l16_fact_sales;
SELECT COUNT(*) AS versions FROM l16_dim_customer;

-- B. История клиента 1610005
SELECT customer_sk, region, segment, valid_from, valid_to FROM l16_dim_customer WHERE customer_id = 1610005 ORDER BY valid_from;
SELECT c.customer_sk, c.region, COUNT(*) AS items, SUM(f.net_amount) AS revenue
FROM l16_fact_sales f JOIN l16_dim_customer c USING (customer_sk)
WHERE c.customer_id = 1610005 GROUP BY c.customer_sk, c.region ORDER BY 1;

-- C. SCD Type 1
SELECT l16_correct_customer_name(1610005, 'Клиент 005 — имя уточнено');
SELECT customer_sk, customer_name, valid_from, valid_to FROM l16_dim_customer WHERE customer_id = 1610005 ORDER BY valid_from;

-- D. SCD Type 2
SELECT l16_change_customer_scd2(1610001, 'Центр', 'VIP', DATE '2025-03-15');
SELECT customer_sk, region, segment, valid_from, valid_to, is_current FROM l16_dim_customer WHERE customer_id = 1610001 ORDER BY valid_from;
SELECT COUNT(*) AS versions FROM l16_dim_customer;
SELECT COUNT(*) AS facts FROM l16_fact_sales;
SELECT * FROM l16_v_customer_period_issues;

-- E. Два поздних заказа
INSERT INTO l16_src_orders (order_id, customer_id, order_date, order_status)
VALUES (1669001, 1610001, '2025-02-10', 'paid'), (1669002, 1610001, '2025-04-20', 'paid')
ON CONFLICT (order_id) DO NOTHING;
INSERT INTO l16_src_order_items (order_id, line_no, product_id, quantity, unit_price, discount_pct)
VALUES (1669001, 1, 1620001, 2, 127.00, 0), (1669002, 1, 1620002, 3, 46.20, 0)
ON CONFLICT (order_id, line_no) DO NOTHING;
SELECT l16_refresh_facts();
SELECT f.order_id, f.net_amount, c.region, c.valid_from, c.valid_to
FROM l16_fact_sales f JOIN l16_dim_customer c USING (customer_sk)
WHERE f.order_id IN (1669001, 1669002) ORDER BY f.order_id;
SELECT COUNT(*) AS facts FROM l16_fact_sales;

-- F. Исторический регион и текущий регион
SELECT c.region AS historical_region, SUM(f.net_amount) AS revenue
FROM l16_fact_sales f JOIN l16_dim_customer c USING (customer_sk)
WHERE f.order_status = 'paid' GROUP BY 1 ORDER BY 1;
SELECT sc.region AS current_region, SUM(f.net_amount) AS revenue
FROM l16_fact_sales f
JOIN l16_dim_customer c USING (customer_sk)
JOIN l16_src_customers sc ON sc.customer_id = c.customer_id
WHERE f.order_status = 'paid' GROUP BY 1 ORDER BY 1;

-- G. Повтор ETL
SELECT l16_refresh_facts() AS should_be_zero;
SELECT (SELECT SUM(round(i.quantity * i.unit_price * (1 - i.discount_pct), 2))
        FROM l16_src_order_items i JOIN l16_src_orders o USING (order_id) WHERE o.order_status = 'paid') AS source_sum,
       (SELECT SUM(net_amount) FROM l16_fact_sales WHERE order_status = 'paid') AS fact_sum;

-- H. Исправление статуса
SELECT order_id, line_no, order_status, net_amount FROM l16_fact_sales WHERE order_id = 1660008 ORDER BY line_no;
UPDATE l16_src_orders SET order_status = 'paid' WHERE order_id = 1660008;
SELECT l16_refresh_facts() AS changed_rows;
SELECT order_id, line_no, order_status, net_amount FROM l16_fact_sales WHERE order_id = 1660008 ORDER BY line_no;
SELECT (SELECT SUM(round(i.quantity * i.unit_price * (1 - i.discount_pct), 2))
        FROM l16_src_order_items i JOIN l16_src_orders o USING (order_id) WHERE o.order_status = 'paid') AS source_sum,
       (SELECT SUM(net_amount) FROM l16_fact_sales WHERE order_status = 'paid') AS fact_sum;
SELECT COUNT(*) AS paid_items FROM l16_fact_sales WHERE order_status = 'paid';
