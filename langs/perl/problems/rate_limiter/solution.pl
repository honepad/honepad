package KeyState;
use strict;
use warnings;

sub new {
    my ($class) = @_;
    return bless {
        limit     => 3,
        window    => 10,
        window_id => undef,
        used      => 0,
    }, $class;
}

package Simulation;
use strict;
use warnings;

sub new {
    my ($class) = @_;
    return bless { keys => {} }, $class;
}

sub _state {
    my ( $self, $key ) = @_;
    $self->{keys}{$key} ||= KeyState->new;
    return $self->{keys}{$key};
}

sub _used_at {
    my ( $self, $item, $timestamp, $persist ) = @_;
    my $window_id = int( $timestamp / $item->{window} );
    if ( !defined $item->{window_id} || $window_id != $item->{window_id} ) {
        if ($persist) {
            $item->{window_id} = $window_id;
            $item->{used}      = 0;
        }
        return 0;
    }
    return $item->{used};
}

sub allow {
    my ( $self, $key, $timestamp ) = @_;
    return $self->allow_weighted( $key, 1, $timestamp );
}

sub configure {
    my ( $self, $key, $limit, $window ) = @_;
    return 'invalid_request' if $limit <= 0 || $window <= 0;
    my $item = $self->_state($key);
    $item->{limit}     = $limit;
    $item->{window}    = $window;
    $item->{window_id} = undef;
    $item->{used}      = 0;
    return 'true';
}

sub remaining {
    my ( $self, $key, $timestamp ) = @_;
    my $item = $self->_state($key);
    my $used = $self->_used_at( $item, $timestamp, 0 );
    return '' . ( $item->{limit} - $used );
}

sub allow_weighted {
    my ( $self, $key, $cost, $timestamp ) = @_;
    return 'invalid_request' if $cost <= 0;
    my $item = $self->_state($key);
    $self->_used_at( $item, $timestamp, 1 );
    return 'false' if $item->{used} + $cost > $item->{limit};
    $item->{used} += $cost;
    return 'true';
}

1;
