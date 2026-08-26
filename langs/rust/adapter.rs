mod ctor;
mod harness;
mod solution;

use crate::ctor::new_target;
use serde::Deserialize;
use serde_json::Value;
use std::env;
use std::fs;
use std::io::{self, Write};
use std::process;

#[derive(Deserialize)]
struct Call {
    m: String,
    a: Vec<Value>,
    e: Value,
}

#[derive(Deserialize)]
struct TestCase {
    id: String,
    calls: Vec<Call>,
}

#[derive(serde::Serialize)]
struct FailRow {
    case: String,
    index: usize,
    method: String,
    expected: Value,
    actual: Value,
}

#[derive(serde::Serialize)]
struct Report {
    passed: usize,
    failed: Vec<FailRow>,
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        eprintln!("usage: adapter cases.json");
        process::exit(2);
    }
    let data = match fs::read_to_string(&args[1]) {
        Ok(text) => text,
        Err(err) => {
            eprintln!("{err}");
            process::exit(2);
        }
    };
    let cases: Vec<TestCase> = match serde_json::from_str(&data) {
        Ok(parsed) => parsed,
        Err(err) => {
            eprintln!("{err}");
            process::exit(2);
        }
    };

    let mut failed = Vec::new();
    let mut passed = 0usize;
    for case in cases {
        let mut obj = new_target();
        let mut ok = true;
        for (i, call) in case.calls.iter().enumerate() {
            match obj.call(&call.m, &call.a) {
                Ok(actual) if actual == call.e => {}
                Ok(actual) => {
                    failed.push(FailRow {
                        case: case.id.clone(),
                        index: i,
                        method: call.m.clone(),
                        expected: call.e.clone(),
                        actual,
                    });
                    ok = false;
                    break;
                }
                Err(err) => {
                    failed.push(FailRow {
                        case: case.id.clone(),
                        index: i,
                        method: call.m.clone(),
                        expected: call.e.clone(),
                        actual: Value::String(format!("exc:{err}")),
                    });
                    ok = false;
                    break;
                }
            }
        }
        if ok {
            passed += 1;
        }
    }

    let nfail = failed.len();
    let report = Report { passed, failed };
    match serde_json::to_string(&report) {
        Ok(encoded) => {
            let _ = writeln!(io::stdout(), "{encoded}");
        }
        Err(err) => {
            eprintln!("{err}");
            process::exit(2);
        }
    }
    if nfail > 0 {
        process::exit(1);
    }
}
