package uk.ac.bbsrc.tgac.statsdb.dao;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.simple.SimpleJdbcInsert;
import uk.ac.bbsrc.tgac.statsdb.analysis.PartitionValue;
import uk.ac.bbsrc.tgac.statsdb.analysis.PositionValue;
import uk.ac.bbsrc.tgac.statsdb.analysis.QCAnalysis;
import uk.ac.bbsrc.tgac.statsdb.exception.QCAnalysisException;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * uk.ac.bbsrc.tgac.qc.dao
 * <p/>
 * Implementation of a QCAnalysisStore
 *
 * @author Rob Davey
 * @date 02/07/13
 * @since 1.0-SNAPSHOT
 */
public class QCAnalysisDAO implements QCAnalysisStore {
  protected static final Logger log = LoggerFactory.getLogger(QCAnalysisDAO.class);
  private JdbcTemplate template;
  private Map<String, Long> typeScopes = new HashMap<>();
  private Map<String, Long> valueTypes = new HashMap<>();
  private boolean verbose = false;

  private static final String TYPE_SCOPE_SELECT =
      "SELECT id FROM type_scope WHERE scope = ?";
  private static final String VALUE_TYPE_SELECT =
      "SELECT id FROM value_type WHERE type_scope_id= ? AND description= ?";

  /**
   * Get the JdbcTemplate associated with this data access object
   *
   * @return the template
   */
  public JdbcTemplate getJdbcTemplate() {
    return template;
  }

  /**
   * Sets the JdbcTemplate to use for this data access object
   *
   * @param template
   */
  public void setJdbcTemplate(JdbcTemplate template) {
    this.template = template;
  }

  @Override
  public void setVerbose(boolean verbose) {
    this.verbose = verbose;
  }

  @Override
  public void insertAnalysis(QCAnalysis analysis) throws QCAnalysisException, DataAccessException {
    log.info("Inserting analysis:");
    MapSqlParameterSource params = new MapSqlParameterSource();

    SimpleJdbcInsert insert = new SimpleJdbcInsert(template)
                          .withTableName("analysis")
                          .usingGeneratedKeyColumns("id");
    Number newId = insert.executeAndReturnKey(params);
    analysis.setId(newId.longValue());

    insertProperties(analysis);
    log.info("\t\\_ Inserted properties");
    insertValues(analysis);
    log.info("\t\\_ Inserted general values");
    insertPartitionValues(analysis);
    log.info("\t\\_ Inserted partition values");
    insertPositionValues(analysis);
    log.info("\t\\_ Inserted position values");
  }

  @Override
  public void insertValues(QCAnalysis analysis) throws QCAnalysisException, DataAccessException {
    Map<String, String> types = analysis.getValueScopes();
    Map<String, String> descriptions = analysis.getValueDescriptions();

    Map<String, Long> valueIds = new HashMap<>();
    long valueId;

    for (String key : types.keySet()) {
      String valueType = types.get(key);
      String valueDesc = descriptions.get(key);
      valueIds.put(key, getValueId(key, valueType, valueDesc));
    }

    Map<String, String> generalValues = analysis.getGeneralValues();
    for (String key : generalValues.keySet()) {
      if (valueIds.get(key) != null) {
        valueId = valueIds.get(key);
        MapSqlParameterSource params = new MapSqlParameterSource();
        params.addValue("analysis_id", analysis.getId())
              .addValue("value_type_id", valueId)
              .addValue("value", generalValues.get(key));

        SimpleJdbcInsert insert = new SimpleJdbcInsert(template)
                              .withTableName("analysis_value")
                              .usingGeneratedKeyColumns("id");
        insert.execute(params);
        if (verbose) {
          log.info("\t\\_ VALUE [" + valueId + "," + generalValues.get(key) + "]");
        }
      }
      else {
        log.warn("Value not defined: " + key);
      }
    }
  }

  @Override
  public void insertProperties(QCAnalysis analysis) throws QCAnalysisException, DataAccessException {
    Map<String, String> properties = analysis.getProperties();
    for (String key : properties.keySet()) {
      MapSqlParameterSource params = new MapSqlParameterSource();
      params.addValue("analysis_id", analysis.getId())
            .addValue("property", key)
            .addValue("value", properties.get(key));

      SimpleJdbcInsert insert = new SimpleJdbcInsert(template)
                            .withTableName("analysis_property")
                            .usingGeneratedKeyColumns("id");
      insert.execute(params);
      if (verbose) {
        log.info("\t\\_ PROPERTY [" + key + "," + properties.get(key) + "]");
      }
    }
  }

  @Override
  public void insertPartitionValues(QCAnalysis analysis) throws QCAnalysisException, DataAccessException {
    Map<String, String> types = analysis.getValueScopes();
    Map<String, String> descriptions = analysis.getValueDescriptions();

    Map<String, Long> valueIds = new HashMap<>();
    long valueId;

    for (String key : types.keySet()) {
      String valueType = types.get(key);
      String valueDesc = descriptions.get(key);
      valueIds.put(key, getValueId(key, valueType, valueDesc));
    }

    List<PartitionValue> partitionValues = analysis.getPartitionValues();
    for (PartitionValue pv : partitionValues) {
      if (valueIds.get(pv.getKey()) != null) {
        valueId = valueIds.get(pv.getKey());
        MapSqlParameterSource params = new MapSqlParameterSource();
        params.addValue("analysis_id", analysis.getId())
              .addValue("position", pv.getPosition())
              .addValue("size", pv.getSize())
              .addValue("value_type_id", valueId)
              .addValue("value", pv.getValue());

        SimpleJdbcInsert insert = new SimpleJdbcInsert(template)
                              .withTableName("per_partition_value")
                              .usingGeneratedKeyColumns("id");
        insert.execute(params);
        if (verbose) {
          log.info("\t\\_ PARTITION VALUE [" + pv.getPosition() + "," + pv.getSize() + ","+valueId+","+pv.getValue()+"]");
        }
      }
      else {
        log.warn("Partition value type not defined: " + pv.getKey());
      }
    }
  }

  @Override
  public void insertPositionValues(QCAnalysis analysis) throws QCAnalysisException, DataAccessException {
    Map<String, String> types = analysis.getValueScopes();
    Map<String, String> descriptions = analysis.getValueDescriptions();

    Map<String, Long> valueIds = new HashMap<>();
    long valueId;

    for (String key : types.keySet()) {
      String valueType = types.get(key);
      String valueDesc = descriptions.get(key);
      valueIds.put(key, getValueId(key, valueType, valueDesc));
    }

    List<PositionValue> positionValues = analysis.getPositionValues();
    for (PositionValue pv : positionValues) {
      if (valueIds.get(pv.getKey()) != null) {
        valueId = valueIds.get(pv.getKey());
        MapSqlParameterSource params = new MapSqlParameterSource();
        params.addValue("analysis_id", analysis.getId())
              .addValue("position", pv.getPosition())
              .addValue("value_type_id", valueId)
              .addValue("value", pv.getValue());

        SimpleJdbcInsert insert = new SimpleJdbcInsert(template)
                              .withTableName("per_position_value")
                              .usingGeneratedKeyColumns("id");
        insert.execute(params);
        if (verbose) {
          log.info("\t\\_ POSITION VALUE [" + pv.getPosition() + ","+valueId+","+pv.getValue()+"]");
        }
      }
      else {
        log.warn("Position value type not defined: " + pv.getKey());
      }
    }
  }

  private long getValueId(String value, String valueType, String description) throws DataAccessException {
    long typeId = 0;
    long valueId = 0;

    if (verbose) {
      log.info("Getting valueId for [" + value + "," + valueType + "," + description + "]");
    }

    if (!typeScopes.keySet().contains(valueType) || typeScopes.get(valueType) == null) {
      try {
        typeId = template.queryForLong(TYPE_SCOPE_SELECT, valueType);
      }
      catch (EmptyResultDataAccessException e) {
        typeId = 0;
      }

      if (typeId != 0) {
        typeScopes.put(valueType, typeId);
      }
      else {
        if (verbose) {
          log.debug("No such type scope in database. Inserting '" + valueType + "'");
        }
        MapSqlParameterSource params = new MapSqlParameterSource();
        params.addValue("scope", valueType);
        SimpleJdbcInsert insert = new SimpleJdbcInsert(template)
                              .withTableName("type_scope")
                              .usingGeneratedKeyColumns("id");
        Number newId = insert.executeAndReturnKey(params);
        typeId = newId.longValue();
        typeScopes.put(valueType, typeId);
      }
    }
    else {
      typeId = typeScopes.get(valueType);
    }

    if (!valueTypes.keySet().contains(value) || valueTypes.get(value) == null) {
      try {
        valueId = template.queryForLong(VALUE_TYPE_SELECT, typeId, value);
      }
      catch (EmptyResultDataAccessException e) {
        valueId = 0;
      }

      if (valueId != 0) {
        valueTypes.put(valueType, valueId);
      }
      else {
        if (verbose) {
          log.debug("No such value type in database. Inserting '" + typeId + "','" + value + "'");
        }
        MapSqlParameterSource params = new MapSqlParameterSource();
        params.addValue("type_scope_id", typeId);
        params.addValue("description", value);
        params.addValue("comment", description);

        SimpleJdbcInsert insert = new SimpleJdbcInsert(template)
                              .withTableName("value_type")
                              .usingGeneratedKeyColumns("id");
        Number newId = insert.executeAndReturnKey(params);
        valueId = newId.longValue();
        valueTypes.put(value, valueId);
      }
    }
    else {
      valueId = valueTypes.get(value);
    }

    return valueId;
  }
}

