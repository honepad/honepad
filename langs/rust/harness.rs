use serde_json::Value;

pub trait Harness {
    fn call(&mut self, method: &str, args: &[Value]) -> Result<Value, String>;
}

pub fn arg_i64(args: &[Value], i: usize) -> Result<i64, String> {
    let value = args.get(i).ok_or_else(|| format!("missing arg {i}"))?;
    if let Some(n) = value.as_i64() {
        return Ok(n);
    }
    if let Some(n) = value.as_u64() {
        return i64::try_from(n).map_err(|_| format!("arg {i} overflow: {value}"));
    }
    if let Some(f) = value.as_f64() {
        if f.fract() == 0.0 {
            return Ok(f as i64);
        }
    }
    Err(format!("arg {i} is not i64: {value}"))
}

pub fn arg_str(args: &[Value], i: usize) -> Result<String, String> {
    let value = args.get(i).ok_or_else(|| format!("missing arg {i}"))?;
    value
        .as_str()
        .map(str::to_string)
        .ok_or_else(|| format!("arg {i} is not string: {value}"))
}

pub fn opt_i64(value: Option<i64>) -> Value {
    match value {
        Some(n) => Value::from(n),
        None => Value::Null,
    }
}

pub fn opt_str(value: Option<String>) -> Value {
    match value {
        Some(s) => Value::String(s),
        None => Value::Null,
    }
}
