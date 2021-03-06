package Genome::Model::Tools::Sam::ExtractReadGroup;

use strict;
use warnings FATAL => 'all';

use Genome;

class Genome::Model::Tools::Sam::ExtractReadGroup {
    is  => 'Genome::Model::Tools::Sam',
    has_input => [
        input => {
            is  => 'String',
            doc => 'Input SAM/BAM file to extract reads from. Required.',
        },
        output => {
            is  => 'String',
            doc => 'Output BAM file to extract to',
        },
        read_group_id => {
            is          => 'String',
            doc         => 'Individual read group requested',
        },
		include_qc_failed => {
			is 			=> 'Boolean',
			doc			=> 'Include reads that were marked within the bam as having failed QC',
			is_optional	=> 1,
			default		=> 0,
		},
        name_sort => {
            is 			=> 'Boolean',
			doc			=> 'Name-sort output bam',
			is_optional	=> 1,
			default		=> 0,
        }
    ],
    has_output => [
        read_count => { 
            is => 'Number',
            is_optional => 1 
        },
    ],
};

sub help_brief {
    'Tool to create a BAM file from an individual read group in a BAM'
}

sub help_detail {
    return <<EOS
    Tool to extract reads from a bam by read group. 
EOS
}


sub execute {
    my $self = shift;

    my $input_file    = $self->input;
    my $output_file   = $self->output;
    my $samtools_path = $self->samtools_path;
    my $rg_id         = $self->read_group_id;

    Genome::Sys->validate_file_for_reading($input_file);
    unless (-s $input_file) {
        die $self->error_message("Input $input_file is not valid");
    }

    unless (Genome::Sys->validate_file_for_writing($output_file)) {
        die $self->error_message("output $output_file is not writable");
    }
    
    my $temp_bam_file = Genome::Sys->create_temp_file_path() . '.bam';

    my $samtools_check_cmd = sprintf("%s view -r%s %s | head -1", $samtools_path, $rg_id, $input_file);
    my $samtools_check_output = `$samtools_check_cmd`;

    if (length($samtools_check_output) == 0) {
        die $self->error_message ('There were no reads in this read group requested: ' . $rg_id);
    } 
	
    my $qc_filter_spec = (! $self->include_qc_failed ? '-F 0x200' : '');

    my $samtools_strip_cmd = sprintf(
        "%s view -b -h -r%s %s %s > %s",
        $samtools_path,
        $self->read_group_id,
		$qc_filter_spec,
        $input_file, 
        $temp_bam_file,
    );

    Genome::Sys->shellcmd(
        cmd => $samtools_strip_cmd, 
        output_files => [$temp_bam_file],
        skip_if_output_is_present => 0,
    );

    if ($self->name_sort) {
        my $sort_cmd = Genome::Model::Tools::Sam::SortBam->create(
            file_name   => $temp_bam_file,
            name_sort   => 1, 
            output_file => $output_file,
            use_version => $self->use_version,
        );

        unless ($sort_cmd->execute) {
            die $self->error_message("Failed sorting reads into name order for iterating");
        }

        # VERIFY READ COUNTS: READ GROUP BAM v. SORTED READ GROUP BAM
        my $temp_bam_read_count = $self->_read_count_for_bam($temp_bam_file);
        return unless $temp_bam_read_count;

        my $sorted_temp_bam_read_count = $self->_read_count_for_bam($output_file);
        return unless $sorted_temp_bam_read_count;

        $self->debug_message('VERIFY READ COUNTS: READ GROUP BAM v. SORTED READ GROUP BAM');
        $self->debug_message("$temp_bam_read_count reads in READ GROUP BAM: $temp_bam_file");
        $self->debug_message("$sorted_temp_bam_read_count reads in SORTED READ GROUP BAM: $output_file");

        if ($temp_bam_read_count ne $sorted_temp_bam_read_count) {
            $self->error_message("Before and after name-sort resulted in different number of reads: $temp_bam_read_count <=> $sorted_temp_bam_read_count");
            return;
        }
        $self->read_count($temp_bam_read_count);
    }
    else {
        unless (Genome::Sys->rename($temp_bam_file, $output_file)) {
            die $self->error_message("Failed to rename $temp_bam_file to $output_file");
        }
    }

    return 1;

}

sub _read_count_for_bam {
    my ($self, $bam) = @_;

    Carp::confess('No bam to get read count!') if not $bam;

    my $tmpdir = Genome::Sys->base_temp_directory;
    my $flagstat_file = $tmpdir.'/flagstat';
    unlink $flagstat_file;
    my $gmt = Genome::Model::Tools::Sam::Flagstat->create(
        bam_file => $bam,
        output_file => $flagstat_file,
        use_version => $self->use_version,
    );
    if ( not $gmt ) {
        $self->error_message('Failed to create gmt same flagstat!');
        return;
    }
    $gmt->dump_status_messages(1);
    my $ok = $gmt->execute;
    if ( not $ok ) {
        $self->error_message('Failed to execute gmt sam flagstat!');
        return;
    }

    my $flagstat = Genome::Model::Tools::Sam::Flagstat->parse_file_into_hashref($flagstat_file);
    if ( not $flagstat ) {
        $self->error_message('Failed to get metrics from flagstat file: '.$flagstat_file);
        return;
    }

    #It seems this picard tool will only return reads passing QC. No QC
    #failed reads will be put in fastq files.
    if ( not defined $flagstat->{reads_marked_passing_qc} ) {
        $self->error_message('No reads_marked_passing_qc from flagstat file!');
        return;
    }

    return $flagstat->{reads_marked_passing_qc};
}


1;
__END__

