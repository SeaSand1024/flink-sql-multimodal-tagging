# Architecture & function-signature notes

## Why two stages?

Single-modality tagging is brittle: a terse SKU title or an ambiguous photo each
miss labels. Recall is cheap (embedding × top-k) but noisy; judgment is accurate
but expensive. Splitting into **recall → judge** keeps the multimodal (costly)
call to a small candidate set, which is the whole point of the article's design.

- **Stage 1 (recall):** text and image are embedded independently and each does
  a top-3 search in the Milvus `product_label` collection. Cheap, parallel,
  per-row — no cross-event state.
- **Stage 2 (judge):** one `ML_PREDICT(qwen3.6-plus, …)` on the original
  (`text`, `image`) **plus** the union of top-3 text & top-3 image candidates.
  The model decides the final multi-label set, resolving text/image disagreement.

## Data flow

```
product_events
   │  AI_EMBED(text) ──► text_vector      ┐
   │  FETCH_CONTENT(img) + AI_EMBED(img) ─► image_vector ┤ → VECTOR_SEARCH_AGG × 2 → candidates
   │                                                                  │ candidate_trim()
   ▼                                                                  ▼
   └───────────────────────────►  ML_PREDICT(qwen3.6-plus, {text,image,cands}) → final_labels
```

## Function-contract caveats — verify per VVR build

The article targets **VVR 11.9 Preview 2**. Argument orders/providers differ
across builds; the signatures below match what the standalone demo assumes:

| function | signature used | what to double-check |
|----------|----------------|----------------------|
| `AI_EMBED` | `AI_EMBED('<model>', <input>, '<text\|image>', <dim>)` | order of input-type vs dim; model id (`qwen3-vl-embedding`); image needs `FETCH_CONTENT` (data URL) |
| `FETCH_CONTENT` | `FETCH_CONTENT(<url>)` | returns Base64 **data URL** for images when the URL is reachable; needs outbound-net access to OSS/HTTPS |
| `VECTOR_SEARCH_AGG` | `VECTOR_SEARCH_AGG('<collection>', <vec>, <topk>)` | required Milvus-connector config; returns JSON array of hits; metric (cosine) often added as extra arg |
| `ML_PREDICT` | `ML_PREDICT('<model>', <json>, <schema>)` | schema/prompt shape varies; model id (`qwen3.6-plus`); paid tier required for real inference |
| Python inline UDF | `CREATE TEMPORARY FUNCTION … AS 'inline' LANGUAGE PYTHON` | namespace `flink.table.udf.ScalarFunction`; ensure PyFlink enabled |

If a function errors on your cluster, the first thing to check is argument
**order**, then the **model id / provider**, then whether the **AI service
model** is actually provisioned (these endpoint slugs are placeholders).

## Milvus `product_label` collection

- Dim: **1024** (matches `qwen3-vl-embedding` output).
- Fields: `label_id`(string pk), `label_name`, `label_desc`, `label_emb`(vector).
- Seeded by `labels/labels.sql` (8 labels). Keep the dim consistent between the
  seed job and the recall queries (`VECTOR_SEARCH_AGG` top-k of 3).
- Metric: cosine (or whichever your Milvus metric column uses — keep metric
  consistent between seed and search).

## Streaming semantics

- The standalone demo (`VALUES` + print) is a bounded source → finishes on its
  own; results are in the TaskManager logs under `print_result`.
- For streaming, swap in `02_source_ddl.sql` (Kafka) and `06_sink_insert.sql`
  (Upsert Kafka `product_tags`). Watermark on `event_time` keeps it a proper
  time-series job; add/with any tumbling-window aggregation upstream of the
  judge if you want to batch recall per window.