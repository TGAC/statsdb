package QCAnalysis::MISO;
use IO::File;
use JSON;
use strict;

=head3 Reports::DB->new()
        
Constructor method. This constuctor doesn't actually establishes the connection.

=cut

#my $self = ();

sub new {
  my $class = shift;
  my $config_file = shift;

  my $self = {"miso_string" => undef,
              "miso_user" => undef,
              "miso_api_key" => undef};

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

# Making a call to the MISO API is a two-step process:
# First, you submit the intended URL, with parameters via GET, to the
# signature generator thing.
# Then, you pass the signature, along with other parameters, to the thing
# that actually gives you your data back.

# Make distinction between local and glocal URLs -
# locals are missing $self->{miso_string} (e.g. http://miso.tgac.ac.uk) 
# globals have that

sub add_miso_data {
  # Designed to be the main entry point to the module.
  # Adding things to an analysis object is taken care of here.
  my $self = shift;
  my $analysis = shift;
  
  # Get relevant analysis parameters from object
  my $runID = $analysis->get_property("run");
  my $sampleID = $analysis->get_property("sample_name");
  
  # Get sampleRef (see comments on that sub for explanation)
  my $sampleRef = $self->get_sample_ref($runID,$sampleID);
  
  # $sampleRef and $sampleID contain all the library (LIB), library
  # dilution (LDI) and project (PRO) numbers we need to get pretty
  # much everything we could ever want out of MISO.
  my ($library,$library_dilution) = lib_ldi_from_sampleid($sampleID);
  my ($project) = pro_from_sampleref($sampleRef);
  
  $self->parse_library_info($analysis, $library);
  $self->parse_project_info($analysis, $project);
}

sub parse_library_info {
  # Takes analysis object and library ID
  # Puts relevant data into analysis object
  my $self = shift;
  my $analysis = shift;
  my $lib = shift;
  
  # $data is a multidimensional hash thing.
  my $data = $self->get_library_info($lib);
  
  # Most important - primary reason for writing this module, in fact -
  # get the library type (e.g., mRNA Seq etc)
  $analysis->add_property("library_type", $data->{libraryType}{description});
  $analysis->add_property("library_strategy", $data->{libraryStrategyType}{name});
  
  # Add selection type (pull-down, PCR, etc)
  $analysis->add_property("library_selection_type", $data->{librarySelectionType}{name});
  
  # Platform name
  $analysis->add_property("platform", $data->{platformName});
  
  # Add some QC data if it's available
  # These are numerical values, so add a value_type, and store
  # as values
  
  # Library QCs
  if ($data->{libraryQCs}) {
    foreach my $qc (@$data->{libraryQCs}) {
      my $name = $qc->{qcType}{name};
      my $result = $qc->{results};
      $analysis->add_valid_type($name.'_result',"analysis");
      $analysis->add_general_value($name.'_result', $result);
    }
  }
  
  # Sample QCs
  if ($data->{sample}{sampleQCs}) {
    foreach my $qc (@$data->{sample}{sampleQCs}) {
      my $name = $qc->{qcType}{name};
      my $result = $qc->{results};
      $analysis->add_valid_type($name.'_result',"analysis");
      $analysis->add_general_value($name.'_result', $result);
    }
  }
  
}

sub parse_project_info {
  # Takes analysis object and library ID
  # Puts relevant data into analysis object
  my $self = shift;
  my $analysis = shift;
  my $pro = shift;
  
  # $data is a multidimensional hash thing.
  my $data = $self->get_project_info($pro);
  
  # Add study type and description
  $analysis->add_property("study_type", $data->{studies}{studyType});
  $analysis->add_property("study_description", $data->{studies}{description});
  
  # Add more once the need becomes apparent
  
  
}

sub get_sample_ref {
  # StatsDB parsers are supplied by default with a run ID and a sample
  # name. MISO can directly understand the run ID, but not the sample
  # name.
  # In fact, there seem to be two types of sample name - referred to as
  # SampleID and SampleRef.
  
  # statsdb_string.txt uses the SampleID, which cross-references library
  # and library dilution IDs.
  # Miso uses the SampleRef, which cross-references the project ID.
  
  # At the moment, we have the former and want the latter. Luckily,
  # we can cross-reference by obtaining the sample sheet.
  
  my $self = shift;
  my $runID = shift;
  my $sampleID = shift;
  
  my $samplesheet = $self->get_sample_sheet($runID);
  
  my $sampleRef = ();
  my @samplesheet = split /\n/, $samplesheet;
  foreach my $line (@samplesheet) {
    my @line = split /,/, $line;
    if ($line[2] eq $sampleID) {
      return $line[3];
    }
  }
}

sub lib_ldi_from_sampleid {
  # The SampleID value has MISO references for both library and
  # library dilution records. Pull them out here.
  # Returns library and library dilution IDs in that order
  my $self = shift;
  my $sampleID = shift;
  
  my @id = split /_/, $sampleID;
  my $lib = $id[1];
  my $ldi = $id[2];
  return ($lib,$ldi);
}

sub pro_from_sampleref {
  # The SampleRef value has a MISO reference for project
  # records. Pull it out here.
  # Returns project ID
  my $self = shift;
  my $sampleRef = shift;
  
  my @id = split /_/, $sampleRef;
  my $pro = $id[0];
  return ($pro);
}

sub get_sample_sheet {
  my $self = shift;
  my $alias = shift;
  
  my $url = "/miso/rest/run/$alias/samplesheet";
  
  my $data = $self->request($url);
  return $data;
}

sub get_library_info {
  # Takes a MISO library ID number
  # Returns a hash of various library data (converted from JSON)
  # WORKS
  my $self = shift;
  my $library = shift;
  
  my $url = "/miso/rest/library/$library";
  
  my $data = $self->request($url);
  return from_json($data);
}

sub get_pool_info {
  # Takes a MISO pool ID number
  # Returns a hash of various pool data (converted from JSON)
  # DOESN'T WORK
  my $self = shift;
  my $library = shift;
  
  my $url = "/miso/rest/pool/$library";
  
  my $data = $self->request($url);
  return from_json($data);
}

sub get_project_info {
  # Takes a MISO pool ID number
  # Returns a hash of various pool data (converted from JSON)
  # WORKS
  my $self = shift;
  my $library = shift;
  
  my $url = "/miso/rest/project/$library";
  
  my $data = $self->request($url);
  return from_json($data);
}

sub get_run_info {
  # Takes a MISO pool ID number
  # Returns a hash of various pool data (converted from JSON)
  # EXCEEDS MAXIMUM NESTING LEVEL
  my $self = shift;
  my $library = shift;
  
  my $url = "/miso/rest/run/$library";
  
  my $data = $self->request($url);
  return from_json($data);
}


sub request {
  # Simply combines the process of getting a signature and
  # submitting a requet in a single call
  my $self = shift;
  my $url = shift;
  
  my $signature = $self->get_signature($url);
  my $data = $self->submit($signature,$url);
  
  return $data;
}

sub get_signature {
  my $self = shift;
  my $url = shift;
  
  my $command = 'echo -n "'.$url.'?x-url='.$url.'@x-user='.$self->{miso_user}.'" | openssl sha1 -binary -hmac "'.$self->{miso_api_key}.'" | openssl base64 | tr -d = | tr +/ -_';
  my $sig = `$command`;
  chomp $sig;
  return $sig;
}

sub submit {
  my $self = shift;
  my $sig = shift;
  my $url = shift;
  
  # -sS flag hides normal progress bar but shows errors
  my $command = 'curl -sS --request GET "'.$self->{miso_string}.$url.'" --header "x-user:'.$self->{miso_user}.'" --header "x-signature:'.$sig.'" --header "x-url:'.$url.'"';
  my $data = `$command`;
  chomp $data;
  
  return $data;
}

1;
