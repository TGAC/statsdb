package uk.ac.bbsrc.tgac.statsdb.run;

import java.sql.SQLException;
import java.util.HashMap;
import java.util.Map;

/**
 * This decorator is used to get reports that are easier to read.
 * <p/>
 * Created by IntelliJ IDEA.
 * User: ramirezr
 * Date: 16/04/2012
 * Time: 14:26
 */
public class ReportsDecorator {
  Reports r;

  public ReportsDecorator(Reports r) {
    this.r = r;
  }

  /**
   * Gets a summary of all the basic statistics.
   * The results of this table can be printed straight away as a general summary report.
   * <p/>
   * TODO: Gather all the textual properties that all the related analysis have in common.
   *
   * @param runProperties
   * @return
   * @throws SQLException
   */
  public ReportTable getBasicStatistics(Map<RunProperty, String> runProperties) throws SQLException {
    //ArrayList<String[]> table = new ArrayList<String[]>(); //When we add complexity to the summary, we have to build the RunTable manually.
    return r.getAverageValues(runProperties);
  }

  /**
   * This wrapper is for convenience. It gets a Map used to create the plot of the quality per base.
   * The map contains the following ReportTables:
   * <p/>
   * -quality_mean
   * <p/>
   * -quality_90th_percentile
   * -quality_upper_quartile
   * -quality_median
   * -quality_lower_quartile
   * -quality_10th_percentile
   * <p/>
   * This is to reproduce a plot like the qualities plot in FastQC. Have a look at the plots in:
   * http://www.bioinformatics.babraham.ac.uk/projects/fastqc/bad_sequence_fastqc/fastqc_report.html
   * <p/>
   * The report tables produced have three columns: position, size and Average. The position
   * column is the first base in the range, the second column is ths size of the block and the
   * third column is the average value for the queried set. If the queried set is a single sample,
   * then the values for the specific run are given.
   * <p/>
   * If a property is missing, the query aggregates of all the runs sharing the properties.
   * <p/>
   * The RunProperty.barcode has to be in base space.
   * <p/>
   * At the moment, only RunProperty.instrument (hiseq-1), RunProperty.run (111104_SN319_0169_BD08YFACXX), RunProperty.lane (1-8), RunProperty.pair(1-2) and RunProperty.barcode (ACCAT) are supported
   *
   * @param runProperties a Map with the properties to select.
   * @return a map containing  a ReportTable for each one of the values listed above.
   * @throws SQLException if there is an issue calling the store procedure
   */
  public Map<String, ReportTable> getPerPositionBaseSequenceQuality(Map<RunProperty, String> runProperties) throws SQLException {
    Map<String, ReportTable> report = new HashMap<String, ReportTable>();
    String reportList[] = {"quality_mean", "quality_90th_percentile", "quality_upper_quartile", "quality_median", "quality_lower_quartile", "quality_10th_percentile"};

    for (String s : reportList) {
      report.put(s, r.getPerPositionValues(s, runProperties));
    }
    return report;
  }

  /**
   * This wrapper generates a table whith the overrepresented sequences in a run. If called on a full lane, it gets averages which can be transfored to totals by multiplying by the last
   * column in the table. The table contains the following columns and order:
   * Description: The sequence that is overrepresented in base space
   * Comment: A Verbose description of the overrepresented sequence, if available.
   * Average: The average number of times the sequence appears
   * Samples: How many "samples" where generated to make the summary.
   * Total: The total count in all the samples
   * <p/>
   * <p/>
   * The RunProperty.barcode has to be in base space.
   * <p/>
   * At the moment, only RunProperty.instrument (hiseq-1), RunProperty.run (111104_SN319_0169_BD08YFACXX), RunProperty.lane (1-8), RunProperty.pair(1-2) and RunProperty.barcode (ACCAT) are supported
   *
   * @param runProperties a Map with the properties to select.
   * @return A table with the overrepresented sequences
   * @throws SQLException if there is an issue calling the store procedure
   */
  public ReportTable getOverrepresentedSequences(Map<RunProperty, String> runProperties) throws SQLException {
    return r.getSummaryValuesWithComments("overrepresented_sequence", runProperties);
  }

  /**
   * It gets a Map used to create the plot of the base content per position.
   * The map contains the following ReportTables:
   * <p/>
   * -base_content_a
   * -base_content_c
   * -base_content_g
   * -base_content_t
   * <p/>
   * This is to reproduce a plot like the base content plot in FastQC. Have a look at the plots in:
   * http://www.bioinformatics.babraham.ac.uk/projects/fastqc/bad_sequence_fastqc/fastqc_report.html
   * <p/>
   * The report tables produced have five columns: position, size,  Average, samples, total. The position
   * column is the first base in the range, the second column is ths size of the block and the
   * third column is the average value for the queried set. The fourth column is the number of samples included in the summary.
   * The fifth column, total,  is a global sum. If the queried set is a single sample,
   * then the values for the specific run are given.
   * <p/>
   * If a property is missing, the query aggregates of all the runs sharing the properties.
   * <p/>
   * The RunProperty.barcode has to be in base space.
   * <p/>
   * At the moment, only RunProperty.instrument (hiseq-1), RunProperty.run (111104_SN319_0169_BD08YFACXX), RunProperty.lane (1-8), RunProperty.pair(1-2) and RunProperty.barcode (ACCAT) are supported
   *
   * @param runProperties a Map with the properties to select.
   * @return a map containing  a ReportTable for each one of the values listed above.
   * @throws SQLException if there is an issue calling the store procedure
   */
  public Map<String, ReportTable> getPerPositionBaseContent(Map<RunProperty, String> runProperties) throws SQLException {
    Map<String, ReportTable> report = new HashMap<String, ReportTable>();
    String reportList[] = {"base_content_a", "base_content_c", "base_content_g", "base_content_t"};

    for (String s : reportList) {
      report.put(s, r.getPerPositionValues(s, runProperties));
    }
    return report;
  }

  /**
   * This wrapper generates a table with the overrepresented tags in a run.It reports the tags that do not correspond to any expected sample.
   * If called on a full lane, it gets average count, the number of samples and the total cunt
   * column in the table. The table contains the following columns and order:
   * Description: The sequence that is overrepresented in base space
   * Average: The average number of times the sequence appears
   * Samples: How many "samples" where generated to make the summary.
   * Total: The total count in all the samples
   * <p/>
   * The RunProperty.barcode has to be in base space.
   * <p/>
   * At the moment, only RunProperty.instrument (hiseq-1), RunProperty.run (111104_SN319_0169_BD08YFACXX), RunProperty.lane (1-8), RunProperty.pair(1-2) and RunProperty.barcode (ACCAT) are supported
   *
   * @param runProperties a Map with the properties to select.
   * @return A table with the overrepresented sequences
   * @throws SQLException if there is an issue calling the store procedure
   */
  public ReportTable getOverrepresentedTags(Map<RunProperty, String> runProperties) throws SQLException {
    return r.getSummaryValues("multiplex_tag", runProperties);
  }
}

