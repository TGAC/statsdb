package uk.ac.tgac.statsdb.run;

import java.io.IOException;
import java.util.List;

/**
 * Interface to describe simple tables. The contract is that the
 * first element in the table is a header and the rest of the
 * elements are tuples of it. That is propagated on the
 * different views for it.
 * <p/>
 * Created by IntelliJ IDEA.
 * User: ramirezr
 * Date: 07/03/2012
 * Time: 09:29
 * To change this template use File | Settings | File Templates.
 */
public interface ReportTable {
  /**
   * Returns a String in Coma Separated Values
   *
   * @return returns the table in CSV format
   */
  String toCSV();

  /**
   * Returns a String containing the table using
   * as separator the given argument
   *
   * @param separator character to separate the fields
   * @return The table represented by the separator
   */
  String toCSV(char separator);

  /**
   * Returns a simple JSON representation of the ReportTable
   *
   * @return a string containing the json representation of the table
   * @throws IOException if something goes wrong creating the json
   */
  String toJSON() throws IOException;

  /**
   * Method to get just the headers from the ReportTable
   *
   * @return a list of headers in the order used in the table
   */
  List<String> getHeaders();

  /**
   * Method to get a copy of the internal structure.
   * The first element is an array with the header
   * The rest of the elements in the list are the
   *
   * @return a list with the tuples.
   */
  List<List<String>> getTable();

  /**
   * Method to check if the ReportTable has results
   *
   * @return true if the ReprtTable is empty, false otherwise.
   */
  boolean isEmpty();
}
