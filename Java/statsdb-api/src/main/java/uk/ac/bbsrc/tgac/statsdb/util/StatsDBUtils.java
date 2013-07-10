package uk.ac.bbsrc.tgac.statsdb.util;

/**
 * uk.ac.bbsrc.tgac.qc.util
 * <p/>
 * Info
 *
 * @author Rob Davey
 * @date 04/07/13
 * @since 1.0-SNAPSHOT
 */
public class StatsDBUtils {
  public static String capitalise(String s) {
    return Character.toUpperCase(s.charAt(0)) + s.substring(1);
  }
}
