package uk.ac.tgac.statsdb.run.parser;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import uk.ac.tgac.statsdb.analysis.AbstractQCAnalysis;
import uk.ac.tgac.statsdb.analysis.QCAnalysis;
import uk.ac.tgac.statsdb.exception.QCAnalysisException;
import uk.ac.tgac.statsdb.util.StatsDBUtils;

import java.io.*;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * uk.ac.tgac.qc.run.parser
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

    headerKeys.put("%gc", "percentage");
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
    StringBuilder sb = new StringBuilder();
    BufferedReader br = null;
    try {
      br = new BufferedReader(new InputStreamReader(r));
      String line;
      while ((line = br.readLine()) != null) {
        if (line.startsWith("##")) {
          qcAnalysis.addProperty("FastQC", line.split("\\s+")[1]);
        }
        else {
          sb.append(line).append("\n");
        }
      }
      String report = sb.toString();

      for (String module : report.split(MODULE_END_REGEX)) {
        for (String modline : module.split("\\n")) {
          Matcher m = moduleNamePattern.matcher(modline);
          if (m.matches()) {
            String[] moduleInfo = m.group(1).split("\\s+");
            String moduleName = "";
            for (String s : moduleInfo) {
              moduleName += StatsDBUtils.capitalise(s);
            }
            log.info("Attempting to parse module: " + moduleName);
            Method parseMethod = this.getClass().getDeclaredMethod("parse" + moduleName, String.class, QCAnalysis.class);
            parseMethod.setAccessible(true);
            log.debug("Calling " + parseMethod.toString() + " on: \n" + module);
            parseMethod.invoke(this, module, qcAnalysis);
          }
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

  private void parseBasicStatistics(String module, QCAnalysis qcAnalysis) throws IOException, QCAnalysisException {
    for (String line : module.split("\\n")) {
      if (!line.startsWith("#") && !line.startsWith(">>")) {
        String[] tokens = line.split("\\t");
        if (tokens.length == 2) {
          log.debug(tokens[0].trim() + " : " + tokens[1].trim());
          if("Sequence length".equals(tokens[0])) {
            Map.Entry<Long, Long> range = AbstractQCAnalysis.parseRange(tokens[1]);
            qcAnalysis.addGeneralValue("general_min_length", String.valueOf(range.getKey()), null);
            qcAnalysis.addGeneralValue("general_max_length", String.valueOf(range.getValue()), null);
          }
          else if (valueKeys.containsKey(tokens[0])) {
            qcAnalysis.addGeneralValue(valueKeys.get(tokens[0]), tokens[1], null);
          }
          else {
            qcAnalysis.addProperty(tokens[0], tokens[1]);
          }
        }
      }
    }
    log.info("OK");
  }

  private void parseBasicStatistics(FileInputStream r, QCAnalysis qcAnalysis) throws IOException, QCAnalysisException {
    log.info(""+r.getChannel().position());
    String module = getModuleBlock(r);
    parseBasicStatistics(module, qcAnalysis);
  }

  private void parsePerBaseSequenceQuality(String module, QCAnalysis qcAnalysis) throws IOException, QCAnalysisException {
    parsePartition(module, qcAnalysis, "quality");
  }

  private void parsePerBaseSequenceQuality(FileInputStream r, QCAnalysis qcAnalysis) throws IOException, QCAnalysisException {
    parsePartition(r, qcAnalysis, "quality");
  }

  private void parsePerSequenceQualityScores(String module, QCAnalysis qcAnalysis) throws IOException, QCAnalysisException {
    parsePosition(module, qcAnalysis, "quality_score");
  }

  private void parsePerSequenceQualityScores(FileInputStream r, QCAnalysis qcAnalysis) throws IOException, QCAnalysisException {
    parsePosition(r, qcAnalysis, "quality_score");
  }

  private void parsePerBaseSequenceContent(String module, QCAnalysis qcAnalysis) throws IOException, QCAnalysisException {
    parsePartition(module, qcAnalysis, "base_content");
  }

  private void parsePerBaseSequenceContent(FileInputStream r, QCAnalysis qcAnalysis) throws IOException, QCAnalysisException {
    parsePartition(r, qcAnalysis, "base_content");
  }

  private void parsePerBaseGCContent(String module, QCAnalysis qcAnalysis) throws IOException, QCAnalysisException {
    parsePartition(module, qcAnalysis, "gc_content");
  }

  private void parsePerBaseGCContent(FileInputStream r, QCAnalysis qcAnalysis) throws IOException, QCAnalysisException {
    parsePartition(r, qcAnalysis, "gc_content");
  }

  private void parsePerSequenceGCContent(String module, QCAnalysis qcAnalysis) throws IOException, QCAnalysisException {
    parsePartition(module, qcAnalysis, "gc_content");
  }

  private void parsePerSequenceGCContent(FileInputStream r, QCAnalysis qcAnalysis) throws IOException, QCAnalysisException {
    parsePartition(r, qcAnalysis, "gc_content");
  }

  private void parsePerBaseNContent(String module, QCAnalysis qcAnalysis) throws IOException, QCAnalysisException {
    parsePartition(module, qcAnalysis, "base_content");
  }

  private void parsePerBaseNContent(FileInputStream r, QCAnalysis qcAnalysis) throws IOException, QCAnalysisException {
    parsePartition(r, qcAnalysis, "base_content");
  }

  private void parseSequenceLengthDistribution(String module, QCAnalysis qcAnalysis) throws IOException, QCAnalysisException {
    parsePartition(module, qcAnalysis, "sequence_length");
  }

  private void parseSequenceLengthDistribution(FileInputStream r, QCAnalysis qcAnalysis) throws IOException, QCAnalysisException {
    parsePartition(r, qcAnalysis, "sequence_length");
  }

  private void parseSequenceDuplicationLevels(String module, QCAnalysis qcAnalysis) throws IOException, QCAnalysisException {
    parsePosition(module, qcAnalysis, "duplication_level");
  }

  private void parseSequenceDuplicationLevels(FileInputStream r, QCAnalysis qcAnalysis) throws IOException, QCAnalysisException {
    parsePosition(r, qcAnalysis, "duplication_level");
  }

  private void parseOverrepresentedSequences(String module, QCAnalysis qcAnalysis) throws IOException, QCAnalysisException {
    for (String line : module.split("\\n")) {
      if (!line.startsWith("#") && !line.startsWith(">>") && !"".equals(line)) {
        String[] tokens = line.split("\\t+");
        if (tokens.length >= 4) {
          values.put(tokens[0], "overrepresented_sequence");
          qcAnalysis.addValueType(tokens[0], "overrepresented_sequence");
          qcAnalysis.addGeneralValue(tokens[0], tokens[1], tokens[3]);
        }
        else {
          throw new QCAnalysisException("Malformed overrepresented sequence line");
        }
      }
    }
    log.info("OK");
  }

  private void parseOverrepresentedSequences(FileInputStream r, QCAnalysis qcAnalysis) throws IOException, QCAnalysisException {
    log.info(""+r.getChannel().position());
    String module = getModuleBlock(r);
    parseOverrepresentedSequences(module, qcAnalysis);
  }

  private void parseKmerContent(String module, QCAnalysis qcAnalysis) throws IOException, QCAnalysisException {
    for (String line : module.split("\\n")) {
      if (!line.startsWith("#") && !line.startsWith(">>") && !"".equals(line)) {
        String[] tokens = line.split("\\t+");
        if (tokens.length >= 2) {
          values.put(tokens[0], "overrepresented_kmer");
          qcAnalysis.addValueType(tokens[0], "overrepresented_kmer");
          qcAnalysis.addGeneralValue(tokens[0], tokens[1], null);
        }
        else {
          throw new QCAnalysisException("Malformed overrepresented kmer line");
        }
      }
    }
    log.info("OK");
  }

  private void parseKmerContent(FileInputStream r, QCAnalysis qcAnalysis) throws IOException, QCAnalysisException {
    log.info(""+r.getChannel().position());
    String module = getModuleBlock(r);
    parseKmerContent(module, qcAnalysis);
  }

  private void parsePartition(String module, QCAnalysis qcAnalysis, String prefix) throws IOException, QCAnalysisException {
    parseModuleBlock(module, qcAnalysis, prefix, "addPartitionValue");
    log.info("OK");
  }

  private void parsePartition(FileInputStream r, QCAnalysis qcAnalysis, String prefix) throws IOException, QCAnalysisException {
    parseModuleBlock(getModuleBlock(r), qcAnalysis, prefix, "addPartitionValue");
    log.info("OK");
  }

  private void parsePosition(String module, QCAnalysis qcAnalysis, String prefix) throws IOException, QCAnalysisException {
    parseModuleBlock(module, qcAnalysis, prefix, "addPositionValue");
    log.info("OK");
  }

  private void parsePosition(FileInputStream r, QCAnalysis qcAnalysis, String prefix) throws IOException, QCAnalysisException {
    parseModuleBlock(getModuleBlock(r), qcAnalysis, prefix, "addPositionValue");
    log.info("OK");
  }

  private void parseModuleBlock(String module, QCAnalysis qcAnalysis, String prefix, String func) throws QCAnalysisException {
    String[] headers = null;
    String[] lines = module.split("\\n");
    for (String line : lines) {
      if (line.startsWith("#")) {
        line = line.substring(1).toLowerCase();
        String[] hs = line.split("\\t+");
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
    }

    if (headers == null) {
      throw new QCAnalysisException("Something went wrong with header row parsing. Failing...");
    }

    for (String line : lines) {
      if (!line.startsWith(">>") && !line.startsWith("#")) {
        if (lineFunctions.containsKey(func)) {
          try {
            Method qcam = this.getClass().getDeclaredMethod(func, QCAnalysis.class, String.class);
            qcam.setAccessible(true);
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
          String[] ls = line.split("\\t+");
          for (int i = 1; i < ls.length; i++) {
            try {
              Method qcam = QCAnalysis.class.getDeclaredMethod(func, String.class, String.class, String.class);
              qcam.setAccessible(true);
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
            throw new QCAnalysisException("Module block to parse doesn't start with a suitable module start string: '" + line + "'");
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