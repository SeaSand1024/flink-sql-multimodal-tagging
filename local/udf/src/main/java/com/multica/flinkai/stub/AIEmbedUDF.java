package com.multica.flinkai.stub;

import org.apache.flink.table.annotation.DataTypeHint;
import org.apache.flink.table.functions.ScalarFunction;

/**
 * Stub for Alibaba Cloud FLINK SQL `AI_EMBED(<model>, <input>, <type>[, <dim>])`.
 *
 * Local substitute returns a 1024-dim FLINK ARRAY<FLOAT> whose first bin encodes
 * a deterministic semantic domain derived from the input. Not a real embedding —
 * see Stubs.codeFor(). Dim is fixed at 1024 to match the article.
 */
public class AIEmbedUDF extends ScalarFunction {

  private static final int DIM = 1024;

  @DataTypeHint("ARRAY<FLOAT>")
  public Float[] eval(String input, String type) {
    int code = Stubs.codeFor(input, type);
    Float[] v = new Float[DIM];
    java.util.Arrays.fill(v, 0f);
    v[0] = (float) code;
    return v;
  }
}