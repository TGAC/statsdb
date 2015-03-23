#!/usr/bin/perl -w
use strict;
use Getopt::Long;
use List::Util qw(min max);
use Reports::DB;
use Reports;
use Timecode;
use Text::Wrap qw(wrap);
use Consumers;

# This is used when printing out long strings, e.g., the program's inbuilt
# help.
$Text::Wrap::columns = 150;

# This is a consumer designed specifically to retrieve data parsed from
# FastQC analysis. 
# This simpler version of the StatsDB consumer shows how data is retrieved, and
# is well suited to modification for alternative output formats, or simply
# retrieving stored data in text format. 

system ('clear');
my @opts = (
  'analysis',
  'instrument',
  'run',
  'pseq',
  'lane',
  'pair',
  'sample_name',
  'barcode',
  'scope',
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

# Call help if -h is used, or if incorrect flags are set
if (($input_values->{HELP}) || ($incorrect_flags == 1)) {
  die wrap ('','',
  "HELP FOR STATSDB CONSUMER
This script simply retrieves QC data associated with specific analyses corresponding to the inputs described below.
-----
Calling StatsDB Perl consumer with command line options:
$help_string
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

# Connect to the database
GetOptions();
print "DB configuration: ".$input_values->{DB_CONFIG}."\n";
my $db = Reports::DB->new($input_values->{DB_CONFIG});
my $reports = Reports->new($db);

my $confuncs = Consumers->new($reports);

# Check that the input parameters passed do, in fact, exist.
# If they don't, bail. 
my $check = $confuncs->check_validity($input_values);
print "$check\n\n";

# Per-sample querying relies upon the sample's barcode being present.
# If it's not supplied, find it.
# Bear in mind that if a sample is not from a multiplexed run, there
# won't be a barcode listed. 
if (($input_values->{SAMPLE}) && (!$input_values->{BARCODE})) {
  $input_values->{BARCODE} = $confuncs->get_barcode_for_sample ($input_values->{SAMPLE});
}

# OK, inputs are good. Check for duplicated records corresponding to those
# inputs.
# Leave the session variable indicating selection type unset; the default behavious is what we want.
my $duplicates = $confuncs->check_for_duplicated_data($input_values);
if ($duplicates) {
  print "WARN: the database contains duplicate records for some or all of the supplied parameters.\n".
  "The following records are older duplicates:\n";
  print $confuncs->make_printable_table($duplicates);
}

# Plan the set of queries for the consumer to go through (if more than one).
# If no query scope is set, then a single query is carried out, based on the
# run, lane, sample, read etc. supplied.

# If the queryscope value is set, though, a query set should be constructed.
# Think of a way of doing this which is scale-agnostic. Use the database!
# I made a sub in the API called list_subdivisions to do just that.

# Store queries as hash references.
my @query_sets = ();
if ($input_values->{QSCOPE} eq 'na') {
  my %qry = %$input_values;
  push @query_sets, \%qry;
}
else {
  print "Preparing query sets\n";
  my $qry = $reports->list_subdivisions($input_values);
  my $avg = $qry->to_csv;
  my ($column_headers,$returned_values) = $confuncs->parse_query_results(\$avg);
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
      my $bc = $confuncs->get_barcode_for_sample($qry{SAMPLE_NAME});
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
  my ($column_headers,$returned_values) = $confuncs->parse_query_results(\$avg);
  
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
  #($column_headers,$returned_values) = $confuncs->parse_query_results(\$avg);
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
  
  # This call gets ALL of the relevant data for this query set out of the database in a single,
  # fast query, and stores it in a big data object thing.
  # We can then access specific bits of it at will.
  my $dbdata = $confuncs->get_all_queryset_data($query_set);
  
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
    
    my @vtdata = $confuncs->aggregate_data($dbdata, $valtype);
    # @vtdata contains 6 array references, which can be used as columns in a results table, in
    # the following order: column headers, position, size, mean, count and sum.
    # It can be flipped round from column-separated to row-separated data for ease of printing:
    my $rotdata = $confuncs->rotate_query_results(@vtdata);
    
    if (@$rotdata >= 1) {
      # Print this data to stdout - it makes the output of this script machine-readable.
      foreach my $line (@$rotdata) { print "$line\n"; }
      print "\n-----\n";
      
      # This data should also be organised into a data structure to facilitate later analyses
      # and plotting. The base positions and intervals should be stored, and the actual data
      # should be made easily and rationally accessible.
      # As well as simple base numbers, give intervals (i.e., partitions) in the format 'x-y'.
      foreach my $basepos (@{$vtdata[1]}) {
        my $interval_name = $basepos;
        if ($base_intervals [-1]) {
          if ($base_intervals [-1] < ($basepos - 1)) {
            $interval_name = ($base_intervals [-1] + 1)."-$basepos";
          }
        }
        push @interval_names, $interval_name;
        push @base_intervals, $basepos;
      }
      
      # That's the base positions and interval names. Now store the actual data.
      @{$qualdata{$valtype}} = @{$vtdata[3]};
    }
    else {
      print "No values found in database\n";
    }
  }
  
  @interval_names = $confuncs->remove_duplicates(\@interval_names);
  @base_intervals = $confuncs->remove_duplicates(\@base_intervals);
  
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
    
    my @vtdata = $confuncs->aggregate_data($dbdata, $valtype);
    # @vtdata contains 6 array references, which can be used as columns in a results table, in
    # the following order: column headers, position, size, mean, count and sum.
    # It can be flipped round from column-separated to row-separated data for ease of printing:
    my $rotdata = $confuncs->rotate_query_results(@vtdata);
    
    if (@$rotdata >= 1) {
      # Print this data to stdout - it makes the output of this script machine-readable.
      foreach my $line (@$rotdata) { print "$line\n"; }
      print "\n-----\n";
      
      # This data should also be organised into a data structure to facilitate later analyses
      # and plotting. The base positions and intervals should be stored, and the actual data
      # should be made easily and rationally accessible.
      # Unlike earlier data, these data may have their own independent scales, which need to be
      # recorded separately.
      @{$independent_interval_names{$valtype}} = @{$vtdata[1]};
      
      # That's the scales. Now store the actual data.
      @{$qualdata{$valtype}} = @{$vtdata[3]};
    }
    else {
      print "No values found in database\n";
    }
  }
  
  # Also, get overrepresented sequences, if any.
  my %overrepresented_sequences = ();
  $qry = $reports->get_summary_values_with_comments('overrepresented_sequence', \%query_properties);
  my $dat = $qry->to_csv;
  ($column_headers,$returned_values) = $confuncs->parse_query_results(\$dat);
  
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

