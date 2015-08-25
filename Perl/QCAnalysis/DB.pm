package QCAnalysis::DB;
use DBI;
use IO::File;
use File::Basename;
use strict;

=head1 QCAnalysis::DB

  QCAnalysis::DB - A class that encapsulates the database connection. 

=head2 SYNOPSIS
    use QCAnalysis::DB;
    my $qc_db = QCAnalysis::DB->new();
    hello->connect("db_config.txt");


=head2 DESCRIPTION
This class does the connection to the database and it is able to 
insert new QCAnalysis. It also reconstructs the QCAnalysis objects
from the database



The db_string attribute is passed to DBI. Currently we support the
following databases:

=over

=item *
 MySQL 5.0  

=back

Other databases may work but we haven't tested. 

=head2 METHODS

=cut



=head3 QCAnalysis::DB->new()
Constructor method. This constuctor doesn't actually establishes the
connection.
=cut

sub new {
    my $class = shift;
    my $self = {"connection" => undef , 
		"db_user" => undef,
		"db_password" => undef ,
		"db_string" => undef,
		"miso_string" => undef,
		"miso_user" => undef,
		"misoi_api_key" => undef,
		"data_types_config_file" => undef};
    bless $self, $class;
    return $self;
}

sub parse_details(){
    my $self = shift;
    my $config_file = shift;
    my $config_fh = new IO::File( $config_file , "r" ) or die $!;
    while(my $line = $config_fh->getline()) {
	chomp $line;
	#print $line."\n";
	if($line =~ /(\S+)\s(\S*)/){
	    $self->{$1} = $2;
	}
    }
    $self->parse_valid_data_types();
}

# This seems a logical place to read in the config file that contains the list of valid data types. It can
# be invoked as part of the connection process - by parse_details, perhaps.
# That list will get attached to the object, so will be available whenever stuff gets inserted into the database.
sub parse_valid_data_types {
    my $self = shift;
    my $config_file = $self->{data_types_config_file};
    my $config_fh = new IO::File( $config_file , "r" ) or die $!;
    while(my $line = $config_fh->getline()) {
	chomp $line;
	#print $line."\n";
	if($line =~ /(\S+)\s(\S*)\s(\S*)/){
	    $self->{data_types_config}{$1} = $3;
	    push @{$self->{data_types_classification}{$2}}, $1;
	}
    }
}

# Due to that exclusivity of data, we are likely to run into cases where a whole analysis object may contain no
# useful data. That can be pre-empted by identifying such cases from statsdb_string input, and skipping them.
# This sub compares the expected data in a given file (as determined by the config file parsed above) to that
# which is configured to be used, and determines whether to skip this analysis object or not.
sub data_enabled_check {
    my $self = shift;
    my $type = lc shift;
    my $path = shift;
    my $file = basename($path);
    
    my $data_class = $type;
    if ($type =~ /interop/i) {
	my $interop_type = $file;
	$interop_type =~ s/Out.bin//;
	$data_class .= "_$interop_type";
    }
    
    # Get list of data types associated with this class of data
    my $data_types = $self->{data_types_classification}{$data_class};
    
    # Check that at least one data type in that list is switched on
    my $on = 0;
    foreach my $data_type (@$data_types) {
	if ($self->{data_types_config}{$data_type} eq 'yes') {
	    $on = 1;
	}
    }
    
    return $on;
}

=head3 $db->connect("config.txt")
Method that establishes a connection to the database. To connect to the database, a configuration file is 
required. It consist of a tab separated file with the following attributes:
=head4 db_config.txt
    db_string	dbi:mysql:database;host=host
    db_user	user
    db_password	password
=cut

sub connect(){
    my $self = shift;
    my $config_file = shift;
    $self->parse_details($config_file);
    #TODO: make some sort of cleaver parser, for safety. 
    $self->{connection} = DBI->connect($self->{db_string},$self->{db_user},$self->{db_password}) ||
    die "Database connection not made: $DBI::errstr";
    print "Connected\n";
}


=head3 $db->disconnect()
Method that closes the connection to the database. 
=cut

sub disconnect(){
    my $self = shift;
    print "Disconnecting\n";
    $self->{connection}->disconnect() or warn "Unable to disconnect $DBI::errstr\n";
}

sub insert_properties() {
    my $self = shift;
    my $analysis = shift;
    my $dbh = $self->{connection};
    my $id = $analysis->{id};
    my $properties = $analysis->{property};
    my $success=1;
    KEY: foreach my $key ( keys %{$properties} ) {
	#print "key: $key, value: " .."\n";
	# Do not insert properties containing the sequencer directory of the run, since this is
	# subject to change and does not belong in the database.
	if (lc($key) eq 'sequencer_folder') {
	    next KEY;
	}
	
	my $value = $properties->{$key};
	my $statement = "INSERT INTO analysis_property(analysis_id, property, value) VALUES ('$id', '$key', '$value');";
	#print $statement."\n";
	$success &= $dbh->do($statement);
    }
    return $success;
}

sub insert_dates() {
    my $self = shift;
    my $analysis = shift;
    my $dbh = $self->{connection};
    my $id = $analysis->{id};
    my $dates = $analysis->{date};
    my $success=1;
    foreach my $key ( keys %{$dates} ) {
	#print "key: $key, value: " .."\n";
	my $value = $dates->{$key};
	my $statement = "INSERT INTO analysis_date(analysis_id, property, date) VALUES ('$id', '$key', '$value');";
	#print $statement."\n";
	$success &= $dbh->do($statement);
    }
    return $success;
}

our %type_scope;
our %value_type;
our %warn_printed;

sub get_value_id() {
    my $self = shift;
    my $value = shift;
    my $type = shift;
    my $desc = shift; #Optional value. 
    
    my $db = $self->{connection};
    
    my $type_id;
    my $value_id;
    unless(defined $type_scope{$type}){
	my $qt = "SELECT id FROM type_scope WHERE scope = '$type';";
	#print $qt;
	my $dbh = $db->prepare($qt);  										
	$dbh->execute();
	$dbh->bind_col( 1, \$type_id );
	if($dbh->fetch()) {
	    $type_scope{$type} = $type_id;				
	} else {
	    # Insert the new type!
	    my $ins_t = "INSERT INTO type_scope (scope) VALUES ('$type')";
	    #print $ins_t."\n";
	    $db->do($ins_t)  ||
	    die "Database error: $DBI::errstr";;
	    $type_id = $db->last_insert_id(undef, undef, undef, undef);				
	    $type_scope{$type} = $type_id;
	}
    }	
    $type_id = $type_scope{$type};
    
    unless (defined $value_type{$value}) {
	my $qv = "SELECT id FROM value_type WHERE type_scope_id='$type_id' AND description='$value' ;";
	#print $qv;
	my $dbh_qv = $db->prepare($qv);
	$dbh_qv->execute();
	$dbh_qv->bind_col(1, \$value_id);
	if($dbh_qv->fetch()) {
	    $value_type{$value} = $value_id;
	} else {
	    #Insert new value!
	    my $ins_v;
	    if(length($desc) > 0 ) {
		$ins_v = "INSERT INTO value_type (description, type_scope_id, comment) VALUES ('$value', $type_id, '$desc')";
		#print $ins_v."\n";
	    } else {
		$ins_v = "INSERT INTO value_type (description, type_scope_id) VALUES ('$value', $type_id)";
	    }
	    
	    $db->do($ins_v)  ||
	    die "Database error: $DBI::errstr";
	    $value_id =  $db->last_insert_id(undef, undef, undef, undef);	
	    $value_type{$value} = $value_id;
	}
    }
    $value_id =  $value_type{$value};
    return $value_id;
}

sub insert_values() {
    my $self = shift;
    my $analysis = shift;
    
    my $db = $self->{connection};
    #print "in insert values\n";
    (my $values, my $values_desc) = $analysis->get_value_types();
    my %id_values;
    #print $values."\n";
    my $id_value;
    while ((my $key, my $value) = each(%$values)) {
	my $value_desc = $values_desc->{$key};
	$id_values{$key} = $self->get_value_id($key, $value, $value_desc);
    }
    my $inserted = 1;
    my $general_values = $analysis->get_general_values();
    while ((my $key, my $value) = each(%$general_values)) {
	if(defined $id_values{$key}) {
	    if ($self->{data_types_config}{$key}) {
		if ($self->{data_types_config}{$key} eq 'yes') {
		    $id_value = $id_values{$key};
		    my $ins_gv = "INSERT INTO analysis_value (analysis_id, value_type_id, value) VALUES ('".$analysis->{id}."', $id_value, $value);";
		    #print $ins_gv."\n";
		    $inserted &= $db->do($ins_gv);
		}
	    }
	    else { print "WARN: Value type \"$key\" not specified in data types config \n"; }
	} else {
	    unless(defined $warn_printed{$key}) {
		print "WARN: Value not defined '".$key."'\n";
		 $warn_printed{$key} = 1;
	    }
	}
    }
    return $inserted;	
}

sub insert_partitions(){
    my $self = shift;
    my $analysis = shift;
    
    my $db = $self->{connection};
    #print "in insert values\n";
    (my $values, my $val_desc ) = $analysis->get_value_types();
    my %id_values;
    #	print $values."\n";
    my $id_value;
    # $key here is the value type.
    while ((my $key, my $value) = each(%$values)) {
	$id_values{$key} = $self->get_value_id($key, $value);
    }
    my $inserted = 1;
    my $partition_values = $analysis->get_partition_values();
    my $analysis_id = $analysis->{id};
    foreach(@$partition_values) {
	if($id_values{$_->[2]} > 0) {
	    # Value type = $_->[2]
	    # Check that that is allowed by the data types config
	    if ($self->{data_types_config}{$_->[2]}) {
		if ($self->{data_types_config}{$_->[2]} eq 'yes') {
		    my $position = $_->[0];
		    my $size = $_->[1];
		    my $value_type_id = $id_values{$_->[2]};
		    my $value =  $_->[3];
		    my $ins_pv = "INSERT INTO per_partition_value (analysis_id, position, size, value, value_type_id) VALUES ($analysis_id, $position, $size, $value, $value_type_id);\n";
		    #print $ins_pv;
		    $inserted &= $db->do($ins_pv);
		}
	    }
	    else { print "WARN: Partition value not specified in data types config ".$_->[2]."\n"; }
	} else {
	    unless(defined $warn_printed{$_->[2]} ) {
		print "WARN: Not defined ".$_->[2]."\n";
		$warn_printed{$_->[2]} = 1;
	    }
	}
    }
    return $inserted;
}

sub insert_positions() {
    my $self = shift;
    my $analysis = shift;
    
    my $db = $self->{connection};
    #print "in insert values\n";
    (my $values, my $val_desc ) = $analysis->get_value_types();
    my %id_values;
    #print $values."\n";
    my $id_value;
    while ((my $key, my $value) = each(%$values)) {
	$id_values{$key} = $self->get_value_id($key, $value);
    }
    my $inserted = 1;
    my $position_values = $analysis->get_position_values();
    my $analysis_id = $analysis->{id};
    foreach(@$position_values){
	if($id_values{$_->[1]} > 0) {
	    # Value type = $_->[1]
	    # Check that that is allowed by the data types config
	    if ($self->{data_types_config}{$_->[1]}) {
		if ($self->{data_types_config}{$_->[1]} eq 'yes') {
		    my $position = $_->[0];
		    my $value_type_id = $id_values{$_->[1]};
		    my $value =  $_->[2];
		    my $ins_pv = "INSERT INTO per_position_value (analysis_id, position, value, value_type_id) VALUES ($analysis_id, $position, $value, $value_type_id);\n";
		    #print $ins_pv;
		    $inserted &= $db->do($ins_pv);
		}
	    }
	    else { print "WARN: Position value not specified in data types config ".$_->[1]."\n"; }
	} else {
	    unless(defined $warn_printed{$_->[1]}) {
		print "WARN: Not defined ".$_->[1]."\n";
		$warn_printed{$_->[1]} = 1;
	    }
	}
    }
    return $inserted;
}


=head3 $db->insert_analysis($qc_analysis)
    $db->insert_analysis($qc_analysis)
Inserts the analysis object in the database. This function hides all
the traversing in the object and ensures that the type, values, etc
are set up correctly and consistent with the data and definitions
already in the database. 

STILL IN DEVELOPMENT!
=cut
sub insert_analysis(){
    my $self = shift;
    my $new_analysis = shift;
    my $dbh = $self->{connection};
    my $q = "INSERT INTO analysis () values ();";
    my $inserted = $dbh->do($q);
    my $id = $dbh->last_insert_id(undef, undef, undef, undef);
    $new_analysis->{id} = $id;
    $inserted &= $self->insert_properties($new_analysis);
    $inserted &= $self->insert_dates($new_analysis); # This is new -Neil
    $inserted &= $self->insert_values($new_analysis);
    $inserted &= $self->insert_partitions($new_analysis);
    $inserted &= $self->insert_positions($new_analysis);
    
    print "inserted $id\n" if($inserted);
}

1;
