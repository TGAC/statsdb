package Reports;
use strict;

use Reports::ReportTable;

use constant {
  ENCODING => "encoding",
  CASAVA_VERSION => "casava_version",
  CHEMISTRY => "chemistry",
  INSTRUMENT => "instrument",
  SOFTWARE_ON_INSTRUMENT => "softwareOnInstrument",
  TYPE_OF_EXPERIMENT => "typeOfExperiment",
  PAIR => "pair",
  SAMPLE_NAME => "sampleName",
  LANE => "lane",
  BARCODE => "barcode",
  RUN => "run"
};

sub new {
  my $class = shift;
  my $db = shift;
  my $self = {"dbh" => $db};
  bless $self, $class;
  return $self;
}

sub get_connection() {
  my $self = shift;

  my $dbh = $self->{dbh};
  $dbh->connect();
  return $dbh->{connection};
}

sub list_global_analyses() {
  my $self = shift;
  my $con = $self->get_connection();
  
  my $statement = "CALL list_summary_per_scope(?)";
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->execute("analysis");

  return Reports::ReportTable->new($sth);
}

sub list_per_base_summary_analyses() {
  my $self = shift;
  my $con = $self->get_connection();

  my $statement = "CALL list_summary_per_scope(?)";
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->execute("base_partition");

  return Reports::ReportTable->new($sth);
}

sub get_per_position_summary() {
  my $self = shift;
  my $analysis = shift;
  my $analysis_property = shift;
  my $analysis_property_value = shift;

  my $con = $self->get_connection();
  my $statement = "CALL summary_per_position(?,?,?)";
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->execute($analysis, $analysis_property, $analysis_property_value);

  return Reports::ReportTable->new($sth);
}

sub get_average_value() {
  my $self = shift;
  my $analysis = shift;
  my $analysis_property = shift;
  my $analysis_property_value = shift;

  my $con = $self->get_connection();
  my $statement = "CALL general_summary(?,?,?)";
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->execute($analysis, $analysis_property, $analysis_property_value);

  return Reports::ReportTable->new($sth);
}

sub get_average_values() {
  my $self = shift;
  my $pref = shift;
  my %properties = %$pref; 

  my @args = (undef, undef, undef, undef, undef);
  $args[0] = $properties{INSTRUMENT} if exists $properties{INSTRUMENT};
  $args[1] = $properties{RUN} if exists $properties{RUN};
  $args[2] = $properties{LANE} if exists $properties{LANE};
  $args[3] = $properties{PAIR} if exists $properties{PAIR};
  $args[4] = $properties{BARCODE} if exists $properties{BARCODE};
  
  my $statement = "CALL general_summaries_for_run(?,?,?,?,?)";
  my $con = $self->get_connection();
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->bind_param(1, $args[0]);
  $sth->bind_param(2, $args[1]);
  $sth->bind_param(3, $args[2]);
  $sth->bind_param(4, $args[3]);
  $sth->bind_param(5, $args[4]);
  
  $sth->execute();
  
  return Reports::ReportTable->new($sth);
}

sub get_per_position_values() {
  my $self = shift;
  my $analysis = shift;
  my $pref = shift;
  my %properties = %$pref; 
  
  my @args = (undef, undef, undef, undef, undef, undef);
  $args[0] = $analysis;
  $args[1] = $properties{INSTRUMENT} if exists $properties{INSTRUMENT};
  $args[2] = $properties{RUN} if exists $properties{RUN};
  $args[3] = $properties{LANE} if exists $properties{LANE};
  $args[4] = $properties{PAIR} if exists $properties{PAIR};
  $args[5] = $properties{BARCODE} if exists $properties{BARCODE};

  my $statement = "CALL summary_per_position_for_run(?,?,?,?,?,?)";
  my $con = $self->get_connection();
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->bind_param(1, $args[0]);
  $sth->bind_param(2, $args[1]);
  $sth->bind_param(3, $args[2]);
  $sth->bind_param(4, $args[3]);
  $sth->bind_param(5, $args[4]);
  $sth->bind_param(6, $args[5]);

  $sth->execute();

  return Reports::ReportTable->new($sth);
}

sub get_summary_values_with_comments() {
  my $self = shift;
  my $scope = shift;
  my $pref = shift;
  my %properties = %$pref; 

  my @args = (undef, undef, undef, undef, undef, undef);
  $args[0] = $scope;
  $args[1] = $properties{INSTRUMENT} if exists $properties{INSTRUMENT};
  $args[2] = $properties{RUN} if exists $properties{RUN};
  $args[3] = $properties{LANE} if exists $properties{LANE};
  $args[4] = $properties{PAIR} if exists $properties{PAIR};
  $args[5] = $properties{BARCODE} if exists $properties{BARCODE};

  my $statement = "CALL summary_value_with_comment(?,?,?,?,?,?)";
  my $con = $self->get_connection();
  
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->bind_param(1, $args[0]);
  $sth->bind_param(2, $args[1]);
  $sth->bind_param(3, $args[2]);
  $sth->bind_param(4, $args[3]);
  $sth->bind_param(5, $args[4]);
  $sth->bind_param(6, $args[5]);

  $sth->execute();

  return Reports::ReportTable->new($sth);
}

sub get_summary_values() {
  my $self = shift;
  my $scope = shift;
  my $pref = shift;
  my %properties = %$pref; 

  my @args = (undef, undef, undef, undef, undef, undef);
  $args[0] = $scope;
  $args[1] = $properties{INSTRUMENT} if exists $properties{INSTRUMENT};
  $args[2] = $properties{RUN} if exists $properties{RUN};
  $args[3] = $properties{LANE} if exists $properties{LANE};
  $args[4] = $properties{PAIR} if exists $properties{PAIR};
  $args[5] = $properties{BARCODE} if exists $properties{BARCODE};

  my $statement = "CALL summary_value(?,?,?,?,?,?)";
  my $con = $self->get_connection();
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->bind_param(1, $args[0]);
  $sth->bind_param(2, $args[1]);
  $sth->bind_param(3, $args[2]);
  $sth->bind_param(4, $args[3]);
  $sth->bind_param(5, $args[4]);
  $sth->bind_param(6, $args[5]);

  $sth->execute();

  return Reports::ReportTable->new($sth);
}

sub get_analysis_properties() {
  my $self = shift;
  my $con = $self->get_connection();

  my $statement = "CALL list_selectable_properties()";
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->execute();

  return Reports::ReportTable->new($sth);
}

sub get_values_for_property() {
  my $self = shift;
  my $property = shift;
  my $con = $self->get_connection();

  my $statement = "CALL list_selectable_values_from_property(?)";
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->execute($property);

  return Reports::ReportTable->new($sth);
}

sub list_all_runs_for_instrument() {
  my $self = shift;
  my $instrument = shift;

  my $con = $self->get_connection();
  my $statement = "SELECT run FROM run WHERE `instrument` = ? GROUP BY run";
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->execute($instrument);

  return Reports::ReportTable->new($sth);
}

sub list_all_instruments {
  my $self = shift;

  my $con = $self->get_connection();
  my $statement = "SELECT instrument FROM run GROUP BY instrument";
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->execute();

  return Reports::ReportTable->new($sth);
}

sub list_all_runs {
  my $self = shift;

  my $con = $self->get_connection();
  my $statement = "SELECT run FROM run GROUP BY run";
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->execute();

  return Reports::ReportTable->new($sth);
}

sub list_lanes_for_run() {
  my $self = shift;
  my $run = shift;

  my $con = $self->get_connection();
  my $statement = "SELECT lane FROM run WHERE `run` = ? GROUP BY lane";
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->execute($run);
  
  return Reports::ReportTable->new($sth);
}

sub get_timestamp_for_run() {
  # Retrieves the timestamp assigned to each run's insertion into the database.
  my $self = shift;
  my $run = shift;

  my $con = $self->get_connection();
  my $statement = "SELECT analysisDate FROM analysis, run
    WHERE `run.run` = ?
    AND analysis.id = run.analysis_id
    GROUP BY analysisDate;";
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->execute($run);

  return Reports::ReportTable->new($sth);
}

sub get_runs_between_dates() {
  # Retrieves runs that were inserted into the database between two given timepoints
  # Note that since the actual time of the analysis is recorded, this data will change
  # if the database is repopulated.
  
  my $self = shift;
  my $date1 = shift;
  my $date2 = shift;

  my $con = $self->get_connection();
  my $statement = "CALL select_runs_between_dates(?, ?)";
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->execute($date1, $date2);

  return Reports::ReportTable->new($sth);
}

sub list_subdivisions() {
  # Assemble a query to get all the available runs, lanes on a run etc. when passed
  # a given set of information. Generalist by design.
  # Get inputs via a hash. Assemble query internally.
  my $self = shift;
  my $pref = shift;
  my %properties = %$pref; 
  
  my @args = (undef, undef, undef, undef, undef, undef, undef);
  $args[0] = $properties{INSTRUMENT} if exists $properties{INSTRUMENT};
  $args[1] = $properties{RUN} if exists $properties{RUN};
  $args[2] = $properties{LANE} if exists $properties{LANE};
  $args[3] = $properties{PAIR} if exists $properties{PAIR};
  $args[4] = $properties{SAMPLE_NAME} if exists $properties{SAMPLE_NAME};
  $args[5] = $properties{BARCODE} if exists $properties{BARCODE};
  $args[6] = $properties{QSCOPE} if exists $properties{QSCOPE};
  
  # Add bits to the statement to reflect available information
  # GROUP BY column supplied as queryscope (plus higher-level scopes)
  
  my @available_columns = ('instrument','run','lane','sample_name','barcode','pair');
  my @retrieve_these = ();
  my $col = ();
  if ($args[6]) {
    do {
      $col = shift @available_columns;
      push @retrieve_these, $col;
    }
    until (($col eq $args[6]) || (@available_columns == 0));
    
    # Ensure that if 'sample_name' is in @available_columns,
    # 'barcode' is as well
    # (vice versa ensured by @available_columns order!)
    my $jn = join ' ', @retrieve_these;
    if (($jn =~ /sample_name/) && ($jn !~ /barcode/)) {
      push @retrieve_these, "barcode";
    }
  }
  else {
    if ($args[0]) { push @retrieve_these, 'instrument'; }
    if ($args[1]) { push @retrieve_these, 'run'; }
    if ($args[2]) { push @retrieve_these, 'lane'; }
    if ($args[4] || $args[5]) {
      push @retrieve_these, 'sample_name';
      push @retrieve_these, 'barcode';
    }
    if ($args[3]) { push @retrieve_these, 'pair'; }
  }
  $col = join ',', @retrieve_these;
  
  my @where_components = ();
  my @query_values = ();
  if ($args[0]) { push @where_components, 'instrument = ? ';  push @query_values, $args[0]; }
  if ($args[1]) { push @where_components, 'run = ? ';         push @query_values, $args[1]; }
  if ($args[2]) { push @where_components, 'lane = ? ';        push @query_values, $args[2]; }
  if ($args[4]) { push @where_components, 'sample_name = ? '; push @query_values, $args[4]; }
  if ($args[5]) { push @where_components, 'barcode = ? ';     push @query_values, $args[5]; }
  if ($args[3]) { push @where_components, 'pair = ? ';        push @query_values, $args[3]; }
  
  my $statement = "SELECT $col FROM run ";
  if (@where_components) {
    my $where_string = join 'AND ', @where_components;
    $where_string = "WHERE $where_string";
    $statement = $statement.$where_string;
  }
  $statement = $statement."GROUP BY $col ORDER BY $col";
  
  my $con = $self->get_connection();
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->execute(@query_values);
  
  return Reports::ReportTable->new($sth);
}

sub list_barcodes_for_run_and_lane() {
  my $self = shift;
  my $run = shift;
  my $lane = shift;

  my $con = $self->get_connection();
  my $statement = "SELECT barcode FROM run WHERE `run` = ? AND `lane` = ? GROUP BY barcode";
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->execute($run, $lane);

  return Reports::ReportTable->new($sth);
}

sub get_samples_from_run_lane_barcode() {
  my $self = shift;
  my $run = shift;
  my $lane = shift;
  my $barcode = shift;

  my $con = $self->get_connection();
  my $statement = "SELECT sample_name FROM run WHERE `run` = ? AND `lane` = ? AND `barcode` = ?";
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->execute($run, $lane, $barcode);

  return Reports::ReportTable->new($sth);
}

sub get_encoding_for_run() {
  my $self = shift;
  my $run = shift;

  my $con = $self->get_connection();
  my $statement = "SELECT encoding FROM run WHERE `run` = ? AND encoding IS NOT NULL GROUP BY encoding";
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->execute($run);

  return Reports::ReportTable->new($sth);
}

sub get_analysis_id() {
  my $self = shift;
  my $pref = shift;
  my %properties = %$pref; 
  
  my @args = (undef, undef, undef, undef, undef, undef);
  $args[0] = $properties{INSTRUMENT} if exists $properties{INSTRUMENT};
  $args[1] = $properties{RUN} if exists $properties{RUN};
  $args[2] = $properties{LANE} if exists $properties{LANE};
  $args[3] = $properties{PAIR} if exists $properties{PAIR};
  $args[4] = $properties{SAMPLE} if exists $properties{SAMPLE};
  $args[5] = $properties{BARCODE} if exists $properties{BARCODE};
  
  my @query_values = ();
  my @where_components = ();
  if ($args[0]) { push @where_components, 'instrument = ? ';  push @query_values, $args[0]; }
  if ($args[1]) { push @where_components, 'run = ? ';         push @query_values, $args[1]; }
  if ($args[2]) { push @where_components, 'lane = ? ';        push @query_values, $args[2]; }
  if ($args[4]) { push @where_components, 'sample_name = ? '; push @query_values, $args[4]; }
  if ($args[5]) { push @where_components, 'barcode = ? ';     push @query_values, $args[5]; }
  if ($args[3]) { push @where_components, 'pair = ? ';        push @query_values, $args[3]; }
  
  my $statement = "SELECT analysis_id FROM run WHERE ";
  if (@where_components) {
    my $where_string = join 'AND ', @where_components;
    $statement = $statement.$where_string;
  }
  $statement = $statement."GROUP BY analysis_id";
  
  my $con = $self->get_connection();
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->execute(@query_values);
  
  return Reports::ReportTable->new($sth);
}

sub get_properties_for_analysis_ids() {
  my $self = shift;
  my $idref = shift;
  my @args = @$idref; 
  
  # Add bits to the statement to reflect available information
  my $statement = "SELECT property, value FROM analysis_property ";
  my @where_components = ();
  foreach (1..@args) {
    push @where_components, "analysis_id = ? ";
  }
  
  if (@where_components) {
    my $where_string = join 'OR ', @where_components;
    $where_string = "WHERE $where_string";
    $statement = $statement.$where_string;
  }
  $statement = $statement."GROUP BY property, value ORDER BY property, value";
  
  my $con = $self->get_connection();
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->execute(@args);
  
  return Reports::ReportTable->new($sth);
}


# These two take care of barcode/sample name interchange.
# Note that sample names are (or should be) unique, so no further
# information need be supplied; barcodes, however, are not, so
# run ID should also be passed.
sub get_barcodes_for_sample_name() {
  my $self = shift;
  my $sample = shift;

  my $con = $self->get_connection();
  my $statement = "SELECT barcode FROM run WHERE `sample_name` = ? GROUP BY barcode";
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->execute($sample);

  return Reports::ReportTable->new($sth);
}

sub get_sample_name_for_barcode() {
  my $self = shift;
  my $run = shift;
  my $sample = shift;

  my $con = $self->get_connection();
  my $statement = "SELECT barcode FROM run WHERE `run` = ? AND `sample_name` = ? GROUP BY barcode";
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->execute($run, $sample);

  return Reports::ReportTable->new($sth);
}


1;
