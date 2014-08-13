package QCAnalysis::RunTable;
use IO::File;
use strict;

our %values;

our %header_scopes;

# This appears to be legacy code that no longer does anything.
#sub add_header_scope{
#	my $class = shift;
#	my $type = shift;
#	my $scope = shift;
#	$header_scopes{$type} = $scope;
#	
#}

sub parse_file(){
	my $class = shift;
	my $filename = shift;
	#my $analysis = shift;
	my @ret;
	#TYPE_OF_EXPERIMENT	PATH_TO_FASTQC	INSTRUMENT	CHMESTRY_VERSION	SOFTWARE_ON_INSTRUMENT_VERSION	CASAVA_VERION	RUN_FOLDER	SAMPLE_NAME	LANE
	
	
	my $fh = new IO::File( $filename, "r" ) or die $!;
	my $to_parse = $fh->getline();
	chomp $to_parse;
	$to_parse = lc $to_parse;
	my @header = split(/\t/, $to_parse); 
	my %values;
	while ( $to_parse = $fh->getline() ) {
		chomp $to_parse;
		my @line = split(/\t/, $to_parse); 
		my $analysis = QCAnalysis->new();
		for(my $i = 0; $i < @header; $i++){
			my $key = $header[$i];
			my $value = $line[$i];
			
			$analysis->add_property($key, $value);	
		
		}
		while ((my $key, my $value) = each(%values)){
			$analysis->add_valid_type($key, $value);
		}
		push(@ret, $analysis);
	}
	
	#while ((my $key, my $value) = each(%values)){
	 #   $analysis->add_valid_type($key, $value);
	#}
       return @ret;
}

1;
