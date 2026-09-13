#!/usr/bin/env bash
# run.sh — build the stub UDF jar, start a local Flink cluster, run the demo,
# then print the captured sample output from the TaskManager log.
#
# Expects: docker (daemon up) + mvn + java 8. All network deps (Maven Central,
# flink image) are pulled the first time.
set -euo pipefail
cd "$(dirname "$0")"

# Prefer the standalone binary when the `docker-compose` plugin is unavailable.
if command -v docker-compose >/dev/null 2>&1; then
  COMPOSE="docker-compose"
else
  COMPOSE="docker compose"
fi

echo ">> [1/5] building stub UDF jar (mvn package)"
(cd udf && mvn -q -DskipTests package)
test -f udf/target/flink-ai-stub-udf.jar || { echo "jar build failed"; exit 1; }

echo ">> [2/5] building local Flink image (docker-compose build)"
docker-compose build --quiet

echo ">> [3/5] starting cluster (jobmanager + taskmanager)"
docker-compose up -d

echo ">> [4/5] waiting for JobManager web UI"
ok=0
for i in $(seq 1 60); do
  if curl -sf http://localhost:8081/config >/dev/null 2>&1; then
    echo "       JobManager ready after ~${i}s"; ok=1; break
  fi
  sleep 1
done
[ "$ok" = "1" ] || { echo "JobManager not ready in time"; docker-compose logs jobmanager | tail -40; exit 1; }

echo ">> [5/5] submitting local_stub_demo.sql via SQL client"
docker-compose exec -e LANG=C.UTF-8 jobmanager ./bin/sql-client.sh -f /opt/sql/local_stub_demo.sql

echo ">> waiting for the bounded job to emit print rows"
# `docker-compose logs` prefixes each line with `taskmanager-1  | ` — match the
# print row anywhere in the line. Poll briefly in case the log driver lags.
rows=""
for i in $(seq 1 90); do
  rows="$(docker-compose logs --no-color taskmanager 2>&1 \
            | grep -E '\+I\[' || true)"
  [ -n "$rows" ] && break
  sleep 2
done

echo ">> ==== sample output (print connector, TaskManager stdout) ===="
if [ -n "$rows" ]; then
  echo "$rows"
else
  echo "(no +I rows printed)"
fi

echo ">> ==== job overview (name / state) ===="
curl -sf http://localhost:8081/jobs/overview | python3 -c \
  "import sys,json; d=json.load(sys.stdin); [print('  ',j['name'],'->',j['state']) for j in d['jobs']]" \
  || echo "(could not read job overview)"

echo
echo ">> Visit http://localhost:8081 for the Flink Web UI."
echo ">> Stop the cluster with:  (cd local && docker-compose down)"