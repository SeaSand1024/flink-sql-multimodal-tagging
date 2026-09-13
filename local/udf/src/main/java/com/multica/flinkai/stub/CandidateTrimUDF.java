package com.multica.flinkai.stub;

import org.apache.flink.table.functions.ScalarFunction;

/**
 * Local stand-in for the article's Python inline `candidate_trim` UDF.
 *
 * The real Python UDF compacted the verbose VECTOR_SEARCH_AGG JSON into
 * {"label","score"} entries. The local VectorSearchUDF already returns that
 * compact shape, so this is a pass-through — kept so the SQL pipeline keeps the
 * same candidate_trim(...) call as the shipped SQL.
 */
public class CandidateTrimUDF extends ScalarFunction {

  public String eval(String raw) {
    return raw == null ? "[]" : raw;
  }
}