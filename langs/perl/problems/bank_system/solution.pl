package Account;
use strict;
use warnings;

sub new {
    my ( $class, $account_id, $created_at ) = @_;
    return bless {
        account_id      => $account_id,
        balance         => 0,
        outgoing        => 0,
        payments        => {},
        created_at      => $created_at,
        balance_history => [ [ $created_at, 0 ] ],
    }, $class;
}

sub record_balance {
    my ( $self, $timestamp ) = @_;
    push @{ $self->{balance_history} }, [ $timestamp, $self->{balance} ];
    return;
}

sub deposit {
    my ( $self, $amount ) = @_;
    $self->{balance} += $amount;
    return $self->{balance};
}

sub withdraw {
    my ( $self, $amount ) = @_;
    return 0 if $self->{balance} < $amount;
    $self->{balance}  -= $amount;
    $self->{outgoing} += $amount;
    return 1;
}

sub get_balance_at {
    my ( $self, $time_at ) = @_;
    return undef if $time_at < $self->{created_at};
    my $result;
    for my $row ( @{ $self->{balance_history} } ) {
        last if $row->[0] > $time_at;
        $result = $row->[1];
    }
    return $result;
}

package Simulation;
use strict;
use warnings;
use JSON::PP ();

my $CASHBACK_DELAY = 24 * 60 * 60 * 1000;

sub new {
    my ($class) = @_;
    return bless {
        accounts          => {},
        payment_counter   => 0,
        pending_cashbacks => [],
    }, $class;
}

sub process_cashbacks {
    my ( $self, $timestamp ) = @_;
    my $pending = $self->{pending_cashbacks};
    while ( @$pending && $pending->[0][0] <= $timestamp ) {
        my ( $cb_timestamp, $account_id, $amount, $payment_id ) = @{ shift @$pending };
        my $account = $self->{accounts}{$account_id};
        next unless $account;
        $account->deposit($amount);
        $account->{payments}{$payment_id} = 'CASHBACK_RECEIVED';
        $account->record_balance($cb_timestamp);
    }
    return;
}

sub create_account {
    my ( $self, $timestamp, $account_id ) = @_;
    $self->process_cashbacks($timestamp);
    return JSON::PP::false if exists $self->{accounts}{$account_id};
    $self->{accounts}{$account_id} = Account->new( $account_id, $timestamp );
    return JSON::PP::true;
}

sub deposit {
    my ( $self, $timestamp, $account_id, $amount ) = @_;
    $self->process_cashbacks($timestamp);
    my $account = $self->{accounts}{$account_id};
    return undef unless $account;
    my $result = $account->deposit($amount);
    $account->record_balance($timestamp);
    return $result;
}

sub transfer {
    my ( $self, $timestamp, $source_account_id, $target_account_id, $amount ) = @_;
    $self->process_cashbacks($timestamp);
    return undef
      unless exists $self->{accounts}{$source_account_id}
      && exists $self->{accounts}{$target_account_id};
    return undef if $source_account_id eq $target_account_id;
    my $source = $self->{accounts}{$source_account_id};
    my $target = $self->{accounts}{$target_account_id};
    return undef unless $source->withdraw($amount);
    $target->deposit($amount);
    $source->record_balance($timestamp);
    $target->record_balance($timestamp);
    return $source->{balance};
}

sub top_spenders {
    my ( $self, $timestamp, $n ) = @_;
    $self->process_cashbacks($timestamp);
    my @ordered = sort {
             $self->{accounts}{$b}{outgoing} <=> $self->{accounts}{$a}{outgoing}
          || $a cmp $b
    } keys %{ $self->{accounts} };
    if ( @ordered > $n ) {
        @ordered = @ordered[ 0 .. $n - 1 ];
    }
    return [ map { "$_($self->{accounts}{$_}{outgoing})" } @ordered ];
}

sub pay {
    my ( $self, $timestamp, $account_id, $amount ) = @_;
    $self->process_cashbacks($timestamp);
    my $account = $self->{accounts}{$account_id};
    return undef unless $account;
    return undef unless $account->withdraw($amount);
    $self->{payment_counter} += 1;
    my $payment_id = 'payment' . $self->{payment_counter};
    $account->{payments}{$payment_id} = 'IN_PROGRESS';
    $account->record_balance($timestamp);
    my $cashback_amount = int( $amount * 2 / 100 );
    push @{ $self->{pending_cashbacks} },
      [ $timestamp + $CASHBACK_DELAY, $account_id, $cashback_amount, $payment_id ];
    return $payment_id;
}

sub get_payment_status {
    my ( $self, $timestamp, $account_id, $payment ) = @_;
    $self->process_cashbacks($timestamp);
    my $account = $self->{accounts}{$account_id};
    return undef unless $account;
    return $account->{payments}{$payment};
}

sub merge_accounts {
    my ( $self, $timestamp, $account_id_1, $account_id_2 ) = @_;
    $self->process_cashbacks($timestamp);
    return JSON::PP::false if $account_id_1 eq $account_id_2;
    return JSON::PP::false
      unless exists $self->{accounts}{$account_id_1}
      && exists $self->{accounts}{$account_id_2};
    my $account1 = $self->{accounts}{$account_id_1};
    my $account2 = $self->{accounts}{$account_id_2};
    $account1->{balance}  += $account2->{balance};
    $account1->{outgoing} += $account2->{outgoing};
    for my $payment_id ( keys %{ $account2->{payments} } ) {
        $account1->{payments}{$payment_id} = $account2->{payments}{$payment_id};
    }
    push @{ $account1->{balance_history} }, @{ $account2->{balance_history} };
    @{ $account1->{balance_history} } =
      sort { $a->[0] <=> $b->[0] } @{ $account1->{balance_history} };
    $account1->{created_at} =
        $account1->{created_at} < $account2->{created_at}
      ? $account1->{created_at}
      : $account2->{created_at};
    $account1->record_balance($timestamp);
    for my $cb ( @{ $self->{pending_cashbacks} } ) {
        $cb->[1] = $account_id_1 if $cb->[1] eq $account_id_2;
    }
    delete $self->{accounts}{$account_id_2};
    return JSON::PP::true;
}

sub get_balance {
    my ( $self, $timestamp, $account_id, $time_at ) = @_;
    $self->process_cashbacks($timestamp);
    my $account = $self->{accounts}{$account_id};
    return undef unless $account;
    return $account->get_balance_at($time_at);
}

1;
