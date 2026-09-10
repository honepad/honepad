package Simulation;
use strict;
use warnings;

sub new {
    my ($class) = @_;
    return bless {
        subs      => {},
        inbox_map => {},
        retained  => {},
    }, $class;
}

sub subscribe {
    my ( $self, $topic, $client ) = @_;
    my $clients = $self->{subs}{$topic} ||= [];
    return 'false' if grep { $_ eq $client } @$clients;
    push @$clients, $client;
    if ( exists $self->{retained}{$topic} ) {
        push @{ $self->{inbox_map}{$client} ||= [] }, "$topic:$self->{retained}{$topic}";
    }
    return 'true';
}

sub unsubscribe {
    my ( $self, $topic, $client ) = @_;
    my $clients = $self->{subs}{$topic};
    return 'false' unless $clients && grep { $_ eq $client } @$clients;
    @$clients = grep { $_ ne $client } @$clients;
    delete $self->{subs}{$topic} unless @$clients;
    return 'true';
}

sub publish {
    my ( $self, $topic, $message ) = @_;
    my $clients = $self->{subs}{$topic} || [];
    my $payload = "$topic:$message";
    for my $client (@$clients) {
        push @{ $self->{inbox_map}{$client} ||= [] }, $payload;
    }
    return '' . scalar @$clients;
}

sub inbox {
    my ( $self, $client ) = @_;
    my $items = $self->{inbox_map}{$client} || [];
    return join ', ', @$items;
}

sub list_topics {
    my ($self) = @_;
    return join ', ', sort keys %{ $self->{subs} };
}

sub subscribers {
    my ( $self, $topic ) = @_;
    my $clients = $self->{subs}{$topic} || [];
    return join ', ', sort @$clients;
}

sub peek {
    my ( $self, $client ) = @_;
    my $items = $self->{inbox_map}{$client} || [];
    return @$items ? $items->[0] : '';
}

sub ack {
    my ( $self, $client, $n ) = @_;
    return 'invalid_request' if $n <= 0 || !exists $self->{inbox_map}{$client};
    my $items = $self->{inbox_map}{$client};
    return 'invalid_request' if $n > @$items;
    splice @$items, 0, $n;
    return '' . scalar @$items;
}

sub retain {
    my ( $self, $topic, $message ) = @_;
    $self->{retained}{$topic} = $message;
    return '';
}

1;
