package uk.ac.bbsrc.tgac.statsdb.analysis;

import uk.ac.bbsrc.tgac.statsdb.exception.QCAnalysisException;

import java.util.List;
import java.util.Map;

/**
 * uk.ac.bbsrc.tgac.qc.analysis
 * <p/>
 * Info
 *
 * @author Rob Davey
 * @date 02/07/13
 * @since 1.0-SNAPSHOT
 */
public interface QCAnalysis {
  public long getId();
  public void setId(long id);
  public String getProperty(String key) throws QCAnalysisException;
  public void addProperty(String key, String value) throws QCAnalysisException;
  public void addPartitionValue(String range, String key, String value) throws QCAnalysisException;
  public void addPositionValue(String position, String key, String value) throws QCAnalysisException;
  public void addGeneralValue(String valueType, String valueScope, String descriptor) throws QCAnalysisException;
  public void addValueType(String valueTypeKey, String valueScope) throws QCAnalysisException;
  public Map<String, String> getProperties();
  public Map<String,String> getGeneralValues();
  public List<PartitionValue> getPartitionValues();
  public List<PositionValue> getPositionValues();
  public Map<String, String> getValueDescriptions();
  public Map<String, String> getValueScopes();
}
