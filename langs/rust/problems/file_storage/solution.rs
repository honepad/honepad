use crate::harness::{arg_i64, arg_str, Harness};
use serde_json::Value;
use std::collections::HashMap;

struct StoredFile {
    name: String,
    size: i64,
    owner: String,
}

pub struct Simulation {
    files: HashMap<String, StoredFile>,
    capacity: HashMap<String, Option<i64>>,
    backups: HashMap<String, HashMap<String, i64>>,
}

impl Simulation {
    pub fn new() -> Self {
        let mut capacity = HashMap::new();
        capacity.insert("admin".to_string(), None);
        Self {
            files: HashMap::new(),
            capacity,
            backups: HashMap::new(),
        }
    }

    fn used(&self, user_id: &str) -> i64 {
        self.files
            .values()
            .filter(|item| item.owner == user_id)
            .map(|item| item.size)
            .sum()
    }

    fn remaining(&self, user_id: &str) -> Option<i64> {
        let cap = self.capacity.get(user_id)?.as_ref()?;
        Some(cap - self.used(user_id))
    }

    fn add_file(&mut self, name: &str, size: i64) -> String {
        if self.files.contains_key(name) {
            return "false".to_string();
        }
        self.files.insert(
            name.to_string(),
            StoredFile {
                name: name.to_string(),
                size,
                owner: "admin".to_string(),
            },
        );
        "true".to_string()
    }

    fn get_file_size(&self, name: &str) -> String {
        self.files
            .get(name)
            .map(|item| item.size.to_string())
            .unwrap_or_default()
    }

    fn delete_file(&mut self, name: &str) -> String {
        self.files
            .remove(name)
            .map(|item| item.size.to_string())
            .unwrap_or_default()
    }

    fn copy_file(&mut self, source: &str, dest: &str) -> String {
        let Some(src) = self.files.get(source) else {
            return String::new();
        };
        if source == dest {
            return src.size.to_string();
        }
        let src_size = src.size;
        let src_owner = src.owner.clone();
        let dest_info = self
            .files
            .get(dest)
            .map(|item| (item.owner.clone(), item.size));
        let owner = dest_info
            .as_ref()
            .map(|(item_owner, _)| item_owner.clone())
            .unwrap_or(src_owner);
        let extra = dest_info
            .as_ref()
            .map(|(_, size)| src_size - size)
            .unwrap_or(src_size);
        if let Some(left) = self.remaining(&owner) {
            if extra > left {
                return String::new();
            }
        }
        if dest_info.is_none() {
            self.files.insert(
                dest.to_string(),
                StoredFile {
                    name: dest.to_string(),
                    size: src_size,
                    owner,
                },
            );
        } else if let Some(item) = self.files.get_mut(dest) {
            item.size = src_size;
        }
        src_size.to_string()
    }

    fn get_n_largest(&self, prefix: &str, n: i64) -> String {
        let mut matched: Vec<&StoredFile> = self
            .files
            .values()
            .filter(|item| item.name.starts_with(prefix))
            .collect();
        matched.sort_by(|a, b| b.size.cmp(&a.size).then_with(|| a.name.cmp(&b.name)));
        let take = (n as usize).min(matched.len());
        matched[..take]
            .iter()
            .map(|item| format!("{}({})", item.name, item.size))
            .collect::<Vec<_>>()
            .join(", ")
    }

    fn add_user(&mut self, user_id: &str, capacity: i64) -> String {
        if self.capacity.contains_key(user_id) {
            return "false".to_string();
        }
        self.capacity.insert(user_id.to_string(), Some(capacity));
        "true".to_string()
    }

    fn add_file_by(&mut self, user_id: &str, name: &str, size: i64) -> String {
        if !self.capacity.contains_key(user_id) || self.files.contains_key(name) {
            return String::new();
        }
        if let Some(left) = self.remaining(user_id) {
            if size > left {
                return String::new();
            }
        }
        self.files.insert(
            name.to_string(),
            StoredFile {
                name: name.to_string(),
                size,
                owner: user_id.to_string(),
            },
        );
        self.remaining(user_id)
            .map(|left| left.to_string())
            .unwrap_or_default()
    }

    fn merge_user(&mut self, user_id1: &str, user_id2: &str) -> String {
        if user_id1 == user_id2 {
            return String::new();
        }
        let Some(Some(cap1)) = self.capacity.get(user_id1).copied() else {
            return String::new();
        };
        let Some(Some(cap2)) = self.capacity.get(user_id2).copied() else {
            return String::new();
        };
        self.capacity
            .insert(user_id1.to_string(), Some(cap1 + cap2));
        for item in self.files.values_mut() {
            if item.owner == user_id2 {
                item.owner = user_id1.to_string();
            }
        }
        self.capacity.remove(user_id2);
        self.backups.remove(user_id2);
        self.remaining(user_id1)
            .map(|left| left.to_string())
            .unwrap_or_default()
    }

    fn backup_user(&mut self, user_id: &str) -> String {
        if !self.capacity.contains_key(user_id) {
            return String::new();
        }
        let snap: HashMap<String, i64> = self
            .files
            .values()
            .filter(|item| item.owner == user_id)
            .map(|item| (item.name.clone(), item.size))
            .collect();
        let count = snap.len();
        self.backups.insert(user_id.to_string(), snap);
        count.to_string()
    }

    fn restore_user(&mut self, user_id: &str) -> String {
        if !self.capacity.contains_key(user_id) {
            return String::new();
        }
        let owned: Vec<String> = self
            .files
            .iter()
            .filter(|(_, item)| item.owner == user_id)
            .map(|(name, _)| name.clone())
            .collect();
        for name in owned {
            self.files.remove(&name);
        }
        let Some(snap) = self.backups.get(user_id).cloned() else {
            return "0".to_string();
        };
        let mut restored = 0i64;
        for (name, size) in snap {
            if self.files.contains_key(&name) {
                continue;
            }
            if let Some(left) = self.remaining(user_id) {
                if size > left {
                    continue;
                }
            }
            self.files.insert(
                name.clone(),
                StoredFile {
                    name,
                    size,
                    owner: user_id.to_string(),
                },
            );
            restored += 1;
        }
        restored.to_string()
    }
}

impl Harness for Simulation {
    fn call(&mut self, method: &str, args: &[Value]) -> Result<Value, String> {
        let text = match method {
            "add_file" => self.add_file(&arg_str(args, 0)?, arg_i64(args, 1)?),
            "copy_file" => self.copy_file(&arg_str(args, 0)?, &arg_str(args, 1)?),
            "get_file_size" => self.get_file_size(&arg_str(args, 0)?),
            "delete_file" => self.delete_file(&arg_str(args, 0)?),
            "get_n_largest" => self.get_n_largest(&arg_str(args, 0)?, arg_i64(args, 1)?),
            "add_user" => self.add_user(&arg_str(args, 0)?, arg_i64(args, 1)?),
            "add_file_by" => {
                self.add_file_by(&arg_str(args, 0)?, &arg_str(args, 1)?, arg_i64(args, 2)?)
            }
            "merge_user" => self.merge_user(&arg_str(args, 0)?, &arg_str(args, 1)?),
            "backup_user" => self.backup_user(&arg_str(args, 0)?),
            "restore_user" => self.restore_user(&arg_str(args, 0)?),
            other => return Err(format!("missing method {other}")),
        };
        Ok(Value::String(text))
    }
}
