package Item;
use strict;
use warnings;

sub new {
    my ( $class, $sku, $name ) = @_;
    return bless {
        sku      => $sku,
        name     => $name,
        qty      => 0,
        reserved => 0,
    }, $class;
}

package Simulation;
use strict;
use warnings;

sub new {
    my ($class) = @_;
    return bless { items => {} }, $class;
}

sub create_item {
    my ( $self, $sku, $name ) = @_;
    return 'false' if exists $self->{items}{$sku};
    $self->{items}{$sku} = Item->new( $sku, $name );
    return 'true';
}

sub stock {
    my ( $self, $sku, $delta ) = @_;
    my $item = $self->{items}{$sku};
    return '' unless $item;
    my $nxt = $item->{qty} + $delta;
    return 'invalid_request' if $nxt < $item->{reserved};
    $item->{qty} = $nxt;
    return '' . $item->{qty};
}

sub get_qty {
    my ( $self, $sku ) = @_;
    my $item = $self->{items}{$sku};
    return '' unless $item;
    return '' . $item->{qty};
}

sub list_low {
    my ( $self, $threshold ) = @_;
    my @matched = grep { $_->{qty} <= $threshold } values %{ $self->{items} };
    @matched = sort {
             $a->{qty} <=> $b->{qty}
          || $a->{sku} cmp $b->{sku}
    } @matched;
    return join ', ', map { "$_->{sku}($_->{qty})" } @matched;
}

sub reserve {
    my ( $self, $sku, $n ) = @_;
    my $item = $self->{items}{$sku};
    return 'invalid_request' if !$item || $n <= 0 || $item->{reserved} + $n > $item->{qty};
    $item->{reserved} += $n;
    return 'true';
}

sub release {
    my ( $self, $sku, $n ) = @_;
    my $item = $self->{items}{$sku};
    return 'invalid_request' if !$item || $n <= 0 || $n > $item->{reserved};
    $item->{reserved} -= $n;
    return 'true';
}

sub ship {
    my ( $self, $sku, $n ) = @_;
    my $item = $self->{items}{$sku};
    return 'invalid_request' if !$item || $n <= 0 || $n > $item->{reserved};
    $item->{reserved} -= $n;
    $item->{qty}      -= $n;
    return 'true';
}

1;
