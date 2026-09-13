#!/usr/bin/env bash
# scripts/submit.sh — copy-paste helper for submitting the SQL to a cluster.
# This is a convenience scaffold; the primary path is the Realtime Compute SQL
# editor (see README "How to run"). Adjust FLINK_SUBMIT to your environment.
set -euo pipefail

FLINK_SUBMIT="${FLINK_SUBMIT:-flink}"
JAR="${JAR:-}"
# file to submit; default to the standalone demo
TARGET="${1:-./sql/demo_all_standalone.sql}"

echo ">> Submitting: $TARGET"

# SQL gateway (Flink 1.17+/VVR 11.x) usage — spare the ; DDL terminator parsing
# args: (WORKSPACE, SQL_STATEMENT_FILE, AIDB, CLUSTER, JOB_NAME)
# For a local/standalone cluster, the gateway handles one <STATEMENT>; submit with:
#   ${FLINK_SUBMIT} run-application -t kubernetes-application \
#      -Dkubernetes.cluster-id=flink-ai-tagging \
#      -j "$JAR" \
#      -c com.alibaba.realtimecompute.ai.AIJobMain "$TARGET"

echo ">> Done scaffolding. Open the SQL editor and paste: $TARGET"
echo ">> Tip: run 01_env.sql → 02…06 in order; labels/labels.sql first run only."