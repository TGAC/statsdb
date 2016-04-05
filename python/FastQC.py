import os, sys, re

values={}

values["general_total_sequences"] = "analysis"
values["general_filtered_sequences"] = "analysis"
values["general_min_length"] = "analysis"
values["general_max_length"] = "analysis"
values["general_gc_content"] = "analysis"

values["quality_mean"] = "base_partition"
values["quality_median"] = "base_partition"
values["quality_lower_quartile"] = "base_partition"
values["quality_upper_quartile"] = "base_partition"
values["quality_10th_percentile"] = "base_partition"
values["quality_90th_percentile"] = "base_partition"

values["quality_score_count"] = "sequence_cumulative"


values["base_content_a"] = "base_partition"
values["base_content_c"] = "base_partition"
values["base_content_g"] = "base_partition"
values["base_content_t"] = "base_partition"

values["gc_content_percentage"] = "base_partition"
values["gc_content_count"] = "sequence_cumulative"

values["base_content_n_percentage"] = "base_partition"

values["sequence_length_count"] = "sequence_cumulative"
values["duplication_level_relative_count"] = "sequence_cumulative"

values["total_duplicate_percentage"] = "analysis"

value_keys={}
value_keys["Total Sequences"] = "general_total_sequences"
value_keys["Filtered Sequences"] = "general_filtered_sequences"
value_keys["\%GC"] = "general_gc_content"

header_keys={}
header_keys["%gc"] = "percentage"
header_keys["n-count"] = "n_percentage"

line_functions={}

line_functions["parse_overrepresented_sequences"] = 1
line_functions["parse_overrepresented_kmer"] = 1

header_keys["total duplicate percentage"] = "total_duplicate_percentage"

def parse_file(filename, analysis):
	print "Inside parse file : ", filename
	if os.path.exists(filename):
		fh = open(filename)
	else:
		print "Cannot open the file : ", filename
		exit(1)
	line=None
	module=None
	status=None
	
	
	
	for line in fh:
		line=line.rstrip()
		match=re.search(r'##FastQC\s+(\S*)', line)
		parse_function=""
		if match:
			analysis.add_property("FastQC", match.group(1))
			analysis.add_property("tool", "FastQC")
		elif re.search(r'>>(.*)\s(\S*)', line):
			match=re.search(r'>>(.*)\s(\S*)', line)
			module=match.group(1)
			status=match.group(2)
			module =match.replace(" ", "_").replace("\t", "_")

			parse_function = "parse_" + module
			if parse_function !="":
				globals()['parse_function'](fh, analysis)
			else:
				print "Warn: No function:  " +  parse_function + "\n"
	for key in values.keys():
		analysis.add_valid_type(key, values[key])

	
	return analysis


def parse_range(value):
	print "Inside parse_range"
	to_parse = value
	amin=None
	amax=None
	match=re.search(r'([0-9]+)-([0-9]+)/)', to_parse)
	if match:
		amin = match.group(1)
		amax = match.group(2)
	elif re.search(r'([0-9]+)', to_parse):
		match=re.search(r'([0-9]+)', to_parse)
		if match:
			amin=match.group(1)
			amax=match.group(1)
	else:
		amin=0; amax=0

#	print "Range parsed: min-max (from to_parse)\n"
	return (amin, amax)

def range_to_from_length(value):
	print "Inside range_to_from_length"
	arange = value
	(afrom, to) = parse_range(arange)
	length = abs(to - afrom)
	if (to < afrom):
		afrom = to

	return (afrom, length + 1)

def parse_Basic_Statistics(value1, value2):
	print "Inside parse_Basic_Statistics"
	fh = value1
	analysis = value2
	
    	to_parse=None
    	done = 0
	input=fh.readlines()
	for to_parse in input:
		to_parse=to_parse.rstrip()
		
		if to_parse.startswith("#"):
			print "it is a comment"
		elif re.search(r'([\S| ]+)\t([\S| ]+)', to_parse):
			match=re.search(r'([\S| ]+)\t([\S| ]+)', to_parse)
			if match.group(1)=="Sequence length":
				min, max=parse_range(match.group(2))
				analysis.add_general_value("general_min_length", min)
				analysis.add_general_value("general_max_length", max)
			elif value_keys[match.group(1)]:
				analysis.add_general_value(value_keys[match.group(1)], match.group(2))
			else:
				analysis.add_property(match.group(1), match.group(2))
		elif re.search(r'>>(.*)', to_parse):
			match1=re.search(r'>>(.*)', to_parse)
			if match1:
				if match1.group(1)=="END_MODULE":
					print "Misformated file !"
					exit(1)
			break;
		else:
			print to_parse



def parse_module(fh, analysis, prefix, function):
	print "Inside parse_module"
	done = 0
	to_parse=None
	header=[]
	
	inputfh=open(fh)
	
	for to_parse in inputfh:
		to_parse=to_parse.rstrip()
		
		if re.search(r'>>(.*)', to_parse):
			if not re.search(r'>>END_MODULE', to_parse):
				print "Misformated file!"
				exit(1)
			break
		elif to_parse.startswith("#"):
			to_parse=to_parse.lowercase()
			line=to_parse.split("\t")
			#print "Header line:to_parse \n"
			if len(line)==2 and header_keys[line[0]]:
				analysis.add_general_value(header_keys[line[0]], line[1])
			else:
				for i in range(len(line)):
					token=line[i]
					#print token + ":"
					token=token.replace(" ", "_")
					if header_keys[token]:
						token=header_keys[token]
					#print token + "\n"
					header[i] = prefix + "_" + token
		else:
			if line_functions[function]:
				function(analysis, to_parse)
			else:
				line=split("\t", to_parse)
				for i in range(len(line)):
					analysis.function(line[0], header[i], line[i])



def parse_partition(*argv):
	parse_module(argv[0], argv[1], argv[2],"add_partition_value" )


def parse_position(*argv):
	parse_module(argv[0], argv[1], argv[2], "add_position_value")

def parse_Per_base_GC_content(filename, analysis):
	parse_partition(filename, analysis, "quality")

def parse_Per_sequence_quality_scores(filename, analysis):
	parse_partition(filename, analysis, "quality_score")

def parse_Per_base_sequence_content(filename, analysis):
	parse_partition(filename, analysis, "base_content")

def parse_Per_base_GC_content(filename, analysis):
	parse_partition(filename, analysis, "gc_content")


def parse_Per_base_N_content(filename, analysis):
	parse_partition(filename, analysis, "base_content")

def parse_Sequence_Length_Distribution(filename, analysis):
	parse_partition(filename, analysis, "sequence_length")

def parse_Sequence_Duplication_Levels (filename, analysis):
	parse_position(filename, analysis, "duplication_level")


def parse_Overrepresented_sequences(*argv):
    	parse_module(argv[0], argv[1], argv[2], "parse_overrepresented_sequences" )


def parse_overrepresented_sequences(analysis, to_parse):

	line_array = to_parse.split("\t")
	values[line[0]] = "overrepresented_sequence"
	analysis.add_general_value(line[0], line[1], line[3])



def parse_Kmer_Content(*argv):
   parse_module(argv[0], argv[1], argv[2], "parse_overrepresented_kmer" )


def parse_overrepresented_kmer(analysis, to_parse):
	line_array = to_parse.split("\t")
	values[line[0]] = "overrepresented_kmer"
	analysis.add_general_value(line[0], line[1])


def get_value_types():
	print "Getting values===========\n\n"
	return values


if __name__=="__main__":
	print "Done"
