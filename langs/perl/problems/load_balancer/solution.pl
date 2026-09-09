package Backend;
use strict;
use warnings;

sub new {
    my ( $class, $backend_id ) = @_;
    return bless {
        backend_id => $backend_id,
        health     => 1,
        weight     => 1,
        inflight   => 0,
    }, $class;
}

package Simulation;
use strict;
use warnings;

sub new {
    my ($class) = @_;
    return bless {
        backends   => [],
        by_id      => {},
        cursor     => 0,
        sticky_map => {},
        use_least  => 0,
    }, $class;
}

sub add_backend {
    my ( $self, $backend_id ) = @_;
    return 'false' if exists $self->{by_id}{$backend_id};
    my $item = Backend->new($backend_id);
    push @{ $self->{backends} }, $item;
    $self->{by_id}{$backend_id} = $item;
    return 'true';
}

sub set_health {
    my ( $self, $backend_id, $flag ) = @_;
    my $item = $self->{by_id}{$backend_id};
    return 'invalid_request' if !$item || ( $flag != 0 && $flag != 1 );
    $item->{health} = $flag == 1 ? 1 : 0;
    $self->_reset_cycle;
    return 'true';
}

sub set_weight {
    my ( $self, $backend_id, $weight ) = @_;
    my $item = $self->{by_id}{$backend_id};
    return 'invalid_request' if !$item || $weight <= 0;
    $item->{weight} = $weight;
    $self->_reset_cycle;
    return 'true';
}

sub route {
    my ($self) = @_;
    return $self->_take;
}

sub sticky {
    my ( $self, $client_id ) = @_;
    my $bound = $self->{sticky_map}{$client_id};
    my $item  = defined $bound ? $self->{by_id}{$bound} : undef;
    if ( $item && $item->{health} ) {
        $item->{inflight} += 1;
        return $item->{backend_id};
    }
    my $chosen = $self->_take;
    $self->{sticky_map}{$client_id} = $chosen if $chosen ne '';
    return $chosen;
}

sub done {
    my ( $self, $backend_id ) = @_;
    my $item = $self->{by_id}{$backend_id};
    return 'invalid_request' if !$item || $item->{inflight} <= 0;
    $item->{inflight} -= 1;
    $self->{use_least} = 1;
    return 'true';
}

sub _reset_cycle {
    my ($self) = @_;
    $self->{cursor}    = 0;
    $self->{use_least} = 0;
    for my $item ( @{ $self->{backends} } ) {
        $item->{inflight} = 0;
    }
    return;
}

sub _tickets {
    my ( $self, $items ) = @_;
    my @tickets;
    for my $item (@$items) {
        push @tickets, ($item) x $item->{weight};
    }
    return @tickets;
}

sub _pick {
    my ($self) = @_;
    my @healthy = grep { $_->{health} } @{ $self->{backends} };
    return undef unless @healthy;
    my @pool = @healthy;
    if ( $self->{use_least} ) {
        my $least = $healthy[0]{inflight};
        for my $item (@healthy) {
            $least = $item->{inflight} if $item->{inflight} < $least;
        }
        @pool = grep { $_->{inflight} == $least } @healthy;
    }
    my @tickets = $self->_tickets( \@pool );
    return undef unless @tickets;
    my $chosen = $tickets[ $self->{cursor} % @tickets ];
    $self->{cursor} += 1;
    return $chosen;
}

sub _take {
    my ($self) = @_;
    my $item = $self->_pick;
    return '' unless $item;
    $item->{inflight} += 1;
    return $item->{backend_id};
}

1;
