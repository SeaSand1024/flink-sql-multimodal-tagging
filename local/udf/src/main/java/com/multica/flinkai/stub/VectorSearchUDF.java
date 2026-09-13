package com.multica.flinkai.stub;

import org.apache.flink.table.annotation.DataTypeHint;
import org.apache.flink.table.functions.ScalarFunction;
import java.util.Arrays;

/**
 * Stub for Alibaba Cloud FLINK SQL `VECTOR_SEARCH_AGG('<collection>', <vec>, <topk>)`.
 *
 * Decodes the domain stored in vec[0] by AIEmbedUDF and returns the top-k
 * candidate labels as a JSON array (e.g. [{"label":"户外运动","score":0.98}, ...]).
 * Mirrors a Milvus top-k recall; the collection name is accepted but ignored.
 */
public class VectorSearchUDF extends ScalarFunction {

  @DataTypeHint("STRING")
  public String eval(String collection, Float[] vec, Integer topk) {
    int code = (vec != null && vec.length > 0 && vec[0] != null) ? Math.round(vec[0]) : 0;
    String[] labels = Stubs.recallFor(code);
    int n = Math.min(topk == null ? 3 : topk, labels.length);
    return Stubs.toJson(Arrays.copyOf(labels, n));
  }
}