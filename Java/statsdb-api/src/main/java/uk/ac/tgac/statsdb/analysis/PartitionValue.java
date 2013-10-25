package uk.ac.tgac.statsdb.analysis;

import uk.ac.tgac.statsdb.exception.QCAnalysisException;

/**
 * A value class that represents a partionable number, i.e. a range, alongside a given key:value description of that metric
 *
 * @author Rob Davey
 * @date 02/07/13
 * @since 1.0_SNAPSHOT
 */
public class PartitionValue {
  private long position;
  private long size;
  private String key;
  private String value;

  public PartitionValue(long position, long size, String key, String value) throws QCAnalysisException {
    this.position = position;
    this.size = size;
    if (key == null || "".equals(key)) { throw new QCAnalysisException("A partition value cannot have a null or empty key"); }
    this.key = key;
    if (value == null || "".equals(value)) { throw new QCAnalysisException("A partition value cannot have a null or empty value"); }
    this.value = value;
  }

  /**
   * Get the partition range start position value
   *
   * @return the range position
   */
  public long getPosition() {
    return this.position;
  }

  /**
   * Get the size of the partition range
   *
   * @return the range size
   */
  public long getSize() {
    return this.size;
  }

  /**
   * Get the value description key
   *
   * @return description key string
   */
  public String getKey() {
    return this.key;
  }

  /**
   * Get the value description value
   *
   * @return description value string
   */
  public String getValue() {
    return this.value;
  }
}
