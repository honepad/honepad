package InMemoryDatabase;
use strict;
use warnings;

sub new {
    my ($class) = @_;
    return bless {
        database          => {},
        backup_timestamps => [],
        backup_states     => [],
    }, $class;
}

sub set_internal {
    my ( $self, $key, $field, $value, $expiry ) = @_;
    $self->{database}{$key} ||= {};
    $self->{database}{$key}{$field} = [ $value, $expiry ];
    return '';
}

sub alive {
    my ( $self, $key, $field, $timestamp ) = @_;
    return 0 unless exists $self->{database}{$key} && exists $self->{database}{$key}{$field};
    my $expiry = $self->{database}{$key}{$field}[1];
    return 1 if !defined $expiry;
    return $timestamp < $expiry;
}

sub set {
    my ( $self, $key, $field, $value ) = @_;
    return $self->set_internal( $key, $field, $value, undef );
}

sub get {
    my ( $self, $key, $field ) = @_;
    return '' unless exists $self->{database}{$key} && exists $self->{database}{$key}{$field};
    return $self->{database}{$key}{$field}[0];
}

sub delete {
    my ( $self, $key, $field ) = @_;
    return 'false' unless exists $self->{database}{$key} && exists $self->{database}{$key}{$field};
    delete $self->{database}{$key}{$field};
    return 'true';
}

sub scan {
    my ( $self, $key ) = @_;
    return '' unless exists $self->{database}{$key};
    return join ', ',
      map { "$_($self->{database}{$key}{$_}[0])" } sort keys %{ $self->{database}{$key} };
}

sub scan_by_prefix {
    my ( $self, $key, $prefix ) = @_;
    return '' unless exists $self->{database}{$key};
    return join ', ', map { "$_($self->{database}{$key}{$_}[0])" }
      sort grep { index( $_, $prefix ) == 0 } keys %{ $self->{database}{$key} };
}

sub set_at {
    my ( $self, $key, $field, $value, $timestamp ) = @_;
    return $self->set_internal( $key, $field, $value, undef );
}

sub set_at_with_ttl {
    my ( $self, $key, $field, $value, $timestamp, $ttl ) = @_;
    return $self->set_internal( $key, $field, $value, $timestamp + $ttl );
}

sub delete_at {
    my ( $self, $key, $field, $timestamp ) = @_;
    return 'false' unless $self->alive( $key, $field, $timestamp );
    delete $self->{database}{$key}{$field};
    return 'true';
}

sub get_at {
    my ( $self, $key, $field, $timestamp ) = @_;
    return '' unless $self->alive( $key, $field, $timestamp );
    return $self->{database}{$key}{$field}[0];
}

sub scan_at {
    my ( $self, $key, $timestamp ) = @_;
    return '' unless exists $self->{database}{$key};
    return join ', ', map { "$_($self->{database}{$key}{$_}[0])" }
      sort grep { $self->alive( $key, $_, $timestamp ) } keys %{ $self->{database}{$key} };
}

sub scan_by_prefix_at {
    my ( $self, $key, $prefix, $timestamp ) = @_;
    return '' unless exists $self->{database}{$key};
    return join ', ', map { "$_($self->{database}{$key}{$_}[0])" }
      sort grep { index( $_, $prefix ) == 0 && $self->alive( $key, $_, $timestamp ) }
      keys %{ $self->{database}{$key} };
}

sub backup {
    my ( $self, $timestamp ) = @_;
    my $state = {};
    for my $key ( keys %{ $self->{database} } ) {
        for my $field ( keys %{ $self->{database}{$key} } ) {
            next unless $self->alive( $key, $field, $timestamp );
            my ( $value, $expiry ) = @{ $self->{database}{$key}{$field} };
            my $remaining = defined $expiry ? $expiry - $timestamp : undef;
            $state->{$key} ||= {};
            $state->{$key}{$field} = [ $value, $remaining ];
        }
    }
    push @{ $self->{backup_timestamps} }, $timestamp;
    push @{ $self->{backup_states} },     $state;
    return '' . scalar keys %$state;
}

sub restore {
    my ( $self, $timestamp, $timestamp_to_restore ) = @_;
    my $idx = -1;
    for my $i ( 0 .. $#{ $self->{backup_timestamps} } ) {
        $idx = $i if $self->{backup_timestamps}[$i] <= $timestamp_to_restore;
    }
    my $backup_state = $self->{backup_states}[$idx];
    $self->{database} = {};
    for my $key ( keys %$backup_state ) {
        for my $field ( keys %{ $backup_state->{$key} } ) {
            my ( $value, $remaining ) = @{ $backup_state->{$key}{$field} };
            my $expiry = defined $remaining ? $timestamp + $remaining : undef;
            $self->set_internal( $key, $field, $value, $expiry );
        }
    }
    return '';
}

1;
