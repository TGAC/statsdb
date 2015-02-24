package Timecode;
use XML::Simple;
use List::Util qw( min max );
use Time::Local qw(timegm);
use POSIX;
use strict;
local $| = 1;

# This module is designed to handle the date- and timestamps passed
# to the consumer scripts when searching for data between given
# time-points, and also to get the various dates available from the output
# of a sequencing run and merge that data into the database insertion object.

sub parse_input_date {
  # Wrangle the supplied dates - probably in the sensible DD/MM/YYYY format
  # - into the timestamp format used when talking to the database.
  my $indate = $_[0];
  
  # Date may not be set. If it isn't set, fill it up with the present time.
  if (!$indate) { $indate = present_timestamp(); }
  
  # Date may be supplied with a time code as well.
  # If it is, it should be checked, set aside and added back on later.
  # If not, add a midnight time (00:00:00).
  
  my ($date, $time) = split /\s/, $indate;
  check_date_input_format ($date);
  $date = standardise_date_input_format($date);
  if (!$time) { $time = "00:00:00"; }
  else { check_input_time_format($time); }
  
  return "$date $time";
}

sub parse_log_date {
  # When retrieving dates from instrument log files, you need to remove
  # unnecessary stuff, and also reformat the timestamp to match the standard
  # format used in the rest of this code.
  my $instring = $_[0];
  
  # Date may not be set. If it isn't set, return error.
  # (This is a debugging issue, rather than a user input one)
  if (!$instring) { die "ERROR: log timestamp string empty\n"; }
  chomp $instring;
  $instring =~ s/\s/ /g;
  
  # Extract the timestamp sections of the string
  # Note that the seconds figure appears to be a decimal. I split on . in order
  # to integerise it. 
  my ($date, $time) = split /[,\.]/, $instring;
  if (!$date) { die "ERROR: cannot retrieve date from log timestamp string\n[$instring]\n"; }
  if (!$time) { die "ERROR: cannot retrieve time from log timestamp string\n[$instring]\n"; }
  
  # Date in logs is supplied in MM/DD/YYYY format. Put that back the right
  # way round.
  my @date_parts = split /\//, $date;
  my $i = $date_parts [1];
  $date_parts[1] = $date_parts [0];
  $date_parts[0] = $i;
  $date = join '/',@date_parts;
  
  # Then do all the normal formatting stuff, the same as any other timestamp.
  check_date_input_format($date);
  $date = standardise_date_input_format($date);
  if (!$time) { $time = "00:00:00"; }
  else { check_input_time_format($time); }
  
  return "$date $time";
}

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
  # 18:00:36 (hour:min:sec)
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
  # or (2/4/14 or 02/04/14)
  # or (2/4/2014 or 02/04/2014)
  # dashes can also be used
  unless ($indate =~ /^[0-9]{1,2}[\/\-][0-9]{1,2}$|^[0-9]{1,2}[\/\-][0-9]{1,2}[\/\-][0-9]{2,4}$/) {
    # If we're in here, we've got a date format I don't expect.
    die "Unexpected input date format\n ($indate)\nSee help (run with flag -h) for correct formats\n\n";
  }
  
  # The above does not make a few other checks for obviously silly values resulting from typos and such
  my ($inday, $inmon, $inyr) = split /\/|\-/, $indate;
  my ($day, $mnt, $yr, $time) = split /[\s\-]/, present_time();
  if ($inday > 31) { die "Probable typo: input day number ($inday) greater than 31\n\n"; }
  if ($inmon > 12) { die "Probable typo: month number ($inmon) greater than 12\n\n"; }
  if ($inyr) {
    if ($inyr > $yr) { die "Probable typo: input year number ($inyr) greater than current year\n\n"; }
    if (length $inyr == 3) { die "Probable typo: input year number ($inyr) has only 3 digits\n\n"; }
  }
}

sub check_timestamp_log_format {
  # Check that a date retrieved from a log is in a suitable format
  # Simply return 1 if it is, and 0 if it's not.
  my $indate = $_[0];
  
  if ($indate =~ /^[0-9]{4}[\/\-][0-9]{1,2}[\/\-][0-9]{1,2} [0-9]{2}:[0-9]{2}:[0-9]{2}$/) {
    return 1;
  }
  else {
    return 0;
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

sub convert_to_numeric_datestamp {
  # Converts a date supplied in the human/SQL-readable format above to the numeric
  # string-type datestamp used by MISO. (UNIX epoch timestamp)
  my $instamp = $_[0];
  
  my ($date, $time) = split / /, $instamp;
  my ($year,$month,$day) = split /-/, $date;
  my ($hour,$min,$sec) = split /:/, $time;
  
  return timegm($sec, $min, $hour, $day, $month, $year);
}

sub convert_from_numeric_datestamp {
  # Converts UNIX epoch timestamps into the format I use more widely here.
  my $instamp = $_[0];
  
  # Note that some epoch stamps are formatted for milliseconds, but others aren't.
  # Try getting a date; if the year comes back as a large number, remove the last 3 characters
  # and try again. 
  $instamp = format_numeric_datestamp($instamp);
  
  my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday) = gmtime($instamp);
  $year += 1900;
  #$month ++;
  
  my $datestring = sprintf "%04d-%02d-%02d %02d:%02d:%02d", $year,$month,$mday,$hour,$min,$sec;
  
  #print "INPUT\t $instamp\tOUT\t$datestring\n\n";
  
  return $datestring;
}

sub format_numeric_datestamp {
  # Sometimes, the unix epoch timestamps we get are formatted in milliseconds rather than
  # the seconds that perl expects.
  # If this proves to be the case, strip the millisecond values off.
  my $instamp = $_[0];
  
  my ($sec,$min,$hour,$mday,$month,$year,$wday,$yday) = gmtime($instamp);
  $year += 1900;
  #$month ++;
  
  # Consider it future-proof.
  if ($year > 3000) {
    for (1..3) { chop $instamp; }
  }
  
  return $instamp;
}

sub convert_to_human_readable_date {
  # This takes the standard datetime input format (YYYY-MM-DD HH:MM:SS) and makes it a
  # human-readable date (DD-Mon-YYYY). 
  my $indate = $_[0];
  my @sp = split / /, $indate;
  my $date = $sp[0];
  my @dates = split /-/, $date;
  my @months = ('Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec');
  my $mon = $dates[1] - 1;
  my $readable_date = $dates[2]."-".$months[$mon]."-".$dates[0];
  return $readable_date;
}

##########
# The following functions are designed to get the various dates available
# from the output of a sequencing run and merge that data into the database
# insertion object.

# At the moment, those sources of timestamps is basically hardcoded (within the
# run directory) on the assumption that users will leave these files where they
# are put by default. This may change as the project develops, or may not.

sub get_dates {
  my $class = shift;
  my $analysis = shift;
  
  # Run directory is stored as a property. Get it.
  my $run_dir = $analysis->get_property("run_folder");
  my $analysis_type = $analysis->get_property("analysis_type");
  my $noindex_readnum = $analysis->get_property("pair");
  
  # Set the read number (if any)
  # The sub called here sets the read number according to the numbering scheme
  # that counts index reads, rather than the FastQC numbering scheme, which
  # does not.
  my $index_readnum = fastqc_readid_to_on_machine($analysis);
  
  # One thing to check: is this run complete?
  # If it isn't, bail with an error.
  # Check if RTAComplete.txt is present
  unless (-e "$run_dir/RTAComplete.txt") { return "WARN: Run not complete\n"; }
  
  # Get all the various types of date we need to get for this type of analysis.
  # Read start and end should only be stored for analyses that are inserted
  # per-read. (I.e., FastQC; InterOp analyses handle this in a different way)
  # Note that types of analysis with no read number assigned will therefore not
  # attempt to fill in read start and end data.
  my @date_types = ("run_start", "run_end");
  if ($analysis_type =~ /fastqc/i) {
    push @date_types, "read_start";
    push @date_types, "read_end";
  }
  
  # Create an action table
  my %actions = (
    run_start  => \&run_start,
    run_end    => \&run_end,
    read_start => \&read_start,
    read_end   => \&read_end,
  );
  
  # Actually go and get each of those date types.
  # It's assumed here that relevant error-checking will be done within the
  # called sub, since it may be quite different for individual dates.
  # If there is a problem, an error code will be returned.
  my $errors = ();
  foreach my $date_type (@date_types) {
    my $date = &{$actions{$date_type}}($run_dir,$index_readnum);
    if (check_timestamp_log_format($date) != 1) {
      $errors .= $date;
    }
    else {
      $analysis->add_date($date_type,$date);
    }
  }
  
  # Pass back the error codes, if any
  if ($errors) {
    return $errors;
  }
  else {
    return 1;
  }
}

sub fastqc_readid_to_on_machine {
  # FastQC read-in may need the read number for the analysis to be adjusted when
  # using Illumina machines.
  # Simply stated, the Illumina primary analysis counts index reads in its read
  # number system, while FastQC does not. Since 
  
  # The $analysis_type variable can be used to determine what to do, if anything,
  # with the read number.
  
  # Additionally, InterOp data is supplied in statsdb_string on a per-run basis,
  # so no read number is supplied in the analysis. It's added later, when the
  # analysis object is cloned. Resolved by setting read start and end times
  # in InterOp.pm AFTER the object is cloned.
  # I leave read start and end conditions to be filled by default in order that
  # single-end reads will still record that information.
  my $analysis = shift;
  
  # Run directory is stored as a property. Get it.
  my $run_dir = $analysis->get_property("run_folder");
  
  my $analysis_type = $analysis->get_property("analysis_type");
  my $fastqc_readnum = $analysis->get_property("pair");
  
  if ($analysis_type =~ /fastqc/i) {
    # Get read numbers (in the numbering scheme that counts index reads) that
    # aren't index reads.
    my $runinfo = parse_runinfo($run_dir);
    my @readnums_that_arent_indexes = ();
    
    my $runs = $runinfo->{Run}{Reads}{Read};
    foreach my $i (@$runs) {
      if ($i->{IsIndexedRead} eq 'N') {
        push @readnums_that_arent_indexes, $i->{Number};
      }
    }
    
    # If value stored in $factqc_readnum is 1, get lowest non-index read.
    # If it's 2, get highest non-index read.
    if ($fastqc_readnum == 1) {
      return min(@readnums_that_arent_indexes);
    }
    elsif ($fastqc_readnum == 2) {
      return max(@readnums_that_arent_indexes);
    }
    else {
      return "n.a";
    }
  }
  else {
    return $fastqc_readnum;
  }
}


sub parse_runinfo {
  # Run directory, by default, contains RunInfo.xml, which contains information on
  # the cycles that make up each read in a run, the number of lanes, the run ID and
  # flowcell ID, and a couple of other things that don't concern us here.
  # We particularly want the cycle numbers for each read.
		#$VAR1 = {
        #  'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
        #  'Version' => '2',
        #  'Run' => {
        #           'Id' => '140306_SN790_0320_BC3UE1ACXX',
        #           'Flowcell' => 'C3UE1ACXX',
        #           'Instrument' => 'SN790',
        #           'FlowcellLayout' => {
        #                               'LaneCount' => '8',
        #                               'SurfaceCount' => '2',
        #                               'SwathCount' => '3',
        #                               'TileCount' => '16'
        #                             },
        #           'Date' => '140306',
        #           'Reads' => {
        #                      'Read' => [
        #                                {
        #                                  'Number' => '1',
        #                                  'IsIndexedRead' => 'N',
        #                                  'NumCycles' => '101'
        #                                },
        #                                {
        #                                  'Number' => '2',
        #                                  'IsIndexedRead' => 'Y',
        #                                  'NumCycles' => '7'
        #                                },
        #                                {
        #                                  'Number' => '3',
        #                                  'IsIndexedRead' => 'N',
        #                                  'NumCycles' => '101'
        #                                }
        #                              ]
        #                    },
        #           'Number' => '320',
        #           'AlignToPhiX' => {
        #                            'Lane' => [
        #                                      '1',
        #                                      '2',
        #                                      '3',
        #                                      '4',
        #                                      '5',
        #                                      '6',
        #                                      '7',
        #                                      '8'
        #                                    ]
        #                          }
        #         },
        #  'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema'
        #};

  
  my $run_dir = $_[0];
  my $xml = new XML::Simple;
  my $runinfo = $xml->XMLin("$run_dir/RunInfo.xml");
  #print Dumper($runinfo);
#  my $rs = $runinfo->{Run}{Reads}{Read}[0]{NumCycles};
#  my $reads = $runinfo->{Run}{Reads}{Read};
#  foreach my $i (1..@$reads) {
#	print "READ $i\n";
#  }
  
  return $runinfo
}

sub run_start {
  # Start date of a run
  # Get earliest modified Log_00.txt file in RTALogs, and get earliest
  # date from it. (i.e., the first line)
  # This counts a run as begun when the machine is set off for the first time,
  # even if the run is halted and restarted at a later time. 
  
  # TODO: replace all instances of ls with find. It's the way to go, apparently.
  
  my $run_dir = $_[0];
  
  # Find appropriate log file
  my $file = `ls -tr $run_dir/Data/RTALogs/*Log_00.txt | head -n 1`;
  
  # If file not found, throw an error
  if (!$file) {
    return "WARN: Startup log file not found\n";
  }
  
  # Get the relevant line of that file
  my $date = `grep "Start up of Illumina RTA" $file`;
  
  # Parse out the timestamp
  $date = parse_log_date($date);
  
  return $date;
}

sub run_end {
  # End date of a run
  # This is more explicitly stated than the start point of a run - it's
  # recorded in its own log file (Basecalling_Netcopy_complete.txt).
  # Getting the run date is simply a matter of parsing that file.
  
  my $run_dir = $_[0];
  
  # Find appropriate log file
  my $file = "$run_dir/Basecalling_Netcopy_complete.txt";
  
  # If file not found, throw an error
  if (!$file) {
    return "WARN: Run end log file $file not found\n";
  }
  
  # Get the relevant line of that file
  my $date = `cat $file`;
  
  # Parse out the timestamp
  $date = parse_log_date($date);
  
  return $date;
}

sub read_start {
  # Start date of a read
  # Get earliest modified Log_00.txt file in RTALogs, and get earliest
  # date from it. (i.e., the first line)
  # This counts a run as begun when the machine is set off for the first time,
  # even if the run is halted and restarted at a later time. 
  
  my $run_dir = $_[0];
  my $read    = $_[1];
  
  # Find appropriate log file
  # This is slightly more involved than getting the run start log.
  # It looks like there are a pair of numbers at the start of each log - looks
  # like a process ID. I want the most recent one for that read.
  # Unfortunately the log files themselves aren't directly labeled with the
  # read ID, so I have to pick the process ID based on the filenames of all the
  # other logs in RTALogs. 
  
  # If no read number is supplied (e.g., single-end read), use run start
  if ((!$read) || ($read !~ /^[0-9]+$/)) {
    my $date = run_start($run_dir);
    return $date;
  }
  else {
    # List all PIDs for a read
    my $pid = `ls -tr $run_dir/Data/RTALogs/ | grep "Read$read" | sed 's/_.*//g' | uniq`;
    chomp $pid;
    $pid =~ s/\n/\|/g;
    
    # Get the most recently modified file from the relevant logs with those PIDs
    my $file = `ls -t $run_dir/Data/RTALogs/*Log_00.txt | awk '/$pid/ { print }' | head -n 1`;
    
    # If file not found, throw an error
    if (!$file) {
      return "WARN: Startup log file not found\n";
    }
    
    # Get the relevant line of that file
    my $date = `grep "Start up of Illumina RTA" $file`;
    
    # Parse out the timestamp
    $date = parse_log_date($date);
    
    return $date;
  }
}

sub read_end {
  # End date of a read
  # This is more explicitly stated than the start point of a read - it's
  # recorded in its own log file (Basecalling_Netcopy_complete_Read[x].txt).
  # Getting the run date is simply a matter of parsing that file.
  
  my $run_dir = $_[0];
  my $read    = $_[1];
  
  # If no read number is supplied (e.g., single-end read), use run start
  if ((!$read) || ($read !~ /^[0-9]+$/)) {
    my $date = run_end($run_dir);
    return $date;
  }
  else {
    # Find appropriate log file
    my $file = "$run_dir/Basecalling_Netcopy_complete_Read$read.txt";
    
    # If file not found, throw an error
    if (!$file) {
      return "WARN: Startup log file not found\n";
    }
    
    # Get the relevant line of that file
    my $date = `cat $file`;
    
    # Parse out the timestamp
    $date = parse_log_date($date);
    
    return $date;
  }
}






1;