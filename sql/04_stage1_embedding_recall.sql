-- 04_stage1_embedding_recall.sql — two-way semantic recall (text + image).
-- Depends on: 01_env.sql (embed model), 02_source_ddl.sql, product_label seeded.

-- 4a. Embed text and image to 1024-dim, then search top-3 in `product_label`.
CREATE TEMPORARY VIEW embedding_recall AS
SELECT
  p.id,
  p.product_name,
  p.product_desc,
  p.image_url,
  CAST(VECTOR_SEARCH_AGG('product_label', p.text_vector,  3) AS STRING) AS text_candidates,
  CAST(VECTOR_SEARCH_AGG('product_label', p.image_vector, 3) AS STRING) AS image_candidates
FROM (
  SELECT
    id,
    product_name,
    product_desc,
    image_url,
    AI_EMBED('qwen3-vl-embedding',
             CONCAT(product_name, '。', product_desc),
             'text' , 1024) AS text_vector,
    AI_EMBED('qwen3-vl-embedding',
             FETCH_CONTENT(image_url),
             'image', 1024) AS image_vector
  FROM product_events
) p;