#!/usr/bin/python
import sys
import GetOption

if len(sys.argv)==1:
	#from prettytable import PrettyTable

	print "usage: python scriptname -option1 value -option2 value -option3 value ... .. ... .."
	print "Examples:"
	print "python api_statsdb.py -from_analysisdate 2013-00-00 -to_analysisdate 2014-00-00"
#	print "python api_statsdb.py -run
	
	exit(0)
	


columns_in_db_tables={
		'analysis':{'columns':['id','analysisdate']},

		#'analysis_property': {'columns':['id', 'property', 'value', 'analysis_id'],'fk':['analysis_id'], 'reference': {'analysis_id':'analysis.id'}},

		'type_scope': {'columns':['id', 'scope']},

		'value_type': {'columns':['id', 'type_scope_id', 'description', 'comment'], 'fk':['type_scope_id'], 'reference':{'type_scope_id':'type_scope.id'}},

		'per_partition_value': {'columns':['id', 'analysis_id', 'position', 'size', 'value', 'value_type_id'], 'fk': ['analysis_id', 'value_type_id'], 'reference': {'analysis_id':'analysis.id', 'value_type_id': 'value_type.id'}},

		'per_position_value': {'columns':['id', 'analysis_id', ' position', 'value', 'value_type_id'], 'fk': ['analysis_id', 'value_type_id'], 'reference': {'analysis_id':'analysis.id', 'value_type_id':'value_type.id'}},

		'analysis_value': {'columns':['id', 'value', 'analysis_id' , 'value_type_id'], 'fk':['analysis_id', 'value_type_id'], 'reference': {'analysis_id':'analysis.id', 'value_type_id': 'value_type.id'}},
		
		'run':{'columns':['analysis_id', 'tool', 'encoding', 'casava', 'chemistry', 'instrument', 'software', 'type', 'pair', 'sample_name', 'lane', 'run', 'barcode'], 'fk':['analysis_id'], 'reference':{'analysis_id':'analysis.id'}}
		
}


scopes={'analysis_value': ['general_min_length', 'general_total_sequences', 'general_gc_content', 'general_max_length', 'general_filtered_sequences', 'total_duplicate_percentage', 'ref_kmer_percent', 'contaminated_reads', 'percentage', 'sample_size_ratio', 'sampled_reads'],
	
	'per_position_value':['quality_score_count', 'duplication_level_relative_count'],

	'per_partition_value': ['quality_mean', 'quality_median', 'quality_lower_quartile', 'quality_upper_quartile', 'quality_10th_percentile', 'quality_90th_percentile', 'base_content_a', 'base_content_c', 'base_content_g', 'base_content_t', 'gc_content_percentage', 'gc_content_count', 'sequence_length_count']
}

scopes_and_value_type_in_db={
	
	'value_type': {'description': scopes['analysis_value'] + scopes['per_partition_value'] + scopes['per_position_value']}
}

#description=['quality_score_count', 'duplication_level_relative_count']

def get_scope_table_for_option(scope):
	for scopetable in scopes.keys():
		for thisscope in scopes[scopetable]:
			if scope==thisscope:
				return scopetable

def strip_of_ands(cmd):
	return cmd.lower().strip(" and ")

def check_scope_value_type(option):
	found=False
	for scope_value_table in scopes_and_value_type_in_db.keys():
		for column in scopes_and_value_type_in_db[scope_value_table].keys():
			for scope in scopes_and_value_type_in_db[scope_value_table][column]:			
				if option == scope:
					return True
	return False
	


def find_tables_for_option(option_array):
	tables=set()
	
	for option in option_array:
		found=False
		for tablename in columns_in_db_tables.keys():
			for column in columns_in_db_tables[tablename]['columns']:
				if column in option:
					tables.add(tablename)
					found=True
		if found==False:
			#find it in scope or value type
			for key in scopes_and_value_type_in_db.keys():
				for column in scopes_and_value_type_in_db[key].keys():
					for scope in scopes_and_value_type_in_db[key][column]:					
						if option == scope:
							tables.add(key)
	

	
	if len(tables)==0:
		return False
	else:
		return tables
	
				
def get_tablename_for_option(option):
	found=False
	for tablename in columns_in_db_tables.keys():
		for column in columns_in_db_tables[tablename]['columns']:
			if column.lower() in option.lower():
				return tablename
	if found==False:
		for scope_value_table in scopes_and_value_type_in_db.keys():
			for column in scopes_and_value_type_in_db[scope_value_table].keys():
				for scope in scopes_and_value_type_in_db[scope_value_table][column]:			
					if option == scope:
						return scope_value_table

	return False

def get_column_for_option(option):
	found=False
	for tablename in columns_in_db_tables.keys():
		for column in columns_in_db_tables[tablename]['columns']:
			if column.lower() in option.lower():
				return column
	if found==False:
		for scope_value_table in scopes_and_value_type_in_db.keys():
			for column in scopes_and_value_type_in_db[scope_value_table].keys():
				for scope in scopes_and_value_type_in_db[scope_value_table][column]:					
					if option.lower() == scope.lower():
						return column

	return False



def check_fk_in_table(tablename):
	if 'fk' in columns_in_db_tables[tablename].keys():
		return True
	else:
		return False

def check_pk_in_table_to_other_table(tablename):
	
	for column in columns_in_db_tables[tablename]['columns']:
		for table in columns_in_db_tables.keys():
			if 'reference' in columns_in_db_tables[table].keys():
				for key in columns_in_db_tables[table]['reference'].keys():
					value=columns_in_db_tables[table]['reference'][key]
					value_array=value.split(".")
					if value_array[0]==tablename and value_array[1]==column:
						return True
	return False

def get_tables_with_fk_for_this_table(tablename):
	tables_with_fk=[]
	for column in columns_in_db_tables[tablename]['columns']:
		for table in columns_in_db_tables.keys():
			if 'reference' in columns_in_db_tables[table].keys():
				for key in columns_in_db_tables[table]['reference'].keys():
					value=columns_in_db_tables[table]['reference'][key]
					value_array=value.split(".")
					if value_array[0]==tablename and value_array[1]==column:
						tables_with_fk.append(table)
	return tables_with_fk

def get_table_fk_columns(tablename):
	return columns_in_db_tables[tablename]['fk']	#return array of fk columns

def get_pk_tables_for_fk(tablename):
	tables=[]
	
	if check_fk_in_table(tablename):
		for fk in columns_in_db_tables[tablename]['reference'].values():
			tables.append(fk.split(".")[0])
					
	
	return tables


def select_everything_from_table(table):
	selection=''
	for column in columns_in_db_tables[table]['columns']:
		selection+=table+'.' +column + ','
	
	return selection.strip(',')

	


def analyse_options(opt, arg):
	options_passed.append(opt[1:])
	tablename=get_tablename_for_option(opt[1:]); print "Table returned:", tablename, "for opt: ", opt
	columnname=get_column_for_option(opt[1:]); print "column returned:", columnname, "for opt:", opt
	columns_used.append(columnname)
	#if run_name=='': sql_cmd_selection+=select_everything_from_table(tablename)
	#else:
	sql_cmd_selection="";sql_cmd_condition=""
	
	sql_cmd_selection+=tablename + "." + columnname
	if arg=='': sql_cmd_condition=""
	
	elif len(arg.split(','))>1:
		arg_array=arg.split(',')
		tmp=''
		for element in arg_array:
			try:
				if int(element) or float(element):
					tmp+=tablename + "." + columnname + '=' + element + ' and '
			except ValueError as ve:
				tmp+=tablename + "." + columnname + '=' + element + ' or '

		if tmp.endswith(' and '): tmp=tmp[:-5]
		elif tmp.endswith(' or '): tmp=tmp[:-4]
		
		tmp='(' +tmp + ')'
		sql_cmd_condition+=tmp
	else:
		if check_scope_value_type(opt[1:]):
			
			sql_cmd_condition=" and " + tablename + "." + columnname + "=\"" + opt[1:] + "\""
		else:
			try:
				int(arg) or float(arg)
				sql_cmd_condition= " and " + tablename + "." + opt[1:] + "=" + arg
			except:
				sql_cmd_condition= " and " + tablename + "." + opt[1:] + "=\"" + arg + "\""
	
					

	return sql_cmd_selection, sql_cmd_condition


	
	
	
	
options_passed=[]
columns_used=[]
build_sql_cmd=""

sql_cmd_condition=""; sql_cmd_tables=""; sql_cmd_selection=""

condition_supplied=False; position_supplied=False



option_list=['h','help', 'from_analysisdate=', 'to_analysisdate=', 'analysisdate=', 'run:', 'tool:','encoding:', 'instrument:', 'type:','pair:','sample_name:', 'lane:', 'barcode:', 'quality_mean:', 'base_content_c:', 'quality_lower_quartile:', 'quality_upper_quartile:', 'base_content_n_percentage:', 'gc_content_count:', 'base_content_g:', 'base_content_c', 'base_content_t', 'quality_median:', 'base_content_a:', 'sequence_length_count:', 'gc_content_percentage:', 'general_min_length:', 'general_total_sequences:', 'base_content_t:', 'general_filtered_sequences:', 'general_max_length:', 'quality_10th_percentile:', 'quality_90th_percentile', 'position:',  'quality_score_count:', 'duplication_level_relative_count:', 'general_gc_content:', 'general_max_length:', 'general_filtered_sequences:', 'total_duplicate_percentage:', 'ref_kmer_percent:', 'contaminated_reads:', 'percentage:', 'sample_size_ratio:', 'sampled_reads:', 'position:', 'size:' ]

user_option_list=GetOption.GetOption_list(sys.argv[1:], option_list)

for opt, arg in user_option_list:
	#print opt, arg
	if opt in ['-h', '-help']:
		usage()
		exit(0)
	elif opt in ['-from_analysisdate']:
		start_date="\"" + arg + "\""
		options_passed.append(opt[1:])
		sql_cmd_selection+=" analysisDate,"
		sql_cmd_condition+=" and analysis.analysisDate >= " + start_date

	elif opt in ['-to_analysisdate']:
		end_date="\"" + arg + "\""
		try:
			start_date
		except NameError as ne:
			print "End date provide without start date"
			exit(1)
		
		options_passed.append(opt[1:])
		sql_cmd_selection+=" analysisDate,"
		sql_cmd_condition+=" AND analysis.analysisDate <= " + end_date
	elif opt in ['-analysisdate']:
		end_date=arg
		options_passed.append(opt[1:])
		sql_cmd_selection+='analysis.analysisDate'
		sql_cmd_condition+='analysis.analysisDate=' + '"' + arg + "\""
	elif opt in ['-run']:
		analyse_options(opt, arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)
		sql_cmd_selection+=opt_sql_cmd_selection + ","; sql_cmd_condition+=opt_sql_cmd_condition
	elif opt in ['-tool']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)	
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
	elif opt in ['-instrument']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)	
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
	elif opt in ['-encoding']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
	elif opt in ['-type']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
	elif opt in ['-pair']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
	elif opt in ['-sample_name']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
	elif opt in ['-lane']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
	elif opt in ['-barcode']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
	elif opt in ['-quality_mean']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
	elif opt in ['-base_content_t']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
	elif opt in ['-base_content_a']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
	elif opt in ['-base_content_g']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
	elif opt in ['-base_content_c']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
	elif opt in ['-quality_lower_quartile']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
	elif opt in ['-quality_upper_quartile']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
	elif opt in ['-base_content_n_percentage']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
	elif opt in ['-gc_content_count']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
	elif opt in ['-quality_median']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
	elif opt in ['-quality_mean']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
	elif opt in ['-sequence_length_count']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
	elif opt in ['-gc_content_percentage']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
	elif opt in ['-general_min_length']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
	elif opt in ['-general_total_sequences']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
	elif opt in ['-general_gc_content']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
	elif opt in ['-general_filtered_sequences']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
	elif opt in ['-general_max_length']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
	elif opt in ['-quality_10th_percentile']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
	elif opt in ['-duplication_level_relative_count']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
	elif opt in ['-quality_90th_percentile']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
	
	elif opt in ['-total_duplicate_percentage']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
	elif opt in ['-quality_score_count']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
	elif opt in ['-contaminated_reads']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
	
	elif opt in ['-ref_kmer_percent']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
	elif opt in ['-sampled_reads']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
	elif opt in ['-percentage']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
	elif opt in ['-sample_size_ratio']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
	elif opt in ['-total_duplicate_percentage']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
	elif opt in ['-ref_kmer_percent']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
	elif opt in ['-gc_content_percentage']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
	elif opt in ['-gc_content_count']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
	elif opt in ['-base_content_n_percentage']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
	elif opt in ['-position']:
		analyse_options(opt,arg)
		opt_sql_cmd_selection, opt_sql_cmd_condition = analyse_options(opt,arg)
		sql_cmd_selection+=opt_sql_cmd_selection+ ","; sql_cmd_condition+=opt_sql_cmd_condition
		position_supplied=True
 
	else:
		print 'Unknown option: ' + opt + ' found'
		exit(1)

#print columns_in_db_tables

#print options_passed

tables_for_options=find_tables_for_option(options_passed)
if tables_for_options==False: print "Could not process. Please use as many options as you require. That will give you exact output as you require"; exit(1)



def check_fk_in_obtained_tables(fkeys, option_tables):
	
	table_set=set()
	
	
	for this_table in option_tables:
		#print "checking in table ", this_table
		if check_fk_in_table(this_table):
			for this_fk in columns_in_db_tables[this_table]['fk']:
				#print "fk column found ", this_fk;
				if fkeys == this_fk:
					table_set.add(this_table)
	
	return table_set

def get_relationship(fk_table, pk_table):
	for akey in columns_in_db_tables[fk_table]['reference'].keys():
		value=columns_in_db_tables[fk_table]['reference'][akey]
		if value.split('.')[0] in pk_tables:
			print "point 3: ", value + "=" + fk_table + "." + akey
			return value + "=" + fk_table + "." + akey
		

def get_relation_between_selected_tables(tables):
	
	relation_array=set()
	for atable in tables:
		if check_fk_in_table(atable):
			
			#check if fk of one table is also within another table in the collected table list
			fk_column=get_table_fk_columns(atable)
			print "fk_columns ", fk_column
			for fkey in fk_column:
				table_set=check_fk_in_obtained_tables(fkey, pk_tables)
				for table_with_fk in table_set:
					sql_cmd_condition=atable + "." + fkey + "=" + table_with_fk + "." + fkey
				
					sql_cmd_condition_array=sql_cmd_condition.split("=")
					if not sql_cmd_condition_array[0]==sql_cmd_condition_array[1]:
						relation_array.add(sql_cmd_condition)
					else:
						print "not adding ", sql_cmd_condition

			for fk_table in get_pk_tables_for_fk(atable):
				print fk_table
				if fk_table in tables:
					
					relation_array.add(get_relationship(atable, fk_table))	#(run, analysis)
		
					
					
	return ' and '.join(relation_array)				


def get_relation_between_selected_tables1(tables):
	relation_array=set()
	for atable in tables:
		if check_fk_in_table(atable):
			#check if fk of one table is also within another table in the collected table list
			for key in columns_in_db_tables[atable]['reference'].keys():
				
				relation_array.add(atable + "." + key + "=" + columns_in_db_tables[atable]['reference'][key])
				
		else:
			# check if it has primary key for another table
			for column in columns_in_db_tables[atable]:
				for key in columns_in_db_tables.keys():
					if 'reference' in columns_in_db_tables[key].keys():
						for ref in columns_in_db_tables[key]['reference'].keys():
							if atable+"."+column == columns_in_db_tables[key]['reference'][ref]:
								relation_array.add(atable+"."+column + "=" + columns_in_db_tables[key]['reference'][ref])
						
					
					
	return ' and '.join(relation_array)


print "Tables found: ", tables_for_options

pk_tables=set(tables_for_options)

options_passed=set(options_passed)

def remove_table_with_no_option_passed(options_passed, tables):
	new_tables=set()
	for atable in tables:
		for columns in columns_in_db_tables[atable]["columns"]:
			if columns in options_passed:
				new_tables.add(atable)
	
	return new_tables
		
def tables_enough(columns_used, tables_for_options):
	columns_used=set(columns_used)
	options=set()
	for an_option in columns_used:
		print "checking option ", an_option
		for table in tables_for_options:
			if an_option in columns_in_db_tables[table]["columns"]:
				options.add(an_option)


	if options==columns_used:
		return True
	else:
		return False



def get_scope_table(scope):
	for table in scopes.keys():
		for db_scope in scopes[key]:
			if db_scope == scope:
				return table

print tables_for_options, options_passed
if 'value_type' in tables_for_options:
	
	print "yes value_type present"
	for option in options_passed:
		print "finding for ", option
		option_table=get_tablename_for_option(option)
		print option_table
		if option_table=='value_type':
			
			scope_table=get_scope_table_for_option(option)
			sql_cmd_condition = sql_cmd_condition.strip().strip("and") +  " and value_type.description=\"" + option + "\" "
			print "scope table found ", scope_table			
			break
		
			


	if scope_table=='analysis_value': pk_tables.add('analysis_value');sql_cmd_selection+="analysis_value.value"
	elif scope_table=='per_partition_value': pk_tables.add('per_partition_value'); sql_cmd_selection+=scope_table + ".position, "  + scope_table + ".size, " + scope_table + ".value " 
	elif scope_table=='per_position_value': pk_tables.add('per_position_value'); sql_cmd_selection+=scope_table + ".position, "  + scope_table + ".value "



for this_table in tables_for_options:	
	if check_fk_in_table(this_table):
		#this_fk_column=get_table_fk_columns(this_table)
		#tables_with_fk_columns=check_fk_in_obtained_tables(this_fk_column, tables_for_options)

		for  fk_table in get_pk_tables_for_fk(this_table):
			print "point 2 ", fk_table, "added"
			pk_tables.add(fk_table)



#pk_tables=remove_table_with_no_option_passed(options_passed, pk_tables)

sql_cmd_tables+=', '.join(pk_tables)

table_relations = get_relation_between_selected_tables(pk_tables)
sql_cmd_condition+= " and " + table_relations

sql_cmd_condition=sql_cmd_condition.strip()

if sql_cmd_condition.startswith("and"): sql_cmd_condition=sql_cmd_condition[3:]
if sql_cmd_condition.endswith("and"): sql_cmd_condition=sql_cmd_condition[:-3]
print "All tables: ", sql_cmd_tables

sql_cmd_condition=sql_cmd_condition.strip()

build_sql_cmd = 'select ' + sql_cmd_selection.strip().strip(',') + ' from ' + sql_cmd_tables.strip().strip(",") + ' where ' + sql_cmd_condition

print build_sql_cmd




def db_connect_and_execute(cmd):
	import MySQLdb
	#connect to databases
	print "connecting to the database"
	try:
		db_handle=MySQLdb.connect("n78048.nbi.ac.uk", "statsdb", "st4t5D8", "statsdb")
	except:
		print "Unable to connect to the database. Please check the database name, username and password."
		exit(1)
	#prepare a cursor object using cursor() method
	cursor=db_handle.cursor()
	#execute SQL query using execute() method
	print "Executing the sql command"
	cursor.execute(cmd)
	print "Fetching the data from database"
	data_records=cursor.fetchall()
	db_handle.close()

	return data_records


data_records=db_connect_and_execute(build_sql_cmd)

def remove_duplicate_record(data_records):
	unique_records={}
	for record in data_records:
		if record in unique_records.keys():
			unique_records[record]+=1
		else:
			unique_records[record]=1
	
	return unique_records.keys()


def copy_and_display_record_to_csv(data_records):
	csvfile=open("data_records.csv", "w")
	count=0
	for record in data_records:
		
		each_record=""
		each_tab_record=""
		for elements in record:
			elements=str(elements)
			elements=elements.rstrip()
			each_record+=elements + ","; each_tab_record+=elements + "\t"
		
		each_record=each_record.rstrip(","); 

		csvfile.write(each_record + "\n"); print each_tab_record.strip()
		count+=1
	csvfile.close()
	sys.stderr.write("Total records: " + str(count) + "\n")


data_records=remove_duplicate_record(data_records)

copy_and_display_record_to_csv(data_records)


exit()





















