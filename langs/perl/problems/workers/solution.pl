package Worker;
use strict;
use warnings;

sub new {
    my ( $class, $worker_id, $position, $compensation ) = @_;
    return bless {
        worker_id     => $worker_id,
        position      => $position,
        compensation  => $compensation,
        in_office     => 0,
        entered_at    => undef,
        finished      => [],
        pending_promo => undef,
        double_pay    => [],
    }, $class;
}

sub total_time {
    my ($self) = @_;
    my $total = 0;
    for my $row ( @{ $self->{finished} } ) {
        $total += $row->[1] - $row->[0];
    }
    return $total;
}

sub position_time {
    my ( $self, $position ) = @_;
    my $total = 0;
    for my $row ( @{ $self->{finished} } ) {
        $total += $row->[1] - $row->[0] if $row->[3] eq $position;
    }
    return $total;
}

sub apply_promo_on_enter {
    my ( $self, $timestamp ) = @_;
    return unless $self->{pending_promo};
    my ( $new_pos, $new_comp, $start_ts ) = @{ $self->{pending_promo} };
    return if $timestamp < $start_ts;
    $self->{position}      = $new_pos;
    $self->{compensation}  = $new_comp;
    $self->{pending_promo} = undef;
    return;
}

package Simulation;
use strict;
use warnings;

sub new {
    my ($class) = @_;
    return bless { workers => {} }, $class;
}

sub add_worker {
    my ( $self, $worker_id, $position, $compensation ) = @_;
    return 'false' if exists $self->{workers}{$worker_id};
    $self->{workers}{$worker_id} = Worker->new( $worker_id, $position, $compensation );
    return 'true';
}

sub register {
    my ( $self, $worker_id, $timestamp ) = @_;
    my $worker = $self->{workers}{$worker_id};
    return 'invalid_request' unless $worker;
    if ( $worker->{in_office} ) {
        push @{ $worker->{finished} },
          [ $worker->{entered_at}, $timestamp, $worker->{compensation}, $worker->{position} ];
        $worker->{in_office}  = 0;
        $worker->{entered_at} = undef;
        return 'registered';
    }
    $worker->apply_promo_on_enter($timestamp);
    $worker->{in_office}  = 1;
    $worker->{entered_at} = $timestamp;
    return 'registered';
}

sub get {
    my ( $self, $worker_id ) = @_;
    my $worker = $self->{workers}{$worker_id};
    return '' unless $worker;
    return '' . $worker->total_time();
}

sub top_n_workers {
    my ( $self, $n, $position ) = @_;
    my @matched = grep { $_->{position} eq $position } values %{ $self->{workers} };
    @matched = sort {
             $b->position_time($position) <=> $a->position_time($position)
          || $a->{worker_id} cmp $b->{worker_id}
    } @matched;
    if ( @matched > $n ) {
        @matched = @matched[ 0 .. $n - 1 ];
    }
    return join ', ', map { "$_->{worker_id}(" . $_->position_time($position) . ')' } @matched;
}

sub promote {
    my ( $self, $worker_id, $new_position, $new_compensation, $start_timestamp ) = @_;
    my $worker = $self->{workers}{$worker_id};
    return 'invalid_request' if !$worker || defined $worker->{pending_promo};
    $worker->{pending_promo} = [ $new_position, $new_compensation, $start_timestamp ];
    return 'success';
}

sub set_double_pay {
    my ( $self, $worker_id, $interval_begin, $interval_end ) = @_;
    my $worker = $self->{workers}{$worker_id};
    return 'invalid_request' if !$worker || $interval_end <= $interval_begin;
    push @{ $worker->{double_pay} }, [ $interval_begin, $interval_end ];
    return 'true';
}

sub calc_salary {
    my ( $self, $worker_id, $start_timestamp, $end_timestamp ) = @_;
    my $worker = $self->{workers}{$worker_id};
    return '' unless $worker;
    my $total = 0;
    for my $row ( @{ $worker->{finished} } ) {
        my ( $session_start, $session_end, $rate ) = @$row;
        my $lo = $session_start > $start_timestamp ? $session_start : $start_timestamp;
        my $hi = $session_end < $end_timestamp     ? $session_end   : $end_timestamp;
        if ( $hi > $lo ) {
            my $bonus = bonus_overlap( $lo, $hi, $worker->{double_pay} );
            $total += ( $hi - $lo - $bonus ) * $rate + $bonus * $rate * 2;
        }
    }
    return '' . $total;
}

sub bonus_overlap {
    my ( $lo, $hi, $windows ) = @_;
    my @segs;
    for my $win (@$windows) {
        my $start = $lo > $win->[0] ? $lo : $win->[0];
        my $stop  = $hi < $win->[1] ? $hi : $win->[1];
        push @segs, [ $start, $stop ] if $stop > $start;
    }
    @segs = sort { $a->[0] <=> $b->[0] } @segs;
    my @merged;
    for my $seg (@segs) {
        if ( !@merged || $seg->[0] >= $merged[-1][1] ) {
            push @merged, [ $seg->[0], $seg->[1] ];
        }
        else {
            $merged[-1][1] = $merged[-1][1] > $seg->[1] ? $merged[-1][1] : $seg->[1];
        }
    }
    my $sum = 0;
    $sum += $_->[1] - $_->[0] for @merged;
    return $sum;
}

1;
