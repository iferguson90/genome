package Genome::Model::Tools::EdgeR::FilterStructures;

use Genome;
use Carp qw/confess/;

use strict;
use warnings;

my $R_SCRIPT = __FILE__ . ".R";

class Genome::Model::Tools::EdgeR::FilterStructures {
    is => "Command::V2",
    has => [
        counts_file => {
            is => "Text",
            doc => "Input counts matrix file",
        },

        output_file => {
            is => "Text",
            doc => "Output file",
        },

        percentile => {
            is => "Number",
            doc => "Percentile across samples to compare to min_count",
        },

        min_count => {
            is => "Number",
            doc => "Minimum number of counts",
        },

    ],
    doc => "Filter out structures where nth percentile "
        . "(--percentile) is less than m (--min-count)"
};

sub help_synopsis {
    return <<EOS

# Filter out structures where the 25th percentile is less than 20
gmt edge-r filter-structures \\
    --counts-file counts.txt \\
    --output-file filtered.txt \\
    --percentile 25 \\
    --min-count 20

EOS
}

sub help_detail {
    return <<EOS

Filter out structures with low counts across samples.

EOS
}

sub execute {
    my $self = shift;

    my $percentile = $self->percentile;
    if ($percentile < 0 or $percentile > 100) {
        confess "percentile param must satisfy 0 <= percentile <= 100 (value: $percentile)";
    }

    my $quantile = $percentile / 100.0;

    my $cmd = sprintf("Rscript %s --input-file %s --output-file %s --quantile %f --min-count %d",
            $R_SCRIPT,
            $self->counts_file,
            $self->output_file,
            $quantile,
            $self->min_count
            );

    return Genome::Sys->shellcmd(
        cmd => $cmd
        );
}

1;
