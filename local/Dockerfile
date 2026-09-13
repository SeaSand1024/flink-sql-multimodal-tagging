# Local run image: plain Apache Flink standalone + the AI stub UDF jar + demo SQL.
# Build context is ./local (run via docker compose from local/).
FROM flink:1.18-scala_2.12

# Ship the stub UDFs on the cluster classpath (jobmanager + taskmanager both get a copy).
COPY udf/target/flink-ai-stub-udf.jar /opt/flink/lib/flink-ai-stub-udf.jar
# Note: jar is pre-built by run.sh (mvn package) before `docker compose build`.

# Demo SQL mounted into the JobManager so the SQL client can read it.
COPY sql/local_stub_demo.sql /opt/sql/local_stub_demo.sql

# UTF-8 so CJK labels survive into logs / SQL client file reads.
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8