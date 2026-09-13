-- ============================================================================
-- demo_all_standalone.sql
-- ★ Run this FIRST. Self-contained reproduction of the article's pipeline:
--   Stage 1 (embedding recall) → Stage 2 (multimodal judge) → Print sink.
--   No Kafka, no Milvus, no OSS required to see it work.
--   Target: Alibaba Cloud Realtime Compute for Apache Flink, VVR 11.9 Preview 2+
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Runtime / workspace config + AI service model registration
--    (adjust model id & endpoint to what is provisioned on your cluster)
-- ----------------------------------------------------------------------------
SET 'sql.time-zone' = 'Asia/Shanghai';
SET 'pipeline.name' = 'flink-sql-multimodal-tagging-demo';

CREATE FUNCTION register_ai_service AS 'com.alibaba.realtimecompute.ai.modelservice.deploy.AIModelServiceUDF'
WITH (
  'model.name'                = 'qwen3-vl-embedding',
  'model.provider'            = 'Ollama',   -- placeholder: swap to your AI-service provider
  'model.endpoint'            = 'http://dummy:11434/api/embed',
  'model.input.maxTokens'     = '1024'
);

CREATE FUNCTION register_judge_model AS 'com.alibaba.realtimecompute.ai.modelservice.deploy.AIModelServiceUDF'
WITH (
  'model.name'                = 'qwen3.6-plus',
  'model.provider'            = 'Ollama',   -- placeholder
  'model.endpoint'            = 'http://dummy:11434/v1/chat/completions'
);

-- ----------------------------------------------------------------------------
-- 2. Python inline UDF: compact raw VECTOR_SEARCH_AGG JSON into {label, score}.
--    Both recall tables emit verbose Milvus JSON; the judge only needs names+score.
-- ----------------------------------------------------------------------------
CREATE TEMPORARY FUNCTION candidate_trim AS 'inline'
LANGUAGE PYTHON
AS $$
from typing import Iterator
from flink.table.udf import ScalarFunction

class candidate_trim(ScalarFunction):
    """Trim a VECTOR_SEARCH_AGG result (JSON array) to [{'label':..,'score':..}...]."""
    def eval(self, raw: str) -> str:
        import json
        if raw is None:
            return '[]'
        try:
            data = json.loads(raw)
        except (ValueError, TypeError):
            return '[]'
        if not isinstance(data, list):
            data = [data]
        out = []
        for item in data:
            row = item if isinstance(item, dict) else {}
            out.append({
                'label': row.get('label_name') or row.get('label') or row.get('entity') or '',
                'score': round(float(row.get('score') or row.get('distance') or 0.0), 4),
            })
        return json.dumps(out, ensure_ascii=False)
$$;

-- ----------------------------------------------------------------------------
-- 3. Sample data — the 3 image+text events from the article.
--    image_url is a Base64 data URL so FETCH_CONTENT needs no outbound fetch.
-- ----------------------------------------------------------------------------
CREATE TEMPORARY TABLE product_events (
  id            STRING,
  product_name  STRING,
  product_desc  STRING,
  image_url     STRING
) WITH ('connector' = 'datagen', 'rows-per-second' = '0');  -- VALUES below, static

INSERT INTO product_events (id, product_name, product_desc, image_url)
VALUES
  ('e1', '户外冲锋衣', '防水透气的三合一冲锋外套，适合徒步和露营', 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII='),
  ('e2', '智能手环',    '支持心率、血氧与睡眠监测的可穿戴设备',        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII='),
  ('e3', '保湿面霜',    '零油脂感的面部保湿霜，敏感肌可用',            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=');

-- ----------------------------------------------------------------------------
-- 4. STAGE 1 · Embedding recall (text + image) against 1024-dim product_label
-- ----------------------------------------------------------------------------
CREATE TEMPORARY TABLE print_emb (
  id STRING, text_vector_dim INT, image_vector_dim INT
) WITH ('connector' = 'print');

INSERT INTO print_emb
SELECT
  id,
  CARDINALITY(text_vector)  AS text_vector_dim,
  CARDINALITY(image_vector) AS image_vector_dim
FROM (
  SELECT
    id,
    AI_EMBED('qwen3-vl-embedding',
             CONCAT(product_name, '。', product_desc),
             'text' , 1024) AS text_vector,
    AI_EMBED('qwen3-vl-embedding',
             FETCH_CONTENT(image_url),
             'image', 1024) AS image_vector
  FROM product_events
);

CREATE TEMPORARY TABLE print_recall (
  id STRING, text_candidates STRING, image_candidates STRING
) WITH ('connector' = 'print');

INSERT INTO print_recall
SELECT
  p.id,
  CAST(VECTOR_SEARCH_AGG('product_label', p.text_vector,  3) AS STRING) AS text_candidates,
  CAST(VECTOR_SEARCH_AGG('product_label', p.image_vector, 3) AS STRING) AS image_candidates
FROM (
  SELECT
    id,
    AI_EMBED('qwen3-vl-embedding',
             CONCAT(product_name, '。', product_desc),
             'text' , 1024) AS text_vector,
    AI_EMBED('qwen3-vl-embedding',
             FETCH_CONTENT(image_url),
             'image', 1024) AS image_vector
  FROM product_events
) p;

-- ----------------------------------------------------------------------------
-- 5. STAGE 2 · Multimodal judge on (text, image) + top-3 candidate union
-- ----------------------------------------------------------------------------
CREATE TEMPORARY TABLE print_result (
  id STRING, final_labels STRING
) WITH ('connector' = 'print');

INSERT INTO print_result
SELECT
  id,
  ML_PREDICT(
    'qwen3.6-plus',
    json_object(
      'text'             , CONCAT(product_name, '。', product_desc),
      'image'            , image_url,
      'text_candidates'  , candidate_trim(text_candidates),
      'image_candidates' , candidate_trim(image_candidates)
    ),
    json_object('labels', 'string array of final multi-labels, format like ["a","b"]')
  ) AS final_labels
FROM (
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
  ) p
);