import QCAnalysis
import TagCount, DB, RunTable

import os.sys

sys.path.append('/usr/users/ga002/shrestha/Dropbox/')

parser=optparse.OptionParser()
parser.add_option("-i", "--input", action="store", type="string", dest="input")
parser.add_option("--db_config", action="store", type="string", dest="db_config")

(options, args) = parser.parse_args()   #gets the arguments and options
print "Input: " + options['input'] + "\n"
print "DB configuration: " + options['db_config'] + "\n"
input=options['input']
line=""; module=""; status=""; config=options['db_config']

db=QCAnalysis.DB()

analysis=QCAnalysis.RunTable.parse_file(input)
db.connect()
for each in analysis:
    print "Analysis: " + each
    fast_qc_file = each.get_property("path_to_counts")
    QCAnalysis.TagCount.parse_file(fast_qc_file, each)
    db.insert_analysis(each)

db.disconnect()
