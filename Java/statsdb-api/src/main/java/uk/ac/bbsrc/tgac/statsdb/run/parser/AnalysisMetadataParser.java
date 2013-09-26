package uk.ac.bbsrc.tgac.statsdb.run.parser;

import uk.ac.bbsrc.tgac.statsdb.analysis.DefaultQCAnalysis;
import uk.ac.bbsrc.tgac.statsdb.analysis.QCAnalysis;
import uk.ac.bbsrc.tgac.statsdb.exception.QCAnalysisException;

import java.io.*;
import java.util.ArrayList;
import java.util.List;

/**
 * Parses the StatsDB analysis metadata file format and populates a QCAnalysis property map
 *
 * @author Rob Davey
 * @date 03/07/13
 * @since 1.0-SNAPSHOT
 */
public class AnalysisMetadataParser {
  /**
   * Parse a StatsDB analysis metadata file, create relevant QCAnalysis objects and populate the relevant properties
   * in said QCAnalysis objects
   *
   * @param file to parse as a Java File object
   * @return a List of QCAnalysis objects created from the metadata file
   * @throws QCAnalysisException
   */
  public List<QCAnalysis> parseMetadataFile(File file) throws QCAnalysisException {
    List<QCAnalysis> qcas = new ArrayList<>();
    try {
      Reader r = new FileReader(file);
      processMetadataFile(r, qcas);
    }
    catch (FileNotFoundException e) {
      throw new QCAnalysisException("Cannot open metadata file for reading: " + file.getAbsolutePath(), e);
    }
    return qcas;
  }

  /**
   * Parse a StatsDB analysis metadata file, create relevant QCAnalysis objects and populate the relevant properties
   * in said QCAnalysis objects
   *
   * @param csv to parse as a CSV text file string
   * @return a List of QCAnalysis objects created from the metadata file
   * @throws QCAnalysisException
   */
  public List<QCAnalysis> parseMetadataFile(String csv) throws QCAnalysisException {
    List<QCAnalysis> qcas = new ArrayList<>();
    Reader r = new StringReader(csv);
    processMetadataFile(r, qcas);
    return qcas;
  }

  private void processMetadataFile(Reader r, List<QCAnalysis> qcas) throws QCAnalysisException {
    BufferedReader br = null;
    try {
      br = new BufferedReader(r);
      String line;
      boolean first = true;
      String[] headers = null;
      while ((line = br.readLine()) != null) {
        if (first) {
          headers = line.toLowerCase().split("[\\s|,]+");
          first = false;
        }
        else {
          String[] values = line.split("[\\s|,]+");
          if (headers == null || headers.length != values.length) {
            throw new QCAnalysisException("Invalid headers found");
          }
          QCAnalysis qa = new DefaultQCAnalysis();
          for (int i = 0; i < headers.length; i++) {
            qa.addProperty(headers[i], values[i]);
          }
          qcas.add(qa);
        }
      }
    }
    catch (IOException e) {
      System.err.println("Error parsing run metadata headers: " + e.getMessage());
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
}
