package Reports::ReportTable;
use strict;

sub new {
  my $class = shift;
  my $sth = shift;
  
  my @headers = @{$sth->{NAME_uc}};
  #my $table_ref = $sth->fetchrow_arrayref;
  
  my @array;
  while (my $ref = $sth->fetchrow_arrayref()) {
    push @array,[@$ref];
  }
  
  my $self = {"headers" => \@headers, "table" => \@array};
  bless $self, $class;
  return $self;
}

sub to_csv() {
  my $self = shift;
  
  my $headers = join(",",@{$self->{headers}});
  my @foo = @{$self->{table}};
  
  my $out = $headers."\n";
  foreach my $r (@foo) {
    my $rowstr = ();
    # Switch off uninitialised variable warnings here; we know that the
    # database will occasionally return some, but that's OK in context.
    {
      no warnings 'uninitialized';
      $rowstr = join(",", @$r);
    }
    $out .= $rowstr."\n";
  }
  return $out;
}

sub to_json {
  my $self = shift;
  ##quote stuff
  my @h = map {qq|"$_"|} @{$self->{headers}};
  my $headers = "[".join(",",@h)."]";
  my @foo = @{$self->{table}};
  
  my $out = "[";
  my @intarr;
  push(@intarr,$headers);

  foreach my $r (@foo) {
    my @rs = map {qq|"$_"|} @$r;
    my $rowstr = "[".join(",", @rs)."]";
    push(@intarr,$rowstr);
  }
  $out .= join(",",@intarr)."]";

  return $out;
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

