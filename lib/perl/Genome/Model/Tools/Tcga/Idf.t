#!/usr/bin/env genome-perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;
use Genome::Utility::Test qw(compare_ok); 
use Genome::Test::Factory::ProcessingProfile::SomaticVariation;
use Genome::Test::Factory::ProcessingProfile::ReferenceAlignment;
use Genome::Test::Factory::Model::SomaticVariation;
use Genome::Test::Factory::Build;

my $class = "Genome::Model::Tools::Tcga::Idf";

my $base_dir = Genome::Utility::Test->data_dir_ok($class, "v4");

subtest add_pp_protocol => sub {
    my $idf = $class->create;
    my $test_pp = get_test_pp();
    my $test_refalign_pp = get_test_refalign_pp();
    $idf->add_somatic_pp_protocols($test_pp);
    $idf->add_refalign_pp_protocols($test_refalign_pp);

    my $expected = {
        "library preparation" => [{name => 'genome.wustl.edu:library_preparation:IlluminaHiSeq_DNASeq:01',
                                    description => 'Illumina library prep'}],
        "imported library preparation" => [{name => 'genome.wustl.edu:library_preparation:Imported:01',
                                    description => 'Imported data'}],
        "mutation filtering annotation and curation" => [{name => 'genome.wustl.edu:maf_creation:data_consolidation:01',
                                    description => 'Automatic and manual filtering and curation of variants'}],
        "variant calling" => [{name => 'genome.wustl.edu:variant_calling:'.$test_pp->id.':01',
                                    description => 'tiering_version=1 transcript_variant_annotator_version=4 get_regulome_db=0 filter_previously_discovered_variants=0 vcf_annotate_dbsnp_info_field_string=NO_INFO required_snv_callers=1 tiers_to_review=1 restrict_to_target_regions=1 bam_readcount_version=0.6'}],
        "nucleic acid sequencing" => [{name => 'genome.wustl.edu:DNA_sequencing:Illumina:01',
                                    description => 'Illumina sequencing by synthesis'}],
        "imported nucleic acid sequencing" => [{name => 'genome.wustl.edu:DNA_sequencing:Imported:01',
                                    description => 'Imported data'}],
        "sequence alignment" => [{name => 'genome.wustl.edu:alignment:'.$test_refalign_pp->id.':01',
                                    description => 'sequencing_platform=solexa dna_type=cdna transcript_variant_annotator_version=4 transcript_variant_annotator_filter=top transcript_variant_annotator_accept_reference_IUB_codes=0 snv_detection_strategy="samtools [ --test 1 ]" read_aligner_name=bwa force_fragment=0'}],
    };

    is_deeply($idf->protocols, $expected, "Fill in idf worked as expected after adding one processing profile");
};

subtest add_same_pp_protocols => sub {
    my $idf = $class->create;
    my $test_pp = get_test_pp();
    my $test_refalign_pp = get_test_refalign_pp();
    $idf->add_somatic_pp_protocols($test_pp);
    $idf->add_somatic_pp_protocols($test_pp);
    $idf->add_refalign_pp_protocols($test_refalign_pp);
    $idf->add_refalign_pp_protocols($test_refalign_pp);

    my $expected = {
        "library preparation" => [{name => 'genome.wustl.edu:library_preparation:IlluminaHiSeq_DNASeq:01',
                                    description => 'Illumina library prep'}],
        "imported library preparation" => [{name => 'genome.wustl.edu:library_preparation:Imported:01',
                                    description => 'Imported data'}],
        "mutation filtering annotation and curation" => [{name => 'genome.wustl.edu:maf_creation:data_consolidation:01',
                                    description => 'Automatic and manual filtering and curation of variants'}],
        "variant calling" => [{name => 'genome.wustl.edu:variant_calling:'.$test_pp->id.':01',
                                    description => 'tiering_version=1 transcript_variant_annotator_version=4 get_regulome_db=0 filter_previously_discovered_variants=0 vcf_annotate_dbsnp_info_field_string=NO_INFO required_snv_callers=1 tiers_to_review=1 restrict_to_target_regions=1 bam_readcount_version=0.6'}],
        "nucleic acid sequencing" => [{name => 'genome.wustl.edu:DNA_sequencing:Illumina:01',
                                    description => 'Illumina sequencing by synthesis'}],
        "sequence alignment" => [{name => 'genome.wustl.edu:alignment:'.$test_refalign_pp->id.':01',
                                    description => 'sequencing_platform=solexa dna_type=cdna transcript_variant_annotator_version=4 transcript_variant_annotator_filter=top transcript_variant_annotator_accept_reference_IUB_codes=0 snv_detection_strategy="samtools [ --test 1 ]" read_aligner_name=bwa force_fragment=0'}],
        "imported nucleic acid sequencing" => [{name => 'genome.wustl.edu:DNA_sequencing:Imported:01',
                                    description => 'Imported data'}],
    };

    is_deeply($idf->protocols, $expected, "Fill in idf worked as expected after adding the same processing profile twice");
};

subtest add_different_pp_protocols => sub {
    my $idf = $class->create;
    my $test_pp = get_test_pp();
    my $test_pp2 = get_test_pp2();
    my $test_refalign_pp = get_test_refalign_pp();
    $idf->add_somatic_pp_protocols($test_pp);
    $idf->add_somatic_pp_protocols($test_pp2);
    $idf->add_refalign_pp_protocols($test_refalign_pp);

    my $expected = {
        "library preparation" => [{name => 'genome.wustl.edu:library_preparation:IlluminaHiSeq_DNASeq:01',
                                    description => 'Illumina library prep'}],
        "imported library preparation" => [{name => 'genome.wustl.edu:library_preparation:Imported:01',
                                    description => 'Imported data'}],
        "mutation filtering annotation and curation" => [{name => 'genome.wustl.edu:maf_creation:data_consolidation:01',
                                    description => 'Automatic and manual filtering and curation of variants'}],
        "variant calling" => [{name => 'genome.wustl.edu:variant_calling:'.$test_pp->id.':01',
                                    description => 'tiering_version=1 transcript_variant_annotator_version=4 get_regulome_db=0 filter_previously_discovered_variants=0 vcf_annotate_dbsnp_info_field_string=NO_INFO required_snv_callers=1 tiers_to_review=1 restrict_to_target_regions=1 bam_readcount_version=0.6'},
                              {name => 'genome.wustl.edu:variant_calling:'.$test_pp2->id.':01',
                                    description => 'tiering_version=3 transcript_variant_annotator_version=4 get_regulome_db=0 filter_previously_discovered_variants=0 vcf_annotate_dbsnp_info_field_string=NO_INFO required_snv_callers=1 tiers_to_review=1 restrict_to_target_regions=1 bam_readcount_version=0.6'}],
        "nucleic acid sequencing" => [{name => 'genome.wustl.edu:DNA_sequencing:Illumina:01',
                                    description => 'Illumina sequencing by synthesis'}],
        "imported nucleic acid sequencing" => [{name => 'genome.wustl.edu:DNA_sequencing:Imported:01',
                                    description => 'Imported data'}],
        "sequence alignment" => [{name => 'genome.wustl.edu:alignment:'.$test_refalign_pp->id.':01',
                                    description => 'sequencing_platform=solexa dna_type=cdna transcript_variant_annotator_version=4 transcript_variant_annotator_filter=top transcript_variant_annotator_accept_reference_IUB_codes=0 snv_detection_strategy="samtools [ --test 1 ]" read_aligner_name=bwa force_fragment=0'}],
    };

    is_deeply($idf->protocols, $expected, "Fill in idf worked as expected after adding the same processing profile twice");
};

subtest resolve_x_protocol => sub {
    my $idf = $class->create;
    my $test_pp = get_test_pp();
    my $test_build = get_test_build();
    is($idf->resolve_maf_protocol, "genome.wustl.edu:maf_creation:data_consolidation:01", "Maf protocol resolved correctly");
    is($idf->resolve_mapping_protocol($test_pp), "genome.wustl.edu:alignment:".$test_pp->id.":01", "Mapping protocol resolved correctly");
    is($idf->resolve_library_protocol($test_build), "genome.wustl.edu:library_preparation:IlluminaHiSeq_DNASeq:01", "Library protocol resolved correctly");
    is($idf->resolve_variants_protocol($test_pp), "genome.wustl.edu:variant_calling:".$test_pp->id.":01", "Variants protocol defined correctly");
    is($idf->resolve_sequencing_protocol($test_build), "genome.wustl.edu:DNA_sequencing:Illumina:01", "Sequencing protocol defined correctly");
};

subtest "print IDF" => sub {
    my %protocol_db = (
        "library preparation" => [
        {name => "libraryprep1", description => "First library prep protocol"}
        ],
        "nucleic acid sequencing" => [
        {name => "sequencing1", description => "First sequencing protocol"},
        ],
        "sequence alignment" => [
        {name => "alignment1", description => "First mapping protocol"},
        ],
        "variant calling" => [
        {name => "variants1", description => "First variant detection protocol"},
        ],
        "mutation filtering and annotation" => [
        {name => "maf1", description => "First filtering protocol"},
        ],
    );
    my $idf = Genome::Model::Tools::Tcga::Idf->create(sdrf_file => "test.sdrf");
    $idf->protocols(\%protocol_db);
    my $output_idf = Genome::Sys->create_temp_file_path;
    ok($idf->print_idf($output_idf), "Print idf called successfully");
    compare_ok($output_idf, $base_dir."/expected.idf", "idf printed as expected");
};

my $TEST_PP;
my $TEST_PP2;
my $TEST_REFALIGN_PP;
sub get_test_pp {
    unless (defined $TEST_PP) {
        $TEST_PP = Genome::Test::Factory::ProcessingProfile::SomaticVariation->setup_object;
    }
    return $TEST_PP;
}

sub get_test_pp2 {
    unless (defined $TEST_PP2) {
        $TEST_PP2 = Genome::Test::Factory::ProcessingProfile::SomaticVariation->setup_object(tiering_version => 3);
    }
    return $TEST_PP2;
}

sub get_test_refalign_pp {
    unless (defined $TEST_REFALIGN_PP) {
        $TEST_REFALIGN_PP = Genome::Test::Factory::ProcessingProfile::ReferenceAlignment->setup_object;
    }
    return $TEST_REFALIGN_PP;
}

sub get_test_build {
    my $model = Genome::Test::Factory::Model::ReferenceAlignment->setup_object;
    my $build = Genome::Test::Factory::Build->setup_object(model_id => $model->id);
}

done_testing;
