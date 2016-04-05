#!/usr/bin/perl -w
use strict;
use Getopt::Long;
use List::Util qw(min max);
use Text::Wrap qw(wrap);
use Reports::DB;
use Reports;

# This is used when printing out long strings, e.g., the program's inbuilt
# help.
$Text::Wrap::columns = 90;

# This is a script to delete an analysis and all of its related records from
# the database.

# This function is kept separate because it's really something that users
# should have to go slightly out of their way to use in most circumstances.

# To use, simply pass a single analysis ID. 

# First, retrieve passed parameters
# Also, supply help if asked
my ($help, $config, $analysis) = ();

# Get all flags. Check that the right flags have been used.
my $incorrect_flags = 0;
foreach my $cla (@ARGV) {
  chomp $cla;
  if ($cla =~ /^-[a-zA-Z]/) {
    unless ($cla =~ /^-[hda]$/) {
      $incorrect_flags = 1;
      print "Input error:\n  Unknown option '$cla'\n";
    }
  }
  elsif ($cla =~ /^--[a-zA-Z]/) {
    unless ($cla =~ /^--help$|^--db_config$|^--analysis$/) {
      $incorrect_flags = 1;
      print "Input error:\n  Unknown option '$cla'\n";
    }
  }
}

GetOptions(
  'h|help'         => \$help,
  'd|db_config=s'  => \$config,
  'a|analysis=s'   => \$analysis,
);

unless ($analysis =~ /^[0-9]+$/) {
  die "Analysis ID (-a or --analysis) parameter must be an integer!\n";
}

# Call help if -h is used, or if incorrect flags are set
if (($help) || ($incorrect_flags == 1)) {
  die wrap ('', '', 
  "HELP FOR STATSDB RECORD DELETER
This script removes all data corresponding to a single analysis ID from the database.

Deleting records is PERMANENT! Deleted records can ONLY be recovered by restoring a backup of the database or by re-inserting the original data. 
-----
StatsDB deleter command line options:
  -d or --db_config   Database connection specification file (required)
  -a or --analysis    Analysis ID to be deleted (required)
-----
");
}

# Connect to the DB
GetOptions();
print "DB configuration: ". $config."\n";
my $db = Reports::DB->new($config);
my $reports = Reports->new($db);

# Populate the query properties hash with supplied values (DBI cleverly deals with non-
# supplied fields in the appropriate way).
my %input_values = ();
$input_values{ANALYSIS} = $analysis; 

# Check that the input analysis passed does, in fact, exist.
my $check = $reports->check_analysis_id(\%input_values);
my $avg = $check->to_csv;
my @returned_values = split /\s/, $avg;
my $colheads = shift @returned_values;

# Only one column is returned by this query, and it's an integer.
# If greater than 0, the record is in the database.
$check = shift @returned_values;

if ($check > 0) {
  my $con = $reports->get_connection();
  my $statement = "CALL delete_analysis(?)";
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->bind_param(1, $analysis);
  $sth->execute();
  # DELETE produces no output, so there is no point checking it.
  print "Analysis $analysis deleted\n";
}
else {
  die wrap ('','',"Analysis ID $analysis not found in the database\n");
}