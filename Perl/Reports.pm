package Reports;
use strict;

use Reports::ReportTable;

sub new {
  my $class = shift;
  my $db = shift;
  my $self = {"dbh" => $db};
  bless $self, $class;
  return $self;
}

sub get_per_position_summary() {
  my $self = shift;
  my $analysis = shift;
  my $analysis_property = shift;
  my $analysis_property_value = shift;

  my $dbh = $self->{dbh};
  $dbh->connect();
  my $con = $dbh->{connection};
  
  my $statement = "{ call summary_per_position(?, ?, ?) }";
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->execute($analysis, $analysis_property, $analysis_property_value);

  return ReportTable->new($sth);
}

sub list_all_runs_for_instrument() {
  my $self = shift;
  my $instrument = shift;
  
  my $dbh = $self->{dbh};
  $dbh->connect();
  my $con = $dbh->{connection};

  my $statement = "SELECT run FROM run WHERE `instrument` = ? GROUP BY run";
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->execute($instrument);

  return ReportTable->new($sth);
}

sub list_all_runs {
  my $self = shift;
  my $dbh = $self->{dbh};
  $dbh->connect();
  my $con = $dbh->{connection};
  
  my $statement = "SELECT run FROM run GROUP BY run";
  my $sth = $con->prepare($statement) || die $con->errstr;
  $sth->execute();

  return Reports::ReportTable->new($sth);
}

1;
