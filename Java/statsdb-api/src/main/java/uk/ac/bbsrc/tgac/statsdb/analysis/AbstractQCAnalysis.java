package uk.ac.bbsrc.tgac.statsdb.analysis;

import uk.ac.bbsrc.tgac.statsdb.exception.QCAnalysisException;

import java.util.AbstractMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Pattern;

/**
 * uk.ac.bbsrc.tgac.qc.analysis
 * <p/>
 * Info
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

  private static final Pattern rangeSpan = Pattern.compile("([0-9]+)-([0-9]+)");
  private static final Pattern rangePoint = Pattern.compile("([0-9]+)");

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
    Map.Entry<String, String> positionAndSize = rangeToSize(range);
    PartitionValue pv = new PartitionValue(Long.parseLong(positionAndSize.getKey()), Long.parseLong(positionAndSize.getValue()), key, value);
    partitionValues.add(pv);
  }

  @Override
  public void addPositionValue(String position, String key, String value) throws QCAnalysisException {
    if (position != null && position.matches("[\\d+]")) {
      PositionValue pv = new PositionValue(Long.parseLong(position), key, value);
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

  public void addValueDescription(String valueTypeKey, String description) throws QCAnalysisException {
    valueDescriptions.put(valueTypeKey, description);
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

  public static Map.Entry<Long, Long> parseRange(String range) throws QCAnalysisException {
    if (range != null) {
      long min = 0L;
      long max = 0L;
      if (rangeSpan.matcher(range).matches()) {
        min = Long.parseLong(rangeSpan.matcher(range).group(1));
        max = Long.parseLong(rangeSpan.matcher(range).group(2));
      }
      else if (rangePoint.matcher(range).matches()) {
        min = max = Long.parseLong(range);
      }
      return new AbstractMap.SimpleImmutableEntry<>(min, max);
    }
    else {
      throw new QCAnalysisException("Null range supplied to range parse.");
    }
  }

  public static Map.Entry<String, String> rangeToSize(String range) throws QCAnalysisException {
    Map.Entry<Long, Long> kv = parseRange(range);
    long from = kv.getKey();
    long to = kv.getValue();
    long length = Math.abs(to - from);

    if (to < from) {
      from = to;
    }

    return new AbstractMap.SimpleImmutableEntry<>(String.valueOf(from), String.valueOf(length+1));
  }
}