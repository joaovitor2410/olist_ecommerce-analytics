-- 03 · Reconciliação com a saída Python, campo a campo e pedido a pedido.
-- Execute após a importação e a criação das views.
BEGIN;
CREATE OR REPLACE VIEW olist.v_reconciliation_detail AS
SELECT coalesce(s.order_id, p.order_id) AS order_id, c.field
FROM olist.v_orders_analysis s
FULL JOIN olist.reference_orders p ON p.order_id = s.order_id
CROSS JOIN LATERAL (VALUES
    ('presenca_pedido', s.order_id IS NULL OR p.order_id IS NULL),
('customer_unique_id', (s.customer_unique_id IS DISTINCT FROM p.customer_unique_id)),
('customer_state', (s.customer_state IS DISTINCT FROM p.customer_state)),
('order_status', (s.order_status IS DISTINCT FROM p.order_status)),
('item_count', (s.item_count IS DISTINCT FROM p.item_count)),
('payment_count', (s.payment_count IS DISTINCT FROM p.payment_count)),
('review_count', (s.review_count IS DISTINCT FROM p.review_count)),
('merchandise_cents', (s.merchandise_cents IS DISTINCT FROM p.merchandise_cents)),
('freight_cents', (s.freight_cents IS DISTINCT FROM p.freight_cents)),
('paid_cents', (s.paid_cents IS DISTINCT FROM p.paid_cents)),
('expected_cents', (s.expected_cents IS DISTINCT FROM p.expected_cents)),
('payment_difference_cents', (s.payment_difference_cents IS DISTINCT FROM p.payment_difference_cents)),
('review_id', (s.review_id IS DISTINCT FROM p.review_id)),
('review_score', (s.review_score IS DISTINCT FROM p.review_score)),
('review_answer_timestamp', (s.review_answer_timestamp IS DISTINCT FROM p.review_answer_timestamp)),
('delivery_days', ((s.delivery_days IS NULL) <> (p.delivery_days IS NULL) OR abs(s.delivery_days - p.delivery_days) > 1e-8)),
('delay_days', (s.delay_days IS DISTINCT FROM p.delay_days)),
('is_late', (s.is_late IS DISTINCT FROM p.is_late)),
('eligible_sales_analysis', (s.eligible_sales_analysis IS DISTINCT FROM p.eligible_sales_analysis)),
('eligible_delivery_analysis', (s.eligible_delivery_analysis IS DISTINCT FROM p.eligible_delivery_analysis)),
('eligible_delivery_review_analysis', (s.eligible_delivery_review_analysis IS DISTINCT FROM p.eligible_delivery_review_analysis))
) AS c(field, differs)
WHERE c.differs;
COMMIT;

-- Uma linha por campo divergente. Resultado vazio é esperado se as versões coincidem.
SELECT field, count(*) AS divergencias FROM olist.v_reconciliation_detail GROUP BY field ORDER BY field;
