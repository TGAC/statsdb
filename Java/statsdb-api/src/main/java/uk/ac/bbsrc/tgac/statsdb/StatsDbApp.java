package uk.ac.bbsrc.tgac.statsdb;

import org.apache.commons.cli.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.ApplicationContext;
import org.springframework.context.support.ClassPathXmlApplicationContext;
import org.springframework.dao.DataAccessException;
import uk.ac.bbsrc.tgac.statsdb.analysis.DefaultQCAnalysis;
import uk.ac.bbsrc.tgac.statsdb.analysis.PartitionValue;
import uk.ac.bbsrc.tgac.statsdb.analysis.PositionValue;
import uk.ac.bbsrc.tgac.statsdb.analysis.QCAnalysis;
import uk.ac.bbsrc.tgac.statsdb.dao.QCAnalysisStore;
import uk.ac.bbsrc.tgac.statsdb.exception.QCAnalysisException;
import uk.ac.bbsrc.tgac.statsdb.run.parser.AnalysisMetadataParser;
import uk.ac.bbsrc.tgac.statsdb.run.parser.FastQCReportParser;
import uk.ac.bbsrc.tgac.statsdb.run.parser.QcReportParser;

import java.io.File;
import java.util.ArrayList;
import java.util.List;
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
    Options options = new Options();

    options.addOption("h", false, "Print this help");
    options.addOption("t", false, "Test mode. Doesn't write anything to the database.");
    options.addOption("v", false, "Verbose mode. Use if you like lots of tasty output.");

    Option metadataFileOption = OptionBuilder.withArgName("file")
        .hasArg()
        .withDescription("Process multiple reports using a StatsDB metadata table file")
        .create("m");
    options.addOption(metadataFileOption);

    Option inputFileOption = OptionBuilder.withArgName("file")
        .hasArg()
        .withDescription("Use given input report file")
        .create("f");
    options.addOption(inputFileOption);

    Option parserTypeOption = OptionBuilder.withArgName("fastqc,other")
        .hasArg()
        .withDescription("Use specified parser type")
        .create("p");
    options.addOption(parserTypeOption);

    Option runNameOption = OptionBuilder.withArgName("run")
        .hasArg()
        .withDescription("Associate the report with a given run name")
        .create("r");
    options.addOption(runNameOption);

    CommandLineParser parser = new BasicParser();
    try {
      CommandLine line = parser.parse(options, args);

      if (line.hasOption("h")) {
        HelpFormatter formatter = new HelpFormatter();
        formatter.printHelp("statsdb.jar", options);
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

      List<QCAnalysis> qcas = new ArrayList<>();

      if (line.hasOption("m")) {
        File inputfile = new File(line.getOptionValue("m"));
        if (!inputfile.exists()) {
          log.error("No input metadata file specified.");
          System.exit(1);
        }
        else {
          AnalysisMetadataParser amp = new AnalysisMetadataParser();
          List<QCAnalysis> pqcas = amp.parseMetadataFile(inputfile);
          for (QCAnalysis pqca : pqcas) {
            try {
              String path = pqca.getProperty("path_to_analysis");
              File reportFileToParse = new File(path);
              if (reportFileToParse.exists()) {
                qcParser.parseReport(reportFileToParse, pqca);
              }
            }
            catch (QCAnalysisException e) {
              log.error("Cannot use metadata file - no property 'path_to_analysis' available. For each report line, this " +
                        "should point to the file path where the report file is located.");
              System.exit(1);
            }
          }
          qcas.addAll(pqcas);
        }
      }
      else if (line.hasOption("f")) {
        File inputfile = new File(line.getOptionValue("f"));
        if (!inputfile.exists()) {
          log.error("No input report file specified.");
          System.exit(1);
        }
        else {
          QCAnalysis qca = new DefaultQCAnalysis();

          if (line.hasOption("r")) {
            qca.addProperty("run", line.getOptionValue("r"));
          }
          else {
            log.warn("No run name specified. Parsed report metrics will only be queryable on raw read filename.");
          }
          qcParser.parseReport(inputfile, qca);
          qcas.add(qca);
        }
      }
      else {
        log.error("No input metadata or report file specified.");
        System.exit(1);
      }

      for (QCAnalysis qca : qcas) {
        if (line.hasOption("v")) {
          log.info("Parsed general values:");
          for (Map.Entry<String, String> p : qca.getGeneralValues().entrySet()) {
            log.info("\t\\_ " + p.getKey()+":"+p.getValue());
          }

          log.info("Parsed partition values:");
          for (PartitionValue p : qca.getPartitionValues()) {
            log.info("\t\\_ " + p.getKey()+":"+p.getValue()+":"+p.getPosition()+":"+p.getSize());
          }

          log.info("Parsed position values:");
          for (PositionValue p : qca.getPositionValues()) {
            log.info("\t\\_ " + p.getKey()+":"+p.getValue()+":"+p.getPosition());
          }
        }

        if (!line.hasOption("t")) {
          //write stuff to the database
          log.info("Writing analysis report to the database:");
          try {
            ApplicationContext context = new ClassPathXmlApplicationContext("db-config.xml");
            QCAnalysisStore store = (QCAnalysisStore)context.getBean("qcAnalysisStore");
            if (line.hasOption("v")) {
              store.setVerbose(true);
            }
            store.insertAnalysis(qca);
            log.info("SUCCESS");
          }
          catch (QCAnalysisException e) {
            log.error("FAIL: Cannot insert analysis into the database: " + e.getMessage());
            e.printStackTrace();
            System.exit(1);
          }
          catch (DataAccessException e) {
            log.error("FAIL: Error inserting analysis into the database: " + e.getMessage());
            e.printStackTrace();
            System.exit(1);
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
