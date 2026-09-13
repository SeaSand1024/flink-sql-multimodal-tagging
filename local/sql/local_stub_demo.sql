-- ============================================================================
-- local_stub_demo.sql
-- Runs the article's two-stage multimodal tagging pipeline on a PLAIN Apache
-- Flink cluster, with the Alibaba Cloud AI-Service functions replaced by local
-- deterministic stubs (jar: flink-ai-stub-udf). Real inference (qwen3-vl-
-- embedding / qwen3.6-plus against VVR + Milvus) needs the paid cluster.
--
-- Pipeline: VALUES(3 events) → Stage1 AI_EMBED + VECTOR_SEARCH_AGG (text+image)
--                                    → Stage2 ML_PREDICT judge → print sink.
-- ============================================================================

-- Register local stubs (fully-qualified UDF classes shipped in /opt/flink/lib).
CREATE TEMPORARY SYSTEM FUNCTION AI_EMBED
  AS 'com.multica.flinkai.stub.AIEmbedUDF';
CREATE TEMPORARY SYSTEM FUNCTION VECTOR_SEARCH_AGG
  AS 'com.multica.flinkai.stub.VectorSearchUDF';
CREATE TEMPORARY SYSTEM FUNCTION ML_PREDICT
  AS 'com.multica.flinkai.stub.MlPredictUDF';
CREATE TEMPORARY SYSTEM FUNCTION FETCH_CONTENT
  AS 'com.multica.flinkai.stub.FetchContentUDF';
CREATE TEMPORARY SYSTEM FUNCTION candidate_trim
  AS 'com.multica.flinkai.stub.CandidateTrimUDF';

SET 'pipeline.name'       = 'local-multimodal-tagging-demo';
SET 'sql.time-zone'       = 'Asia/Shanghai';
SET 'parallelism.default' = '1';

CREATE TABLE print_result (
  id STRING,
  text_candidates  STRING,
  image_candidates STRING,
  final_labels     STRING
) WITH ('connector' = 'print');

INSERT INTO print_result
SELECT
  id,
  VECTOR_SEARCH_AGG('product_label',
                    AI_EMBED(CONCAT(product_name, '。', product_desc), 'text'),
                    3)  AS text_candidates,
  VECTOR_SEARCH_AGG('product_label',
                    AI_EMBED(FETCH_CONTENT(image_url), 'image'),
                    3)  AS image_candidates,
  ML_PREDICT('qwen3.6-plus',
             CONCAT(product_name, '。', product_desc),
             image_url,
             candidate_trim(VECTOR_SEARCH_AGG('product_label',
                              AI_EMBED(CONCAT(product_name, '。', product_desc), 'text'), 3)),
             candidate_trim(VECTOR_SEARCH_AGG('product_label',
                              AI_EMBED(FETCH_CONTENT(image_url), 'image'), 3))
             ) AS final_labels
FROM (
  VALUES
    ('e1', '户外冲锋衣', '防水透气的三合一冲锋外套，适合徒步和露营 #key:outdoor',  'img:camping'),
    ('e2', '智能手环',   '支持心率、血氧与睡眠监测的可穿戴设备 #key:wearable',     'img:band'),
    ('e3', '保湿面霜',   '零油脂感的面部保湿霜，敏感肌可用 #key:skincare',        'img:jar')
) AS events(id, product_name, product_desc, image_url);