package uk.ac.tgac.statsdb.exception;

/**
 * Info
 *
 * @author Rob Davey
 * @date 25/10/13
 * @since 1.1
 */
public class ConsumerException extends Exception {
  public ConsumerException(String s) {
    super(s);
  }

  public ConsumerException(String s, Throwable cause) {
    super(s);
    if (cause != null) {
        initCause(cause);
    }
  }
}
