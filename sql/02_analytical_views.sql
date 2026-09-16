-- 02 · Views. Pode executar antes ou depois da importação, sempre após 01.
-- Views consultam tabelas tratadas; a referência Python é usada só na validação.
BEGIN;
CREATE OR REPLACE VIEW olist.v_items_by_order AS
SELECT order_id, count(*)::bigint AS item_count,
       -- Impede que uma soma parcial seja apresentada como total do pedido.
       CASE WHEN count(price_cents) = count(*) THEN sum(price_cents) END AS merchandise_cents,
       CASE WHEN count(freight_value_cents) = count(*) THEN sum(freight_value_cents) END AS freight_cents
FROM olist.items GROUP BY order_id;

CREATE OR REPLACE VIEW olist.v_payments_by_order AS
SELECT order_id, count(*)::bigint AS payment_count,
       CASE WHEN count(payment_value_cents) = count(*) THEN sum(payment_value_cents) END AS paid_cents
FROM olist.payments GROUP BY order_id;

CREATE OR REPLACE VIEW olist.v_review_one_per_order AS
WITH ranked AS (
    SELECT r.*, count(*) OVER (PARTITION BY order_id) AS review_count,
           row_number() OVER (
               PARTITION BY order_id
               ORDER BY review_answer_timestamp DESC NULLS LAST,
                        review_creation_date DESC NULLS LAST,
                        review_id COLLATE "C" ASC NULLS LAST, source_row ASC
           ) AS position
    FROM olist.reviews r
)
SELECT order_id, review_id, review_score, review_answer_timestamp, review_count
FROM ranked WHERE position = 1;

CREATE OR REPLACE VIEW olist.v_orders_analysis AS
WITH joined AS (
    SELECT o.*, c.customer_unique_id, c.customer_state, c.customer_city,
           coalesce(i.item_count, 0)::bigint AS item_count,
           coalesce(p.payment_count, 0)::bigint AS payment_count,
           coalesce(r.review_count, 0)::bigint AS review_count,
           i.merchandise_cents, i.freight_cents, p.paid_cents,
           r.review_id, r.review_score, r.review_answer_timestamp,
           -- Comparações com datas ausentes não são classificadas como violação.
           (coalesce(o.order_approved_at < o.order_purchase_timestamp, false)
            OR coalesce(o.order_delivered_carrier_date < o.order_approved_at, false)
            OR coalesce(o.order_delivered_customer_date < o.order_delivered_carrier_date, false)
            OR coalesce(o.order_delivered_customer_date < o.order_purchase_timestamp, false)
            OR coalesce(o.order_estimated_delivery_date < o.order_purchase_timestamp, false)) AS flag_date_sequence
    FROM olist.orders o
    JOIN olist.customers c USING (customer_id)
    LEFT JOIN olist.v_items_by_order i USING (order_id)
    LEFT JOIN olist.v_payments_by_order p USING (order_id)
    LEFT JOIN olist.v_review_one_per_order r USING (order_id)
), eligible AS (
    SELECT *,
           coalesce(order_status = 'delivered'
               AND order_purchase_timestamp IS NOT NULL
               AND merchandise_cents IS NOT NULL AND item_count > 0, false) AS eligible_sales_analysis,
           coalesce(order_status = 'delivered'
               AND order_purchase_timestamp IS NOT NULL
               AND order_delivered_customer_date IS NOT NULL
               AND order_estimated_delivery_date IS NOT NULL
               AND NOT flag_date_sequence, false) AS eligible_delivery_analysis
    FROM joined
)
SELECT *, merchandise_cents + freight_cents AS expected_cents,
       paid_cents - (merchandise_cents + freight_cents) AS payment_difference_cents,
       CASE WHEN eligible_delivery_analysis
            THEN extract(epoch FROM (order_delivered_customer_date - order_purchase_timestamp))::double precision / 86400.0
       END AS delivery_days,
       CASE WHEN eligible_delivery_analysis
            THEN order_delivered_customer_date::date - order_estimated_delivery_date::date
       END AS delay_days,
       CASE WHEN eligible_delivery_analysis
            THEN order_delivered_customer_date::date > order_estimated_delivery_date::date
       END AS is_late,
       eligible_delivery_analysis AND review_score IS NOT NULL AS eligible_delivery_review_analysis
FROM eligible;

CREATE OR REPLACE VIEW olist.v_sales_monthly AS
WITH limits AS (
    SELECT date_trunc('month', min(order_purchase_timestamp)) AS first_month,
           date_trunc('month', max(order_purchase_timestamp)) AS last_month
    FROM olist.orders
), calendar AS (
    SELECT generate_series(first_month, last_month, interval '1 month')::date AS month,
           first_month::date AS first_month, last_month::date AS last_month FROM limits
), all_orders AS (
    SELECT date_trunc('month', order_purchase_timestamp)::date AS month, count(*) AS total_orders
    FROM olist.orders WHERE order_purchase_timestamp IS NOT NULL GROUP BY 1
), sales AS (
    SELECT date_trunc('month', order_purchase_timestamp)::date AS month,
           count(*) AS sales_orders, sum(merchandise_cents) AS merchandise_cents
    FROM olist.v_orders_analysis WHERE eligible_sales_analysis GROUP BY 1
)
SELECT c.month, coalesce(a.total_orders, 0) AS total_orders,
       coalesce(s.sales_orders, 0) AS sales_orders,
       coalesce(s.merchandise_cents, 0) AS merchandise_cents,
       coalesce(s.merchandise_cents, 0) / 100.0 AS merchandise_brl,
       s.merchandise_cents / 100.0 / nullif(s.sales_orders, 0) AS ticket_brl,
       100.0 * coalesce(s.sales_orders, 0) / nullif(a.total_orders, 0) AS eligible_pct,
       c.month IN (c.first_month, c.last_month) AS observation_edge
FROM calendar c LEFT JOIN all_orders a USING (month) LEFT JOIN sales s USING (month);

CREATE OR REPLACE VIEW olist.v_delivery_by_state AS
SELECT coalesce(customer_state, 'Não informada') AS customer_state,
       count(*) AS orders, count(*) FILTER (WHERE is_late) AS late_orders,
       100.0 * count(*) FILTER (WHERE is_late) / nullif(count(*), 0) AS late_pct,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY delivery_days) AS median_days
FROM olist.v_orders_analysis WHERE eligible_delivery_analysis
GROUP BY coalesce(customer_state, 'Não informada');

CREATE OR REPLACE VIEW olist.v_delay_reviews AS
SELECT is_late, count(*) AS orders, avg(review_score) AS mean_score,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY review_score) AS median_score,
       count(*) FILTER (WHERE review_score <= 2) AS low_scores,
       100.0 * count(*) FILTER (WHERE review_score <= 2) / nullif(count(*), 0) AS low_score_pct
FROM olist.v_orders_analysis WHERE eligible_delivery_review_analysis GROUP BY is_late;
COMMIT;
