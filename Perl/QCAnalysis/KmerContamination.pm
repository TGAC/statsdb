package QCAnalysis::KmerContamination;
use base 'QCAnalysis';
use strict;
no strict "refs";
use IO::File;

our %values;
$values{sample} = "analysis";
$values{reference} = "analysis";
$values{sample_size_ratio} = "analysis";
$values{program} = "analysis";
$values{sampled_reads} = "analysis";
$values{contaminated_reads} = "analysis";
$values{percentage} = "analysis";
$values{ref_kmer_percent} = "analysis";

our %value_keys;
$value_keys{"Sample"} = "sample";
$value_keys{"Reference"} = "reference";
$value_keys{"SampleSize(Ratio)"} = "sample_size_ratio";
$value_keys{"Program"} = "program";
$value_keys{"SampledReads"} = "sampled_reads";
$value_keys{"ContaminatedReads"} = "contaminated_reads";
$value_keys{"Percentage"} = "percentage";
$value_keys{"RefKmerPercent"} = "ref_kmer_percent";
