# Flink SQL × AI：一条 SQL 实现图文多模态理解与实时多标签打标

README 中文说明见下方对应小节。This workspace reproduces the WeChat technical
article **《Flink SQL × AI：一条 SQL 实现图文多模态理解与实时多标签打标》** (何志臻 @阿里云),
which demos a **real-time multi-label tagging pipeline** built entirely in SQL on
Alibaba Cloud Realtime Compute for Apache Flink (Flink, VVR 11.9 Preview 2).

> ⚠️ **About the source:** The original WeChat article is behind a CAPTCHA/bot
> check (`mp.weixin.qq.com/s/Y9n7fqvWuH-q-Y5lXm2BCg`) and could not be fetched
> programmatically, nor could web search return supplementary copies. This
> reproduction was rebuilt from the issue's summary of the article plus the
> public Alibaba Cloud Flink AI Service function contracts (`AI_EMBED`,
> `VECTOR_SEARCH_AGG`, `ML_PREDICT`, `FETCH_CONTENT`, Python inline UDF).
> Verify the exact per-function argument order against your installed VVR
> version before running on a paid cluster (see `docs/architecture.md`).

---

## Pipeline at a glance

```
  incoming product event (text + image OSS url)
        │
        ▼
  ┌────────────────────────── STAGE 1 · Embedding recall ──────────────────────┐
  │  text_vector  = AI_EMBED(qwen3-vl-embedding, name·desc, 'text',  1024)     │
  │  image_vector = AI_EMBED(qwen3-vl-embedding, FETCH_CONTENT(img),'image',1024)│
  │        │ both embedded to 1024-dim                                          │
  │        ▼                                                                    │
  │  text_candidates  = VECTOR_SEARCH_AGG('product_label', text_vector,  3)    │
  │  image_candidates = VECTOR_SEARCH_AGG('product_label', image_vector, 3)    │
  │        (Milvus-backed 1024-dim `product_label` collection, top-3 each)      │
  └────────────────────────────────────┬───────────────────────────────────────┘
        │ top-3 text candidates + top-3 image candidates (raw JSON)
        ▼
  ┌────────────────────────── STAGE 2 · Multimodal judge ──────────────────────┐
  │  candidate_trim(...)  Python inline UDF → compact {label,score}[3/3]       │
  │  ML_PREDICT(qwen3.6-plus, {text, image, text_candidates, image_candidates})│
  │        → final multi-label tags (multimodal, jointly on text + image)      │
  └────────────────────────────────────┬───────────────────────────────────────┘
        ▼
   Print connector (sample output) / UDF-XX downstream sink
```

**Key idea validated by the 3 sample events:** text and image each
contribute complementary label evidence. Text-alone recall and image-alone
recall can disagree; the multimodal judge on the *union* of candidates yields
labels that neither modality provides on its own.

---

## Directory layout

```
flink-sql-multimodal-tagging/
├── README.md                        # this file
├── docs/
│   └── architecture.md              # design notes + per-function signature caveats
├── sql/
│   ├── demo_all_standalone.sql      # ★ ONE self-contained script (VALUES→print), run this first
│   ├── 01_env.sql                   # runtime/workspace config, job name, model registration
│   ├── 02_source_ddl.sql            # source table DDL (Kafka / OSS / datagen variants)
│   ├── 03_python_udf.sql            # Python inline UDF: candidate_trim()
│   ├── 04_stage1_embedding_recall.sql   # AI_EMBED + VECTOR_SEARCH_AGG (two-way recall)
│   ├── 05_stage2_multimodal_judge.sql   # ML_PREDICT judge + label whitening
│   └── 06_sink_insert.sql           # final INSERT into sink
├── labels/
│   └── labels.sql                   # 8 labels + seed-embeddings DML for `product_label`
└── data/
    ├── events.json                  # 3 image+text sample events (id/title/desc/img_url)
    └── sample_images_README.md      # how to obtain the 3 demo images (public data URLs)
```

---

## How to run

### Option A — standalone demo (no external Kafka/Milvus) — 推荐先跑这个

`sql/demo_all_standalone.sql` is fully self-contained: the 3 events are injected
with a `VALUES` source, all AI calls happen in the job, and results go to the
**Print connector**, so it is visible directly in the Flink job's TaskManager log.

Prereqs on your Alibaba Cloud Realtime Compute cluster (VVR 11.9 Preview 2+):

1. Go to **Realtime Compute Console → 管理 Flink 作业 → 作业开发 (SQL)**.
2. Open a new **SQL editor** window.
3. From the **AI 服务** panel confirm these services are enabled and map to the
   right models:
   - `qwen3-vl-embedding`  → embedding model (1024-dim, text + image input)
   - `qwen3.6-plus`        → multimodal judge model
4. Configure the `danmaku-*`-style workspace/attachment settings if your
   console expects them (or leave the default `ai_params` in `01_env.sql`).

Paste the whole file into the editor and click **运行 → Print (直接预览)**.
Watch the TaskManager logs; the final judge output rows appear after the two
`print_*` staging tables and one `print_result` table.

To move from preview to a real streaming job, swap the `VALUES` source for the
Kafka/OSS source in `02_source_ddl.sql` (§ Option B).

### Option B — production-shaped streaming job

The numbered files `01_env.sql` … `06_sink_insert.sql` are the production-shaped
splits. Submit them in order (1 → 6). Differences vs the demo:

- `02_source_ddl.sql` — real Kafka connector over a `product_events` topic, with
  a Kafka/OSS-backed `image_url` pointing at public images; `FETCH_CONTENT`
  pulls them in-job.
- `06_sink_insert.sql` — `INSERT INTO` three output tables: raw embeds
  (debug), candidate recall (debug), and final tags (downstream consumer).

### Labels seed

`labels/labels.sql` defines the 8 labels and the DML that embeds each label's
description with `qwen3-vl-embedding` and writes into the Milvus
`product_label` collection (1024-dim), so that stage-1 recall has something to
search. Run it once before the main job.

In production you may prefer to seed Milvus outside Flink (the console's
**数据存储 → Milvus** tab, or embedding via OSS + a vector load job) — the DML
is provided so the whole pipeline can stay "one SQL" as the article stresses.

---

## Artifacts you can inspect before paying for any AI inference

- `data/events.json` — the 3 sample events and the expected final labels
  (defines what "complementarity" means for this dataset).
- `data/sample_images_README.md` — three ready-to-use public image data URLs
  (one per event), so the repro runs without you uploading anything.
- `scripts/generate_sample_images.py` — optional: locally paints 3 simple PNGs
  so you have byte-exact local image fixtures (no network fetched image).

---

## Notes & limitations

- The exact argument orders for `AI_EMBED` / `VECTOR_SEARCH_AGG` / `ML_PREDICT`
  can vary between VVR builds. `docs/architecture.md` lists the signatures used
  here and what to double-check.
- `FETCH_CONTENT` on an OSS image returns a Base64 **data URL**, which is what
  the multimodal model consumes as `image` — that is why stage 2 does not need
  to re-fetch by URL.
- Model tier: `ML_PREDICT(qwen3.6-plus, ...)` runs on a paid inference endpoint.
  The free-tier flow here only demonstrates SQL shape; actual inference requires
  the corresponding AI-service model to be provisioned.

_Reproduced by claude code ai / LARI-15._