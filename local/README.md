# Local run — Apache Flink + stubbed AI

This is the **closest runnable local substitute** for the article. It runs the
exact two-stage SQL pipeline on a **plain Apache Flink standalone** cluster
(Docker Compose), where the Alibaba Cloud AI-Service functions are served by a
small **deterministic stub UDF jar** instead of the paid VVR endpoint.

```
local/
├── Dockerfile              # flink:1.18-scala_2.12 + stub jar + demo SQL
├── docker-compose.yml      # jobmanager (8081) + 1 taskmanager
├── run.sh                  # build jar → build image → up → submit SQL → print output
├── sql/
│   └── local_stub_demo.sql # the pipeline (params-driven mirror of sql/demo_all_standalone.sql)
└── udf/                    # Maven project: local stubs for the 5 AI functions
```

## What runs vs. what is stubbed

| Flink SQL function (paid VVR) | local substitute (`udf/`) |
|-------------------------------|----------------------------|
| `AI_EMBED('qwen3-vl-embedding', …)` | `AIEmbedUDF` → deterministic 1024-`ARRAY<FLOAT>`; bin[0] encodes a semantic domain |
| `VECTOR_SEARCH_AGG('product_label', v, 3)` | `VectorSearchUDF` → decodes domain, returns top-k `[{label,score}...]` (in-memory, no Milvus) |
| `FETCH_CONTENT(oss_url)` | `FetchContentUDF` → returns the `img:<token>` as the resolved content |
| `ML_PREDICT('qwen3.6-plus', …)` | `MlPredictUDF` → merges text+image candidate label sets (dedup) → `{"labels":[…]}` |
| Python inline `candidate_trim` | `CandidateTrimUDF` → pass-through (stub already trims) |

The pipeline **shape is faithful** (VALUES → embed-recall → judge → print), and
the sample data deliberately exercises **text/image complementarity**: e2's
image recall adds `数码家电`, which text recall alone does not produce — the
judge finds it by merging both.

## Prereqs

- macOS/Linux with **Docker** (daemon running)
- **Maven 3.x** + **JDK 8** (jar build only; the container runs its own JDK 11)

## How to run

From the repo root:

```bash
cd local
./run.sh
```

suite does: build jar → `docker compose build` → `docker compose up -d` →
wait for JobManager → `./bin/sql-client.sh -f /opt/sql/local_stub_demo.sql` →
grep the TaskManager log for the print rows.

Expected sample output (three events → combined multi-labels):

```
+I[e1, [{"label":"户外运动","score":0.98},…], […], {labels:["户外运动","服饰穿搭"]}]
+I[e2, …, …, {labels:["智能穿戴","数码家电"]}]     # 数码家电 comes from the image recall
+I[e3, …, …, {labels:["美妆护肤"]}]
```

Also live at **http://localhost:8081** (Flink Web UI). Stop with
`(cd local && docker compose down)`.

## Manual teardown / rerun

```bash
cd local
docker compose down          # stop cluster
./run.sh                     # rebuild + rerun from scratch
```

## Honest gap

This is a **substitute**, not the real thing: it validates that the SQL pipeline
and the multilabel-complementarity logic run on a real Flink engine, but it does
**not** perform real embedding / vector recall / multimodal inference. To get
the genuine article output you need the Alibaba Cloud Realtime Compute Flink
(VVR 11.9 Preview 2+) cluster with `qwen3-vl-embedding` + `qwen3.6-plus`
provisioned and the Milvus `product_label` collection seeded (`labels/labels.sql`).
The stub borrows each AI call's *contract* so the SQL mirrors the shipped
`sql/demo_all_standalone.sql`; swap the `CREATE TEMPORARY SYSTEM FUNCTION …`
registration for the cloud functions there.