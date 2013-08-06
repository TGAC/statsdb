package uk.ac.bbsrc.tgac.statsdb;

import org.apache.commons.cli.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.ApplicationContext;
import org.springframework.context.support.ClassPathXmlApplicationContext;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import uk.ac.bbsrc.tgac.statsdb.analysis.DefaultQCAnalysis;
import uk.ac.bbsrc.tgac.statsdb.analysis.PartitionValue;
import uk.ac.bbsrc.tgac.statsdb.analysis.PositionValue;
import uk.ac.bbsrc.tgac.statsdb.analysis.QCAnalysis;
import uk.ac.bbsrc.tgac.statsdb.exception.QCAnalysisException;
import uk.ac.bbsrc.tgac.statsdb.run.parser.FastQCReportParser;
import uk.ac.bbsrc.tgac.statsdb.run.parser.QcReportParser;

import javax.sql.DataSource;
import java.io.File;
import java.util.Map;

/**
 * uk.ac.bbsrc.tgac.statsdb
 * <p/>
 * Info
 *
 * @author Rob Davey
 * @date 06/08/13
 * @since 1.1-SNAPSHOT
 */
public class StatsDbApp {
  protected static final Logger log = LoggerFactory.getLogger(StatsDbApp.class);

  public static void main(String[] args) {
    ApplicationContext context = new ClassPathXmlApplicationContext("db-config.xml");

    Options options = new Options();

    options.addOption("h", false, "Print this help");
    options.addOption("t", false, "Test mode. Doesn't write anything to the database.");
    options.addOption("v", false, "Verbose mode. Use if you like lots of tasty output.");

    Option inputFileOption = OptionBuilder.withArgName("file")
        .hasArg()
        .withDescription("use given input file")
        .create("f");
    options.addOption(inputFileOption);

    Option parserTypeOption = OptionBuilder.withArgName("fastqc,other")
        .hasArg()
        .withDescription("use specified parser type")
        .create("p");
    options.addOption(parserTypeOption);

    CommandLineParser parser = new BasicParser();
    try {
      CommandLine line = parser.parse(options, args);

      if (line.hasOption("h")) {
        HelpFormatter formatter = new HelpFormatter();
        formatter.printHelp( "statsdb.jar", options );
      }

      QcReportParser<File> qcParser = null;
      if (line.hasOption("p")) {
        String parserType = line.getOptionValue("p");
        if ("".equals(parserType) || "fastqc".equals(parserType)) {
          qcParser = new FastQCReportParser();
        }
        else if ("other".equals(parserType)) {
          log.error("Unsupported option 'other'. Please specify a parser type.");
          System.exit(1);
        }
      }
      else {
        log.info("No parser type specified. Using FASTQC as the default report type.");
        qcParser = new FastQCReportParser();
      }

      if (line.hasOption("f")) {
        File inputfile = new File(line.getOptionValue("f"));
        if (!inputfile.exists()) {
          log.error("No input file specified.");
          System.exit(1);
        }
        else {
          QCAnalysis qca = new DefaultQCAnalysis();
          qcParser.parseReport(inputfile, qca);

          if (line.hasOption("v")) {
            log.info("Position values:");
            for (PositionValue p : qca.getPositionValues()) {
              log.info("\t\\_ " + p.getKey()+":"+p.getValue()+":"+p.getPosition());
            }

            log.info("Partition values:");
            for (PartitionValue p : qca.getPartitionValues()) {
              log.info("\t\\_ " + p.getKey()+":"+p.getValue()+":"+p.getPosition()+":"+p.getSize());
            }

            log.info("General values:");
            for (Map.Entry<String, String> p : qca.getGeneralValues().entrySet()) {
              log.info("\t\\_ " + p.getKey()+":"+p.getValue());
            }
          }

          if (!line.hasOption("t")) {
            //write stuff to the database
            log.info("Writing stuff to the database...");
          }
        }
      }
    }
    catch (ParseException e) {
      log.error("Parsing failed.  Reason: " + e.getMessage());
      e.printStackTrace();
      System.exit(1);
    }
    catch (QCAnalysisException e) {
      log.error("Unable to parse QC report: " + e.getMessage());
      e.printStackTrace();
      System.exit(1);
    }
    System.exit(0);
  }
}
