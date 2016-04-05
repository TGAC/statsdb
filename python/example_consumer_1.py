#!/usr/bin/env python
import os,sys, optparse, argparse, read_file, add_parameters

#sys.path.append(sys.path.abspath(sys.argv[0]))

DESCRIPTION="This is a program developed for StatsDB users to retrieve the data from the database with some common SQL query."


USAGE="Some examples of the commands\n\
python$ python example_consumer.py --show_tables\n\
python example_consumer.py --display_table analysis [ or any other table name (see the name of tables from above command)]\n\
python %prog --db_config examples/template_db.txt --get_average_values --instrument M01242 --run \"130726_M01242_0028_000000000-A4FE1\" --lane 1 --pair 1 --barcode \" \" --scope base_partition\n\
python %prog --db_config examples/template_db.txt --get_summary_values_with_comments --instrument M01242 --run \"130726_M01242_0028_000000000-A4FE1\" --lane 1 --pair 1 --barcode \" \" --scope analysis\n\
python %prog --db_config examples/template_db.txt --get_per_position_values --instrument M01242 --run \"130726_M01242_0028_000000000-A4FE1\" --lane 1 --pair 1 --barcode " " --analysis quality_mean\n\
python %prog --db_config examples/template_db.txt --list_all_runs_for_instrument M01242\n\
python %prog --db_config examples/template_db.txt --list_all_runs\n\
python %prog --db_config examples/template_db.txt --list_lanes_for_run --run 140704_SN790_0356_AC491LACXX\n\
python %prog --db_config examples/template_db.txt --list_barcodes_for_run_and_lane --run 140704_SN790_0356_AC491LACXX --lane 1\n\
python %prog --db_config examples/template_db.txt --get_samples_from_run_lane_barcode --run 130705_M01242_0025_000000000-A5AC4 --lane 1 --barcode AAGGATTCC\n\
python %prog --db_config examples/template_db.txt --get_analysis_id --run 130705_M01242_0025_000000000-A5AC4 --lane 1 --barcode AAGGATTCC --pair 1 --instrument M01242\n\
python %prog --db_config examples/template_db.txt --get_analysis_id --run 130705_M01242_0025_000000000-A5AC4\n\
python %prog --db_config examples/template_db.txt --get_properties_for_analysis_ids --analysis_ids 3,30\n\
python %prog --db_config examples/template_db.txt --list_global_analyses analysis\n\
python %prog --db_config examples/template_db.txt --list_global_analyses base_partition\n\
python example_consumer.py --db_config examples/template_db.txt --get_per_position_summary --analysis quality_mean --property lane --value 1\n\
\n\
ENJOY !!!"



#parser=optparse.OptionParser(description=DESCRIPTION, version="%prog version 1.0", usage=USAGE)
parser=argparse.ArgumentParser(formatter_class=argparse.RawDescriptionHelpFormatter, description=DESCRIPTION, prog='PROG', version="%(prog) version 1.0", epilog=USAGE, conflict_handler='resolve')


input_template=os.path.abspath(os.path.dirname(sys.argv[0])) + "/examples/template_db.txt"
parser.add_argument("--usage", action="store_true", default=False, help="Display the help message")
parser.add_argument("-c", "--db_config", dest="input", help="Input Database configuration file")
parser.add_argument("-r", "--run",  dest="RUN", help="Input RUN name e.g. HQTAXXRATZ")
parser.add_argument("-i", "--instrument",  dest="INSTRUMENT", help="Input instrument name e.g. HISEQ-1")
parser.add_argument("-l", "--lane",type=int, dest="LANE", help="Input lane number (usually 1 to 8)")
parser.add_argument("-p", "--pair",  type=int, dest="PAIR", help="Input pair number (usually either 1 or 2)")
parser.add_argument("-b", "--barcode", dest="BARCODE", help="Input barcode")
parser.add_argument("-s", "--samplename",   dest="SAMPLE_NAME", help="Input samplename")
parser.add_argument("-q", "--scope",   dest="SCOPE", help="Input SCOPE from scope table")
parser.add_argument("-d","--display_table",  dest="display_table", help="Display everything in the provide tablename")
parser.add_argument("-t","--show_tables",  default=False, help="Display all table name")
parser.add_argument("--analysis_ids",   dest="ids", help="list of comma separated analysis id numbers")
parser.add_argument("-a", "--analysis",  dest="analysis", help="provide description column from table - value_type")
parser.add_argument("--property",  dest="property", help="provide property column form table analysis_property")
parser.add_argument("--value",  dest="value", help="provide value column from table analysis_property.")
parser.add_argument("--from_analysisdate",  dest="from_date", help="Provide date from when you like to know the project runs")
parser.add_argument("--to_analysisdate", dest="to_date", help="Provide date to when you like to know the project runs")
parser.add_argument("--date",  dest="date", help="Provide the date of analysis")
parser.add_argument("--describe",  dest="describe", help="describes the table. Shows the columns in the table. Provide a table name")
parser.add_argument("-o","--outfile",  default="statsdb_out.txt", dest="output", help="provide the output filename [default: statsdb_out.txt]")
#parser.add_argument("--usage default=False, action="store_true", help="prints the command line usage of the program")


#parser=argparse.ArgumentGroup(parser, "StatsDB procedures options", "Options that calls stored procedures/function in StatsDB")
parser.add_argument("--list_global_analyses",  dest="list_global_analyses",  help="calls the procedure - list_summary_per_scope from table analysis; takes the value either analysis or base_partition")
parser.add_argument("--list_per_base_summary_analyses", action='store_true', default=False, help="calls the procedure - list_summary_per_scope from table base_partition")
parser.add_argument("--get_per_position_summary", action='store_true', default=False,help="calls the procedure - summary_per_position. Requirements : analysis, analysis_property, analysis_value")
parser.add_argument("--get_average_value", action='store_true', default=False,help="calls the procedure - general_summary. Requirements : analysis, analysis_property, analysis_property_value")
parser.add_argument("--get_average_values", action='store_true', default=False,help="calls the procedure - general_summary_for_run. Requirements : Instrument, Run, Lane, Pair, Barcode")
parser.add_argument("--get_per_position_values", action='store_true', default=False,help="calls the procedure - summary_per_position_for_run. Requirement : Instrument, Run, Lane, Pair, Barcode")
parser.add_argument("--get_summary_values_with_comments", action='store_true', default=False,help="calls the procedure - summary_value_with_comment. Requirements: Instrument, Run, Lane, Pair, Barcode")
parser.add_argument("--get_summary_values", action='store_true', default=False,help="calls the procedure - summary_value. Requirements : Instrument, Run, Lane, Pair, Barcode")
parser.add_argument("--get_analysis_properties", action='store_true', default=False,help="calls the procedure - list_selected_properties.")
parser.add_argument("--get_values_for_property", action='store_true', default=False,help="calls the procedure - list_selectable_values_from_property. Requirement : property")
parser.add_argument("--list_all_runs_for_instrument", action='store_true', dest="instrument_name", help="Lists all the runs for an instrument and grouped by run")
parser.add_argument("--list_all_instruments", action='store_true', default=False,help="lists all the instuments and grouped by instruments")
parser.add_argument("--list_all_runs", action='store_true', default=False,help="lists all the runs and groups by run")
parser.add_argument("--list_lanes_for_run", action='store_true', default=False,help= "list the lanes for a particular run and group by lane. Requirement : Run")
parser.add_argument("--list_subdivisions", action='store_true', default=False,help="calls the procedure summary_value. Requirements : Instrument, Run, Lane, Pair, Barcode, QSCOPE")
parser.add_argument("--list_barcodes_for_run_and_lane",  action='store_true', default=False,help="lists barcodes for a given run and lane. Requirement: Run and Lane")
parser.add_argument("--get_samples_from_run_lane_barcode", action='store_true', default=False,help="list samples from a given run, lane, barcode. Requirement: run, lane, barcode")
parser.add_argument("--get_analysis_id", action='store_true', default=False,help="lists the analysis_ids. Requirements :  Instrument, Run, Lane, Pair, Barcode, QSCOPE")
parser.add_argument("--get_properties_for_analysis_ids", action='store_true',default=False, help="Lists property and values")
parser.add_argument("--get_barcodes_for_sample_name", action='store_true', default=False,help="Lists barcodes for a given sample. Requirement : sample")
parser.add_argument("--get_sample_name_for_barcode", action='store_true', default=False,help="Lists barcodes for a given sample and run, groups by run and sample. Requirements : sample, run")


#print parser.parse_args()
options = parser.parse_args()   #gets the arguments and options
options=options.__dict__


#print "DB configuration: " + options['input']
if options['input']: config=options["input"]
else:
	config=input_template


def print_dict(mydict):
	for key in mydict.keys():
		if mydict[key]!=None:
			print key, mydict[key]


def print_help():
	print parser.print_help()
	exit(0)

		
#print_dict(options)
#print config

import Reports_DB, Reports, Reports_ReportTable

#db = Reports_DB.Report_DB()
#db_con=db.New(config)

reportTable=Reports_ReportTable.ReportTable()	#creating an object for reporting tables

def display_outputs(analyses):
	#print "analyses :", analyses
	if analyses==None: return None
	if not len(analyses)==0:
		print reportTable.to_csv(analyses)
		#print reportTable.to_json(analyses)
		if options["output"]:
			fh=open(os.path.abspath(options["output"]), "w")
			fh.write(reportTable.to_csv(analyses))
			fh.close()

def check_analysis_property_value():
	if not options["analysis"]: print "analysis option should be provided"; exit(0)
	if not options["property"]: print "property option should be provided"; exit(0)
	if not options["value"]: print "value option should be provided"; exit(0)


def check_missed(check_list):
	for one in check_list:
		print "check ", one, options[one]
		if not options[one]:
			return False
	return True

if options["display_table"]:
	reports = Reports.Reports(config);tables=reports.display_table(options["display_table"]); display_outputs(tables)
elif options["describe"]:
	reports = Reports.Reports(config);tables=reports.describe_table(options["describe"]); display_outputs(tables)
elif options["show_tables"]:
	reports = Reports.Reports(config);tables=reports.show_tables(); display_outputs(tables)
elif options["list_global_analyses"]:
	reports = Reports.Reports(config);tables=reports.list_global_analyses(options["list_global_analyses"]); display_outputs(tables)
elif options["list_per_base_summary_analyses"]:
	reports = Reports.Reports(config);tables=reports.list_per_base_summary_analyses(); display_outputs(tables)
elif options["get_per_position_summary"]:
	check_analysis_property_value()
	reports = Reports.Reports(config);tables=reports.get_per_position_summary(options["analysis"], options["property"], options["value"]); display_outputs(tables)
elif options["get_average_value"]:
	check_analysis_property_value()
	check_list=["analysis", "property", "value"]
	if check_missed(check_list):
		args=[]
		for each in check_list:
			args.append(options[each])
		reports = Reports.Reports(config);tables=reports.get_average_value(args); display_outputs(tables); reports.disconnect()
	else:
		print "You have not supplied one of the option parameter. Make sure you supplied parameters for all of these : ", ",".join(check_list)
		exit(1)

elif options["get_average_values"]:
	check_list=["INSTRUMENT", "RUN", "LANE", "PAIR", "BARCODE"]
	if check_missed(check_list):
		args=[]
		for each in check_list:
			args.append(options[each])
		reports = Reports.Reports(config);tables=reports.get_average_values(args); display_outputs(tables);
	else:
		print "You have not supplied one of the option parameter. Make sure you supplied parameters for all of these : ", ",".join(check_list)
		exit(1)

elif options["get_per_position_values"]:
	check_list=["analysis", "INSTRUMENT", "RUN", "LANE", "PAIR", "BARCODE"]
	if check_missed(check_list):
		args=[]
		for each in check_list:
			args.append(options[each])
		reports = Reports.Reports(config);tables=reports.get_per_position_values(args); display_outputs(tables)
	else:
		print "You have not supplied one of the option parameter. Make sure you supplied parameters for all of these : ", ",".join(check_list)
		exit(1)

elif options["get_summary_values_with_comments"]:
	check_list=["SCOPE", "INSTRUMENT", "RUN", "LANE", "PAIR", "BARCODE"]
	if check_missed(check_list):
		args=[]
		for each in check_list:
			args.append(options[each])
		reports = Reports.Reports(config);tables=reports.get_summary_values_with_comments(args); display_outputs(tables)
	else:
		print "You have not supplied one of the option parameter. Make sure you supplied parameters for all of these : ", ",".join(check_list)
		exit(1)

elif options["get_summary_values"]:
	check_list=["SCOPE", "INSTRUMENT", "RUN", "LANE", "PAIR", "BARCODE"]
	if check_missed(check_list):
		args=[]
		for each in check_list:
			args.append(options[each])
		reports = Reports.Reports(config);tables=reports.get_summary_values(args); display_outputs(tables)
	else:
		print "You have not supplied one of the option parameter. Make sure you supplied parameters for all of these : ", ",".join(check_list)
		exit(1)
	

elif options["get_analysis_properties"]:
	reports = Reports.Reports(config);tables=reports.get_analysis_properties(); display_outputs(tables)
	

elif options["instrument_name"]:	#pass instrument name e.g. M01242
	reports = Reports.Reports(config);tables=reports.list_all_runs_for_instrument(options["instrument_name"]); display_outputs(tables); reports.disconnect()
elif options["list_all_instruments"]:
	reports = Reports.Reports(config);tables=reports.list_all_instruments(); display_outputs(tables); reports.disconnect()
elif options["list_all_runs"]:
	reports = Reports.Reports(config);tables=reports.list_all_runs(); display_outputs(tables); reports.disconnect()
elif options["list_lanes_for_run"]:
	reports = Reports.Reports(config);tables=reports.list_lanes_for_run(options["RUN"]); display_outputs(tables); reports.disconnect()
elif options["list_subdivisions"]:
	reports = Reports.Reports(config);tables=reports.list_subdividision(options); display_outputs(tables); reports.disconnect()
elif options["list_barcodes_for_run_and_lane"]:
	check_list=["RUN", "LANE"]
	if check_missed(check_list):
		args=[]
		for each in check_list:
			args.append(options[each])
		reports = Reports.Reports(config);tables=reports.list_barcodes_for_run_and_lane(args); display_outputs(tables)
	else:
		print "You have not supplied one of the option parameter. Make sure you supplied parameters for all of these : ", ",".join(check_list)
		exit(1)
	
elif options["get_samples_from_run_lane_barcode"]:
	check_list=["RUN", "LANE", "BARCODE"]
	if check_missed(check_list):
		args=[]
		for each in check_list:
			args.append(options[each])
		reports = Reports.Reports(config);tables=reports.get_samples_from_run_lane_barcode(args); display_outputs(tables)
	else:
		print "You have not supplied one of the option parameter. Make sure you supplied parameters for all of these : ", ",".join(check_list)
		exit(1)
	
elif options["get_analysis_id"]:
	check_list=["INSTRUMENT", "RUN", "LANE", "PAIR", "SAMPLE_NAME", "BARCODE"]	#supply at least one or all of these options
	reports = Reports.Reports(config);tables=reports.get_analysis_id(options); display_outputs(tables)
	
	
elif options["get_properties_for_analysis_ids"]:
	if options["ids"]:
		if os.path.exists(options["ids"]):
			list_of_ids=read_file.read_file(options["ids"])
		else:
			list_of_ids=options["ids"]
		reports = Reports.Reports(config);tables=reports.get_properties_for_analysis_ids(list_of_ids); display_outputs(tables); reports.disconnect()
	else:
		print "Please provide a list of analysis ids which you wish to get the properties"
		exit(1)

elif options["get_barcodes_for_sample_name"]:
	if options["SAMPLE_NAME"]:
		if os.path.exists(options["SAMPLE_NAME"]):
			#read the file
			list_of_samplenames=read_file.read_file(options["SAMPLE_NAME"])
			selections, where_clause=add_parameters.selections_conditions("sample_name", list_of_samplenames, "")
		else:
			selections, where_clause=add_parameters.selections_conditions("sample_name", options["SAMPLE_NAME"], "")
		statement = "select distinct run.sample_name, run.barcode from run where " + where_clause + " group by barcode"
		reports = Reports.Reports(config);tables=reports.get_sample_name_for_barcode(statement); display_outputs(tables); reports.disconnect()
	else:
		print "Please provide a sample name to get the barcode for it"
		exit(1)

elif options["get_sample_name_for_barcode"]:
	if options["BARCODE"]:
		if os.path.exists(options["BARCODE"]):
			#read the file
			list_of_barcodes=read_file.read_file(options["BARCODE"])
			selections, where_clause=add_parameters.selections_conditions("barcode", list_of_barcodes, "")
		else:
			selections, where_clause=add_parameters.selections_conditions("barcode", options["BARCODE"], "")
		statement = "select distinct run.sample_name, run.barcode from run where " + where_clause + " group by barcode"
		reports = Reports.Reports(config);tables=reports.get_sample_name_for_barcode(statement); display_outputs(tables); reports.disconnect()
	else:
		print "Please provide barcode name to get the sample name"
		exit(1)

elif options["from_date"] and options["to_date"]:
	reports = Reports.Reports(config);tables=reports.fromdate_todate(options["from_date"], options["to_date"]); display_outputs(tables); reports.disconnect()
elif options["from_date"]:
	reports = Reports.Reports(config);tables=reports.fromdate(options["from_date"]); display_outputs(tables); reports.disconnect()
elif options["to_date"]:
	reports = Reports.Reports(config);tables=reports.todate(options["to_date"]); display_outputs(tables); reports.disconnect()
elif options["date"]:
	reports = Reports.Reports(config);tables=reports.get_from_date(options["date"]); display_outputs(tables); reports.disconnect()

elif len(sys.argv)==1:
	print parser.print_help()
elif options["RUN"] or options["INSTRUMENT"] or options["PAIR"] or options["LANE"] or options["BARCODE"] or options["SAMPLE_NAME"]:
	print "Configuring SQL statement with given options"
	empty_statement="";selections=""; where_clause=""
	if options["ids"]:
		if os.path.exists(options["ids"]):
			list_of_ids=read_file.read_file(options["ids"])
		else:
			list_of_ids=options["ids"]
		firstpart, secondpart = add_parameters.selections_conditions("analysis_id", list_of_ids, selections); selections= "," + firstpart; where_clause+=" and " + secondpart
	if options["RUN"]:
		firstpart, secondpart = add_parameters.selections_conditions("RUN", options["RUN"], selections); selections= "," + firstpart; where_clause+=" and " + secondpart
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
	
	empty_statement = "select analysis_id, run, instrument, sample_name, pair, lane, barcode from run where " + where_clause[5:]
	reports = Reports.Reports(config);tables=reports.from_emtpy_statement(empty_statement); display_outputs(tables); reports.disconnect()
	

elif options["--usage"]:
	print parser.print_help()

exit(0)
