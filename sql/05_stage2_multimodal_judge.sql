-- 05_stage2_multimodal_judge.sql — multimodal judge on (text, image) + candidates.
-- Depends on: 01_env.sql (judge model), 03_python_udf.sql, embedding_recall view.
CREATE TEMPORARY VIEW judged AS
SELECT
  id,
  product_name,
  product_desc,
  image_url,
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
FROM embedding_recall;