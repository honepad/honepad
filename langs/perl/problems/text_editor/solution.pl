package Simulation;
use strict;
use warnings;

sub new {
    my ($class) = @_;
    return bless {
        buf        => '',
        pos        => 0,
        undo_stack => [],
        redo_stack => [],
        sel        => undef,
        clip       => '',
    }, $class;
}

sub _push {
    my ($self) = @_;
    push @{ $self->{undo_stack} }, [ $self->{buf}, $self->{pos} ];
    $self->{redo_stack} = [];
    $self->{sel}        = undef;
}

sub insert {
    my ( $self, $pos, $text ) = @_;
    return 'invalid_request' if $pos < 0 || $pos > length $self->{buf};
    $self->_push;
    substr( $self->{buf}, $pos, 0 ) = $text;
    return '' . length $self->{buf};
}

sub erase {
    my ( $self, $pos, $n ) = @_;
    return 'invalid_request'
      if $n <= 0 || $pos < 0 || $pos + $n > length $self->{buf};
    $self->_push;
    my $deleted = substr( $self->{buf}, $pos, $n );
    substr( $self->{buf}, $pos, $n ) = '';
    $self->{pos} = length $self->{buf} if $self->{pos} > length $self->{buf};
    return $deleted;
}

sub get_text {
    my ($self) = @_;
    return $self->{buf};
}

sub length {
    my ($self) = @_;
    return '' . length $self->{buf};
}

sub move {
    my ( $self, $pos ) = @_;
    return 'invalid_request' if $pos < 0 || $pos > length $self->{buf};
    $self->{pos} = $pos;
    return 'true';
}

sub type_text {
    my ( $self, $text ) = @_;
    $self->_push;
    my $at = $self->{pos};
    substr( $self->{buf}, $at, 0 ) = $text;
    $self->{pos} = $at + length $text;
    return '' . length $self->{buf};
}

sub cursor {
    my ($self) = @_;
    return '' . $self->{pos};
}

sub undo {
    my ($self) = @_;
    return 'false' unless @{ $self->{undo_stack} };
    push @{ $self->{redo_stack} }, [ $self->{buf}, $self->{pos} ];
    my $snap = pop @{ $self->{undo_stack} };
    $self->{buf} = $snap->[0];
    $self->{pos} = $snap->[1];
    $self->{sel} = undef;
    return 'true';
}

sub redo {
    my ($self) = @_;
    return 'false' unless @{ $self->{redo_stack} };
    push @{ $self->{undo_stack} }, [ $self->{buf}, $self->{pos} ];
    my $snap = pop @{ $self->{redo_stack} };
    $self->{buf} = $snap->[0];
    $self->{pos} = $snap->[1];
    $self->{sel} = undef;
    return 'true';
}

sub select {
    my ( $self, $start, $end ) = @_;
    return 'invalid_request'
      if $start < 0 || $end < 0 || $start > $end || $end > length $self->{buf};
    $self->{sel} = [ $start, $end ];
    return 'true';
}

sub cut {
    my ($self) = @_;
    return 'invalid_request'
      if !defined $self->{sel} || $self->{sel}[0] == $self->{sel}[1];
    my ( $start, $end ) = @{ $self->{sel} };
    my $text = substr( $self->{buf}, $start, $end - $start );
    substr( $self->{buf}, $start, $end - $start ) = '';
    $self->{clip} = $text;
    $self->{pos}  = $start;
    $self->{sel}  = undef;
    return $text;
}

sub copy_sel {
    my ($self) = @_;
    return 'invalid_request'
      if !defined $self->{sel} || $self->{sel}[0] == $self->{sel}[1];
    my ( $start, $end ) = @{ $self->{sel} };
    $self->{clip} = substr( $self->{buf}, $start, $end - $start );
    return $self->{clip};
}

sub paste {
    my ($self) = @_;
    return 'invalid_request' if $self->{clip} eq '';
    my $at = $self->{pos};
    substr( $self->{buf}, $at, 0 ) = $self->{clip};
    $self->{pos} = $at + length $self->{clip};
    return '' . length $self->{buf};
}

1;
