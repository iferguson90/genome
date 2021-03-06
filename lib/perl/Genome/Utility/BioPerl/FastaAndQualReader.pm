package Genome::Utility::BioPerl::FastaAndQualReader;

use strict;
use warnings;

use Genome;

require Bio::SeqIO;
require Bio::Seq;
require Bio::Seq::Quality;
use Data::Dumper 'Dumper';

class Genome::Utility::BioPerl::FastaAndQualReader {
    is => 'UR::Object',
    has => [
        fasta_file => {
            is => 'Text',
            doc => 'Fasta file for reading or writing.'
        },
        qual_file => {
            is => 'Text',
            is_optional => 1,
            doc => 'Qual file for reading or writing.'
        },
        _fasta_io => {
            is => 'Bio::SeqIO',
            is_optional => 1,
            doc => 'Fasta bioseq objects.'
        },
        _qual_io => {
            is => 'Bio::SeqIO',
            is_optional => 1,
            doc => 'qual bioseq objects.'
        },
    ],
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    $self->_create_readers or return;

    return $self;
}

sub _create_readers {
    my $self = shift;

    $self->_fasta_io( 
        Genome::Utility::BioPerl->create_bioseq_reader(
            $self->fasta_file, 'fasta'
        )
    )
        or return;
    if ( $self->qual_file ) { 
         $self->_qual_io( 
             Genome::Utility::BioPerl->create_bioseq_reader(
                 $self->qual_file, 'qual'
             )
         )
            or return;
    }

    return 1;
}

sub next_seq {
    my $self = shift;

    my $fasta = $self->_fasta_io->next_seq
        or return;

    return $fasta unless $self->_qual_io;

    my $qual = $self->_qual_io->next_seq;

    my $bioseq = Genome::Utility::BioPerl->create_bioseq_from_fasta_and_qual(
        fasta => $fasta, 
        qual => $qual,
    )
        or die;

    return $bioseq;
}

1;

=pod

=head1 Disclaimer

Copyright (C) 2010 Genome Center at Washington University in St. Louis

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@genome.wustl.edu>

=cut

#$HeadURL$
#$Id$
