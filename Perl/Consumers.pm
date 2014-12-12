package Consumers;
use List::Util qw(min max);
use Timecode;
use strict;

# This module contains general methods that are useful when writing
# consumer scripts. Using these ought to make it easier both to write
# and to read consumers.

# The following hash stores all the short-type (single character) input
# flags, corresponding to longer names.
# If adding a new flag, update this too
my %short_flags = (
  'help'        => 'h',
  'db_config'   => 'd',
  'analysis'    => 'a',
  'instrument'  => 'i',
  'run'         => 'r',
  'pseq'        => 'o',
  'lane'        => 'l',
  'pair'        => 'p',
  'sample_name' => 's',
  'barcode'     => 'b',
  'scope'       => 'q',
  'begin'       => 'c',
  'end'         => 'e',
  'datetype'    => 't',
  'tool'        => 'm',
);

# Reverse that so long flags can be looked up from short flags
my %long_flags = reverse %short_flags;

# The following hash stores help strings for individual options in much
# the same way.
my %help_strings = (
  'help'        => 'Display this message',
  'db_config'   => 'Database connection specification file (required)',
  'analysis'    => 'Numeric ID of a single analysis record',
  'instrument'  => 'Instrument name',
  'run'         => 'Run ID',
  'pseq'        => 'PSEQ/SEQOP ID (TGAC internal tracking system)',
  'lane'        => 'Lane',
  'pair'        => 'Read',
  'sample_name' => 'Sample name',
  'barcode'     => 'Barcode',
  'scope'       => 'Query scope',
  'begin'       => 'Begin date/time of a time interval',
  'end'         => 'End date/time of a time interval',
  'datetype'    => 'Time record type to use in time interval selection',
  'tool'        => 'Type of analysis data to select (e.g., FastQC)',
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
    'h|help'          => \$vals{help},
    'd|db_config=s'   => \$vals{db_config},
    'a|analysis:i'    => \$vals{analysis},
    'i|instrument:s'  => \$vals{instrument},
    'r|run:s'         => \$vals{run},
    'o|pseq:s'        => \$vals{pseq},
    'l|lane:s'        => \$vals{lane},
    'p|pair:i'        => \$vals{pair},
    's|sample_name:s' => \$vals{sample_name},
    'b|barcode:s'     => \$vals{barcode},
    'q|scope:s'       => \$vals{qscope},
    'c|begin:s'       => \$vals{begindate},
    'e|end:s'         => \$vals{enddate},
    't|datetype:s'    => \$vals{datetype},
    'm|tool:s'        => \$vals{tool},
  );
  
  # Set the supplied list of active options into a hash, for ease of
  # searching them
  my %opts = ();
  foreach my $opt (@$opts) { $opts{$opt} = 1; }
  # Certain options should always be present; set them now
  $opts{db_config} = 1;
  $opts{help}      = 1;
  
  # Do some simple error-checking
  # Check that the passed query scope, if any, is one of the available
  # values
  unless (($query_scopes{$vals{qscope}}) || ($vals{qscope} eq 'na')) {
    die "Query scope (-q) should be set to one of:\n".
        (join "\n", keys %query_scopes).
        "\nor left unset\n";
  }
  
  # Handle date-times, if any are supplied as inputs
  if ($vals{begindate} || $vals{enddate}) {
    $vals{begindate} = Timecode::parse_input_date($vals{begindate});
    $vals{enddate}   = Timecode::parse_input_date($vals{enddate});
  }
  
  # If a PSEQ or SEQOP ID (internal TGAC operations tracking code) is
  # supplied, we need to look up the corresponding run ID, since that's
  # what the database stores.
  if ($vals{pseq}) {
    pseq_to_run_id(\%vals);
  }
  
  # Now actually set the supplied values into a hash
  my $input_values = ();
  $input_values->{QSCOPE} = $vals{qscope};
  my @help_string = ();
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
  # stored procedure sometimes returns null columns at 
  
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

# Set up query sets
# Given input values, return a list of distinct, defined sets of parameters
# that can be passed to an SQL select statement to retrieve desired data. 

sub prepare_query_sets {
  my $self = shift;
  my $input_values = shift;
  my $reports = $self->{reports};
  
  if (!$input_values->{QSCOPE}) { $input_values->{QSCOPE} = 'na'; }
  
  my @query_sets = ();
  if ($input_values->{QSCOPE} eq 'na') {
    my %qry = %$input_values;
    push @query_sets, \%qry;
  }
  else {
    print "Preparing query sets\n";
    my $qry = $reports->list_subdivisions($input_values);
    my $avg = $qry->to_csv;
    my ($column_headers,$returned_values) = $self->parse_query_results(\$avg);
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
        my $bc = get_barcode_for_sample($qry{SAMPLE_NAME});
        $qry{BARCODE} = $bc;
      }
      
      push @query_sets, \%qry;
      
      print "QUERY $n:\n";
      foreach my $key (keys %qry) {
        print "\t$key:\t".$qry{$key}."\n";
      }
    }
  }
  
  return \@query_sets;
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

sub parse_query_results {
  # Dealing with the csv data returned from a query requires several
  # lines of scruffy code. This sub takes care of it much more neatly.
  # Pass in a query results object and get back two array references:
  # first, the column headers;
  # second, an array of values per row, split on comma (since csv). 
  my $self = shift;
  my $in_ref = shift;
  
  chomp $$in_ref;
  my @returned_values = split /\s/, $$in_ref;
  
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
    ($column_headers,$returned_values) = $self->parse_query_results(\$input1);
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










# The following subs all call R scripts to produce graphs.










# The following subs are involved with generating reports in LaTeX.







1;