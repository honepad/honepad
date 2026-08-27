package Simulation;
use strict;
use warnings;

sub new {
    my ($class) = @_;
    return bless {
        files    => {},
        order    => [],
        capacity => { admin => undef },
        backups  => {},
    }, $class;
}

sub used {
    my ( $self, $user_id ) = @_;
    my $total = 0;
    for my $name ( @{ $self->{order} } ) {
        my $item = $self->{files}{$name};
        $total += $item->{size} if $item->{owner} eq $user_id;
    }
    return $total;
}

sub remaining {
    my ( $self, $user_id ) = @_;
    return undef unless exists $self->{capacity}{$user_id};
    my $cap = $self->{capacity}{$user_id};
    return undef if !defined $cap;
    return $cap - $self->used($user_id);
}

sub _add {
    my ( $self, $name, $size, $owner ) = @_;
    $self->{files}{$name} = { name => $name, size => $size, owner => $owner };
    push @{ $self->{order} }, $name;
    return;
}

sub _delete_name {
    my ( $self, $name ) = @_;
    delete $self->{files}{$name};
    $self->{order} = [ grep { $_ ne $name } @{ $self->{order} } ];
    return;
}

sub add_file {
    my ( $self, $name, $size ) = @_;
    return 'false' if exists $self->{files}{$name};
    $self->_add( $name, $size, 'admin' );
    return 'true';
}

sub get_file_size {
    my ( $self, $name ) = @_;
    my $item = $self->{files}{$name};
    return $item ? '' . $item->{size} : '';
}

sub delete_file {
    my ( $self, $name ) = @_;
    my $item = $self->{files}{$name};
    return '' unless $item;
    my $size = $item->{size};
    $self->_delete_name($name);
    return '' . $size;
}

sub copy_file {
    my ( $self, $source, $dest ) = @_;
    my $src = $self->{files}{$source};
    return '' unless $src;
    return '' . $src->{size} if $source eq $dest;
    my $dest_item = $self->{files}{$dest};
    my $owner     = $dest_item ? $dest_item->{owner} : $src->{owner};
    my $extra     = $dest_item ? $src->{size} - $dest_item->{size} : $src->{size};
    my $left      = $self->remaining($owner);
    return '' if defined $left && $extra > $left;
    if ( !$dest_item ) {
        $self->_add( $dest, $src->{size}, $owner );
    }
    else {
        $dest_item->{size} = $src->{size};
    }
    return '' . $src->{size};
}

sub get_n_largest {
    my ( $self, $prefix, $n ) = @_;
    my @matched =
      grep { index( $_->{name}, $prefix ) == 0 } map { $self->{files}{$_} } @{ $self->{order} };
    @matched = sort { $b->{size} <=> $a->{size} || $a->{name} cmp $b->{name} } @matched;
    if ( @matched > $n ) {
        @matched = @matched[ 0 .. $n - 1 ];
    }
    return join ', ', map { "$_->{name}($_->{size})" } @matched;
}

sub add_user {
    my ( $self, $user_id, $capacity ) = @_;
    return 'false' if exists $self->{capacity}{$user_id};
    $self->{capacity}{$user_id} = $capacity;
    return 'true';
}

sub add_file_by {
    my ( $self, $user_id, $name, $size ) = @_;
    return '' unless exists $self->{capacity}{$user_id} && !exists $self->{files}{$name};
    my $left = $self->remaining($user_id);
    return '' if defined $left && $size > $left;
    $self->_add( $name, $size, $user_id );
    $left = $self->remaining($user_id);
    return defined $left ? '' . $left : '';
}

sub merge_user {
    my ( $self, $user_id1, $user_id2 ) = @_;
    return '' if $user_id1 eq $user_id2;
    return '' unless exists $self->{capacity}{$user_id1} && exists $self->{capacity}{$user_id2};
    my $cap1 = $self->{capacity}{$user_id1};
    my $cap2 = $self->{capacity}{$user_id2};
    return '' if !defined $cap1 || !defined $cap2;
    $self->{capacity}{$user_id1} = $cap1 + $cap2;
    for my $name ( @{ $self->{order} } ) {
        my $item = $self->{files}{$name};
        $item->{owner} = $user_id1 if $item->{owner} eq $user_id2;
    }
    delete $self->{capacity}{$user_id2};
    delete $self->{backups}{$user_id2};
    my $left = $self->remaining($user_id1);
    return defined $left ? '' . $left : '';
}

sub backup_user {
    my ( $self, $user_id ) = @_;
    return '' unless exists $self->{capacity}{$user_id};
    my @snap;
    for my $name ( @{ $self->{order} } ) {
        my $item = $self->{files}{$name};
        next unless $item->{owner} eq $user_id;
        push @snap, [ $name, $item->{size} ];
    }
    $self->{backups}{$user_id} = \@snap;
    return '' . scalar @snap;
}

sub restore_user {
    my ( $self, $user_id ) = @_;
    return '' unless exists $self->{capacity}{$user_id};
    my @keep;
    for my $name ( @{ $self->{order} } ) {
        my $item = $self->{files}{$name};
        if ( $item->{owner} eq $user_id ) {
            delete $self->{files}{$name};
        }
        else {
            push @keep, $name;
        }
    }
    $self->{order} = \@keep;
    my $snapshot = $self->{backups}{$user_id};
    return '0' unless $snapshot;
    my $restored = 0;
    for my $row (@$snapshot) {
        my ( $name, $size ) = @$row;
        next if exists $self->{files}{$name};
        my $left = $self->remaining($user_id);
        next if defined $left && $size > $left;
        $self->_add( $name, $size, $user_id );
        $restored += 1;
    }
    return '' . $restored;
}

1;
