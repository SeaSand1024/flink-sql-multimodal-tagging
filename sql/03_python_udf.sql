-- 03_python_udf.sql — Python inline UDF used by both recall and judge stages.
CREATE TEMPORARY FUNCTION candidate_trim AS 'inline'
LANGUAGE PYTHON
AS $$
from typing import Iterator
from flink.table.udf import ScalarFunction

class candidate_trim(ScalarFunction):
    """Compact a VECTOR_SEARCH_AGG JSON result into [{'label': .., 'score': ..}...]."""
    def eval(self, raw: str) -> str:
        import json
        if raw is None:
            return '[]'
        try:
            data = json.loads(raw)
        except (ValueError, TypeError):
            return '[]'
        if not isinstance(data, list):
            data = [data]
        out = []
        for item in data:
            row = item if isinstance(item, dict) else {}
            out.append({
                'label': row.get('label_name') or row.get('label') or row.get('entity') or '',
                'score': round(float(row.get('score') or row.get('distance') or 0.0), 4),
            })
        return json.dumps(out, ensure_ascii=False)
$$;