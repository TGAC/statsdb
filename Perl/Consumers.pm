package Consumers;
use List::Util qw(min max);
use Term::ANSIColor;
use Timecode;
use strict;

# This module contains general methods that are useful when writing
# consumer scripts. Using these ought to make it easier both to write
# and to read consumers.

# The following hash stores all the short-type (single character) input
# flags, corresponding to longer names.
# If adding a new flag, update this too
my %short_flags = (
  'help'            => 'h',
  'db_config'       => 'd',
  #'miso_config'     => 'm',
  'analysis'        => 'a',
  'instrument'      => 'i',
  'run'             => 'r',
  'pseq'            => 'o',
  'lane'            => 'l',
  'pair'            => 'p',
  'sample_name'     => 's',
  'barcode'         => 'b',
  'scope'           => 'q',
  'begin'           => 'c',
  'end'             => 'e',
  'datetype'        => 't',
  'tool'            => 'f',
  'duplicate_type'  => 'v',
);

# Reverse that so long flags can be looked up from short flags
my %long_flags = reverse %short_flags;

# The following hash stores help strings for individual options in much
# the same way.
my %help_strings = (
  'help'            => 'Display this message',
  'db_config'       => 'Database connection specification file (required)',
  #'miso_config'     => 'MISO API connection specification file (required)',
  'analysis'        => 'Numeric ID of a single analysis record',
  'instrument'      => 'Instrument name',
  'run'             => 'Run ID',
  'pseq'            => 'PSEQ/SEQOP ID (TGAC internal tracking system)',
  'lane'            => 'Lane',
  'pair'            => 'Read',
  'sample_name'     => 'Sample name',
  'barcode'         => 'Barcode',
  'scope'           => 'Query scope',
  'begin'           => 'Begin date/time of a time interval',
  'end'             => 'End date/time of a time interval',
  'datetype'        => 'Time record type to use in time interval selection',
  'tool'            => 'Type of analysis data to select (e.g., FastQC)',
  'duplicate_type'  => 'Select only the most recent version of matching data (new), only older duplicates (old), or everything (all)'
);

my @charlengths = ();
foreach my $i (keys %help_strings) { push @charlengths, length $i; }
my $helpstring_max = max(@charlengths);

# A list of acceptable query scopes
my %query_scopes = (
  instrument  => 1,
  run         => 1,
  lane        => 1,
  pair        => 1,
  sample_name => 1,
  barcode     => 1,
);

sub new {
  my $class = shift;
  my $reports = shift;
  my $self = {reports => $reports};
  bless $self, $class;
  return $self;
}

sub deal_with_inputs {
  # Sort out the arguments that consumers take
  # I want to be able to pass in a list of accepted arguments, and
  # the input parameters themselves, and return an appropriately
  # structured hash and a help string describing those options.
  # This has the twin effect of constraining the range of inputs, and
  # of making consumers a lot easier to write.
  my $args = $_[0]; # Command line arguments from GetOpt::Long, OO style
  my $opts = $_[1]; # List of active command line arguments to use
  
  # lowercase everything in @$opts (for compatibility)
  $_=lc for @$opts;
  
  # Check that the options set as valid are all recognised here
  foreach my $opt (@$opts) {
    unless ($short_flags{$opt}) {
      print "PROGRAMMING ERROR: Unrecognised option $opt\nValid options should be chosen from this list:\n";
      foreach my $i (keys \%short_flags) { print "$i\n"; }
      die "";
    }
  }
  
  my %vals = ();
  $vals{qscope} = 'na';
  
  $args->getoptions(
    'h|help'             => \$vals{help},
    'd|db_config=s'      => \$vals{db_config},
    #'m|miso_config=s'    => \$vals{miso_config},
    'a|analysis:i'       => \$vals{analysis},
    'i|instrument:s'     => \$vals{instrument},
    'r|run:s'            => \$vals{run},
    'o|pseq:s'           => \$vals{pseq},
    'l|lane:s'           => \$vals{lane},
    'p|pair:i'           => \$vals{pair},
    's|sample_name:s'    => \$vals{sample_name},
    'b|barcode:s'        => \$vals{barcode},
    'q|scope:s'          => \$vals{qscope},
    'c|begin:s'          => \$vals{begin},
    'e|end:s'            => \$vals{end},
    't|datetype:s'       => \$vals{datetype},
    'f|tool:s'           => \$vals{tool},
    'v|duplicate_type:s' => \$vals{duplicate_type},
  );
  
  # Set the supplied list of active options into a hash, for ease of
  # searching them
  my %opts = ();
  foreach my $opt (@$opts) { $opts{$opt} = 1; }
  # Certain options should always be present; set them now
  $opts{db_config} = 1;
  $opts{help}      = 1;
  # If the MISO config file is in the opts lists, it should be required.
  #if (/miso_config/ ~~ @$opts) {
  #  $opts{miso_config} = 1;
  #}
  
  # Deal with errors for missing mandatory inputs here
  # Check both for empty inputs and for files that don't actually exist.
  my @help_string = ();
  if ($opts{db_config}) {
    if (!$vals{db_config}) {
      $vals{help} = 1;
      print colored ['bright_white on_red'], "\n::WARNING::";
      print colored ['reset'], "\tinput flag --db_config MUST be set!\n\n";
    }
    elsif (!-f $vals{db_config}) {
      $vals{help} = 1;
      print colored ['bright_white on_red'], "\n::WARNING::";
      print colored ['reset'], "\tCannot find file\n\t\t  ".$vals{db_config}."\n\t\tspecified via input flag --db_config!\n\n";
    }
  }
  
  #if ($opts{miso_config}) {
  #  if (!$vals{miso_config}) {
  #    $vals{help} = 1;
  #    print colored ['bright_white on_red'], "\n::WARNING::";
  #    print colored ['reset'], "\tinput flag --miso_config MUST be set!\n\n";
  #  }
  #  elsif (!-f $vals{miso_config}) {
  #    $vals{help} = 1;
  #    print colored ['bright_white on_red'], "\n::WARNING::";
  #    print colored ['reset'], "\tCannot find file\n\t\t  ".$vals{miso_config}."\n\t\tspecified via input flag --miso_config!\n\n";
  #  }
  #}
  
  # Do some simple error-checking
  # Check that the passed query scope, if any, is one of the available
  # values
  unless (($query_scopes{$vals{qscope}}) || ($vals{qscope} eq 'na')) {
    die "Query scope (-q) should be set to one of:\n".
        (join "\n", keys %query_scopes).
        "\nor left unset\n";
  }
  
  # Handle date-times, if any are supplied as inputs
  if ($vals{begin} || $vals{end}) {
    $vals{begin} = Timecode::parse_input_date($vals{begin});
    $vals{end}   = Timecode::parse_input_date($vals{end});
  }
  
  # If a PSEQ or SEQOP ID (internal TGAC operations tracking code) is
  # supplied, we need to look up the corresponding run ID, since that's
  # what the database stores.
  if ($vals{pseq}) {
    pseq_to_run_id(\%vals);
  }
  
  # If set, the duplicate_values input must be one of 3 values.
  # If set improperly, throw a warning and set to null.
  if ($vals{duplicate_type}) {
    unless ($vals{duplicate_type} =~ /^all$|^old$|^new$/){
      print colored ['bright_white on_red'], "\n::WARNING::";
      print colored ['reset'], "\tInput flag --duplicate_type must be set to one ofthe following:\n\told new all\n\n";
      $vals{duplicate_type} = ();
    }
  }
  
  
  # Now actually set the supplied values into a hash
  my $input_values = ();
  $input_values->{QSCOPE} = $vals{qscope};
  
  foreach my $opt (keys %opts) {
    # Get the input value for this key
    my $val = $vals{$opt};
    
    if ($val) {
      my $key = uc $opt;
      $input_values->{$key} = $val;
    }
    
    # Add relevant things to the help string too
    my $helpstr = "  -".$short_flags{$opt}." or --$opt";
    for (length $opt..$helpstring_max) { $helpstr .= " "; }
    $helpstr .= $help_strings{$opt};
    push @help_string, $helpstr;
    
  }
  @help_string = sort {$a cmp $b} @help_string;
  my $helpstr = join "\n", @help_string;
  return ($input_values, $helpstr);
}

sub check_for_incorrect_flags {
  # If an incorrect or non-functional flag has been supplied, this
  # sub recognises it and returns appropriate warnings
  my $args = $_[0]; # Command line arguments direct from @ARGV
  my $opts = $_[1]; # List of active command line arguments to use
  
  # Set the supplied list of active options into a hash, for ease of
  # searching them
  my %opts = ();
  foreach my $opt (@$opts) {
    $opts{$opt} = 1;
  }
  # Certain options should always be present; set them now
  $opts{db_config} = 1;
  $opts{help}      = 1;
  
  my $incorrect_flags = 0;
  foreach my $arg (@$args) {
    chomp $arg;
    
    # Get the name of the flag (no leading dashes) for lookup
    my $argname = $arg;
    $argname =~ s/^[-]+//g;
    
    $arg = lc $arg;
    if ($arg =~ /^-[a-zA-Z]/) {
      my $longarg = $long_flags{$argname};
      unless ($opts{$longarg}) {
        $incorrect_flags = 1;
        print "Input error: Unknown option '$arg'\n";
      }
    }
    elsif ($arg =~ /^--[a-zA-Z]/) {
      unless ($opts{$argname}) {
        $incorrect_flags = 1;
        print "Input error: Unknown option '$arg'\n";
      }
    }
  }
  return $incorrect_flags;
}

sub pseq_to_run_id {
  # Users at TGAC might want to query on a particular run, which can
  # be most conveniently accessed by supplying a PSEQ number.
  my $args = $_[0];
  
  # Several steps are necessary here. If this is running on a machine
  # outside the TGAC environment, it should fail gracefully and
  # immediately.
  # Assume QC environment has already been sourced
  unless ($ENV{TGACTOOLS_CONFIG_DIR}) {
    die "ERROR: PSEQ/SEQOP input option -o ".$args->{pseq}." unavailable; cannot be used outside of TGAC internal environment\nRemember to source the QC environment, if you haven't yet!\n";
  }
  
  my $jira_paths_file = $ENV{TGACTOOLS_CONFIG_DIR}.'/jira_paths.txt';
  open(JIRAPATHS, '<', $jira_paths_file) or die "ERROR: Cannot open Jira paths file $jira_paths_file\n";
  my %paths = ();
  while (my $line = <JIRAPATHS>) {
    chomp $line;
    my @line = split /\t/, $line;
    $paths{$line[0]} = $line[1];
  }
  close JIRAPATHS;
  
  # Check that the PSEQ/SEQOP number has been correctly formatted
  # Try to correct if it isn't
  my $pseq = $args->{pseq};
  unless ($pseq =~ /^PSEQ-[0-9]+$|^SEQOP-[0-9]+$/) {
    print "WARN: Incorrect PSEQ number detected [$pseq]\n";
    $pseq =~ s/[^0-9]//g;
    $pseq = 'PSEQ-'.$pseq;
    print "Corrected to $pseq\n";
  }
  
  # Look for the PSEQ/SEQOP  number in the jira_paths data
  if ($paths{$pseq}) {
    # If the run input has already been set, check that it points at
    # the same run ID. Otherwise, report a likely input error
    if ($args->{run}) {
      unless ($args->{run} eq $paths{$pseq}) {
        die "WARN: Probable input error\nSupplied run ID (".$args->{run}.") does not match supplied PSEQ/SEQOP run ID ($pseq :: ".$paths{$pseq}.")\n";
      }
    }
    else {
      $args->{run} = $paths{$pseq};
    }
  }
  else {
    die "ERROR: ".$paths{$pseq}." not found in current list of runs\n";
  }
}

sub check_validity {
  # Take the values passed into this script (hash)
  # Pass that right on to the list_subdivisons or something
  # If it returns a list of things, it's valid.
  # If not, it's not.
  # Simple.
  
  # Note: if warnings (-w) enabled in calling script, this may cause
  # uninitialised value warnings. This is expected - the list_subdivisions
  # stored procedure sometimes returns null columns when a given data type
  # has no possible representation for certain fields.
  
  my $self = shift;
  my $in = shift;
  my $reports = $self->{reports};
  
  my $qry = $reports->list_subdivisions($in);
  my $avg = $qry->to_csv;
  my @returned_values = split /\n/, $avg;
  
  if (@returned_values <= 1) {
    die "Input error:\n  Specified input parameters do not correspond to any records in the database.\n";
  }
  
  return "Input validated";
}

sub check_for_duplicated_data {
  # Sometimes, the same run may be entered into the database multiple times.
  # The code in its current state can deal with this (by using only the most
  # recent data), but a warning and relevant information should be sent to the
  # user.
  
  my $self = shift;
  my $in = shift;
  my $reports = $self->{reports};
  
  my $qry = $reports->detect_duplicates($in);
  my $avg = $qry->to_csv;
  my @returned_values = split /\n/, $avg;
  
  if (@returned_values > 1) {
    return $avg;
  }
}

# The following functions are for setting up query sets.

# Clean up results returned from the list_subdivisions stored procedure; remove columns,
# reduce dimensionality (remove ruplicates)
sub clean_query_sets {
  my $self = shift;
  # Inputs: column header and data from parse_query_results, column to remove,
  # Outputs: same, edited.
  my $column_headers = shift;
  my $returned_values = shift;
  my $columns_to_remove = shift;
  
  unless (ref($columns_to_remove) eq 'ARRAY'){
    die "ERROR: list of columns to remove in function clean_query_sets (Consumers.pm) must be an array reference\n"
  }
  
  foreach my $col_tr (@$columns_to_remove) {
    unless (uc $col_tr ~~ @$column_headers) {
      print "WARN: column $col_tr not found in results\n";
    }
    
    # Get the index number ($i) of the column we're about to remove
    my $i = 0; 
    HEAD: foreach my $head (@$column_headers) {
      if (uc $col_tr eq $head) {
        last HEAD;
      }
      $i++;
    }
    
    # Remove the column using splice
    splice @$column_headers,$i,1;
    foreach my $line (@$returned_values) {
      splice @$line,$i,1;
    }
  }
  
  # Remove duplicate lines to complete the cleanup process
  # Since $returned _values is an array of arrays, the lines have to be joined into strings first,
  # then split up again afterwards. 
  my @textlines = ();
  foreach my $line (@$returned_values) {
    push @textlines, (join ',', @$line);
  }
  @textlines = $self->remove_duplicates(\@textlines);
  $returned_values = ();
  foreach my $line (@textlines) {
    my @line = split /,/, $line;
    push @$returned_values, \@line;
  }
  
  return ($column_headers,$returned_values);
}

# Remove read 0 lines.
sub remove_read0_lines {
  my $self = shift;
  # Inputs: column header and data from parse_query_results, column to remove,
  # Outputs: same, edited.
  my $column_headers = shift;
  my $returned_values = shift;
  
  # Get the index number ($i) of the read column
  my $i = 0; 
  HEAD: foreach my $head (@$column_headers) {
    if ($head eq 'PAIR') {
      last HEAD;
    }
    $i++;
  }
  
  my $returned_values_no_read0_lines = ();
  foreach my $line (@$returned_values) {
    if ($line->[$i]) {
      if ($line->[$i] > 0) {
        push @$returned_values_no_read0_lines, $line;
      }
    }
  }
  
  return ($column_headers,$returned_values_no_read0_lines);
}

# Remove index reads.
sub remove_index_reads {
  my $self = shift;
  # Inputs: column header and data from parse_query_results, column to remove,
  # Outputs: same, edited.
  my $column_headers = shift;
  my $returned_values = shift;
  
  # Get the index number ($i) of the read column
  my $i = 0; 
  HEAD: foreach my $head (@$column_headers) {
    if ($head eq 'PAIR') {
      last HEAD;
    }
    $i++;
  }
  
  my $returned_values_no_indexread_lines = ();
  foreach my $line (@$returned_values) {
    if ($line->[$i]) {
      if ($line->[$i] !~ /index/i) {
        push @$returned_values_no_indexread_lines, $line;
      }
    }
  }
  
  return ($column_headers,$returned_values_no_indexread_lines);
}

# When given a set of results returned from the list_subdivisions stored procedure (possibly edited by
# clean_query_sets and others, above), this organises the results into the hash data structure that other
# parts of the API use.
sub prepare_query_sets {
  my $self = shift;
  # Inputs: column header and data from parse_query_results, column to remove,
  # Outputs: same, edited.
  my $column_headers = shift;
  my $returned_values = shift;
  
  # Make returned column headers upper-case so they match the hash keys used
  # in the API
  foreach my $k (@$column_headers) {
    $k = uc $k;
  }
  
  my $n = 0;  my @query_sets = ();
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
      my $bc = $self->get_barcode_for_sample($qry{SAMPLE_NAME});
      $qry{BARCODE} = $bc;
    }
    
    push @query_sets, \%qry;
    
    print "QUERY $n:\n";
    foreach my $key (keys %qry) {
      if ($qry{$key}) {
        print "\t$key:\t".$qry{$key}."\n";
      }
    }
  }
  
  return \@query_sets;
}

sub get_barcode_for_sample {
  my $self = shift;
  my $samp = shift;
  my $reports = $self->{reports};
  
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

sub queryset_label {
  # Set up a label to go at the top of the report.
  # Pick sample names, if those are specified.
  # If not, use lanes.
  # If those are missing, use runs, if those are missing use instruments,
  # and if (for some reason) everything is missing, just use a generic
  # string.
  my $self = shift;
  my $query_properties = shift;
  
  my $queryset_label = ();
  if ($query_properties->{SAMPLE_NAME}) {
    $queryset_label = "Sample ".$query_properties->{SAMPLE_NAME};
    if ($query_properties->{PAIR}) {
      $queryset_label = "$queryset_label, Read ".$query_properties->{PAIR};
    }
  }
  elsif ($query_properties->{LANE}) {
    $queryset_label = "Lane ".$query_properties->{LANE};
    if ($query_properties->{BARCODE}) {
      $queryset_label = "$queryset_label, Barcode ".$query_properties->{BARCODE};
    }
    if ($query_properties->{PAIR}) {
      $queryset_label = "$queryset_label, Read ".$query_properties->{PAIR};
    }
  }
  elsif ($query_properties->{RUN}) {
    $queryset_label = "Run ".$query_properties->{RUN};
  }
  elsif ($query_properties->{INSTRUMENT}) {
    $queryset_label = "Instrument ".$query_properties->{INSTRUMENT};
  }
  else {
    $queryset_label = "General query";
  }
  
  return $queryset_label;
}


# The following subs all return data in a particular format, to be used in
# certain contexts - some more specific than others.
sub round_to_x_places {
  my $self = shift;
  my $i = shift;
  my $places = shift;
  
  my $j = abs $i;
  my $rounded = substr ($j + ('0.' . '0' x $places . '5'), 0, length(int($j)) + $places + 1);
  if ($i < 0) {
    $rounded = "-$rounded";
  }
  return $rounded;
}

sub parse_query_results {
  # Dealing with the csv data returned from a query requires several
  # lines of scruffy code. This sub takes care of it much more neatly.
  # Pass in a query results object and get back two array references:
  # first, the column headers;
  # second, an array of values per row, split on comma (since csv). 
  my $self = shift;
  my $in = shift;
  
  # Input can be either a CSV string, or an array reference, or (potentially) an
  # array of arrays. Two checks handle that appropriately. 
  my @returned_values = ();
  if (ref $in) {
    foreach my $line (@$in) {
      if (ref $line) { push @returned_values, $line; }
      else {
        my @sp = split /,/, $line;
        push @returned_values, \@sp;
      }
    }
  }
  else {
    chomp $in;
    my @sp = split /\s|\n/, $in;
    # Recursive call to this func, supplying it with an array reference
    my ($col_heads,$results) = $self->parse_query_results(\@sp);
    return ($col_heads,$results);
  }
  
  my $col_heads = shift @returned_values;
  return ($col_heads, \@returned_values);
}

sub make_printable_table {
  # Takes query output and makes a pretty table out of it.
  # (Can take it either directly in CSV form as it comes back from the
  # database, or already parsed)
  # Returns the table as a string.
  
  # Labeled this way because we're not yet sure if parsed or not
  my $self = shift;
  my $input1 = shift;
  my $input2 = shift;
  
  my ($column_headers,$returned_values) = ();
  if ($input2) {
    $column_headers  = $input1;
    $returned_values = $input2;
  }
  else {
    ($column_headers,$returned_values) = $self->parse_query_results($input1);
  }
  
  # Get max character length for each column (counting headers too)
  my @maxlengths = ();
  foreach my $i (1..@$column_headers) {
    $i --;
    # $i is column number
    my @lengths = (length ($column_headers->[$i]));
    foreach my $j (1..@$returned_values) {
      $j --;
      if ($returned_values->[$j][$i]) {
        push @lengths, length($returned_values->[$j][$i]);
      }
      else {
        push @lengths, '0';
      }
    }
    
    # Get the max length for this column now
    push @maxlengths, max(@lengths);
  }
  
  # Now start arranging that string.
  my @table = ();
  # Header section
  push @table, make_horizontal_table_line(\@maxlengths);
  
  push @table, make_horizontal_table_line(\@maxlengths,$column_headers);
  push @table, make_horizontal_table_line(\@maxlengths);
  
  # Body section
  foreach my $line (@$returned_values) {
    push @table, make_horizontal_table_line(\@maxlengths,$line);
  }
  push @table, make_horizontal_table_line(\@maxlengths);
  return join "\n", @table;
}

sub make_horizontal_table_line {
  # Creates a table line string based on either
  # 1: supplied lengths + supplied values (appropriately spaced text)
  # 2: supplied lengths (dashes that mark out horizontal lines)
  my $input1 = $_[0];
  my $input2 = $_[1];
  
  my @line = ();
  my $numcols = @$input1;
  foreach my $i (1..$numcols) {
    $i --;
    my $length = $input1->[$i];
    my $item = ();
    if ($input2) {
      # Make line of spaced values
      $item = $input2->[$i];
      $item = embiggen($item,$length);
    }
    else {
      for $i (1..$length) {
        $item .= '-';
      }
    }
    push @line, $item;
  }
  
  if ($input2) {
    # Make line of spaced values
    my $line = join ' | ', @line;
    return "| $line |";
  }
  else {
    my $line = join '-+-', @line;
    return "+-$line-+";
  }
}

sub embiggen {
  # Adds spaces at the beginning or end of a string, depending on
  # if it's numeric or not
  my $string = $_[0];
  my $length = $_[1];
  
  if (!$string) {
    my @str = ();
    for (1..$length) {
      push @str, ' ';
    }
    $string = join '', @str;
  }
  elsif ($string =~ /^[0-9]+$|^[0-9]+\.[0-9]+$/) {
    while (length $string < $length) {
      $string = " $string";
    }
  }
  else {
    while (length $string < $length) {
      $string = "$string ";
    }
  }
  return $string;
}

sub remove_duplicates {
  # Dead simple: return an array with only one of each unique string.
  my $self = shift;
  my $in = shift;
  
  my @in = @$in;
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

# These subs set up a common data structure that more advanced output functions can make use of.
# It's a similar idea to the input hashes, but it holds more stuff.
sub add_to_data_stash {
  # Pass it a table and a value type, and it'll read it into a memory structure, easy as that.
  my $self = shift;
  my $datastruct = shift;   # Reference to the data structure to add the query data to.
  my $results = shift;      # Query results, either from parse_query_results or rotate_query_results_col_to_row
  my $value_type = shift;   # Value type of the data, e.g. quality_mean
  my $data_type = shift;    # Data to select from the query data - e.g., average, sum (i.e., pick a column)
  
  if (!$value_type) { die "ERROR: No value type supplied to data storage function\n"; }
  
  # If $results is an array ref, it means we have output from either parse_query_results or
  # rotate_query_results_col_to_row. Those are both line-oriented structures, but we want them as
  # a column-oriented structure here. Use rotate_query_results_row_to_col.
  # Otherwise, the input is a single value that can be attached more directly.
  if (ref $results) {
    my $cols = $self->rotate_query_results_row_to_col($results);
    
    # Good - now we can get the columns we want and add them to the structure.
    
    # Get the position column (look through @{$cols->[0]} to find it)
    my $i = 1;
    FINDHEAD: foreach my $head (@{$cols->[0]}) {
      if ($head =~ /position/i) { last FINDHEAD; }
      $i ++;
    }
    
    # There are actually two things we want to record here - the single base position (directly from the
    # query), and the interval (the previous + 1 base to the base in the query's data).
    foreach my $basepos (@{$cols->[1]}) {
      my $interval_name = $basepos;  # This is so that if we have a single value where it doesn't make sense to store an
                                     # interval, we still get the correct number of interval names, and a correct point value
      if ($datastruct->{$value_type}{base_scale}[-1]) {
        if ($datastruct->{$value_type}{base_scale}[-1] < ($basepos - 1)) {
          $interval_name = ($datastruct->{$value_type}{base_scale}[-1] + 1)."-$basepos";
        }
      }
      push @{$datastruct->{$value_type}{interval_names_scale}}, $interval_name;
      push @{$datastruct->{$value_type}{base_scale}}, $basepos;
    }
    
    # Get the column number corresponding to the value supplied in $data_type
    $i = 1;
    FINDCOL: foreach my $head (@{$cols->[0]}) {
      if ($head =~ /$data_type/i) { last FINDCOL; }
      $i ++;
    }
    
    # Put that column in the right place
    @{$datastruct->{$value_type}{data}} = @{$cols->[$i]};
  }
  else {
    $datastruct->{$value_type} = $results;
  }
}

# How about something to get data out of it too? It's easy enough that a few lines of code can handle it
# anyway, but it might be more convenient to use this. 
sub get_data_from_stash {
  # A counterpart to add_data_to_stash - this retrieves the specified data from the structure
  # that add_data_to_stash fills up, along with its scale values, and puts it in a standard form that
  # the output functions can understand.
  my $self = shift;
  my $datastruct = shift;
  my $value_type = shift;  # Ref to array of value types to pick out. 
  
  return $datastruct->{$value_type};
}

sub get_data_point_from_stash {
  # Same as above, but aimed at getting a single data point rather than the whole array.
  # Expects array index number rather than scale number, on the grounds that it will be called within
  # a loop where scale points are being cycled through anyway.
  my $self = shift;
  my $datastruct = shift;
  my $value_type = shift;  # Ref to array of value types to pick out.
  my $index = shift;
  
  return $datastruct->{$value_type}{data}[$index];
}

sub check_scale_identity {
  # This is meant to be called as an integral check on the data that gets fed to a more complex output
  # function. In those cases, it may be that several different value types are called. It's possible
  # that types with different scales may be accidentally mixed in together. This sub is used to detect
  # that kind of situation, or to return a single scale if all is well.
  my $self = shift;
  my $qualdata = shift;   # Data structure ref
  my $valtypes = shift;   # Arrayt of value types ref
  my $scale_type = shift; # Scale type - single values (base_scale) or ranges (interval_names_scale)
  
  my @scales = ();
  foreach my $value_type (@$valtypes) { push @scales, $qualdata->{$value_type}{$scale_type}; }
  
  my $first_scale = $scales[0];
  foreach my $scale (@scales) {
    unless (@$first_scale ~~ @$scale) {
      print "ERROR: Mismatched scales for the following data series!\n";
      foreach my $valtype (@$valtypes) { print "  $valtype"; }
      die "\n";
    }
  }
  return $first_scale;
}

# The following subs all call R scripts to produce graphs, or are related to that.

sub call_rscript {
  # Calls an R script (name of script supplied as input) on supplied
  # data. File containig data and name of output plot should also be
  # supplied.
  # $args should be an array reference
  my $self = shift;
  my $func = shift;
  my $args = shift;
  
  # It would be better if I could pass the filename ($data) to R, rather
  # than have it hardcoded into the script. 
  # Passing the name of the output file would be nice too, though I
  # seem to remember having some kind of trouble with that.
  # Note that R scripts should all return the name of the plot file.
  # (Should probably implement a check for errors or something)
  #my @argv = ("R --slave -f R/$func.r");
  my @argv = ("Rscript R/$func.r");
  if (ref $args) {
    #$argv[0] .= " --args";
    foreach my $arg (@$args) { $argv[0] .= " $arg"; }
  }
  elsif ($args) { print "ERROR: option \$args should be an array reference when calling R script $func\n"; }
  #my $Rout = system(@argv) == 0 or die "ERROR: Unable to launch $func R script\n";
  my $Rout = `$argv[0]` or die "ERROR: Unable to launch $func R script\n";
  
  my @Rout = split /\n/, $Rout;
  my $plot = ();
  foreach my $line (@Rout) {
    chomp $line;
    if ($line =~ /PLOT FILE: /) {
      $plot = $line;
      $plot =~ s/\"//g;
      $plot =~ s/.*PLOT FILE: //g;
      chomp $plot;
    }
  }
  
  # Move the plot somewhere for safe keeping
  # To make it clear, this first check is asking if the variable $plot holds anything, bot whether
  # the file itself is found. 
  if ($plot) {
    # NOTE: if using ggplot, I can easily save it to the right place within R, so I tend to
    # do it there. Only lauch this mv if it's actually necessary
    if ((-e $plot) && ($plot !~ /^R\/Plots\/.*/)) {
      @argv = ("mv -f $plot R/Plots/$plot");
      system(@argv) == 0 or die "ERROR: Unable to move quality plot to /Plots directory\n";
    }
  }
  else { print "ERROR: No plot found for R script $func\n"; }
  
  # What should I return, if anything?
  return ($plot);
}

sub write_data_to_file {
  # Designed to handle writing an arbitrary set of data from the standard query data structure to a file.
  # Useful because a lot of more advanced output functions, e.g. graphical outputs, require files written. 
  my $self = shift;
  my $qualdata = shift;
  my $datafile = shift;
  my $intervals = shift;
  my $valtypes = shift;
  my $colheads = shift; # Note that 'Intervals' will always be printed first anyway, so it can be omitted here.
  
  # For the purposes of writing a useful error message, get the name of the sub that called this:
  my $calling_sub = (caller(1))[3];
  open(DAT, '>', $datafile) or die "Cannot open data file\n  $datafile\nfor output function $calling_sub\n";
  print DAT "Interval";
  foreach my $head (@$colheads) { print DAT "\t$head"; }
  
  my $i = 0;
  foreach my $interval (@$intervals) {
    my @line = ($interval);
    foreach my $value_type (@$valtypes) {
      push @line, $self->get_data_point_from_stash($qualdata,$value_type,$i);
    }
    my $line = join "\t", @line;
    print DAT "\n$line";
    $i++;
  }
  close DAT;
  # No need to return anything here
}

# All of these subs get data (from a reference to an object containing
# all data extracted by querying the database as part of a consumer
# script), write it out to a file, and call an R script to produce a
# plot from that data. 
sub freq_distribution_over_range_plot {
  my $self = shift;
  my $qualdata = shift;       # Reference to data object
  my $valtypes = shift;       # List of value types in data object to use here.
                              # Expected order: top point, top of box, middle of box, bottom of box, bottom point, line point
  my $plot_title = shift;
  my $xlabel = shift;
  my $ylabel = shift;
  my $qnum = shift;           # Unique identifier of current query set
  
  if (!$qnum) { $qnum = 1; }
  
  # Set output filenames
  # These can be derived from the plot title, with all troublesome characters stripped out.
  my $filename = $plot_title;
  $filename =~ s/\s/_/g;
  $filename =~ s/[^a-zA-Z0-9_]//g;
  my $datafile = "$filename\_q$qnum.df";
  my $plotfile = "$filename\_q$qnum.pdf";
  #my $rscript = "read_quality_graph";
  my $rscript = "freq_distribution_over_range_plot";
  
  # Check that the right number of value types have been supplied
  my $required_types = 6;
  my $this_sub = (caller(1))[3];
  unless (@$valtypes == $required_types) { die "ERROR: Incorrect number of value types supplied to $this_sub function\n(".@$valtypes." supplied, $required_types required)\n"; }
  # Check that all scales used in the supplied data types match
  my $intervals = $self->check_scale_identity($qualdata,$valtypes,'interval_names_scale');
  # Make the column headers for the output file (which will be the series names in the plot)
  my $colheads -> ('Max','Upper quartile','Median','LowerQuartile','Min','Mean');
  
  # Write the data to the file we set a bit earlier
  $self->write_data_to_file($qualdata,$filename,$intervals,$valtypes,$colheads);
  
  # Set up arguments and execute the R script!
  my @args = ($datafile, $qnum, $plot_title, $xlabel, $ylabel);
  $self->call_rscript($rscript, \@args);
  return ($plotfile, $datafile);
}


# Looks like I don't need this - it's just a simple line plot, like several others.
#sub freq_distribution_plot {
#  my $self = shift;
#  my $qualdata = shift;       # Reference to data object
#  my $valtypes = shift;       # List of value types in data object to use here. (Only one here)
#  my $plot_title = shift;
#  my $xlabel = shift;
#  my $ylabel = shift;
#  my $qnum = shift;           # Unique identifier of current query set
#  
#  if (!$qnum) { $qnum = 1; }
#  
#  # Set output filenames
#  # These can be derived from the plot title, with all troublesome characters stripped out.
#  my $filename = $plot_title;
#  $filename =~ s/\s/_/g;
#  $filename =~ s/[^a-zA-Z0-9_]//g;
#  my $datafile = "$filename\_q$qnum.df";
#  my $plotfile = "$filename\_q$qnum.pdf";
#  my $rscript = "quality_distribution";
#  
#  # Check that the right number of value types have been supplied
#  my $required_types = 1;
#  my $this_sub = (caller(1))[3];
#  unless (@$valtypes == $required_types) { die "ERROR: Incorrect number of value types supplied to $this_sub function\n(".@$valtypes." supplied, $required_types required)\n"; }
#  # Check that all scales used in the supplied data types match
#  my $intervals = $self->check_scale_identity($qualdata,$valtypes,'interval_names_scale');
#  # Make the column headers for the output file (which will be the series names in the plot)
#  my $colheads = ();
#  foreach my $valtype (@$valtypes) {
#    my $cleaned_up = ucfirst $valtype;
#    $cleaned_up =~ s/_/ /g;
#    push @$colheads, $cleaned_up;
#  }
#  
#  # Write the data to the file we set a bit earlier
#  $self->write_data_to_file($qualdata,$filename,$intervals,$valtypes,$colheads);
#  
#  # Set up arguments and execute the R script!
#  my @args = ($datafile, $qnum, $plot_title, $xlabel, $ylabel);
#  $self->call_rscript($rscript, \@args);
#  return ($plotfile, $datafile);
#}

sub sequence_content_plot {
  my $self = shift;
  my $qualdata = shift;       # Reference to data object
  my $valtypes = shift;       # List of value types in data object to use here.
                              # Expected order: A, C, G, T
  my $plot_title = shift;
  my $xlabel = shift;
  my $ylabel = shift;
  my $qnum = shift;           # Unique identifier of current query set
  
  if (!$qnum) { $qnum = 1; }
  
  # Set output filenames
  # These can be derived from the plot title, with all troublesome characters stripped out.
  my $filename = $plot_title;
  $filename =~ s/\s/_/g;
  $filename =~ s/[^a-zA-Z0-9_]//g;
  my $datafile = "$filename\_q$qnum.df";
  my $plotfile = "$filename\_q$qnum.pdf";
  #my $rscript = "sequence_content_across_reads";
  my $rscript = "sequence_content_plot";
  
  # Check that the right number of value types have been supplied
  my $required_types = 4;
  my $this_sub = (caller(1))[3];
  unless (@$valtypes == $required_types) { die "ERROR: Incorrect number of value types supplied to $this_sub function\n(".@$valtypes." supplied, $required_types required)\n"; }
  # Check that all scales used in the supplied data types match
  my $intervals = $self->check_scale_identity($qualdata,$valtypes,'interval_names_scale');
  # Make the column headers for the output file (which will be the series names in the plot)
  my $colheads = ();
  foreach my $valtype (@$valtypes) {
    my $cleaned_up = ucfirst $valtype;
    $cleaned_up =~ s/_/ /g;
    push @$colheads, $cleaned_up;
  }
  
  # Write the data to the file we set a bit earlier
  $self->write_data_to_file($qualdata,$filename,$intervals,$valtypes,$colheads);
  
  # Set up arguments and execute the R script!
  my @args = ($datafile, $qnum, $plot_title, $xlabel, $ylabel);
  $self->call_rscript($rscript, \@args);
  return ($plotfile, $datafile);
}

sub single_line_plot {
  my $self = shift;
  my $qualdata = shift;       # Reference to data object
  my $valtypes = shift;       # List of value types in data object to use here.
                              # Expected order: A, C, G, T
  my $plot_title = shift;
  my $xlabel = shift;
  my $ylabel = shift;
  my $qnum = shift;           # Unique identifier of current query set
  
  if (!$qnum) { $qnum = 1; }
  
  # Set output filenames
  # These can be derived from the plot title, with all troublesome characters stripped out.
  my $filename = $plot_title;
  $filename =~ s/\s/_/g;
  $filename =~ s/[^a-zA-Z0-9_]//g;
  my $datafile = "$filename\_q$qnum.df";
  my $plotfile = "$filename\_q$qnum.pdf";
  my $rscript = "sequence_content_across_reads";
  
  # Check that the right number of value types have been supplied
  my $required_types = 1;
  my $this_sub = (caller(1))[3];
  unless (@$valtypes == $required_types) { die "ERROR: Incorrect number of value types supplied to $this_sub function\n(".@$valtypes." supplied, $required_types required)\n"; }
  # Check that all scales used in the supplied data types match
  my $intervals = $self->check_scale_identity($qualdata,$valtypes,'interval_names_scale');
  # Make the column headers for the output file (which will be the series names in the plot)
  my $colheads = ();
  foreach my $valtype (@$valtypes) {
    my $cleaned_up = ucfirst $valtype;
    $cleaned_up =~ s/_/ /g;
    push @$colheads, $cleaned_up;
  }
  
  # Write the data to the file we set a bit earlier
  $self->write_data_to_file($qualdata,$filename,$intervals,$valtypes,$colheads);
  
  # Set up arguments and execute the R script!
  my @args = ($datafile, $qnum, $plot_title, $xlabel, $ylabel);
  $self->call_rscript($rscript, \@args);
  return ($plotfile, $datafile);
}

sub normal_distribution_plot {
  my $self = shift;
  my $qualdata = shift;       # Reference to data object
  my $valtypes = shift;       # List of value types in data object to use here.
                              # Expected order: A, C, G, T
  my $plot_title = shift;
  my $xlabel = shift;
  my $ylabel = shift;
  my $qnum = shift;           # Unique identifier of current query set
  
  if (!$qnum) { $qnum = 1; }
  
  # Set output filenames
  # These can be derived from the plot title, with all troublesome characters stripped out.
  my $filename = $plot_title;
  $filename =~ s/\s/_/g;
  $filename =~ s/[^a-zA-Z0-9_]//g;
  my $datafile = "$filename\_q$qnum.df";
  my $plotfile = "$filename\_q$qnum.pdf";
  my $rscript = "gc_distribution";
  
  # Check that the right number of value types have been supplied
  my $required_types = 1;
  my $this_sub = (caller(1))[3];
  unless (@$valtypes == $required_types) { die "ERROR: Incorrect number of value types supplied to $this_sub function\n(".@$valtypes." supplied, $required_types required)\n"; }
  # Check that all scales used in the supplied data types match
  my $intervals = $self->check_scale_identity($qualdata,$valtypes,'interval_names_scale');
  # Make the column headers for the output file (which will be the series names in the plot)
  my $colheads = ();
  foreach my $valtype (@$valtypes) {
    my $cleaned_up = ucfirst $valtype;
    $cleaned_up =~ s/_/ /g;
    push @$colheads, $cleaned_up;
  }
  
  # Write the data to the file we set a bit earlier
  $self->write_data_to_file($qualdata,$filename,$intervals,$valtypes,$colheads);
  
  # Set up arguments and execute the R script!
  my @args = ($datafile, $qnum, $plot_title, $xlabel, $ylabel);
  $self->call_rscript($rscript, \@args);
  return ($plotfile, $datafile);
}

#sub n_content_plot {
#  # MAY be able to replace this with a single line plot - see how it goes
#  my $self = shift;
#  my $interval_names = shift; # Position info for each data point
#  my $qualdata = shift;       # Reference to data object
#  my $qnum = shift;           # Unique identifier of current query set
#  
#  # Set output filenames
#  my $datafile = "n_content_q$qnum.df";
#  my $plotfile = "n_content_plot_q$qnum.pdf";
#  my $rscript = "n_content_across_reads";
#  
#  open(DAT, '>', $datafile) or die "Cannot open quality data file $datafile for R input\n";
#  print DAT "Interval\tN";
#  foreach my $interval (@$interval_names) {
#    my @line = ($interval);
#    push @line, shift @{$qualdata->{'base_content_n_percentage'}};
#    my $line = join "\t", @line;
#    print DAT "\n$line";
#  }
#  close DAT;
#  
#  # Set up arguments and execute the R script!
#  my @args = ($qnum);
#  $self->call_rscript($rscript, \@args);
#  return ($plotfile, $datafile);
#}

#sub length_distribution_plot {
#  # Reluctant to do this just yet - looks like I might have to pad some missing data.
#  # I'm going to add a function elsewhere to add leading/following padding, then feed this to the single line plotter.
#  my $self = shift;
#  my $interval_names = shift; # Position info for each data point
#  my $qualdata = shift;       # Reference to data object
#  my $qnum = shift;           # Unique identifier of current query set
#  
#  # Set output filenames
#  my $datafile = "length_dist_q$qnum.df";
#  my $plotfile = "length_dist_plot_q$qnum.pdf";
#  my $rscript = "length_distribution";
#  
#  open(DAT, '>', $datafile) or die "Cannot open quality data file $datafile for R input\n";
#  print DAT "Xval\tLengthDist";
#  
#  # In the case of Illumina reads, there will only be one entry here.
#  # Put one either side, in order to replicate the FastQC plot.
#  if (@$interval_names == 1) {
#    my $num = $interval_names->[0];
#    unshift @$interval_names, $num - 1;
#    unshift @{$qualdata->{'sequence_length_count'}}, '0.0';
#    push @$interval_names,    $num + 1;
#    push @{$qualdata->{'sequence_length_count'}}, '0.0';
#  }
#  
#  foreach my $interval (@$interval_names) {
#    my @line = ($interval);
#    push @line, shift @{$qualdata->{'sequence_length_count'}};
#    my $line = join "\t", @line;
#    print DAT "\n$line";
#  }
#  close DAT;
#  
#  # Set up arguments and execute the R script!
#  my @args = ($qnum);
#  $self->call_rscript($rscript, \@args);
#  return ($plotfile, $datafile);
#}

#sub sequence_duplication_plot {
#  # MAY be able to replace this with a single line plot - see how it goes
#  my $self = shift;
#  my $qualdata = shift;       # Reference to data object
#  my $valtypes = shift;       # List of value types in data object to use here.
#                              # Expected order: A, C, G, T
#  my $qnum = shift;           # Unique identifier of current query set
#  my $plot_title = shift;
#  my $xlabel = shift;
#  my $ylabel = shift;
#  
#  # Set output filenames
#  # These can be derived from the plot title, with all troublesome characters stripped out.
#  my $filename = $plot_title;
#  $filename =~ s/\s/_/g;
#  $filename =~ s/[^a-zA-Z0-9_]//g;
#  my $datafile = "$filename\_q$qnum.df";
#  my $plotfile = "$filename\_q$qnum.pdf";
#  my $rscript = "sequence_duplication";
#  
#  
#  # Check that the right number of value types have been supplied
#  my $required_types = 1;
#  my $this_sub = (caller(1))[3];
#  unless (@$valtypes == $required_types) { die "ERROR: Incorrect number of value types supplied to $this_sub function\n(".@$valtypes." supplied, $required_types required)\n"; }
#  # Check that all scales used in the supplied data types match
#  my $intervals = $self->check_scale_identity($qualdata,$valtypes,'interval_names_scale');
#  # Make the column headers for the output file (which will be the series names in the plot)
#  my $colheads = ();
#  foreach my $valtype (@$valtypes) {
#    my $cleaned_up = ucfirst $valtype;
#    $cleaned_up =~ s/_/ /g;
#    push @$colheads, $cleaned_up;
#  }
#  
#  # Write the data to the file we set a bit earlier
#  $self->write_data_to_file($qualdata,$filename,$intervals,$valtypes,$colheads);
#  
#  # Set up arguments and execute the R script!
#  my @args = ($datafile, $qnum, $plot_title, $xlabel, $ylabel);
#  $self->call_rscript($rscript, \@args);
#  return ($plotfile, $datafile);
#}

sub machine_activity_plot {
  # Makes a plot of when machines are actually engaged over a given time interval
  # This uses very different data to that used by the funcs above. Don't rewrite until I'm sure what I'm doing.
  # Given that it actually does carry out a function that isn't easily generalisable, I might leave it as it is.
  my $self = shift;
  my $inputs = shift;   # The standard hash reference to the inputs arranged above
  my $qualdata = shift; # File containing operations overview data
  
  my $datafile = "ops_dates.df";
  #my $plotfile = "ops_plot.pdf";
  my $rscript = "instrument_activity_plot";
  
  open(DAT, '>', $datafile) or die "Cannot open operations data file $datafile for R input\n";
  print DAT "DATE_TYPE,DATE,INSTRUMENT,RUN,LANE,PAIR\n";
  foreach my $line (@$qualdata) {
    print DAT "$line\n";
  }
  close DAT;
  
  # Set up arguments
  my @args = ("'".$inputs->{BEGIN}."'", "'".$inputs->{END}."'");
  # Passing data file as argument to call_rscript is deprecated; it should be passed as an argument to the R script.
  my $plotfile = $self->call_rscript($rscript, $datafile, \@args);
  return ($plotfile, $datafile);
}

sub small_barplot {
  # Makes a simple bar plot. Data should be supplied as a hash reference, with
  # the hash keys being the names of the plots. Barcode tags can also be supplied
  # as a second hash reference.
  # Again, this takes quite different data - it may not be right to rewrite it.
  my $self = shift;
  my $data = shift;
  my $tags = shift;
  my $title = shift;
  # Going to assume that the title is "Lane n adapters" or similar
  my $lane = $title;
  $lane =~ s/[^0-9]//g;
  
  my $datafile = "adapter_plot.df";
  my $rscript = "adapter_barplot";
  
  my @sample_names = sort {$a cmp $b} keys $data;
  
  open(DAT, '>', $datafile) or die "Cannot open operations data file $datafile for R input\n";
  print DAT "sampleName,readCount,barcode\n";
  foreach my $sample_name (@sample_names) {
    print DAT "$sample_name,".$data->{$sample_name}.",".$tags->{$sample_name}."\n";
  }
  close DAT;
  
  # Set up arguments
  my @args = ("'".$title."' $lane");
  # Passing data file as argument to call_rscript is deprecated; it should be passed as an argument to the R script.
  my $plotfile = $self->call_rscript($rscript, $datafile, \@args);
  return ($plotfile, $datafile);
}

# The following subs are involved with generating reports in LaTeX.
# Given relevant inputs or data, they will produce a string that can be
# interpolated with others to produce a full LaTeX file from a consumer
# script.
my %texcode = ();
$texcode {"open_fig"} =
"\\begin{figure}[htp]
";

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

sub new_texdoc {
  # Sets up the modules and opening declarations etc. that are necessary at the
  # beginning of the document
  return "\\documentclass[slides,12pt]{article}
  \\usepackage{graphicx}
  \\usepackage{longtable}
  \\usepackage[margin=0.75in]{geometry}
  \\usepackage{float}
  \\usepackage{multirow}
  \\graphicspath{ {R/Plots/} }
  \\begin{document}\n";
}

sub clear_page {
  # Basically a forced declaration to finish a page and move on to the next.
  return "\\clearpage\n\n";
}

sub make_vertical_space {
  # Makes a vspace command, which causes everything below to be nudged downwards by the
  # specified number of millimetres.
  my $self = shift;
  my $n = shift;
  return "\\vspace{$n mm}\n";
}

sub end_texdoc {
  return "\\end{document}";
}

sub make_simple_table {
  # Takes in a lot of array refs and uses them to build a table.
  # Does a sanity check first: number of headers should match number of columns,
  # and number of rows should be the same across all columns.
  # Array of headers supplied first, followed by arrays for each of the data
  # columns
  my $self = shift;
  my $headers = shift;
  my $data = shift;
  # Use this in cases where you know that the number of column headers is going oto be different to the
  # number of rows (e.g., multi-line headers). 
  my $suppress_colcount_check = shift; 
  
  # Sanity checks
  # Check number of headers = number of columns
  unless ((@$data == @$headers) || ($suppress_colcount_check)) {
    die "ERROR: Number of column headings in LaTeX data table does not match number of data columns\n(".@$data." vs. ".@$headers.")\n";
  }
  
  # Check number of rows is always the same
  my $numrows = @{$data->[0]};
  foreach my $i (1..@$data) {
    $i--;
    unless (@{$data->[$i]} == $numrows) {
      die "ERROR: Data colums in LaTeX table have different lengths.\n";
    }
  }
  
  # Output comes as a string, with the table data encoded within it.
  my $string = "\\begin{tabular}{";
  
  # Set number of columns in this tabular environment
  foreach my $col (@$data) { $string .= 'l'; }
  $string .= '}';
  
  my $line = join ' & ', @$headers;
  # When producing a multi-line header, that join can result in lower lines having too many '&'
  # symbols, resulting in a failed LaTeX conversion. In other words, a '&' gets written before the
  # first cell. Remove it here.
  $line =~ s/\n \&/\n /g;
  
  $string .= "\n\t"."$line \\\\"."\n\t".'\hline'."\n";
  
  foreach my $row (1..$numrows) {
    $row --;
    my @rowdata = ();
    foreach my $col (@$data) {
      push @rowdata, $col->[$row];
    }
    $line = join ' & ', @rowdata;
    $string .= "\t$line \\\\"."\n";
  }
  
  $string .= "\\end{tabular}\n\\vspace{4mm}";
  return $string;
}

sub make_simple_figure {
  # Plant a single, full-width figure down. 
  my $self = shift;
  my $img = shift;
  
  # This might need some work yet.
  my $fig =
  "\\begin{figure}[htp]
  \\includegraphics[width=1\\textwidth]{$img}
  \\end{figure}
  \\clearpage
  ";
  return $fig;
}

sub make_fastqc_report_figure {
  # Makes a figure comprised of up to 8 sub-figures per page.
  # These appear in a 2X4 grid.
  my $self = shift;
  my $plotfiles = shift;
  # Text1 will, in the context of FastQC diagrams, be the run ID
  # Text2 will be the filename containing all the reads.
  my $text1 = shift;
  my $text2 = shift;
  
  if (@$plotfiles > 8) {
    die "ERROR: incorrect number of plot files (".@$plotfiles." > 8) supplied to LaTeX figure generator\n";
  }
  
  # Using the bits of TeX code set earlier, this creates a 2x4 figure
  # with the 8 plots just produced by R.
  my $string = $texcode{"open_fig"};
  $string =~ s/_/\\_/g;
  $string =~ s/%/\\%/g;
  
  if ($text1) {
    $string .= "\\large
{\\bf $text1} \\\\
\normalsize\n";
  }
  if ($text2) {
    $string .= "\\large
{\\bf $text2} \\\\
\normalsize\n";
  }
  
  # I reuse this sub somewhere else, in a different context. In that case, then there might be either
  # 1, 2 or 8 plots supplied. That means I have to add the capability to deal with odd numbers of
  # figures. They should be over to the left. 
  
  my $leftright = 'l';
  my $c = 0;
  foreach my $plot (@$plotfiles) {
    my $subfig = $texcode{"include_img"};
    $c++;
    $subfig =~ s/img/$plot/;
    
    if ($leftright eq 'l') {
      if ($c == @$plotfiles) {
        $string .= $texcode{"left_img"}.$subfig.$texcode{"between_img"}.$texcode{"right_img"};
      }
      else {
        $string .= $texcode{"left_img"}.$subfig.$texcode{"between_img"};
        $leftright = 'r';
      }
    }
    else {
      $string .= $subfig.$texcode{"right_img"};
      $leftright = 'l';
    }
    
  }
  $string .= $texcode{"close_fig"};
  return $string;
}

sub latex_to_pdf {
  # Calls pdflatex on a LaTeX doc, producing a PDF.
  my $self = shift;
  my $latex = shift;
  
  my @argv = ('pdflatex '.$latex);
  #system(@argv) == 0 or die "Cannot automatically convert $latex to PDF\n";
  my $cl = `$argv[0]` or die "Cannot automatically convert $latex to PDF\n";
}



# The following subs prepare queries that are useful in consumers and operations overviews.
# In other words, they are useful for actually retrieving data from the database.

sub get_all_queryset_data {
  # I've discovered that it's far quicker to retrieve as much data as possible with a small number of
  # carefully optimised but broad-scope queries, than to submit hundreds of similar, narrow-scope queries.
  # There are still 3 major divisions within that data, though (per-analysis, per-position and per-partition)
  # and there are distinct queries to deal with each.
  # This is a convenience function that calls all 3 of those queries and parses their data into a single
  # hash structure.
  # Takes the standard consumer input parameter structure as an input.
  my $self = shift;
  my $inputs = shift;
  my $reports = $self->{reports};
  
  my $queryset_data = ();
  
  # Get values that have only a single instance across an analysis object
  my $qry = $reports->per_analysis_values_for_run($inputs);
  my $avg = $qry->to_csv;
  my @returned_values = split /\n/, $avg;
  shift @returned_values;
  
  foreach my $line (@returned_values) {
    chomp $line;
    my @vals = split /,/, $line;
    # Be aware that some of these values, particularly $barcode, may be null...
    foreach my $i (1..9) {
      if (!$vals[$i-1]) { $vals[$i-1] = '0.000'; }
    }
    
    my ($value,$value_type,$instrument,$run,$lane,$read,$sample_name,$barcode,$tool) = @vals;
    
    # Arrange the data into the best structure.
    # If it proves necessary I'll make sample_name substitutable for barcode, because it reflects
    # the real situation well.
    $queryset_data->{$instrument}{$run}{$lane}{$read}{$sample_name}{$tool}{$value_type} = $value;
    #$queryset_data->{$instrument}{$run}{$lane}{$read}{$barcode}{$tool}{$value_type} = $value;
  }
  
  # Get values that describe single discrete points along an interval for an analysis object
  $qry = $reports->per_position_values_for_run($inputs);
  $avg = $qry->to_csv;
  @returned_values = split /\n/, $avg;
  shift @returned_values;
  
  foreach my $line (@returned_values) {
    chomp $line;
    my @vals = split /,/, $line;
    # Be aware that some of these values, particularly $barcode, may be null/NA...
    foreach my $i (1..10) {
      if (!$vals[$i-1]) { $vals[$i-1] = '0.000'; }
    }
    
    my ($position,$value,$value_type,$instrument,$run,$lane,$read,$sample_name,$barcode,$tool) = @vals;
    
    # Arrange the data into the best structure.
    # If it proves necessary I'll make sample_name substitutable for barcode, because it reflects
    # the real situation well.
    $queryset_data->{$instrument}{$run}{$lane}{$read}{$sample_name}{$tool}{$value_type}{$position}{value} = $value;
    #$queryset_data->{$instrument}{$run}{$lane}{$read}{$barcode}{$tool}{$value_type}{$position} = $value;
  }
  
  # Get values that describe a contiguous range of points along an interval for an analysis object
  $qry = $reports->per_partition_values_for_run($inputs);
  $avg = $qry->to_csv;
  @returned_values = split /\n/, $avg;
  shift @returned_values;
  
  foreach my $line (@returned_values) {
    chomp $line;
    my @vals = split /,/, $line;
    # Be aware that some of these values, particularly $barcode, may be null...
    foreach my $i (1..10) {
      if (!$vals[$i-1]) { $vals[$i-1] = '0.000'; }
    }
    
    my ($partition,$partition_size,$value,$value_type,$instrument,$run,$lane,$read,$sample_name,$barcode,$tool) = @vals;
    
    # Arrange the data into the best structure.
    # If it proves necessary I'll make sample_name substitutable for barcode, because it reflects
    # the real situation well.
    $queryset_data->{$instrument}{$run}{$lane}{$read}{$sample_name}{$tool}{$value_type}{$partition}{value} = $value;
    $queryset_data->{$instrument}{$run}{$lane}{$read}{$sample_name}{$tool}{$value_type}{$partition}{size} = $partition_size;
    #$queryset_data->{$instrument}{$run}{$lane}{$read}{$barcode}{$tool}{$value_type}{$partition}{value} = $value;
    #$queryset_data->{$instrument}{$run}{$lane}{$read}{$barcode}{$tool}{$value_type}{$partition}{size} = $partition_size;
  }
  
  return $queryset_data;
}

sub aggregate_data {
  # This sub does two things at once:
  # It retrieves all the data of a specified type from the data object set up in get_all_queryset_data.
  # It also aggregates that data into a single set of averaged/summed figures according to the data type.
  my $self = shift;
  my $data = shift;
  my $value_type = shift;
  
  unless ($value_type) {
    die "ERROR: value_type not set in data aggregation function\n";
  }
  
  my %agg_data = ();
  my %agg_size = ();
  foreach my $instrument (keys %{$data}) {
    foreach my $run (keys %{$data->{$instrument}}) {
      foreach my $lane (keys %{$data->{$instrument}{$run}}) {
        foreach my $read (keys %{$data->{$instrument}{$run}{$lane}}) {
          foreach my $sample_name (keys %{$data->{$instrument}{$run}{$lane}{$read}}) {
            foreach my $tool (keys %{$data->{$instrument}{$run}{$lane}{$read}{$sample_name}}) {
              # OK, that navigates us down to the level of a single record (or set of records).
              # We only need to do anything if the matching value type is present here.
              if ($data->{$instrument}{$run}{$lane}{$read}{$sample_name}{$tool}{$value_type}) {
                # If the matching data type is found, 3 courses of action are available.
                # 1. If $data{...}{$value_type} is a single value, push it into @agg_data.
                #    It's an analysis value, and a simple mean/sum will be returned.
                # 2. If $data{...}{$value_type} is an array value and a partition size is not present,
                #    it's a position value and we'll set up an array of arrays to get mean/sum for
                #    each position.
                # 3. If If $data{...}{$value_type} is an array value and a partition size is present,
                #    it's a partition value and we'll set up an array of arrays for mean/sum per
                #    partition, and also store the sizes of the partitions in a similar array.
                
                if ($data->{$instrument}{$run}{$lane}{$read}{$sample_name}{$tool}{$value_type}) {
                  # Possibilities 2 and 3 lead here
                  my @positions = keys %{$data->{$instrument}{$run}{$lane}{$read}{$sample_name}{$tool}{$value_type}};
                  
                  if (ref($data->{$instrument}{$run}{$lane}{$read}{$sample_name}{$tool}{$value_type}{$positions[0]}{size})) {
                    # Possibility 3 (partition values) leads here
                    # We can tell because they have a 'size' field attached as well as a 'value' field.
                    foreach my $partition (@positions) {
                      my $value = $data->{$instrument}{$run}{$lane}{$read}{$sample_name}{$tool}{$value_type}{$partition}{value};
                      my $size = $data->{$instrument}{$run}{$lane}{$read}{$sample_name}{$tool}{$value_type}{$partition}{size};
                      push @{$agg_data{$partition}}, $value;
                      push @{$agg_size{$partition}}, $size;
                    }
                  }
                  else {
                    # Possibility 2 (position values) leads here
                    foreach my $position (@positions) {
                      my $value = $data->{$instrument}{$run}{$lane}{$read}{$sample_name}{$tool}{$value_type}{$position}{value};
                      push @{$agg_data{$position}}, $value;
                    }
                  }
                }
                else {
                  # Possibility 1 (analysis values) leads here
                  push @{$agg_data{$value_type}}, $data->{$instrument}{$run}{$lane}{$read}{$sample_name}{$tool}{$value_type};
                }
              }
            }
          }
        }
      }
    }
  }
  
  # That's the data rearranged; now it's a matter of getting either an overall average (in the case of
  # analysis_value data) or a per-position/partition average, and returning it all in a consistent format.
  # I also round sum and mean to3 decimal places here.
  if ($agg_data{$value_type}) {
    # If data is found in here, there is only one list of numbers to be averaged/summed.
    my $sum = $self->sum($agg_data{$value_type});
    my $mean = $self->mean($agg_data{$value_type});
    $sum = $self->round_to_x_places($sum, 3);
    $mean = $self->round_to_x_places($mean, 3);
    my $count = @{$agg_data{$value_type}};
    
    my @headers = ('AVERAGE','SAMPLES','TOTAL');
    return (\@headers,$mean,$count,$sum);
  }
  else {
    my @positions = sort {$a <=> $b} keys %agg_data;
    my @sums = (); my @means = ();
    my @size_means = ();
    my @counts = ();
    
    foreach my $position (@positions) {
      my $sum = $self->sum($agg_data{$position});
      my $mean = $self->mean($agg_data{$position});
      $sum = $self->round_to_x_places($sum, 3);
      $mean = $self->round_to_x_places($mean, 3);
      my $count = @{$agg_data{$position}};
      push @sums, $sum;
      push @means, $mean;
      push @counts, $count;
      
      if ($agg_size{$position}) {
        my $size_mean = $self->mean($agg_size{$position});
        push @size_means, $size_mean;
      }
      else { push @size_means, 1; }
    }
    
    my @headers = ('POSITION','SIZE','AVERAGE','SAMPLES','TOTAL');
    return (\@headers,\@positions,\@size_means,\@means,\@counts,\@sums);
  }
}

sub rotate_query_results_col_to_row {
  # The results returned from aggregate_data are organised into columns.
  # This organises them by row, making it easier to print this stuff to stdout etc.
  # It's assumed that column references are supplied in the correct order.
  my $self = shift;
  my $headers = shift;
  my @columns = @_;
  
  my @lines = ();
  my $headstring = join "\t", @$headers;
  push @lines, $headstring;
  
  foreach my $line_num (1..@{$columns[0]}) {
    my @line = ();
    foreach my $column (@columns) {
      push @line, $column->[$line_num - 1];
    }
    my $line = join "\t", @line;
    push @lines, $line;
  }
  return \@lines;
}

sub rotate_query_results_row_to_col {
  # This organises query results by row, making it easier to get to specific columns.
  # The inverse operation to rotate_query_results_col_to_row.
  # Note that output of parse_query_results can also be understood by this function, as long as the header
  # array reference is unshifted into the data array.
  my $self = shift;
  my @rows = @_;
  # Input may have been passed as a reference; account for that here
  if ((@rows == 1) && (ref $rows[0])) { @rows = @{$rows[0]}; }
  
  my $headstring = shift @rows;
  my @headers = ();
  if (ref $headstring) { @headers = @$headstring; }
  else                 { @headers = split /,|\t/, $headstring; }
  
  my @columns = ();
  $columns[0] = \@headers;
  foreach my $line (@rows) {
    my @data = ();
    if (ref $line) { @data = @$line; }
    else           { @data = split /,|\t/, $line; }
    foreach my $i (1..@data) {
      push @{$columns[$i]}, $data[$i-1];
    }
  }
  
  return \@columns;
}

sub sum {
  my $self = shift;
  my $in = shift;
  my $total = 0;
  foreach my $i (@$in) {
    $total += $i;
  }
  return $total;
}

sub mean {
  my $self = shift;
  my $in = shift;
  
  if (!$in) {
    return 0;
  }
  my @data = @$in;
  if (@data == 0) {
    return 0;
  }
  
  my $total = $self->sum(\@data);
  my $mean = $total / @data;
  return $mean;
}

1;