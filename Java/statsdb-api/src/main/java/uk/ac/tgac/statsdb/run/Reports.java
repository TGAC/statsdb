package uk.ac.tgac.statsdb.run;

import org.springframework.jdbc.core.JdbcTemplate;

import javax.sql.DataSource;
import java.sql.*;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

public class Reports {
  private Connection connection;
  private DataSource dataSource = null;
  private JdbcTemplate template = null;
  private boolean suppressClose = false;

  /**
   * Create a Reports object with a Spring JdbcTemplate.
   *
   * @param template
   */
  public Reports(JdbcTemplate template) {
    this.template = template;
  }

  /**
   * Create a Reports object with a connection. For development outside a container.
   * Use the DataSource constructor to use a managed DataSource
   *
   * @param c
   */
  public Reports(Connection c) {
    this.connection = c;
  }

  /**
   * Creates a Reports object. When used this constructor, each query pulls and free
   * a connection from the datasource.
   *
   * @param ds
   */
  public Reports(DataSource ds) {
    dataSource = ds;
  }

  /**
   * Returns a connection to be used in a query
   *
   * @return
   * @throws SQLException
   */
  private Connection getConnection() throws SQLException {
    if (template != null) {
      return template.getDataSource().getConnection();
    }
    else if (dataSource != null) {
      return dataSource.getConnection();
    }
    return connection;
  }

  public boolean isSuppressClose() {
    return suppressClose;
  }

  public void setSuppressClose(boolean suppressClose) {
    this.suppressClose = suppressClose;
  }

  /**
   * Method that returns a summary table given an analysis done in partitions (per base, per percentile, etc..(
   *
   * @param analysis                The analysis to query.
   * @param analysis_property       Property to query
   * @param analysis_property_value expected value to group
   * @return
   * @throws SQLException
   */
  public ReportTable getPerPositionSummary(String analysis, String analysis_property, String analysis_property_value) throws SQLException {
    ReportTable rt = null;
    Connection con = null;
    try {
      con = getConnection();
      CallableStatement proc = con.prepareCall("{ call summary_per_position(? , ?, ?) }");
      proc.setString(1, analysis);
      proc.setString(2, analysis_property);
      proc.setString(3, analysis_property_value);

      boolean hadResults = proc.execute();
      if (hadResults) {
        rt = new GenericReportTable(proc.getResultSet());
      }
    }
    finally {
      if (!isSuppressClose()) {
        close(con);
      }
    }
    return rt;
  }

  /**
   * List all the analyses that are available per base.
   *
   * @return
   * @throws SQLException
   */
  public List<String> listPerBaseSummaryAnalyses() throws SQLException {
    List<String> list = null;
    Connection con = null;
    try {
      con = getConnection();
      CallableStatement proc = con.prepareCall("{ call list_summary_per_scope(?) }");
      proc.setString(1, "base_partition");

      boolean hadResults = proc.execute();
      if (hadResults) {
        list = resultSetToList(proc.getResultSet());
      }
    }
    finally {
      if (!isSuppressClose()) {
        close(con);
      }
    }
    return list;
  }

  /**
   * List all the analysis that are global to a run. This may also be summaries.
   *
   * @return
   * @throws SQLException
   */
  public List<String> listGlobalAnalyses() throws SQLException {
    List<String> list = null;
    Connection con = null;
    try {
      con = getConnection();
      CallableStatement proc = con.prepareCall("{ call list_summary_per_scope(?) }");
      proc.setString(1, "analysis");

      boolean hadResults = proc.execute();
      if (hadResults) {
        list = resultSetToList(proc.getResultSet());
      }
    }
    finally {
      if (!isSuppressClose()) {
        close(con);
      }
    }
    return list;
  }

  /**
   * Gets a single average value given the selection criteria.
   *
   * @param analysis
   * @param analysis_property
   * @param analysis_property_value
   * @return
   * @throws SQLException
   */
  public double getAverageValue(String analysis, String analysis_property, String analysis_property_value) throws SQLException {
    double average = 0;
    Connection con = null;
    try {
      con = getConnection();
      CallableStatement proc = con.prepareCall("{ call general_summary( ?, ?, ?)}");
      proc.setString(1, analysis);
      proc.setString(2, analysis_property);
      proc.setString(3, analysis_property_value);

      boolean hadResults = proc.execute();
      if (hadResults) {
        ResultSet rs = proc.getResultSet();
        if (rs.next()) {
          average = rs.getDouble(1);
        }
      }
    }
    finally {
      if (!isSuppressClose()) {
        close(con);
      }
    }
    return average;
  }

  /**
   * Gets all the summary values from the
   *
   * @param analysis_property
   * @param analysis_property_value
   * @return
   * @throws SQLException
   */

  public ReportTable getAverageValues(String analysis_property, String analysis_property_value) throws SQLException {
    ReportTable rt = null;
    Connection con = null;
    try {
      con = getConnection();
      CallableStatement proc = con.prepareCall("{ call general_summaries(?, ?) }");
      proc.setString(1, analysis_property);
      proc.setString(2, analysis_property_value);

      boolean hadResults = proc.execute();
      if (hadResults) {
        rt = new GenericReportTable(proc.getResultSet());
      }
    }
    finally {
      if (!isSuppressClose()) {
        close(con);
      }
    }
    return rt;
  }

  /**
   * Returns the average values for the run properties.  If a property is missing, the query
   * aggregates
   * The RunProperty.barcode has to be in base space.
   * <p/>
   * At the moment, only RunProperty.instrument, RunProperty.run, RunProperty.lane, RunProperty.pair and RunProperty.barcode are supported
   *
   * @param runProperties a Map with the properties to select.
   * @return
   * @throws SQLException
   */
  public ReportTable getAverageValues(Map<RunProperty, String> runProperties) throws SQLException {
    String[] args = new String[5];
    args[0] = runProperties.get(RunProperty.instrument);
    args[1] = runProperties.get(RunProperty.run);
    args[2] = runProperties.get(RunProperty.lane);
    args[3] = runProperties.get(RunProperty.pair);
    args[4] = runProperties.get(RunProperty.barcode);

    ReportTable rt = null;
    Connection con = null;
    try {
      con = getConnection();
      CallableStatement proc = con.prepareCall("{ call general_summaries_for_run(?,?,?,?,?) }");

      for (int i = 0; i < args.length; i++) {
        if (args[i] == null) {
          proc.setNull(i + 1, java.sql.Types.VARCHAR);
        }
        else {
          proc.setString(i + 1, args[i]);
        }
      }

      boolean hadResults = proc.execute();
      if (hadResults) {
        rt = new GenericReportTable(proc.getResultSet());
      }
    }
    finally {
      if (!isSuppressClose()) {
        close(con);
      }
    }
    return rt;
  }

  public ReportTable getPerPositionValues(String analysis, Map<RunProperty, String> runProperties) throws SQLException {
    return getResultTableFromStoreProcedure("summary_per_position_for_run", analysis, runProperties);
  }

  public ReportTable getSummaryValuesWithComments(String scope, Map<RunProperty, String> runProperties) throws SQLException {
    return getResultTableFromStoreProcedure("summary_value_with_comment", scope, runProperties);
  }

  public ReportTable getSummaryValues(String scope, Map<RunProperty, String> runProperties) throws SQLException {
    return getResultTableFromStoreProcedure("summary_value", scope, runProperties);
  }

  private ReportTable getResultTableFromStoreProcedure(String storeProcedure, String analysis, Map<RunProperty, String> runProperties) throws SQLException {
    String[] args = new String[6];
    args[0] = analysis;
    args[1] = runProperties.get(RunProperty.instrument);
    args[2] = runProperties.get(RunProperty.run);
    args[3] = runProperties.get(RunProperty.lane);
    args[4] = runProperties.get(RunProperty.pair);
    args[5] = runProperties.get(RunProperty.barcode);

    ReportTable rt = null;
    Connection con = null;
    try {
      con = getConnection();
      CallableStatement proc = con.prepareCall("{ call " + storeProcedure + "(?,?,?,?,?,?) }");

      for (int i = 0; i < args.length; i++) {
        if (args[i] == null) {
          proc.setNull(i + 1, java.sql.Types.VARCHAR);
        }
        else {
          proc.setString(i + 1, args[i]);
        }
      }

      boolean hadResults = proc.execute();
      if (hadResults) {
        rt = new GenericReportTable(proc.getResultSet());
      }
    }
    finally {
      if (!isSuppressClose()) {
        close(con);
      }
    }
    return rt;
  }

  /**
   * Returns a list of all the properties that can be used to select from a single property.
   *
   * @return
   * @throws SQLException
   */
  public List<String> getAnalysisProperties() throws SQLException {
    List<String> list = null;
    Connection con = null;
    try {
      con = getConnection();
      CallableStatement proc = con.prepareCall("{ call list_selectable_properties() }");

      boolean hadResults = proc.execute();
      if (hadResults) {
        list = resultSetToList(proc.getResultSet());
      }
    }
    finally {
      if (!isSuppressClose()) {
        close(con);
      }
    }
    return list;
  }

  public List<String> getValuesForProperty(String property) throws SQLException {
    List<String> list = null;
    Connection con = null;
    try {
      con = getConnection();
      CallableStatement proc = con.prepareCall("{ call list_selectable_values_from_property(?) }");
      proc.setString(1, property);

      boolean hadResults = proc.execute();
      if (hadResults) {
        list = resultSetToList(proc.getResultSet());
      }
    }
    finally {
      if (!isSuppressClose()) {
        close(con);
      }
    }
    return list;
  }

  public List<String> listRunsForInstrument(String instrument) throws SQLException {
    List<String> list = null;

    Connection con = null;
    try {
      con = getConnection();
      PreparedStatement proc = con.prepareStatement("SELECT DISTINCT analysis_property.value from analysis_property " +
                                                    "WHERE property = 'run' " +
                                                    "AND analysis_id IN " +
                                                    "(SELECT DISTINCT analysis_property.analysis_id from analysis_property "+
                                                    "WHERE property = 'instrument' AND value = ?);");
      proc.setString(1, instrument);

      boolean hadResults = proc.execute();
      ResultSet rs;
      if (hadResults) {
        rs = proc.getResultSet();
        list = resultSetToList(rs);
      }
    }
    finally {
      if (!isSuppressClose()) {
        close(con);
      }
    }
    return list;
  }

  public List<String> listAllRuns() throws SQLException {
    List<String> list = null;

    Connection con = null;
    try {
      con = getConnection();
      CallableStatement proc = con.prepareCall("{ call list_runs(?, ?, ?, ?, ?) }");
      proc.setNull(1, java.sql.Types.VARCHAR);
      proc.setNull(2, java.sql.Types.VARCHAR);
      proc.setNull(3, java.sql.Types.VARCHAR);
      proc.setNull(4, java.sql.Types.VARCHAR);
      proc.setNull(5, java.sql.Types.VARCHAR);

      boolean hadResults = proc.execute();
      ResultSet rs;
      if (hadResults) {
        rs = proc.getResultSet();
        list = resultSetToList(rs);
      }
    }
    finally {
      if (!isSuppressClose()) {
        close(con);
      }
    }
    return list;
  }

  public List<String> listLanesForRun(String run) throws SQLException {
    List<String> list = null;

    Connection con = null;
    try {
      con = getConnection();
      PreparedStatement proc = con.prepareStatement("SELECT DISTINCT analysis_property.value from analysis_property " +
                                                    "WHERE property = 'lane' " +
                                                    "AND analysis_id IN " +
                                                    "(SELECT DISTINCT analysis_property.analysis_id from analysis_property "+
                                                    "WHERE property = 'run' AND value = ?);");
      proc.setString(1, run);

      boolean hadResults = proc.execute();
      ResultSet rs;
      if (hadResults) {
        rs = proc.getResultSet();
        list = resultSetToList(rs);
      }
    }
    finally {
      if (!isSuppressClose()) {
        close(con);
      }
    }
    return list;
  }

  public List<String> listBarcodesForRunAndLane(String run, String lane) throws SQLException {
    List<String> list = null;

    Connection con = null;
    try {
      con = getConnection();
      PreparedStatement proc = con.prepareStatement("SELECT DISTINCT analysis_property.value from analysis_property " +
                                                    "WHERE property = 'barcode' " +
                                                    "AND analysis_id IN " +
                                                    "(SELECT DISTINCT analysis_property.analysis_id from analysis_property "+
                                                    "WHERE property = 'lane' AND value = ?) "+
                                                    "AND analysis_id IN "+
                                                    "(SELECT DISTINCT analysis_property.analysis_id from analysis_property "+
                                                    "WHERE property = 'run' AND value = ?);");
      proc.setString(1, lane);
      proc.setString(2, run);

      boolean hadResults = proc.execute();
      ResultSet rs;
      if (hadResults) {
        rs = proc.getResultSet();
        list = resultSetToList(rs);
      }
    }
    finally {
      if (!isSuppressClose()) {
        close(con);
      }
    }
    return list;
  }

  public String getSampleFromRunLaneBarcode(String run, String lane, String barcode) throws SQLException {
    List<String> list = null;

    Connection con = null;
    try {
      con = getConnection();
      PreparedStatement proc = con.prepareStatement("SELECT DISTINCT analysis_property.value from analysis_property " +
                                                    "WHERE property = 'sample_name' " +
                                                    "AND analysis_id IN " +
                                                    "(SELECT DISTINCT analysis_property.analysis_id from analysis_property "+
                                                    "WHERE property = 'barcode' AND value = ?) " +
                                                    "AND analysis_id IN " +
                                                    "(SELECT DISTINCT analysis_property.analysis_id from analysis_property "+
                                                    "WHERE property = 'lane' AND value = ?) "+
                                                    "AND analysis_id IN "+
                                                    "(SELECT DISTINCT analysis_property.analysis_id from analysis_property "+
                                                    "WHERE property = 'run' AND value = ?);");
      proc.setString(1, barcode);
      proc.setString(2, lane);
      proc.setString(3, run);

      boolean hadResults = proc.execute();
      ResultSet rs;
      if (hadResults) {
        rs = proc.getResultSet();
        list = resultSetToList(rs);
      }
    }
    finally {
      if (!isSuppressClose()) {
        close(con);
      }
    }
    return list.get(0);
  }

  private static List<String> resultSetToList(ResultSet rs) throws SQLException {
    ResultSetMetaData rsmd = rs.getMetaData();
    int columnCount = rsmd.getColumnCount();

    if (columnCount != 1)
      throw new SQLException("Expected just one column and found " + columnCount);

    List<String> list = new ArrayList<>();
    while (rs.next() && rs.getObject(1) != null) {
      list.add(rs.getObject(1).toString());
    }
    return list;
  }

  private void close(Connection con) {
    try {
      if (con != null) {
        con.close();
      }
    }
    catch (SQLException e) {
      e.printStackTrace();
    }
  }
}
