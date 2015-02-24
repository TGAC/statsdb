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
  # List the types of summary values in the 'analysis' scope - max run length,
  # number of sequences, overall GC content etc.
  my $self = shift;
  my $con = $self->get_connection();
  
  my $statement = "CALL list_summary_per_scope(?)";
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->execute("analysis");

  return Reports::ReportTable->new($sth);
}

sub set_duplicate_selection_type() {
  my $self = shift;
  my $pref = shift;
  
  my @args = (undef);
  $args[0] = $pref->{DUPLICATE_TYPE} if exists $pref->{DUPLICATE_TYPE};
  
  my $statement = "CALL set_duplicate_selection_type(?)";
  my $con = $self->get_connection();
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->bind_param(1, $args[0]);
  
  $sth->execute();

  return Reports::ReportTable->new($sth);
}

sub detect_duplicates() {
  # Runs a stored procedure that detects duplicate records matching input parameters
  # in the database
  # (old, new or all; specified by set_duplicate_detection_type)
  my $self = shift;
  my $pref = shift;
  
  my @args = (undef, undef, undef, undef, undef, undef, undef);
  $args[0] = $pref->{INSTRUMENT} if exists $pref->{INSTRUMENT};
  $args[1] = $pref->{RUN} if exists $pref->{RUN};
  $args[2] = $pref->{LANE} if exists $pref->{LANE};
  $args[3] = $pref->{PAIR} if exists $pref->{PAIR};
  $args[4] = $pref->{SAMPLE_NAME} if exists $pref->{SAMPLE_NAME};
  $args[5] = $pref->{BARCODE} if exists $pref->{BARCODE};
  $args[6] = $pref->{TOOL} if exists $pref->{TOOL};
  
  my $statement = "CALL detect_duplicates(?,?,?,?,?,?,?)";
  my $con = $self->get_connection();
  my $sth = $con->prepare($statement) || die $con->errstr;
  foreach my $i (1..7) {
    $sth->bind_param($i, $args[$i-1]);
  }
  
  $sth->execute();

  return Reports::ReportTable->new($sth);
}

sub list_per_base_summary_analyses() {
  # List the types of values in the base_partition scope, in which a result value
  # is supplied for a range of determinant values. Mean and quartiles for quality
  # measurements, percent GC, content of individual bases.
  my $self = shift;
  my $con = $self->get_connection();

  my $statement = "CALL list_summary_per_scope(?)";
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->execute("base_partition");

  return Reports::ReportTable->new($sth);
}

sub get_per_position_summary() {
  # Get averaged per-position (e.g., per base) values for a given partition and
  # data type
  my $self = shift;
  my $analysis = shift;
  my $analysis_property = shift;
  my $analysis_property_value = shift;
  
  my $con = $self->get_connection();
  my $statement = "CALL summary_per_position(?,?,?)";
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->bind_param(1, $analysis);
  $sth->bind_param(2, $analysis_property);
  $sth->bind_param(3, $analysis_property_value);
  
  $sth->execute();
  
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
  $sth->bind_param(1, $analysis);
  $sth->bind_param(2, $analysis_property);
  $sth->bind_param(3, $analysis_property_value);
  
  $sth->execute();

  return Reports::ReportTable->new($sth);
}

sub get_average_values() {
  # Returns a list of averaged summary values across a given combination of
  # instrument, run, lane, pair and barcode
  my $self = shift;
  my $pref = shift;

  my @args = (undef, undef, undef, undef, undef, undef);
  $args[0] = $pref->{INSTRUMENT} if exists $pref->{INSTRUMENT};
  $args[1] = $pref->{RUN} if exists $pref->{RUN};
  $args[2] = $pref->{LANE} if exists $pref->{LANE};
  $args[3] = $pref->{PAIR} if exists $pref->{PAIR};
  $args[4] = $pref->{SAMPLE_NAME} if exists $pref->{SAMPLE_NAME};
  $args[5] = $pref->{BARCODE} if exists $pref->{BARCODE};
  
  my $statement = "CALL general_summaries_for_run(?,?,?,?,?,?)";
  my $con = $self->get_connection();
  my $sth = $con->prepare($statement) || die $con->errstr;
  foreach my $i (1..6) {
    $sth->bind_param($i, $args[$i-1]);
  }
  
  $sth->execute();
  
  return Reports::ReportTable->new($sth);
}

sub get_per_position_values() {
  my $self = shift;
  my $analysis = shift;
  my $pref = shift;
  
  my @args = (undef, undef, undef, undef, undef, undef, undef, undef);
  $args[0] = $analysis;
  $args[1] = $pref->{INSTRUMENT} if exists $pref->{INSTRUMENT};
  $args[2] = $pref->{RUN} if exists $pref->{RUN};
  $args[3] = $pref->{LANE} if exists $pref->{LANE};
  $args[4] = $pref->{PAIR} if exists $pref->{PAIR};
  $args[5] = $pref->{SAMPLE_NAME} if exists $pref->{SAMPLE_NAME};
  $args[6] = $pref->{BARCODE} if exists $pref->{BARCODE};
  $args[7] = $pref->{TOOL} if exists $pref->{TOOL};
  
  my $statement = "CALL summary_per_position_for_run(?,?,?,?,?,?,?,?)";
  my $con = $self->get_connection();
  my $sth = $con->prepare($statement) || die $con->errstr;
  foreach my $i (1..8) {
    $sth->bind_param($i, $args[$i-1]);
  }
  
  $sth->execute();

  return Reports::ReportTable->new($sth);
}

sub get_summary_values_with_comments() {
  # Get summary values with additional information stored as linked comments
  # across any combination of instrument, run, lane, pair and barcode
  my $self = shift;
  my $scope = shift;
  my $pref = shift;

  my @args = (undef, undef, undef, undef, undef, undef, undef);
  $args[0] = $scope;
  $args[1] = $pref->{INSTRUMENT} if exists $pref->{INSTRUMENT};
  $args[2] = $pref->{RUN} if exists $pref->{RUN};
  $args[3] = $pref->{LANE} if exists $pref->{LANE};
  $args[4] = $pref->{PAIR} if exists $pref->{PAIR};
  $args[5] = $pref->{SAMPLE_NAME} if exists $pref->{SAMPLE_NAME};
  $args[6] = $pref->{BARCODE} if exists $pref->{BARCODE};
  
  my $statement = "CALL summary_value_with_comment(?,?,?,?,?,?,?)";
  my $con = $self->get_connection();
  
  my $sth = $con->prepare($statement) || die $con->errstr;
  foreach my $i (1..7) {
    $sth->bind_param($i, $args[$i-1]);
  }
  
  $sth->execute();

  return Reports::ReportTable->new($sth);
}

sub get_summary_values() {
  # Get averaged summary values across any combination of instrument, run,
  # lane, pair and barcode
  my $self = shift;
  my $scope = shift;
  my $pref = shift;

  my @args = (undef, undef, undef, undef, undef, undef, undef);
  $args[0] = $scope;
  $args[1] = $pref->{INSTRUMENT} if exists $pref->{INSTRUMENT};
  $args[2] = $pref->{RUN} if exists $pref->{RUN};
  $args[3] = $pref->{LANE} if exists $pref->{LANE};
  $args[4] = $pref->{PAIR} if exists $pref->{PAIR};
  $args[5] = $pref->{SAMPLE_NAME} if exists $pref->{SAMPLE_NAME};
  $args[6] = $pref->{BARCODE} if exists $pref->{BARCODE};
  
  my $statement = "CALL summary_value(?,?,?,?,?,?,?)";
  my $con = $self->get_connection();
  my $sth = $con->prepare($statement) || die $con->errstr;
  foreach my $i (1..7) {
    $sth->bind_param($i, $args[$i-1]);
  }
  
  $sth->execute();

  return Reports::ReportTable->new($sth);
}

sub list_contaminants () {
  # Returns a list of contaminants that were screened against for a given set of inputs
  # (instrument, run and lane)
  my $self = shift;
  my $pref = shift;

  my @args = (undef, undef, undef);
  $args[0] = $pref->{INSTRUMENT} if exists $pref->{INSTRUMENT};
  $args[1] = $pref->{RUN} if exists $pref->{RUN};
  $args[2] = $pref->{LANE} if exists $pref->{LANE};
  
  my $statement = "CALL list_contaminants(?,?,?)";
  my $con = $self->get_connection();
  my $sth = $con->prepare($statement) || die $con->errstr;
  foreach my $i (1..3) {
    $sth->bind_param($i, $args[$i-1]);
  }
  
  $sth->execute();
  
  return Reports::ReportTable->new($sth);
}

sub contaminant_summary () {
  # Returns a set of screening statistics for a set of instrument, run and lane
  # analyses and a reference genome screened against. 
  my $self = shift;
  my $reference = shift;
  my $pref = shift;

  my @args = (undef, undef, undef);
  $args[0] = $reference;
  $args[1] = $pref->{INSTRUMENT} if exists $pref->{INSTRUMENT};
  $args[2] = $pref->{RUN} if exists $pref->{RUN};
  $args[3] = $pref->{LANE} if exists $pref->{LANE};
  
  my $statement = "CALL contaminant_summary(?,?,?,?)";
  my $con = $self->get_connection();
  my $sth = $con->prepare($statement) || die $con->errstr;
  foreach my $i (1..4) {
    $sth->bind_param($i, $args[$i-1]);
  }
  
  $sth->execute();
  
  return Reports::ReportTable->new($sth);
}


sub get_analysis_properties() {
  # Get a list of all the different properties that are available for all
  # analyses.
  my $self = shift;
  my $con = $self->get_connection();

  my $statement = "CALL list_selectable_properties()";
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->execute();

  return Reports::ReportTable->new($sth);
}

sub get_values_for_property() {
  # Given an analysis property, this lists all selectable values associated
  # with it.
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
  
  my $statement = "CALL list_runs_for_instrument(?)";
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->execute($instrument);

  return Reports::ReportTable->new($sth);
}

sub list_all_instruments {
  # This sub uses a stored procedure that returns the instrument ID
  # for any given combination of instrument, run, lane, pair, sample name and
  # barcode. Those are all left undef here, though, so this returns a list of
  # all instruments.
  my $self = shift;
  
  my $con = $self->get_connection();
  #my $statement = "SELECT instrument FROM run GROUP BY instrument";
  # NOTE: NOT sure what happens, yet, when I leave these parameters unset.
  # Try it.
  my $statement = "CALL list_instruments (?,?,?,?,?,?)";
  my $sth = $con->prepare($statement) || die $con->errstr;
  foreach my $i (1..6) {
    $sth->bind_param($i, undef);
  }
  $sth->execute();
  
  return Reports::ReportTable->new($sth);
}

sub list_all_runs {
  # This sub uses a stored procedure that returns the run ID
  # for any given combination of instrument, run, lane, pair, sample name and
  # barcode. Those are all left undef here, though, so this returns a list of
  # all runs.
  my $self = shift;
  
  my $con = $self->get_connection();
  #my $statement = "SELECT run FROM run GROUP BY run";
  my $statement = "CALL list_instruments (?,?,?,?,?,?)";
  my $sth = $con->prepare($statement) || die $con->errstr;
  foreach my $i (1..6) {
    $sth->bind_param($i, undef);
  }
  $sth->execute();
  
  return Reports::ReportTable->new($sth);
}

sub get_runs_between_dates() {
  # Retrieves runs that were inserted into the database between two given timepoints
  # Note that since the actual time of the analysis is recorded, this data will change
  # if the database is repopulated.
  
  my $self = shift;
  my $pref = shift;
  
  my @args = (undef, undef, undef);
  $args[0] = $pref->{BEGIN} if exists $pref->{BEGIN};
  $args[1] = $pref->{END} if exists $pref->{END};
  $args[2] = $pref->{DATETYPE} if exists $pref->{DATETYPE};
  
  my $con = $self->get_connection();
  my $statement = "CALL select_runs_between_dates(?,?,?)";
  
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->bind_param(1, $args[0]);
  $sth->bind_param(2, $args[1]);
  $sth->bind_param(3, $args[2]);
  
  $sth->execute();

  return Reports::ReportTable->new($sth);
}

sub get_operation_overview() {
  # Retrieves runs that were inserted into the database between two given timepoints
  # Note that since the actual time of the analysis is recorded, this data will change
  # if the database is repopulated.
  
  my $self = shift;
  my $pref = shift;
  
  my @args = (undef, undef, undef);
  $args[0] = $pref->{BEGIN} if exists $pref->{BEGIN};
  $args[1] = $pref->{END} if exists $pref->{END};
  
  my $con = $self->get_connection();
  my $statement = "CALL operation_overview(?,?)";
  
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->bind_param(1, $args[0]);
  $sth->bind_param(2, $args[1]);
  
  $sth->execute();

  return Reports::ReportTable->new($sth);
}

sub get_library_type_for_run() {
  # Get library type - i.e., baired-end, RNAseq etc., for a given run
  my $self = shift;
  my $pref = shift;

  my @args = (undef);
  $args[0] = $pref->{RUN} if exists $pref->{RUN};
  
  my $statement = "CALL get_lib_type_for_run(?)";
  my $con = $self->get_connection();
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->bind_param(1, $args[0]);
  
  $sth->execute();

  return Reports::ReportTable->new($sth);
}

sub list_lanes_for_run() {
  # This uses a less generalist function than the previous two subs
  # to return the lanes in a run 
  my $self = shift;
  my $run = shift;
  
  my $con = $self->get_connection();
  #my $statement = "SELECT lane FROM run WHERE `run` = ? GROUP BY lane";
  my $statement = "CALL list_lanes_for_run (?)";
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->execute($run);
  
  return Reports::ReportTable->new($sth);
}

sub count_reads_for_run() {
  # This uses a less generalist function than the previous two subs
  # to return the lanes in a run 
  my $self = shift;
  my $run = shift;
  
  my $con = $self->get_connection();
  my $statement = "CALL count_reads_for_run(?)";
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->execute($run);
  
  return Reports::ReportTable->new($sth);
}

sub list_subdivisions() {
  # This is for assembling the query sets used by a consumer.
  # For example, a user may wish to set up a series of independent queries
  # for every sample in a run (as opposed to averaging all results in the run).
  # When supplied with inputs provided by the user, including a query scope,
  # this function returns the information required for each of those independent
  # queries as a single row.
  my $self = shift;
  my $pref = shift;
  
  my @args = (undef, undef, undef, undef,
              undef, undef, undef, undef,
              undef, undef, undef, undef);
  $args[0] = $pref->{INSTRUMENT} if exists $pref->{INSTRUMENT};
  $args[1] = $pref->{RUN} if exists $pref->{RUN};
  $args[2] = $pref->{LANE} if exists $pref->{LANE};
  $args[3] = $pref->{PAIR} if exists $pref->{PAIR};
  $args[4] = $pref->{SAMPLE_NAME} if exists $pref->{SAMPLE_NAME};
  $args[5] = $pref->{BARCODE} if exists $pref->{BARCODE};
  $args[6] = $pref->{ANALYSIS} if exists $pref->{ANALYSIS};
  $args[7] = $pref->{BEGIN} if exists $pref->{BEGIN};
  $args[8] = $pref->{END} if exists $pref->{END};
  $args[9] = $pref->{DATETYPE} if exists $pref->{DATETYPE};
  $args[10] = $pref->{TOOL} if exists $pref->{TOOL};
  $args[11] = $pref->{QSCOPE} if exists $pref->{QSCOPE};
  
  my $statement = "CALL list_subdivisions(?,?,?,?,?,?,?,?,?,?,?,?)";
  my $con = $self->get_connection();
  
  my $sth = $con->prepare($statement) || die $con->errstr;
  foreach my $i (1..12) {
    $sth->bind_param($i, $args[$i-1]);
  }
  
  $sth->execute();
  
  return Reports::ReportTable->new($sth);
}



# These three subs take care of barcode/sample name interchange.
# I.e., when you have one, you most likely want the other at some point too.
# Note that sample names are (or should be) unique, so no further
# information need be supplied; barcodes, however, are not, so
# run ID should also be passed.

sub list_barcodes_for_run_and_lane() {
  my $self = shift;
  my $run = shift;
  my $lane = shift;

  my $con = $self->get_connection();
  #my $statement = "SELECT barcode FROM run WHERE `run` = ? AND `lane` = ? GROUP BY barcode";
  my $statement = "CALL list_barcodes_for_run_and_lane (?,?)";
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->execute($run, $lane);

  return Reports::ReportTable->new($sth);
}

sub get_barcodes_for_sample_name() {
  my $self = shift;
  my $sample = shift;

  my $con = $self->get_connection();
  my $statement = "CALL list_barcodes_for_sample(?)";
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->execute($sample);

  return Reports::ReportTable->new($sth);
}

sub get_samples_from_run_lane_barcode() {
  my $self = shift;
  my $run = shift;
  my $lane = shift;
  my $barcode = shift;

  my $con = $self->get_connection();
  #my $statement = "SELECT sample_name FROM run WHERE `run` = ? AND `lane` = ? AND `barcode` = ?";
  my $statement = "CALL get_sample_from_run_lane_barcode (?,?,?)";
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->bind_param(1, $run);
  $sth->bind_param(2, $lane);
  $sth->bind_param(3, $barcode);
  $sth->execute();
  
  return Reports::ReportTable->new($sth);
}

sub get_encoding_for_run() {
  # Specifically retrieves the encoding property for a given run.
  my $self = shift;
  my $run = shift;
  
  my $con = $self->get_connection();
  #my $statement = "SELECT encoding FROM run WHERE `run` = ? AND encoding IS NOT NULL GROUP BY encoding";
  my $statement = "CALL get_encoding_for_run (?)";
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->execute($run);
  
  return Reports::ReportTable->new($sth);
}

sub get_analysis_id() {
  # Returns the unique numeric ID of a particular analysis
  # Note that if some inputs are not supplied, a list of analysis IDs
  # can be returned instead. 
  my $self = shift;
  my $pref = shift;
  
  my @args = (undef, undef, undef, undef, undef, undef);
  $args[0] = $pref->{INSTRUMENT} if exists $pref->{INSTRUMENT};
  $args[1] = $pref->{RUN} if exists $pref->{RUN};
  $args[2] = $pref->{LANE} if exists $pref->{LANE};
  $args[3] = $pref->{PAIR} if exists $pref->{PAIR};
  $args[4] = $pref->{SAMPLE_NAME} if exists $pref->{SAMPLE_NAME};
  $args[5] = $pref->{BARCODE} if exists $pref->{BARCODE};
  $args[6] = $pref->{TOOL} if exists $pref->{TOOL};
  
  my $statement = "CALL get_analysis_id(?,?,?,?,?,?,?)";
  
  my $con = $self->get_connection();
  my $sth = $con->prepare($statement) || die $con->errstr;
  foreach my $i (1..7) {
    $sth->bind_param($i, $args[$i-1]);
  }
  $sth->execute();
  
  return Reports::ReportTable->new($sth);
}

sub check_analysis_id() {
  # Checks if the numeric ID of a particular analysis is present in the
  # database.
  my $self = shift;
  my $pref = shift;
  
  my @args = (undef);
  $args[0] = $pref->{ANALYSIS} if exists $pref->{ANALYSIS};
  
  my $statement = "CALL analysis_id_check(?)";
  
  my $con = $self->get_connection();
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->bind_param(1, $args[0]);
  $sth->execute();
  
  return Reports::ReportTable->new($sth);
}

sub get_properties_for_analysis_ids() {
  # Retrieves all the properties associated with an analysis ID.
  # If given a list of analysis IDs, it will retrieve the properties for all of them.
  my $self = shift;
  my $idref = shift;
  my @analysis_ids = @$idref; 
  
  # Add bits to the statement to reflect available information
  
  my $statement = "SELECT property, value FROM analysis_property ";
  my @where_components = ();
  foreach my $i (1..@analysis_ids) {
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
  foreach my $i (1..@analysis_ids) {
    $sth->bind_param($i, $analysis_ids[$i-1]);
  }
  $sth->execute();
  
  return Reports::ReportTable->new($sth);
}


1;
