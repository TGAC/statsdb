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

}

sub get_average_values() {
  my $self = shift;
  my %properties = shift; 

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

}

sub get_summary_values_with_comments() {

}

sub get_summary_values() {

}

sub get_result_table_from_stored_procedure() {

}

sub get_analysis_properties() {

}

sub get_values_for_property() {

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

sub list_all_runs {
  my $self = shift;

  my $con = $self->get_connection();
  my $statement = "SELECT run FROM run GROUP BY run";
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->execute();

  return Reports::ReportTable->new($sth);
}

sub list_lanes_for_run() {

}

sub list_barcodes_for_run_and_lane() {

}

sub get_samples_from_run_lane_barcode() {

}

sub result_set_to_array() {

}

1;
