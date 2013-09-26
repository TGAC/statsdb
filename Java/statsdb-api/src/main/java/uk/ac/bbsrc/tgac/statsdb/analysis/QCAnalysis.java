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
  /**
   * Get the QCAnalysis ID
   * @return the QCAnalysis object ID
   */
  public long getId();

  /**
   * Sets the ID of this QCAnalysis object
   * @param id
   */
  public void setId(long id);

  /**
   * Retrieve an analysis property value associated with a given key
   *
   * @param key
   * @return
   * @throws QCAnalysisException
   */
  public String getProperty(String key) throws QCAnalysisException;

  /**
   * Add an analysis property
   *
   * @param key
   * @param value
   * @throws QCAnalysisException
   */
  public void addProperty(String key, String value) throws QCAnalysisException;

  /**
   * Add a partition value
   *
   * @param range
   * @param key
   * @param value
   * @throws QCAnalysisException
   */
  public void addPartitionValue(String range, String key, String value) throws QCAnalysisException;

  /**
   * Add a position value
   *
   * @param position
   * @param key
   * @param value
   * @throws QCAnalysisException
   */
  public void addPositionValue(String position, String key, String value) throws QCAnalysisException;

  /**
   * Add a general value
   *
   * @param valueType
   * @param valueScope
   * @param descriptor
   * @throws QCAnalysisException
   */
  public void addGeneralValue(String valueType, String valueScope, String descriptor) throws QCAnalysisException;

  /**
   * Add a value type scope
   *
   * @param valueTypeKey
   * @param valueScope
   * @throws QCAnalysisException
   */
  public void addValueType(String valueTypeKey, String valueScope) throws QCAnalysisException;

  /**
   * Add a value type description
   *
   * @param valueTypeKey
   * @param valueDescription
   * @throws QCAnalysisException
   */
  public void addValueDescription(String valueTypeKey, String valueDescription) throws QCAnalysisException;

  /**
   * Retrieve all analysis properties
   *
   * @return a map of key:value pairs
   */
  public Map<String, String> getProperties();

  /**
   * Retrieve all analysis general values
   *
   * @return a map of key:value pairs
   */
  public Map<String,String> getGeneralValues();

  /**
   * Retrieve all analysis partition values
   *
   * @return a list of PartitionValues
   */
  public List<PartitionValue> getPartitionValues();

  /**
   * Retrieve all analysis position values
   *
   * @return a list of PositionValues
   */
  public List<PositionValue> getPositionValues();

  /**
   * Retrieve all analysis value descriptions
   *
   * @return a map of key:value pairs
   */
  public Map<String, String> getValueDescriptions();

  /**
   * Retrieve all analysis value type scopes
   *
   * @return a map of key:value pairs
   */
  public Map<String, String> getValueScopes();
}
