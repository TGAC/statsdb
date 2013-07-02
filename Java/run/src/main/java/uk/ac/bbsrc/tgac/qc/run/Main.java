package uk.ac.bbsrc.tgac.qc.run;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Properties;

/**
 * Created by IntelliJ IDEA.
 * User: ramirezr
 * Date: 20/02/2012
 * Time: 15:24
 * To change this template use File | Settings | File Templates.
 */
public class Main {
  public static void main(String[] args) throws Exception {
    System.out.println("Testing store proceudures.");
    Connection con = getConnectionFromProperties(null);

    Reports r = new Reports(con);
    ReportTable table = r.getPerPositionSummary("quality_mean", "instrument", "HiSeq1");
    System.out.print(table.toCSV());
    table = r.getPerPositionSummary("quality_mean", "instrument", "HiSeq1");
    System.out.println(table.toJSON());

    List<String> tmp_list = r.listPerBaseSummaryAnalyses();
    System.out.println(tmp_list);

    tmp_list = r.listGlobalAnalyses();
    System.out.println(tmp_list);

    System.out.println(r.getAverageValue("general_total_sequences", "lane", "7"));

    table = r.getAverageValues("lane", "1");
    System.out.println(table.toCSV());
    table = r.getAverageValues("barcode", "GCCAAT");
    System.out.println(table.toCSV());

    table = r.getAverageValues("barcode", "GGCTAC");
    System.out.println(table.toCSV());

    tmp_list = r.getAnalysisProperties();
    System.out.println(tmp_list);

    for (String s : tmp_list) {
      List<String> values = r.getValuesForProperty(s);
      System.out.println(s);
      System.out.println(values);
    }

    Map<RunProperty, String> properties = new HashMap<RunProperty, String>();
    table = r.getAverageValues(properties);
    System.out.println(table.toJSON());
    table = r.getPerPositionValues("quality_mean", properties);
    System.out.println(table.toCSV());

    properties.put(RunProperty.lane, "1");
    table = r.getAverageValues(properties);
    System.out.println(table.toJSON());
    table = r.getPerPositionValues("quality_mean", properties);
    System.out.println(table.toCSV());
    con.close();
  }

  static Connection getConnectionFromProperties(Properties p) {
    //See your driver documentation for the proper format of this string :
    String dbConnString = "jdbc:mysql://localhost:3306/run_statistics";
    //Provided by your driver documentation. In this case, a MySql driver is used :
    String driverClass = "org.gjt.mm.mysql.Driver";
    String user = "root";
    String password = "";

    Connection result = null;
    try {
      Class.forName(driverClass).newInstance();
    }
    catch (Exception ex) {
      System.out.println("Check classpath. Cannot load db driver: " + driverClass);
      ex.printStackTrace();
    }

    try {
      result = DriverManager.getConnection(dbConnString, user, password);
    }
    catch (SQLException e) {
      System.out.println("Driver loaded, but cannot connect to db: " + dbConnString);
      e.printStackTrace();
    }
    return result;
  }
}
