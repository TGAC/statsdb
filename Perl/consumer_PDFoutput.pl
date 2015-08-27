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
# This more complex consumer uses R and self-generated LaTeX scripts to produce
# graphical output describing QC data, in a format similar to that produced by
# FastQC.

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
This script produces a set of reports, similar to a FastQC report, from QC data associated with specific analyses corresponding to the inputs described below.
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


GetOptions();
print "DB configuration: ". $input_values->{DB_CONFIG}."\n";
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
# Specify that we're looking for older duplicates here, in order to suggest
# to the user that they be deleted.
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
my $query_sets = ();
if ($input_values->{QSCOPE} eq 'na') {
  my %qry = $input_values;
  push @$query_sets, \%qry;
}
else {
  print "Preparing query sets\n";
  my $qry = $reports->list_subdivisions($input_values);
  my $avg = $qry->to_csv;
  my ($column_headers,$returned_values) = $confuncs->parse_query_results($avg);
  
  # The query sets returned by that function are not quite what we need here.
  # They are separated at the level of analysis tool used to produce the data (e.g., FastQC); this is helpful
  # for clearing up many otherwise confusing potential conflicts, but in this consumer we want a separation
  # at the levels of instrument/run/lane/pair/barcode/sample name, NOT tool.
  # This function cleans that up by removing the tool dimension from consideration here (and also cleans
  # up some other irrelevant things, such as query sets for incorrect read numbers and index reads).
  ($column_headers,$returned_values) = $confuncs->remove_read0_lines($column_headers,$returned_values);
  ($column_headers,$returned_values) = $confuncs->remove_index_reads($column_headers,$returned_values);
  my @columns_to_remove = ('tool');
  ($column_headers,$returned_values) = $confuncs->clean_query_sets($column_headers,$returned_values,\@columns_to_remove);
  
  # Then, feed the remaining data into prepare_query_sets to generate the appropriate hash structure.
  $query_sets = $confuncs->prepare_query_sets($column_headers,$returned_values);
}

print "Set up ".@$query_sets." query set(s)\n\n";

# Open TeX-format output, print stuff to start the file off
open(TEX, '>', 'query_report.tex') or die "Unable to open LaTeX output file\n";
print TEX
"\\documentclass[slides,12pt]{article}
\\usepackage{graphicx}
\\usepackage{longtable}
\\usepackage[margin=0.75in]{geometry}
\\usepackage{float}
\\graphicspath{ {R/Plots/} }
\\begin{document}\n";
close TEX;

# Set some repetitive TeX code that will be used a lot later
my %texcode = ();
$texcode {"open_fig"} =
"\\begin{figure}[htp]
\\large
{\\bf Text1}
\\\\
{\\bf Text2}\n";

$texcode{"left_img"} =
"\n\\begin{minipage}{0.45\\textwidth}
\\centering\n";

$texcode{"include_img"} =
"\\includegraphics[width=1\\textwidth]{img}\n";

$texcode{"between_img"} =
"\\end{minipage}
\\hfill
\\begin{minipage}{0.45\\textwidth}
\\centering\n";

$texcode{"right_img"} =
"\\end{minipage}\n\n";

$texcode {"close_fig"} =
"\\end{figure}
\\clearpage\n\n";

$texcode{"summary_table"} =
"\\begin{tabular}{ll}
	Filename & 12\\\\
	File type & 22\\\\
	Encoding & 32\\\\
	Total sequences & 42\\\\
	Filtered sequences & 52\\\\
	Sequence length & 62\\\\
	\\%GC & 72\\\\
\\end{tabular}\n";


# Query sets now established. Cycle each one, produce output graphs for each,
# and append relevant stuff to a LaTeX output file. 
my $qnum = 0;
foreach my $query_set (@$query_sets) {
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
  my ($column_headers,$returned_values) = $confuncs->parse_query_results($avg);
  
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
  my $headers = shift @analysis_ids;
  
  # Add filename and file type to %summarydata by querying the analysis_property
  # table. 
  # A complete list of summary properties which might be retrieved in
  # this way can be obtained using the SQL routine list_selectable_properties
  $qry = $reports->get_properties_for_analysis_ids(\@analysis_ids);
  $avg = $qry->to_csv;
  ($column_headers,$returned_values) = $confuncs->parse_query_results($avg);
  
  print "Querying analysis properties\nPROPERTY,VALUE\n";
  foreach my $line (@$returned_values) {
    my @sp = split /,/, $line;
    my $property = $sp[0]; my $value = $sp[1];
    
    # Prevent this from producing entries for data that is actually missing.
    # (E.g., barcodes, frequently)
    if ($value) {
      push @{$summarydata{$property}}, $value;
      print "$property\t$value\n";
    }
  }
  print "\n-----\n";
  
  # Before we generate a label, it would be handy to have some date information to put in it.
  # Use get_dates_for_run to... well, take a guess.
  # Parse that into a hash so we can get the bits we need shortly.
  my %date_info = ();
  $qry = $reports->get_dates_for_run(\%query_properties);
  $avg = $qry->to_csv;
  ($column_headers,$returned_values) = $confuncs->parse_query_results($avg);
  foreach my $line (@$returned_values) {
    my @sp = split /,/, $line;
    my $type = $sp[0];  my $date = $sp[1];
    $date_info{$type} = $date;
  }
  
  # Set up a label to go at the top of the report.
  # Pick sample names, if those are specified.
  # If not, use lanes.
  # If those are missing, use runs, if those are missing use instruments,
  # and if (for some reason) everything is missing, just use a generic
  # string.
  my $queryset_label = ();
  my $d1 = $date_info{run_start};   my $d2 = $date_info{run_end};
  my $d3 = $date_info{read_start};  my $d4 = $date_info{read_end};
  if ($query_properties{SAMPLE_NAME}) {
    $queryset_label = "Sample ".$query_properties{SAMPLE_NAME};
    if ($query_properties{PAIR}) {
      $queryset_label = "$queryset_label, Read ".$query_properties{PAIR}." ($d3 to $d4)";
    }
  }
  elsif ($query_properties{LANE}) {
    $queryset_label = "Lane ".$query_properties{LANE};
    if ($query_properties{BARCODE}) {
      $queryset_label = "$queryset_label, Barcode ".$query_properties{BARCODE}." ($d3 to $d4)";
    }
    if ($query_properties{PAIR}) {
      $queryset_label = "$queryset_label, Read ".$query_properties{PAIR}." ($d3 to $d4)";
    }
  }
  elsif ($query_properties{RUN}) {
    $queryset_label = "Run ".$query_properties{RUN}." ($d1 to $d2)";
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
  my $qualdata = ();
  #my @base_intervals = ();
  #my @interval_names = ();
  foreach my $valtype (@per_position_value_types) {
    print "Querying $valtype\n";
    
    my @vtdata = $confuncs->aggregate_data($dbdata, $valtype);
    # @vtdata contains 6 array references, which can be used as columns in a results table, in
    # the following order: column headers, position, size, mean, count and sum.
    # It can be flipped round from column-separated to row-separated data for ease of printing:
    my $rotdata = $confuncs->rotate_query_results_col_to_row(@vtdata);
    
    if (@$rotdata >= 1) {
      # Print this data to stdout - it makes the output of this script readable.
      foreach my $line (@$rotdata) { $line =~ s/\t/,/g; }
      print $confuncs->make_printable_table($rotdata);
      print "\n-----\n";
      
      # This data should also be organised into a data structure to facilitate later analyses
      # and plotting. The base positions and intervals should be stored, and the actual data
      # should be made easily and rationally accessible.
      # As well as simple base numbers, give intervals (i.e., partitions) in the format 'x-y'.
      # A function in Consumers.pm can handle that.
      $confuncs->add_to_data_stash($qualdata,$rotdata,$valtype,'average');
      
      #foreach my $basepos (@{$vtdata[1]}) {
      #  my $interval_name = $basepos;
      #  if ($base_intervals[-1]) {
      #    if ($base_intervals[-1] < ($basepos - 1)) {
      #      $interval_name = ($base_intervals[-1] + 1)."-$basepos";
      #    }
      #  }
      #  push @interval_names, $interval_name;
      #  push @base_intervals, $basepos;
      #}
      #
      ## That's the base positions and interval names. Now store the actual data.
      #@{$qualdata{$valtype}} = @{$vtdata[3]};
      
    }
    else {
      print "No values found in database\n";
    }
  }
  
  #@interval_names = $confuncs->remove_duplicates(\@interval_names);
  #@base_intervals = $confuncs->remove_duplicates(\@base_intervals);
  
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
    my $rotdata = $confuncs->rotate_query_results_col_to_row(@vtdata);
    
    if (@$rotdata >= 1) {
      # Print this data to stdout - it makes the output of this script readable.
      foreach my $line (@$rotdata) { $line =~ s/\t/,/g; }
      print $confuncs->make_printable_table($rotdata);
      print "\n-----\n";
      
      # This data should also be organised into a data structure to facilitate later analyses
      # and plotting. The base positions and intervals should be stored, and the actual data
      # should be made easily and rationally accessible.
      # Unlike earlier data, these data may have their own independent scales, which need to be
      # recorded separately.
      # A function in Consumers.pm can handle that.
      $confuncs->add_to_data_stash($qualdata,$rotdata,$valtype,'average');
      
      #@{$independent_interval_names{$valtype}} = @{$vtdata[1]};
      
      # That's the scales. Now store the actual data.
      #@{$qualdata{$valtype}} = @{$vtdata[3]};
    }
    else {
      print "No values found in database\n";
    }
  }
  
  # Also, get overrepresented sequences, if any.
  my %overrepresented_sequences = ();
  $qry = $reports->get_summary_values_with_comments('overrepresented_sequence', \%query_properties);
  my $dat = $qry->to_csv;
  ($column_headers,$returned_values) = $confuncs->parse_query_results($dat);
  
  print "Overrepresented sequences:\nSequence\tComment\n";
  foreach my $ors (@$returned_values) {
    $ors =~ s/,/\t/g;
    
    my @sp = split /\t/, $ors;
    my $seq = shift @sp;
    
    for (1..3) { pop @sp; }
    my $comment = join ' ', @sp;
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
  
  # One more thing: general high-level summary values, using 
  
  
  # Now that the data is available, some plots can be produced simply
  # by writing appropriate data to a file and calling the associated
  # R script.
  
  # Most are just a little bit different from the others, so are scripted independently.
  
  my @plotfiles = ();
  my @datafiles = ();
  
  
  #####################
  # READ QUALITY PLOT #
  #####################
  print "Read quality plot\n";
  #my ($plotfile,$datafile) = $confuncs->read_quality_plot(\@interval_names,\%qualdata,$qnum);
  # Pick the value types that will be used for this plot
  my $valtypes -> ('quality_90th_percentile',
                   'quality_upper_quartile',
                   'quality_mean',
                   'quality_lower_quartile',
                   'quality_10th_percentile',
                   'quality_median');
  my $title = "Quality scores across all bases";
  my $xlabel = "Position in read (bp)";
  my $ylabel = "Phred quality score";
  my ($plotfile,$datafile) = $confuncs->freq_distribution_over_range_plot($qualdata,$valtypes,$title,$xlabel,$ylabel,$qnum);
  push @plotfiles, $plotfile;
  push @datafiles, $datafile;
  
  #############################
  # QUALITY DISTRIBUTION PLOT #
  #############################
  print "Quality distribution plot\n";
  $valtypes -> ('quality_score_count');
  $title = "Quality score distribution over all sequences";
  $xlabel = "Mean Sequence Quality (Phred Score)";
  $ylabel = "Frequency";
  ($plotfile,$datafile) = $confuncs->single_line_plot($qualdata,$valtypes,$title,$xlabel,$ylabel,$qnum);
  push @plotfiles, $plotfile;
  push @datafiles, $datafile;
  
  #########################
  # SEQUENCE CONTENT PLOT #
  #########################
  print "Sequence content plot\n";
  $valtypes -> ('base_content_a',
                'base_content_c',
                'base_content_g',
                'base_content_t',);
  $title = "Sequence content across all bases";
  $xlabel = "Position in read (bp)";
  $ylabel = "Frequency of base (%)";
  ($plotfile,$datafile) = $confuncs->sequence_content_plot($qualdata,$valtypes,$title,$xlabel,$ylabel,$qnum);
  push @plotfiles, $plotfile;
  push @datafiles, $datafile;
  
  ###################
  # GC CONTENT PLOT #
  ###################
  print "GC content plot\n";
  $valtypes -> ('gc_content_percentage');
  $title = "GC content across all bases";
  $xlabel = "Position in read (bp)";
  $ylabel = "GC frequency (%)";
  ($plotfile,$datafile) = $confuncs->single_line_plot($qualdata,$valtypes,$title,$xlabel,$ylabel,$qnum);
  push @plotfiles, $plotfile;
  push @datafiles, $datafile;
  
  ########################
  # GC DISTRIBUTION PLOT #
  ########################
  print "GC distribution plot\n";
  $valtypes -> ('gc_content_count');
  $title = "GC distribution over all sequences";
  $xlabel = "Mean GC Content (%)";
  $ylabel = "Frequency";
  ($plotfile,$datafile) = $confuncs->normal_distribution_plot($qualdata,$valtypes,$title,$xlabel,$ylabel,$qnum);
  push @plotfiles, $plotfile;
  push @datafiles, $datafile;
  
  ##################
  # N CONTENT PLOT #
  ##################
  print "N content plot\n";
  $valtypes -> ('gc_content_count');
  $title = "Sequence content across all bases";
  $xlabel = "Position in read (bp)";
  $ylabel = "N frequency (%)";
  ($plotfile,$datafile) = $confuncs->single_line_plot($qualdata,$valtypes,$title,$xlabel,$ylabel,$qnum);
  push @plotfiles, $plotfile;
  push @datafiles, $datafile;
  
  ############################
  # LENGTH DISTRIBUTION PLOT #
  ############################
  print "Length distribution plot\n";
  # This is unique in that I may need to pad the data out a little. In an Illumina dataset, there may only
  # be a single X axis point here. I need to add one to either side (with 0 as the y value) if so.
  # Make a subroutine to do that. 
  
  
  $valtypes -> ('sequence_length_count');
  $title = "Distribution of sequnce lengths over all sequences";
  $xlabel = "Sequence length (bp)";
  $ylabel = "Frequency";
  ($plotfile,$datafile) = $confuncs->length_distribution_plot($qualdata,$valtypes,$title,$xlabel,$ylabel,$qnum);
  push @plotfiles, $plotfile;
  push @datafiles, $datafile;
  
  #############################
  # SEQUENCE DUPLICATION PLOT #
  #############################
  print "Sequence distribution plot\n";
  $valtypes -> ('duplication_level_relative_count');
  $title = "Sequence duplication level";
  $xlabel = "Sequence length (bp)";
  $ylabel = "Relative frequency (%)";
  ($plotfile,$datafile) = $confuncs->sequence_duplication_plot($qualdata,$valtypes,$title,$xlabel,$ylabel,$qnum);
  push @plotfiles, $plotfile;
  push @datafiles, $datafile;
  
  
  ######################
  ## READ QUALITY PLOT #
  ######################
  #print "Read quality plot\n";
  ##my ($plotfile,$datafile) = $confuncs->read_quality_plot(\@interval_names,\%qualdata,$qnum);
  ## Pick the value types that will be used for this plot
  #my $valtypes -> ('quality_90th_percentile',
  #                 'quality_upper_quartile',
  #                 'quality_mean',
  #                 'quality_lower_quartile',
  #                 'quality_10th_percentile',
  #                 'quality_median');
  #my ($plotfile,$datafile) = $confuncs->freq_distribution_over_range_plot($qualdata,$valtypes,$qnum);
  #push @plotfiles, $plotfile;
  #push @datafiles, $datafile;
  #
  ##############################
  ## QUALITY DISTRIBUTION PLOT #
  ##############################
  #print "Quality distribution plot\n";
  #my @Xvals = @{$independent_interval_names{'quality_score_count'}};
  #($plotfile,$datafile) = $confuncs->quality_distribution_plot(\@Xvals,\%qualdata,$qnum);
  #push @plotfiles, $plotfile;
  #push @datafiles, $datafile;
  #
  ##########################
  ## SEQUENCE CONTENT PLOT #
  ##########################
  #print "Sequence content plot\n";
  #($plotfile,$datafile) = $confuncs->sequence_content_plot(\@interval_names,\%qualdata,$qnum);
  #push @plotfiles, $plotfile;
  #push @datafiles, $datafile;
  #
  ####################
  ## GC CONTENT PLOT #
  ####################
  #print "GC content plot\n";
  #($plotfile,$datafile) = $confuncs->gc_content_plot(\@interval_names,\%qualdata,$qnum);
  #push @plotfiles, $plotfile;
  #push @datafiles, $datafile;
  #
  #########################
  ## GC DISTRIBUTION PLOT #
  #########################
  #print "GC distribution plot\n";
  #@Xvals = @{$independent_interval_names{'gc_content_count'}};
  #($plotfile,$datafile) = $confuncs->gc_distribution_plot(\@Xvals,\%qualdata,$qnum);
  #push @plotfiles, $plotfile;
  #push @datafiles, $datafile;
  #
  ###################
  ## N CONTENT PLOT #
  ###################
  #print "N content plot\n";
  #($plotfile,$datafile) = $confuncs->n_content_plot(\@interval_names,\%qualdata,$qnum);
  #push @plotfiles, $plotfile;
  #push @datafiles, $datafile;
  #
  #############################
  ## LENGTH DISTRIBUTION PLOT #
  #############################
  #print "Length distribution plot\n";
  #@Xvals = @{$independent_interval_names{'sequence_length_count'}};
  #($plotfile,$datafile) = $confuncs->length_distribution_plot(\@Xvals,\%qualdata,$qnum);
  #push @plotfiles, $plotfile;
  #push @datafiles, $datafile;
  #
  ##############################
  ## SEQUENCE DUPLICATION PLOT #
  ##############################
  #print "Sequence distribution plot\n";
  #@Xvals = @{$independent_interval_names{'duplication_level_relative_count'}};
  #($plotfile,$datafile) = $confuncs->sequence_duplication_plot(\@Xvals,\%qualdata,$qnum);
  #push @plotfiles, $plotfile;
  #push @datafiles, $datafile;
  
  # Delete data files
  #unlink "quality.df";
  #unlink "seq_content.df";
  #unlink "gc_content.df";
  #unlink "n_content.df";
  #unlink "qual_dist.df";
  #unlink "gc_dist.df";
  #unlink "length_dist.df";
  #unlink "seq_dupe.df";
  foreach my $data (@datafiles) { unlink $data; }
  
  
  ##########
  # OUTPUT #
  ##########
  
  # Once everything is present, combine all those plots into a single PDF.
  # Use laTeX! Append the file opened earlier.
  
  open(TEX, '>>', 'query_report.tex') or die "Unable to open LaTeX output file\n";
  
  my $latex_queryset_label = $queryset_label;
  $latex_queryset_label =~ s/_/\\_/g;
  $latex_queryset_label =~ s/%/\\%/g;
  
  # Using the bits of TeX code set earlier, this creates a 2x4 figure
  # with the 8 plots just produced by R.
  my $line = $texcode{"open_fig"};
  $line =~ s/Text1/$queryset_label/;
  $line =~ s/Text2/$reads_filename/;
  $line =~ s/_/\\_/g;
  $line =~ s/%/\\%/g;
  print TEX $line;
  
  my $leftright = 'l';
  foreach my $plot (@plotfiles) {
    my $line = $texcode{"include_img"};
    $line =~ s/img/$plot/;
    
    if ($leftright eq 'l') {
      $line = $texcode{"left_img"}.$line.$texcode{"between_img"};
      $leftright = 'r';
    }
    else {
      $line = $line.$texcode{"right_img"};
      $leftright = 'l';
    }
    
    print TEX $line;
  }
  print TEX $texcode {"close_fig"};
  
  # That's the figures printed.
  # On the next page, print a table showing summary stats, a summary of
  # analysis modules (if available), and overrepresented sequences.
  my $summarytable = $texcode{"summary_table"};
  
  # Substitute in appropriate stats
  $reads_filename =~ s/_/\\_/g;
  $reads_filename =~ s/%/\\%/g;
  $summarytable =~ s/12/$reads_filename/;
  
  # File type
  if ($summarydata{'File type'}) {
    my @arr = @{$summarydata{'File type'}};
    if (@{$summarydata{'File type'}} == 1) {
      my $filetype = $arr[0];
      $filetype =~ s/_/\\_/g;
      $filetype =~ s/%/\\%/g;
      $summarytable =~ s/22/$filetype/;
    }
    else {
      $summarytable =~ s/22/Multiple types/;
    }
  }
  else { $summarytable =~ s/22/None listed/; }
  
  # Encoding
  if ($summarydata{'Encoding'}) {
    my @arr = @{$summarydata{'Encoding'}};
    if (@{$summarydata{'Encoding'}} == 1) {
      my $encoding = $arr[0];
      $encoding =~ s/_/\\_/g;
      $encoding =~ s/%/\\%/g;
      $summarytable =~ s/32/$encoding/;
    }
    else {
      $summarytable =~ s/32/Multiple types/;
    }
  }
  else { $summarytable =~ s/32/None listed/; }  
  
  $summarydata{general_total_sequences} = int $summarydata{general_total_sequences};
  $summarydata{general_total_sequences} =~ s/_/\\_/g;
  $summarydata{general_total_sequences} =~ s/%/\\%/g;
  $summarytable =~ s/42/$summarydata{general_total_sequences}/;
  
  $summarydata{general_filtered_sequences} =~ s/_/\\_/g;
  $summarydata{general_filtered_sequences} =~ s/%/\\%/g;
  $summarytable =~ s/52/$summarydata{general_filtered_sequences}/;
  
  $summarydata{general_max_length} =~ s/_/\\_/g;
  $summarydata{general_max_length} =~ s/%/\\%/g;
  $summarytable =~ s/62/$summarydata{general_max_length}/;
  
  $summarydata{general_gc_content} = sprintf '%.3f', $summarydata{general_gc_content};
  $summarydata{general_gc_content} =~ s/_/\\_/g;
  $summarydata{general_gc_content} =~ s/%/\\%/g;
  $summarytable =~ s/72/$summarydata{general_gc_content}/;
  
  print TEX "\\large\n{\\bf $latex_queryset_label}\n\n{\\bf $reads_filename}"
           ."\n\\vspace{4 mm}\n\n{\\bf Summary}\n\\vspace{2 mm}\n\\scriptsize"
           ."\n\n$summarytable\n\n"
           ."\\vspace{4 mm}\n\\large\n{\\bf Analysis properties}"
           ."\n\\vspace{2 mm}\n\\scriptsize\n\n";
  
  # Also print, as a separate table, some other analysis properties:
  # Path to results (key: 'run_folder')
  # Cassava version
  # Chemistry version
  # Type of experiment (key: 'type_of_experiment')
  # Instrument
  # Run
  # Lane
  # Sample
  # Barcode
  # Read
  # Reference
  
  my @property_table_rows = (
    'run_folder',
    'cassava_version',
    'chemistry_version',
    'type_of_experiment',
    'instrument',
    'run',
    'lane',
    'sample_name',
    'barcode',
    'pair',
    'reference'
  );
  
  # For specific circumstances, I might want to print a list of things, rather
  # than just 'multiple'.
  # Also must avoid printing a huge list that shoots right off the side of the page.
  # Use smaller text to avoid that.
  print TEX "\\begin{tabular}{ll}\n";
  foreach my $key (@property_table_rows) {
    my $name = $key;
    $name =~ s/_/ /g;
    $name = ucfirst $name;
    
    if ($summarydata{$key}) {
      my @dat = @{$summarydata{$key}};
      $name =~ s/_/\\_/g;
      $name =~ s/%/\\%/g;
      
      @dat = $confuncs->remove_duplicates(\@dat);
      
      if (@dat == 1) {
        my $val = $dat [0];
        $val =~ s/_/\\_/g;
        $val =~ s/%/\\%/g;
        print TEX "        $name & $val\\\\\n";
      }
      elsif ((@dat > 1) && (@dat < 9)) {
        # Some things - lanes, reads, etc. - should give a numeric range here,
        # rather than just 'multiple'.
        if ($name eq 'Lane' or 'Pair' or 'Reference') {
          @dat = sort {$a cmp $b} @dat;
          print TEX "        $name &";
          foreach my $val (@dat) {
            $val =~ s/_/\\_/g;
            $val =~ s/%/\\%/g;
            print TEX " $val";
          }
          print TEX "\\\\\n";
        }
        else { print TEX "        $name & ".@dat." entries\\\\\n"; }
      }
      else {
        print TEX "        $name & ".@dat." entries\\\\\n";
      }
    }
  }
  print TEX "\\end{tabular}\n\n";
  
  # Finally, print overrepresented sequences (if any)
  print TEX "{\\vspace{4 mm}\n\\large\n\\bf Overrepresented sequences}\n"
           ."\\vspace{2 mm}\n\\scriptsize\n\n";
  
  if ($overrepresented_sequences{"seqs"}) {
    my @seqs = @{$overrepresented_sequences{"seqs"}};
    my @comments = @{$overrepresented_sequences{"comments"}};
    my $num_ors = @seqs;
    
    print TEX "\\begin{longtable}{ll}";
    foreach my $i (1..$num_ors) {
      my $seq = shift @seqs;
      my $comment = shift @comments;
      
      my $line = "\n$seq & $comment\\\\";
      
      $line =~ s/_/\\_/g;
      $line =~ s/%/\\%/g;
      print TEX $line;
    }
    print TEX "\n\\end{longtable}\n\n";
  }
  else {
    print TEX "None\n\n";
  }
  
  
  print TEX "\\clearpage\n\n";
  
  close TEX;
}


# Close off the LaTeX file
open(TEX, '>>', 'query_report.tex') or die "Unable to open LaTeX output file\n";
print TEX
"\\end{document}";
close TEX;


# Execute LaTeX compilation, move PDF to the right place.
my @argv = ('pdflatex query_report.tex');
system(@argv) == 0 or die "Cannot automatically convert quality_report.tex to PDF\n";



$db->disconnect();

print "Retrieval of data complete\n";
