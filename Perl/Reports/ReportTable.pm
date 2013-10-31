package Reports::ReportTable;
use strict;

sub new {
  my $class = shift;
  my $sth = shift;

  my @headers = @{$sth->{NAME_uc}};
  my $table_ref = $sth->fetchrow_arrayref;

  my $self = {"headers" => \@headers, "table" => $table_ref};
  bless $self, $class;
  return $self;
}

sub to_csv() {
  my $self = shift;
  
  my $headers = join(",",@{$self->{headers}});
  my @foo = @{$self->{table}};
  
  my $out = $headers."\n";
  foreach my $r (@foo) { 
    my $rowstr = join(",", $r);
    $out .= $rowstr."\n";
  }
  return $out;
}

sub to_json {
  my $self = shift;
}

sub get_headers() {
  my $self = shift;
  return $self->{headers};
}

sub get_table() {
  my $self = shift;
  return $self->{table};
}

sub is_empty {
  my $self = shift;
  my @foo = @{$self->{table}};
  return (scalar @foo eq 0);
}

1;

