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

DROP PROCEDURE IF EXISTS list_summary_per_scope$$
CREATE PROCEDURE  list_summary_per_scope(
	IN scope_l VARCHAR(45))
BEGIN 
	SELECT description
	FROM value_type, type_scope
	WHERE type_scope_id = type_scope.id
	AND scope_l = scope;
END$$ 

DROP PROCEDURE IF EXISTS list_selectable_values_for_run$$
CREATE PROCEDURE list_selectable_values_for_run(
	IN instrument_in VARCHAR(500),
	IN run_in VARCHAR(500),
	IN lane_in VARCHAR(500),
	IN pair_in VARCHAR(500),
	IN sample_name_in VARCHAR(500),
	IN barcode_in VARCHAR(500),
	IN tool_in VARCHAR(500))
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
	
	DROP TEMPORARY TABLE IF EXISTS values_analysis_values;
	CREATE TEMPORARY TABLE values_analysis_values ENGINE=MEMORY AS
	SELECT DISTINCT 
		analysis_value.value_type_id AS value_type_id
	FROM analysis_value
	WHERE analysis_value.analysis_id IN
		(SELECT * FROM analysis_ids_tmp)
	;
	
	DROP TEMPORARY TABLE IF EXISTS values_analysis_positions;
	CREATE TEMPORARY TABLE values_analysis_positions ENGINE=MEMORY AS
	SELECT DISTINCT 
		per_position_value.value_type_id AS value_type_id
	FROM per_position_value
	WHERE per_position_value.analysis_id IN
		(SELECT * FROM analysis_ids_tmp)
	;
	
	DROP TEMPORARY TABLE IF EXISTS values_analysis_partitions;
	CREATE TEMPORARY TABLE values_analysis_partitions ENGINE=MEMORY AS
	SELECT DISTINCT 
		per_partition_value.value_type_id AS value_type_id
	FROM per_partition_value
	WHERE per_partition_value.analysis_id IN
		(SELECT * FROM analysis_ids_tmp)
	;
	
	DROP TEMPORARY TABLE IF EXISTS values_out;
	CREATE TEMPORARY TABLE values_out ENGINE=MEMORY AS
	SELECT 
		value_type_id,
		"analysis_value" AS data_type
	FROM values_analysis_values
	UNION ALL
	SELECT
		value_type_id,
		"per_position_value" AS data_type
	FROM values_analysis_positions
	UNION ALL
	SELECT
		value_type_id,
		"per_partition_value" AS data_type
	FROM values_analysis_partitions
	;
	
	SELECT 
		vt.description AS description,
		ts.scope AS scope,
		vo.data_type AS data_type
	FROM values_out AS vo
	INNER JOIN value_type AS vt 
		ON vt.id = vo.value_type_id
	INNER JOIN type_scope AS ts
		ON ts.id = vt.type_scope_id
	;
END$$

DROP PROCEDURE IF EXISTS list_contaminants$$
CREATE PROCEDURE list_contaminants(
	IN instrument_in VARCHAR(500),
	IN run_in VARCHAR(500),
	IN lane_in VARCHAR(500))
BEGIN
	CALL get_analysis_id_as_temp_table(
		instrument_in,
		run_in,
		lane_in,
		NULL,NULL,NULL,NULL)
	;
	
	SELECT value
    FROM statsdb.analysis_property
	WHERE analysis_id IN(
		SELECT analysis_id 
		FROM analysis_property
		WHERE property = 'tool'
		AND value like 'KMER_CONTAMINATION%')
	AND analysis_id IN
		(SELECT * FROM analysis_ids_tmp)
	AND property = 'reference'
	;
	DROP TEMPORARY TABLE IF EXISTS analysis_ids_tmp;
END$$

DROP PROCEDURE IF EXISTS contaminant_summary$$
CREATE PROCEDURE contaminant_summary(
	IN contaminant_in VARCHAR(500),
	IN instrument_in VARCHAR(500),
	IN run_in VARCHAR(500),
	IN lane_in VARCHAR(500))
BEGIN
	CALL get_analysis_id_as_temp_table(
		instrument_in,
		run_in,
		lane_in,
		NULL,NULL,NULL,NULL)
	;
	
	DROP TEMPORARY TABLE IF EXISTS analysis_ids_contaminants_tmp;
	CREATE TEMPORARY TABLE analysis_ids_contaminants_tmp ENGINE=INNODB AS
	SELECT DISTINCT analysis_id 
	FROM statsdb.analysis_property
	WHERE analysis_id IN(
		SELECT analysis_id 
		FROM analysis_property
		WHERE property = 'tool'
		AND value like 'KMER_CONTAMINATION%')
	AND analysis_id IN
		(SELECT * FROM analysis_ids_tmp)
	AND analysis_id IN
		(SELECT analysis_id
		FROM analysis_property
		WHERE property = 'reference'
		AND value = contaminant_in)
	;
	
	SELECT 
		av.value AS value,
		vt.description AS value_type
	FROM analysis_value AS av
	INNER JOIN value_type AS vt
		ON av.value_type_id = vt.id
	WHERE av.analysis_id IN(
		SELECT * FROM analysis_ids_contaminants_tmp)
	;
	DROP TEMPORARY TABLE IF EXISTS analysis_ids_tmp;
	DROP TEMPORARY TABLE IF EXISTS analysis_ids_contaminants_tmp;
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
	IN date2 TIMESTAMP,
	IN date_type VARCHAR(500))
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

DROP PROCEDURE IF EXISTS get_dates_for_run$$
CREATE PROCEDURE get_dates_for_run(
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
    
	SELECT DISTINCT
		property as property,
		date as date
	FROM analysis_date
	WHERE analysis_date.analysis_id IN
		(SELECT * FROM analysis_ids_tmp)
	;
	DROP TEMPORARY TABLE IF EXISTS analysis_ids_tmp;
END$$

DROP PROCEDURE IF EXISTS operation_overview$$
CREATE PROCEDURE operation_overview(
	IN date1 TIMESTAMP,
	IN date2 TIMESTAMP)
BEGIN
	DROP TEMPORARY TABLE IF EXISTS rundates_tmp;
	CREATE TEMPORARY TABLE rundates_tmp ENGINE=INNODB AS
	SELECT DISTINCT
		--pr.analysis_id as analysis,
		d.property as date_type,
		d.date as date,
		pr.value AS instrument,
		gr.value AS run,
		lr.value AS lane,
		pp.value AS pair
	FROM analysis_date AS d
	INNER JOIN analysis_property AS pr ON d.analysis_id = pr.analysis_id 
		AND pr.property = 'instrument'
	INNER JOIN analysis_property AS gr ON d.analysis_id = gr.analysis_id 
		AND gr.property = 'run'
	INNER JOIN analysis_property AS lr ON d.analysis_id = lr.analysis_id 
		AND lr.property = 'lane'
	INNER JOIN analysis_property AS pp ON d.analysis_id = pp.analysis_id 
		AND pp.property = 'pair'
	WHERE 
		date BETWEEN date1 AND date2
	;
	
	SELECT date_type, date, instrument, run, lane, pair
	FROM rundates_tmp
	ORDER BY instrument, run, lane, pair, date_type DESC
	;
	
	DROP TEMPORARY TABLE IF EXISTS rundates_tmp;
END$$

DROP PROCEDURE IF EXISTS get_lib_type_for_run$$
CREATE PROCEDURE get_lib_type_for_run(
	IN run_in VARCHAR(500))
BEGIN
	CALL get_analysis_id_as_temp_table(
		NULL,
		run_in,
		NULL,NULL,NULL,NULL,NULL)
	;
	
	SELECT DISTINCT
	value as library_type
	FROM analysis_property
	WHERE property = ''
	AND analysis_id IN (SELECT * FROM analysis_ids_tmp)
	;
	
	DROP TEMPORARY TABLE IF EXISTS analysis_ids_tmp;
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
END$$

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
		value_type, analysis_value, type_scope
	WHERE
		type_scope.scope = "analysis"
		AND type_scope.id=value_type.type_scope_id 
		AND value_type.id = analysis_value.value_type_id
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
--	;
--	
--	IF EXISTS (
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
--	END IF;get_analysis_id

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
get_ids:BEGIN
	DROP TEMPORARY TABLE IF EXISTS an_ids_tmp1;
	CREATE TEMPORARY TABLE an_ids_tmp1 ENGINE=INNODB AS
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
	
	-- If @duplicate_selection indicates to retrieve all matching IDs,
	-- then we need go no further this time.
	IF @duplicate_selection = 'all' 
	THEN
		SELECT analysis_id
		FROM an_ids_tmp1;
		LEAVE get_ids;
	END IF;
	
	-- Pull in other identifying info for the run IDs
	DROP TEMPORARY TABLE IF EXISTS an_ids_tmp2;
	CREATE TEMPORARY TABLE an_ids_tmp2 ENGINE=INNODB AS
	SELECT DISTINCT
		tmp.analysis_id as analysis_id,
		d.analysisDate as date,
		ins.value AS instrument,
		rn.value AS run,
		ln.value AS lane,
		pr.value AS pair,
		sn.value AS sample_name,
		bc.value AS barcode,
		tl.value AS tool,
		ref.value AS screening_reference,
		ist.value AS interop_subtype
	FROM an_ids_tmp1 AS tmp
	INNER JOIN analysis AS d 
		ON tmp.analysis_id = d.id
	INNER JOIN analysis_property AS ins 
		ON tmp.analysis_id = ins.analysis_id 
		AND ins.property = 'instrument'
	INNER JOIN analysis_property AS rn 
		ON tmp.analysis_id = rn.analysis_id 
		AND rn.property = 'run'
	INNER JOIN analysis_property AS ln 
		ON tmp.analysis_id = ln.analysis_id 
		AND ln.property = 'lane'
	INNER JOIN analysis_property AS pr 
		ON tmp.analysis_id = pr.analysis_id 
		AND pr.property = 'pair'
	INNER JOIN analysis_property AS sn 
		ON tmp.analysis_id = sn.analysis_id 
		AND sn.property = 'sample_name'
	INNER JOIN analysis_property AS bc 
		ON tmp.analysis_id = bc.analysis_id 
		AND bc.property = 'barcode'
	INNER JOIN analysis_property AS tl 
		ON tmp.analysis_id = tl.analysis_id 
		AND tl.property = 'tool'
	LEFT JOIN analysis_property AS ref 
		ON tmp.analysis_id = ref.analysis_id 
		AND ref.property = 'reference'
	LEFT JOIN analysis_property AS ist 
		ON tmp.analysis_id = ist.analysis_id 
		AND ist.property = 'interop_subtype'
	;
	
	-- Get the groupwise most recent dates and their respective records
	-- Then find all records in that set to get the correct IDs.
	
	DROP TEMPORARY TABLE IF EXISTS an_ids_tmp3;
	CREATE TEMPORARY TABLE an_ids_tmp3 ENGINE=MEMORY AS
	SELECT 
		instrument,
		run,
		lane,
		pair,
		sample_name,
		barcode,
		tool,
		screening_reference,
		interop_subtype,
		MAX(date) AS maxdate
	FROM an_ids_tmp2
	GROUP BY 
		instrument,
		run,
		lane,
		pair,
		sample_name,
		barcode,
		tool,
		screening_reference,
		interop_subtype
	;
	
	-- List all the most recent pertinent analysis IDs 
	DROP TEMPORARY TABLE IF EXISTS an_ids_tmp4;
	CREATE TEMPORARY TABLE an_ids_tmp4 ENGINE=MEMORY AS
	SELECT i.analysis_id
	FROM an_ids_tmp2 AS i
	INNER JOIN an_ids_tmp3 AS j
		ON i.instrument = j.instrument
		AND i.run = j.run
		AND i.lane = j.lane
		AND i.pair = j.pair
		AND i.sample_name = j.sample_name
		AND i.barcode = j.barcode
		AND i.tool = j.tool
		AND (i.screening_reference = j.screening_reference
			OR (i.screening_reference IS NULL AND j.screening_reference IS NULL))
		AND (i.interop_subtype = j.interop_subtype
			OR (i.interop_subtype IS NULL AND j.interop_subtype IS NULL))
		AND i.date = j.maxdate
	;
	
	-- Note that if conditions make retrieval of most recent IDs the
	-- default setting here
	IF @duplicate_selection = 'old' 
	THEN
		SELECT analysis_id
		FROM an_ids_tmp2
		WHERE analysis_id NOT IN (
			SELECT analysis_id
			FROM an_ids_tmp4)
        LEAVE get_ids;
		;
	END IF;
    
    SELECT analysis_id
	FROM an_ids_tmp4;

	DROP TEMPORARY TABLE IF EXISTS an_ids_tmp1;
	DROP TEMPORARY TABLE IF EXISTS an_ids_tmp2;
	DROP TEMPORARY TABLE IF EXISTS an_ids_tmp3;
	DROP TEMPORARY TABLE IF EXISTS an_ids_tmp4;
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
get_ids:BEGIN
--	This creates a temporary table in memory holding a set of analysis_ids,
--	in order to work around MySQL's inability to use the output of
--	stored procedures inside other stored procedures.
	DROP TEMPORARY TABLE IF EXISTS an_ids_tmp1;
	CREATE TEMPORARY TABLE an_ids_tmp1 ENGINE=MEMORY AS
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
	
	-- If @duplicate_selection indicates to retrieve all matching IDs,
	-- then we need go no further this time.
	IF @duplicate_selection = 'all' 
	THEN
		DROP TEMPORARY TABLE IF EXISTS analysis_ids_tmp;
		CREATE TEMPORARY TABLE analysis_ids_tmp ENGINE=MEMORY AS
		SELECT analysis_id
		FROM an_ids_tmp1;
		LEAVE get_ids;
	END IF;
	
	-- Pull in other identifying info for the run IDs
	DROP TEMPORARY TABLE IF EXISTS an_ids_tmp2;
	CREATE TEMPORARY TABLE an_ids_tmp2 ENGINE=INNODB AS
	SELECT DISTINCT
		tmp.analysis_id as analysis_id,
		d.analysisDate as date,
		ins.value AS instrument,
		rn.value AS run,
		ln.value AS lane,
		pr.value AS pair,
		sn.value AS sample_name,
		bc.value AS barcode,
		tl.value AS tool,
		ref.value AS screening_reference,
		ist.value AS interop_subtype
	FROM an_ids_tmp1 AS tmp
	INNER JOIN analysis AS d 
		ON tmp.analysis_id = d.id
	INNER JOIN analysis_property AS ins 
		ON tmp.analysis_id = ins.analysis_id 
		AND ins.property = 'instrument'
	INNER JOIN analysis_property AS rn 
		ON tmp.analysis_id = rn.analysis_id 
		AND rn.property = 'run'
	INNER JOIN analysis_property AS ln 
		ON tmp.analysis_id = ln.analysis_id 
		AND ln.property = 'lane'
	INNER JOIN analysis_property AS pr 
		ON tmp.analysis_id = pr.analysis_id 
		AND pr.property = 'pair'
	INNER JOIN analysis_property AS sn 
		ON tmp.analysis_id = sn.analysis_id 
		AND sn.property = 'sample_name'
	INNER JOIN analysis_property AS bc 
		ON tmp.analysis_id = bc.analysis_id 
		AND bc.property = 'barcode'
	INNER JOIN analysis_property AS tl 
		ON tmp.analysis_id = tl.analysis_id 
		AND tl.property = 'tool'
	LEFT JOIN analysis_property AS ref 
		ON tmp.analysis_id = ref.analysis_id 
		AND ref.property = 'reference'
	LEFT JOIN analysis_property AS ist 
		ON tmp.analysis_id = ist.analysis_id 
		AND ist.property = 'interop_subtype'
	;
	
	-- Get the groupwise most recent dates and their respective records
	-- Then find all records in that set to get the correct IDs.
	
	DROP TEMPORARY TABLE IF EXISTS an_ids_tmp3;
	CREATE TEMPORARY TABLE an_ids_tmp3 ENGINE=MEMORY AS
	SELECT 
		instrument,
		run,
		lane,
		pair,
		sample_name,
		barcode,
		tool,
		screening_reference,
		interop_subtype,
		MAX(date) AS maxdate
	FROM an_ids_tmp2
	GROUP BY 
		instrument,
		run,
		lane,
		pair,
		sample_name,
		barcode,
		tool,
		screening_reference,
		interop_subtype
	;
	
	-- List all the most recent pertinent analysis IDs 
	DROP TEMPORARY TABLE IF EXISTS an_ids_tmp4;
	CREATE TEMPORARY TABLE an_ids_tmp4 ENGINE=MEMORY AS
	SELECT i.analysis_id
	FROM an_ids_tmp2 AS i
	INNER JOIN an_ids_tmp3 AS j
		ON i.instrument = j.instrument
		AND i.run = j.run
		AND i.lane = j.lane
		AND i.pair = j.pair
		AND i.sample_name = j.sample_name
		AND i.barcode = j.barcode
		AND i.tool = j.tool
		AND (i.screening_reference = j.screening_reference
			OR (i.screening_reference IS NULL AND j.screening_reference IS NULL))
		AND (i.interop_subtype = j.interop_subtype
			OR (i.interop_subtype IS NULL AND j.interop_subtype IS NULL))
		AND i.date = j.maxdate
	;
	
	-- Note that 'if' conditions make retrieval of most recent IDs the
	-- default setting here
	IF @duplicate_selection = 'old' 
	THEN
		DROP TEMPORARY TABLE IF EXISTS analysis_ids_tmp;
		CREATE TEMPORARY TABLE analysis_ids_tmp ENGINE=MEMORY AS
		SELECT analysis_id
		FROM an_ids_tmp2
		WHERE analysis_id NOT IN (
			SELECT analysis_id
			FROM an_ids_tmp4)
		;
        LEAVE get_ids;
	END IF;
    
    DROP TEMPORARY TABLE IF EXISTS analysis_ids_tmp;
    CREATE TEMPORARY TABLE analysis_ids_tmp ENGINE=MEMORY AS
    SELECT analysis_id
    FROM an_ids_tmp4;

	DROP TEMPORARY TABLE IF EXISTS an_ids_tmp1;
	DROP TEMPORARY TABLE IF EXISTS an_ids_tmp2;
	DROP TEMPORARY TABLE IF EXISTS an_ids_tmp3;
	DROP TEMPORARY TABLE IF EXISTS an_ids_tmp4;
END$$

DROP PROCEDURE IF EXISTS set_duplicate_selection_type$$
CREATE PROCEDURE set_duplicate_selection_type(
	IN type_in VARCHAR(3))
BEGIN
	SET @duplicate_selection = type_in;
END$$

DROP PROCEDURE IF EXISTS detect_duplicates$$
CREATE PROCEDURE detect_duplicates(
	IN instrument_in VARCHAR(500),
	IN run_in VARCHAR(500),
	IN lane_in VARCHAR(500),
	IN pair_in VARCHAR(500),
	IN sample_name_in VARCHAR(500),
	IN barcode_in VARCHAR(500),
	IN tool_in VARCHAR(500))
get_ids:BEGIN
	DROP TEMPORARY TABLE IF EXISTS an_ids_tmp1;
	CREATE TEMPORARY TABLE an_ids_tmp1 ENGINE=MEMORY AS
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
	
	-- Pull in other identifying info for the run IDs
	DROP TEMPORARY TABLE IF EXISTS an_ids_tmp2;
	CREATE TEMPORARY TABLE an_ids_tmp2 ENGINE=INNODB AS
	SELECT DISTINCT
		tmp.analysis_id as analysis_id,
		d.analysisDate as date,
		ins.value AS instrument,
		rn.value AS run,
		ln.value AS lane,
		pr.value AS pair,
		sn.value AS sample_name,
		bc.value AS barcode,
		tl.value AS tool,
		ref.value AS screening_reference,
		ist.value AS interop_subtype
	FROM an_ids_tmp1 AS tmp
	INNER JOIN analysis AS d 
		ON tmp.analysis_id = d.id
	INNER JOIN analysis_property AS ins 
		ON tmp.analysis_id = ins.analysis_id 
		AND ins.property = 'instrument'
	INNER JOIN analysis_property AS rn 
		ON tmp.analysis_id = rn.analysis_id 
		AND rn.property = 'run'
	INNER JOIN analysis_property AS ln 
		ON tmp.analysis_id = ln.analysis_id 
		AND ln.property = 'lane'
	INNER JOIN analysis_property AS pr 
		ON tmp.analysis_id = pr.analysis_id 
		AND pr.property = 'pair'
	INNER JOIN analysis_property AS sn 
		ON tmp.analysis_id = sn.analysis_id 
		AND sn.property = 'sample_name'
	INNER JOIN analysis_property AS bc 
		ON tmp.analysis_id = bc.analysis_id 
		AND bc.property = 'barcode'
	INNER JOIN analysis_property AS tl 
		ON tmp.analysis_id = tl.analysis_id 
		AND tl.property = 'tool'
	LEFT JOIN analysis_property AS ref 
		ON tmp.analysis_id = ref.analysis_id 
		AND ref.property = 'reference'
	LEFT JOIN analysis_property AS ist 
		ON tmp.analysis_id = ist.analysis_id 
		AND ist.property = 'interop_subtype'
	;
	
	-- If @duplicate_selection indicates to retrieve all matching IDs,
	-- then we need go no further this time.
	IF @duplicate_selection = 'all' 
	THEN
		SELECT
			analysis_id,
			date,
			tool,
			instrument,
			run,
			lane,
			pair,
			sample_name,
			barcode,
			screening_reference,
			interop_subtype
		FROM an_ids_tmp2
		ORDER BY 
			analysis_id,
			tool,
			instrument,
			run,
			lane,
			pair,
			sample_name,
			barcode,
			screening_reference,
			interop_subtype
		;
		LEAVE get_ids;
	END IF;
	
	-- Get the groupwise most recent dates and their respective records
	-- Then find all records that AREN'T in that set; these are the older
	-- duplicates.
	
	DROP TEMPORARY TABLE IF EXISTS an_ids_tmp3;
	CREATE TEMPORARY TABLE an_ids_tmp3 ENGINE=MEMORY AS
	SELECT 
		instrument,
		run,
		lane,
		pair,
		sample_name,
		barcode,
		tool,
		screening_reference,
		interop_subtype,
		MAX(date) AS maxdate
	FROM an_ids_tmp2
	GROUP BY 
		instrument,
		run,
		lane,
		pair,
		sample_name,
		barcode,
		tool,
		screening_reference,
		interop_subtype
	;
	
	-- This table (4) should contain all the analysis IDs for the records
	-- picked out in 3. 
	DROP TEMPORARY TABLE IF EXISTS an_ids_tmp4;
	CREATE TEMPORARY TABLE an_ids_tmp4 ENGINE=MEMORY AS
	SELECT i.analysis_id
	FROM an_ids_tmp2 AS i
	INNER JOIN an_ids_tmp3 AS j
		ON i.instrument = j.instrument
		AND i.run = j.run
		AND i.lane = j.lane
		AND i.pair = j.pair
		AND i.sample_name = j.sample_name
		AND i.barcode = j.barcode
		AND i.tool = j.tool
		AND (i.screening_reference = j.screening_reference
			OR (i.screening_reference IS NULL AND j.screening_reference IS NULL))
		AND (i.interop_subtype = j.interop_subtype
			OR (i.interop_subtype IS NULL AND j.interop_subtype IS NULL))
		AND i.date = j.maxdate
	;
	
	-- Output everything of relevance
	-- Note that if conditions make retrieval of most recent IDs the
	-- default setting here
	IF @duplicate_selection = 'new' 
	THEN
		SELECT 
			analysis_id,
			date,
			tool,
			instrument,
			run,
			lane,
			pair,
			sample_name,
			barcode,
			screening_reference,
			interop_subtype
		FROM an_ids_tmp2
		WHERE analysis_id IN (
			SELECT analysis_id
			FROM an_ids_tmp4)
		ORDER BY 
			analysis_id,
			tool,
			instrument,
			run,
			lane,
			pair,
			sample_name,
			barcode,
			screening_reference,
			interop_subtype
		;
	ELSE
		SELECT 
			analysis_id,
			date,
			tool,
			instrument,
			run,
			lane,
			pair,
			sample_name,
			barcode,
			screening_reference,
			interop_subtype
		FROM an_ids_tmp2
		WHERE analysis_id NOT IN (
			SELECT analysis_id
			FROM an_ids_tmp4)
		ORDER BY 
			analysis_id,
			tool,
			instrument,
			run,
			lane,
			pair,
			sample_name,
			barcode,
			screening_reference,
			interop_subtype
		;
	END IF;
	
	DROP TEMPORARY TABLE IF EXISTS an_ids_tmp1;
	DROP TEMPORARY TABLE IF EXISTS an_ids_tmp2;
	DROP TEMPORARY TABLE IF EXISTS an_ids_tmp3;
	DROP TEMPORARY TABLE IF EXISTS an_ids_tmp4;
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

DROP PROCEDURE IF EXISTS count_reads_for_run$$
CREATE PROCEDURE count_reads_for_run(
	IN run_in VARCHAR(500))
BEGIN
	-- The idea is to get the number of reads for all subdivisions
	-- of a run here, cutting down the number of queries required.
	CALL get_analysis_id_as_temp_table(
		NULL,
		run_in,
		NULL,NULL,NULL,NULL,NULL)
	;
	
	SELECT 
		av.value AS numreads,
		ln.value AS lane,
		pr.value AS pair,
		sn.value AS sample_name,
		bc.value AS barcode
	FROM analysis_value AS av
	INNER JOIN analysis_property AS ln 
		ON av.analysis_id = ln.analysis_id 
		AND ln.property = 'lane'
	INNER JOIN analysis_property AS pr 
		ON av.analysis_id = pr.analysis_id 
		AND pr.property = 'pair'
	INNER JOIN analysis_property AS sn 
		ON av.analysis_id = sn.analysis_id 
		AND sn.property = 'sample_name'
	INNER JOIN analysis_property AS bc 
		ON av.analysis_id = bc.analysis_id 
		AND bc.property = 'barcode'
	WHERE av.analysis_id IN (SELECT * FROM analysis_ids_tmp)
	AND av.value_type_id IN (
		SELECT id
		FROM value_type
		WHERE description = 'general_total_sequences')
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
		CASE WHEN barcode_in IS NOT NULL THEN barcode END AS barcode,
		tool as tool
		FROM subdivisions_tmp_2
		ORDER BY instrument, run, lane, pair, sample_name, barcode
		;
	END IF;
	DROP TEMPORARY TABLE IF EXISTS analysis_ids_tmp;
	DROP TEMPORARY TABLE subdivisions_tmp;
	DROP TEMPORARY TABLE subdivisions_tmp_2;
END$$

DROP PROCEDURE IF EXISTS analysis_values_for_run$$
CREATE PROCEDURE analysis_values_for_run(
	IN instrument_in VARCHAR(500),
	IN run_in VARCHAR(500),
	IN lane_in VARCHAR(500),
	IN pair_in VARCHAR(500),
	IN sample_name_in VARCHAR(500),
	IN barcode_in VARCHAR(500),
	IN tool_in VARCHAR(500))
BEGIN
	-- Idea with this is to make some nice, fast queries that get
	-- ALL analysis values for a given query set
	CALL get_analysis_id_as_temp_table(
		instrument_in,
		run_in,
		lane_in,
		pair_in,
		sample_name_in,
		barcode_in,
		tool_in)
	;
	
	DROP TEMPORARY TABLE IF EXISTS picked_properties;
	CREATE TEMPORARY TABLE picked_properties ENGINE=INNODB AS
	SELECT DISTINCT
		tmp.analysis_id as analysis_id,
		ins.value AS instrument,
		rn.value AS run,
		ln.value AS lane,
		pr.value AS pair,
		sn.value AS sample_name,
		bc.value AS barcode,
		tl.value AS tool
	FROM analysis_ids_tmp AS tmp
	INNER JOIN analysis AS d 
		ON tmp.analysis_id = d.id
	INNER JOIN analysis_property AS ins 
		ON tmp.analysis_id = ins.analysis_id 
		AND ins.property = 'instrument'
	INNER JOIN analysis_property AS rn 
		ON tmp.analysis_id = rn.analysis_id 
		AND rn.property = 'run'
	INNER JOIN analysis_property AS ln 
		ON tmp.analysis_id = ln.analysis_id 
		AND ln.property = 'lane'
	INNER JOIN analysis_property AS pr 
		ON tmp.analysis_id = pr.analysis_id 
		AND pr.property = 'pair'
	INNER JOIN analysis_property AS sn 
		ON tmp.analysis_id = sn.analysis_id 
		AND sn.property = 'sample_name'
	INNER JOIN analysis_property AS bc 
		ON tmp.analysis_id = bc.analysis_id 
		AND bc.property = 'barcode'
	INNER JOIN analysis_property AS tl 
		ON tmp.analysis_id = tl.analysis_id 
		AND tl.property = 'tool'
	;
	
	DROP TEMPORARY TABLE IF EXISTS analysis_data;
	CREATE TEMPORARY TABLE analysis_data ENGINE=INNODB AS
	SELECT * 
	FROM analysis_value
	WHERE analysis_id IN (SELECT * FROM analysis_ids_tmp)
	;
	
	SELECT
		pos.value,
		vt.description AS description,
		pp.instrument AS instrument,
		pp.run AS run,
		pp.lane AS lane,
		pp.pair AS pair,
		pp.sample_name AS sample_name,
		pp.barcode AS barcode,
		pp.tool AS tool
	FROM analysis_data AS pos
	INNER JOIN value_type AS vt 
		ON pos.value_type_id = vt.id
	INNER JOIN picked_properties AS pp
		ON pos.analysis_id = pp.analysis_id
	;
END$$

DROP PROCEDURE IF EXISTS position_values_for_run$$
CREATE PROCEDURE position_values_for_run(
	IN instrument_in VARCHAR(500),
	IN run_in VARCHAR(500),
	IN lane_in VARCHAR(500),
	IN pair_in VARCHAR(500),
	IN sample_name_in VARCHAR(500),
	IN barcode_in VARCHAR(500),
	IN tool_in VARCHAR(500))
BEGIN
	-- Idea with this is to make some nice, fast queries that get
	-- ALL position values for a given query set
	CALL get_analysis_id_as_temp_table(
		instrument_in,
		run_in,
		lane_in,
		pair_in,
		sample_name_in,
		barcode_in,
		tool_in)
	;
	
	DROP TEMPORARY TABLE IF EXISTS picked_properties;
	CREATE TEMPORARY TABLE picked_properties ENGINE=INNODB AS
	SELECT DISTINCT
		tmp.analysis_id as analysis_id,
		ins.value AS instrument,
		rn.value AS run,
		ln.value AS lane,
		pr.value AS pair,
		sn.value AS sample_name,
		bc.value AS barcode,
		tl.value AS tool
	FROM analysis_ids_tmp AS tmp
	INNER JOIN analysis AS d 
		ON tmp.analysis_id = d.id
	INNER JOIN analysis_property AS ins 
		ON tmp.analysis_id = ins.analysis_id 
		AND ins.property = 'instrument'
	INNER JOIN analysis_property AS rn 
		ON tmp.analysis_id = rn.analysis_id 
		AND rn.property = 'run'
	INNER JOIN analysis_property AS ln 
		ON tmp.analysis_id = ln.analysis_id 
		AND ln.property = 'lane'
	INNER JOIN analysis_property AS pr 
		ON tmp.analysis_id = pr.analysis_id 
		AND pr.property = 'pair'
	INNER JOIN analysis_property AS sn 
		ON tmp.analysis_id = sn.analysis_id 
		AND sn.property = 'sample_name'
	INNER JOIN analysis_property AS bc 
		ON tmp.analysis_id = bc.analysis_id 
		AND bc.property = 'barcode'
	INNER JOIN analysis_property AS tl 
		ON tmp.analysis_id = tl.analysis_id 
		AND tl.property = 'tool'
	;
	
	DROP TEMPORARY TABLE IF EXISTS position_data;
	CREATE TEMPORARY TABLE position_data ENGINE=INNODB AS
	SELECT * 
	FROM per_position_value
	WHERE analysis_id IN (SELECT * FROM analysis_ids_tmp)
	;
	
	SELECT
		pos.position,
		pos.value,
		vt.description AS description,
		pp.instrument AS instrument,
		pp.run AS run,
		pp.lane AS lane,
		pp.pair AS pair,
		pp.sample_name AS sample_name,
		pp.barcode AS barcode,
		pp.tool AS tool
	FROM position_data AS pos
	INNER JOIN value_type AS vt 
		ON pos.value_type_id = vt.id
	INNER JOIN picked_properties AS pp
		ON pos.analysis_id = pp.analysis_id
	;
END$$

DROP PROCEDURE IF EXISTS partition_values_for_run$$
CREATE PROCEDURE partition_values_for_run(
	IN instrument_in VARCHAR(500),
	IN run_in VARCHAR(500),
	IN lane_in VARCHAR(500),
	IN pair_in VARCHAR(500),
	IN sample_name_in VARCHAR(500),
	IN barcode_in VARCHAR(500),
	IN tool_in VARCHAR(500))
BEGIN
	-- Idea with this is to make some nice, fast queries that get
	-- ALL partition values for a given query set
	CALL get_analysis_id_as_temp_table(
		instrument_in,
		run_in,
		lane_in,
		pair_in,
		sample_name_in,
		barcode_in,
		tool_in)
	;
	
	DROP TEMPORARY TABLE IF EXISTS picked_properties;
	CREATE TEMPORARY TABLE picked_properties ENGINE=INNODB AS
	SELECT DISTINCT
		tmp.analysis_id as analysis_id,
		ins.value AS instrument,
		rn.value AS run,
		ln.value AS lane,
		pr.value AS pair,
		sn.value AS sample_name,
		bc.value AS barcode,
		tl.value AS tool
	FROM analysis_ids_tmp AS tmp
	INNER JOIN analysis AS d 
		ON tmp.analysis_id = d.id
	INNER JOIN analysis_property AS ins 
		ON tmp.analysis_id = ins.analysis_id 
		AND ins.property = 'instrument'
	INNER JOIN analysis_property AS rn 
		ON tmp.analysis_id = rn.analysis_id 
		AND rn.property = 'run'
	INNER JOIN analysis_property AS ln 
		ON tmp.analysis_id = ln.analysis_id 
		AND ln.property = 'lane'
	INNER JOIN analysis_property AS pr 
		ON tmp.analysis_id = pr.analysis_id 
		AND pr.property = 'pair'
	INNER JOIN analysis_property AS sn 
		ON tmp.analysis_id = sn.analysis_id 
		AND sn.property = 'sample_name'
	INNER JOIN analysis_property AS bc 
		ON tmp.analysis_id = bc.analysis_id 
		AND bc.property = 'barcode'
	INNER JOIN analysis_property AS tl 
		ON tmp.analysis_id = tl.analysis_id 
		AND tl.property = 'tool'
	;
	
	DROP TEMPORARY TABLE IF EXISTS partition_data;
	CREATE TEMPORARY TABLE partition_data ENGINE=INNODB AS
	SELECT * 
	FROM per_partition_value
	WHERE analysis_id IN (SELECT * FROM analysis_ids_tmp)
	;
	
	SELECT
		pos.position,
		pos.size,
		pos.value,
		vt.description AS description,
		pp.instrument AS instrument,
		pp.run AS run,
		pp.lane AS lane,
		pp.pair AS pair,
		pp.sample_name AS sample_name,
		pp.barcode AS barcode,
		pp.tool AS tool
	FROM partition_data AS pos
	INNER JOIN value_type AS vt 
		ON pos.value_type_id = vt.id
	INNER JOIN picked_properties AS pp
		ON pos.analysis_id = pp.analysis_id
	;
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
