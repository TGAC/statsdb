package uk.ac.bbsrc.tgac.qc.analysis;

import uk.ac.bbsrc.tgac.qc.exception.QCAnalysisException;

/**
 * uk.ac.bbsrc.tgac.qc.analysis
 * <p/>
 * Info
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
    if (key == null || "".equals(key)) { throw new QCAnalysisException("A partition value cannot have a null or empty key"); }
    this.key = key;
    if (value == null || "".equals(value)) { throw new QCAnalysisException("A parition value cannot have a null or empty value"); }
    this.value = value;
  }

  public long getPosition() {
    return this.position;
  }

  public String getKey() {
    return this.key;
  }

  public String getValue() {
    return this.value;
  }
}
