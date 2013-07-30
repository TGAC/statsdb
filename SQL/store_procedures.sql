-- --------------------------------------------------------------------------------
-- Routine DDL
-- --------------------------------------------------------------------------------



DELIMITER $$

DROP PROCEDURE IF EXISTS summary_per_position$$
CREATE PROCEDURE summary_per_position(
	IN partition_value VARCHAR(45), 
    IN  analysis_property VARCHAR (45), 
    IN analysis_property_value VARCHAR (500))
BEGIN
    
    SELECT  
    position as Position, 
    size as Size, 
    AVG(per_partition_value.value) as Average
    FROM analysis_property, value_type, per_partition_value,type_scope   
    WHERE type_scope.scope = "base_partition"
		AND type_scope.id=value_type.type_scope_id  
		AND value_type.description = partition_value
		AND value_type.id = per_partition_value.value_type_id  
        AND analysis_property.property = analysis_property
        AND analysis_property.value = analysis_property_value
		AND per_partition_value.analysis_id=analysis_property.analysis_id
    GROUP BY value_type.id, position, size;
END$$



DROP PROCEDURE IF EXISTS list_summary_per_scope $$
CREATE PROCEDURE  list_summary_per_scope(IN scope_l VARCHAR(45))
BEGIN 
SELECT description FROM value_type, type_scope WHERE type_scope_id = type_scope.id and scope_l = scope;
END$$ 


DROP PROCEDURE IF EXISTS list_selectable_properties$$
CREATE PROCEDURE list_selectable_properties()
BEGIN 
SELECT property FROM analysis_property GROUP BY property;
END$$ 

DROP PROCEDURE IF EXISTS list_selectable_values_from_property$$
CREATE PROCEDURE list_selectable_values_from_property(IN prop VARCHAR (45))
BEGIN 
SELECT value FROM analysis_property WHERE property = prop GROUP BY value;
END$$

DROP PROCEDURE IF EXISTS general_summary$$

CREATE PROCEDURE general_summary(
	IN summary VARCHAR(45), 
    IN analysis_property VARCHAR (45), 
    IN analysis_property_value VARCHAR (500))
BEGIN
SELECT AVG(analysis_value.value) as Average FROM 
	value_type, analysis_value, analysis_property, type_scope
WHERE
	type_scope.scope = "analysis"
	AND type_scope.id=value_type.type_scope_id 
    AND value_type.id = analysis_value.value_type_id
    AND analysis_value.analysis_id = analysis_property.analysis_id
    AND description = summary 
    AND property = analysis_property
    AND analysis_property.value = analysis_property_value
	GROUP BY value_type.id;
END$$

DROP PROCEDURE IF EXISTS general_summaries$$
CREATE PROCEDURE general_summaries(
    IN analysis_property VARCHAR (45), 
    IN analysis_property_value VARCHAR (500))
BEGIN
SELECT description, AVG(analysis_value.value) as Average FROM 
	value_type, analysis_value, analysis_property, type_scope
WHERE
	type_scope.scope = "analysis"
	AND type_scope.id=value_type.type_scope_id 
    AND value_type.id = analysis_value.value_type_id
    AND analysis_value.analysis_id = analysis_property.analysis_id
    AND property = analysis_property
    AND analysis_property.value = analysis_property_value
	GROUP BY value_type.id, description;
END $$

CREATE OR REPLACE VIEW property
AS
SELECT
    analysis_property.analysis_id as id, 
    IF(property="Encoding", value, NULL) AS encoding  ,
    IF(property="cassava_version", value, NULL) AS casava  ,
    IF(property="chemistry_version", value, NULL) AS chemistry  ,
    IF(property="instrument", value, NULL) AS instrument  ,
    IF(property="software_on_instrument_version", value, NULL) AS software  ,
    IF(property="type_of_experiment", value, NULL) AS type  ,
    IF(property="pair", value, NULL) AS pair  ,
    IF(property="sample_name", value, NULL) AS sample_name , 
    IF(property="lane", value, NULL) AS lane ,  
    IF(property="barcode", value, NULL ) as barcode,
    IF(property="run", value, NULL ) as run
FROM 
    analysis_property
GROUP BY analysis_property.id $$

-- show warnings;

CREATE OR REPLACE VIEW run
AS
SELECT 
    property.id as analysis_id, 
    MAX(property.encoding) as encoding, 
    MAX(property.casava) as casava,  
    MAX(property.chemistry) as chemistry,
    MAX(property.instrument) as instrument, 
    MAX(property.software) as software, 
    MAX(property.type) as type,
    MAX(property.pair) as pair, 
    MAX(property.sample_name) as sample_name, 
    MAX(property.lane) as lane, 
    MAX(property.run) as run, 
    MAX(property.barcode) as barcode
FROM property AS property
GROUP BY id $$

DROP PROCEDURE IF EXISTS general_summaries_for_run$$

CREATE PROCEDURE 	general_summaries_for_run(
	IN instrument_in VARCHAR(500),
	IN run_in VARCHAR(500),
	IN lane_in VARCHAR(500),
	IN pair_in VARCHAR(500),
	IN barcode_in VARCHAR(500))
BEGIN	
	SELECT description, AVG(analysis_value.value) as Average FROM 
		value_type, analysis_value, run, type_scope
	WHERE
		type_scope.scope = "analysis"
		AND type_scope.id=value_type.type_scope_id 
	    AND value_type.id = analysis_value.value_type_id
	    AND analysis_value.analysis_id = run.analysis_id
	    AND IF(instrument_in IS NULL, TRUE, run.instrument = instrument_in)
		AND IF(run_in IS NULL, TRUE, run.run = run_in)
		AND IF(lane_in  IS NULL, TRUE,  run.lane = lane_in ) 
		AND IF(pair_in IS NULL, TRUE, run.pair = pair_in)
		AND IF(barcode_in IS NULL, TRUE, run.barcode = barcode_in)
	GROUP BY value_type.id, description;

END$$

-- call general_summaries_for_run(NULL, NULL, NULL, NULL, NULL)$$

-- call general_summaries_for_run(NULL, NULL, "1", NULL, NULL)$$

-- call general_summaries_for_run(NULL, NULL, "2", NULL, NULL)$$
-- 
DROP PROCEDURE IF EXISTS summary_per_position_for_run$$
CREATE PROCEDURE summary_per_position_for_run(
	IN partition_value VARCHAR(45), 
	IN instrument_in VARCHAR(500),
	IN run_in VARCHAR(500),
	IN lane_in VARCHAR(500),
	IN pair_in VARCHAR(500),
	IN barcode_in VARCHAR(500))
BEGIN
    
    SELECT  
    position as Position, 
    size as Size, 
    AVG(per_partition_value.value) as Average
    FROM run, value_type, per_partition_value,type_scope   
    WHERE type_scope.scope = "base_partition"
		AND type_scope.id=value_type.type_scope_id  
		AND value_type.description = partition_value
		AND value_type.id = per_partition_value.value_type_id  
		AND per_partition_value.analysis_id=run.analysis_id
		AND IF(instrument_in IS NULL, TRUE, run.instrument = instrument_in)
		AND IF(run_in IS NULL, TRUE, run.run = run_in)
		AND IF(lane_in  IS NULL, TRUE,  run.lane = lane_in ) 
		AND IF(pair_in IS NULL, TRUE, run.pair = pair_in)
		AND IF(barcode_in IS NULL, TRUE, run.barcode = barcode_in)
    GROUP BY value_type.id, position, size;
END$$
-- call summary_per_position_for_run("quality_mean", NULL, NULL, NULL, NULL, NULL)$$

-- call summary_per_position_for_run("quality_mean",NULL, NULL, "1", NULL, NULL)$$

-- call summary_per_position_for_run("quality_mean",NULL, NULL, "2", NULL, NULL)$$
delimiter ;
