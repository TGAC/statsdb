#!/usr/bin/env perl

use Getopt::Long;

use strict;
use File::stat;
use QCAnalysis::FastQC;
use QCAnalysis::KmerContamination;
use QCAnalysis::InterOp;
use QCAnalysis::MISO;
use QCAnalysis;
use QCAnalysis::DB;
use QCAnalysis::RunTable;
use Timecode;

use HTTP::Request;
use LWP::UserAgent;
#use warning;

my %arguments = ();

my $opt_ret = GetOptions( \%arguments, 'input=s', 'db_config=s' );

print "Input: " . $arguments{input} . "\n";
print "DB configuration: ". $arguments{db_config}."\n";
my $input = $arguments{input};

my $line;
my $module;
my $status;
my $config = $arguments{db_config};

my $db = QCAnalysis::DB->new();

# Most likely a bit of 'fossil' code. Commented out to prevent confusion.
#QCAnalysis::RunTable->add_header_scope("barcode", "analysis");

my @analysis = QCAnalysis::RunTable->parse_file($input); 

$db->connect($config);

ANALYSIS: foreach(@analysis) {
    my $analysis = $_;
    my $analysis_path = $_->get_property("path_to_analysis");
    my $analysis_type = $_->get_property("analysis_type");
    print "path : ".$analysis_path."\n";
    print "type : ".$analysis_type."\n";
    
    # Check that the current type of analysis hasn't been effectively disabled
    # It may be that all of the data types associated with this type of analysis have been disabled in the
    # data types config. If so, we cannot allow this analysis to be inserted, since it will contain no useful
    # data, and will therefore cause nothing but confusion.
    # We can figure this out from the path and the listed analysis type. The $db object has a function to do that.
    my $skip = $db->data_enabled_check($analysis_type,$analysis_path);
    unless ($skip eq 1) {
	print "WARN: No data types for this analysis enabled in the data config file. Proceeding with next analysis.\n";
	next ANALYSIS;
    }
    
    # Get the various timestamps associated with this analysis.
    # Also checks if the run is complete!
    my $date_check = Timecode->get_dates($analysis);
    unless ($date_check eq 1) {
	print "Timestamp check error:\n$date_check";
	#next ANALYSIS;
    }
    
    if (-e $analysis_path) {
	for ($analysis_type) {
	    if (/^FastQC$/) {
		QCAnalysis::FastQC->parse_file($analysis_path, $analysis);
		$db->insert_analysis($analysis);
	    }
	    elsif (/^KmerContamination$/) {
		QCAnalysis::KmerContamination->parse_file($analysis_path, $analysis);
		$db->insert_analysis($analysis);
	    }
	    elsif (/^InterOp$/) {
		# The InterOp parser is designed to return multiple analysis objects from a single
		# file. Submit each on its own.
		my $InterOp_analyses = QCAnalysis::InterOp->parse_file($analysis_path, $analysis);
		if (ref($InterOp_analyses) eq 'ARRAY') {
		    foreach my $individual_analysis (@$InterOp_analyses) {
			$db->insert_analysis($individual_analysis);
		    }
		}
		else {
		    # If $InterOp_analyses is an array ref, it contains analysis objects
		    # that can be inserted into the database.
		    # If not, it contains an informative error message.
		    print "$InterOp_analyses\n\n";
		}
		
	    }
	    elsif (/^MISO$/) {
		my $miso = QCAnalysis::MISO->new($db);
		if (ref($miso)) {
		    $miso->add_miso_data($analysis);
		    $db->insert_analysis($analysis);
		}
		else {
		    # If the MISO constructor doesn't return a reference, it has failed to establish
		    # a connection. Throw a warning (supplied in $miso).
		    print "$miso\n\n";
		}
		
	    }
	    else {
		print "WARN: Unknown analysis type [$analysis_type]\n";
	    }
	}
    }
    else {
	print "WARN: Unable to read file\n";
    }

}

$db->disconnect();
