#!/usr/bin/env perl
use strict;

use Getopt::Long;
use Reports::DB;
use Reports;

my %arguments = ();
my $opt_ret = GetOptions( \%arguments, 'db_config=s' );
print "DB configuration: ". $arguments{db_config}."\n";
my $config = $arguments{db_config};

my $db = Reports::DB->new($config);
my $reports = Reports->new($db);

my $runs = $reports->list_all_runs();
unless ($runs->is_empty) {
  my $csv = $runs->to_csv();
  print $csv;
}

