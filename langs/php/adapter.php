#!/usr/bin/env php
<?php

function honepad_nonfinite($value): bool
{
    if (is_float($value)) {
        return !is_finite($value);
    }
    if (is_array($value)) {
        foreach ($value as $item) {
            if (honepad_nonfinite($item)) {
                return true;
            }
        }
    }
    if (is_object($value)) {
        foreach (get_object_vars($value) as $item) {
            if (honepad_nonfinite($item)) {
                return true;
            }
        }
    }
    return false;
}

function honepad_tag($value)
{
    if (is_float($value)) {
        if (is_nan($value)) {
            return 'NaN';
        }
        if (is_infinite($value)) {
            return $value > 0 ? 'Infinity' : '-Infinity';
        }
    }
    if (is_array($value)) {
        foreach ($value as $key => $item) {
            $value[$key] = honepad_tag($item);
        }
    }
    if (is_object($value)) {
        $out = [];
        foreach (get_object_vars($value) as $key => $item) {
            $out[$key] = honepad_tag($item);
        }
        return $out;
    }
    return $value;
}

$solutionPath = $argv[1];
$className = $argv[2];
$casesPath = $argv[3];

$origStdout = fopen('php://stdout', 'w');
ob_start(static function ($buffer) {
    return '';
});

require $solutionPath;

$cases = json_decode(file_get_contents($casesPath), true);
$failed = [];
$passed = 0;

foreach ($cases as $c) {
    $obj = new $className();
    $ok = true;
    foreach ($c['calls'] as $i => $call) {
        $method = $call['m'];
        if (str_contains($method, '_')) {
            $parts = explode('_', $method);
            $name = $parts[0];
            for ($p = 1; $p < count($parts); $p++) {
                $name .= ucfirst($parts[$p]);
            }
        } else {
            $name = $method;
        }
        $args = $call['a'];
        $expected = $call['e'];
        try {
            $actual = $obj->$name(...$args);
        } catch (Throwable $err) {
            $failed[] = [
                'case' => $c['id'],
                'index' => $i,
                'method' => $method,
                'expected' => $expected,
                'actual' => 'exc:' . $err::class,
            ];
            $ok = false;
            break;
        }
        $bad = honepad_nonfinite($actual);
        $flags = JSON_INVALID_UTF8_SUBSTITUTE;
        if ($bad || json_encode($actual, $flags) !== json_encode($expected, $flags)) {
            $failed[] = [
                'case' => $c['id'],
                'index' => $i,
                'method' => $method,
                'expected' => $expected,
                'actual' => $bad ? honepad_tag($actual) : $actual,
            ];
            $ok = false;
            break;
        }
    }
    if ($ok) {
        $passed += 1;
    }
}

fwrite(
    $origStdout,
    json_encode(
        ['passed' => $passed, 'failed' => $failed],
        JSON_INVALID_UTF8_SUBSTITUTE
    ) . "\n"
);
exit($failed === [] ? 0 : 1);
