#!/usr/bin/perl -w
use strict;
use Getopt::Long;
use List::Util qw(min max);
use Reports::DB;
use Reports;


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
- Query between two dates (most common usage):
 perl monthly_stats.pl -d examples/live_db.txt -b \"15/7/13\" -e \"30/7/2013\"

- Query between two dates, also specifying times:
 perl monthly_stats.pl -d examples/live_db.txt -b \"15/7/13 17:19:21\" -e \"30/7/2013 18:00:36\"

Note that doublequotes around date-time values are recommended.
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
my $timestamp1 = parse_input_date ($begindate);
my $timestamp2 = parse_input_date ($enddate);

# Connect to database, load API objects
GetOptions();
print "DB configuration: ". $config."\n";
my $db = Reports::DB->new($config);
my $reports = Reports->new($db);

# get_runs_between_dates does what it says on the tin.
print "GETTING RUNS...\n";
my $qry = $reports->get_runs_between_dates($timestamp1, $timestamp2);
my $rir = $qry->to_csv;
my @runs_in_range = split /\s/, $rir;
my $colheads = shift @runs_in_range;
my $total_runs = @runs_in_range;

# Set up some totals, then cycle runs and collect relevant data for each run.
# If adding new statistics to be added up, initialise them here.
my $total_bases = 0;
my $total_sequences = 0;
my $total_samples = 0;

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
  my $num_seqs = 0;
  foreach my $row (@returned_values) {
    my @dat = split /,/, $row;
    my $desc  = $dat [0];
    my $avg   = $dat [1];
    my $count = $dat [2];
    my $sum   = $dat [3];
    
    if ($desc eq 'general_total_sequences') {
      $total_sequences += $sum;
      $num_seqs = $sum;
    }
    if ($desc eq 'general_max_length') {
      my $num_bases = $num_seqs * $avg;
      $total_bases += $num_bases;
    }
    
    # When counting samples, the number is the same on all rows;
    # it only needs to be counted once, so only pick one row to count at.
    if ($desc eq 'general_min_length') {
      $total_samples += $count;
    }
  }
}
print "\n\nTotal number of
Runs\t\t$total_runs
Bases\t\t$total_bases
Sequences\t$total_sequences
Samples\t\t$total_samples
\n";

sub add_leading_zeros {
  my $string = $_[0];
  my $desired_length = $_[1];
  
  while (length $string < $desired_length) {
    $string = "0$string";
  }
  return $string;
}

sub present_time {
  # Returns the current time and date, in this format:
  # 30-7-2013 18:00:36
  my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime (time);
  $year += 1900;
  $mon ++;
  
  #return localtime (time);
  return "$mday-$mon-$year $hour:$min:$sec";
}

sub check_date_input_format {
  # Check that an inputted date is in a roughly suitable format
  # Die if it's not, with a helpful error message
  my $indate = $_[0];
  
  # Unless $indate =~ (2/4 or 02/04)
  #                   or (2/4/14 or 02/04/14)
  #                   or (2/4/2014 or 02/04/2014)
  # dashes can also be used
  unless ($indate =~ /^[0-9]{1,2}[\/\-][0-9]{1,2}$|^[0-9]{1,2}[\/\-][0-9]{1,2}[\/\-][0-9]{2,4}$/) {
    # If we're in here, we've got a date format I don't expect.
    die "Unexpected input date format\n  ($indate)\nSee help (run with flag -h) for correct formats\n\n";
  }
  
  # The above does not make a few other checks for obviously silly values resulting from typos and such
  my ($inday, $inmon, $inyr) = split /\/|\-/, $indate;
  my ($day, $mnt, $yr, $time) = split / /, present_time();
  if ($inday > 31) { die "Probable typo: input day number ($inday) greater than 31\n\n"; }
  if ($inmon > 12) { die "Probable typo: month number ($inmon) greater than 12\n\n"; }
  if ($inyr) {
    if ($inyr > $yr) { die "Probable typo: input year number ($inyr) greater than current year\n\n"; }
    if (length $inyr == 3) { die "Probable typo: input year number ($inyr) has only 3 digits\n\n"; }
  }
}

sub standardise_date_input_format {
  # Add leading zeros, correct century number etc. so that dates are all
  # in the same, correct format.
  # MySQL is probably clever enough to figure it out if I supply it the normal
  # human-readable way, but why take a chance?
  my $indate = $_[0];
  my ($day, $mnt, $yr, $time) = split /[\s\-]/, present_time();
  
  my ($inday, $inmon, $inyr) = split /\/|\-/, $indate;
  $inday = add_leading_zeros ($inday, 2);
  $inmon = add_leading_zeros ($inmon, 2);
  
  if (!$inyr) { $inyr = $yr; }
  if (length $inyr == 2) {
    my @yr = split //, $yr;
    $inyr = $yr[0].$yr[1].$inyr;
  }
  
  # Remember that in the database, records are stored YYYY-MM-DD
  return "$inyr-$inmon-$inday";
}

sub check_input_time_format {
  # Check that the input time, if any, matches either the hh:mm or hh:mm:ss format
  # Die if it doesn't
  my $intime = $_[0];
  
  unless ($intime =~ /^[0-9]{2}:[0-9]{2}$|^[0-9]{2}:[0-9]{2}:[0-9]{2}$/) {
    die "Input time ($intime) does not match expected format.\nSee help (run with flag -h) for correct formats\n\n";
  }
}

sub parse_input_date {
  # Wrangle the supplied dates - probably in the sensible DD/MM/YYYY format
  # - into the timestamp format used in the database.
  my $indate = $_[0];
  
  # Date may not be set. If it isn't set, fill it up.
  if (!$indate) { $indate = present_time(); }
  
  # Date may be supplied with a time code as well.
  # If it is, it should be checked, set aside and added back on later.
  # If not, add a midnight time (00:00:00).
  
  my ($date, $time) = split /\s/, $indate;
  check_date_input_format ($date);
  $date = standardise_date_input_format($date);
  if (!$time) { $time = "00:00:00"; }
  else        { check_input_time_format($time) }
  
  return "$date $time";
}