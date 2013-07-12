#!/bin/perl

use Getopt::Long;

use strict;
use File::stat;
use Time::localtime;
use QCAnalysis::FastQC;
use QCAnalysis;
use QCAnalysis::DB;
use QCAnalysis::RunTable;



#use warning;

my %arguments = ();

my $opt_ret = GetOptions( \%arguments, 'input=s', 'db_config=s' );

print "Input: " . $arguments{input} . "\n";
#print "Sample ID: " . $arguments{sample} . "\n";
print "DB configuration: ". $arguments{db_config}."\n";
my $input = $arguments{input};

my $line;
my $module;
my $status;
my $config =  $arguments{db_config};

#my $analysis = QCAnalysis->new();
my $db = QCAnalysis::DB->new();

QCAnalysis::RunTable->add_header_scope("barcode", "analysis");

my @analysis =  QCAnalysis::RunTable->parse_file($input); 

#my $fast_qc_file = $analysis->get_property("path_to_fastqc");
#QCAnalysis::FastQC->parse_file($fast_qc_file, $analysis);

$db->connect($config);
foreach(@analysis) {
 #  print "Anaysis: ".$_;
    my $analysis_path = $_->get_property("path_to_analysis");
    my $analysis_type = $_->get_property("analysis_type");
    
    if ( -e$ analysis_path) {
	for ($analysis_type) {
	    if (/^FastQC$/) { QCAnalysis::FastQC->parse_file($analysis_path, $_); $db->insert_analysis($_); }
	    elsif (/^KmerContamination$/) { QCAnalysis::KmerContamination->parse_file($analysis_path, $_); $db->insert_analysis($_); }
	    else { }
	}
    } else {
	print "WARN: Unable to read file $fast_qc_file\n";
    }

}

$db->disconnect();
