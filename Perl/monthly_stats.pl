#!/usr/bin/perl -w
use strict;
use Getopt::Long;
use List::Util qw(min max);
use Reports::DB;
use Reports;
use Timecode;
use Text::Wrap qw(wrap);
use QCAnalysis::MISO;
use Data::Dumper;
use Consumers;

# This is used when printing out long strings, e.g., the program's inbuilt
# help.
$Text::Wrap::columns = 150;

# This script reports a set of simple statistics for runs that have occurred
# within a given time range. A few example data types are included, but this script
# could easily be expanded to handle more.
# See consumer_simple.pl for code in which other data types are retrieved, and
# in which further restrictions on queries - to a single machine, for example -
# are implemented.

# Autoflush stdout
$|++;

system ('clear');
my @opts = (
  'begin',
  'end',
  'datetype',
  'miso_config',
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
  "HELP FOR MONTHLY STATS CONSUMER\n
This script returns summary statistics for the runs on record within
a time interval specified by two dates or timestamps.
-----
Calling StatsDB Perl consumer with command line options:
$help_string
Examples:
- Query between two dates:
 perl monthly_stats.pl -d examples/template_db.txt -c \"23/4/14\" -e \"27/4/2014\"

- Query between two dates, also specifying times:
 perl monthly_stats.pl -d examples/template_db.txt -c \"15/7/13 17:19:21\" -e \"30/7/2013 18:00:36\"

Note that double-quotes around date/time values are recommended.
-----
Output consists of a list of runs, followed by a simple table listing
summary statistics.
-----
Warning: If non-standard QC and primary analyses (for example, RADplex demultiplexing) are carried out on any of the runs within the time interval, the number of samples stored in StatsDB may be lower than that actually produced by the QC/PA pipeline, since this data is not yet automatically entered into the database.");
}

# Connect to database, load API objects
GetOptions();
print "DB configuration: ". $input_values->{DB_CONFIG}."\n";
my $db = Reports::DB->new($input_values->{DB_CONFIG});
my $reports = Reports->new($db);
my $confuncs = Consumers->new($reports);

# get_runs_between_dates does what it says on the tin.
print "Runs between\n\t".$input_values->{BEGIN}."\tand\n\t".$input_values->{END}."...\n\n";
#my $qry = $reports->get_runs_between_dates($input_values);
$input_values->{QSCOPE} = 'run';
my $qry = $reports->list_subdivisions($input_values);
my $rir = $qry->to_csv;
my @returned_values = split /\n/, $rir;
my $colheads = shift @returned_values;

my @runs_in_range = ();
my %run_instruments = ();
my %statsdb_instruments = ();
foreach my $analysis (@returned_values) {
  my @dat = split /,/, $analysis;
  my $run = $dat[1];
  my $instrument = $dat[0];
  push @runs_in_range, $run;
  $run_instruments{$run} = $instrument;
  $statsdb_instruments{$instrument} = 1;
}
@runs_in_range = $confuncs->remove_duplicates(\@runs_in_range);
my $total_runs = @runs_in_range;



foreach my $run (@runs_in_range) { print "$run\n"; }
print "-----\n";

# Set up some totals, then cycle runs and collect relevant data for each run.
# If adding new statistics to be added up, initialise them here.
my ($total_bases, $total_sequences, $total_samples) = 0;
my (@numseqs, @readlengths, @numbases, @numsamples) = ();

my %data = ();
my %library_types = ();
my %screening = ();
my %contaminants_screened = ();
my %runs_lanes = ();
my %num_reads = ();
my %barcodes = ();

my $c = 0;
foreach my $runID (@runs_in_range) {
  $c ++;
  print "RUN $runID\t($c of $total_runs)\n";
  my $instrument = $run_instruments{$runID};
  
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
  
  # Get num clusters, cluster density, clusters_pf, density_pf
  # Percent phasing and prephasing too
  # It's a per partition value
  # Quality_mean is a per position value, but I handle that shortly.
  my @valtypes = ('quality_mean',
                  'percentphasing_mean',
                  'percentprephasing_mean',
                  'clusters_mean',
                  'clusterspf_mean',
                  'density_mean',
                  'densitypf_mean'
                  );
  
  foreach my $type (@valtypes) {
    my $qry = $reports->get_per_position_values($type, \%query_properties);
    my $avg = $qry->to_csv;
    my @returned_values = split /\n/, $avg;
    shift @returned_values;
    
    my $arrayname = $type;
    $arrayname =~ s/_mean//g;
    
    # Because quality score is per-position, it has to be handled slightly differently
    # to the other types, wwhich are per-position. Just get the mean of all positions
    # across the run.
    if ($arrayname eq 'quality') {
      my @qualscores = ();
      foreach my $line (@returned_values) {
        my @data = split /,/, $line;
        push @qualscores, $data[2];
      }
      push @{$data{$arrayname}}, mean(\@qualscores);
    }
    else {
      my @data = split /,/,$returned_values[0];
      push @{$data{$arrayname}}, $data[2];
    }
  }
  
  # Get library type for this run
  $qry = $reports->get_library_type_for_run(\%query_properties);
  $avg = $qry->to_csv;
  @returned_values = split /\n/, $avg;
  shift @returned_values;
  my $libtype = shift @returned_values;
  
  #push @library_types, $libtype;
  if (!$libtype) { $libtype = 'Unknown'; }
  $library_types{$libtype} ++;
  
  
  # Get contaminant screening results for this run
  # Need number of lanes in this run first for more meaningful stats
  $qry = $reports->list_lanes_for_run($runID);
  $avg = $qry->to_csv;
  @returned_values = split /\n/, $avg;
  
  shift @returned_values;
  my @lanes = ();
  foreach my $analysis (@returned_values) {
    my @dat = split /,/, $analysis;
    push @lanes, $dat[0];
  }
  
  @lanes = $confuncs->remove_duplicates(\@lanes);
  @lanes = sort {$a <=> $b} @lanes;
  
  # Also need list of contaminants that were screened in this run
  $qry = $reports->list_contaminants(\%query_properties);
  $avg = $qry->to_csv;
  @returned_values = split /\n/, $avg;
  shift @returned_values;
  my @contaminant_refs = @returned_values;
  
  foreach my $lane (@lanes) {
    $query_properties{LANE} = $lane;
    push @{$runs_lanes{$runID}}, $lane;
    foreach my $contaminant (@contaminant_refs) {
      $contaminants_screened{$contaminant} = 1;
      
      my $qry = $reports->contaminant_summary($contaminant, \%query_properties);
      my $avg = $qry->to_csv;
      my @returned_values = split /\n/, $avg;
      shift @returned_values;
      
      # Several values returned here. What do we actually want?
      # ref_kmer_percent is the percentage of the reference that is represented in the reads.
      # percentage is the percent of reads that have kmers from the reference.
      # Proper interpretation of contaminant data requires both figures, really.
      foreach my $line (@returned_values) {
        my @sp = split /,/, $line;
        my $average = $sp[0];
        my $type = $sp[3];
        
        $screening{$instrument}{$runID}{$lane}{$contaminant}{$type} = $average;
      }
    }
  }
  
  
  # People are interested in seeing the relative abundances of different libraries in each
  # lane of a run.
  # Data for that is (apparently) available, but concisely presenting it is another matter.
  # Use count_reads_for_run in Reports. It returns read counts for every sample in a run.
  # Add it up as appropriate for what I want here.
  $qry = $reports->count_reads_for_run($runID);
  $avg = $qry->to_csv;
  @returned_values = split /\n/, $avg;
  shift @returned_values;
  
  # Columns from this query are numreads, lane, pair, sample_name and barcode
  foreach my $line (@returned_values) {
    my @sp = split /,/, $line;
    my ($numreads,$lane,$pair,$sample_name,$barcode) = @sp;
    
    $num_reads{$runID}{$lane}{$sample_name} += $numreads;
    if (!$barcode) { $barcode = 'NoIndex'; }
    $barcodes{$runID}{$lane}{$sample_name} = $barcode;
  }
  
  
  # If I'm going to print out per-run details as they come in, this is the place to do it!
  
}



# Start outputting the retrieved figures here

# STILL TO ADD:
# Mean Phred quality score (+ variation) across all runs
# Percentage of various contaminants!
# Breakdown of library types. (Preparing a bar plot would be nice and simple, plus pretty)

# I want all this data printed out in a much prettier format. Tables where appropriate.
# Functions for table production are in the Consumers module.

# SUM TABLE
my @tablines = (
                $total_runs,
                "$total_bases (".mean(\@numbases)." +/- ".(int stdev(\@numbases) * 2)." per run)",
                "$total_sequences (".(int mean(\@numseqs))." +/- ".(int stdev(\@numseqs) * 2)." per run)",
                "$total_samples (".(int mean(\@numsamples))." per run)",
                (int sum(\@{$data{clusters}}))." (+/- ".(int stdev(\@{$data{clusters}}) * 2)." per run)",
                (int sum(\@{$data{clusterspf}}))." (+/- ".(int stdev(\@{$data{clusterspf}}) * 2)." per run)"
                );
my $l = 0;
foreach my $i (@tablines) {
  if (length $i > $l) { $l = length $i; }
}


print "

SUM AND AVERAGE SUMMARY FIGURES FOR INTERVAL
+------------------------+-".("-" x $l)."-+
| TOTALS                 | ".(" " x $l)." |
+------------------------+-".("-" x $l)."-+
| Runs                   | ".(" " x ($l - length $tablines[0])).$tablines[0]." |
| Bases                  | ".(" " x ($l - length $tablines[1])).$tablines[1]." |
| Sequences              | ".(" " x ($l - length $tablines[2])).$tablines[2]." |
| Samples                | ".(" " x ($l - length $tablines[3])).$tablines[3]." |
| Clusters               | ".(" " x ($l - length $tablines[4])).$tablines[4]." |
| Clusters passed filter | ".(" " x ($l - length $tablines[5])).$tablines[5]." |
+------------------------+-".("-" x $l)."-+
";

# Set up this table as a more manageable structure too
my @labels = ('Runs','Bases','Sequences','Samples','Clusters','Clusters passed filter');
my @sum_table = ();
push @sum_table, [@labels];
push @sum_table, [@tablines];

# AVG TABLE
@tablines = (
                int mean(\@readlengths),
                int mean(\@{$data{quality}}),
                int mean(\@{$data{density}}),
                int mean(\@{$data{densitypf}}),
                $confuncs->round_to_x_places(mean(\@{$data{percentphasing}}),6),
                $confuncs->round_to_x_places(mean(\@{$data{percentprephasing}}),6)
                );
$l = 0;
foreach my $i (@tablines) {
  if (length $i > $l) { $l = length $i; }
}

print "
+--------------+-".("-" x $l)."-+
| AVERAGES     | ".(" " x $l)." |
+--------------+-".("-" x $l)."-+
| Read length  | ".(" " x ($l - length $tablines[0])).$tablines[0]." |
| Phred score  | ".(" " x ($l - length $tablines[1])).$tablines[1]." |
| Density      | ".(" " x ($l - length $tablines[2])).$tablines[2]." |
| Density PF   | ".(" " x ($l - length $tablines[3])).$tablines[3]." |
| % Phasing    | ".(" " x ($l - length $tablines[4])).$tablines[4]." |
| % Prephasing | ".(" " x ($l - length $tablines[5])).$tablines[5]." |
+--------------+-".("-" x $l)."-+
";

# Set up this table as a more manageable structure too
@labels = ('Read length','Phred score','Density','Density PF','% Phasing','% Prephasing');
my @avg_table = ();
push @avg_table, [@labels];
push @avg_table, [@tablines];

# Breakdown of run types table
@tablines = ();
my @tablabs = ();
foreach my $k (keys %library_types) {
  push @tablines, $library_types{$k};
  push @tablabs, $k;
}

my $l1 = length "LIBRARY TYPE";
foreach my $i (@tablines) {
  if (length $i > $l1) { $l1 = length $i; }
}

my $l2 = 40;

my $l3 = length "FREQ";
foreach my $i (@tablabs) {
  if (length $i > $l3) { $l3 = length $i; }
}

print "
PROPORTION OF LIBRARY TYPES OVER INTERVAL
+-".("-" x $l1)."-+-".("-" x $l2)."-+-".("-" x $l3)."-+
| LIBRARY TYPE".(" " x ($l1 - length "LIBRARY TYPE"))." | PROPORTION".(" " x ($l2 - length "PROPORTION"))." | FREQ".(" " x ($l3 - length "FREQ"))." |
+-".("-" x $l1)."-+-".("-" x $l2)."-+-".("-" x $l3)."-+
";
my $sumvals = sum(\@tablines);
if (@tablines) {
  foreach my $i (1..@tablines) {
    $i --;
    my $prop = int ($tablines[$i] / $sumvals);
    print "| ".$tablabs[$i].(" " x ($l1 - length $tablabs[$i]))." | ".("=" x ($prop * $l2)).(" " x ($l2 - ($prop * $l2)))." | ".(" " x ($l3 - length $tablines[$i])).$tablines[$i]." |\n";
  }
}
else {
  print "| No library type information available".(" " x ($l1 + $l2 + $l3 + 6 - length "No library type information available"))." |\n";
}
print "+-".("-" x $l1)."-+-".("-" x $l2)."-+-".("-" x $l3)."-+
";

# Set up this table as a more manageable structure too
my @lib_table = ();
# This table needs two data columns: proportion of total (as percent), and frequency.
my @lib_table_proportion = ();
foreach my $value (@tablines) {
  push @lib_table_proportion, (($value / $sumvals) * 100);
}
push @lib_table, [@tablabs];
push @lib_table, [@lib_table_proportion];
push @lib_table, [@tablines];


# Error rate?
# In the future maybe.


# Contaminant screening percentages
# I want to break this down by machine (it's more useful)
# Show % reads and % ref columns for every contaminant
# Bit of an awkward table, this one
my @tabls = ();    # Easier to store the various lengths in an array here
my @contaminants = sort {$a cmp $b } keys %contaminants_screened;
my $minwidth = 15; # That is, 100.000 x 2, plus one central space.

# Set first column width - instrument names
$l = length ("CONTAMINANT");
foreach my $instrument (keys %statsdb_instruments) {
  my $insl = length ($instrument);
  if ($insl > $l) { $l = $insl; }
}
push @tabls, $l;

# Set other column widths - contaminant names
foreach my $ref (@contaminants) {
  my $refl = length($ref);
  if ($refl > $minwidth) { push @tabls, $refl; }
  else                   { push @tabls, $minwidth; }
}

print "
CONTAMINANT SCREENING SUMMARY
+";
# Draw top line
foreach my $l (@tabls) { print "-".("-" x $l)."-+"; }
my @coltitles = @contaminants;
unshift @coltitles, "CONTAMINANT";
print "\n|";
# First line in the header - contaminant names
foreach my $c (1..@coltitles) {
  $c--;
  my $title = $coltitles[$c];
  my $colsize = $tabls[$c];
  my $l = length $title;
  print " $title".(" " x ($colsize - $l))." |";
}
# Second line in the header - subfields (%reads and %ref)
print "\n| INSTRUMENT".(" " x ($tabls[0] - length("INSTRUMENT")))." |";
foreach my $c (1..@contaminants) {
  $c--;
  my $colsize = $tabls[$c+1];
  my $l1 = length("% reads");
  my $l2 = length("% ref  ");
  print " % ref   % reads".(" " x ($colsize - ($l1 + $l2 + 1)))." |";
}
print "\n+";
# Draw bottom line of header
foreach my $l (@tabls) { print "-".("-" x $l)."-+"; }
print "\n|";
# Make a line for every instrument
my %con_table_data = ();
foreach my $instrument (sort {$a cmp $b} keys %statsdb_instruments) {
  print " $instrument".(" " x ($tabls[0] - length($instrument)))." |";
  
  foreach my $c (1..@contaminants) {
    $c--;
    my $ref = $contaminants[$c];
    # There will, more likely than not, be several runs on each machine. I've got to get
    # the average of everything for the current contaminant.
    my @readdata = ();
    my @refdata = ();
    my @runs = keys $screening{$instrument};
    
    foreach my $run (@runs) {
      my @lanes = keys $screening{$instrument}{$run};
      foreach my $lane (@lanes) {
        push @readdata, $screening{$instrument}{$run}{$lane}{$ref}{percentage};
        push @refdata, $screening{$instrument}{$run}{$lane}{$ref}{ref_kmer_percent};
      }
    }
    
    my $readmean = $confuncs->round_to_x_places(mean(\@readdata), 3);
    my $refmean = $confuncs->round_to_x_places(mean(\@refdata), 3);
    
    my $colsize = $tabls[$c+1];
    my $numstring = " ".(" " x (7 - length($refmean)))."$refmean ".
    (" " x (7 - length($readmean)))."$readmean";
    
    print $numstring;
    print " " x ($colsize - length($numstring) + 1)." |";
    
    push @{$con_table_data{"$ref-ref"}}, $refmean;
    push @{$con_table_data{"$ref-read"}}, $readmean;
  }
  
  print "\n+";
}
# Draw bottom line
foreach my $l (@tabls) { print "-".("-" x $l)."-+"; }
print "\n";

# Sort this out into a more manageable data structure too
my @con_table = ();
push @con_table, [sort {$a cmp $b} keys %statsdb_instruments];
foreach my $ref (@contaminants) {
  push @con_table, [@{$con_table_data{"$ref-ref"}}];
  push @con_table, [@{$con_table_data{"$ref-read"}}];
}


# In @timedata, I have a list of all the op times of all the runs of any relevance here.
# SCRATCH THAT - I can get all that in a single query - in a more R-friendly format, at that -
# from the operations_overview procedure. Use that instead.

# I would also like to display the runs that are currently in progress, or have failed.
# Both data sets will be merged together in one text file, and sent to an R script for plotting.
#my $miso = QCAnalysis::MISO->new($miso_config);
#my $allrunsdata = $miso->get_run_info();

# Get operation overview table
$qry = $reports->get_operation_overview($input_values);
my $avg = $qry->to_csv;
my @timedata = split /\n/, $avg;
shift @timedata;

# Modify table - make the PAIR column contain more specific data
# That is, modify the numbers to specify that we're working with read numbers.
# Also, modify any lines where PAIR = 0, because they're not useful here. In R,
# we'll strip those out.
my @timedata2;
LINE: foreach my $line (@timedata) {
  my @sp = split /,/, $line;
  my $datetype = $sp[0];
  my $pair = $sp[5];
  
  #if ($pair eq '0') {
  #  $pair = 'completed';
  #}
  
  #$datetype =~ s/run_//g;
  if ($datetype =~ /run_/) {
    next LINE;
  }
  
  $datetype =~ s/read_//g;
  
  if ($pair =~ /index/) {
    $pair =~ s/i/I/;
  }
  elsif ($pair =~ /^[0-9]+$/) {
    $pair = "Read$pair";
  }
  
  $sp[0] = $datetype;
  $sp[5] = $pair;
  $line = join ',', @sp;
  push @timedata2, $line;
}
@timedata = @timedata2;
@timedata2 = ();

# Get all runs from MISO
my $miso = QCAnalysis::MISO->new($input_values->{MISO_CONFIG});
my $allrunsdata = $miso->get_run_info();

# $allrunsdata is a big array of hashes - each hash holding details of a single run.
# Cycle them and get the relevant ones.
# This needs comparison between two different date types.
# Get the start and end dates supplied as input in numeric format, same as MISO uses.
my $intervalstart = Timecode::convert_to_numeric_datestamp($input_values->{BEGIN});
my $intervalend = Timecode::convert_to_numeric_datestamp($input_values->{END});
#print "CURRENT TIME:\n".(time)."\n\nINTERVAL START/END IN UNIX EPOCH:\n$intervalstart to $intervalend\n\n";
RUN: foreach my $run (@$allrunsdata) {
  # Is run within correct date range? Inclusive comparison.
  
  # Note that as yet, this script can only support Illumina runs.
  # MISO should standardise this data sufficiently that other platforms can
  # be supported, but I've found cases where it isn't quite there yet.
  # It seems to be old SOLID runs. Others seem OK.
  
  my $platform = $run->{platformType};
  unless ($platform =~ /illumina/i) { next RUN; }
  
  # Get run's current condition - running, complete, failed etc.
  my $health = lc $run->{status}{health};
  
  my $runstart = Timecode::format_numeric_datestamp($run->{status}{startDate});
  
  
  # OK, this proves problematic. It causes all sorts of weirdness to happen, like including
  # incomplete runs that commence AFTER the end date that this sets.
  # How about if running, set to today's date? That would make much more sense. 
  my $runend = ();
  if ($run->{status}{completionDate}) {
    $runend = Timecode::format_numeric_datestamp($run->{status}{completionDate});
  }
  elsif ($health eq 'running') {
    # If run is listed as still running, check if the run's start date lies within 3 months of
    # the interval start date. Otherwise, skip it.
    my $toofarback = 7776000;
    my $time = time();
    if ($runstart < ($intervalstart - $toofarback)) {
      next RUN;
    }
    # Likewise, if the run's total run time is greater than 3 months, skip it.
    if (($time - $runstart) > $toofarback) {
      next RUN;
    }
    
    $runend = $time;
  }
  else {
    next RUN;
  }
  
  my $runname = $run->{status}{runName};
  
  if ((($runend <= $intervalend) && ($runend >= $intervalstart))
      || (($runstart >= $intervalstart) && ($runstart <= $intervalend))
      || (($runstart <= $intervalstart) && ($runend >= $intervalend))) {
    #print "$runstart to $runend ($health) IN";
    # Check if the run is in the list of runs retrieved from StatsDB.
    unless ($runname ~~ @runs_in_range) {
      #print " NEW";
      # If we're interested in this run, add its record to the table.
      # Columns:
      # date_type, date, instrument, run, lane, pair
      # Oh - I need to do this twice, for start and end times.
      
      # Number of lanes is not consistently available from this data; I would need
      # to look in MISO if I wanted that.
      
      # This statement brings the $health descriptor used in MISO in line with what I use
      # in the database
      my $print_health = $health;
      if ($health =~ /running/) { $print_health =~ s/running/run/g; }
      
      # Cycle lanes in the run here, creating distinct start/end entries for
      # each lane.
      # That means getting the number of lanes. 
      # Good opportunity to deal with hiseq dual-flowcell stuff at the same time
      # First, check if this run is from a hiseq
      # Then, check if it has the 'B' identifier in its run ID 4th section
      # Then, modify lane numbers as appropriate (add 8 so that the second row of lanes
      # doesn'tcrash into the first set when plotted)
      # note: the structure of these objects seems to change a bit in some old
      # versions; ensure at least one lane can always be represented
      my $lanes = $run->{runQCs}[0]{partitionSelections};
      my $hiseq_dual_flowcell_adjustment = 0;
      if ($lanes) {
        if ($run->{sequencerPartitionContainers}[0]{platform}{instrumentModel} =~ /hiseq/i) {
          my @splitOnUscores = split /_/, $run->{alias};
          my $indicator = substr($splitOnUscores[3],0,1);
          if ($indicator =~ /b/i) {
            $hiseq_dual_flowcell_adjustment = 8;
          }
        }
      }
      else {
        push @$lanes, '1';
      }
      foreach my $lane (1..@$lanes) {
        # Do lane number adjustment based on run ID here?
        my $lanenum = $lane + $hiseq_dual_flowcell_adjustment;
        
        my @line = ();
        push @line, "start";        
        push @line, Timecode::convert_from_numeric_datestamp($runstart);
        push @line, $run->{status}{instrumentName};
        push @line, $run->{status}{runName};
        push @line, $lanenum;
        push @line, $print_health;
        push @timedata, join ',', @line;
        
        @line = ();
        push @line, "end";        
        push @line, Timecode::convert_from_numeric_datestamp($runend);
        push @line, $run->{status}{instrumentName};
        push @line, $run->{status}{runName};
        push @line, $lanenum;
        push @line, $print_health;
        push @timedata, join ',', @line;
      }
    }
    
    #print Dumper($run);
    #my $rngoerigeg = <STDIN>;
    
    
  }
}
print "\n";

# Pack that data off to R to be plotted
#my ($plot, $timedataFile) = $confuncs->machine_activity_plot($input_values,\@timedata);
# Commented out for now due to lack of lubridate.
my $plot = "ops_plot.pdf";

#########
# LaTeX #
#########

# This is a good place to start generating a PDF report, I suppose.
# Give it a filename and title that reflects the time interval we're looking at
my $hr_startdate = Timecode::convert_to_human_readable_date($input_values->{BEGIN});
my $hr_enddate = Timecode::convert_to_human_readable_date($input_values->{END});

my $filename_startdate = $hr_startdate;
my $filename_enddate = $hr_enddate;
my $texfile = "operations_report_$filename_startdate"."_to_$filename_enddate.tex";
open(TEX, ">", $texfile)
  or die "ERROR: Cannot open LaTeX script file operations_report_$filename_startdate"."_to_$filename_enddate.tex\n";

my $texstr = $confuncs->new_texdoc();
print TEX $texstr;

# Print a big header thing
print TEX "\\setlength{\\parindent}{0pt}
\\large
{\\bf Operations overview} \\\\
{\\bf $hr_startdate to $hr_enddate}
\\vspace{4 mm}
\\normalsize
";

# Incorporate the figure that I just made using R
$texstr = $confuncs->make_simple_figure($plot);
print TEX $texstr;

# Count that all up and make a table.
# Be sure never to count a run twice.
my $total_time = $intervalend - $intervalstart;
my %runtimes = ();
my %instrumenttimes = ();
my %allruns = (); my %allinstruments;
foreach my $line (@timedata) {
  my @sp = split /,/, $line;
  
  my $type = $sp[0];
  my $date = $sp[1];
  my $instrument = $sp[2];
  my $run = $sp[3];
  my $read = $sp[4];
  
  $date = Timecode::convert_to_numeric_datestamp($date);
  if (($date > $intervalend) && ($type =~ /end/))     { $date = $intervalend; }
  if (($date < $intervalstart) && ($type =~ /start/)) { $date = $intervalstart; }
  
  #if ($type =~ /read_start/) { $type = "read".$read."_start"; }
  #if ($type =~ /read_end/) { $type = "read".$read."_end"; }
  
  $runtimes{$run}{instrument} = $instrument;
  $runtimes{$run}{$type} = $date;
  
  #print "runtimes{$run}{$type} = $date\n";
  
  $instrumenttimes{$instrument} = $total_time;
  $allruns{$run} = 1;
  $allinstruments{$instrument} = 1;
}

#print "TOTAL INTERVAL TIME: $total_time\n";
RUN: foreach my $run (keys %allruns) {
  # Get times. May be under different names
  my $runtime = ();
  my ($start, $end) = ();
  
  $start = $runtimes{$run}{start};
  $end = $runtimes{$run}{end};
  $runtime = $end - $start;
  
  my $instrument = $runtimes{$run}{instrument};
  $instrumenttimes{$instrument} -= $runtime;
  
  #print "\t-$runtime\t[$start - $end] from $instrument\t($run)\n";
}

# Let's try a different approach.
# I'm sure there's a mathematical way to do this, but I don't know what it is.
# Maybe an interval tree. I dunno.
# This will be pretty memory intensive.
# Set::IntSpan::Fast may be good for this, if run in a context where modules can be installed.
foreach my $instrument (keys %allinstruments) {
  my %seconds = ();
  foreach my $second ($intervalstart..$intervalend) {
    $seconds{$second} = 1;
  }
  
  RUN: foreach my $run (keys %allruns) {
    unless ($runtimes{$run}{instrument} eq $instrument) {
      next RUN;
    }
    
    my ($runstart, $runend) = ();
    
    $runstart = $runtimes{$run}{start};
    $runend = $runtimes{$run}{end};
    
    foreach my $second ($runstart..$runend) {
      $seconds{$second} = 0;
    }
  }
  
  my $runtime = 0;
  foreach my $second (keys %seconds) {
    if ($seconds{$second} == 1) {
      $runtime ++;
    }
  }
  
  $instrumenttimes{$instrument} = $runtime;
}


# Now print the table that shows usage figures.
$l1 = length "INSTRUMENT";
foreach my $instrument (keys %allinstruments) {
  if (length $instrument > $l1) { $l1 = length $instrument; }
}

$l2 = length "% ACTIVITY";

print "ACTIVITY LEVEL OF INSTRUMENTS OVER INTERVAL
+-".("-" x $l1)."-+-".("-" x $l2)."-+
| INSTRUMENT".(" " x ($l1 - length "INSTRUMENT"))." | % ACTIVITY".(" " x ($l2 - length "% ACTIVITY"))." |
+-".("-" x $l1)."-+-".("-" x $l2)."-+
";
my @active_pc = ();
foreach my $instrument (sort {$a cmp $b} keys %allinstruments) {
  my $inactive = $instrumenttimes{$instrument} / $total_time;
  my $active = 1 - $inactive;
  
  my $active_pc = $confuncs->round_to_x_places(($active * 100), 2);
  my $inactive_pc = $confuncs->round_to_x_places(($inactive * 100), 2);
  
  print "| ".$instrument.(" " x ($l1 - length $instrument))." | ".(" " x ($l2 - length $active_pc)).$active_pc." |\n";
  push @active_pc, $active_pc;
}

print "+-".("-" x $l1)."-+-".("-" x $l2)."-+

";
my @act_table = ();
push @act_table, [sort {$a cmp $b} keys %allinstruments];
push @act_table, [@active_pc];


# I could also remake all the tables I put on the command line earlier in latex.
# (Later tables can be written too)
# Data for the tables produced so far is in @sum_table, @avg_table, @lib_table, @con_table
# and @act_table.

# Tables here should be in small-size text
print TEX "\n\\footnotesize\n";

# Sums table
print TEX "\n{\\bf Sums \\& averages}\n\\vspace{4mm}\n\n";
my @headers = ('Totals', ' ');
$texstr = $confuncs->make_simple_table(\@headers, \@sum_table);
print TEX "$texstr\n\n";

# Averages table
@headers = ('Averages', ' ');
$texstr = $confuncs->make_simple_table(\@headers, \@avg_table);
print TEX "$texstr\n\n";

# Libraries table
print TEX "\n{\\bf Library types}\n\\vspace{4mm}\n\n";
@headers = ('Library type', 'Proportion (\%)','Frequency');
$texstr = $confuncs->make_simple_table(\@headers, \@lib_table);
print TEX "$texstr\n\n";

# Contaminant table is a little more involved. There is a double header, and some cells in it are
# double-width.
# The two lines can be achieved just by writing them as two lines in the header string. Note the
# bunch of backslashes. Then the rest of the data goes in just like normal.
# Use the multiline package to make double-width cells.
print TEX "\n{\\bf Contaminant screening summary}\n\\vspace{4mm}\n\n";
@headers = ('Contaminant');
$c = 0;
foreach my $contaminant (@contaminants) {
  $c ++;
  my $print_con = $contaminant;
  $print_con =~ s/_/\\_/g;
  my $string = "\\multicolumn{2}{l}{".$print_con.'}';
  if ($c == @contaminants) {
    $string .= " \\\\ \n";
  }
  push @headers, $string;
}
# Second line too
push @headers, 'Instrument';
foreach my $contaminant (@contaminants) {
  push @headers, '\%ref';
  push @headers, '\%reads';
}
$texstr = $confuncs->make_simple_table(\@headers, \@con_table, 1);
print TEX "$texstr\n\n";

# Activity table
print TEX "\n{\\bf Instrument activity}\n\\vspace{4mm}\n\n";
@headers = ('Instrument', 'Activity (\%)');
$texstr = $confuncs->make_simple_table(\@headers, \@act_table);
print TEX "$texstr\n\n";

$texstr = $confuncs->clear_page();
print TEX $texstr;


# One more thing: adapter performance.
# This won't get displayed on the command line at all - it will go straight to R
# and LaTeX, because I can't think of a good way of meaningfully summarising it in a single
# neat little package.
# Note: this can only display runs taken from StatsDB, where this information is available.
print TEX "\\large\n{\\bf Adapter performance overview} \\\\ \n\\normalsize\n\n";
foreach my $run (@runs_in_range) {
  # Make a plot for each lane in this run
  my @plots = ();
  my @lanes = sort {$a <=> $b} keys %{$num_reads{$run}};
  foreach my $lane (@lanes) {
    my ($plotfile,$datafile) = $confuncs->adapter_performance_barplot($num_reads{$run}{$lane},$barcodes{$run}{$lane},"Lane $lane");
    push @plots, $plotfile;
  }
  
  # The underscore must be escaped in latex docs. Make it so here.
  my $printable_run = $run;
  $printable_run =~ s/_/\\_/g;
  
  # Wrangle all this run's plots into a single neat figure
  # Print a bit of text saying which run this is first.
  print TEX "{\\bf Run $printable_run} \\\\ \n";
  
  $texstr = $confuncs->make_fastqc_report_figure(\@plots);
  print TEX $texstr;
}

# Once that's all done, close up the doc
$texstr = $confuncs->end_texdoc();
print TEX $texstr;

close TEX;

# Now make it into a PDF
$confuncs->latex_to_pdf($texfile);








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

