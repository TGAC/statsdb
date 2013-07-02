package uk.ac.bbsrc.tgac.qc.exception;

/**
 * uk.ac.bbsrc.tgac.qc.exception
 * <p/>
 * Info
 *
 * @author Rob Davey
 * @date 02/07/13
 * @since 1.0-SNAPSHOT
 */
public class QCAnalysisException extends Exception {
  public QCAnalysisException(String s) {
    super(s);
  }

  public QCAnalysisException(String s, Throwable cause) {
    super(s);
    if (cause != null) {
        initCause(cause);
    }
  }
}
