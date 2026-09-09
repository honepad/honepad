package Gpu;
use strict;
use warnings;

sub new {
    my ( $class, $gpu_id, $mem ) = @_;
    return bless {
        gpu_id => $gpu_id,
        mem    => $mem,
        job_id => undef,
    }, $class;
}

package Job;
use strict;
use warnings;

sub new {
    my ( $class, $job_id, $mem, $seq ) = @_;
    return bless {
        job_id   => $job_id,
        mem      => $mem,
        seq      => $seq,
        priority => 0,
        state    => 'queued',
        gpu_id   => undef,
    }, $class;
}

package Simulation;
use strict;
use warnings;

sub new {
    my ($class) = @_;
    return bless {
        gpus      => {},
        gpu_order => [],
        jobs      => {},
        next_seq  => 0,
    }, $class;
}

sub add_gpu {
    my ( $self, $gpu_id, $mem ) = @_;
    return 'invalid_request' if $mem <= 0;
    return 'false'           if exists $self->{gpus}{$gpu_id};
    $self->{gpus}{$gpu_id} = Gpu->new( $gpu_id, $mem );
    push @{ $self->{gpu_order} }, $gpu_id;
    return 'true';
}

sub submit_job {
    my ( $self, $job_id, $mem ) = @_;
    return 'invalid_request' if $mem <= 0;
    return 'false'           if exists $self->{jobs}{$job_id};
    $self->{jobs}{$job_id} = Job->new( $job_id, $mem, $self->{next_seq} );
    $self->{next_seq} += 1;
    return 'true';
}

sub status {
    my ( $self, $job_id ) = @_;
    my $job = $self->{jobs}{$job_id};
    return '' unless $job;
    return $job->{state};
}

sub _place {
    my ( $self, $job, $gpu ) = @_;
    $job->{state}  = 'running';
    $job->{gpu_id} = $gpu->{gpu_id};
    $gpu->{job_id} = $job->{job_id};
    return;
}

sub assign {
    my ($self) = @_;
    my @queued = grep { $_->{state} eq 'queued' } values %{ $self->{jobs} };
    @queued = sort { $b->{priority} <=> $a->{priority} || $a->{seq} <=> $b->{seq} } @queued;
    for my $job (@queued) {
        for my $gpu_id ( @{ $self->{gpu_order} } ) {
            my $gpu = $self->{gpus}{$gpu_id};
            next unless !defined $gpu->{job_id} && $gpu->{mem} >= $job->{mem};
            $self->_place( $job, $gpu );
            return $job->{job_id};
        }
    }
    return '';
}

sub complete {
    my ( $self, $job_id ) = @_;
    my $job = $self->{jobs}{$job_id};
    return 'invalid_request' if !$job || $job->{state} ne 'running' || !defined $job->{gpu_id};
    $self->{gpus}{ $job->{gpu_id} }{job_id} = undef;
    $job->{gpu_id} = undef;
    $job->{state}  = 'done';
    return 'true';
}

sub cancel {
    my ( $self, $job_id ) = @_;
    my $job = $self->{jobs}{$job_id};
    return 'invalid_request' if !$job || $job->{state} eq 'done';
    if ( $job->{state} eq 'running' && defined $job->{gpu_id} ) {
        $self->{gpus}{ $job->{gpu_id} }{job_id} = undef;
    }
    delete $self->{jobs}{$job_id};
    $self->assign if $job->{state} eq 'running';
    return 'true';
}

sub set_priority {
    my ( $self, $job_id, $priority ) = @_;
    my $job = $self->{jobs}{$job_id};
    return 'invalid_request' if !$job || $job->{state} ne 'queued';
    $job->{priority} = $priority;
    return 'true';
}

1;
