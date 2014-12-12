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
$Text::Wrap::columns = 90;

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
  $input_values->{BARCODE} = get_barcode_for_sample ($input_values->{SAMPLE});
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
  my %qry = $input_values;
  push @query_sets, \%qry;
}
else {
  print "Preparing query sets\n";
  my $qry = $reports->list_subdivisions($input_values);
  my $avg = $qry->to_csv;
  my @returned_values = split /\s/, $avg;
  my $colheads = shift @returned_values;
  my @column_headers = split /,/, $colheads;
  
  print "@column_headers\n";
  
  # Make returned column headers upper-case so they match the hash keys used
  # in the API
  foreach my $k (@column_headers) {
    $k = uc $k;
  }
  
  my $n = 0;
  foreach my $query_set (@returned_values) {
    $n ++;
    my @qry_vals = split /,/, $query_set;
    my @keys = @column_headers;
    my %qry = ();
    while (@qry_vals) {
      my $val = shift @qry_vals;
      my $key = shift @keys;
      $qry {$key} = $val;
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
  my @returned_values = split /\n/, $avg;
  shift @returned_values;
  
  # Rows: min seq length, total seqs, gc content, filtered seqs, max seq length,
  # total duplicate read percentage
  # Set up summary data hash to store this (and other) properties of this query set
  my %summarydata = ();
  foreach my $row (@returned_values) {
    my @dat = split /,/, $row;
    my $desc = $dat [0];
    my $val  = $dat [1];
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
  
  @returned_values = split /\n/, $avg;
  $headers = shift @returned_values;
  
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
    my @returned_values = split /\s/, $dat;
    
    my $column_headers = shift @returned_values;
    print "$column_headers\n";
    
    if (@returned_values >= 1) {
      foreach my $rv (@returned_values) {
        $rv =~ s/,/\t/g;
        
        # Do something about the large number of decimal places. 3 ought to be plenty.
        my @dat = split /\t/, $rv;
        foreach my $val (@dat) {
          unless ($val =~ /[[:alpha:]]/) {
            if ($val != int $val) {
              $val = sprintf '%.3f', $val;
            }
          }
        }
        
        # Store the base interval of this particular record
        # Give as an interval, if possible.
        my $basepos = $dat [0];
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
        push @{$qualdata{$valtype}}, $dat [2];
        
        my $pout = join "\t", @dat;
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
    my @returned_values = split /\s/, $dat;
    
    my $column_headers = shift @returned_values;
    print "$column_headers\n";
    
    # X axis values for these plots are single figures, rather than
    # intervals. That means no other manipulation is necessary.
    my @xvals = ();
    
    if (@returned_values >= 1) {
      foreach my $rv (@returned_values) {
        $rv =~ s/,/\t/g;
        
        # Do something about the large number of decimal places. 3 ought to be plenty.
        my @dat = split /\t/, $rv;
        foreach my $val (@dat) {
          unless ($val =~ /[[:alpha:]]/) {
            if ($val != int $val) {
              $val = sprintf '%.3f', $val;
            }
          }
        }
        
        # Store the base interval of this particular record
        # Give as an interval, if possible.
        my $xval = $dat [0];
        push @xvals, $xval;
        
        # Store the actual data in a hash of arrays, according to type
        # (It's pretty easy to retrieve later)
        # Column 3 holds the data.
        push @{$qualdata{$valtype}}, $dat [2];
        
        my $pout = join "\t", @dat;
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
  @returned_values = split /\n/, $dat;
  my $column_headers = shift @returned_values;
  
  print "Overrepresented sequences:\nSequence\tComment\n";
  foreach my $ors (@returned_values) {
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
  if (@returned_values == 0) {
    print "None\n";
  }
  
  print "\n-----\n";
  
  # Now that the data is available, some plots can be produced simply
  # by writing appropriate data to a file and calling the associated
  # R script.
  
  # Most are just a little bit different from the others, so are scripted independently.
  
  my @plots = ();
  
  #####################
  # READ QUALITY PLOT #
  #####################
  print "Read quality plot\n";
  open(DAT, '>', 'quality.df') or die "Cannot open quality data file for R input\n";
  print DAT "Interval\t90th Percentile\tUpper Quartile\tMedian\tMean\tLower Quartile\t10th Percentile";
  foreach my $interval (@interval_names) {
    my @line = ($interval);
    push @line, shift @{$qualdata{'quality_90th_percentile'}};
    push @line, shift @{$qualdata{'quality_upper_quartile'}};
    push @line, shift @{$qualdata{'quality_median'}};
    push @line, shift @{$qualdata{'quality_mean'}};
    push @line, shift @{$qualdata{'quality_lower_quartile'}};
    push @line, shift @{$qualdata{'quality_10th_percentile'}};
    my $line = join "\t", @line;
    print DAT "\n$line";
  }
  
  # And execute the R script!
  my @argv = ('R --slave -f R/read_quality_graph.r');
  system(@argv) == 0 or die "Unable to launch quality graph R script\n";
  
  # Move the plot somewhere for safe keeping
  my $plot = "quality_plot_q$qnum.pdf";
  @argv = ("mv -f quality_plot.pdf R/Plots/$plot");
  system(@argv) == 0 or die "Unable to move quality plot to /Plots directory\n";
  push @plots, $plot;
  
  
  #############################
  # QUALITY DISTRIBUTION PLOT #
  #############################
  print "Quality distribution plot\n";
  open(DAT, '>', 'qual_dist.df') or die "Cannot open quality score distribution data file for R input\n";
  print DAT "Xval\tQualDist";
  my @Xvals = @{$independent_interval_names{'quality_score_count'}};
  foreach my $xval (@Xvals) {
    my @line = ($xval);
    push @line, shift @{$qualdata{'quality_score_count'}};
    my $line = join "\t", @line;
    print DAT "\n$line";
  }
  
  # And execute the R script!
  @argv = ('R --slave -f R/quality_distribution.r');
  system(@argv) == 0 or die "Unable to launch quality score distribution R script\n";
  
  # Move the plot somewhere for safe keeping
  $plot = "qual_dist_plot_q$qnum.pdf";
  @argv = ("mv -f qual_dist_plot.pdf R/Plots/$plot");
  system(@argv) == 0 or die "Unable to move quality score distribution plot to /Plots directory\n";
  push @plots, $plot;
  
  
  #########################
  # SEQUENCE CONTENT PLOT #
  #########################
  print "Sequence content plot\n";
  open(DAT, '>', 'seq_content.df') or die "Cannot open seq. content data file for R input\n";
  print DAT "Interval\tA\tC\tT\tG";
  foreach my $interval (@interval_names) {
    my @line = ($interval);
    push @line, shift @{$qualdata{'base_content_a'}};
    push @line, shift @{$qualdata{'base_content_c'}};
    push @line, shift @{$qualdata{'base_content_t'}};
    push @line, shift @{$qualdata{'base_content_g'}};
    my $line = join "\t", @line;
    print DAT "\n$line";
  }
  
  # And execute the R script!
  @argv = ('R --slave -f R/sequence_content_across_reads.r');
  system(@argv) == 0 or die "Unable to launch sequence content graph R script\n";
  
  # Move the plot somewhere for safe keeping
  $plot = "sequence_content_plot_q$qnum.pdf";
  @argv = ("mv -f sequence_content_plot.pdf R/Plots/$plot");
  system(@argv) == 0 or die "Unable to move sequence content plot to /Plots directory\n";
  push @plots, $plot;
  
  
  ###################
  # GC CONTENT PLOT #
  ###################
  print "GC content plot\n";
  open(DAT, '>', 'gc_content.df') or die "Cannot open GC content data file for R input\n";
  print DAT "Interval\tGC";
  foreach my $interval (@interval_names) {
    my @line = ($interval);
    push @line, shift @{$qualdata{'gc_content_percentage'}};
    my $line = join "\t", @line;
    print DAT "\n$line";
  }
  
  # And execute the R script!
  @argv = ('R --slave -f R/gc_content_across_reads.r');
  system(@argv) == 0 or die "Unable to launch GC content R script\n";
  
  # Move the plot somewhere for safe keeping
  $plot = "gc_content_plot_q$qnum.pdf";
  @argv = ("mv -f gc_content_plot.pdf R/Plots/$plot");
  system(@argv) == 0 or die "Unable to move GC content plot to /Plots directory\n";
  push @plots, $plot;
  
  
  ########################
  # GC DISTRIBUTION PLOT #
  ########################
  print "GC distribution plot\n";
  open(DAT, '>', 'gc_dist.df') or die "Cannot open GC distribution data file for R input\n";
  print DAT "Xval\tGCDist";
  @Xvals = @{$independent_interval_names{'gc_content_count'}};
  foreach my $xval (@Xvals) {
    my @line = ($xval);
    push @line, shift @{$qualdata{'gc_content_count'}};
    my $line = join "\t", @line;
    print DAT "\n$line";
  }
  
  # And execute the R script!
  @argv = ('R --slave -f R/gc_distribution.r');
  system(@argv) == 0 or die "Unable to launch GC distribution R script\n";
  
  # Move the plot somewhere for safe keeping
  $plot = "gc_dist_plot_q$qnum.pdf";
  @argv = ("mv -f gc_dist_plot.pdf R/Plots/$plot");
  system(@argv) == 0 or die "Unable to move GC distribution plot to /Plots directory\n";
  push @plots, $plot;
  
  
  ##################
  # N CONTENT PLOT #
  ##################
  print "N content plot\n";
  open(DAT, '>', 'n_content.df') or die "Cannot open N content data file for R input\n";
  print DAT "Interval\tN";
  foreach my $interval (@interval_names) {
    my @line = ($interval);
    push @line, shift @{$qualdata{'base_content_n_percentage'}};
    my $line = join "\t", @line;
    print DAT "\n$line";
  }
  
  # And execute the R script!
  @argv = ('R --slave -f R/n_content_across_reads.r');
  system(@argv) == 0 or die "Unable to launch N content R script\n";
  
  # Move the plot somewhere for safe keeping
  $plot = "n_content_plot_q$qnum.pdf";
  @argv = ("mv -f n_content_plot.pdf R/Plots/$plot");
  system(@argv) == 0 or die "Unable to move N content plot to /Plots directory\n";
  push @plots, $plot;
  
  
  ############################
  # LENGTH DISTRIBUTION PLOT #
  ############################
  print "Length distribution plot\n";
  open(DAT, '>', 'length_dist.df') or die "Cannot open length distribution data file for R input\n";
  print DAT "Xval\tLengthDist";
  @Xvals = @{$independent_interval_names{'sequence_length_count'}};
  
  # In the case of Illumina reads, there will only be one entry here.
  # Put one either side, in order to replicate the FastQC plot.
  if (@Xvals == 1) {
    my $num = $Xvals [0];
    unshift @Xvals, $num - 1;
    unshift @{$qualdata{'sequence_length_count'}}, '0.0';
    push @Xvals,    $num + 1;
    push @{$qualdata{'sequence_length_count'}}, '0.0';
  }
  
  foreach my $xval (@Xvals) {
    my @line = ($xval);
    push @line, shift @{$qualdata{'sequence_length_count'}};
    my $line = join "\t", @line;
    print DAT "\n$line";
  }
  
  # And execute the R script!
  @argv = ('R --slave -f R/length_distribution.r');
  system(@argv) == 0 or die "Unable to launch length distribution R script\n";
  
  # Move the plot somewhere for safe keeping
  $plot = "length_dist_plot_q$qnum.pdf";
  @argv = ("mv -f length_dist_plot.pdf R/Plots/$plot");
  system(@argv) == 0 or die "Unable to move length distribution plot to /Plots directory\n";
  push @plots, $plot;
  
  
  #############################
  # SEQUENCE DUPLICATION PLOT #
  #############################
  print "Sequence distribution plot\n";
  open(DAT, '>', 'seq_dupe.df') or die "Cannot open sequence duplication data file for R input\n";
  print DAT "Xval\tSequenceDuplication";
  @Xvals = @{$independent_interval_names{'duplication_level_relative_count'}};
  
  # The final X value in this plot represents all duplicates present n OR MORE
  # times. The final figure in @Xvals should have a '+' added to show that.
  my $i = $Xvals [-1];
  $i = $i.'+';
  $Xvals [-1] = $i;
  
  foreach my $xval (@Xvals) {
    my @line = ($xval);
    push @line, shift @{$qualdata{'duplication_level_relative_count'}};
    my $line = join "\t", @line;
    print DAT "\n$line";
  }
  
  # And execute the R script!
  @argv = ('R --slave -f R/sequence_duplication.r');
  system(@argv) == 0 or die "Unable to launch sequence duplication R script\n";
  
  # Move the plot somewhere for safe keeping
  $plot = "seq_dupe_plot_q$qnum.pdf";
  @argv = ("mv -f seq_dupe_plot.pdf R/Plots/$plot");
  system(@argv) == 0 or die "Unable to move sequence duplication plot to /Plots directory\n";
  push @plots, $plot;
  
  
  # Delete data files
  unlink "quality.df";
  unlink "seq_content.df";
  unlink "gc_content.df";
  unlink "n_content.df";
  unlink "qual_dist.df";
  unlink "gc_dist.df";
  unlink "length_dist.df";
  unlink "seq_dupe.df";
  
  
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
  foreach my $plot (@plots) {
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
      
      @dat = remove_duplicates(@dat);
      
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
  # Pass that right on to list_subdivisons 
  # If it returns a list of things (beyond column headers), it's valid.
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