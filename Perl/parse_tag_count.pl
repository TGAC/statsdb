#!/bin/perl

use Getopt::Long;

use strict;
use File::stat;
use Time::localtime;
use QCAnalysis;
use QCAnalysis::TagCount;
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

my @analysis =  QCAnalysis::RunTable->parse_file( $input); 


$db->connect($config);
foreach(@analysis){
   print "Anaysis: ".$_;
   my $fast_qc_file = $_->get_property("path_to_counts");
	
   QCAnalysis::TagCount->parse_file($fast_qc_file, $_);
   $db->insert_analysis($_);
}
$db->disconnect();