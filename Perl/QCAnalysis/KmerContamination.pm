package QCAnalysis::KmerContamination;
use base 'QCAnalysis';
use strict;
no strict "refs";
use IO::File;

our %values;
$values{sample_size_ratio} = "sample_size_ratio";
$values{sampled_reads} = "sampled_reads";
$values{contaminated_reads} = "contaminated_reads";
$values{percentage} = "percentage";
$values{ref_kmer_percent} = "ref_kmer_percent";

our %value_keys;
$value_keys{"SampleSize(Ratio)"} = "sample_size_ratio";
$value_keys{"SampledReads"} = "sampled_reads";
$value_keys{"ContaminatedReads"} = "contaminated_reads";
$value_keys{"Percentage"} = "percentage";
$value_keys{"RefKmerPercent"} = "ref_kmer_percent";

sub parse_file(){
    my $class = shift;
    my $filename = shift;
    my $analysis = shift;
    my $fh = new IO::File( $filename, "r" ) or die $!;
    my $line;
    my @header;
    my @results;

    while ( $line = $fh->getline() ) {
	chomp($line);
                if ($line =~ /^Sample.*RefKmerPercent$/) {
		    #Header row
		    @header = split(/\t/, $line);
                } else {
		    @results = split(/\t/, $line);
		    
		    if (@header==@results) {
			for (my $i=0;$i<@results;$i++) {
			    if ($header[$i] =~ /Program/) {
				$analysis->add_property($results[$i], "0.1");
				$analysis->add_property("tool", $results[$i]);
			    } elsif ($header[$i] =~ /Reference/) {
				$analysis->add_property("reference",$results[$i]);
			    } elsif ($header[$i] =~ /^Sample$/) {
				$analysis->add_property("sample",$results[$i]);
			    } elsif (defined $value_keys{$header[$i]}) {
				if ($results[$i] =~ /,/) { $results[$i] =~ tr/,//d; }
				$analysis->add_general_value($value_keys{$header[$i]}, $results[$i]);
			    }
			}
		    }

		}
    }

    while ((my $key, my $value) = each(%values)){
	$analysis->add_valid_type($key, $value);
    }

    return $analysis;
}

