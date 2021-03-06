package Genome::Model::Tools::Consed::PhdReader;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Consed::PhdReader {
};

sub read {
    my ($self, $file) = @_;

    if ( not $file ) {
        $self->error_message('No file to write read as phd');
        return;
    }
    my $io = eval{ Genome::Sys->open_file_for_reading($file); };
    if ( not $io ) {
        $self->error_message("Failed to open file ($file): $@");
        return;
    }

    my %object_builders = ( 
        BEGIN_COMMENT => '_parse_comment',
        BEGIN_DNA => '_parse_DNA',
        "WR{" => '_parse_WR',
        BEGIN_TAG => '_parse_tag',
    );

    my %phd;
    my $header_line = $io->getline;
    if ( not $header_line ) {
        $self->error_message("No phd header line");
        return;
    }
    chomp $header_line;
    my @tokens = split(/ /, $header_line);
    if ( $tokens[0] ne 'BEGIN_SEQUENCE' ) {
        $self->error_message("Invalid phd header: $header_line");
        return;
    }
    $phd{name} = $tokens[1];

    while ( my $line = $io->getline ) {
        chomp $line;
        my @tokens = split(/ /, $line);
        my $tag = shift @tokens;
        if ( $tag and my $method = $object_builders{$tag}) {
            $self->$method($io, \%phd);
        }
    }

    return \%phd;
}

# COMMENT EX:
# CHROMAT_FILE: L24337P6000G2.g1
# ABI_THUMBPRINT: 0
# PHRED_VERSION: 0.040406.a_2
# CALL_METHOD: abi
# QUALITY_LEVELS: 99
# TIME: Tue Nov 6 15:08:10 2007
# TRACE_ARRAY_MIN_INDEX: 0
# TRACE_ARRAY_MAX_INDEX: 8736
# CHEM: term
# DYE: big
sub _parse_comment {
    my ($self, $io, $phd) = @_;

    while ( my $line = $io->getline ) 
    {
        chomp $line;
        last if $line =~ /END_COMMENT/;
        next if $line =~ /^\s*$/; 
        my @tokens = split(/:\s/, $line);
        $phd->{comments}->{ lc($tokens[0]) } = $tokens[1];
    }
    
    return 1;
}

sub _parse_DNA {
    my ($self, $io, $phd) = @_;

    while ( my $line = $io->getline ) 
    {
        chomp $line;
        last if $line =~ /END_DNA/;
        my @pos = split(/ /,$line);
        $phd->{base_string} .= $pos[0];
        push @{ $phd->{qualities} }, $pos[1];
        push @{ $phd->{chromat_positions} }, $pos[2];
    }

    return 1;
}

sub _parse_WR 
{
    my ($self, $io, $phd) = @_;

    my $wr;
    while (my $line = $io->getline ) 
    {
        last if $line =~ /^}/;
        $wr .= $line;
    }
    
    chomp $wr;
    
    return push @{ $phd->{wr} }, $wr;
}

sub _parse_tag 
{
    my ($self, $io, $phd) = @_;
    
    my %tag_data;
    my $text;
    while ( my $line = $io->getline ) 
    {
        chomp $line;
        last if $line =~ /^END_TAG/;
        if ($line =~ /BEGIN_COMMENT/) 
        {
            while ( my $comment_line = $io->getline ) 
            {
                last if $comment_line =~ /END_COMMENT/;
                $text .= $comment_line;
            }
        }
        my @tokens = split(/\:\s/, $line);
        $tag_data{$tokens[0]} = $tokens[1];
    }
    my @pos = split(/\s/, $tag_data{UNPADDED_READ_POS});
    
    my $tag = {
        parent => $phd->{name},
        type   => $tag_data{TYPE},
        source => $tag_data{SOURCE},
        date   => $self->_convert_from_phd_tag_date( $tag_data{DATE} ),
        unpad_start  => $pos[0],
        unpad_stop   => $pos[1],
    };

    $tag->text($text) if $text;
    
    return push @{ $phd->{tags} }, $tag;
}

sub _convert_from_phd_tag_date {
    my ($self, $date) = @_;

    return ( $date =~ /^[89]/ ? ('19' . $date) : ('20' . $date));
}

1;

=pod

=head1 Name

Genome::Model::Tools::Consed::PhdReader;

=head1 Synopsis

This package is a phd file reader.  Given an IO object, an assemled read object representing the phd infomation in the IO will be returned.  It is a singleton, so "create" by calling instance on the class, then call the execute method.

=head1 Usage

 use Genome::Model::Tools::Consed::PhdReader;
 use IO::File;

 my $fh = IO::File->new("< read.phd.1")
    or die "$!\n";
 my $reader = Genome::Model::Tools::Consed::PhdReader->create(io => $fh);
 my $phd = $reader->read($fh);
 $fh->close;

 print $phd->{name},"\n";

=head1 Methods

 my $phd = Genome::Model::Tools::Consed::PhdReader->read;
 
=over

=item I<Synopsis>   Parses the phd info in the file handle

=item I<Params>     None

=item I<Returns>    Phd hashref

=back

=cut

