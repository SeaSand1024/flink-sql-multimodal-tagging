-- 01_env.sql — runtime config + AI service model registration
-- Run once per session. Adjust the dummy endpoints to your provisioned models.

SET 'sql.time-zone' = 'Asia/Shanghai';
SET 'pipeline.name' = 'flink-sql-multimodal-tagging';
SET 'execution.checkpointing.interval' = '60s';

-- Embedding model (multimodal: text + image), 1024-dim output.
CREATE FUNCTION register_embed AS 'com.alibaba.realtimecompute.ai.modelservice.deploy.AIModelServiceUDF'
WITH (
  'model.name'      = 'qwen3-vl-embedding',
  'model.provider'  = 'Ollama',
  'model.endpoint'  = 'http://dummy:11434/api/embed',
  'model.input.maxTokens' = '1024'
);

-- Multimodal judge model.
CREATE FUNCTION register_judge AS 'com.alibaba.realtimecompute.ai.modelservice.deploy.AIModelServiceUDF'
WITH (
  'model.name'     = 'qwen3.6-plus',
  'model.provider' = 'Ollama',
  'model.endpoint' = 'http://dummy:11434/v1/chat/completions'
);