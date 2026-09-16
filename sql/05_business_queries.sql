-- 05 · Análises de negócio. Selecione UMA consulta completa para executar e exportar.
-- 1. Cobertura: os denominadores são diferentes por pergunta.
SELECT count(*) AS todos_pedidos,
       count(*) FILTER (WHERE eligible_sales_analysis) AS vendas_entregues,
       count(*) FILTER (WHERE eligible_delivery_analysis) AS entregas_elegiveis,
       count(*) FILTER (WHERE eligible_delivery_review_analysis) AS entregas_com_nota
FROM olist.v_orders_analysis;

-- 2. Vendas entregues: soma de mercadorias não é receita líquida nem lucro.
SELECT count(*) AS pedidos, count(DISTINCT customer_unique_id) AS consumidores,
       sum(merchandise_cents) / 100.0 AS mercadorias_brl,
       round(sum(merchandise_cents) / 100.0 / nullif(count(*), 0), 2) AS ticket_brl,
       sum(freight_cents) / 100.0 AS frete_observado_brl,
       round(100.0 * count(freight_cents) / nullif(count(*), 0), 2) AS cobertura_frete_pct
FROM olist.v_orders_analysis WHERE eligible_sales_analysis;

-- 3. Evolução mensal: bordas não comprovam meses completos; olhar eligible_pct.
SELECT month, total_orders, sales_orders, merchandise_brl,
       round(ticket_brl, 2) AS ticket_brl, round(eligible_pct, 2) AS eligible_pct, observation_edge
FROM olist.v_sales_monthly ORDER BY month;

-- 4. Entregas: percentis complementam a média e incluem todos os elegíveis.
SELECT count(*) AS pedidos,
       round(100.0 * count(*) FILTER (WHERE is_late) / nullif(count(*), 0), 2) AS atraso_pct,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY delivery_days) AS mediana_dias,
       percentile_cont(0.9) WITHIN GROUP (ORDER BY delivery_days) AS p90_dias
FROM olist.v_orders_analysis WHERE eligible_delivery_analysis;

-- 5. UF do CLIENTE: o mesmo mínimo de 100 pedidos do notebook de EDA.
SELECT customer_state, orders, late_orders, round(late_pct, 2) AS late_pct, median_days
FROM olist.v_delivery_by_state
WHERE orders >= 100 AND customer_state <> 'Não informada'
ORDER BY late_pct DESC, customer_state;

-- 6. Atraso e notas: comparação descritiva, não causal.
SELECT CASE WHEN is_late THEN 'Atrasado' ELSE 'No prazo' END AS grupo,
       orders, round(mean_score, 2) AS mean_score, median_score, low_scores,
       round(low_score_pct, 2) AS low_score_pct
FROM olist.v_delay_reviews ORDER BY is_late;

-- 7. Diferença em pontos percentuais, sem subtrair grupos ausentes como zero.
SELECT a.low_score_pct - b.low_score_pct AS diferenca_notas_baixas_pp
FROM olist.v_delay_reviews a CROSS JOIN olist.v_delay_reviews b
WHERE a.is_late AND NOT b.is_late;

-- 8. Cobertura das avaliações: ausência de nota pode ser seletiva.
SELECT is_late, count(*) AS entregas,
       count(*) FILTER (WHERE eligible_delivery_review_analysis) AS com_nota,
       100.0 * count(*) FILTER (WHERE eligible_delivery_review_analysis) / nullif(count(*), 0) AS cobertura_pct
FROM olist.v_orders_analysis WHERE eligible_delivery_analysis GROUP BY is_late ORDER BY is_late;

-- 9. Faixas de atraso: zero ou negativo corresponde a entrega no prazo.
WITH bands AS (
    SELECT *, CASE WHEN delay_days <= 0 THEN 0 WHEN delay_days <= 3 THEN 1
        WHEN delay_days <= 7 THEN 2 WHEN delay_days <= 14 THEN 3 ELSE 4 END AS band
    FROM olist.v_orders_analysis WHERE eligible_delivery_review_analysis
)
SELECT CASE band WHEN 0 THEN 'No prazo' WHEN 1 THEN '1–3 dias' WHEN 2 THEN '4–7 dias'
       WHEN 3 THEN '8–14 dias' ELSE '15+ dias' END AS faixa,
       count(*) AS pedidos, avg(review_score) AS nota_media,
       100.0 * count(*) FILTER (WHERE review_score <= 2) / count(*) AS notas_baixas_pct
FROM bands GROUP BY band ORDER BY band;

-- 10. Sensibilidade: avaliações respondidas após a entrega.
SELECT is_late, count(*) AS pedidos, avg(review_score) AS nota_media,
       100.0 * count(*) FILTER (WHERE review_score <= 2) / count(*) AS notas_baixas_pct
FROM olist.v_orders_analysis
WHERE eligible_delivery_review_analysis AND review_answer_timestamp >= order_delivered_customer_date
GROUP BY is_late ORDER BY is_late;

-- 11. Diferença dentro da UF: mínimo 20 pedidos em CADA grupo, igual à EDA.
WITH rates AS (
    SELECT customer_state, is_late, count(*) AS n,
           100.0 * count(*) FILTER (WHERE review_score <= 2) / count(*) AS low_pct
    FROM olist.v_orders_analysis
    WHERE eligible_delivery_review_analysis AND customer_state IS NOT NULL
    GROUP BY customer_state, is_late
)
SELECT a.customer_state, a.n AS n_atrasados, b.n AS n_no_prazo,
       a.low_pct - b.low_pct AS diferenca_pp
FROM rates a JOIN rates b USING (customer_state)
WHERE a.is_late AND NOT b.is_late AND a.n >= 20 AND b.n >= 20
ORDER BY diferenca_pp DESC;
