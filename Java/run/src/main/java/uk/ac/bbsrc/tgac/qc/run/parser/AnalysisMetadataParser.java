package uk.ac.bbsrc.tgac.qc.run.parser;

import uk.ac.bbsrc.tgac.qc.analysis.DefaultQCAnalysis;
import uk.ac.bbsrc.tgac.qc.analysis.QCAnalysis;
import uk.ac.bbsrc.tgac.qc.exception.QCAnalysisException;

import java.io.*;
import java.util.ArrayList;
import java.util.List;

/**
 * uk.ac.bbsrc.tgac.qc.run.parser
 * <p/>
 * Parses the StatsDB analysis metadata file format and populates a QCAnalysis property map
 * <p/>
 * TYPE_OF_EXPERIMENT     PATH_TO_FASTQC  INSTRUMENT      CHMESTRY_VERSION        SOFTWARE_ON_INSTRUMENT_VERSION  CASAVA_VERION   RUN_FOLDER      SAMPLE_NAME     LANE
 *
 * @author Rob Davey
 * @date 03/07/13
 * @since 1.0-SNAPSHOT
 */
public class AnalysisMetadataParser {
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
