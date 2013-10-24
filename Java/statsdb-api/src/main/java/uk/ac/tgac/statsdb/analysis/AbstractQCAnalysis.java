package uk.ac.tgac.statsdb.analysis;

import uk.ac.tgac.statsdb.exception.QCAnalysisException;
import uk.ac.tgac.statsdb.util.StatsDBUtils;

import java.util.AbstractMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Skeleton implementation of a QCAnalysis object. Contains default methods for storing and retrieving QC report
 * metrics.
 *
 * @author Rob Davey
 * @date 02/07/13
 * @since 1.0-SNAPSHOT
 */
public abstract class AbstractQCAnalysis implements QCAnalysis {
  private long id = 0L;

  public Map<String,String> properties;
  public Map<String,String> valueTypes;
  public Map<String,String> valueDescriptions;
  public Map<String,String> generalValues;
  public List<PartitionValue> partitionValues;
  public List<PositionValue> positionValues;

  @Override
  public void setId(long id) {
    this.id = id;
  }

  @Override
  public long getId() {
    return this.id;
  }

  @Override
  public String getProperty(String key) throws QCAnalysisException {
    if (properties.containsKey(key)) {
      return properties.get(key);
    }
    else {
      throw new QCAnalysisException("No such property on analysis: " + getId());
    }
  }

  @Override
  public void addProperty(String key, String value) throws QCAnalysisException {
    properties.put(key, value);
  }

  @Override
  public void addPartitionValue(String range, String key, String value) throws QCAnalysisException {
    Map.Entry<String, String> positionAndSize = StatsDBUtils.rangeToSize(range);
    PartitionValue pv = new PartitionValue(Long.parseLong(positionAndSize.getKey()), Long.parseLong(positionAndSize.getValue()), key, value);
    partitionValues.add(pv);
  }

  @Override
  public void addPositionValue(String position, String key, String value) throws QCAnalysisException {
    if (position != null && position.matches("[\\d\\+]+")) {
      PositionValue pv = new PositionValue(Long.parseLong(position.replaceAll("\\+", "")), key, value);
      positionValues.add(pv);
    }
    else {
      throw new QCAnalysisException("Invalid numerical position '"+position+"' for " + key + " : " + value);
    }
  }

  @Override
  public void addGeneralValue(String valueTypeKey, String valueScope, String description) throws QCAnalysisException {
    generalValues.put(valueTypeKey, valueScope);
    if (description != null && !"".equals(description)) {
      addValueDescription(valueTypeKey, description);
    }
  }

  @Override
  public void addValueType(String valueTypeKey, String valueScope) throws QCAnalysisException {
    valueTypes.put(valueTypeKey, valueScope);
  }

  @Override
  public void addValueDescription(String valueTypeKey, String description) throws QCAnalysisException {
    valueDescriptions.put(valueTypeKey, description);
  }

  @Override
  public Map<String,String> getProperties() {
    return properties;
  }

  @Override
  public Map<String,String> getGeneralValues() {
    return generalValues;
  }

  @Override
  public List<PartitionValue> getPartitionValues() {
    return this.partitionValues;
  }

  @Override
  public List<PositionValue> getPositionValues() {
    return this.positionValues;
  }

  @Override
  public Map<String, String> getValueScopes() {
    return valueTypes;
  }

  @Override
  public Map<String, String> getValueDescriptions() {
    return valueDescriptions;
  }
}