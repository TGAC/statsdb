package QCAnalysis::InterOp;
use base 'QCAnalysis';
use strict;
no strict "refs";
use IO::File;
use Bio::IlluminaSAV;
use Storable;
use lib '..';
use Timecode;

# This module is a bit bigger than the other parsers, since it must also
# produce summary stats for the InterOp data. The InterOp files are far too
# large to insert into the DB whole, so must be summarised.
# This is made rather more difficult by the differences in formatting between
# the various InterOp files.

# Check, once I'm getting closer, if these could be knocked down to my
our %interop_values;
my $data;
my @pairs;

# Key is InterOp readID, value is the value that should go in the DB.
my %database_pairids = ();
my $run_directory;
my @InterOp_files;
my @bases = ('N', 'A', 'C', 'G', 'T');
my %read_ends = ();

# I want a couple of reasonable options in terms of input:
# One, to parse all the files in a single directory when it's passed in.
# Two, to parse an individual file when passed directory and filename.
# Importantly, both should produce the same sort of output to the database.
# That means a distinct analysis (new analysis_id) for each file as well as each
# lane, etc.

# INPUT TO THIS MODULE:
  # statsdb_string.txt can very easily be given everything we need within
  # its current structure. Indeed, all that's REALLY necessary is the run
  # directory on a single line in statsdb_string.txt. Everything else can
  # be dealt with inside this module.
  # I'll return an array of objects, which can then be added to the data-
  # base using insert_analysis() by the calling script.

sub parse_directory {
  my $class = shift;
  $run_directory = shift;
  $run_directory =~ s/\/$//g;
  my $analysis = shift;
  
  # You can think of this sub as a kind of wrapper for parse_file.
  # When given a directory, it gets all the relevant InterOp files, and passes each in turn to
  # parse_file. The result is a set of objects primed for insertion into the database, exactly
  # as if a consumer had been given a list of files from statsdb_string.txt.
  
  opendir(INTEROP, "$run_directory/InterOp/") or die "Cannot find InterOp directory in run directory $run_directory\n";
  @InterOp_files = grep {/MetricsOut.bin/} readdir INTEROP;
  closedir INTEROP;
  
  my @analyses = ();
  foreach my $file (@InterOp_files) {
	my $thisfile_analyses = parse_file ("$run_directory/InterOp/$file", $analysis);
	
	foreach my $thisfile_analysis (@$thisfile_analyses) {
	  push @analyses, $thisfile_analysis;
	}
  }
  
  return \@analyses;
}

sub parse_file {
  my $class = shift;
  
  # Inputs here are run directory, file and a generic analysis object (which I'll clone
  # and fill up as appropriate).
  
  # This sub is meant to be the main entrance point to the module.
  # Pass in the name of a file (full path) and a generic analysis object.
  # Outputs are a list of objects containing data, based on that initial object.
  my $file = ();
  if ($class =~ /^[a-zA-Z0-9]+\:\:[a-zA-Z0-9]+$/) { $file = shift; }
  else { $file = $class; }
  
  my $generic_analysis = shift;
  
  # $data should be reset, or the amount of data read in from the SAV files causes
  # system memory to fill up quickly and pointlessly.
  $data = ();
  
  # Get the run directory if not yet supplied
  if (!$run_directory) {
	$run_directory = $file;
	$run_directory =~ s/\/InterOp\/[a-zA-Z0-9]+.bin$//g;
  }
  
  # The filename supplied will most likely be a full path.
  # We only need the actual file name.
  my @split = split /\//, $file;
  $file = $split[-1];
  
  # Check that the file exists.
  unless (-e "$run_directory/InterOp/$file") {
	return "WARN: file\n $file\ninaccessible or does not exist";
  }
  
  # Get basic run information (RunInfo.xml)
  RunInfo($run_directory);
  # If this is inaccessible, then we cannot go any further. Return an error.
  unless ($data->{info}) {
	return "WARN: basic run parameters (number of lanes, read length etc) unavailable";
  }
  
  # Read the relevant SAV file into memory
  read_file($file, $run_directory); 
  
  # Figure out number of lanes, since each lane needs its own set
  # of records. (Each lane is a different analysis).
  my $number_of_lanes = NumLanes($run_directory);
  
  # Figure out the read IDs, where each read starts and ends, etc.
  # InterOp files contain data for index reads as well as sequence reads.
  # Keep everything, but sort out what the read IDs in the InterOp should
  # translate to.
  # (MUST only be called after RunInfo has been called)
  read_ids_and_lengths();
  
  # Add some generic properties to the $analysis object
  # This need only be the most basic stuff (run ID) since other
  # analysis properties are already filled in by FastQC
  my $run = get_run_id($run_directory);
  $generic_analysis->add_property("run", $run);
  $generic_analysis->add_property("interop_folder", $run_directory."/InterOp");
  $generic_analysis->add_property("tool", "InterOp");
  
  # InterOp data is contained within a set of files rather than a single file, and each of
  # those files contains quite different types of data. By figuring out which file we've got
  # here, we learn how to handle the data in it.
  my $data_classification = $file;
  $data_classification =~ s/Out.bin//g;
  #$generic_analysis->add_property ("data_classification", $data_classification);
  # Try storing this property as 'encoding', since that's an appropriate term for
  # what each file holds.
  # UPDATE: 'encoding' is in use by something else. Use 'interop_subtype'.
  $generic_analysis->add_property ("interop_subtype", $data_classification);
  
  # Input comes in as a single file, but I need to output a distinct
  # object for each combination of lane, read and data type.
  # Copy the $analysis object (which is otherwise set up) and modify it
  # to have these properties, as appropriate, for each combination.
  my @analyses = ();
  print "Retrieving $data_classification data for\n";
  foreach my $lane (1..$number_of_lanes) {
	
	# @pairs is set up in read_ids_and_lengths
	# It uses InterOp-style readIDs (so, including index reads)
	# See that sub for an explanation
	foreach my $pair (@pairs) {
	  # Each lane and read will have its own record
	  # For example, lane 1/read 1 will be recognised as a distinct analysis,
	  # as will lane 1/read 2
	  # That requires cloning the oriinal analysis object supplied as input
	  my $single_analysis = $generic_analysis->clone();
	  $single_analysis->add_property("lane", $lane);
	  $single_analysis->add_property("pair", $pair);
	  print "--lane $lane, pair $database_pairids{$pair}\n";
	  
	  # Start and end times of a particular read can also now be added
	  $single_analysis->add_date('read_start',Timecode::read_start($run_directory,$pair));
	  $single_analysis->add_date('read_end',Timecode::read_end($run_directory,$pair));
	  
	  parse_data($file, $single_analysis);
	  
	  #my $single_analysis = prepare_analysis_object($run_directory, $file, $lane, $pair, $generic_analysis);
	  
	  # Now that I've extracted and sorted out the data for this
	  # analysis, I should change its read identifier to the human-readable version
	  # rather than the InterOp version (use %database_pairids)
	  $single_analysis->add_property("pair", $database_pairids{$pair});
	  
	  # parse_files returns a hash reference structure if it is successful;
	  # otherwise, it returns a string.
	  if (ref($single_analysis)) {
		push @analyses, $single_analysis;
	  }
	}
  }
  
  
  
  
  
  return \@analyses;
}


# ATTEMPTING TO BYPASS THIS
#sub prepare_analysis_object {
#  my $run_directory = shift;
#  my $file = shift;
#  my $lane = shift;
#  my $pair = shift;
#  my $generic_analysis = shift;
#  
#  # Previous subs have dealt with constructing the set of objects that will be
#  # necessary given the data at hand.
#  # This sub sets off the hard work of actually retrieving and filling a given
#  # object with data from a given file.
#  
#  # I want to clone $generic_analysis, not just copy the pointer.
#  # Create a local copy in this scope. This suffices for the scale of the hash
#  # in its present state.
#  # (I.e., it works because it's not a recursive structure)
#  #my %localcopy = %$generic_analysis;
#  #my $specific_analysis = \%localcopy;
#  #bless $specific_analysis, "QCAnalysis";
#  
#  #my $specific_analysis = Storable::dclone($generic_analysis);
#  #bless $specific_analysis, "QCAnalysis";
#  
#  my $specific_analysis = $generic_analysis->clone();
#  
#  
#  # Add these things as data using add_header_scope and add_property
#  # Use add_property to add analysis_property things
#  # NOTE for when you want to get at these:
#  # use get_property
#  $specific_analysis->add_property("lane", $lane);
#  $specific_analysis->add_property("pair", $pair);
#  print "--lane $lane, pair $pair\n";
#  
#  parse_data($file, $specific_analysis);
#  
#  # Now that I've extracted and sorted out the data for this
#  # analysis, I should change its read identifier to the human-readable version
#  # rather than the InterOp version (use %database_pairids)
#  #$specific_analysis->add_property("pair", $database_pairids{$pair});
#  
#  return $specific_analysis;
#}

sub read_ids_and_lengths {
  # I want the start and end of each read available.
  # I also want to be able to translate between the read IDs that
  # appear in InterOp data, and those that will go into the database
  
  # Key is Interop readID and 'start' or 'end', values are start and end
  # of the read
  my $reads = $data->{info}{reads};
  
  # Read numbers are one of the values in each of the hashes stored in @$pairs
  @pairs = ();
  foreach my $p (@$reads) {
	push @pairs, $p->{readnum};
  }
  
  # The pairs in the database refer only to the actual reads, but those in
  # the InterOp data also count indexes as reads. This loop accounts for
  # that difference.
  my $db_pairid = 0;	my $index_pairid = 0;
  for (my $i = 1; $i <= @$reads; $i++) {
	my $isindex = $data->{info}{reads}[$i-1]{is_index};
	if ($isindex eq '0') {
	  $db_pairid ++;
	  $database_pairids{$i} = $db_pairid;
	}
	else {
	  $index_pairid ++;
	  $database_pairids{$i} = 'index'.$index_pairid;
	}
	
	$read_ends{$i}{start} = $data->{info}{reads}[$i-1]{first_cycle};
	$read_ends{$i}{end}   = $data->{info}{reads}[$i-1]{last_cycle};
  }
}

sub get_run_id {
  # When passed the run directory, this returns the run ID.
  # Works only on UNIX-style directories at the moment.
  my $rundir = shift;
  my @dirs = split /\//, $rundir;
  return $dirs [-1];
}

sub read_file {
  my $file = shift;
  my $rundir = shift;
  # Which SAV file is it? Read the first part of the filename to find out, and
  # then send it off to the appropriate sub to get the data out of it.
  my $parse_function = $file;
  $parse_function =~ s/Out.bin//g;
  if (defined &{$parse_function}){
	&$parse_function($rundir);
  } else {
    print "WARN: No read function:  " . $parse_function . "\n";
  }
}

# These functions all deal with retrieving the data from SAV files into memory.
# I keep them separate like this in order to avoid loading all files into memory at once.
# That turns out to be a significant and unnecessary drain on resources.

sub RunInfo {
  my $rundir = shift;
  my $sav = Bio::IlluminaSAV->new($rundir);
  $data->{info} = $sav->run_info();
}

sub NumLanes {
  my $rundir = shift;
  my $sav = Bio::IlluminaSAV->new($rundir);
  return $sav->num_lanes();
}

sub ControlMetrics {
  my $rundir = shift;
  my $sav = Bio::IlluminaSAV->new($rundir);
  $data->{ControlMetrics} = $sav->control_metrics();
}

sub CorrectedIntMetrics {
  my $rundir = shift;
  my $sav = Bio::IlluminaSAV->new($rundir);
  $data->{CorrectedIntMetrics} = $sav->corrected_int_metrics();
}

sub ErrorMetrics {
  my $rundir = shift;
  my $sav = Bio::IlluminaSAV->new($rundir);
  $data->{ErrorMetrics} = $sav->error_metrics();
}

sub ExtractionMetrics {
  my $rundir = shift;
  my $sav = Bio::IlluminaSAV->new($rundir);
  $data->{ExtractionMetrics} = $sav->extraction_metrics();
}

sub ImageMetrics {
  my $rundir = shift;
  my $sav = Bio::IlluminaSAV->new($rundir);
  $data->{ImageMetrics} = $sav->image_metrics();
}

sub QMetrics {
  my $rundir = shift;
  my $sav = Bio::IlluminaSAV->new($rundir);
  $data->{QMetrics} = $sav->quality_metrics();
}

sub TileMetrics {
  my $rundir = shift;
  my $sav = Bio::IlluminaSAV->new($rundir);
  $data->{TileMetrics} = $sav->tile_metrics();
}

sub parse_data {
  # To be clear: I've already read the file in; I now want a generalised method of
  # establishing an object that can be passed on to the database entry method.
  my $file = shift;
  my $analysis = shift;
  
  my $parse_function = $file;
  $parse_function =~ s/Out.bin//g;
  $parse_function = "parse_".$parse_function;
  
  if( defined &{$parse_function} ){
	&$parse_function($analysis);
  }else{
	print "WARN: No parse function:  " . $parse_function . "\n";
  }
}

# Write functions to deal with each specific data type

sub parse_ControlMetrics {
  my $analysis = shift;
  my $lines = $data->{ControlMetrics};
  
  # This data MAY not normally contain anything.
  # That may cause problems. Try to anticipate it.
  # (If that fails, just skip this file; it doesn't have anything we would
  # normally be very interested in anyway.)
  # It MAY also be better stored as analysis properties. CHECK.
  
  # Add the data series encountered here as valid types
  #$analysis->add_valid_type("control_name", "");
  #$analysis->add_valid_type("index_name", "");
  #$analysis->add_valid_type("control_clusters", "");
  
  # Remember, we're after a given lane and read only from this data.
  my $pair = $analysis->get_property("pair");
  my $lane = $analysis->get_property("lane");
  my $first_cycle = $data->{info}{reads}[$pair-1]{first_cycle};
  my $last_cycle = $data->{info}{reads}[$pair-1]{last_cycle};
  
  # This essentially goes through each line in the file, but collects data only
  # for the given read and lane.
  my %relevant_data = ();
  LINE: foreach my $line (@$lines) {
	# $line is a hash reference, with the folowing keys:
	# (keys marked with a * themselves contain array references)
	# lane tile read  control_name index_name control_clusters
	
	# Compare lane and read of this line to those of the analysis we're building
	my $read = $line->{read};
	unless (($read == $pair)
		&&  ($line->{lane} eq $lane)) {
	  next LINE;
	}
	
	# Deal with the various series in this file
	my $series_name = "control_name";
	my $val = $line->{$series_name};
	push @{$relevant_data{$series_name}}, $val;
	
	$series_name = "index_name";
	$val = $line->{$series_name};
	push @{$relevant_data{$series_name}}, $val;
	
	$series_name = "control_clusters";
	$val = $line->{$series_name};
	push @{$relevant_data{$series_name}}, $val;
  }
  
  # O-kaaaaay.
  # Looks like there can, in fact, be a lot of control names per lane.
  # And a lot of indexes per control name.
  # That means I've got to find a way of dealing with this stuff. 
  
  # This code will run, but won't actually add anything to the analysis object.
  # Sort it out later.
  
  
  if ($relevant_data{control_name}) {
	# Get an array (ref) of all the deduplicated control names and index names
	my $control_name = remove_duplicates($relevant_data{control_name});
	my $index_names = remove_duplicates($relevant_data{index_name});
	
	# If the returned arrays have only one thing, add as a properties.
	# If the returned arrays have multiple things, throw an error - the input has not been
	# specified correctly (there should be only one control per lane, surely?)
	
	
  }
  
  
#  foreach my $series (keys $relevant_data) {
#	my ($mean, $stdev) = summary_stats($relevant_data->{$series});
#	add_data_series_to_object($analysis, $series, $mean, $stdev);
#  }
  
  
  
  
}

sub parse_CorrectedIntMetrics {
  my $analysis = shift;
  my $lines = $data->{CorrectedIntMetrics};
  
  # Remember, we're after a given lane and read only from this data.
  my $pair = $analysis->get_property("pair");
  my $lane = $analysis->get_property("lane");
  my $first_cycle = $data->{info}{reads}[$pair-1]{first_cycle};
  my $last_cycle = $data->{info}{reads}[$pair-1]{last_cycle};
  
  # Add the data series encountered here as valid types
  foreach my $type ('mean', 'stdev') {
	$analysis->add_valid_type("avg_intensity_$type", "base_position");
	foreach my $base ('a', 'c', 'g', 't') {
	  $analysis->add_valid_type("avg_corrected_int_$base\_$type", "base_position");
	  $analysis->add_valid_type("avg_called_int_$base\_$type", "base_position");
	}
  }
  foreach my $type ('mean', 'stdev', 'max', 'upper_quartile', 'median', 'lower_quartile', 'min') {
	$analysis->add_valid_type("snr_$type", "base_position");
  }
  $analysis->add_valid_type("num_basecalls", "base_position");
  
  # This essentially goes through each line in the file, but collects data only
  # for the given read and lane.
  my %relevant_data = ();
  LINE: foreach my $line (@$lines) {
	# $line is a hash reference, with the folowing keys:
	# (keys marked with a * themselves contain array references)
	# lane tile cycle avg_intensity avg_corrected_int* avg_called_int* num_basecalls* snr
	
	# Compare lane and read of this line to those of the analysis we're building
	my $cycle = $line->{cycle};
	unless (($cycle >= $first_cycle)
		&&  ($cycle <= $last_cycle)
		&&  ($line->{lane} eq $lane)) {
	  next LINE;
	}
	
	# For some reason known to no man (but probably due to Bio::IlluminaSAV failing to
	# convert the numbers from binary properly), the values stored in num_basecalls
	# need to be multiplied by 2 ^ 149 before they become the actual number of reads.
	my $factor = 2 ** 149;
	my $basecalls = $line->{num_basecalls};
	foreach my $i (@$basecalls) {
	  $i = $i * $factor;
	}
	
	# Deal with the various series in this file
	parse_single_value ("avg_intensity", $cycle, $line, \%relevant_data);
	parse_perbase_arrayref("avg_corrected_int", $cycle, $line, \%relevant_data);
	parse_perbase_arrayref("avg_called_int", $cycle, $line, \%relevant_data);
	parse_single_value("snr", $cycle, $line, \%relevant_data);
	parse_perbase_arrayref("num_basecalls", $cycle, $line, \%relevant_data);
  }
  
  # The data we want is now stored in %relevant_data.
  # Get summary stats for each series
  foreach my $series (keys %relevant_data) {
	my ($mean, $stdev, $spread) = ();
	if ($series =~ /num_basecalls/) {
	  # num_basecalls series (there are 5) should be added up and treated as a single value
	  # per cycle
	  foreach my $cycle ($first_cycle..$last_cycle) {
		$mean->[$cycle] = sum($relevant_data{$series}{$cycle});
	  }
	}
	else {
	  ($mean, $stdev)= summary_stats($relevant_data{$series});
	  if ($series eq 'snr') {
		$spread = median_range_and_quartiles($relevant_data{$series});
	  }
	}
	add_data_series_to_object($analysis, $series, $mean, $stdev, $spread);
  }
}

sub parse_ErrorMetrics {
  my $analysis = shift;
  my $lines = $data->{ErrorMetrics};
  
  # Remember, we're after a given lane and read only from this data.
  my $pair = $analysis->get_property("pair");
  my $lane = $analysis->get_property("lane");
  
  my $first_cycle = $data->{info}{reads}[$pair-1]{first_cycle};
  my $last_cycle = $data->{info}{reads}[$pair-1]{last_cycle};
  
  # Add the data series encountered here as valid types
  foreach my $type ('mean', 'stdev', 'max', 'upper_quartile', 'median', 'lower_quartile', 'min') {
	$analysis->add_valid_type("err_rate_$type", "base_position");
  }
  
  # This essentially goes through each line in the file, but collects data only
  # for the given read and lane.
  my %relevant_data = ();
  LINE: foreach my $line (@$lines) {
	# $line is a hash reference, with the folowing keys:
	# (keys marked with a * themselves contain array references)
	# lane tile cycle err_rate err_reads*
	
	# Compare lane and read of this line to those of the analysis we're building
	my $cycle = $line->{cycle};
	unless (($cycle >= $first_cycle)
		&&  ($cycle <= $last_cycle)
		&&  ($line->{lane} eq $lane)) {
	  next LINE;
	}
	
	# Deal with the various series in this file
	parse_single_value ("err_rate", $cycle, $line, \%relevant_data);
	#parse_perbase_arrayref ("avg_corrected_int", $cycle, $line, $relevant_data);
  }
  
  # The data we want is now stored in $relevant_data.
  # Get summary stats for each series
  foreach my $series (keys %relevant_data) {
	#print "SERIES: $series\n";
	my ($mean, $stdev) = summary_stats($relevant_data{$series});
	my $spread = ();
	if ($series =~ /err_rate/) {
	  $spread = median_range_and_quartiles($relevant_data{$series});
	}
	add_data_series_to_object($analysis, $series, $mean, $stdev, $spread);
  }
}

sub parse_ExtractionMetrics {
  my $analysis = shift;
  my $lines = $data->{ExtractionMetrics};
  
  # Remember, we're after a given lane and read only from this data.
  my $pair = $analysis->get_property("pair");
  my $lane = $analysis->get_property("lane");
  my $first_cycle = $data->{info}{reads}[$pair-1]{first_cycle};
  my $last_cycle = $data->{info}{reads}[$pair-1]{last_cycle};
  
  # Add the data series encountered here as valid types
  foreach my $type ('mean', 'stdev') {
	foreach my $base ('a', 'c', 'g', 't') {
	  $analysis->add_valid_type("fwhm_$base\_$type", "base_position");
	  $analysis->add_valid_type("intensities_$base\_$type", "base_position");
	}
  }
  
  # This essentially goes through each line in the file, but collects data only
  # for the given read and lane.
  my %relevant_data = ();
  LINE: foreach my $line (@$lines) {
	# $line is a hash reference, with the folowing keys:
	# (keys marked with a * themselves contain array references)
	# lane tile cycle fwhm* intensities* cif_datestamp cif_timestamp
	
	# Compare lane and read of this line to those of the analysis we're building
	my $cycle = $line->{cycle};
	unless (($cycle >= $first_cycle)
		&&  ($cycle <= $last_cycle)
		&&  ($line->{lane} eq $lane)) {
	  next LINE;
	}
	
	# Deal with the various series in this file
	parse_perbase_arrayref ("fwhm", $cycle, $line, \%relevant_data);
	parse_perbase_arrayref ("intensities", $cycle, $line, \%relevant_data);
	
	# cif_datestamp and cif_timestamp are ignored here because these data are already
	# written into the database from another source.
  }
  
  # The data we want is now stored in $relevant_data.
  # Get summary stats for each series
  # Nope, I want PER-CYCLE here
  foreach my $series (keys %relevant_data) {
	my ($mean, $stdev) = summary_stats ($relevant_data{$series});
	add_data_series_to_object($analysis, $series, $mean, $stdev);
  }
  
}

sub parse_ImageMetrics {
  my $analysis = shift;
  my $lines = $data->{ImageMetrics};
  
  # Remember, we're after a given lane and read only from this data.
  my $pair = $analysis->get_property("pair");
  my $lane = $analysis->get_property("lane");
  my $first_cycle = $data->{info}{reads}[$pair-1]{first_cycle};
  my $last_cycle = $data->{info}{reads}[$pair-1]{last_cycle};
  
  # Add the data series encountered here as valid types
  foreach my $type ('mean', 'stdev') {
	$analysis->add_valid_type("avg_intensity_$type", "base_position");
	foreach my $base ('a', 'c', 'g', 't') {
	  $analysis->add_valid_type("avg_corrected_int_$base\_$type", "base_position");
	  $analysis->add_valid_type("avg_called_int_$base\_$type", "base_position");
	}
  }
  $analysis->add_valid_type("num_basecalls", "base_position");
  
  # This essentially goes through each line in the file, but collects data only
  # for the given read and lane.
  my %relevant_data = ();
  LINE: foreach my $line (@$lines) {
	# $line is a hash reference, with the folowing keys:
	# (keys marked with a * themselves contain array references)
	# lane tile cycle channel_id min_contrast max_contrast
	
	# Compare lane and read of this line to those of the analysis we're building
	my $cycle = $line->{cycle};
	unless (($cycle >= $first_cycle)
		&&  ($cycle <= $last_cycle)
		&&  ($line->{lane} eq $lane)) {
	  next LINE;
	}
	
	# Deal with the various series in this file
	# Here, the channel ID determines which base the max and min contrast figures apply to.
	# Standard order: 0=A, 1=C, 2=G, 3=T
	my $base = lc $bases[$line->{channel_id} + 1];
	push @{$relevant_data{"min_contrast_$base"}{$cycle}}, $line->{min_contrast};
	push @{$relevant_data{"max_contrast_$base"}{$cycle}}, $line->{max_contrast};
  }
  
  # The data we want is now stored in $relevant_data.
  # Get summary stats for each series
  foreach my $series (keys %relevant_data) {
	# Need to look at these data to be sure, but I'm pretty sure I just want single
	# values here - especially for max/min contrast.
	my ($mean, $stdev) = summary_stats ($relevant_data{$series});
	add_data_series_to_object($analysis, $series, $mean, $stdev);
  }
}

sub parse_QMetrics {
  my $analysis = shift;
  my $lines = $data->{QMetrics};
  
  # I only need the normal range quantifiers - but getting them is a
  # little more troublesome. Each tile's record itself contains a distribution of
  # quality scores, from 1 to 50 (number of reads with that qscore is stored in an
  # array, with qscore represented by array cell number)
  # I want to pool all the tiles for each cycle, giving summar values for each cycle.
  
  # Remember, we're after a given lane and read only from this data.
  my $pair = $analysis->get_property("pair");
  my $lane = $analysis->get_property("lane");
  my $first_cycle = $data->{info}{reads}[$pair-1]{first_cycle};
  my $last_cycle = $data->{info}{reads}[$pair-1]{last_cycle};
  
  # Add the data series encountered here as valid types
  foreach my $type ('mean', 'stdev', 'max', 'upper_quartile', 'median', 'lower_quartile', 'min') {
	$analysis->add_valid_type("qscore_$type", "base_position");
  }
  $analysis->add_valid_type("percent_q20", "base_position");
  $analysis->add_valid_type("percent_q30", "base_position");
  
  # This essentially goes through each line in the file, but collects data only
  # for the given read and lane.
  # Note - relevant_data should be a hash, in line with all other parser subs.
  my @relevant_data = ();
  my ($q20_data, $q30_data) = ();
  LINE: foreach my $line (@$lines) {
	# $line is a hash reference, with the folowing keys:
	# (keys marked with a * themselves contain array references)
	# lane tile cycle qscores
	
	# Compare lane and read of this line to those of the analysis we're building
	my $cycle = $line->{cycle};
	unless (($cycle >= $first_cycle)
		&&  ($cycle <= $last_cycle)
		&&  ($line->{lane} eq $lane)) {
	  next LINE;
	}
	
	# Deal with the various series in this file
	my $thistile_data = $line->{qscores};
	# How about tracking percent q20 and percent q30 per-base as well?
	my $total = sum($thistile_data);
	my ($q20, $q30) = 0;
	if ($total > 0) {
	  foreach my $qn (1..@$thistile_data) {
		# Qscores start at 1; array cells start at 0
		$qn--;
		
		# Add the current qscore to the pooled, building it up
		$relevant_data[$cycle][$qn] += $thistile_data->[$qn];
		
		# If this qscore number is >= 20 or 30, start adding up the number of runs
		if ($qn > 20) { $q20 += $thistile_data->[$qn]; }
		if ($qn > 30) { $q30 += $thistile_data->[$qn]; }
	  }
	  
	  # Store the Q20/Q30 percentages for this tile
	  $q20_data->[$cycle] = ($q20 / $total) * 100;
	  $q30_data->[$cycle] = ($q30 / $total) * 100;
	}
	else {
	  foreach my $qn (1..@$thistile_data) {
		# Qscores start at 1; array cells start at 0
		$qn--;
		
		# Add the current qscore to the pooled, building it up
		$relevant_data[$cycle][$qn] = 0;
	  }
	  $q20_data->[$cycle] = 0;
	  $q30_data->[$cycle] = 0;
	}
  }
  
  my ($mean, $stdev, $spread) = ();
  foreach my $cycle ($first_cycle..$last_cycle) {
	# Get the mean, stdev and spread metrics for the distribution of qscores (it's a freq table)
	# on this cycle.
	# MEAN
	my $qscores = $relevant_data[$cycle];	
	my $total = sum($qscores);
	
	my $this_cycle_mean = 0;
	if ($total > 0) {
	  foreach my $qn (1..@$qscores) {
		$this_cycle_mean += ($qscores->[$qn-1] * $qn);
	  }
	  $this_cycle_mean /= $total;
	}
	$mean->[$cycle] = $this_cycle_mean;
	
	# STDEV
	my $this_cycle_stdev = 0;
	my $meansq = 0;
	if ($total > 0) {
	  foreach my $qn (1..@$qscores) {
		$meansq += ($qscores->[$qn-1] * ($qn * $qn));
	  }
	  $meansq /= $total;
	  $this_cycle_stdev = sprintf "%.3f", sqrt($meansq - ($this_cycle_mean * $this_cycle_mean));
	}
	$stdev->[$cycle] = $this_cycle_stdev;
	
	# SPREAD
	my $this_cycle_spread = median_range_and_quartiles($qscores, 1);
	
	# Add each of the 5 summary stats to an array of arrays for that summary stat (just
	# like I just did with mean and stdev)
	foreach my $i (1..5) {
	  $i --;
	  $spread->[$i][$cycle] = $this_cycle_spread->[$i];
	}
  }
  add_data_series_to_object($analysis, "qscore", $mean, $stdev, $spread);
  
  # Get data percent Q20/Q30 and prepare it for database insertion too.
  add_data_series_to_object($analysis, "percent_q20", $q20_data);
  add_data_series_to_object($analysis, "percent_q30", $q30_data);
}

sub parse_TileMetrics {
  my $analysis = shift;
  my $lines = $data->{TileMetrics};
  
  # These values are all weird - I'll have to write a whole bunch of code to deal
  # with these special cases.
  # Treat per-read data as partitions across the read,
  # and per-run data as... I dunno, partitions across the run? The read?
  # The read would kinda make a bit more sense.
  
  # Remember, we're after a given lane and read only from this data.
  my $pair = $analysis->get_property("pair");
  my $lane = $analysis->get_property("lane");
  my $first_cycle = $data->{info}{reads}[$pair-1]{first_cycle};
  my $last_cycle = $data->{info}{reads}[$pair-1]{last_cycle};
  
  # Add the data series encountered here as valid types
  foreach my $type ('mean', 'stdev') {
	$analysis->add_valid_type("percentaligned_$type", "base_position");
  }
  foreach my $type ('mean', 'stdev', 'max', 'upper_quartile', 'median', 'lower_quartile', 'min') {
	$analysis->add_valid_type("percentphasing_$type", "base_partition");
	$analysis->add_valid_type("percentprephasing_$type", "base_partition");
  }
  
  # TileMetrics aren't stored in the same way as other data - each different
  # TileMetric data type is given a numeric ID, listed below
  my %tmkeys = (
	100 => "density",
	101 => "densitypf",
	102 => "clusters",
	103 => "clusterspf",
	
	(200 + ($pair - 1) * 2) => "percentphasing",
	(201 + ($pair - 1) * 2) => "percentprephasing",
	(300 + $pair - 1)       => "percentaligned"
  );
  # Oh, and one more thing:
  # Remember that at least some of these probably don't have values for index
  # reads.
  
  # This essentially goes through each line in the file, but collects data only
  # for the given read and lane.
  my %relevant_data = ();
  LINE: foreach my $line (@$lines) {
	# $line is a hash reference, with the folowing keys:
	# (keys marked with a * themselves contain array references)
	# lane tile cycle channel_id min_contrast max_contrast
	
	# Compare metric type of this line to those of the analysis we're building
	unless (($tmkeys{$line->{metric}})
		    &&  ($line->{lane} eq $lane)) {
	  next LINE;
	}
	
	# Deal with the various series in this file
	my $thistile_data = $line->{metric_val};
	# Values in here seem to come out as 0 sometimes
	if ($thistile_data < 0) { $thistile_data = 0; }
	
	my $series = $tmkeys{$line->{metric}};
	push @{$relevant_data{$series}}, $thistile_data;
  }
  
  # The data we want is now stored in $relevant_data.
  # I want the mean, stdev etc.
  foreach my $series (keys %relevant_data) {
	my $dat = $relevant_data{$series};
	my ($mean, $stdev) = summary_stats($dat);
	my $spread = ();
	if ($series =~ /percentphasing|percentprephasing/) {
	  $spread = median_range_and_quartiles($dat);
	}
	add_data_series_to_object($analysis, $series, $mean, $stdev, $spread);
  }
  
}

sub parse_perbase_arrayref {
  # To save copy-pasting a lot of code, this sub takes an array reference present
  # on each line of certain InterOp files, and parses the series within into distinct
  # per-base series.
  my $series_name = shift;
  my $cycle = shift;
  my $line = shift;
  my $data_aggregation_ref = shift;
  my @vals = @{$line->{$series_name}};
  # Values for each base are ordered the same as bases in @bases
  foreach my $i (1..@vals) {
	# This calculation causes the @bases array to be accessed in reverse, giving the
	# correct base allocation whether this data contains a series for N bases or not.
	$i = 0 - $i;
	
	my $base = $bases[$i];
	my $val = $vals[$i];
	my $base_series_name = $series_name."_".lc $base;
	push @{$data_aggregation_ref->{$base_series_name}{$cycle}}, $val;
  }
}

sub parse_single_value {
  # Performs a similar function to parse_perbase_arrayref, but deals with data types
  # where only a single series (and hence a single figure) is included in this part
  # of the line.
  my $series_name = shift;
  my $cycle = shift;
  my $line = shift;
  my $data_aggregation_ref = shift;
  
  my $val = $line->{$series_name};
  
  # Only a single value stored here
  if ($val >= 0) {
	push @{$data_aggregation_ref->{$series_name}{$cycle}}, $val;
  }
}

sub summary_stats {
  # Apparently simple stuff - take an array of numbers, return a set of summary stats
  # In reality it's a little bit more complex
  # I might pass in a single array of data, or I might pass in a set per cycle.
  # In the former case, I just need to return single figures.
  # In the latter, I need to return references to arrays containing the figures, in
  # order. 
  # I need to be able to tell, automatically, whether we're dealing with per-cycle or
  # otherwise data, though. See http://docstore.mik.ua/orelly/perl/prog3/ch09_04.htm
  my $series = shift;
  
  my ($mean, $stdev) = ();
  if (ref($series) eq 'HASH') {
	# If $series is a hash reference, then we have per-cycle data
	# Collect summary stats for each cycle, put into an array
	foreach my $cycle (sort {$a <=> $b} keys $series) {
	  $mean->[$cycle] = mean($series->{$cycle});
	  $stdev->[$cycle] = stdev($series->{$cycle});
	}
  }
  elsif (ref($series) eq 'ARRAY') {
	# If $series is not a hash reference, it's just a list of numbers with no
	# further dimensionality
	$mean = mean($series);
	$stdev = stdev($series);
  }
  else {
	die "DEBUG: $series is not an array or hash reference!\n";
  }
  return ($mean, $stdev);
}

sub add_data_series_to_object {
  # Following on from summary_stats, this sub handles the way a summarised series is
  # actually set up to be inserted into the database.
  # Specifically, values with cycles can be inserted.
  # Again, see http://docstore.mik.ua/orelly/perl/prog3/ch09_04.htm
  
  # Probably also need to add the series name as a value_type, etc.
  # (Use add_valid_type)
  my $analysis = $_[0];
  my $series = $_[1];
  my $data1 = $_[2];
  my $data2 = $_[3];
  
  # $spread is an array reference containing refs to max, upper quartile, median, lower quartile and
  # min data, in that order. Not all series have that, but if they do, it will always be supplied
  # together.
  my @spread_values = ('max','upper_quartile','median','lower_quartile','min');
  
  # If two series are supplied, take them as mean and stdev
  # Otherwise, take it as a single series
  if ($data2) {
	# Set up the mean and stdev data in this analysis
	data_into_object($data1, $series, "mean", $analysis);
	data_into_object($data2, $series, "stdev", $analysis);
  }
  else {
	data_into_object($data1, $series, "", $analysis);
  }
  
  if ($_[4]) {
	my $spread = $_[4];
	foreach my $i (1..5) {
	  $i--;
	  my $data3 = $spread->[$i];
	  data_into_object($data3, $series, $spread_values[$i], $analysis);
	}
  }
}

sub data_into_object {
  # After all that, we are now in a position to use the functions available to
  # $analysis to accept the data we've extracted.
  # Input here is one of:
  # A data point, and the name of the series it belongs to
  # Or a data series, and the name of that series.
  
  # Review of relevant API functions:
  # --Add an analysis property, e.g. 
  # $analysis->add_property("tool", "InterOp)
  # Properties are used for storing text information about the analysis.
  # Stored in table analysis_property
  #
  # --Add a valid type
  # $analysis->add_valid_type("snr_median", "base_position")
  # Valid types tell the database what a data series is - it's name, and how it should
  # be interpreted (its type scope).
  # Valid type names are stored in table valid_type
  #
  # --Add a global value
  # $analysis->add_general_value("general_min_length", 101, "optional description")
  # Global values are used to store one-off values that apply to the whole analysis.
  # Their name is entered in value_type, and the value_type id is reused if already
  # present.
  # The (numeric) values themselves are stored in table analysis_value.
  #
  # --Add a data point for a single locus
  # $analysis->add_position_value(30, "snr_median", 10.23489)
  # This tells the DB to store the value 10.23489 under the "snr_median" valid type,
  # at position 30. (Can be 30 bases along the read, can be any other continuous series
  # of integers!). Added to table per_position_value.
  #
  # --Add a datapoint for a set of loci
  # $analysis->add_partition_value([1-101], "denitypf", 10252353)
  # This is similar to add_position_value, except it stores a data point corresponding to
  # a range of loci - in this case, a whole read. Added to table per_partition_value.
  
  # A ref to the data, the series name (qscores, intensity etc), data type (mean,
  # stdev etc), and the analysis object are passed in.
  my $relevant_data = $_[0];
  my $series = $_[1];
  my $data_type= $_[2];
  my $analysis = $_[3];
  
  # Get read number first (needed to get start and end)
  my $read = $analysis->get_property("pair");
  
  my $series_name = $series;
  if ($data_type) { $series_name = $series_name."_".$data_type; }
  
  # If there is an array reference in $relevant_data, then treat as per-position data
  # If there is a single value, treat it as per-partition data, with the partition
  # extending across the whole read.
  # If there is nothing (which may be the case when dealing with quartile/median/etc
  # data) return a warning message.
  if (ref($relevant_data) eq 'ARRAY') {
	$analysis->add_valid_type ($series_name, "base_position");
	
	POSITION: foreach my $i (1..@$relevant_data) {
	  $i --;
	  my $val = $relevant_data->[$i];
	  
	  # This is to ensure that the correct position number is maintained when the supplied array
	  # has empty cells at the start (as would be the case for read 2 etc.)
	  if (!$val) { next POSITION; }
	  $analysis->add_position_value ($i, $series_name, $val);
	}
  }
  elsif (($relevant_data) || ($relevant_data == 0)) {
	# Add the partition
	# Sort out the range of the partition; it should be supplied as a string in the form
	# '1-100'
	# (note single-quotes - I think Perl tries to be clever and treats that like a
	# subtraction if it's double-quoted).
	# Partition can also be added if the value of the data is 0. It's a legit value.
	# That condition should be fine because adding partitions means we're using only
	# numbers.
	$analysis->add_valid_type($series_name, "base_partition");
	$analysis->add_partition_value($read_ends{$read}{start}.'-'.$read_ends{$read}{end}, $series_name, $relevant_data);
  }
  else {
	# The following conditions can simply be quietly ignored, since they are expected to
	# be empty in most cases. Otherwise, give a warning that data is missing.
	unless (($read == 2) && ($series_name =~ /percentphasing|percentprephasing/)) {
	  print "WARN: No data in analysis object $series_name\n";
	}
  }
}

sub mean {
  my $in = $_[0];
  
  if (!$in) {
    return 0;
  }
  my @data = @$in;
  if (@data == 0) {
    return 0;
  }
  
  my $total = sum(\@data);
  my $mean = $total / @data;
  return $mean;
}

sub stdev {
  my $in = $_[0];
  
  if(@$in <= 1){
    return 0;
  }
  
  my $mean = mean($in);
  my $sqtotal = 0;
  foreach my $i (@$in) {
    $sqtotal += ($mean - $i) ** 2;
  }
  
  my $std = ($sqtotal / (@$in - 1)) ** 0.5;
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

sub median_range_and_quartiles {
  # This is a quite general sub, that can produce those summary stats, or lists of
  # those summary stats, in several different contexts.
  # I say "max" and "min", but we can use the 95th and 5th percentile respectively.
  my $in = $_[0];
  my $freq_table_mode = $_[1];
  #my @sorted = sort {$a <=> $b} @in;
  
  # Just like with the summary_stats sub, a bit of flexibility is required. I may
  # want to get the median etc. from a frequency table of Qscores, or I may want
  # to get non-cumulative summary stats.
  my ($max, $upper_quartile, $median, $lower_quartile, $min) = ();
  if (ref($in) eq 'HASH') {
	# If $series is a hash reference, then we have per-cycle data
	# Collect summary stats for each cycle, put into an array
	# Otherwise, use recursion to get the summary stats for each cycle
	foreach my $cycle (sort {$a <=> $b} keys $in) {
	  my $spread = median_range_and_quartiles($in->{$cycle});
	  $max->[$cycle]            = $spread->[0];
	  $upper_quartile->[$cycle] = $spread->[1];
	  $median->[$cycle]         = $spread->[2];
	  $lower_quartile->[$cycle] = $spread->[3];
	  $min->[$cycle]            = $spread->[4];
	}
  }
  elsif (ref($in) eq 'ARRAY') {
	# If $series is not a hash reference, it's either a freq table, or it's just a
	# list of numbers with no further dimensionality.
	# If $cumulative exists, do this in freq table mode.
	if ($freq_table_mode) {
	  $median         = percentile_from_freq_table($in, 50);
	  $upper_quartile = percentile_from_freq_table($in, 75);
	  $lower_quartile = percentile_from_freq_table($in, 25);
	  #$max            = max_from_freq_table($in);
	  #if ($max > 0) { $min = min_from_freq_table($in); }
	  #else          { $min = $max; }
	  $max            = percentile_from_freq_table($in, 95);
	  $min            = percentile_from_freq_table($in, 5);
	}
	else {
	  $median         = percentile($in, 50);
	  $upper_quartile = percentile($in, 75);
	  $lower_quartile = percentile($in, 25);
	  #$max            = max($in);
	  #if ($max > 0) { $min = min($in); }
	  #else          { $min = $max; }
	  $max            = percentile($in, 95);
	  $min            = percentile($in, 5);
	}
  }
  else {
	die "DEBUG: $in is not an array or hash reference!\n";
  }
  
#  
#  # CHECK SOME STUFF
#  if ((!$max)||(!$upper_quartile)||(!$median)||(!$lower_quartile)||(!$min)) {
#	print "ITS ALL GONE WRONG
#	$max,$upper_quartile,$median,$lower_quartile,$min\n"
#  }
#  
#  
  
  
  my @spreadstats = ($max,$upper_quartile,$median,$lower_quartile,$min);
  return \@spreadstats;
}

sub max_from_freq_table {
  # Note: returns the max frequency greater than 0 from a frequency table
  my $in = shift;
  my $max = @$in;
  MAX: foreach my $q (1..@$in) {
	$q = (@$in - $q) + 1;
	if ($in->[$q-1] == 0) { $max --; }
	else { last MAX; }
  }
  return $max;
}

sub min_from_freq_table {
  # Note: returns the min frequency greater than 0 from a frequency table
  my $in = shift;
  my $min = 1;
  MIN: foreach my $q (1..@$in) {
	if ($in->[$q-1] == 0) { $min ++; }
	else { last MIN; }
  }
  return $min;
}

sub max {
  my $in = shift;
  my $max = 0;
  foreach my $i (@$in) {
	if ($i > $max) {
	  $max = $i;
	}
  }
  return $max;
}

sub min {
  my $in = shift;
  my $min = $in->[rand @$in];
  foreach my $i (@$in) {
	if ($i < $min) {
	  $min = $i;
	}
  }
  return $min;
}

sub percentile_from_freq_table {
  # As with min and max, a special version of this is needed when working with freq tables.
  # Requires sorted data
  my $in = $_[0];
  my $p = $_[1];
  
  my $cumfreq = get_cumulative_frequency_table($in);
  my $total = sum($in);
  
  if ($total > 0) {
	my $perc = 0;
	while ((($cumfreq->[$perc] / $total) <= ($p / 100)) && ($perc <= @$in)) {
	  $perc ++;
	}
	return $perc;
  }
  else { return "0"; }
}

sub percentile {
  # This is the non freq table version. Called in the same way though.
  my $in = $_[0];
  my $p = $_[1];
  
  my @sorted = sort {$a <=> $b} @$in;
  return $sorted[int(($p / 100) * @sorted)];
}

sub get_cumulative_frequency_table {
  # When supplied with an array of frequencies (assumed sorted in the apppropriate order),
  # this returns an array of the cumulative frequencies.
  my $in = $_[0];
  my @in = @$in;
  
  my $cumfreq = 0;	my @out = ();
  foreach my $i (1..@in) {
	$i --;
	$cumfreq += $in[$i];
	$out[$i] = $cumfreq;
  }
  
  return \@out;
}

sub remove_duplicates {
  my $in = $_[0];
  my @in = @$in;
  my %k = ();
  foreach my $i (@in) { $k{$i} = 1; }
  my $deduped = keys %k;
  return $deduped;
}


1;