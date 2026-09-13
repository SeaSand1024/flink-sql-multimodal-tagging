-- 06_sink_insert.sql — downstream INSERTs for the production job.
-- Depends on: embedding_recall (04), judged (05).

-- 6a. Debug: raw embed dims.
CREATE TEMPORARY TABLE print_emb (
  id STRING, text_vector_dim INT, image_vector_dim INT
) WITH ('connector' = 'print');
INSERT INTO print_emb
SELECT id, CARDINALITY(text_vector) AS text_vector_dim, CARDINALITY(image_vector) AS image_vector_dim
FROM (SELECT id, AI_EMBED('qwen3-vl-embedding', CONCAT(product_name,'。',product_desc),'text',1024) AS text_vector,
             AI_EMBED('qwen3-vl-embedding', FETCH_CONTENT(image_url),'image',1024) AS image_vector
      FROM product_events);

-- 6b. Debug: top-3 recall for text and image.
CREATE TEMPORARY TABLE print_recall (
  id STRING, text_candidates STRING, image_candidates STRING
) WITH ('connector' = 'print');
INSERT INTO print_recall
SELECT id, text_candidates, image_candidates FROM embedding_recall;

-- 6c. Final: judged multi-labels → real downstream sink (Upsert Kafka in prod).
CREATE TEMPORARY TABLE final_tags (
  id STRING, final_labels STRING
) WITH (
  'connector' = 'kafka',
  'topic'     = 'product_tags',
  'properties.bootstrap.servers' = 'bootstrap:9092',
  'properties.group.id' = 'flink-tagging-out',
  'format'    = 'json'
);
INSERT INTO final_tags
SELECT id, final_labels FROM judged;