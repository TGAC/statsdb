
import os, sys
import MySQLdb
import optparse
import QCAnalysis, FastQC, RunTable, DB

parser=optparse.OptionParser()
parser.add_option("-i", "--input", action="store", type="string", dest="input")
parser.add_option("-d", "--db_config", action="store", type="string", dest="db_config")

(options, args) = parser.parse_args()   #gets the arguments and options
options=options.__dict__
print "Input: " + options['input'] + "\n"
print "DB configuration: " + options['db_config'] + "\n"
input_metafile=options['input']
line=""; module=""; status=""; config=options['db_config']
print "Input : ", input_metafile
print "config : ", config


print "Creating database connection "


try:
	#read config file and get connection information
	dbhost=""; dbuser="";password=""; dbname=""
	fh=open(config)
	
	firstline=fh.readline().strip().split("\t")[1].split(";")
	dbhost=firstline[1].split("=")[1]
	dbname=firstline[0].split(":")[2]
	dbuser=fh.readline().strip().split("\t")[1]
	password=fh.readline().strip().split("\t")[1]
	#print dbhost, dbuser, password, dbname
	dbase_con= MySQLdb.connect(dbhost, dbuser, password, dbname)	#this is the object holding connection
	#dbase_con = MySQLdb.connect(db='statsdb')
	
except:
	print "Could not get connection. Please check the database name."
	exit(1)
RunTable.add_header_scope("barcode", "analysis")
list_of_objs=RunTable.parse_file(input_metafile)

#db.connect(config)
db=DB.dbase(dbase_con)



for obj in list_of_objs:
	print obj.data["property"]
	fast_qc_file = obj.get_property("path_to_analysis")
	print "fast_qc_file: ", fast_qc_file
	if os.path.exists(fast_qc_file):
		FastQC.parse_file(fast_qc_file, obj)
		print "Inserting the record now: "
		db.insert_analysis(obj)
	else:
		print "WARN: Unable to read file ", fast_qc_file

dbase_con.close()
