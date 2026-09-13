package com.multica.flinkai.stub;

import org.apache.flink.table.annotation.DataTypeHint;
import org.apache.flink.table.functions.ScalarFunction;

/**
 * Stub for Alibaba Cloud FLINK SQL `ML_PREDICT('<model>', <payload>, <schema>)`.
 *
 * STAGE 2 judge. The real qwen3.6-plus call jointly reasons over (text, image)
 * plus the candidate labels. The local substitute deterministically merges the
 * candidate label sets from the text-recall and image-recall (dedup, order kept),
 * which is exactly the "resolve text/image disagreement" step the article's
 * multimodal judge performs. Returns {"labels":[...]}.
 *
 * The article builds the payload with json_OBJECT(); the local run passes
 * positional args (text, image, text_candidates, image_candidates) to avoid
 * depending on the json_OBJECT builtin.
 */
public class MlPredictUDF extends ScalarFunction {

  @DataTypeHint("STRING")
  public String eval(String model, String text, String image,
                     String textCandidates, String imageCandidates) {
    java.util.LinkedHashSet<String> merged = new java.util.LinkedHashSet<>();
    merged.addAll(Stubs.parseLabels(textCandidates));
    merged.addAll(Stubs.parseLabels(imageCandidates));

    StringBuilder sb = new StringBuilder("{\"labels\":[");
    int i = 0;
    for (String l : merged) {
      if (i++ > 0) sb.append(',');
      sb.append('"').append(l).append('"');
    }
    return sb.append("]}").toString();
  }
}