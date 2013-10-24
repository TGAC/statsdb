package uk.ac.tgac.statsdb.util;

import uk.ac.tgac.statsdb.exception.QCAnalysisException;

import java.util.AbstractMap;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Helper class containing any StatsDB general handy constants and functions
 *
 * @author Rob Davey
 * @date 04/07/13
 * @since 1.0-SNAPSHOT
 */
public class StatsDBUtils {
  /**
   * Regular expression representing a valid range string
   */
  private static final Pattern rangeSpan = Pattern.compile("([0-9]+)-([0-9]+)");

  /**
   * Regular expression representing a valid point number
   */
  private static final Pattern rangePoint = Pattern.compile("([0-9]+)");

  /**
   * Convert a string object representing a range of numbers separated by a hyphen into two numbers
   *
   * @param range
   * @return A pair (Map.Entry) representing the min and max bounds of a given range string, e.g. 32-142
   * results in min=32, max=142
   *
   * @throws uk.ac.tgac.statsdb.exception.QCAnalysisException when a null range is passed to this method, or when the input string is an invalid range string
   */
  public static Map.Entry<Long, Long> parseRange(String range) throws QCAnalysisException {
    if (range != null) {
      long min = 0L;
      long max = 0L;
      Matcher m = rangeSpan.matcher(range);
      if (m.matches()) {
        min = Long.parseLong(m.group(1));
        max = Long.parseLong(m.group(2));
      }
      else if (rangePoint.matcher(range).matches()) {
        min = max = Long.parseLong(range);
      }
      else {
        throw new QCAnalysisException("Invalid range string '"+range+"'. Needs to be of the form 'a-b'");
      }
      return new AbstractMap.SimpleImmutableEntry<>(min, max);
    }
    else {
      throw new QCAnalysisException("Null range supplied to range parse.");
    }
  }

  /**
   * Parses a given range string to produce the size of the difference between the min and max values
   *
   * @param range
   * @return A pair (Map.Entry) representing the min value and the size of the range
   * @throws QCAnalysisException
   */
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

  /**
   * Capitalise the first letter of a string
   *
   * @param s
   * @return the capitalised string
   */
  public static String capitalise(String s) {
    return Character.toUpperCase(s.charAt(0)) + s.substring(1);
  }
}
