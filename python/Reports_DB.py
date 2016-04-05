import re, MySQLdb

class Report_DB:
	
	def __init__(self):
		self.con={"connection":None, "db_user": None, "db_password":None, "db_string": None}
	
	def New(self, config_file):
		self.config_file=config_file
		return self.parse_details()
		
		
	def parse_details(self):
		try:
			fh= open(self.config_file)
		except IOError as err:
			print "Cannot open the file : ", self.config_file
			print err
			exit(1)
		
		firstline=fh.readline().strip().split("\t")[1].split(";")
		self.dbhost=firstline[1].split("=")[1]
		self.dbname=firstline[0].split(":")[2]
		self.dbuser=fh.readline().strip().split("\t")[1]
		self.password=fh.readline().strip().split("\t")[1]
		
		fh.close()
		
		return self.Connect()


	'''
	=head3 $db->connect("config.txt")

	Method that establishes a connection to the database. To connect to the database, a configuration file is 
	required. It consist of a tab separated file with the following attributes:

	=head4 db_config.txt

		        db_string       dbi:mysql:database;host=host
		        db_user user
		        db_password     password

	=cut
	'''
	
	def Connect(self):
		try:
			self.connection = MySQLdb.connect(self.dbhost, self.dbuser, self.password, self.dbname)
			print "Connected to Database"
			return self.connection
		except:
			print "Database connection not made. Please check the connection details."
	#        print "Connected\n";

	def disconnect(self):
		print "Disconnecting"
		self.close()

