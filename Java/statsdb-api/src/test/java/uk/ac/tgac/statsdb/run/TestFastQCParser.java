package uk.ac.tgac.statsdb.run;

import org.junit.AfterClass;
import org.junit.BeforeClass;
import org.junit.Test;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import uk.ac.tgac.statsdb.analysis.DefaultQCAnalysis;
import uk.ac.tgac.statsdb.analysis.PartitionValue;
import uk.ac.tgac.statsdb.analysis.PositionValue;
import uk.ac.tgac.statsdb.analysis.QCAnalysis;
import uk.ac.tgac.statsdb.exception.QCAnalysisException;
import uk.ac.tgac.statsdb.run.parser.FastQCReportParser;
import uk.ac.tgac.statsdb.run.parser.QcReportParser;

import java.io.*;
import java.net.URI;
import java.net.URL;
import java.util.Map;

/**
 * Created with IntelliJ IDEA.
 * User: rob
 * Date: 30/07/13
 * Time: 13:20
 * To change this template use File | Settings | File Templates.
 */
public class TestFastQCParser {
  protected static final Logger log = LoggerFactory.getLogger(TestFastQCParser.class);

  private static QcReportParser<File> fastqcReportParser;
  private static File f;
  private static QCAnalysis fastqcAnalysis;

  @BeforeClass
  public static void setUp() throws IOException {
    log.info("Initial setup...");
    fastqcReportParser = new FastQCReportParser();
    URL furl = TestFastQCParser.class.getResource("/fastqc_data.txt");
    if (furl == null) {
      throw new IOException("No such file 'fastqc_data.txt'. Cannot run FastQC parser tests");
    }
    else {
      f = new File(URI.create(furl.toString()));
    }
  }

  @Test
  public void parseFastQCReport() throws QCAnalysisException {
    fastqcAnalysis = new DefaultQCAnalysis();
    fastqcReportParser.parseReport(f, fastqcAnalysis);
  }

  @Test
  public void checkQcAnalysisObejct() throws QCAnalysisException {
    if (fastqcAnalysis != null) {
      log.info("Position values:");
      for (PositionValue p : fastqcAnalysis.getPositionValues()) {
        log.info("\t\\_ " + p.getKey()+":"+p.getValue()+":"+p.getPosition());
      }

      log.info("Partition values:");
      for (PartitionValue p : fastqcAnalysis.getPartitionValues()) {
        log.info("\t\\_ " + p.getKey()+":"+p.getValue()+":"+p.getPosition()+":"+p.getSize());
      }

      log.info("General values:");
      for (Map.Entry<String, String> p : fastqcAnalysis.getGeneralValues().entrySet()) {
        log.info("\t\\_ " + p.getKey()+":"+p.getValue());
      }
    }
    else {
      throw new QCAnalysisException("No fastqcAnalysis object available. Parsing probably failed.");
    }
  }

  @AfterClass
  public static void tearDown() {
    log.info("Final teardown...");
    fastqcReportParser = null;
  }
}
