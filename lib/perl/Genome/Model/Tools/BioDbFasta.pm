package Genome::Model::Tools::BioDbFasta;

use Genome;
use strict;
use warnings;

class Genome::Model::Tools::BioDbFasta {
    is => 'Command',
    doc => "fast random access to sequence/quality files"
};

sub help_brief {
    shift->__meta__->doc;
}

sub help_detail {
    return <<EOS;
TODO: ADD THIS
EOS
}

1;

