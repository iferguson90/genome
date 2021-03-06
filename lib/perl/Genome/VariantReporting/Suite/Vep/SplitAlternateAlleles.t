#!/usr/bin/env genome-perl

use strict;
use warnings FATAL => 'all';

use Test::More;
use above 'Genome';
use Genome::Utility::Test qw(compare_ok);
use Genome::File::Vcf::Differ;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

my $pkg = 'Genome::VariantReporting::Suite::Vep::SplitAlternateAlleles';
use_ok($pkg) || die;

my $VERSION = 1; # Bump this each time test data changes
my $test_dir = Genome::Utility::Test->data_dir($pkg, "v$VERSION");
if (-d $test_dir) {
    note "Found test directory ($test_dir)";
} else {
    die "Failed to find test directory ($test_dir)";
}

my $input_file = File::Spec->join($test_dir, 'input.vcf');
my $expected_output_file = File::Spec->join($test_dir, 'expected_output.vcf');

my $output_file = Genome::Sys->create_temp_file_path();
$pkg->execute(
    input_file => $input_file,
    output_file => $output_file,
);

my $differ = Genome::File::Vcf::Differ->new($output_file, $expected_output_file);
my $diff = $differ->diff;
is($diff, undef, "Found No differences between $output_file and (expected) $expected_output_file") ||
    diag $diff->to_string;

done_testing();
