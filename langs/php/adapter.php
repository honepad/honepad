#!/usr/bin/env php
<?php

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
        if (json_encode($actual) !== json_encode($expected)) {
            $failed[] = [
                'case' => $c['id'],
                'index' => $i,
                'method' => $method,
                'expected' => $expected,
                'actual' => $actual,
            ];
            $ok = false;
            break;
        }
    }
    if ($ok) {
        $passed += 1;
    }
}

fwrite($origStdout, json_encode(['passed' => $passed, 'failed' => $failed]) . "\n");
exit($failed === [] ? 0 : 1);
