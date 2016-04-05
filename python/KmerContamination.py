#package QCAnalysis::KmerContamination
#use base 'QCAnalysis'
#use strict
#no strict "refs"
#use IO::File

values={}
values["sample_size_ratio"] = "sample_size_ratio"
values["sampled_reads"] = "sampled_reads"
values["contaminated_reads"] = "contaminated_reads"
values["percentage"] = "percentage"
values["ref_kmer_percent"] = "ref_kmer_percent"

value_keys={}
value_keys["SampleSize(Ratio)"] = "sample_size_ratio"
value_keys["SampledReads"] = "sampled_reads"
value_keys["ContaminatedReads"] = "contaminated_reads"
value_keys["Percentage"] = "percentage"
value_keys["RefKmerPercent"] = "ref_kmer_percent"

def parse_file(classname, filename, analysis):
	try:
		fh=open(filename)
	except IOError as err:
		print "Cannot open file: ", filename
	
	
	for line in fh:
		line=line.strip()
		
		match=re.search(r'Sample.*RefKmerPercent', line)
		if match:
			#Header row
			header=line.split("\t")
		else:
			results=line.split("\t")
			
			if header == results:
				for i in range(len(results)):
					if 'Program' in header[i]:
			    			analysis.add_property(results[i], "0.1")
			    			analysis.add_property("tools", results[i])
			    		elif "Reference" in header[i]:
			    			analysis.add_property('reference', results[i])
			    		elif 'Sample' in header[i]:
			    			analysis.add_property("sample", results[i])
			    		elif value_keys[header[i]]:
			    			if "," in results[i]:
			    				results[i].replace(",", "")
			    				analysis.add_general_value(value_keys[header[i]], results[i])
	for key, value in values.items():
		analysis.add_valid_type(key, value)
	
	return analysis



