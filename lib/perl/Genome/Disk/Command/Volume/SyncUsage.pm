package Genome::Disk::Command::Volume::SyncUsage;

use strict;
use warnings;

use Genome;

class Genome::Disk::Command::Volume::SyncUsage {
    is => ['Genome::Role::Logger', 'Command'],
    has => [
        filter => {
            is => 'Text',
            doc => 'Filter expression for volume(s) to sync.',
            shell_args_position => 1,
        },
        tie_stderr => {
            is => 'Boolean',
            default => 1,
            doc => '(warning) globally tie STDERR to this logger',
        },
    ],
    doc => 'Sync usage info for volume (e.g. total KB and unallocated KB)',
};

sub help_detail {
    'Sync usage info for volume (e.g. total KB and unallocated KB).'
}

sub execute {
    my $self = shift;

    my $data_type = 'Genome::Disk::Volume';
    my $bx = UR::BoolExpr->resolve_for_string($data_type, $self->filter);

    my $volume_iter = $data_type->create_iterator($bx);
    while (my $volume = $volume_iter->next) {
        $self->info(sprintf('Syncing %s...', $volume->mount_path));
        $volume->sync_usage(verbose => 1);
    }

    return 1;
}

1;
