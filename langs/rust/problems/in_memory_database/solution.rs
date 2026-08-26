use crate::harness::{arg_i64, arg_str, Harness};
use serde_json::Value;
use std::collections::HashMap;

#[derive(Clone)]
struct FieldVal {
    value: String,
    expiry: Option<i64>,
}

pub struct InMemoryDatabase {
    database: HashMap<String, HashMap<String, FieldVal>>,
    backup_timestamps: Vec<i64>,
    backup_states: Vec<HashMap<String, HashMap<String, FieldVal>>>,
}

impl InMemoryDatabase {
    pub fn new() -> Self {
        Self {
            database: HashMap::new(),
            backup_timestamps: Vec::new(),
            backup_states: Vec::new(),
        }
    }

    fn set_internal(&mut self, key: &str, field: &str, value: &str, expiry: Option<i64>) -> String {
        self.database.entry(key.to_string()).or_default().insert(
            field.to_string(),
            FieldVal {
                value: value.to_string(),
                expiry,
            },
        );
        String::new()
    }

    fn is_alive(&self, key: &str, field: &str, timestamp: i64) -> bool {
        let Some(fields) = self.database.get(key) else {
            return false;
        };
        let Some(fv) = fields.get(field) else {
            return false;
        };
        match fv.expiry {
            None => true,
            Some(expiry) => timestamp < expiry,
        }
    }

    fn set(&mut self, key: &str, field: &str, value: &str) -> String {
        self.set_internal(key, field, value, None)
    }

    fn get(&self, key: &str, field: &str) -> String {
        self.database
            .get(key)
            .and_then(|fields| fields.get(field))
            .map(|fv| fv.value.clone())
            .unwrap_or_default()
    }

    fn delete(&mut self, key: &str, field: &str) -> String {
        let Some(fields) = self.database.get_mut(key) else {
            return "false".to_string();
        };
        if fields.remove(field).is_none() {
            return "false".to_string();
        }
        "true".to_string()
    }

    fn scan(&self, key: &str) -> String {
        let Some(fields) = self.database.get(key) else {
            return String::new();
        };
        let mut names: Vec<&String> = fields.keys().collect();
        names.sort();
        names
            .into_iter()
            .map(|field| format!("{}({})", field, fields[field].value))
            .collect::<Vec<_>>()
            .join(", ")
    }

    fn scan_by_prefix(&self, key: &str, prefix: &str) -> String {
        let Some(fields) = self.database.get(key) else {
            return String::new();
        };
        let mut names: Vec<&String> = fields
            .keys()
            .filter(|field| field.starts_with(prefix))
            .collect();
        names.sort();
        names
            .into_iter()
            .map(|field| format!("{}({})", field, fields[field].value))
            .collect::<Vec<_>>()
            .join(", ")
    }

    fn set_at(&mut self, key: &str, field: &str, value: &str, _timestamp: i64) -> String {
        self.set_internal(key, field, value, None)
    }

    fn set_at_with_ttl(
        &mut self,
        key: &str,
        field: &str,
        value: &str,
        timestamp: i64,
        ttl: i64,
    ) -> String {
        self.set_internal(key, field, value, Some(timestamp + ttl))
    }

    fn delete_at(&mut self, key: &str, field: &str, timestamp: i64) -> String {
        if !self.is_alive(key, field, timestamp) {
            return "false".to_string();
        }
        self.database.get_mut(key).unwrap().remove(field);
        "true".to_string()
    }

    fn get_at(&self, key: &str, field: &str, timestamp: i64) -> String {
        if !self.is_alive(key, field, timestamp) {
            return String::new();
        }
        self.database[key][field].value.clone()
    }

    fn scan_at(&self, key: &str, timestamp: i64) -> String {
        let Some(fields) = self.database.get(key) else {
            return String::new();
        };
        let mut names: Vec<&String> = fields
            .keys()
            .filter(|field| self.is_alive(key, field, timestamp))
            .collect();
        names.sort();
        names
            .into_iter()
            .map(|field| format!("{}({})", field, fields[field].value))
            .collect::<Vec<_>>()
            .join(", ")
    }

    fn scan_by_prefix_at(&self, key: &str, prefix: &str, timestamp: i64) -> String {
        let Some(fields) = self.database.get(key) else {
            return String::new();
        };
        let mut names: Vec<&String> = fields
            .keys()
            .filter(|field| field.starts_with(prefix) && self.is_alive(key, field, timestamp))
            .collect();
        names.sort();
        names
            .into_iter()
            .map(|field| format!("{}({})", field, fields[field].value))
            .collect::<Vec<_>>()
            .join(", ")
    }

    fn backup(&mut self, timestamp: i64) -> String {
        let mut state: HashMap<String, HashMap<String, FieldVal>> = HashMap::new();
        let keys: Vec<String> = self.database.keys().cloned().collect();
        for key in keys {
            let fields: Vec<(String, FieldVal)> = self.database[&key]
                .iter()
                .map(|(field, fv)| (field.clone(), fv.clone()))
                .collect();
            for (field, fv) in fields {
                if !self.is_alive(&key, &field, timestamp) {
                    continue;
                }
                let remaining = fv.expiry.map(|expiry| expiry - timestamp);
                state.entry(key.clone()).or_default().insert(
                    field,
                    FieldVal {
                        value: fv.value,
                        expiry: remaining,
                    },
                );
            }
        }
        let count = state.len();
        self.backup_timestamps.push(timestamp);
        self.backup_states.push(state);
        count.to_string()
    }

    fn restore(&mut self, timestamp: i64, timestamp_to_restore: i64) -> String {
        let mut idx: Option<usize> = None;
        for (i, ts) in self.backup_timestamps.iter().enumerate() {
            if *ts <= timestamp_to_restore {
                idx = Some(i);
            }
        }
        let Some(idx) = idx else {
            self.database.clear();
            return String::new();
        };
        let backup = self.backup_states[idx].clone();
        self.database.clear();
        for (key, fields) in backup {
            for (field, fv) in fields {
                let expiry = fv.expiry.map(|remaining| timestamp + remaining);
                self.set_internal(&key, &field, &fv.value, expiry);
            }
        }
        String::new()
    }
}

impl Harness for InMemoryDatabase {
    fn call(&mut self, method: &str, args: &[Value]) -> Result<Value, String> {
        let text = match method {
            "set" => self.set(&arg_str(args, 0)?, &arg_str(args, 1)?, &arg_str(args, 2)?),
            "get" => self.get(&arg_str(args, 0)?, &arg_str(args, 1)?),
            "delete" => self.delete(&arg_str(args, 0)?, &arg_str(args, 1)?),
            "scan" => self.scan(&arg_str(args, 0)?),
            "scan_by_prefix" => self.scan_by_prefix(&arg_str(args, 0)?, &arg_str(args, 1)?),
            "set_at" => self.set_at(
                &arg_str(args, 0)?,
                &arg_str(args, 1)?,
                &arg_str(args, 2)?,
                arg_i64(args, 3)?,
            ),
            "set_at_with_ttl" => self.set_at_with_ttl(
                &arg_str(args, 0)?,
                &arg_str(args, 1)?,
                &arg_str(args, 2)?,
                arg_i64(args, 3)?,
                arg_i64(args, 4)?,
            ),
            "delete_at" => {
                self.delete_at(&arg_str(args, 0)?, &arg_str(args, 1)?, arg_i64(args, 2)?)
            }
            "get_at" => self.get_at(&arg_str(args, 0)?, &arg_str(args, 1)?, arg_i64(args, 2)?),
            "scan_at" => self.scan_at(&arg_str(args, 0)?, arg_i64(args, 1)?),
            "scan_by_prefix_at" => {
                self.scan_by_prefix_at(&arg_str(args, 0)?, &arg_str(args, 1)?, arg_i64(args, 2)?)
            }
            "backup" => self.backup(arg_i64(args, 0)?),
            "restore" => self.restore(arg_i64(args, 0)?, arg_i64(args, 1)?),
            other => return Err(format!("missing method {other}")),
        };
        Ok(Value::String(text))
    }
}
