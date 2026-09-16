-- 01 · Estrutura. Execute no banco olist_analytics, pelo Query Tool.
-- Somente cria objetos; não remove nem substitui dados existentes.
BEGIN;
CREATE SCHEMA IF NOT EXISTS olist;

CREATE TABLE IF NOT EXISTS olist.customers (
    customer_id text PRIMARY KEY,
    customer_unique_id text NOT NULL,
    customer_zip_code_prefix text CHECK (customer_zip_code_prefix ~ '^[0-9]{5}$'),
    customer_city text,
    customer_state text
);

CREATE TABLE IF NOT EXISTS olist.products (
    product_id text PRIMARY KEY,
    product_category_name text,
    product_name_length integer CHECK (product_name_length >= 0),
    product_description_length integer CHECK (product_description_length >= 0),
    product_photos_qty integer CHECK (product_photos_qty >= 0),
    product_weight_g numeric CHECK (product_weight_g > 0),
    product_length_cm numeric CHECK (product_length_cm > 0),
    product_height_cm numeric CHECK (product_height_cm > 0),
    product_width_cm numeric CHECK (product_width_cm > 0)
);

CREATE TABLE IF NOT EXISTS olist.sellers (
    seller_id text PRIMARY KEY,
    seller_zip_code_prefix text CHECK (seller_zip_code_prefix ~ '^[0-9]{5}$'),
    seller_city text,
    seller_state text
);

CREATE TABLE IF NOT EXISTS olist.orders (
    order_id text PRIMARY KEY,
    customer_id text NOT NULL REFERENCES olist.customers(customer_id),
    order_status text,
    order_purchase_timestamp timestamp without time zone,
    order_approved_at timestamp without time zone,
    order_delivered_carrier_date timestamp without time zone,
    order_delivered_customer_date timestamp without time zone,
    order_estimated_delivery_date timestamp without time zone
);

CREATE TABLE IF NOT EXISTS olist.items (
    order_id text NOT NULL REFERENCES olist.orders(order_id),
    order_item_id integer NOT NULL CHECK (order_item_id > 0),
    product_id text NOT NULL REFERENCES olist.products(product_id),
    seller_id text NOT NULL REFERENCES olist.sellers(seller_id),
    shipping_limit_date timestamp without time zone,
    price_cents bigint CHECK (price_cents > 0),
    freight_value_cents bigint CHECK (freight_value_cents >= 0),
    PRIMARY KEY (order_id, order_item_id)
);

CREATE TABLE IF NOT EXISTS olist.payments (
    order_id text NOT NULL REFERENCES olist.orders(order_id),
    payment_sequential integer NOT NULL CHECK (payment_sequential > 0),
    payment_type text,
    payment_installments integer CHECK (payment_installments > 0),
    payment_value_cents bigint CHECK (payment_value_cents >= 0),
    PRIMARY KEY (order_id, payment_sequential)
);

CREATE TABLE IF NOT EXISTS olist.reviews (
    source_row bigint PRIMARY KEY,
    review_id text,
    order_id text NOT NULL REFERENCES olist.orders(order_id),
    review_score integer CHECK (review_score BETWEEN 1 AND 5),
    review_comment_title text,
    review_comment_message text,
    review_creation_date timestamp without time zone,
    review_answer_timestamp timestamp without time zone
);

CREATE TABLE IF NOT EXISTS olist.geolocation (
    source_row bigint PRIMARY KEY,
    geolocation_zip_code_prefix text CHECK (geolocation_zip_code_prefix ~ '^[0-9]{5}$'),
    geolocation_lat numeric CHECK (geolocation_lat BETWEEN -90 AND 90),
    geolocation_lng numeric CHECK (geolocation_lng BETWEEN -180 AND 180),
    geolocation_city text,
    geolocation_state text,
    flag_coord_candidate boolean
);

CREATE TABLE IF NOT EXISTS olist.translation (
    product_category_name text PRIMARY KEY,
    product_category_name_english text
);

CREATE TABLE IF NOT EXISTS olist.reference_orders (
    order_id text PRIMARY KEY,
    customer_unique_id text,
    customer_state text,
    order_status text,
    item_count bigint,
    payment_count bigint,
    review_count bigint,
    merchandise_cents bigint,
    freight_cents bigint,
    paid_cents bigint,
    expected_cents bigint,
    payment_difference_cents bigint,
    review_id text,
    review_score integer,
    review_answer_timestamp timestamp without time zone,
    delivery_days double precision,
    delay_days integer,
    is_late boolean,
    eligible_sales_analysis boolean,
    eligible_delivery_analysis boolean,
    eligible_delivery_review_analysis boolean
);

COMMENT ON TABLE olist.reviews IS 'Avaliações preservadas. review_id não é único; source_row reproduz a posição no Parquet para desempate.';

COMMENT ON TABLE olist.reference_orders IS 'Referência Python para reconciliação; não é fonte dos indicadores SQL.';

COMMENT ON TABLE olist.geolocation IS 'Observações por prefixo; prefixo não é chave única. flag_coord_candidate é triagem aproximada, não validação territorial.';

COMMENT ON COLUMN olist.items.price_cents IS 'Valor do item em centavos. Ausente não equivale a zero.';

CREATE INDEX IF NOT EXISTS idx_orders_customer ON olist.orders(customer_id);

CREATE INDEX IF NOT EXISTS idx_orders_purchase ON olist.orders(order_purchase_timestamp);

CREATE INDEX IF NOT EXISTS idx_items_product ON olist.items(product_id);

CREATE INDEX IF NOT EXISTS idx_items_seller ON olist.items(seller_id);

CREATE INDEX IF NOT EXISTS idx_reviews_order ON olist.reviews(order_id);

CREATE INDEX IF NOT EXISTS idx_geo_zip ON olist.geolocation(geolocation_zip_code_prefix);

COMMIT;
