-- 02_source_ddl.sql — source table for production-shaped streaming.
-- image_url points at a public URL (or OSS) so FETCH_CONTENT pulls the image in-job.
-- Uncomment the connector variant that matches your cluster.

CREATE TEMPORARY TABLE product_events (
  id            STRING,
  product_name  STRING,
  product_desc  STRING,
  image_url     STRING,
  event_time    TIMESTAMP_LTZ(3) METADATA FROM 'timestamp',
  WATERMARK FOR event_time AS event_time - INTERVAL '3' SECOND
) WITH (
  'connector'            = 'kafka',
  'topic'                = 'product_events',
  'properties.bootstrap.servers' = 'bootstrap:9092',
  'properties.group.id'  = 'flink-tagging',
  'scan.startup.mode'    = 'earliest-offset',
  'format'               = 'json'
);

-- Prefer OSS-backed images in production (public objects that allow GET).
-- 'connector' = 'oss' variant: image objects are fetched via FETCH_CONTENT.
-- CREATE TEMPORARY TABLE product_events_oss (... ) WITH ('connector' = 'oss', ...);