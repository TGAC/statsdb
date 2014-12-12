-- --------------------------------------------------------------------------------
-- Routine DDL
-- --------------------------------------------------------------------------------



DELIMITER $$

DROP PROCEDURE IF EXISTS summary_per_position$$
CREATE PROCEDURE summary_per_position(
	IN partition_value VARCHAR(45), 
	IN analysis_property VARCHAR (45), 
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
CREATE PROCEDURE  list_summary_per_scope(
    IN scope_l VARCHAR(45))
BEGIN 
	SELECT description
	FROM value_type, type_scope
	WHERE type_scope_id = type_scope.id
	AND scope_l = scope;
END$$ 


DROP PROCEDURE IF EXISTS list_selectable_properties$$
CREATE PROCEDURE list_selectable_properties()
BEGIN 
    SELECT property
    FROM analysis_property
    GROUP BY property;
END$$ 

DROP PROCEDURE IF EXISTS list_selectable_values_from_property$$
CREATE PROCEDURE list_selectable_values_from_property(
	IN prop VARCHAR (45))
BEGIN 
	SELECT value
	FROM analysis_property
	WHERE property = prop
	GROUP BY value;
END$$

DROP PROCEDURE IF EXISTS select_runs_between_dates$$
CREATE PROCEDURE select_runs_between_dates(
	IN date1 TIMESTAMP,
	IN date2 TIMESTAMP)
BEGIN
	DECLARE hold TIMESTAMP;
	IF (date2 < date1) THEN
	SET hold = date2;
	SET date2 = date1;
	SET date1 = hold;
	END IF;
	
	IF (date_type IS NULL) THEN
	SET date_type = 'run_end';
	END IF;
	
	SELECT DISTINCT analysis_property.value 
	FROM analysis_property
	WHERE property = 'run' 
	AND analysis_id IN
		(SELECT DISTINCT analysis_id
		FROM analysis_date
		WHERE property = date_type
		AND date BETWEEN date1 AND date2)
	;
END$$

DROP PROCEDURE IF EXISTS general_summary$$
CREATE PROCEDURE general_summary(
	IN summary VARCHAR(45), 
	IN analysis_property VARCHAR (45), 
	IN analysis_property_value VARCHAR (500))
BEGIN
	SELECT AVG(analysis_value.value) as Average
    FROM 
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
    SELECT description, AVG(analysis_value.value) as Average
    FROM 
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
	IF(property="tool", value, NULL) AS tool  ,
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
	MAX(property.tool) as tool,
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

CREATE OR REPLACE view latest_run
AS 
SELECT 
	MAX(analysis_id) as analysis_id,  tool, encoding, casava, chemistry, instrument, software, type, pair, sample_name, lane, run, barcode 
FROM
	run
GROUP BY tool, encoding, casava, chemistry, instrument, software, type, pair, sample_name, lane, run, barcode $$

DROP PROCEDURE IF EXISTS general_summaries_for_run$$
CREATE PROCEDURE general_summaries_for_run(
	IN instrument_in VARCHAR(500),
	IN run_in VARCHAR(500),
	IN lane_in VARCHAR(500),
	IN pair_in VARCHAR(500),
    IN sample_name_in VARCHAR(500),
	IN barcode_in VARCHAR(500))
BEGIN
    CALL get_analysis_id_as_temp_table(
		instrument_in,
		run_in,
		lane_in,
		pair_in,
		sample_name_in,
		barcode_in,
		NULL)
	;
    
	SELECT description as Description,
		AVG(value) as Average, 
		COUNT(*) as Samples,
		sum(value) as Total 
	FROM 
		value_type, analysis_value, latest_run as run, type_scope
	WHERE
		type_scope.scope = "analysis"
		AND type_scope.id=value_type.type_scope_id 
		AND value_type.id = analysis_value.value_type_id
		AND analysis_value.analysis_id = run.analysis_id
		AND analysis_value.analysis_id IN
			(SELECT * FROM analysis_ids_tmp)
	GROUP BY value_type.id, description;
    DROP TEMPORARY TABLE IF EXISTS analysis_ids_tmp;
END$$

-- 
DROP PROCEDURE IF EXISTS summary_per_position_for_run$$
CREATE PROCEDURE summary_per_position_for_run(
	IN partition_value VARCHAR(45), 
	IN instrument_in VARCHAR(500),
	IN run_in VARCHAR(500),
	IN lane_in VARCHAR(500),
	IN pair_in VARCHAR(500),
    IN sample_name_in VARCHAR(500),
	IN barcode_in VARCHAR(500),
    IN tool_in VARCHAR(500))
BEGIN
--	DECLARE scope VARCHAR(500);
--	DECLARE valtype_id VARCHAR (500);
--	
--	SET scope = (
--		SELECT type_scope.scope 
--		FROM type_scope 
--		WHERE type_scope.id = (
--			SELECT value_type.type_scope_id 
--			FROM value_type 
--			WHERE value_type.description = partition_value))
--	;
--	
--	SET valtype_id = (
--		SELECT id 
--		FROM value_type 
--		WHERE value_type.description = partition_value)
--    ;
--    
--    IF EXISTS (
--		SELECT * 
--		FROM statsdb.per_partition_value 
--		WHERE value_type_id = valtype_id) 
--	THEN
--		SELECT  
--		position as Position,
--		size as Size,
--		AVG(value) as Average,
--		COUNT(*) as Samples,
--		sum(value) as Total
--		FROM value_type, per_partition_value,type_scope, latest_run as run
--		WHERE type_scope.scope = scope
--			AND type_scope.id=value_type.type_scope_id  
--			AND value_type.description = partition_value
--			AND value_type.id = per_partition_value.value_type_id  
--			AND per_partition_value.analysis_id=run.analysis_id
--			AND IF(instrument_in IS NULL, TRUE, run.instrument = instrument_in)
--			AND IF(run_in IS NULL, TRUE, run.run = run_in)
--			AND IF(lane_in  IS NULL, TRUE,  run.lane = lane_in )
--			AND IF(pair_in IS NULL, TRUE, run.pair = pair_in)
--			AND IF(barcode_in IS NULL, TRUE, run.barcode = barcode_in)
--		GROUP BY value_type.id, position, size
--		;
--	ELSE
--		SELECT  
--		position as Position,  
--		'1' as Size,
--		AVG(value) as Average,
--		COUNT(*) as Samples,
--		sum(value) as Total
--		FROM value_type, per_position_value,type_scope, latest_run as run
--		WHERE type_scope.scope = scope
--			AND type_scope.id=value_type.type_scope_id  
--			AND value_type.description = partition_value
--			AND value_type.id = per_position_value.value_type_id  
--			AND per_position_value.analysis_id=run.analysis_id
--			AND IF(instrument_in IS NULL, TRUE, run.instrument = instrument_in)
--			AND IF(run_in IS NULL, TRUE, run.run = run_in)
--			AND IF(lane_in  IS NULL, TRUE,  run.lane = lane_in )
--			AND IF(pair_in IS NULL, TRUE, run.pair = pair_in)
--			AND IF(barcode_in IS NULL, TRUE, run.barcode = barcode_in)
--		GROUP BY value_type.id, position
--		ORDER BY Position
--		;
--	END IF;

--  This seems to result in a truly massive increase in speed, largely by
--  eliminating the use of the run/latest_run views, which are complex and
--  take a long time to put together.
    DECLARE valtype_id VARCHAR (500);
	SET valtype_id = (
		SELECT id 
		FROM value_type 
		WHERE value_type.description = partition_value)
	;
	
	CALL get_analysis_id_as_temp_table(
		instrument_in,
		run_in,
		lane_in,
		pair_in,
		sample_name_in,
		barcode_in,
		tool_in)
	;
	
	IF EXISTS (
		SELECT * 
		FROM statsdb.per_partition_value 
		WHERE value_type_id = valtype_id) 
	THEN
		SELECT  
		position as Position,
		size as Size,
		AVG(value) as Average,
		COUNT(*) as Samples,
		sum(value) as Total
		FROM per_partition_value AS pos
		INNER JOIN value_type AS val ON val.id = pos.value_type_id
		WHERE analysis_id IN (SELECT * FROM analysis_ids_tmp)
		AND value_type_id = valtype_id
		GROUP BY value_type_id, position
		ORDER BY position
		;
	ELSE
		SELECT  
		position as Position,  
		'1' as Size,
		AVG(value) as Average,
		COUNT(*) as Samples,
		sum(value) as Total
		FROM per_position_value AS pos
		INNER JOIN value_type AS val ON val.id = pos.value_type_id
		WHERE analysis_id IN (SELECT * FROM analysis_ids_tmp)
		AND value_type_id = valtype_id
		GROUP BY value_type_id, position
		ORDER BY position
		;
    END IF;
	DROP TEMPORARY TABLE IF EXISTS analysis_ids_tmp;
END$$

DROP PROCEDURE IF EXISTS get_analysis_id$$
CREATE PROCEDURE get_analysis_id(
	IN instrument_in VARCHAR(500),
	IN run_in VARCHAR(500),
	IN lane_in VARCHAR(500),
	IN pair_in VARCHAR(500),
	IN sample_name_in VARCHAR(500),
	IN barcode_in VARCHAR(500),
    IN tool_in VARCHAR(500))
BEGIN
	SELECT DISTINCT analysis_id 
	FROM analysis_property
	WHERE 
		IF(instrument_in IS NULL, TRUE, analysis_id IN
			(SELECT DISTINCT analysis_id
			FROM analysis_property
			WHERE property = 'instrument'
			AND value = instrument_in))
		AND IF(run_in IS NULL, TRUE, analysis_id IN
			(SELECT DISTINCT analysis_id
			FROM analysis_property
			WHERE property = 'run'
			AND value = run_in))
		AND IF(lane_in IS NULL, TRUE, analysis_id IN
			(SELECT DISTINCT analysis_id
			FROM analysis_property
			WHERE property = 'lane'
			AND value = lane_in))
		AND IF(pair_in IS NULL, TRUE, analysis_id IN
			(SELECT DISTINCT analysis_id
			FROM analysis_property
			WHERE property = 'pair'
			AND value = pair_in))
		AND IF(sample_name_in IS NULL, TRUE, analysis_id IN
			(SELECT DISTINCT analysis_id
			FROM analysis_property
			WHERE property = 'sample_name'
			AND value = sample_name_in))
		AND IF(barcode_in IS NULL, TRUE, analysis_id IN
			(SELECT DISTINCT analysis_id
			FROM analysis_property
			WHERE property = 'barcode'
			AND value = barcode_in))
		AND IF(tool_in IS NULL, TRUE, analysis_id IN
			(SELECT DISTINCT analysis_id
			FROM analysis_property
			WHERE property = 'tool'
			AND value = tool_in))
	;
END$$

DROP PROCEDURE IF EXISTS get_analysis_id_as_temp_table$$
CREATE PROCEDURE get_analysis_id_as_temp_table(
	IN instrument_in VARCHAR(500),
	IN run_in VARCHAR(500),
	IN lane_in VARCHAR(500),
	IN pair_in VARCHAR(500),
	IN sample_name_in VARCHAR(500),
	IN barcode_in VARCHAR(500),
    IN tool_in VARCHAR(500))
BEGIN
--    This creates a temporary table in memory holding a set of analysis_ids,
--    in order to work around MySQL's inability to use the output of
--    stored procedures inside other stored procedures.
    DROP TEMPORARY TABLE IF EXISTS analysis_ids_tmp;
    CREATE TEMPORARY TABLE analysis_ids_tmp ENGINE=MEMORY AS
	SELECT DISTINCT analysis_id 
	FROM analysis_property
	WHERE 
		IF(instrument_in IS NULL, TRUE, analysis_id IN
			(SELECT DISTINCT analysis_id
			FROM analysis_property
			WHERE property = 'instrument'
			AND value = instrument_in))
		AND IF(run_in IS NULL, TRUE, analysis_id IN
			(SELECT DISTINCT analysis_id
			FROM analysis_property
			WHERE property = 'run'
			AND value = run_in))
		AND IF(lane_in IS NULL, TRUE, analysis_id IN
			(SELECT DISTINCT analysis_id
			FROM analysis_property
			WHERE property = 'lane'
			AND value = lane_in))
		AND IF(pair_in IS NULL, TRUE, analysis_id IN
			(SELECT DISTINCT analysis_id
			FROM analysis_property
			WHERE property = 'pair'
			AND value = pair_in))
		AND IF(sample_name_in IS NULL, TRUE, analysis_id IN
			(SELECT DISTINCT analysis_id
			FROM analysis_property
			WHERE property = 'sample_name'
			AND value = sample_name_in))
		AND IF(barcode_in IS NULL, TRUE, analysis_id IN
			(SELECT DISTINCT analysis_id
			FROM analysis_property
			WHERE property = 'barcode'
			AND value = barcode_in))
		AND IF(tool_in IS NULL, TRUE, analysis_id IN
			(SELECT DISTINCT analysis_id
			FROM analysis_property
			WHERE property = 'tool'
			AND value = tool_in))
	;
END$$

DROP PROCEDURE IF EXISTS list_runs$$
CREATE PROCEDURE list_runs(
	IN instrument_in VARCHAR(500),
	IN run_in VARCHAR(500),
	IN lane_in VARCHAR(500),
	IN pair_in VARCHAR(500),
	IN sample_name_in VARCHAR(500),
	IN barcode_in VARCHAR(500))
BEGIN
	CALL get_analysis_id_as_temp_table(
		instrument_in,
		run_in,
		lane_in,
		pair_in,
		sample_name_in,
		barcode_in,
		tool_in)
	;
	
    SELECT DISTINCT analysis_property.value AS run
	FROM analysis_property
	WHERE 
    property = 'run'
    AND analysis_id IN
		(SELECT * FROM analysis_ids_tmp)
	;
	DROP TEMPORARY TABLE IF EXISTS analysis_ids_tmp;
END$$

DROP PROCEDURE IF EXISTS list_instruments$$
CREATE PROCEDURE list_instruments(
	IN instrument_in VARCHAR(500),
	IN run_in VARCHAR(500),
	IN lane_in VARCHAR(500),
	IN pair_in VARCHAR(500),
	IN sample_name_in VARCHAR(500),
	IN barcode_in VARCHAR(500))
BEGIN
	CALL get_analysis_id_as_temp_table(
		instrument_in,
		run_in,
		lane_in,
		pair_in,
		sample_name_in,
		barcode_in,
		NULL)
	;
	
    SELECT DISTINCT analysis_property.value as instrument
	FROM analysis_property
	WHERE 
    property = 'instrument'
    AND analysis_id IN
		(SELECT * FROM analysis_ids_tmp)
	;
	DROP TEMPORARY TABLE IF EXISTS analysis_ids_tmp;
END$$

DROP PROCEDURE IF EXISTS list_runs_for_instrument$$
CREATE PROCEDURE list_runs_for_instrument(
    IN instrument_in VARCHAR(500))
BEGIN
	SELECT DISTINCT analysis_property.value AS run
	FROM analysis_property 
	WHERE property = 'run'
	AND analysis_id IN 
		(SELECT DISTINCT analysis_property.analysis_id
		FROM analysis_property 
		WHERE property = 'instrument'
		AND value = instrument_in)
	;
END$$

DROP PROCEDURE IF EXISTS list_lanes_for_run$$
CREATE PROCEDURE list_lanes_for_run(
    IN run_in VARCHAR(500))
BEGIN
	SELECT DISTINCT analysis_property.value AS lane
	FROM analysis_property 
	WHERE property = 'lane' 
	AND analysis_id IN 
		(SELECT DISTINCT analysis_property.analysis_id
		FROM analysis_property 
		WHERE property = 'run'
		AND value = run_in)
	;
END$$

DROP PROCEDURE IF EXISTS get_encoding_for_run$$
CREATE PROCEDURE get_encoding_for_run(
IN run_in VARCHAR(500))
BEGIN
	SELECT DISTINCT analysis_property.value
	FROM analysis_property
	WHERE property = 'Encoding' 
    AND value IS NOT NULL
    AND analysis_id IN
        (SELECT DISTINCT analysis_property.analysis_id
        FROM analysis_property
        WHERE property = 'run' 
        AND value = run_in)
	;
END$$

DROP PROCEDURE IF EXISTS list_barcodes_for_run_and_lane$$
CREATE PROCEDURE list_barcodes_for_run_and_lane(
	IN run_in VARCHAR(500), 
	IN lane_in VARCHAR(500))
BEGIN
	SELECT DISTINCT analysis_property.value
	FROM analysis_property
	WHERE property = 'barcode'
	AND analysis_id IN 
		(SELECT DISTINCT analysis_property.analysis_id
		FROM analysis_property 
		WHERE property = 'lane'
		AND value = lane_in)
	AND analysis_id IN 
		(SELECT DISTINCT analysis_property.analysis_id
		FROM analysis_property 
		WHERE property = 'run'
		AND value = run_in)
	;
END$$

DROP PROCEDURE IF EXISTS list_barcodes_for_sample$$
CREATE PROCEDURE list_barcodes_for_sample(
    IN sample_name_in VARCHAR(500))
BEGIN
	SELECT DISTINCT analysis_property.value
	FROM analysis_property
	WHERE property = 'barcode' 
	AND value IS NOT NULL
	AND analysis_id IN
			(SELECT DISTINCT analysis_property.analysis_id
			FROM analysis_property
			WHERE property = 'sample_name' 
			AND value = sample_name_in)
	;
END$$

DROP PROCEDURE IF EXISTS get_sample_from_run_lane_barcode$$
CREATE PROCEDURE get_sample_from_run_lane_barcode(
	IN run_in VARCHAR(500),
	IN lane_in VARCHAR(500), 
	IN barcode_in VARCHAR(500)
	)
BEGIN
	SELECT DISTINCT analysis_property.value AS sample_name
	FROM analysis_property 
	WHERE property = 'sample_name'
	AND analysis_id IN
		(SELECT DISTINCT analysis_property.analysis_id
		FROM analysis_property 
		WHERE property = 'barcode'
		AND value = barcode_in)
	AND analysis_id IN 
		(SELECT DISTINCT analysis_property.analysis_id
		FROM analysis_property 
		WHERE property = 'lane'
		AND value = lane_in) 
	AND analysis_id IN 
		(SELECT DISTINCT analysis_property.analysis_id
		FROM analysis_property 
		WHERE property = 'run'
		AND value = run_in)
	;
END$$

DROP PROCEDURE IF EXISTS list_subdivisions$$
CREATE PROCEDURE list_subdivisions(
	IN instrument_in VARCHAR(500),
	IN run_in VARCHAR(500),
	IN lane_in VARCHAR(500),
	IN pair_in VARCHAR(500),
	IN sample_name_in VARCHAR(500),
	IN barcode_in VARCHAR(500),
    IN analysis_in BIGINT(20),
	IN date1 TIMESTAMP, 
	IN date2 TIMESTAMP,
	IN date_type VARCHAR(500),
	IN tool_in VARCHAR(500),
	IN qscope_in VARCHAR(500))
BEGIN
	DECLARE hold TIMESTAMP;
	IF (date2 < date1) THEN
		SET hold = date2;
		SET date2 = date1;
		SET date1 = hold;
	END IF;
	
	IF (qscope_in IS NULL AND analysis_in IS NOT NULL) THEN
		SET qscope_in = 'barcode';
	END IF;
	
	IF (date_type IS NULL) THEN
        SET date_type = 'run_end';
	END IF;
	
	CALL get_analysis_id_as_temp_table(
		instrument_in,
		run_in,
		lane_in,
		pair_in,
		sample_name_in,
		barcode_in,
		tool_in)
	;
	
	DROP TEMPORARY TABLE IF EXISTS subdivisions_tmp;
    CREATE TEMPORARY TABLE subdivisions_tmp ENGINE=MEMORY AS
    SELECT analysis_id,
        CASE WHEN property = 'instrument'
            THEN value END AS instrument,
        CASE WHEN property = 'run'
            THEN value END AS run,
        CASE WHEN property = 'lane'
            THEN value END AS lane,
        CASE WHEN property = 'pair'
            THEN value END AS pair,
        CASE WHEN property = 'sample_name'
            THEN value END AS sample_name,
        CASE WHEN property = 'barcode'
            THEN value END AS barcode,
		CASE WHEN property = 'tool'
            THEN value END AS tool
    FROM analysis_property
    WHERE
        IF(analysis_in IS NULL, TRUE, analysis_id = analysis_in)
		AND analysis_id IN
            (SELECT * FROM analysis_ids_tmp)
		AND IF(date1 IS NULL OR date2 IS NULL, TRUE, analysis_id IN
            (SELECT DISTINCT analysis_id
			FROM analysis_date
			WHERE property = date_type
			AND date BETWEEN date1 AND date2))
    ;
	
	DROP TEMPORARY TABLE IF EXISTS subdivisions_tmp_2;
	CREATE TEMPORARY TABLE subdivisions_tmp_2 ENGINE=INNODB AS
	SELECT DISTINCT
	GROUP_CONCAT(instrument) AS instrument,
	GROUP_CONCAT(run) AS run,
	GROUP_CONCAT(lane) AS lane,
	GROUP_CONCAT(pair) AS pair,
	GROUP_CONCAT(sample_name) AS sample_name,
	GROUP_CONCAT(barcode) AS barcode,
    GROUP_CONCAT(tool) AS tool
	FROM subdivisions_tmp
	GROUP BY analysis_id
	;
	
	IF qscope_in IS NOT NULL
	THEN
		SELECT DISTINCT
		CASE WHEN qscope_in IN ('instrument','run','lane','pair','sample','sample_name','barcode') 
			THEN instrument END AS instrument,
		CASE WHEN qscope_in IN ('run','lane','pair','sample','sample_name','barcode') 
			THEN run END AS run,
		CASE WHEN qscope_in IN ('lane','pair','sample','sample_name','barcode')
			THEN lane END AS lane,
		CASE WHEN qscope_in IN ('pair','sample','sample_name','barcode')
			THEN pair END AS pair,
		CASE WHEN qscope_in IN ('sample','sample_name','barcode')
			THEN sample_name END AS sample_name,
		CASE WHEN qscope_in IN ('sample','sample_name','barcode')
			THEN barcode END AS barcode,
        tool as tool
		FROM subdivisions_tmp_2
		ORDER BY instrument, run, lane, pair, sample_name, barcode
		;
	ELSE
		SELECT DISTINCT
		CASE WHEN instrument_in IS NOT NULL THEN instrument END AS instrument,
		CASE WHEN run_in IS NOT NULL THEN run END AS run,
		CASE WHEN lane_in IS NOT NULL THEN lane END AS lane,
		CASE WHEN pair_in IS NOT NULL THEN pair END AS pair,
		CASE WHEN sample_name_in IS NOT NULL THEN sample_name END AS sample_name,
		CASE WHEN barcode_in IS NOT NULL THEN barcode END AS barcode
        tool as tool
		FROM subdivisions_tmp_2
		ORDER BY instrument, run, lane, pair, sample_name, barcode
		;
	END IF;
    DROP TEMPORARY TABLE IF EXISTS analysis_ids_tmp;
	DROP TEMPORARY TABLE subdivisions_tmp;
	DROP TEMPORARY TABLE subdivisions_tmp_2;
END$$

DROP PROCEDURE IF EXISTS summary_value_with_comment$$
CREATE PROCEDURE summary_value_with_comment(
	IN scope_in VARCHAR(45), 
	IN instrument_in VARCHAR(500),
	IN run_in VARCHAR(500),
	IN lane_in VARCHAR(500),
	IN pair_in VARCHAR(500),
    IN sample_name_in VARCHAR(500),
	IN barcode_in VARCHAR(500))	
BEGIN
    CALL get_analysis_id_as_temp_table(
		instrument_in,
		run_in,
		lane_in,
		pair_in,
		sample_name_in,
		barcode_in,
		NULL)
	;
    
	SELECT  
	description as Description,
	comment as Comment, 
	AVG(value) as Average, 
	COUNT(*) as Samples,
	sum(value) as Total
	FROM type_scope, value_type, analysis_value
	WHERE
		scope = scope_in 
		AND type_scope.id = value_type.type_scope_id 
		AND analysis_value.value_type_id = value_type.id 
		AND analysis_value.analysis_id = run.analysis_id
		AND analysis_value.analysis_id IN
			(SELECT * FROM analysis_ids_tmp)
	GROUP BY 
		description, comment
	ORDER BY 
		Total DESC 
	;
	DROP TEMPORARY TABLE IF EXISTS analysis_ids_tmp;
END$$

DROP PROCEDURE IF EXISTS summary_value$$
CREATE PROCEDURE summary_value(
	IN scope_in VARCHAR(45), 
	IN instrument_in VARCHAR(500),
	IN run_in VARCHAR(500),
	IN lane_in VARCHAR(500),
	IN pair_in VARCHAR(500),
    IN sample_name_in VARCHAR(500),
	IN barcode_in VARCHAR(500))	
BEGIN
    CALL get_analysis_id_as_temp_table(
		instrument_in,
		run_in,
		lane_in,
		pair_in,
		sample_name_in,
		barcode_in,
		NULL)
	;
    
	SELECT  
	description as Description,
	AVG(value) as Average, 
	COUNT(*) as Samples,
	sum(value) as Total
	FROM type_scope, value_type, analysis_value
	WHERE scope=scope_in 
		AND type_scope.id =value_type.type_scope_id 
		AND analysis_value.value_type_id = value_type.id 
		AND analysis_value.analysis_id=run.analysis_id
		AND analysis_value.analysis_id IN
			(SELECT * FROM analysis_ids_tmp)
	GROUP BY 
		description, comment
	ORDER BY
		Total Desc
	;
    DROP TEMPORARY TABLE IF EXISTS analysis_ids_tmp;
END$$

DROP PROCEDURE IF EXISTS analysis_id_check$$
CREATE PROCEDURE analysis_id_check(
	IN analysis_in INT(45))	
BEGIN
	SELECT COUNT(*) 
	AS total 
	FROM analysis
	WHERE id = analysis_in
	;
END$$

DROP PROCEDURE IF EXISTS delete_analysis$$
CREATE PROCEDURE delete_analysis(
	IN analysis_in INT(45))	
BEGIN
	DELETE FROM statsdb.analysis
	WHERE id = analysis_in
	;
END$$

-- call summary_per_position_for_run("quality_mean",NULL, NULL, "1", NULL, NULL)$$

-- call summary_per_position_for_run("quality_mean",NULL, NULL, "2", NULL, NULL)$$
delimiter ;
