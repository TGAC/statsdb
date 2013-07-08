package uk.ac.bbsrc.tgac.qc.run.parser;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import uk.ac.bbsrc.tgac.qc.analysis.QCAnalysis;
import uk.ac.bbsrc.tgac.qc.exception.QCAnalysisException;
import uk.ac.bbsrc.tgac.qc.util.StatsDBUtils;

import java.io.*;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

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
  private Logger log = LoggerFactory.getLogger(getClass());

  private Map<String, String> values = new HashMap<>();
  private Map<String, String> valueKeys = new HashMap<>();
  private Map<String, String> headerKeys = new HashMap<>();
  private Map<String, String> lineFunctions = new HashMap<>();

  private static final String MODULE_START_REGEX = ">>(.*)";
  private static final String MODULE_END_REGEX = ">>END_MODULE";
  private static final String MODULE_NAME_REGEX = ">>(.*)[\\s]+([\\S]*)";

  private Pattern moduleStartPattern = Pattern.compile(MODULE_START_REGEX);
  private Pattern moduleEndPattern = Pattern.compile(MODULE_END_REGEX);
  private Pattern moduleNamePattern = Pattern.compile(MODULE_NAME_REGEX);

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

    lineFunctions.put("parseOverrepresentedSequences", "1");
    lineFunctions.put("parseOverrepresentedKmer", "1");
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
      while ((line = br.readLine()) != null) {
        Matcher m = moduleNamePattern.matcher(line);
        if (m.matches()) {
          String[] module = m.group(1).split("[\\s]+");
          String moduleName = "";
          for (String s : module) {
            moduleName += StatsDBUtils.capitalise(s);
          }
          log.info("Attempting to parse module: " + moduleName);
          Method parseMethod = this.getClass().getMethod("parse" + moduleName, FileInputStream.class, QCAnalysis.class);
          parseMethod.invoke(this, r, qcAnalysis);
        }
      }
    }
    catch (IOException e) {
      log.error("Error parsing run metadata headers: " + e.getMessage());
      e.printStackTrace();
    }
    catch (NoSuchMethodException e) {
      log.error("No such parser for module : " + e.getMessage());
      e.printStackTrace();
    }
    catch (InvocationTargetException e) {
      log.error("Cannot call parser module : " + e.getMessage());
      e.printStackTrace();
    }
    catch (IllegalAccessException e) {
      e.printStackTrace();
    }
    finally {
      if (br != null) {
        try {
          br.close();
        }
        catch (IOException e) {
          e.printStackTrace();
        }
      }
    }
  }

  private void parseBasicStatistics(FileInputStream r, QCAnalysis qcAnalysis) throws IOException {
    BufferedReader br = newReader(r);
    String line;
    try {
      while ((line = br.readLine()) != null) {
        //Matcher m = modulePattern.matcher(line);

      }
    }
    finally {
      closeReader(br);
    }
  }

  private void parsePerBaseSequenceQuality(FileInputStream r, QCAnalysis qcAnalysis) throws IOException, QCAnalysisException {
    parsePartition(r, qcAnalysis, "quality");
  }

  private void parsePerSequenceQualityScores(FileInputStream r, QCAnalysis qcAnalysis) throws IOException, QCAnalysisException {
    parsePosition(r, qcAnalysis, "quality_score");
  }

  private void parsePerBaseSequenceContent(FileInputStream r, QCAnalysis qcAnalysis) throws IOException, QCAnalysisException {
    parsePartition(r, qcAnalysis, "base_content");
  }

  private void parsePerBaseGCContent(FileInputStream r, QCAnalysis qcAnalysis) throws IOException, QCAnalysisException {
    parsePartition(r, qcAnalysis, "gc_content");
  }

  private void parsePerSequenceGCContent(FileInputStream r, QCAnalysis qcAnalysis) throws IOException, QCAnalysisException {
    parsePartition(r, qcAnalysis, "gc_content");
  }

  private void parsePerBaseNContent(FileInputStream r, QCAnalysis qcAnalysis) throws IOException, QCAnalysisException {
    parsePartition(r, qcAnalysis, "base_content");
  }

  private void parseSequenceLengthDistribution(FileInputStream r, QCAnalysis qcAnalysis) throws IOException, QCAnalysisException {
    parsePartition(r, qcAnalysis, "sequence_length");
  }

  private void parseSequenceDuplicationLevels(FileInputStream r, QCAnalysis qcAnalysis) throws IOException, QCAnalysisException {
    parsePosition(r, qcAnalysis, "duplication_level");
  }

  private void parseOverrepresentedSequences(FileInputStream r, QCAnalysis qcAnalysis) throws IOException, QCAnalysisException {
    String s = getModuleBlock(r);

    /*
      my $analysis = shift;
      my $to_parse = shift;
      my @line = split(/\t/, $to_parse);
      $values{$line[0]} = "overrepresented_sequence";
      $analysis->add_general_value($line[0], $line[1], $line[3]);
    */
  }

  private void parseKmerContent(FileInputStream r, QCAnalysis qcAnalysis) throws IOException, QCAnalysisException {
    String s = getModuleBlock(r);

    /*
      my $analysis = shift;
      my $to_parse = shift;
      my @line = split(/\t/, $to_parse);
      $values{$line[0]} = "overrepresented_kmer";
      $analysis->add_general_value($line[0], $line[1]);
    */
  }

  private void parsePartition(FileInputStream r, QCAnalysis qcAnalysis, String prefix) throws IOException, QCAnalysisException {
    parseModuleBlock(getModuleBlock(r), qcAnalysis, prefix, "addPartitionValue");
  }

  private void parsePosition(FileInputStream r, QCAnalysis qcAnalysis, String prefix) throws IOException, QCAnalysisException {
    parseModuleBlock(getModuleBlock(r), qcAnalysis, prefix, "addPositionValue");
  }

  private void parseModuleBlock(String module, QCAnalysis qcAnalysis, String prefix, String func) throws QCAnalysisException {
    String[] headers = null;
    for (String line : module.split("\\n")) {
      if (line.startsWith("#")) {
        //header row
        line = line.substring(1);
        String[] hs = line.split("\\s+");
        headers = new String[hs.length];
        if (hs.length == 2 && headerKeys.containsKey(hs[0])) {
          qcAnalysis.addGeneralValue(headerKeys.get(hs[0]), hs[1], "");
        }
        else {
          for (int i = 0; i < hs.length; i++) {
            String token = hs[i];
            token = token.replaceAll("\\s+", "_");
            if (headerKeys.containsKey(token)) {
              token = headerKeys.get(token);
            }
            headers[i] = prefix + "_" + token;
          }
        }
      }
      else {
        if (headers == null) {
          throw new QCAnalysisException("Something went wrong with header row parsing. Failing...");
        }

        if (lineFunctions.containsKey(func)) {
          try {
            Method qcam = this.getClass().getMethod(func, QCAnalysis.class, String.class);
            qcam.invoke(this, qcAnalysis, line);
          }
          catch (NoSuchMethodException e) {
            throw new QCAnalysisException("No such method '" + func + "' on " + this.getClass().getSimpleName(), e);
          }
          catch (InvocationTargetException e) {
            throw new QCAnalysisException("Cannot call '" + func + "' on " + this.getClass().getSimpleName(), e);
          }
          catch (IllegalAccessException e) {
            throw new QCAnalysisException("Not allowed to call '" + func + "' " + this.getClass().getSimpleName(), e);
          }
        }
        else {
          String[] ls = line.split("\\s+");
          for (int i = 1; i < ls.length; i++) {
            try {
              Method qcam = QCAnalysis.class.getMethod(func, String.class, String.class, String.class);
              qcam.invoke(qcAnalysis, ls[0], headers[i], ls[i]);
            }
            catch (NoSuchMethodException e) {
              throw new QCAnalysisException("No such method '" + func + "' on QCAnalysis.", e);
            }
            catch (InvocationTargetException e) {
              throw new QCAnalysisException("Cannot call '" + func + "' on QCAnalysis.", e);
            }
            catch (IllegalAccessException e) {
              throw new QCAnalysisException("Not allowed to call '" + func + "' on QCAnalysis.", e);
            }
          }
        }
      }
    }
  }

  private String getModuleBlock(FileInputStream r) throws IOException, QCAnalysisException {
    BufferedReader br = newReader(r);
    String line;
    StringBuilder moduleBlock = new StringBuilder();
    boolean first = true;
    try {
      while ((line = br.readLine()) != null) {
        if (first) {
          Matcher mS = moduleStartPattern.matcher(line);
          if (mS.matches()) {
            moduleBlock.append(line);
            first = false;
          }
          else {
            throw new QCAnalysisException("Module block to parse doesn't start with a suitable module start string");
          }
        }
        else {
          Matcher mE = moduleEndPattern.matcher(line);
          if (mE.matches()) {
            break;
          }
          else {
            moduleBlock.append(line);
          }
        }
      }
    }
    finally {
      closeReader(br);
    }

    return moduleBlock.toString();
  }

  private BufferedReader newReader(FileInputStream r) {
    try {
      //reset the position of the input stream
      //the following new buffered reader will need to read the QC report from the start
      r.getChannel().position(0);
      return new BufferedReader(new InputStreamReader(r));
    }
    catch (IOException e) {
      e.printStackTrace();
    }
    return null;
  }

  private void closeReader(BufferedReader br) {
    if (br != null) {
      try {
        br.close();
      }
      catch (IOException e) {
        e.printStackTrace();
      }
    }
  }
}