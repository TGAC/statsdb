#package QCAnalysis::TagCount;
#use base 'QCAnalysis';
#use strict;
#no strict "refs";
#use IO::File;

values={}


def parse_file(*argv):
	classname = argv[0]
	filename = argv[1]
	analysis = argv[2]
	print "opening: " + filename
	try:
		fh=open(filename)
	except IOError as err:
		print "Cannot open file: ", filename


	analysis.add_property("tool", "tgac_tag_count")
	
	for line in fh:
		
	 	parse_tag_sequence_count(analysis, line.strip());
	for key, value in values.items():
		
	    analysis.add_valid_type(key, value)
	
	return analysis



def parse_tag_sequence_count(analysis, to_parse):

	line=to_parse.split("\t")
	values[line[2]] = "multiplex_tag"
	if line[0] == analysis.get_property("lane"):
#		print "Adding for lane". $line[0]."\n";
		analysis.add_general_value(line[2], line[3])



