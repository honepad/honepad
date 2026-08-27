#!/usr/bin/env perl
use strict;
use warnings;
use JSON::PP qw(encode_json decode_json);

sub json_safe {
    my ($value) = @_;
    return undef if !defined $value;
    return $value if JSON::PP::is_bool($value);
    my $ref = ref $value;
    if ( $ref eq 'ARRAY' ) {
        return [ map { json_safe($_) } @$value ];
    }
    if ( $ref eq 'HASH' ) {
        return { map { $_ => json_safe( $value->{$_} ) } keys %$value };
    }
    return $value;
}

sub load_solution {
    my ($file) = @_;
    my $ok = do $file;
    die "failed to load $file: $@" if $@;
    die "failed to load $file: $!" if !defined $ok && $!;
    return;
}

sub main {
    my ( $file, $class_name, $cases_path ) = @ARGV;
    load_solution($file);
    open my $fh, '<', $cases_path or die "failed to read $cases_path: $!";
    my $raw = do { local $/; <$fh> };
    close $fh;
    my $cases = decode_json($raw);
    my @failed;
    my $passed = 0;
    for my $case (@$cases) {
        my $obj = $class_name->new;
        my $ok  = 1;
        my $i   = 0;
        for my $call ( @{ $case->{calls} } ) {
            my $method   = $call->{m};
            my $args     = $call->{a};
            my $expected = $call->{e};
            my $actual;
            eval {
                $actual = $obj->$method(@$args);
                1;
            } or do {
                my $err = $@;
                $err =~ s/\s+\z//;
                $err =~ s/\s+at\s+\S+\s+line\s+\d+\.?\z//;
                push @failed,
                  {
                    case     => $case->{id},
                    index    => $i,
                    method   => $method,
                    expected => $expected,
                    actual   => "exc:$err",
                  };
                $ok = 0;
                last;
            };
            if ( encode_json( json_safe($actual) ) ne encode_json($expected) ) {
                push @failed,
                  {
                    case     => $case->{id},
                    index    => $i,
                    method   => $method,
                    expected => $expected,
                    actual   => json_safe($actual),
                  };
                $ok = 0;
                last;
            }
            $i += 1;
        }
        $passed += 1 if $ok;
    }
    print encode_json( { passed => $passed, failed => \@failed } ) . "\n";
    exit( @failed ? 1 : 0 );
}

main();
