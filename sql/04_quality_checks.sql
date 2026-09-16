-- 04 · Execute cada consulta selecionando o bloco completo no Query Tool.
-- Contagem zero de divergências só é conclusiva quando a referência está carregada.
SELECT 'customers' AS tabela, count(*) AS linhas FROM olist.customers
UNION ALL SELECT 'orders', count(*) FROM olist.orders
UNION ALL SELECT 'items', count(*) FROM olist.items
UNION ALL SELECT 'payments', count(*) FROM olist.payments
UNION ALL SELECT 'reviews', count(*) FROM olist.reviews
UNION ALL SELECT 'products', count(*) FROM olist.products
UNION ALL SELECT 'sellers', count(*) FROM olist.sellers
UNION ALL SELECT 'geolocation', count(*) FROM olist.geolocation
UNION ALL SELECT 'translation', count(*) FROM olist.translation
UNION ALL SELECT 'reference_orders', count(*) FROM olist.reference_orders;

-- Comparação estrutural: cada contagem de pedidos deve ser igual.
SELECT (SELECT count(*) FROM olist.orders) AS pedidos_tabela,
       (SELECT count(*) FROM olist.v_orders_analysis) AS pedidos_view,
       (SELECT count(DISTINCT order_id) FROM olist.v_orders_analysis) AS ids_unicos,
       (SELECT count(*) FROM olist.reference_orders) AS pedidos_referencia,
       (SELECT count(*) FROM olist.v_reconciliation_detail) AS campos_divergentes;

-- Pendências conhecidas não foram transformadas em correções arbitrárias.
SELECT count(*) FILTER (WHERE flag_date_sequence) AS sequencia_temporal_suspeita,
       count(*) FILTER (WHERE order_status = 'delivered' AND order_delivered_customer_date IS NULL) AS entregue_sem_data,
       count(*) FILTER (WHERE item_count = 0) AS sem_itens,
       count(*) FILTER (WHERE payment_count = 0) AS sem_pagamentos,
       count(*) FILTER (WHERE review_count > 1) AS multiplas_avaliacoes,
       count(*) FILTER (WHERE payment_difference_cents <> 0) AS divergencia_pagamento,
       count(*) FILTER (WHERE payment_difference_cents IS NULL) AS conciliacao_indisponivel
FROM olist.v_orders_analysis;

-- Categorias sem tradução são preservadas: por isso não há FK nessa relação.
SELECT p.product_category_name, count(*) AS produtos
FROM olist.products p LEFT JOIN olist.translation t USING (product_category_name)
WHERE p.product_category_name IS NOT NULL AND t.product_category_name IS NULL
GROUP BY p.product_category_name ORDER BY produtos DESC;

-- Triagem do prazo em 2020 e de outros intervalos extremos; nenhum ano é adivinhado.
SELECT i.order_id, i.order_item_id, i.shipping_limit_date, o.order_purchase_timestamp,
       i.shipping_limit_date - o.order_purchase_timestamp AS intervalo
FROM olist.items i JOIN olist.orders o USING (order_id)
WHERE i.shipping_limit_date < o.order_purchase_timestamp
   OR i.shipping_limit_date - o.order_purchase_timestamp > interval '365 days'
ORDER BY i.shipping_limit_date DESC;

-- Prefixos continuam não únicos; geolocalização não deve ser ligada diretamente aos pedidos.
SELECT count(*) AS observacoes,
       count(DISTINCT geolocation_zip_code_prefix) AS prefixos,
       count(*) FILTER (WHERE NOT flag_coord_candidate OR flag_coord_candidate IS NULL) AS fora_triagem_ou_ausentes
FROM olist.geolocation;
