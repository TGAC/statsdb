#!/usr/bin/perl -w
use strict;
use Getopt::Long;
use List::Util qw(min max);
use Reports::DB;
use Reports;
use Timecode;


# This script reports a set of simple statistics for runs that have occurred
# within a given time range. A few example data types are included, but this script
# could easily be expanded to handle more.
# See consumer_simple.pl for code in which other data types are retrieved, and
# in which further restrictions on queries - to a single machine, for example -
# are implemented.

# Autoflush stdout
$|++;

system ('clear');

my ($begindate, $enddate, $config, $help) = ();

# Get all flags. Check that the right flags have been used.
my $incorrect_flags = 0;
foreach my $cla (@ARGV) {
  chomp $cla;
  if ($cla =~ /^-[a-zA-Z]/) {
    unless ($cla =~ /^-[hdbe]$/) {
      $incorrect_flags = 1;
      print "Input error:\n  Unknown option '$cla'\n";
    }
  }
  elsif ($cla =~ /^--[a-zA-Z]/) {
    unless ($cla =~ /^--help$|^--db_config$|^--begin$|^--end$/) {
      $incorrect_flags = 1;
      print "Input error:\n  Unknown option '$cla'\n";
    }
  }
}

GetOptions(
  'h|help'         => \$help,
  'd|db_config=s'  => \$config,
  'b|begin=s'      => \$begindate,
  'e|end:s'        => \$enddate
);

# Call help if -h is used, or if incorrect flags are set
if (($help) || ($incorrect_flags == 1)) {
  die
  "HELP FOR MONTHLY STATS CONSUMER\n
This script returns summary statistics for the runs on record within
a time interval specified by two dates or timestamps.
-----
Calling StatsDB Perl consumer with command line options:
  -d or --db_config  Database connection specification file (required)
  
  -b or --begin      Beginning of a date range (required)
  -e or --end        End of a date range (optional)
                      (If -b supplied and -e not, all data between
                       -b [date] and current time is returned)
Examples:
- Query between two dates:
 perl monthly_stats.pl -d examples/template_db.txt -b \"15/7/13\" -e \"30/7/2013\"

- Query between two dates, also specifying times:
 perl monthly_stats.pl -d examples/template_db.txt -b \"15/7/13 17:19:21\" -e \"30/7/2013 18:00:36\"

Note that double-quotes around date/time values are recommended.
-----
Output consists of a list of runs, followed by a simple table listing
summary statistics.
-----
Warning: If non-standard QC and primary analyses (for example, RADplex
demultiplexing) are carried out on any of the runs within the time
interval, the number of samples stored in StatsDB may be lower than that
actually produced by the QC/PA pipeline, since this data is not auto-
matically entered into the database.

";
}

# Parse supplied dates
my $timestamp1 = Timecode::parse_input_date($begindate);
my $timestamp2 = Timecode::parse_input_date($enddate);

# Connect to database, load API objects
GetOptions();
print "DB configuration: ". $config."\n";
my $db = Reports::DB->new($config);
my $reports = Reports->new($db);

# get_runs_between_dates does what it says on the tin.
print "Runs between\n\t$timestamp1\tand\n\t$timestamp2...\n";
my $qry = $reports->get_runs_between_dates($timestamp1, $timestamp2);
my $rir = $qry->to_csv;
my @runs_in_range = split /\s/, $rir;
my $colheads = shift @runs_in_range;
my $total_runs = @runs_in_range;

# Set up some totals, then cycle runs and collect relevant data for each run.
# If adding new statistics to be added up, initialise them here.
my ($total_bases, $total_sequences, $total_samples) = 0;
my (@numseqs, @readlengths, @numbases, @numsamples) = ();

my $c = 0;
foreach my $runID (@runs_in_range) {
  $c ++;
  print "RUN $runID\t($c of $total_runs)\n";
  
  # Get some summary stats 
  # Those come from passing the relevant data to get_average_values
  # (In order to restrict queries to - for example - a particular machine, further
  # parameters could be added to %query_properties)
  my %query_properties = (
    RUN   => $runID
  );
  my $qry = $reports->get_average_values(\%query_properties);
  my $avg = $qry->to_csv;
  my @returned_values = split /\n/, $avg;
  shift @returned_values;
  
  # Rows: min seq length, total seqs, gc content, filtered seqs, max seq length,
  # total duplicate read percentage
  # Set up summary data hash to store this (and other) properties of this query
  my %summarydata = ();
  # I need the number of sequences in this run to continue to be available once
  # we get to the max length row. Set a variable here
  my ($thisrun_seqs, $thisrun_readlength, $thisrun_bases, $thisrun_samples) = ();
  my $rownum = 0;
  foreach my $row (@returned_values) {
    $rownum ++;
    my @dat = split /,/, $row;
    my $desc    = $dat [0];
    my $average = $dat [1];
    my $samples = $dat [2];
    my $total   = $dat [3];
    
    if ($desc eq 'general_total_sequences') {
      $total_sequences += $total;
      $thisrun_seqs = $total;
    }
    
    # Note that this calculation gives an accurate number of bases for this run
    # only for Illumina runs at the moment, since Illumina read length is fixed
    # to the value in this field.
    if ($desc eq 'general_max_length') {
      $thisrun_readlength = $average;
      $thisrun_bases = $thisrun_seqs * $average;
      $total_bases += $thisrun_bases;
    }
    
    # When counting samples, the number is the same on all rows;
    # it only needs to be counted once, so only pick one row to count at.
    if ($rownum == 1) {
      $total_samples += $samples;
      $thisrun_samples = $samples;
    }
  }
  
  # Put this run's num bases, mean read length, num sequences and num samples in
  # an array so I can get average values of each later on.
  push @numseqs, $thisrun_seqs;
  push @readlengths, $thisrun_readlength;
  push @numbases, $thisrun_bases;
  push @numsamples, $thisrun_samples;
  
  
  
  ##########################
  # Could add some further #
  # queries here for more  #
  # advanced summary stats #
  ##########################
  
}

# Start outputting the retrieved figures here
print "\n\nTOTALS
Runs\t\t$total_runs
Bases\t\t$total_bases (".mean(\@numbases)." +/- ".(int stdev(\@numbases) * 2)." per run)
Sequences\t$total_sequences (".(int mean(\@numseqs))." +/- ".(int stdev(\@numseqs) * 2)." per run)
Samples\t\t$total_samples (".(int mean(\@numsamples))." per run)

AVERAGES
Read length\t".(int mean(\@readlengths))."\n\n";

#Phred quality\t".."
#Error rate\t".."
#\n";





sub mean {
  my $in = $_[0];
  
  if (!$in) {
    return 0;
  }
  my @data = @$in;
  if (@data == 0) {
    return 0;
  }
  
  my $total = sum (\@data);
  my $mean = $total / @data;
  return $mean;
}

sub stdev {
  my $in = $_[0];
  
  if(@$in <= 1){
    return 0;
  }
  
  my $mean = mean($in);
  my @sq_dfms = ();
  foreach my $i (@$in) {
    my $sq_dfm = ($mean - $i) ** 2;
    push @sq_dfms, $sq_dfm;
  }
  
  my $std = sqrt mean(\@sq_dfms);
  return $std;
}

sub sum {
  my $in = $_[0];
  my $total = 0;
  foreach my $i (@$in) {
    $total += $i;
  }
  return $total;
}

