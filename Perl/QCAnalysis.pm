package QCAnalysis;
use strict;
use Storable;

=head1 QCAnalysis

=head2 SYNOPSIS

QCAnalysis encapsulates a generic analysis and holds information on what needs to be set up in the database. 


=head2 Methods

=cut


=head3 QCAnalysis->new()

Constructor method. 

=cut

sub new {
    my $class = shift;
	my $self = {"id" => undef , 
	 			"property" => {},
				"value" => {} ,
				"partition_value" => [], #This is an array of hashes
				"position_value" => [], 
				"value_desc" => {} , #Auxiliary to add description to a value
				"value_type" => {}
				};
	bless $self, $class;
	return $self;
}

=head3 $new_analysis = $qc_analysis->clone($original_analysis)

Creates a copy of an existing analysis object

=cut

sub clone {
	my $self = shift;
	#my $original = shift;
	
	#my $new = Storable::dclone($original);
	my $new = Storable::dclone($self);
	return $new;
}

=head3 $qc_analysis->add_property($key, $value)

This method recives a key and a value to store as a general proerty fot the Analysis. This values are NOT to hold numeric values. 

=cut

sub add_property{
	my $self = shift;
	my $key = shift;
	my $value = shift;
	$self->{property}->{$key} = $value;
	
}

sub get_property{
	my $self = shift;
	my $key = shift;
	return 	$self->{property}->{$key};
}

sub pos_size_from_range{
	my $range = shift;
	(my $from, my $to) = parse_range($range);
	my $length = abs($to - $from);
	$from = $to if ($to < $from);
	return ($from, $length + 1);
}


=head3 $qc_analysis->add_partition_value($position,  $size, $type, $value)

Adds the $value for a partition starting from $position to $position + $size. $type must be a valid type for the analysis.  

=cut

sub add_partition_value{
	my $self = shift;
	my $range = shift;
	my $key = shift;
	my $value = shift;
	
	(my $position, my $size) = pos_size_from_range($range);
	
#TODO: Validate that the type is supported by the class. 
	my $partitions = $self->{partition_value};
	my $arr = [$position, $size, $key, $value];
#	print "Adding to partition ($arr) : $position, $size, $key, $value \n";

	push(@$partitions, $arr);
}

sub add_position_value{
	my $self = shift;
	my $position = shift;
	my $key = shift;
	my $value = shift;
	my $pos;
#TODO: Validate that the type is supported by the class. 	
	if($position =~ /([\d]+)/){
		$pos = $1;
		my $positions = $self->{position_value};
		my $arr = [$pos, $key, $value];
		push(@$positions, $arr);
	}else{
		print "Invalid position for: $position, $key, $value \n";
	}
	


#	

	
}

sub add_general_value{
	#TODO: Fill this.
	my $self = shift;
	my $key = shift;
	my $value = shift;
	my $description = shift;
	#TODO: Validate that the value is valid!
	$self->{value}->{$key} = $value;
	if($description){
	#	print "Adding $key $description \n";
		$self->{value_desc}->{$key} = $description;
	}
	
}

sub get_general_values{
	my $self = shift;
	return $self->{value};
}

sub get_partition_values{
	my $self = shift;
	return $self->{partition_value};
}

sub get_position_values{
	my $self = shift;
	return $self->{position_value};
}


=head3 $qc_analysis->add_valid_type($value_type, $value_scope)

Adds a valid type with it's scope. The scope and the type are designed to be able to distinguish the values. 

=cut

sub add_valid_type{
	my $self = shift;
	my $value_type = shift;
	my $value_scope = shift;
#	print "adding: $value_type, $value_scope:";
	$self->{value_type}->{$value_type} = $value_scope;
#	print $self->{value_type}->{$value_type} . "\n";
}	


=head3 get_value_types

Returns the hash with all the valid value types, as a pointer. 

=cut


sub get_value_types{
	my $self = shift;
	return ($self->{value_type}, $self->{value_desc} );
}

sub parse_range{
	my $to_parse = shift;
	my $min;
	my $max;
	if($to_parse =~ /([0-9]+)-([0-9]+)/){
		$min = $1;
		$max = $2;
	}elsif($to_parse =~ /([0-9]+)/){
		$min = $1;
		$max = $1;
	}else{
		$min = 0;
		$max = 0;
	}
#	print "Range parsed: $min-$max (from $to_parse)\n";
	return ($min, $max);
}

1;
