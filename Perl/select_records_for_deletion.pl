#!/usr/bin/perl -w
use strict;
use Getopt::Long;
use List::Util qw(min max);
use Text::Wrap qw(wrap);
use Reports::DB;
use Data::Dumper;
use Reports;
use Consumers;

# This is used when printing out long strings, e.g., the program's inbuilt
# help.
$Text::Wrap::columns = 90;

# This is a script to find and delete analyses in a more human-friendly way.

# This function is kept separate because it's really something that users
# should have to go slightly out of their way to use in most circumstances.

# I'm also going to use this to try out consumer functions through
# Consumers.pm which will later be rolled out across the other existing
# scripts.
# Make an array listing options this parser should be allowed to take!
my @opts = (
  'analysis',
  'instrument',
  'run',
  'pseq',
  'lane',
  'pair',
  'sample_name',
  'barcode',
  'begin',
  'end',
  'datetype',
  'tool'
);

# Check the flags supplied match those just specified
my $incorrect_flags = Consumers::check_for_incorrect_flags(\@ARGV, \@opts);

# Get command line arguments, and submit them (and the list of active
# arguments) to be parsed in.
my $args = Getopt::Long::Parser->new;
my ($input_values, $help_string) = Consumers::deal_with_inputs($args,\@opts);

# The query scope input needs to be set to sample_name or barcode here.
# Having it set to higher levels of classification interferes with the
# ability to display records that will be deleted.
$input_values->{QSCOPE} = 'sample_name';

# Print help if -h is used, or if incorrect flags are set
if (($input_values->{HELP}) || ($incorrect_flags == 1)) {
  die wrap ('', '', 
  "\nHELP FOR STATSDB RECORD DELETER
This script removes all data corresponding to a single analysis ID from the database.

Deleting records is PERMANENT! Deleted records can ONLY be recovered by restoring a backup of the database or by re-inserting the original data. 
-----
StatsDB deleter command line options:
$help_string
-----
");
}

# Connect to the database
GetOptions();
print "DB configuration: ".$input_values->{DB_CONFIG}."\n";
my $db = Reports::DB->new($input_values->{DB_CONFIG});
my $reports = Reports->new($db);

my $confuncs = Consumers->new($reports);

# As validation, and for user confirmation, list all the records
# in the database that correspond to the input list of parameters.
my $qry = $reports->list_subdivisions($input_values);
my $avg = $qry->to_csv;

# Print it all out
# TODO: Try to work in a way of displaying 'tool' field, because that is
# useful information in this context.
my $table = $confuncs->make_printable_table($avg);

# Check that the user REALLY wants to delete all that
print "$table\n
the above records will be permanently deleted.
Type \"Delete these records\" to continue:\n\n";

my $check = <STDIN>;
chomp $check;

unless ($check =~ /Delete these records/) {
  die "Delete aborted\n";
}

# Get analysis IDs of selected records
$qry = $reports->get_analysis_id($input_values);
$avg = $qry->to_csv;
my ($column_headers,$returned_values) = $confuncs->parse_query_results(\$avg);

foreach my $line (@$returned_values) {
  my $analysis_id = $line->[0];
  my $delete_command = "perl delete_analysis.pl --db_config ".
  $input_values->{DB_CONFIG}." --analysis $analysis_id";
  `$delete_command`;
  print "Analysis $analysis_id deleted\n";
}
