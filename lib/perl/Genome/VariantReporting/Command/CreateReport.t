#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{NO_LSF} = 1;
    $ENV{UR_DUMP_DEBUG_MESSAGES} = 1;
    $ENV{UR_COMMAND_DUMP_DEBUG_MESSAGES} = 1;
    $ENV{UR_DUMP_STATUS_MESSAGES} = 1;
    $ENV{UR_COMMAND_DUMP_STATUS_MESSAGES} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;
use Test::Deep;
use File::Basename qw(basename);
use File::Spec;
use Genome::Utility::Test qw(compare_ok);
use Test::Exception;

my $pkg = 'Genome::VariantReporting::Command::CreateReport';
use_ok($pkg);

my $code_test_dir = __FILE__ . '.d';

subtest 'working_command' => sub {
    my $test_dir = Genome::Sys->create_temp_directory;
    Genome::Sys->rsync_directory(
        source_directory => $code_test_dir,
        target_directory => $test_dir
    );

    my $input_vcf = File::Spec->join($test_dir, "input.vcf");
    my $cmd = $pkg->create(
        input_vcf => $input_vcf,
        variant_type => 'snvs',
        plan_file => File::Spec->join($test_dir, 'plan.yaml'),
        translations_file => get_translations_file($input_vcf),
    );
    my $p = $cmd->execute();
    UR::Context->commit();
    my $expected_result_dir = File::Spec->join($test_dir, "expected_in_result");

    my $output_dir = Genome::Sys->create_temp_directory;
    $p->symlink_results($output_dir);
    compare_dir_ok($output_dir, $expected_result_dir,
        'All reports are as expected');

    my $expected_process_dir = File::Spec->join($test_dir, "expected_in_process");
    compare_dir_ok($p->metadata_directory, $expected_process_dir,
        'All metadata files are as expected');

    subtest 'test compare_output subroutine - same inputs' => sub {
        my $other_test_dir = Genome::Sys->create_temp_directory;
        Genome::Sys->rsync_directory(
            source_directory => $code_test_dir,
            target_directory => $other_test_dir
        );
        my $other_input_vcf = File::Spec->join($other_test_dir, 'input.vcf');
        my $other_cmd = $pkg->create(
            input_vcf => $other_input_vcf,
            variant_type => 'snvs',
            plan_file => File::Spec->join($other_test_dir, 'plan.yaml'),
            translations_file => get_translations_file($other_input_vcf),
        );
        my $other_p = $other_cmd->execute();
        UR::Context->commit();
        is_deeply({$p->compare_output($other_p->id)}, {}, 'Two identical process executions produce the same output');
    };

    subtest 'test compare_output subroutine - different inputs' => sub {
        my $other_test_dir = Genome::Sys->create_temp_directory;
        Genome::Sys->rsync_directory(
            source_directory => $code_test_dir,
            target_directory => $other_test_dir
        );
        my $other_input_vcf = File::Spec->join($other_test_dir, 'other_input.vcf');

        my $other_cmd = $pkg->create(
            input_vcf => $other_input_vcf,
            variant_type => 'snvs',
            plan_file => File::Spec->join($other_test_dir, 'plan.yaml'),
            translations_file => get_translations_file($other_input_vcf),
        );
        my $other_p = $other_cmd->execute();
        UR::Context->commit();
        my %diffs = $p->compare_output($other_p->id);
        my $report_file = File::Spec->join($p->output_directory('__test__'), 'report.txt');
        my $other_report_file = File::Spec->join($other_p->output_directory('__test__'), 'report.txt');
        my $diff_key = File::Spec->join('__test__', 'report.txt');
        is_deeply([keys %diffs], [$diff_key], 'Two process executions with different input files produce different reports');

        subtest 'test compare_output subroutine - missing file in other report directory' => sub {
            unlink $other_report_file;
            %diffs = $p->compare_output($other_p->id);
            my $other_process_id = $other_p->id;
            like($diffs{$diff_key}, qr/__test__\/report\.txt.*$other_process_id/, 'Missing files in other report output directory gets detected');
            Genome::Sys->copy_file($report_file, $other_report_file);
        };
        subtest 'test compare_output subroutine - missing file in report directory' => sub {
            unlink $report_file;
            %diffs = $p->compare_output($other_p->id);
            my $process_id = $p->id;
            like($diffs{$diff_key}, qr/__test__\/report\.txt.*$process_id/, 'Missing files in report output directory gets detected');
            Genome::Sys->copy_file($other_report_file, $report_file);
        };
    };

    subtest 'test compare_output subroutine - different plan files with additional report' => sub {
        my $other_test_dir = Genome::Sys->create_temp_directory;
        Genome::Sys->rsync_directory(
            source_directory => $code_test_dir,
            target_directory => $other_test_dir
        );
        my $other_input_vcf = File::Spec->join($other_test_dir, 'input.vcf');

        my $other_cmd = $pkg->create(
           input_vcf => $other_input_vcf,
           variant_type => 'snvs',
           plan_file => File::Spec->join($other_test_dir, 'plan2.yaml'),
           translations_file => get_translations_file_for_plan2($other_input_vcf),
        );
        my $other_p = $other_cmd->execute();
        UR::Context->commit();
        my %diffs = $p->compare_output($other_p->id);
        like($diffs{'__translated_test__'}, qr/no directory __translated_test__ found/, 'Additional report gets detected');
        like($diffs{File::Spec->join('__test__', 'plan.yaml')}, qr/files are not the same/, 'Plan file difference gets detected');
    };
};

subtest 'no_translations_file' => sub {
    my $test_dir = Genome::Sys->create_temp_directory;
    Genome::Sys->rsync_directory(
        source_directory => $code_test_dir,
        target_directory => $test_dir
    );

    my $output_dir = Genome::Sys->create_temp_directory;

    my $input_vcf = File::Spec->join($test_dir, "input.vcf");
    my $cmd = $pkg->create(
        input_vcf => $input_vcf,
        variant_type => 'snvs',
        plan_file => File::Spec->join($test_dir, 'plan.yaml'),
        translations_file => "does_not_exist.yaml",
    );

    dies_ok { $cmd->execute } 'Command fails with non-existent translations_file';
};

subtest 'no_plan_file' => sub {
    my $test_dir = Genome::Sys->create_temp_directory;
    Genome::Sys->rsync_directory(
        source_directory => $code_test_dir,
        target_directory => $test_dir
    );

    my $output_dir = Genome::Sys->create_temp_directory;

    my $input_vcf = File::Spec->join($test_dir, "input.vcf");
    my $cmd = $pkg->create(
        input_vcf => $input_vcf,
        variant_type => 'snvs',
        plan_file => 'does_not_exist.plan',
        translations_file => get_translations_file($input_vcf),
    );

    dies_ok { $cmd->execute } 'Command fails with nonexistant plan_file';
};

subtest 'no_vcf' => sub {
    my $test_dir = Genome::Sys->create_temp_directory;
    Genome::Sys->rsync_directory(
        source_directory => $code_test_dir,
        target_directory => $test_dir
    );

    my $output_dir = Genome::Sys->create_temp_directory;

    my $input_vcf = File::Spec->join($test_dir, "input.vcf");
    my $cmd = $pkg->create(
        input_vcf => 'does_not_exist.vcf',
        variant_type => 'snvs',
        plan_file => File::Spec->join($test_dir, 'plan.yaml'),
        translations_file => get_translations_file($input_vcf),
    );

    ok(!$cmd->execute, 'Command fails with nonexistant input_vcf');
};

done_testing;

sub get_translations_file {
    my $input_vcf = shift;

    my $provider = Genome::VariantReporting::Framework::Component::RuntimeTranslations->create();
    my $tmp_dir = Genome::Sys->create_temp_directory;
    my $translations_file = File::Spec->join($tmp_dir, 'resources.yaml');
    $provider->write_to_file($translations_file);
    return $translations_file;
}

sub get_translations_file_for_plan2 {
    my $input_vcf = shift;

    my $provider = Genome::VariantReporting::Framework::Component::RuntimeTranslations->create(
        translations => {
            __input__ => 'test',
            tumor => 'test sample',
            old_value => 'new value',
            old_value1 => 'new value 1',
            old_value2 => 'new value 2',
            to_translate1 => 'test',
        }
    );
    my $tmp_dir = Genome::Sys->create_temp_directory;
    my $translations_file = File::Spec->join($tmp_dir, 'resources.yaml');
    $provider->write_to_file($translations_file);
    return $translations_file;
}

sub compare_dir_ok {
    my ($got_dir, $expected_dir, $message) = @_;

    my @got_files = map {basename($_)} glob(File::Spec->join($got_dir, '*'));
    my @expected_files = map {basename($_)} glob(File::Spec->join($expected_dir, '*'));

    my $got_files = Set::Scalar->new(@got_files);
    for my $filename (@expected_files) {
        ok($got_files->contains($filename), sprintf(
            "Found file (%s) in directory (%s)", $filename, $got_dir),
        ) || die;

        # this file has absolute paths to test files in it
        next if $filename eq 'resources.yaml';

        my $got = File::Spec->join($got_dir, $filename);
        my $expected = File::Spec->join($expected_dir, $filename);
        compare_ok($got, $expected, "File ($filename) is as expected");

    }
}
