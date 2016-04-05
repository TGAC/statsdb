import optparse 
import QCAnalysis
#import FastQC, KmerContamination, DB, RunTable

import os, sys

#sys.path.append('/usr/users/ga002/shrestha/Dropbox/')

parser=optparse.OptionParser()
parser.add_option("-i", "--input", action="store", type="string", dest="input")
parser.add_option("--db_config", action="store", type="string", dest="db_config")

(options, args) = parser.parse_args()   #gets the arguments and options
print "Input: " + options.input + "\n"
print "DB configuration: " + options.db_config + "\n"
input=options.input
line=""; module=""; status=""; config=options.db_config

db=QCAnalysis.NEW()
RunTable.add_header_scope(db, "barcode", "analysis")

QCAnalysis.analysis=RunTable.parse_file(input)

db.connect(config)

for each in analysis:
    analysis=each
    analysis_path=each.get_property("path_to_analysis")
    analysis_type=each.get_protperty("analysis_type")
    
    print "path : " + analysis_path + "\n"
    print "type : " + analysis_type + "\n"
    
    if os.path.exists(analysis_path):
        for thisvalue in analysis_type:
            if "FASTQC" in thisvalue:
                QCAnalysis.FastQC.parse_file(analysis_path, analysis)
                db.insert_analysis(analysis)
            elif "KmerContamination" in thisvalue:
                QCAnalysis.KmerContamination.parse_file(analysis_path, analysis)
                db.insert_analysis(analysis)
            else:
                None
    else:
        print "WARN: Unable to read file\n"

db.connect()





    
                
