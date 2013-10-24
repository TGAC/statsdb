package uk.ac.tgac.statsdb.util;

/**
 * Interface that describes an object that knows about a verbose toggle
 *
 * @author Rob Davey
 * @date 07/08/13
 * @since 1.1-SNAPSHOT
 */
public interface VerbosityAware {
  /**
   * Sets an object's logging output to be verbose (true) or not (false)
   *
   * @param verbose
   */
  void setVerbose(boolean verbose);
}
