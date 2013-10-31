package Reports::DB;
use DBI;
use IO::File;
use strict;

=head3 Reports::DB->new()
        
Constructor method. This constuctor doesn't actually establishes the connection.

=cut

sub new {
  my $class = shift;
  my $config_file=shift;

  my $self = {"connection" => undef ,
              "db_user" => undef,
              "db_password" => undef ,
              "db_string" => undef };

  bless $self, $class;
  $self->parse_details($config_file);

  return $self;
}

sub parse_details(){
        my $self = shift;
        my $config_file = shift;
        my $config_fh = new IO::File( $config_file , "r" ) or die $!;
        while(my $line = $config_fh->getline()){
                chomp $line;
                if($line =~ /(\S+)\s+(\S*)/){
                        $self->{$1} = $2;
                }
        }
}


=head3 $db->connect("config.txt")

Method that establishes a connection to the database. To connect to the database, a configuration file is 
required. It consist of a tab separated file with the following attributes:

=head4 db_config.txt

                db_string       dbi:mysql:database;host=host
                db_user user
                db_password     password

=cut

sub connect(){
        my $self = shift;
        $self->{connection} = DBI->connect($self->{db_string},$self->{db_user},$self->{db_password}) ||
         die "Database connection not made: $DBI::errstr";
        print "Connected\n";
}


=head3 $db->disconnect()

Method that closes the connection to the database. 

=cut

sub disconnect(){
        my $self = shift;
        print "Disconnecting\n";
        $self->{connection}->disconnect() or warn "Unable to disconnect $DBI::errstr\n"; 
}

1;
