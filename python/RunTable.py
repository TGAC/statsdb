
import QCAnalysis

def dictionary(mydict):
	for key in mydict.keys():
		print key, mydict[key]


header_scopes={}; values={}
def add_header_scope(self, classtype, scope):
	#header_scopes={}; values={}
	self.header_scopes[classtype] = scope

def parse_file(filename):
	#my $analysis = shift;
	ret = []
	#TYPE_OF_EXPERIMENT	PATH_TO_FASTQC	INSTRUMENT	CHMESTRY_VERSION	SOFTWARE_ON_INSTRUMENT_VERSION	CASAVA_VERION	RUN_FOLDER	SAMPLE_NAME	LANE
	#print "Parsed file : ", filename
	try:
		fh = open( filename, "r" )
	except IOError as err:
		print "Cannot open file ", filename
	to_parse = fh.readline()
	#print "to parse : ", to_parse
	to_parse = to_parse.strip().lower()
	header = to_parse.split("\t")
	#print "header: ", header
	values= {}
	
	for to_parse in fh:
		to_parse=to_parse.strip()
		if to_parse=="": continue
		line=to_parse.replace(" ", "").split("\t")
		#print "After spliting:", line
		#creating object for each record
		analysis=QCAnalysis.NEW()
		for i in range(len(header)):
			key = header[i]
			value = line[i]
			#print key, value
			
			analysis.add_property(key, value)
			
		for key, value in values.items():

			analysis.add_valid_type(key, value)
	
		ret.append(analysis)	#adding the objects in an array
	
	return ret

def get_property_from_QCanalysis(self,value):
	
	return self.analysis.get_property(value)

