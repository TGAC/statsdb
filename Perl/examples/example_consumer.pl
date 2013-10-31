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

print "\n=== Listing global analyses ===\n";
my $analyses = $reports->list_global_analyses();
unless ($analyses->is_empty) {
  print $analyses->to_csv();
}
print "\n";

print "\n=== Getting average values ===\n";
my $average_values = $reports->get_average_values();
unless ($average_values->is_empty) {
  print $average_values->to_csv();
}
print "\n";

print "\n=== Listing runs ===\n";
my $runs = $reports->list_all_runs();
unless ($runs->is_empty) {
  print $runs->to_csv();
}
print "\n";

$db->disconnect();

