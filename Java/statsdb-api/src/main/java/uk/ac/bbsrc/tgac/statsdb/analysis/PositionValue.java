package uk.ac.bbsrc.tgac.statsdb.analysis;

import uk.ac.bbsrc.tgac.statsdb.exception.QCAnalysisException;

/**
 * A value class that represents a position number, i.e. a single number, alongside a given key:value description of that metric
 *
 * @author Rob Davey
 * @date 02/07/13
 * @since 1.0_SNAPSHOT
 */
public class PositionValue {
  private long position;
  private String key;
  private String value;

  public PositionValue(long position, String key, String value) throws QCAnalysisException {
    this.position = position;
    if (key == null || "".equals(key)) { throw new QCAnalysisException("A position value cannot have a null or empty key"); }
    this.key = key;
    if (value == null || "".equals(value)) { throw new QCAnalysisException("A position value cannot have a null or empty value"); }
    this.value = value;
  }

  /**
   * Get the position
   *
   * @return the position
   */
  public long getPosition() {
    return this.position;
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
