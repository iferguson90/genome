use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use above "Genome";
use Test::More;
use Genome::Model::TestHelpers qw(
    define_test_classes
    create_test_sample
    create_test_pp
    create_test_model
);

my $class = "Genome::ModelGroup::Command::GetLastCompletedBuilds";
use_ok($class) || die;

define_test_classes();
my $sample = create_test_sample('test_sample');
my $pp = create_test_pp('test_pp');

my $model = create_test_model($sample, $pp, 'first_test_model');

class Genome::Model::Build::Test {
    is => 'Genome::Model::Build',
};
my $build = Genome::Model::Build::Test->create(model => $model);
ok($build, "Created test build") || die;

my $model_group = Genome::ModelGroup->create(models => [$model], name => 'test_model_group');
ok($model_group, "Created model group") || die;

my $cmd = $class->create(model_group => $model_group);
eval {$cmd->execute()};
ok($@ =~ 'Found no last_completed_build for model');

$build->status('Succeeded');
$cmd = $class->create(model_group => $model_group);
ok($cmd->execute(), "Successfully executed command");
my @builds = $cmd->builds;
is_deeply([$build], \@builds, "Found expected builds");

done_testing();
