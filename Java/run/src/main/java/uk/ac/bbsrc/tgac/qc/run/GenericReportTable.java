package uk.ac.bbsrc.tgac.qc.run;

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
 *
 * User: ramirezr
 * Date: 07/03/2012
 * Time: 09:28
 * To change this template use File | Settings | File Templates.
 */
public class GenericReportTable implements ReportTable{

    private ArrayList<String[]> table;
    private boolean empty;

    public  GenericReportTable(ArrayList<String[]> table){
        this.table = new ArrayList<String[]>(table);
        empty = table.size() <= 1;
    }

    public GenericReportTable(ResultSet rs) throws  SQLException{
        empty = true;
		ResultSetMetaData rsmd;
		rsmd = rs.getMetaData();
		int columnCount = rsmd.getColumnCount();
		String[] header = new String[columnCount];

		for (int i = 1; i <= columnCount; i++) {
			header[i-1] = rsmd.getColumnName(i);
		}

		table = new ArrayList<String[]>();
		table.add(header);
		String[] tmp;

		while (rs.next()){
            empty = false;
			tmp = new String[columnCount];
			for (int i = 1; i <= columnCount; i++) {
				tmp[i-1] = rs.getObject(i).toString();
			}
			table.add(tmp);
		}

		try{
			rs.beforeFirst();
		}catch (SQLException sqle){
			Logger.getLogger("Reports").log(Level.WARNING, "Unable to rest pointer" + sqle.getSQLState());
		}
	}


    public String toCSV() {
       return this.toCSV(',');
    }

    public String toCSV(char separator) {
        StringBuilder buff = new StringBuilder();
        for(Serializable[] arr: table){
            for (Serializable s: arr){
                buff.append(s.toString());
                buff.append(separator);
            }
            buff.deleteCharAt(buff.length()-1);
            buff.append('\n');
        }
        return buff.toString();
    }

    public String toJSON() throws IOException {
        ObjectMapper mapper = new ObjectMapper();
        return mapper.writeValueAsString(table);
    }

    public List<String> getHeaders() {

        Serializable[] headers = table.get(0);
        List<String> l = new LinkedList<String>();
        for (Serializable header : headers) {
            l.add(header.toString());
        }
        return l;
    }


    public List<String[]> getTable() {
       return new ArrayList<String[]>(table);
    }

    @Override
    public boolean isEmpty() {
      return empty;
    }

    public void append(ReportTable rt){
        List<String[]> other =  rt.getTable();
        boolean first = true;
        for(String[] col: other){
            if(!first){
                table.add(col);
            }
            first = false;
        }

    }



}
