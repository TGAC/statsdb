package uk.ac.tgac.statsdb.run;

import org.codehaus.jackson.map.ObjectMapper;

import java.io.IOException;
import java.io.Serializable;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.LinkedList;
import java.util.List;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * Reference implementation for a simple table.
 * <p/>
 * User: ramirezr
 * Date: 07/03/2012
 * Time: 09:28
 */
public class GenericReportTable implements ReportTable {
  private List<List<String>> table;
  private boolean empty;

  public GenericReportTable(List<List<String>> table) {
    this.table = table;
    empty = table.size() <= 1;
  }

  public GenericReportTable(ResultSet rs) throws SQLException {
    empty = true;
    ResultSetMetaData rsmd = rs.getMetaData();
    int columnCount = rsmd.getColumnCount();
    List<String> header = new ArrayList<String>();

    for (int i = 1; i <= columnCount; i++) {
      header.add(i-1, rsmd.getColumnName(i));
    }

    table = new ArrayList<List<String>>();
    table.add(header);
    List<String> tmp;

    while (rs.next()) {
      empty = false;
      tmp = new ArrayList<String>();
      for (int i = 1; i <= columnCount; i++) {
        tmp.add(i-1,  rs.getObject(i).toString());
      }
      table.add(tmp);
    }

    try {
      rs.beforeFirst();
    }
    catch (SQLException sqle) {
      Logger.getLogger("Reports").log(Level.WARNING, "Unable to reset ResultSet pointer: " + sqle.getSQLState());
      sqle.printStackTrace();
    }
  }

  @Override
  public String toCSV() {
    return this.toCSV(',');
  }

  @Override
  public String toCSV(char separator) {
    StringBuilder buff = new StringBuilder();
    for (List<? extends Serializable> arr : table) {
      for (Serializable s : arr) {
        buff.append(s.toString());
        buff.append(separator);
      }
      buff.deleteCharAt(buff.length() - 1);
      buff.append('\n');
    }
    return buff.toString();
  }

  @Override
  public String toJSON() throws IOException {
    ObjectMapper mapper = new ObjectMapper();
    return mapper.writeValueAsString(table);
  }

  @Override
  public List<String> getHeaders() {
    List<? extends Serializable> headers = table.get(0);
    List<String> l = new LinkedList<String>();
    for (Serializable header : headers) {
      l.add(header.toString());
    }
    return l;
  }

  @Override
  public List<List<String>> getTable() {
    return new ArrayList<List<String>>(table);
  }

  @Override
  public boolean isEmpty() {
    return empty;
  }

  public void append(ReportTable rt) {
    List<List<String>> other = rt.getTable();
    boolean first = true;
    for (List<String> col : other) {
      if (!first) {
        table.add(col);
      }
      first = false;
    }
  }
}
