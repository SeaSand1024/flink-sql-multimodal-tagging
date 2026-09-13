package com.multica.flinkai.stub;

import org.apache.flink.table.functions.ScalarFunction;

/**
 * Stub for Alibaba Cloud FLINK SQL `FETCH_CONTENT(<url>)`.
 *
 * The real function fetchs an OSS image and returns a Base64 data URL. The local
 * substitute treats image_url as an already-resolved `img:<token>` and returns
 * it verbatim — the token is what AIEmbedUDF maps to an image domain.
 */
public class FetchContentUDF extends ScalarFunction {

  public String eval(String url) {
    return url == null ? "" : url;
  }
}