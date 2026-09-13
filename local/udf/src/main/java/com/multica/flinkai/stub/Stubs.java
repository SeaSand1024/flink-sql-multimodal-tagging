package com.multica.flinkai.stub;

import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

/**
 * Shared deterministic "recall catalog" for the local stubs.
 *
 * This is NOT a real embedding / vector DB. It simulates the two AI calls the
 * article makes on the paid VVR endpoint:
 *   - AI_EMBED()  returns a 1024-dim vector whose first bin encodes a semantic
 *                 domain derived from the input text token or image token.
 *   - VECTOR_SEARCH_AGG() decodes that domain and returns the top-k candidate
 *                 labels for it (as a JSON array), mirroring a Milvus recall.
 *
 * Domain codes are keyed on explicit `#key:<name>` (text) and `img:<name>`
 * (image) tokens so the demo is deterministic and encoding-safe. The mapping is
 * intentional so the 3 sample events demonstrate text/image complementarity:
 * e.g. e2's IMAGE recall adds "数码家电" which the TEXT recall does not contain.
 */
final class Stubs {

  /** The 8 labels from labels/labels.sql. */
  static final String[] CATALOG = {
      "户外运动", "智能穿戴", "美妆护肤", "数码家电",
      "家居生活", "食品饮料", "服饰穿搭", "母婴玩具"
  };

  /** domain code -> candidate labels (top-k, in score order). */
  private static final Map<Integer, String[]> RECALL = new HashMap<>();

  static {
    // text domains
    RECALL.put(1,  new String[]{"户外运动", "服饰穿搭"}); // #key:outdoor
    RECALL.put(2,  new String[]{"智能穿戴"});             // #key:wearable
    RECALL.put(3,  new String[]{"美妆护肤"});             // #key:skincare
    // image domains
    RECALL.put(11, new String[]{"户外运动", "服饰穿搭"});   // img:camping
    RECALL.put(12, new String[]{"智能穿戴", "数码家电"});   // img:band   -> image ADDS 数码家电
    RECALL.put(13, new String[]{"美妆护肤"});               // img:jar
    // fallback (unmapped input)
    RECALL.put(0,  new String[]{"食品饮料", "家居生活"});
    RECALL.put(10, new String[]{"家居生活", "食品饮料"});
  }

  /** Map an AI_EMBED input to a deterministic domain code. */
  static int codeFor(String input, String type) {
    String low = input == null ? "" : input.toLowerCase(Locale.ROOT);
    if ("image".equalsIgnoreCase(type)) {
      if (low.contains("img:band"))  return 12;
      if (low.contains("img:jar"))   return 13;
      if (low.contains("img:camp"))  return 11;
      return 10;
    }
    if (low.contains("key:outdoor") || low.contains("冲锋") || low.contains("露营")) return 1;
    if (low.contains("key:wearable") || low.contains("手环") || low.contains("可穿戴")) return 2;
    if (low.contains("key:skincare") || low.contains("面霜") || low.contains("护肤")) return 3;
    return 0;
  }

  static String[] recallFor(int code) {
    return RECALL.getOrDefault(code, RECALL.get(0));
  }

  /** Render candidate labels as the trimmed JSON the judge consumes. */
  static String toJson(String[] labels) {
    StringBuilder sb = new StringBuilder("[");
    double[] scores = {0.98, 0.92, 0.85};
    int n = labels.length;
    for (int i = 0; i < n; i++) {
      if (i > 0) sb.append(',');
      sb.append("{\"label\":\"").append(labels[i])
        .append("\",\"score\":")
        .append(String.format(Locale.ROOT, "%.2f", scores[Math.min(i, 2)]))
        .append('}');
    }
    return sb.append(']').toString();
  }

  /** Collect label names from a candidate-JSON array (used by the judge). */
  static java.util.List<String> parseLabels(String json) {
    java.util.List<String> out = new java.util.ArrayList<>();
    if (json == null) return out;
    java.util.regex.Matcher m =
        java.util.regex.Pattern.compile("\"label\":\"([^\"]*)\"").matcher(json);
    while (m.find()) out.add(m.group(1));
    return out;
  }

  private Stubs() {}
}