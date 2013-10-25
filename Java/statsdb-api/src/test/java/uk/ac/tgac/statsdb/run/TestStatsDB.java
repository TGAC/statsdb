package uk.ac.tgac.statsdb.run;

import junit.framework.TestCase;
import org.junit.AfterClass;
import org.junit.BeforeClass;
import org.junit.Test;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.datasource.SingleConnectionDataSource;

import javax.sql.DataSource;
import java.io.IOException;
import java.io.InputStream;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Properties;

/**
 * uk.ac.tgac.qc.run
 * <p/>
 * Info
 *
 * @author Rob Davey
 * @date 12/03/12
 * @since 1.0-SNAPSHOT
 */
public class TestStatsDB {
  protected static final Logger log = LoggerFactory.getLogger(TestStatsDB.class);

  private static DataSource datasource;

  private static final String[] tables = {
      "analysis",
      "analysis_property",
      "analysis_value",
      "per_partition_value",
      "per_position_value",
      "type_scope",
      "value_type"
  };

  @BeforeClass
  public static void setUp() throws Exception {
    log.info("Initial setup...");
    InputStream in = TestStatsDB.class.getClassLoader().getResourceAsStream("test.statsdb.properties");
    Properties props = new Properties();
    props.load(in);
    log.info("Properties loaded...");

    Connection jdbcConnection = DriverManager.getConnection(
        props.getProperty("db.url"),
        props.getProperty("db.username"),
        props.getProperty("db.password")
    );
    datasource = new SingleConnectionDataSource(jdbcConnection, false);
  }

  @AfterClass
  public static void tearDown() throws SQLException {
    log.info("Final teardown...");
    Connection conn = datasource.getConnection();
    try {
      if (conn != null) {
        conn.close();
      }
    }
    catch (SQLException e) {
      e.printStackTrace();
    }
  }

  @Test
  public void testPerPositionSummary() {
    try {
      TestCase.assertNotNull(datasource);
      Connection con = datasource.getConnection();

      Reports r = new Reports(con);

      log.info("QUALITY MEAN - HiSeq1 -> CSV");
      ReportTable table = r.getPerPositionSummary("quality_mean", "instrument", "HiSeq1");
      log.info(table.toCSV());

      log.info("QUALITY MEAN - HiSeq1 -> JSON");
      table = r.getPerPositionSummary("quality_mean", "instrument", "HiSeq1");
      log.info(table.toJSON());
    }
    catch (SQLException e1) {
      e1.printStackTrace();
    }
    catch (IOException e1) {
      e1.printStackTrace();
    }
  }

  @Test
  public void testListPerBaseSummaryAnalyses() {
    try {
      TestCase.assertNotNull(datasource);
      Connection con = datasource.getConnection();

      Reports r = new Reports(con);

      log.info("PER BASE SUMMARY ANALYSIS");
      List<String> tmp_list = r.listPerBaseSummaryAnalyses();
      log.info(tmp_list.toString());
    }
    catch (SQLException e1) {
      e1.printStackTrace();
    }
  }

  @Test
  public void testListGlobalAnalyses() {
    try {
      TestCase.assertNotNull(datasource);
      Connection con = datasource.getConnection();

      Reports r = new Reports(con);

      log.info("GLOBAL ANALYSES");
      List<String> tmp_list = r.listGlobalAnalyses();
      log.info(tmp_list.toString());
    }
    catch (SQLException e1) {
      e1.printStackTrace();
    }
  }

  @Test
  public void testGetAverageGeneralTotalSequences() {
    try {
      TestCase.assertNotNull(datasource);
      Connection con = datasource.getConnection();

      Reports r = new Reports(con);

      log.info("AVERAGE GENERAL TOTAL SEQUENCES - Lane 7");
      log.info(Double.toString(r.getAverageValue("general_total_sequences", "lane", "7")));
    }
    catch (SQLException e) {
      e.printStackTrace();
    }
  }

  @Test
  public void testGetAverageLaneValues() {
    try {
      TestCase.assertNotNull(datasource);
      Connection con = datasource.getConnection();

      Reports r = new Reports(con);

      log.info("AVERAGE LANE VALUES - Lane 1");
      ReportTable table = r.getAverageValues("lane", "1");
      log.info(table.toCSV());
    }
    catch (SQLException e) {
      e.printStackTrace();
    }
  }

  @Test
  public void testGetAverageBarcodeValues() {
    try {
      TestCase.assertNotNull(datasource);
      Connection con = datasource.getConnection();

      Reports r = new Reports(con);

      log.info("AVERAGE BARCODE VALUES - GCCAAT");
      ReportTable table = r.getAverageValues("barcode", "GCCAAT");
      log.info(table.toCSV());

      log.info("AVERAGE BARCODE VALUES - GGCTAC");
      table = r.getAverageValues("barcode", "GGCTAC");
      log.info(table.toCSV());
    }
    catch (SQLException e) {
      e.printStackTrace();
    }
  }

  @Test
  public void testGetAnalysisProperties() {
    try {
      TestCase.assertNotNull(datasource);
      Connection con = datasource.getConnection();

      Reports r = new Reports(con);

      List<String> tmp_list = r.getAnalysisProperties();

      for (String s : tmp_list) {
        List<String> values = r.getValuesForProperty(s);
        log.info(s + " -> " + values.toString());
      }

      Map<RunProperty, String> properties = new HashMap<RunProperty, String>();
      ReportTable table = r.getAverageValues(properties);
      log.info(table.toJSON());

      table = r.getPerPositionValues("quality_mean", properties);
      log.info(table.toCSV());

      properties.put(RunProperty.lane, "1");
      table = r.getAverageValues(properties);
      log.info(table.toJSON());

      table = r.getPerPositionValues("quality_mean", properties);
      log.info(table.toCSV());
    }
    catch (SQLException e) {
      e.printStackTrace();
    }
    catch (IOException e) {
      e.printStackTrace();
    }
  }

  @Test
  public void testGetPerBaseQuality() {
    try {
      TestCase.assertNotNull(datasource);
      Connection con = datasource.getConnection();

      Map<RunProperty, String> properties = new HashMap<>();
      Reports r = new Reports(con);
      ReportsDecorator rd = new ReportsDecorator(r);

      Map<String, ReportTable> perBaseQuality = rd.getPerPositionBaseSequenceQuality(properties);

      log.info("Tables in quality per base: " + perBaseQuality.keySet().toString());
      for (String k : perBaseQuality.keySet()) {
        log.info("Quality table: " + k);
        log.info(perBaseQuality.get(k).toCSV());
      }
    }
    catch (SQLException e) {
      e.printStackTrace();
    }
  }

  @Test
  public void testGetOverrepresentedSequences() {
    try {
      TestCase.assertNotNull(datasource);
      Connection con = datasource.getConnection();

      Map<RunProperty, String> properties = new HashMap<>();
      Reports r = new Reports(con);
      ReportsDecorator rd = new ReportsDecorator(r);
      ReportTable rt = rd.getOverrepresentedSequences(properties);

      log.info("Overrepresented sequences: " + rt.toCSV());
    }
    catch (SQLException e) {
      e.printStackTrace();
    }
  }

  @Test
  public void testBaseContent() {
    try {
      TestCase.assertNotNull(datasource);
      Connection con = datasource.getConnection();

      Map<RunProperty, String> properties = new HashMap<>();
      Reports r = new Reports(con);
      ReportsDecorator rd = new ReportsDecorator(r);

      Map<String, ReportTable> perBaseQuality = rd.getPerPositionBaseContent(properties);

      log.info("Tables in base content: " + perBaseQuality.keySet().toString());
      for (String k : perBaseQuality.keySet()) {
        log.info("Content table: " + k);
        log.info(perBaseQuality.get(k).toCSV());
      }
    }
    catch (SQLException e) {
      e.printStackTrace();
    }
  }

  @Test
  public void testGetOverrepresentedTags() {
    try {
      TestCase.assertNotNull(datasource);
      Connection con = datasource.getConnection();

      Map<RunProperty, String> properties = new HashMap<RunProperty, String>();
      Reports r = new Reports(con);
      ReportsDecorator rd = new ReportsDecorator(r);

      ReportTable rt = rd.getOverrepresentedTags(properties);

      log.info("Overrepresented tags: " + rt.toCSV());
    }
    catch (SQLException e) {
      e.printStackTrace();
    }
  }
}
