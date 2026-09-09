use crate::harness::{arg_i64, arg_str, Harness};
use serde_json::Value;
use std::collections::HashMap;

struct KeyState {
    limit: i64,
    window: i64,
    window_id: Option<i64>,
    used: i64,
}

impl KeyState {
    fn new() -> Self {
        Self {
            limit: 3,
            window: 10,
            window_id: None,
            used: 0,
        }
    }
}

pub struct Simulation {
    keys: HashMap<String, KeyState>,
}

impl Simulation {
    pub fn new() -> Self {
        Self {
            keys: HashMap::new(),
        }
    }

    fn state(&mut self, key: &str) -> &mut KeyState {
        self.keys
            .entry(key.to_string())
            .or_insert_with(KeyState::new)
    }

    fn used_at(item: &mut KeyState, timestamp: i64, persist: bool) -> i64 {
        let window_id = timestamp / item.window;
        if item.window_id != Some(window_id) {
            if persist {
                item.window_id = Some(window_id);
                item.used = 0;
            }
            return 0;
        }
        item.used
    }

    fn allow(&mut self, key: &str, timestamp: i64) -> String {
        self.allow_weighted(key, 1, timestamp)
    }

    fn configure(&mut self, key: &str, limit: i64, window: i64) -> String {
        if limit <= 0 || window <= 0 {
            return "invalid_request".to_string();
        }
        let item = self.state(key);
        item.limit = limit;
        item.window = window;
        item.window_id = None;
        item.used = 0;
        "true".to_string()
    }

    fn remaining(&mut self, key: &str, timestamp: i64) -> String {
        let item = self.state(key);
        let used = Self::used_at(item, timestamp, false);
        (item.limit - used).to_string()
    }

    fn allow_weighted(&mut self, key: &str, cost: i64, timestamp: i64) -> String {
        if cost <= 0 {
            return "invalid_request".to_string();
        }
        let item = self.state(key);
        Self::used_at(item, timestamp, true);
        if item.used + cost > item.limit {
            return "false".to_string();
        }
        item.used += cost;
        "true".to_string()
    }
}

impl Harness for Simulation {
    fn call(&mut self, method: &str, args: &[Value]) -> Result<Value, String> {
        let text = match method {
            "allow" => self.allow(&arg_str(args, 0)?, arg_i64(args, 1)?),
            "configure" => self.configure(&arg_str(args, 0)?, arg_i64(args, 1)?, arg_i64(args, 2)?),
            "remaining" => self.remaining(&arg_str(args, 0)?, arg_i64(args, 1)?),
            "allow_weighted" => {
                self.allow_weighted(&arg_str(args, 0)?, arg_i64(args, 1)?, arg_i64(args, 2)?)
            }
            other => return Err(format!("missing method {other}")),
        };
        Ok(Value::String(text))
    }
}
