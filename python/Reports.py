#package Reports;
#use strict;

#use Reports::ReportTable;
import MySQLdb, Reports_ReportTable, read_file, add_parameters
import os
class Reports:
	
	db_con=""
	dbc=""
		
	def __init__(self, config_file):
		try:
			fh= open(config_file)
		except IOError as err:
			print "Cannot open the file : ", config_file
			print err
			exit(1)
		
		firstline=fh.readline().strip().split("\t")[1].split(";")
		self.dbhost=firstline[1].split("=")[1]
		self.dbname=firstline[0].split(":")[2]
		self.dbuser=fh.readline().strip().split("\t")[1]
		self.password=fh.readline().strip().split("\t")[1]
		
		fh.close()

		self.db_con = MySQLdb.connect(self.dbhost, self.dbuser, self.password, self.dbname)
		print "Connected to Database"
		self.dbc=self.db_con.cursor()
	
	def execute_and_return(self, statement):
		print "Statement to be executed : ", statement
		self.dbc.execute(statement);
		#desc=self.dbc.description; rows=self.dbc.fetchall()
		#print desc, rows
		obj=Reports_ReportTable.ReportTable()
		return obj.New(self.dbc)
	
	def disconnect(self):
		self.db_con.close()

	def display_table(self, tablename, args=[]):
		if len(args)==0:
			statement="select * from " + tablename
		else:
			arguments=",".join(args)
			statement="select " + arguments + " from " + tablename
		
		obtained=self.execute_and_return(statement)
		return obtained

	def show_tables(self):
		return self.execute_and_return("show tables")
	def describe_table(self, tablename):
		return self.execute_and_return("describe " + tablename)

	def list_global_analyses(self, value):
		statement = "CALL list_summary_per_scope(\"%s\")" %(value)
		return self.execute_and_return(statement)
		
	
		
	def get_per_position_summary(self, analysis, analysis_property, analysis_property_value):
		statement = "CALL summary_per_position(\"%s\",\"%s\",%d)" % (analysis, analysis_property, int(analysis_property_value))
		return self.execute_and_return(statement)
		
	def get_average_value(self, args):
		statement = "CALL general_summary(\"%s\",\"%s\",%d)" %(args[0], args[1], int(args[2]))
		return self.execute_and_return(statement)
		
	def get_average_values(self, args):
		print "Inside get_average_values", "Option provided :", args 
		
		statement = "CALL general_summaries_for_run(\"%s\",\"%s\",%d, %d,\"%s\")" %(args[0],args[1], int(args[2]), int(args[3]),args[4])
		return self.execute_and_return(statement)
		
	def get_per_position_values(self, args):
		statement = "CALL summary_per_position_for_run(\"%s\",\"%s\",\"%s\",%d, %d,\"%s\")" %(args[0], args[1], args[2], int(args[3]), int(args[4]), args[5])
		return self.execute_and_return(statement)
	
	def get_summary_values_with_comments(self, args):
		statement = "CALL summary_value_with_comment(\"%s\", \"%s\",\"%s\",%d, %d,\"%s\")" %(args[0],args[1], args[2], int(args[3]), int(args[4]),args[5])
		return self.execute_and_return(statement)
	
	def get_summary_values(self, args):
		statement = "CALL summary_value(\"%s\", \"%s\",\"%s\",%d, %d,\"%s\")" %(args[0],args[1], args[2], int(args[3]), int(args[4]),args[5])
		return self.execute_and_return(statement)

	def get_analysis_properties(self):
		statement = "CALL list_selectable_properties()"
		return self.execute_and_return(statement)
		
	def get_values_for_property(self, objproperty):
		statement = "CALL list_selectable_values_from_property(\"%s\")" % objproperty
		return self.execute_and_return(statement)
	
	def list_all_runs_for_instrument(self, instrument):
		statement = "SELECT run FROM run WHERE instrument = \"%s\" GROUP BY run" %(instrument)
		return self.execute_and_return(statement)
	
	def list_all_instruments(self):
		statement = "SELECT instrument FROM run GROUP BY instrument"
		return self.execute_and_return(statement)

	def list_all_runs(self):
		statement = "SELECT run FROM run GROUP BY run"
		return self.execute_and_return(statement)
	
	def list_lanes_for_run(self, run):
		statement = "SELECT lane FROM run WHERE run = \"%s\" GROUP BY lane" % run
		return self.execute_and_return(statement)
	
	def list_subdivisions(self, properties):
		# Assemble a query to get all the available runs, lanes on a run etc. when passed
		# a given set of information. Generalist by design.
		# Get inputs via a hash. Assemble query internally.
		args=[]
		if properties['INSTRUMENT']: args.append(properties['INSTRUMENT'])
		if properties['RUN']: args.append(properties['RUN'])
		if properties['LANE']: args.append(properties['LANE'])
		if properties['PAIR']: args.append(properties['PAIR'])
		if properties['BARCODE']: args.append(properties['BARCODE'])
		if properties['SCOPE']: args.append(properties['SCOPE'])
 		
		statement = "CALL summary_value(\"%s\",\"%s\",%d, %d,\"%s\",\"%s\")" %(args[0],args[1], int(args[2]), int(args[3]) ,args[4],args[5])
		
		# Add bits to the statement to reflect available information
		# GROUP BY column supplied as queryscope (plus higher-level scopes)
  
		available_columns = ('instrument','run','lane','sample_name','barcode','pair')
		retrieve_these = []
		col = []
		
		if args[6]:
			for column in available_columns:
				col.append(column)
				if col == args[6]: break
			# Ensure that if 'sample_name' is in @available_columns,
			# 'barcode' is as well
			# (vice versa ensured by @available_columns order!)
			jn = ' '.join(retrieve_these)
			if "sample_name" in jn and "barcode" not in jn:
				retrieve_these.append("barcode")
		else:
			if args[0]: retrieve_these.append('instrument')
			if args[1]: retrieve_these('run')
			if args[2]: retrieve_these('lane')
			if args[4] or args[5]:
				retrieve_these.append('sample_name')
				retrieve_these.append('barcode')
			
			if args[3]: retrieve_these.append('pair')
		
			col = ' '.join(retrieve_these)
		
		where_components = []
		query_values = []
		
		if args["INSTRUMENT"]:
			where_components.append('instrument = \"%s\" ' % args["INSTRUMENT"])
			query_values.append(args["INSTRUMENT"])
		if args["RUN"]:
			where_components.append('run = \"%s\" ' % args["RUN"])
			query_values.append(args["RUN"])
		if args["LANE"]:
			where_components.append('lane = %d ' % args["LANE"])
			query_values.append(args["LANE"])
		if args["PAIR"]:
			where_components.append('pair = %d ' % args["PAIR"])
			query_values.append(args["PAIR"])
		if args["SAMPLE_NAME"]:
			where_components.append('sample_name = \"%s\" ' % args["SAMPLE_NAME"])
			query_values.append(args["SAMPLE_NAME"])
		if args["BARCODE"]:
			where_components.append('barcode = \"%s\" ' % args["BARCODE"])
			query_values.append(args["BARCODE"])
		
		statement = 'SELECT ' + col + ' FROM run '
		
		if where_components:
			where_string = 'AND'.join(where_components)
			where_string = 'WHERE ' + where_string
			statement = statement +  where_string
		statement = statement + " GROUP BY " + col + " ORDER BY " + col
  		return self.execute_and_return(statement)
	
	def list_barcodes_for_run_and_lane(self, args):
		statement = "SELECT barcode FROM run WHERE run = \"%s\" AND lane = %d GROUP BY barcode" % (args[0], args[1])
		return self.execute_and_return(statement)
		
	def get_samples_from_run_lane_barcode(self, args):
		
		statement = "SELECT sample_name FROM run WHERE run = \"%s\" AND lane = %d AND barcode = \"%s\"" %(args[0], args[1], args[2])
		return self.execute_and_return(statement)
	
	def get_analysis_id(self,options):
		selections=""; where_clause=""
		if options["INSTRUMENT"]:
			firstpart, secondpart = add_parameters.selections_conditions("INSTRUMENT", options["INSTRUMENT"], selections); selections="," + firstpart; where_clause+=" and " +secondpart
		if options["PAIR"]:
			firstpart, secondpart = add_parameters.selections_conditions("PAIR", options["PAIR"], selections); selections="," + firstpart; where_clause+=" and " +secondpart
		if options["LANE"]:
			firstpart, secondpart = add_parameters.selections_conditions("LANE", options["LANE"], selections); selections="," + firstpart; where_clause+=" and " +secondpart
		if options["BARCODE"]:
			if os.path.exists(options["BARCODE"]):
				list_of_barcodes=read_file.read_file(options["BARCODE"])
			else:
				list_of_barcodes=options["BARCODE"]
			firstpart, secondpart = add_parameters.selections_conditions("BARCODE", list_of_barcodes, selections); selections="," + firstpart; where_clause+=" and " +secondpart
		if options["SAMPLE_NAME"]:
			if os.path.exists(options["SAMPLE_NAME"]):
				list_of_samplenames=read_file.read_file(options["SAMPLE_NAME"])
			else:
				list_of_samplenames=options["SAMPLE_NAME"]
			firstpart, secondpart = add_parameters.selections_conditions("SAMPLE_NAME", list_of_samplenames, selections); selections="," + firstpart; where_clause+=" and " +secondpart
		statement =  "SELECT analysis_id FROM run WHERE " + where_clause[5:]

		
		statement = statement + " GROUP BY analysis_id"
		return self.execute_and_return(statement)

	def get_properties_for_analysis_ids(self, idref):
		# Add bits to the statement to reflect available information
		statement = "SELECT property, value FROM analysis_property "
		where_components = []
		for each in idref.split(","):
			where_components.append("analysis_property.id = \"%s\" " % each)
		
		if len(where_components) > 0:
			where_string = ' OR '.join(where_components)
			where_string = "WHERE " + where_string
			statement =  statement + where_string
		statement = statement + "GROUP BY property, value ORDER BY property, value"
		return self.execute_and_return(statement)
  		
	# These two take care of barcode/sample name interchange.
	# Note that sample names are (or should be) unique, so no further
	# information need be supplied; barcodes, however, are not, so
	# run ID should also be passed.

	def get_barcodes_for_sample_name(self, statement):
		#statement = "SELECT barcode FROM run WHERE sample_name = \"%s\" GROUP BY barcode" %sample
		return self.execute_and_return(statement)

	def get_sample_name_for_barcode(self, statement ):
		#statement = "SELECT sample_name FROM run WHERE barcode = \"%s\" GROUP BY barcode" %(barcode)
		return self.execute_and_return(statement)
	
	def fromdate_todate(self, fromdate, todate):
		if " " not in fromdate: fromdate=fromdate + " 00:00:00"
		if " " not in todate: todate=todate + " 23:59:59"

		statement="SELECT id, analysisDate, tool, chemistry, instrument, software, type, pair, sample_name, lane, run from analysis, run where analysisDate>=\"" + fromdate + "\" and analysisDate<=\"" + todate + "\""
		return self.execute_and_return(statement)

	def fromdate(self, fromdate):
		if " " not in fromdate: fromdate=fromdate + " 00:00:00"
		statement="SELECT id, analysisDate, tool, chemistry, instrument, software, type, pair, sample_name, lane, run from analysis, run where analysisDate>=\"" + fromdate + "\""+ "and id=run.analysis_id group by run"
		return self.execute_and_return(statement)
	
	def todate(self, todate):
		if " " not in todate: todate=todate + " 23:59:59"
		statement="SELECT id, analysisDate, tool, chemistry, instrument, software, type, pair, sample_name, lane, run from analysis, run where analysisDate<=\""  + todate + "\""+ "and id=run.analysis_id group by run"
		return self.execute_and_return(statement)

	def get_from_date(self, mydate):
		if " " not in mydate:
			fromdate=mydate + " 00:00:00"
			todate=mydate + " 23:59:59"
			statement="SELECT id, analysisDate, tool, chemistry, instrument, software, type, pair, sample_name, lane, run from analysis, run where analysisDate>=\"" + fromdate + "\" and analysisDate<=\"" + todate + "\""+ "and id=run.analysis_id group by run"
		else:
			statement="SELECT id, analysisDate, tool, chemistry, instrument, software, type, pair, sample_name, lane, run from analysis, run where analysisDate=\"" + mydate + "\"" + "and id=run.analysis_id group by run"

		return self.execute_and_return(statement)

	def from_emtpy_statement(self, myemtpy_statement):
		return self.execute_and_return(myemtpy_statement)






