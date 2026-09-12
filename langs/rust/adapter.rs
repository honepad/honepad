mod ctor;
mod harness;
mod solution;

use crate::ctor::new_target;
use serde::Deserialize;
use serde_json::Value;
use std::env;
use std::fs;
use std::fs::File;
use std::io::Write;
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

fn sink_stdout() -> File {
    #[cfg(unix)]
    {
        use std::os::fd::{AsRawFd, FromRawFd};
        extern "C" {
            fn dup(fd: i32) -> i32;
            fn dup2(oldfd: i32, newfd: i32) -> i32;
        }
        let saved = unsafe { dup(1) };
        if saved < 0 {
            eprintln!("failed to dup stdout");
            process::exit(2);
        }
        let null = File::options().write(true).open("/dev/null").unwrap_or_else(|err| {
            eprintln!("{err}");
            process::exit(2);
        });
        if unsafe { dup2(null.as_raw_fd(), 1) } < 0 {
            eprintln!("failed to sink stdout");
            process::exit(2);
        }
        std::mem::forget(null);
        return unsafe { File::from_raw_fd(saved) };
    }
    #[cfg(windows)]
    {
        use std::os::windows::io::{AsRawHandle, FromRawHandle};
        extern "system" {
            fn GetStdHandle(n_std_handle: i32) -> isize;
            fn SetStdHandle(n_std_handle: i32, handle: isize) -> i32;
            fn GetCurrentProcess() -> isize;
            fn DuplicateHandle(
                source_process: isize,
                source: isize,
                target_process: isize,
                target: *mut isize,
                desired_access: u32,
                inherit: i32,
                options: u32,
            ) -> i32;
        }
        const STD_OUTPUT_HANDLE: i32 = -11;
        const DUPLICATE_SAME_ACCESS: u32 = 2;
        let handle = unsafe { GetStdHandle(STD_OUTPUT_HANDLE) };
        let proc = unsafe { GetCurrentProcess() };
        let mut duped = 0isize;
        if unsafe {
            DuplicateHandle(proc, handle, proc, &mut duped, 0, 1, DUPLICATE_SAME_ACCESS)
        } == 0
        {
            eprintln!("failed to dup stdout");
            process::exit(2);
        }
        let null = File::options().write(true).open("NUL").unwrap_or_else(|err| {
            eprintln!("{err}");
            process::exit(2);
        });
        if unsafe { SetStdHandle(STD_OUTPUT_HANDLE, null.as_raw_handle() as isize) } == 0 {
            eprintln!("failed to sink stdout");
            process::exit(2);
        }
        std::mem::forget(null);
        return unsafe { File::from_raw_handle(duped as _) };
    }
    #[cfg(not(any(unix, windows)))]
    {
        eprintln!("stdout sink is not supported on this platform");
        process::exit(2);
    }
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        eprintln!("usage: adapter cases.json");
        process::exit(2);
    }
    let mut report_out = sink_stdout();
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
            let _ = writeln!(report_out, "{encoded}");
            let _ = report_out.flush();
        }
        Err(err) => {
            eprintln!("{err}");
            process::exit(2);
        }
    }
    if nfail > 0 {
        process::exit(1);
    }
    process::exit(0);
}
