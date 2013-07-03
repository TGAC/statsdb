package uk.ac.bbsrc.tgac.qc.run.parser;

import uk.ac.bbsrc.tgac.qc.analysis.QCAnalysis;
import uk.ac.bbsrc.tgac.qc.exception.QCAnalysisException;

import java.io.*;
import java.util.HashMap;
import java.util.Map;

/**
 * uk.ac.bbsrc.tgac.qc.run.parser
 * <p/>
 * Info
 *
 * @author Rob Davey
 * @date 03/07/13
 * @since 1.0-SNAPSHOT
 */
public class FastQCReportParser implements QcReportParser<File> {

  private Map<String, String> values = new HashMap<>();
  private Map<String, String> valueKeys= new HashMap<>();
  private Map<String, String> headerKeys= new HashMap<>();

  public FastQCReportParser() {
    values.put("general_total_sequences", "analysis");
    values.put("general_filtered_sequences", "analysis");
    values.put("general_min_length", "analysis");
    values.put("general_max_length", "analysis");
    values.put("general_gc_content", "analysis");
    values.put("total_duplicate_percentage", "analysis");

    values.put("quality_mean", "base_partition");
    values.put("quality_median", "base_partition");
    values.put("quality_lower_quartile", "base_partition");
    values.put("quality_upper_quartile", "base_partition");
    values.put("quality_10th_percentile", "base_partition");
    values.put("quality_90th_percentile", "base_partition");
    values.put("base_content_a", "base_partition");
    values.put("base_content_c", "base_partition");
    values.put("base_content_g", "base_partition");
    values.put("base_content_t", "base_partition");
    values.put("gc_content_percentage", "base_partition");
    values.put("base_content_n_percentage", "base_partition");

    values.put("quality_score_count", "sequence_cumulative");
    values.put("gc_content_count", "sequence_cumulative");
    values.put("sequence_length_count", "sequence_cumulative");
    values.put("duplication_level_relative_count", "sequence_cumulative");

    valueKeys.put("Total Sequences", "general_total_sequences");
    valueKeys.put("Filtered Sequences", "general_filtered_sequences");
    valueKeys.put("%GC", "general_gc_content");
    
    headerKeys.put("%GC", "percentage");
    headerKeys.put("n-count", "n_percentage");
  }

  @Override
  public void parseReport(File in, QCAnalysis qcAnalysis) throws QCAnalysisException {
    try {
      FileInputStream r = new FileInputStream(in);
      qcAnalysis.addProperty("tool", "FastQC");

      for (Map.Entry<String, String> kv : values.entrySet()) {
        qcAnalysis.addValueType(kv.getKey(), kv.getValue());
      }

      processFastQCReportFile(r, qcAnalysis);
    }
    catch (FileNotFoundException e) {
      throw new QCAnalysisException("Cannot open FastQC report file for reading: " + in.getAbsolutePath(), e);
    }
  }

  private void processFastQCReportFile(FileInputStream r, QCAnalysis qcAnalysis) throws QCAnalysisException {
    BufferedReader br = null;
    try {
      br = new BufferedReader(new InputStreamReader(r));
      String line;
      boolean first = true;
      String[] headers = null;
      while ((line = br.readLine()) != null) {

      }
    }
    catch (IOException e) {
      System.err.println("Error parsing run metadata headers: " + e.getMessage());
    }
    finally {
      if (br != null) {
        try {
          br.close();
          r.getChannel().position(0);
        }
        catch (IOException e) {
          e.printStackTrace();
        }
      }
    }
  }

  private void parseBasicStatistics(FileInputStream r, QCAnalysis qcAnalysis) {

  }
}
