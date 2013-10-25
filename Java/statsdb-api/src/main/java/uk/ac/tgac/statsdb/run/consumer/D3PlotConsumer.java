package uk.ac.tgac.statsdb.run.consumer;

import net.sf.json.JSONArray;
import net.sf.json.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import uk.ac.tgac.statsdb.exception.ConsumerException;
import uk.ac.tgac.statsdb.run.ReportTable;
import uk.ac.tgac.statsdb.run.Reports;
import uk.ac.tgac.statsdb.run.ReportsDecorator;
import uk.ac.tgac.statsdb.run.RunProperty;

import javax.sql.DataSource;
import java.util.HashMap;
import java.util.Map;

/**
 * Consumer that is able to easily generate D3.js compliant JSON for plotting common QC graphs
 *
 * @author Rob Davey
 * @date 25/10/13
 * @since 1.1
 */
public class D3PlotConsumer {
  protected static final Logger log = LoggerFactory.getLogger(D3PlotConsumer.class);
  private ReportsDecorator reportsDecorator;

  public D3PlotConsumer(ReportsDecorator reportsDecorator) {
    this.reportsDecorator = reportsDecorator;
  }

  public D3PlotConsumer(DataSource dataSource) {
    this.reportsDecorator = new ReportsDecorator(new Reports(dataSource));
  }

  public D3PlotConsumer(JdbcTemplate template) {
    this(template.getDataSource());
  }

    /**
     * Returns JSONObject formatted Sequence Quality report for each lane.
     *
     * @param runName
     * @param pairedEnd
     * @param laneNumber
     * @return
     * @throws ConsumerException
     */

    public JSONObject getPerPositionBaseSequenceQualityForLane(String runName, boolean pairedEnd, int laneNumber) throws ConsumerException {
    Map<RunProperty, String> map = new HashMap<>();
    map.put(RunProperty.run, runName);
    map.put(RunProperty.lane, String.valueOf(laneNumber));
    String pair;
    if (pairedEnd) {
      pair = "1";
    }
    else {
      pair = "2";
    }
    map.put(RunProperty.pair, pair);

    JSONObject laneQuality = new JSONObject();
    try {
      Map<String, ReportTable> resultMap = reportsDecorator.getPerPositionBaseSequenceQuality(map);

      JSONArray quality_lower_quartile = JSONArray.fromObject(resultMap.get("quality_lower_quartile").toJSON());
      JSONArray quality_10th_percentile = JSONArray.fromObject(resultMap.get("quality_10th_percentile").toJSON());
      JSONArray quality_90th_percentile = JSONArray.fromObject(resultMap.get("quality_90th_percentile").toJSON());
      JSONArray quality_mean = JSONArray.fromObject(resultMap.get("quality_mean").toJSON());
      JSONArray quality_median = JSONArray.fromObject(resultMap.get("quality_median").toJSON());
      JSONArray quality_upper_quartile = JSONArray.fromObject(resultMap.get("quality_upper_quartile").toJSON());

      if (quality_lower_quartile.size() > 1) {
        JSONArray jsonArray = new JSONArray();
        for (int index = 1; index < quality_lower_quartile.size(); index++) {
          JSONObject eachBase = new JSONObject();
          eachBase.put("base", quality_lower_quartile.getJSONArray(index).getString(0));
          eachBase.put("mean", quality_mean.getJSONArray(index).getString(2));
          eachBase.put("median", quality_median.getJSONArray(index).getString(2));
          eachBase.put("lowerquartile", quality_lower_quartile.getJSONArray(index).getString(2));
          eachBase.put("upperquartile", quality_upper_quartile.getJSONArray(index).getString(2));
          eachBase.put("tenthpercentile", quality_10th_percentile.getJSONArray(index).getString(2));
          eachBase.put("ninetiethpercentile", quality_90th_percentile.getJSONArray(index).getString(2));
          jsonArray.add(eachBase);
        }
        laneQuality.put("stats", jsonArray);
      }
      else {
        laneQuality.put("stats", JSONArray.fromObject("[]"));
      }
    }
    catch (Exception e) {
      e.printStackTrace();
    }
    return laneQuality;
  }

    /**
     * Returns JSONObject formatted per position base content report for each lane.
     *
     * @param runName
     * @param pairedEnd
     * @param laneNumber
     * @return
     * @throws ConsumerException
     */

    public JSONObject getPerPositionBaseContentForLane(String runName, boolean pairedEnd, int laneNumber) throws ConsumerException {
    Map<RunProperty, String> map = new HashMap<>();
    map.put(RunProperty.run, runName);
    map.put(RunProperty.lane, String.valueOf(laneNumber));
    String pair;
    if (pairedEnd) {
      pair = "1";
    }
    else {
      pair = "2";
    }
    map.put(RunProperty.pair, pair);

    JSONObject laneQuality = new JSONObject();
    try {
      Map<String, ReportTable> resultMap = reportsDecorator.getPerPositionBaseContent(map);

      JSONArray base_content_a = JSONArray.fromObject(resultMap.get("base_content_a").toJSON());
      JSONArray base_content_c = JSONArray.fromObject(resultMap.get("base_content_c").toJSON());
      JSONArray base_content_g = JSONArray.fromObject(resultMap.get("base_content_g").toJSON());
      JSONArray base_content_t = JSONArray.fromObject(resultMap.get("base_content_t").toJSON());

      if (base_content_a.size() > 1) {
        JSONArray jsonArray = new JSONArray();
        for (int index = 1; index < base_content_a.size(); index++) {
          JSONObject eachBase = new JSONObject();
          eachBase.put("base", base_content_a.getJSONArray(index).getString(0));
          eachBase.put("G", base_content_g.getJSONArray(index).getString(2));
          eachBase.put("A", base_content_a.getJSONArray(index).getString(2));
          eachBase.put("T", base_content_t.getJSONArray(index).getString(2));
          eachBase.put("C", base_content_c.getJSONArray(index).getString(2));
          jsonArray.add(eachBase);
        }
        laneQuality.put("stats", jsonArray);
      }
      else {
        laneQuality.put("stats", JSONArray.fromObject("[]"));
      }
    }
    catch (Exception e) {
      e.printStackTrace();
    }
    return laneQuality;
  }
}
