#!/usr/bin/env genome-perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;
use Genome::Test::Factory::InstrumentData::MergedAlignmentResult;
use Genome::Test::Factory::SoftwareResult::User;
use Sub::Install qw (reinstall_sub);

my $pkg = "Genome::Qc::Run";
use_ok($pkg);

my $test_dir = __FILE__.".d";
{
    package TestTool1;

    use Genome;

    class TestTool1 {
        is => [$pkg],
        has => {input_file => {}},
    };

    sub first_input_file {
        my $self = shift;
        return $self->alignment_result->bam_path;
    }

    sub cmd_line {
        my $self = shift;
        return ("head", "-n", "1", $self->input_file);
    }

    sub supports_streaming {
        return 1;
    }

    sub get_metrics {
        return {
            metric1 => 1,
            metric2 => 2,
        };
    }
}

{
    package TestTool2;

    use Genome;

    class TestTool2 {
        is => [$pkg],
        has => {input_file => {}},
    };

    sub first_input_file {
        my $self = shift;
        return $self->alignment_result->bam_path;
    }

    sub cmd_line {
        my $self = shift;
        return ("tail", "-n", "1", $self->input_file);
    }

    sub supports_streaming {
        return 1;
    }

    sub get_metrics {
        return {
            metricA => 1,
            metricB => 2,
        };
    }
}

    my $alignment_result = Genome::Test::Factory::InstrumentData::MergedAlignmentResult->setup_object();
    my $bam = File::Spec->join($test_dir, "in");
    reinstall_sub({
            into => 'Genome::InstrumentData::AlignmentResult::Merged',
            as => 'bam_path',
            code => sub {
                return $bam;
            },
        });

subtest "teed input" => sub {
    use Genome::Qc::Config;
    reinstall_sub({
            into => 'Genome::Qc::Config',
            as => 'get_commands_for_alignment_result',
            code => sub {
                return {test1 => {class => "TestTool1",
                                  params => {input_file => '-'},
                                  in_file => "first_input_file",
                                  out_file => "test1.out"},
                    test2 => {class => "TestTool2",
                              params => {input_file => '-'},
                              in_file => "first_input_file",
                              out_file => "test2.out"}};
            },
        });

    my $command = $pkg->create(
        alignment_result => $alignment_result,
        %{Genome::Test::Factory::SoftwareResult::User->setup_user_hash},
    );

    ok($command->execute, "Command executes ok");
    ok($command->output_result, "Result is defined after command executes");

    for my $test (1,2) {
        my $file_name = "test$test.out";
        compare_ok(File::Spec->join($command->output_result->output_dir, $file_name),
            File::Spec->join($test_dir, $file_name), "Teed processes produced correct file $test");
    }
};

subtest "piped input" => sub {
    use Genome::Qc::Config;
    reinstall_sub({
            into => 'Genome::Qc::Config',
            as => 'get_commands_for_alignment_result',
            code => sub {
                return {test1 => {class => "TestTool1",
                        params => {input_file => '-'},
                        in_file => "first_input_file"},
                    test2 => {class => "TestTool2",
                    params => {input_file => '-'},
                    dependency => {fd => "STDOUT", name => "test1"},
                    out_file => "test-piped.out"}};
            },
        });

    my $command = $pkg->create(
        alignment_result => $alignment_result,
        %{Genome::Test::Factory::SoftwareResult::User->setup_user_hash},
    );

    ok($command->execute, "Command executes ok");
    ok($command->output_result, "Result is defined after command executes");

    my $file_name = "test-piped.out";
    compare_ok(File::Spec->join($command->output_result->output_dir, $file_name),
        File::Spec->join($test_dir, $file_name), "Piped processes produced correct file");
};
done_testing;

