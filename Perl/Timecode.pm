package Timecode;
use strict;

# This module is designed to handle the date- and timestamps passed
# to the consumer scripts when searching for data between given
# time-points.

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
  else { check_input_time_format($time) }
  
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

1;