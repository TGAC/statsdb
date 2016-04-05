'''
package QCAnalysis::DB;
use DBI;
use IO::File;
use strict;

=head1 QCAnalysis::DB

  QCAnalysis::DB - A class that encapsulates the database connection. 

=head2 SYNOPSIS

	use QCAnalysis::DB;
	my $qc_db = QCAnalysis::DB->new();
	hello->connect("db_config.txt");


=head2 DESCRIPTION
 
This class does the connection to the database and it is able to insert new QCAnalysis. It also reconstructs
the QCAnalysis objects from the database



The db_string attribute is passed to DBI. Currently we support the following databases:

=over

=item *
 MySQL 5.0  

=back

Other databases may work but we haven't tested. 

=head2 METHODS

=cut



=head3 QCAnalysis::DB->new()
	
Constructor method. This constuctor doesn't actually establishes the connection.

=cut
'''

import MySQLdb

class dbase:
	type_scope={}; value_type={}; warn_printed={}
	def __init__(self, db):
		self.db=db
		self.dbc=self.db.cursor()
		#con = {"connection" : None , 
		 #			"db_user": None,
		#			"db_password": None ,
		#			"db_string" : None };
		#return con


	def parse_details(self, config_file):
		self.db_connection={}
		try:
			config_fh = open(config_file)
		except IOError as err:
			print "Cannot open file : ", config_file
			exit(1)
		for line in config_fh:
			line=line.strip()
		#	print $line."\n";
			if re.search(r'(\S+)\s(\S*)'):
				match=re.search(r'(\S+)\s(\S*)')
				#$self->{$1} = $2;
				self.db_connection[match.group(1)]=match.group(2)

	'''
	=head3 $db->connect("config.txt")

	Method that establishes a connection to the database. To connect to the database, a configuration file is 
	required. It consist of a tab separated file with the following attributes:

	=head4 db_config.txt

			db_host	localhost
			db_user	user
			db_password	password
			db_name	statsdb

	=cut
	'''
	def connect(self, config_file):
		self.db_connection = self.parse_details(config_file);
		return (self.db_connection["db_host"], self.db_connection["db_user"], self.db_connection["db_password"], self.db_connection["db_name"])

	'''
	=head3 $db->disconnect()

	Method that closes the connection to the database. 

	=cut
	'''


	def insert_properties(self, analysis):

		#my $id = $analysis->{id};
		properties = analysis.data["property"]
		
		success=0
		for key in properties.keys():
			
			value = properties[key]
			#print "key: ", key, "value:", value
			statement = "INSERT INTO analysis_property(analysis_id, property, value) VALUES (%d,\"%s\",\"%s\")" %(analysis.data["id"],str(key),str(value))
			#print $statement."\n";
		  	#$success &= $dbh->do($statement);
		  	try:
		  		self.dbc.execute(statement)
		  		self.db.commit()
		  		#print "Execution Successful, statement: ", statement
		  		success +=1
		  	except:
		  		print "Cannot execute the statement : ", statement
		  		self.dbc.rollback()
		
		#print "Successes : ", success
		return success


	def get_value_id(self, value, atype, desc=""):

	
		#my $db = $self->{connection};
	
		#my $type_id;
		#my $value_id;
		if atype not in self.type_scope.keys():
			#print "No ", atype, " in ", self.type_scope
			qt = "SELECT id FROM type_scope WHERE scope = '" + atype + "';";
			#print qt
			#my $dbh = $db->prepare($qt);  										
			#$dbh->execute();
			#$dbh->bind_col( 1, \$type_id );
			try:
				self.dbc.execute(qt)
				#self.db.commit()
				#print "Execution successful, statement = :", qt
			except:
				print "Execution failed : ", qt
				
				exit(1)
			records=self.dbc.fetchall()
			if records:
				#print records
				for outer_row in records:
					#print outer_row
					for inner_row in outer_row:
						#print inner_row
						type_id=inner_row
						#print "A row ", type_id
						self.type_scope[atype]=type_id
			
			
			else:
			
				#Insert the new type!
				#print "Not fetched all"
				ins_t = "INSERT INTO type_scope (scope) VALUES (' " + atype + "')"
	#			#print $ins_t."\n";
				try:
					self.dbc.execute(ins_t)
					self.db.commit()
				except MySQLdb.error as err:
					print "execution failed: statement: ", ins_t
					print err
					exit(1)
				
				type_id = self.dbc.lastrowid
				self.type_scope[atype] = type_id
	
		type_id = self.type_scope[atype]
		#print "type_id: ", type_id
		
		if value not in self.value_type.keys():
			qv = "SELECT id FROM value_type WHERE type_scope_id='" + str(type_id) + "' AND description=' " + str(value) + "' ;"
			#print qv
			#$dbh_qv->bind_col(1, \$value_id);
			self.dbc.execute(qv)
			if self.dbc.fetchall():
				for arow in self.dbc.fetchall():
					value_id=arow[0]
					#print "A row ", arow[0]
					value_type[value] = value_id
			else:
				#Insert new value!
				
				if(len(desc) > 0 ):
				
					ins_v = "INSERT INTO value_type (description, type_scope_id, comment) VALUES ('%s', %d, '%s')" %(str(value), type_id, str(desc))
					#print ins_v
				else:
					ins_v = "INSERT INTO value_type (description, type_scope_id) VALUES ('%s', %d)" %(str(value), type_id)
				
			
				try:
					self.dbc.execute(ins_v)
					self.db.commit()
					#print "Execution successful, statement : ", ins_v
				except:
					print "Database error"
					exit(1)
				value_id =  self.dbc.lastrowid
				self.value_type[value] = value_id
		
		value_id = self.value_type[value]
		return value_id

	def insert_values(self, analysis):
		
	#	print "in insert values\n";
		(values, values_desc) = analysis.get_value_type()
		#print "values: ", values, "values_desc: ", values_desc
		id_values={}
	#	print $values."\n";
		value_desc=""
		for key, value in values.items():
			
			#print "key : ", key, "value : ", value
			if key in values_desc.keys():
				value_desc = values_desc[key]
			id_values[key] = self.get_value_id(key, value, value_desc)
		
		
		inserted = 1;
		general_values = analysis.get_general_values()
		for key, value in general_values.items():
			
			
			if id_values[key]:
				id_value = id_values[key]
				ins_gv = "INSERT INTO analysis_value (analysis_id, value_type_id, value) VALUES (%d, %d, %d);" %(analysis_id, id_value, value)
	#			print $ins_gv."\n";
				self.dbc.execute(ins_gv)
				inserted += self.dbc.rowcount()
			else:
				if not warn_printed[key]:
					print "WARN: Value not defined '" + key + "'\n"
					warn_printed[key] = 1
		#print "From insert values, returning: ", inserted
		return inserted
	

	def insert_partitions(self, analysis):
		#print "in insert values\n";
		(values, val_desc ) = analysis.get_value_type()
		id_values={}
		#print $values."\n";
		id_value=None
		for key, value in values.items():
			id_values[key] = self.get_value_id(key, value,)
		inserted = 1
		partition_values = analysis.get_partition_value()
		analysis_id = analysis.data["id"]
		for avalue in partition_values:
			
			if(id_values[avalue[2]] > 0):
				#print 
				position = avalue[0]
				size = avalue[1]
				value_type_id = id_values[avalue[2]]
				value = avalue[3]

				ins_pv = "INSERT INTO per_partition_value (analysis_id, position, size, value, value_type_id) VALUES ($analysis_id, $position, $size, $value, $value_type_id);"
			#	print $ins_pv;
				self.dbc.execute(ins_pv)
				inserted += self.dbc.rowcount
			else:
				if warn_printed[avalue[2]]:
					
					
					print "WARN: Not defined ", avalue[2]
					warn_printed[avalue-[2]] = 1
		#print "From inserted_partitins: Returning : ", inserted
		return inserted

	def insert_positions(self, analysis):
		(values, val_desc ) = analysis.get_value_type()
		id_values = {}
		for key, value in values.items():
			id_values[key] = self.get_value_id(key, value)
			
		
		
		inserted = 1;
		position_values = analysis.get_position_value()
		analysis_id = analysis.data["id"]
		for each in position_values:
			if id_value[each[1]] > 0:
				position = each[0]
				value_type_id = id_values[each[1]]
				value = each[2]
				ins_pv = "INSERT INTO per_position_value (analysis_id, position, value, value_type_id) VALUES (%d, %d, %d, %d)" %(analysis_id, position, value, value_type_id)
			#	print $ins_pv;
				self.dbc.execute(ins_pv)
				self.db.commit()
				inserted += self.dbc.rowcount()
				#print "Number of Insertions : ", inserted
			else:
				if not warn_printed[each[1]]:
					print "WARN: Not defined " + each[1] + "\n"
					warn_printed[each[1]] = 1
		return inserted


	'''
	=head3 $db->insert_analysis($qc_analysis)

		$db->insert_analysis($qc_analysis)

	Inserts the analysis object in the database. This function hides all the traversing in the object and ensures
	that the type, values, etc are setted up correctly and consistent with the data and definitions already in the 
	database. 

	STILL IN DEVELOPMENT!
	=cut
	'''
	def insert_analysis(self, new_analysis):
		q = "INSERT INTO analysis () values ();"
		try:
			self.dbc.execute(q)
			self.db.commit()
			#print "Execution successful, statement executed : ", q
			
		except :
			print "Execution failed, statement tried: ", q
			exit(1)
		
		inserted = self.dbc.rowcount
		
		a_id = self.dbc.lastrowid
		new_analysis.data["id"] = a_id
		inserted += self.insert_properties(new_analysis)
		inserted += self.insert_values(new_analysis)
		inserted += self.insert_partitions(new_analysis)
		inserted += self.insert_positions(new_analysis)
	
		if(inserted):
			print "inserted ", a_id 

