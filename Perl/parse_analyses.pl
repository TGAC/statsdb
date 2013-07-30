#!/usr/bin/env perl

use Getopt::Long;

use strict;
use File::stat;
use Time::localtime;
use QCAnalysis::FastQC;
use QCAnalysis::KmerContamination;
use QCAnalysis;
use QCAnalysis::DB;
use QCAnalysis::RunTable;

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
QCAnalysis::RunTable->add_header_scope("barcode", "analysis");

my @analysis =  QCAnalysis::RunTable->parse_file($input); 

$db->connect($config);

foreach(@analysis) {
    my $analysis = $_;
    my $analysis_path = $_->get_property("path_to_analysis");
    my $analysis_type = $_->get_property("analysis_type");

    print "path : ".$analysis_path."\n";
    print "type : ".$analysis_type."\n";

    if ( -e $analysis_path) {
	for ($analysis_type) {
	    if (/^FastQC$/) { QCAnalysis::FastQC->parse_file($analysis_path, $analysis); $db->insert_analysis($analysis); }
	    elsif (/^KmerContamination$/) { QCAnalysis::KmerContamination->parse_file($analysis_path, $analysis); $db->insert_analysis($analysis); }
	    else { }
	}
    } else {
	print "WARN: Unable to read file\n";
    }

}

$db->disconnect();
