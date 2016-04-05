package QCAnalysis::FastQC;
use base 'QCAnalysis';
use strict;
no strict "refs";
use IO::File;

our %values;

$values{general_total_sequences} = "analysis";
$values{general_filtered_sequences} = "analysis";
$values{general_min_length} = "analysis";
$values{general_max_length} = "analysis";
$values{general_gc_content} = "analysis";

$values{quality_mean} = "base_partition";
$values{quality_median} = "base_partition";
$values{quality_lower_quartile} = "base_partition";
$values{quality_upper_quartile} = "base_partition";
$values{quality_10th_percentile} = "base_partition";
$values{quality_90th_percentile} = "base_partition";

$values{quality_score_count} = "sequence_cumulative";


$values{base_content_a} = "base_partition";
$values{base_content_c} = "base_partition";
$values{base_content_g} = "base_partition";
$values{base_content_t} = "base_partition";

$values{"gc_content_percentage"} = "base_partition";
$values{"gc_content_count"} = "sequence_cumulative";

$values{base_content_n_percentage} = "base_partition";

$values{"sequence_length_count"} = "sequence_cumulative";
$values{"duplication_level_relative_count"} = "sequence_cumulative";

$values{"total_duplicate_percentage"} = "analysis";

our %value_keys;
$value_keys{"Total Sequences"} = "general_total_sequences";
$value_keys{"Filtered Sequences"} = "general_filtered_sequences";
$value_keys{"\%GC"} = "general_gc_content";

our %header_keys;
$header_keys{"\%gc"} = "percentage";
$header_keys{"n-count"} = "n_percentage";

our %line_functions;

$line_functions{"parse_overrepresented_sequences"} = 1;
$line_functions{"parse_overrepresented_kmer"} = 1;
	
$header_keys{"#total duplicate percentage"} = "total_duplicate_percentage";

sub parse_file(){
	my $class = shift;
	my $filename = shift;
	my $analysis = shift;
	my $fh = new IO::File( $filename, "r" ) or die $!;
	my $line;
	my $module;
	my $status;
	
	while ( $line = $fh->getline() ) {
	    chomp($line);
		if($line =~ /##FastQC	(\S*)/){
			$analysis->add_property("FastQC", $1);
			$analysis->add_property("tool", "FastQC");
		}elsif ( $line =~ />>(.*)\t(\S*)/ ) {
	        $module = $1;
	        $status = $2;
	        $module =~ s/\s/_/g;

	        my $parse_function = "parse_" . $module;
	        if( defined &{$parse_function} ){
	            &$parse_function($fh, $analysis);
	        }else{
	            print "Warn: No function:  " . $parse_function . "\n";
	        }
	    }
	}
	while ((my $key, my $value) = each(%values)){
	    $analysis->add_valid_type($key, $value);
	}
	return $analysis;
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
sub range_to_from_length{
	my $range = shift;
	(my $from, my $to) = parse_range($range);
	my $length = abs($to - $from);
	$from = $to if ($to < $from);
	return ($from, $length + 1);
}

sub parse_Basic_Statistics {
    my $fh = shift;
	my $analysis = shift;

    my $to_parse;
    my $done = 0;
    while ( $to_parse = $fh->getline() ) {
    	if($to_parse =~ m/^#/){
    		#It is a comment. 
    	}elsif($to_parse =~ /([\S| ]+)\t([\S| ]+)/){
    		#print $1."\n";
    		if($1 eq "Sequence length"){
				(my $min, my $max) = parse_range($2);
				$analysis->add_general_value("general_min_length", $min);
				$analysis->add_general_value("general_max_length", $max);
			}elsif(defined $value_keys{$1}){
    			$analysis->add_general_value($value_keys{$1}, $2);
    		}else{
				$analysis->add_property($1, $2);
			}
			#$self->{$1} = $2;
		}elsif ( $to_parse =~ />>(.*)/ ) {
            unless ( $to_parse =~ m/>>END_MODULE/ ) {
                die "Missformated file!";
            }
            last;
        }
        else {
            print $to_parse;
        }
    }
}


sub parse_module{
	my $fh = shift;
	my $analysis = shift;
	my $prefix = shift;
	my $function = shift;
    my $done = 0;
	my $to_parse;
	my @header;
    while ( $to_parse = $fh->getline() ) {
		chomp $to_parse;
        if ( $to_parse =~ />>(.*)/ ) {
            unless ( $to_parse =~ m/>>END_MODULE/ ) {
                die "Missformated file!";
            }
            last;
        }elsif($to_parse =~ m/^#/){
			$to_parse = lc $to_parse;
			
			my @line = split(/\t/, $to_parse);
			#print "Header line:$to_parse \n";
			
			if( scalar @line == 2 && defined $header_keys{$line[0]}){
				$analysis->add_general_value( $header_keys{$line[0]}, $line[1]);
			}else{
				for (my $i = 0; $i < scalar @line; $i++){
					my $token = $line[$i];
					#print $token.":";
					$token =~ s/\s/_/g;
					if(defined $header_keys{$token}){
						$token = $header_keys{$token};
					}
					#print $token."\n";
					$header[$i]  = $prefix."_".$token;
				}
			}
		}else {
			if(defined $line_functions{$function}){
				&$function($analysis, $to_parse);
			}else{
				my @line = split(/\t/, $to_parse);
				for (my $i = 1; $i < scalar @line; $i++){
					 $analysis->$function($line[0], $header[$i], $line[$i]);
				}
			}
        }
    }
#	print "\n";
	
}

sub parse_partition {
    parse_module(shift, shift, shift, "add_partition_value" );
}

sub parse_position{
	parse_module(shift, shift, shift, "add_position_value" );
}

sub parse_Per_base_sequence_quality {
    my $fh = shift;
	my $analysis = shift;
    parse_partition($fh, $analysis, "quality");
}

sub parse_Per_sequence_quality_scores {
   	my $fh = shift;
	my $analysis = shift;
    parse_position($fh, $analysis, "quality_score");
}

sub parse_Per_base_sequence_content {
    parse_partition(shift, shift, "base_content");
}

sub parse_Per_base_GC_content {
    parse_partition(shift, shift, "gc_content");
}

sub parse_Per_sequence_GC_content {
    parse_partition(shift, shift, "gc_content");
}

sub parse_Per_base_N_content {
    parse_partition(shift, shift, "base_content");
}

sub parse_Sequence_Length_Distribution {
    parse_partition(shift, shift, "sequence_length");
}

sub parse_Sequence_Duplication_Levels {
    parse_position(shift, shift, "duplication_level");
}

sub parse_Overrepresented_sequences {
    parse_module(shift, shift, shift, "parse_overrepresented_sequences" );
}

sub parse_overrepresented_sequences{
	my $analysis = shift;
	my $to_parse = shift;
	my @line = split(/\t/, $to_parse);
	$values{$line[0]} = "overrepresented_sequence";
	$analysis->add_general_value($line[0], $line[1], $line[3]);
}


sub parse_Kmer_Content {
   parse_module(shift, shift, shift, "parse_overrepresented_kmer" );
}

sub parse_overrepresented_kmer{
	my $analysis = shift;
	my $to_parse = shift;
	my @line = split(/\t/, $to_parse);
	$values{$line[0]} = "overrepresented_kmer";
	$analysis->add_general_value($line[0], $line[1]);
}

sub get_value_types{
	print "Getting values===========\n\n";
	return \%values;
}

1;
