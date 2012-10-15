package QCAnalysis::TagCount;
use base 'QCAnalysis';
use strict;
no strict "refs";
use IO::File;

my %values;


sub parse_file(){
	my $class = shift;
	my $filename = shift;
	my $analysis = shift;
	print "opening: $filename\n";
	my $fh = new IO::File( $filename, "r" ) or die $!;
	my $line;
	my $module;
	my $status;
	
	$analysis->add_property("tool", "tgac_tag_count");
		
	while ( $line = $fh->getline() ) {
	 	parse_tag_sequence_count($analysis, $line);
	}
	while ((my $key, my $value) = each(%values)){
	    $analysis->add_valid_type($key, $value);
	}
	return $analysis;
}


sub parse_tag_sequence_count{
	my $analysis = shift;
	my $to_parse = shift;
	my @line = split(/\s/, $to_parse);
	$values{$line[2]} = "multiplex_tag";
	if($line[0] == $analysis->get_property("lane")){
#		print "Adding for lane". $line[0]."\n";
		$analysis->add_general_value($line[2], $line[3]);
	}
}


1;