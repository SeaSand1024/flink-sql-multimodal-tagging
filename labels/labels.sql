-- labels/labels.sql — the 8 product labels + seed-embedding DML.
-- Seeds the Milvus `product_label` collection (1024-dim) so stage-1
-- VECTOR_SEARCH_AGG has something to recall against. Run BEFORE the main job.

-- 8 labels. `label_desc` is what gets embedded (text + optional image exemplar).
CREATE TEMPORARY TABLE label_seed (
  label_id    STRING,
  label_name  STRING,
  label_desc  STRING,
  label_img   STRING
) WITH ('connector' = 'datagen', 'rows-per-second' = '0');  -- VALUES below

INSERT INTO label_seed (label_id, label_name, label_desc, label_img) VALUES
  ('L01', '户外运动',   '徒步、露营、登山、冲锋衣等户外装备与服饰', 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII='),
  ('L02', '智能穿戴',   '智能手表、手环、耳机等可穿戴电子设备',     'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII='),
  ('L03', '美妆护肤',   '面部护肤、保湿面霜、精华等个护化妆品',     'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII='),
  ('L04', '数码家电',   '手机、平板、小家电等数码与家电产品',       'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII='),
  ('L05', '家居生活',   '床品、收纳、厨具等家居日用百货',           'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII='),
  ('L06', '食品饮料',   '零食、饮品、生鲜等食品饮料类商品',         'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII='),
  ('L07', '服饰穿搭',   '上衣、裤装、鞋靴等日常服饰搭配单品',       'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII='),
  ('L08', '母婴玩具',   '婴儿用品、奶粉、儿童玩具等母婴商品',       'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=');

-- Seed the Milvus `product_label` collection using the embedding model.
-- Each label stores {label_name, label_desc} plus a 1024-dim vector.
CREATE TEMPORARY TABLE product_label_sink (
  id        STRING,
  label_name STRING,
  label_desc STRING,
  label_emb ARRAY<FLOAT>
) WITH (
  'connector' = 'milvus',
  'collection.name' = 'product_label',
  'collection.dim'  = '1024'
);

INSERT INTO product_label_sink
SELECT
  label_id,
  label_name,
  label_desc,
  CAST(AI_EMBED('qwen3-vl-embedding', label_desc, 'text', 1024) AS ARRAY<FLOAT>)
FROM label_seed;