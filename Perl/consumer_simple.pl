#!/usr/bin/perl -w
use strict;
use Getopt::Long;
use List::Util qw(min max);
use Reports::DB;
use Reports;
use Timecode;
use Text::Wrap qw(wrap);

# This is used when printing out long strings, e.g., the program's inbuilt
# help.
$Text::Wrap::columns = 90;

# This is a consumer designed specifically to retrieve data parsed from
# FastQC analysis. 
# This simpler version of the StatsDB consumer shows how data is retrieved, and
# is well suited to modification for alternative output formats, or simply
# retrieving stored data in text format. 

system ('clear');

# First, retrieve passed parameters
# Also, supply help if asked
my $queryscope = 'na';
my ($help, $config, $instrument, $run, $lane, $pair,
    $sample, $barcode, $begindate, $enddate) = ();

# Get all flags. Check that the right flags have been used.
my $incorrect_flags = 0;
foreach my $cla (@ARGV) {
  chomp $cla;
  if ($cla =~ /^-[a-zA-Z]/) {
    unless ($cla =~ /^-[hdirlpsbq]$/) {
      $incorrect_flags = 1;
      print "Input error:\n  Unknown option '$cla'\n";
    }
  }
  elsif ($cla =~ /^--[a-zA-Z]/) {
    unless ($cla =~ /^--help$|^--db_config$|^--instrument$|^--run$|^--lane$|^--pair$|^--sample$|^--barcode$|^--scope$/) {
      $incorrect_flags = 1;
      print "Input error:\n  Unknown option '$cla'\n";
    }
  }
}

GetOptions(
  'h|help'         => \$help,
  'd|db_config=s'  => \$config,
  'i|instrument:s' => \$instrument,
  'r|run:s'        => \$run,
  'l|lane:s'       => \$lane,
  'p|pair:s'       => \$pair,
  's|sample:s'     => \$sample,
  'b|barcode:s'    => \$barcode,
  'q|scope:s'      => \$queryscope,
  'c|begin:s'      => \$begindate,
  'e|end:s'        => \$enddate
);

# Call help if -h is used, or if incorrect flags are set
if (($help) || ($incorrect_flags == 1)) {
  die wrap ('','',
  "HELP FOR STATSDB CONSUMER
This script simply retrieves QC data associated with specific analyses corresponding to the inputs described below.
-----
Calling StatsDB Perl consumer with command line options:
  -d or --db_config   Database connection specification file (required)
  -i or --instrument  Instrument name (optional)
  -r or --run         Run ID (optional)
  -l or --lane        Lane (optional)
  -p or --pair        Read (optional)
  -b or --barcode     Barcode  (optional)
  -s or --sample      Sample name  (optional)
  -q or --scope       Query scope (optional)
  -c or --begin       Begin date, when selecting data based upon run date (optional)
  -e or --end         End date, when selecting data based upon run date (optional)
-----
Available query scopes:
      instrument
      run
      lane
      pair
      sample_name
      barcode
-----
To produce QC overviews for each sample in a given run, for example, specify a run with the -r flag, and set the scope of the query to 'sample'. This produces a set of reports - one for each sample - in a single PDF. If the query scope is unspecified, a single report (consisting of readings averaged across the whole run) is produced instead.
-----
Output to the command line consists of the data used to generate the report, and may be redirected to a file by adding ' > file.txt' to the end of the command used to call this script.\n\n");
}


GetOptions();
print "DB configuration: ". $config."\n";
my $db = Reports::DB->new($config);
my $reports = Reports->new($db);

# It used to be that at least one of $instrument and $run must be set.
# Since a user can now query all runs within a given time frame
# across more than one machine, though, I can switch this off.
#unless ($run || $instrument) {
#  die "A run ID (-r) or an instrument name (-i) parameter must be passed.\n";
#}

# Populate the query properties hash with supplied values (DBI cleverly deals with non-
# supplied fields in the appropriate way).
my %input_values = ();
if ($instrument) { $input_values{INSTRUMENT} = $instrument; }
if ($run)        { $input_values{RUN} = $run; }
if ($lane)       { $input_values{LANE} = $lane; }
if ($pair)       { $input_values{PAIR} = $pair; }
if ($barcode)    { $input_values{BARCODE} = $barcode; }
if ($sample)     { $input_values{SAMPLE_NAME} = $sample; }
$input_values{TOOL} = 'FastQC';

# Handle date-times, if any are supplied as inputs
if ($begindate || $enddate) {
  my $timestamp1 = Timecode::parse_input_date($begindate);
  my $timestamp2 = Timecode::parse_input_date($enddate);
  
  $input_values{DATE1} = $timestamp1;
  $input_values{DATE2} = $timestamp2;
}

# Check that query scope (if passed) is set to a sensible value.
# $queryscope should also be modified slightly to reflect column names
# in the actual database
chomp $queryscope;
$queryscope =~ s/\'//g;
$queryscope = lc $queryscope;
unless ($queryscope =~ /^instrument$|^run$|^lane$|^sample$|^sample_name$|^barcode$|^read$|^pair$|^na$/) {
  die "Query scope should be set to one of:\ninstrument\nrun\nlane\nsample_name\nbarcode\nread\nor left unset\n";
}
if ($queryscope =~ /sample/) { $queryscope = 'sample_name'; }
if ($queryscope =~ /read/)   { $queryscope = 'pair'; }
$input_values{QSCOPE} = $queryscope; 

# Check that the input parameters passed do, in fact, exist.
# If they don't, bail. 
my $check = check_validity (\%input_values);
print "$check\n\n";

# Per-sample querying relies upon the sample's barcode being present.
# If it's not supplied, find it.
# Bear in mind that if a sample is not from a multiplexed run, there
# won't be a barcode listed. 
if (($sample) && (!$barcode)) {
  $barcode = get_barcode_for_sample ($sample);
  $input_values{BARCODE} = $barcode;
}


# Plan the set of queries for the consumer to go through (if more than one).
# If no query scope is set, then a single query is carried out, based on the
# run, lane, sample, read etc. supplied.

# If the queryscope value is set, though, a query set should be constructed.
# Think of a way of doing this which is scale-agnostic. Use the database!
# I made a sub in the API called list_subdivisions to do just that.

# Store queries as hash references.
my @query_sets = ();
if ($queryscope eq 'na') {
  my %qry = %input_values;
  push @query_sets, \%qry;
}
else {
  print "Preparing query sets\n";
  my $qry = $reports->list_subdivisions(\%input_values);
  my $avg = $qry->to_csv;
  my ($column_headers,$returned_values) = parse_query_results(\$avg);
  print "@$column_headers\n";
  
  # Make returned column headers upper-case so they match the hash keys used
  # in the API
  foreach my $k (@$column_headers) {
    $k = uc $k;
  }
  
  my $n = 0;
  foreach my $query_set (@$returned_values) {
    $n ++;
    my %qry = ();
    for my $i (1..@$column_headers) {
      $i --;
      my $val = $query_set->[$i];
      my $key = $column_headers->[$i];
      if ($val) { $qry {$key} = $val; }
    }
    
    # Check that if sample names are represented, barcodes are too
    # (Should be dealt with by list_subdivisions, but it never hurts to double-check)
    if (($qry{SAMPLE_NAME}) && (!$qry{BARCODE})) {
      my $bc = get_barcode_for_sample ($qry{SAMPLE_NAME});
      $qry{BARCODE} = $bc;
    }
    
    push @query_sets, \%qry;
    
    print "QUERY $n:\n";
    foreach my $key (keys %qry) {
      if ($qry{$key}) {
        print "\t$key:\t".$qry{$key}."\n";
      }
      else {
        print "\t$key:\tNone specified\n";
      }
    }
  }
}

print "Set up ".@query_sets." query set(s)\n\n";

# Query sets now established. Cycle each one, produce output graphs for each,
# and dump the data into StdOut
my $qnum = 0;
foreach my $query_set (@query_sets) {
  my %query_properties = %$query_set;
  $qnum ++;
  
  # Print something so that results from one query set are distinguishable from another!
  print "=====\nQUERY SET $qnum\n-----\nQuery values\nKEY,VALUE\n";
  foreach my $key (keys %query_properties) {
    my $val = $query_properties{$key};
    print "$key\t$val\n";
  }
  
  # Get some summary stats for this query set:
  # Total sequences, filtered sequences, sequence length, overall % GC
  # Those come from passing the relevant data to get_average_values
  my $qry = $reports->get_average_values(\%query_properties);
  my $avg = $qry->to_csv;
  my ($column_headers,$returned_values) = parse_query_results(\$avg);
  
  # Rows: min seq length, total seqs, gc content, filtered seqs, max seq length,
  # total duplicate read percentage
  # Set up summary data hash to store this (and other) properties of this query set
  my %summarydata = ();
  foreach my $row (@$returned_values) {
    my $desc = $row->[0];
    my $val  = $row->[1];
    $summarydata {$desc} = $val;
  }
  
  # Need an analysis_id number for this query set
  # There may be several. Store them; they can all be queried.
  my $analysis_id = ();
  my @analysis_ids = ();
  
  $qry = $reports->get_analysis_id(\%query_properties);
  $avg = $qry->to_csv;
  @analysis_ids = split /\s/, $avg;
  
  
  # Add filename and file type to %summarydata by querying the analysis_property
  # table. 
  # A complete list of summary properties which might be retrieved in
  # this way can be obtained using the SQL routine list_selectable_properties
  $qry = $reports->get_properties_for_analysis_ids(\@analysis_ids);
  $avg = $qry->to_csv;
  #($column_headers,$returned_values) = parse_query_results(\$avg);
  ##@$returned_values = split /\n/, $avg;
  #
  #print "Querying analysis properties\nPROPERTY,VALUE\n";
  #foreach my $line (@$returned_values) {
  #  my $property = $line->[0];
  #  my $value = $line->[1];
  #  
  #  # Prevent this from producing entries for data that is actually missing.
  #  # (E.g., barcodes, frequently)
  #  if ($value) {
  #    push @{$summarydata{$property}}, $value;
  #    print "$property\t$value\n";
  #  }
  #}
  #print "\n-----\n";
  
  my @returned_values = split /\n/, $avg;
  my $headers = shift @returned_values;
  
  print "Querying analysis properties\nPROPERTY,VALUE\n";
  foreach my $line (@returned_values) {
    my @sp = split /,/, $line;
    my $property = $sp [0]; my $value = $sp [1];
    
    # Prevent this from producing entries for data that is actually missing.
    # (E.g., barcodes, frequently)
    if ($value) {
      push @{$summarydata{$property}}, $value;
      print "$property\t$value\n";
    }
  }
  print "\n-----\n";
  
  # Set up a label to go at the top of the report.
  # Pick sample names, if those are specified.
  # If not, use lanes.
  # If those are missing, use runs, if those are missing use instruments,
  # and if (for some reason) everything is missing, just use a generic
  # string.
  my $queryset_label = ();
  if ($query_properties{SAMPLE_NAME}) {
    $queryset_label = "Sample ".$query_properties{SAMPLE_NAME};
    if ($query_properties{PAIR}) {
      $queryset_label = "$queryset_label, Read ".$query_properties{PAIR};
    }
  }
  elsif ($query_properties{LANE}) {
    $queryset_label = "Lane ".$query_properties{LANE};
    if ($query_properties{BARCODE}) {
      $queryset_label = "$queryset_label, Barcode ".$query_properties{BARCODE};
    }
    if ($query_properties{PAIR}) {
      $queryset_label = "$queryset_label, Read ".$query_properties{PAIR};
    }
  }
  elsif ($query_properties{RUN}) {
    $queryset_label = "Run ".$query_properties{RUN};
  }
  elsif ($query_properties{INSTRUMENT}) {
    $queryset_label = "Instrument ".$query_properties{INSTRUMENT};
  }
  else {
    $queryset_label = "General query";
  }
  
  my $reads_filename = ();
  if ($summarydata{'Filename'}) {
    my @arr = @{$summarydata{'Filename'}};
    if (@arr == 1) { $reads_filename = $arr[0]; }
    else           { $reads_filename = "Multiple files"; }
  }
  else { $reads_filename = "  "; }
  
  # A list of data types falling into classes along the read length
  # (Grouped together this way for convenient handling - they're all treated the same)
  my @per_position_value_types = (
    'quality_mean',
    'quality_lower_quartile',
    'quality_upper_quartile',
    'quality_median',
    'quality_10th_percentile',
    'quality_90th_percentile',
    'base_content_a',
    'base_content_c',
    'base_content_t',
    'base_content_g',
    'gc_content_percentage',
    'base_content_n_percentage'
  );
  
  # Store all that lovely data in a single data structure.
  my %qualdata = ();
  my @base_intervals = ();
  my @interval_names = ();
  foreach my $valtype (@per_position_value_types) {
    print "Querying $valtype\n";
    
    my $qry = $reports->get_per_position_values($valtype, \%query_properties);
    my $dat = $qry->to_csv;
    my ($column_headers,$returned_values) = parse_query_results(\$dat);
    
    print "@$column_headers\n";
    
    if (@$returned_values >= 1) {
      foreach my $row (@$returned_values) {
        # Do something about the large number of decimal places. 3 ought to be plenty.
        foreach my $val (@$row) {
          unless ($val =~ /[[:alpha:]]/) {
            if ($val != int $val) {
              $val = sprintf '%.3f', $val;
            }
          }
        }
        
        # Store the base interval of this particular record
        # Give as an interval, if possible.
        my $basepos = $row->[0];
        my $interval_name = $basepos;
        if ($base_intervals [-1]) {
          if ($base_intervals [-1] < ($basepos - 1)) {
            $interval_name = ($base_intervals [-1] + 1)."-$basepos";
          }
        }
        push @interval_names, $interval_name;
        push @base_intervals, $basepos;
        
        # Store the actual data in a hash of arrays, according to type
        # (It's pretty easy to retrieve later)
        # Column 3 holds the data.
        push @{$qualdata{$valtype}}, $row->[2];
        
        my $pout = join "\t", @$row;
        print "$pout\n";
      }
      print "\n-----\n";
    }
    else {
      print "No values found in database\n";
    }
  }
  
  @interval_names = remove_duplicates (@interval_names);
  @base_intervals = remove_duplicates (@base_intervals);
  
  # Other data types that don't fall into classes along the length of
  # the reads need to be handled differently. Each might have its own
  # x-axis scales, so those should be stored independently. 
  my @other_value_types = (
    'quality_score_count',
    'gc_content_count',
    'sequence_length_count',
    'duplication_level_relative_count'
  );
  
  my %independent_interval_names = ();
  foreach my $valtype (@other_value_types) {
    print "Querying $valtype\n";
    
    my $qry = $reports->get_per_position_values($valtype, \%query_properties);
    my $dat = $qry->to_csv;
    my ($column_headers,$returned_values) = parse_query_results(\$dat);
    
    print "@$column_headers\n";
    
    # X axis values for these plots are single figures, rather than
    # intervals. That means no other manipulation is necessary.
    my @xvals = ();
    
    if (@$returned_values >= 1) {
      foreach my $row (@$returned_values) {
        # Do something about the large number of decimal places. 3 ought to be plenty.
        foreach my $val (@$row) {
          unless ($val =~ /[[:alpha:]]/) {
            if ($val != int $val) {
              $val = sprintf '%.3f', $val;
            }
          }
        }
        
        # Store the base interval of this particular record
        # Give as an interval, if possible.
        my $xval = $row->[0];
        push @xvals, $xval;
        # (Should be dealt with by list_subdivisions, but it never hurts to double-check)
        
        # Store the actual data in a hash of arrays, according to type
        # (It's pretty easy to retrieve later)
        # Column 3 holds the data.
        push @{$qualdata{$valtype}}, $row->[2];
        
        my $pout = join "\t", @$row;
        print "$pout\n";
      }
      
      @{$independent_interval_names{$valtype}} = @xvals;
      print "\n-----\n";
    }
    else {
      print "No values found in database\n";
    }
  }
  
  # Also, get overrepresented sequences, if any.
  my %overrepresented_sequences = ();
  $qry = $reports->get_summary_values_with_comments('overrepresented_sequence', \%query_properties);
  my $dat = $qry->to_csv;
  ($column_headers,$returned_values) = parse_query_results(\$dat);
  
  print "Overrepresented sequences:\nSequence\tComment\n";
  foreach my $ors (@$returned_values) {
    my $seq = $ors->[0];
    
    my @shorten_row = @$ors;
    for (1..4) { pop @shorten_row; }
    my $comment = join ' ', @shorten_row;
    print "$seq";
    if ($comment) { print "\t$comment"; }
    print "\n";
    
    push @{$overrepresented_sequences{"seqs"}}, $seq;
    if ($comment) { push @{$overrepresented_sequences{"comments"}}, $comment; }
    else          { push @{$overrepresented_sequences{"comments"}}, " "; }
  }
  if (@$returned_values == 0) {
    print "None\n";
  }
  
  print "\n-----\n";
  
  ##################################
  ##################################
  ##                              ##
  ## Code for more complex output ##
  ## can be added here!           ##
  ##                              ##
  ##################################
  ##################################
  
  
  
  
}

$db->disconnect();

print "Retrieval of data complete\n";


sub get_barcode_for_sample {
  my $samp = $_ [0];
  
  my $qry = $reports->get_barcodes_for_sample_name($samp);
  my $dat = $qry->to_csv;
  my @returned_values = split /\s/, $dat;
  
  my $bc = ();
  my $column_headers = shift @returned_values;
  if (@returned_values >= 1) {
    $bc = shift @returned_values;
  }
  return $bc;
}


sub check_validity {
  # Take the values passed into this script (hash)
  # Pass that right on to the list_subdivisons or something
  # If it returns a list of things, it's valid.
  # If not, it's not.
  # Simple.
  my $in = $_ [0];
  my %in = %$in;
  
  my $qry = $reports->list_subdivisions(\%in);
  my $avg = $qry->to_csv;
  my @returned_values = split /\n/, $avg;
  
  if (@returned_values <= 1) {
    die "Input error:\n  Specified input parameters do not correspond to any records in the database.\n";
  }
  
  return "Input validated";
}


sub remove_duplicates {
  # Return an array with only one of each unique string.
  my @in = @_;
  my @out = ();
  
  my %chk = ();
  foreach my $val (@in) {
    unless ($chk{$val}) {
      push @out, $val;
    }
    $chk {$val} = 1;
  }
  
  return @out;
}


sub parse_query_results {
  # Dealing with the csv data returned from a query requires several
  # lines of scruffy code. This sub takes care of it much more neatly.
  # Pass in a query results object and get back two array references:
  # first, the column headers;
  # second, an array of values per row, split on comma (since csv). 
  my $in_ref = $_ [0];
  my $in_string = $$in_ref;
  
  my @returned_values = split /\s/, $in_string;
  
  # The first line of this table is always the column headers
  my $column_headers = shift @returned_values;
  my @col_heads = split /,/,$column_headers;
  
  my @results = ();
  foreach my $rv (@returned_values) {
    my @dat = split /,/, $rv;
    push @results, \@dat;
  }
  
  return (\@col_heads, \@results);
}