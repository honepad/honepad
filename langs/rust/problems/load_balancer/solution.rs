use crate::harness::{arg_i64, arg_str, Harness};
use serde_json::Value;
use std::collections::HashMap;

struct Backend {
    backend_id: String,
    health: bool,
    weight: i64,
    inflight: i64,
}

pub struct Simulation {
    backends: Vec<Backend>,
    by_id: HashMap<String, usize>,
    cursor: i64,
    sticky_map: HashMap<String, String>,
    use_least: bool,
}

impl Simulation {
    pub fn new() -> Self {
        Self {
            backends: Vec::new(),
            by_id: HashMap::new(),
            cursor: 0,
            sticky_map: HashMap::new(),
            use_least: false,
        }
    }

    fn add_backend(&mut self, backend_id: &str) -> String {
        if self.by_id.contains_key(backend_id) {
            return "false".to_string();
        }
        let idx = self.backends.len();
        self.backends.push(Backend {
            backend_id: backend_id.to_string(),
            health: true,
            weight: 1,
            inflight: 0,
        });
        self.by_id.insert(backend_id.to_string(), idx);
        "true".to_string()
    }

    fn set_health(&mut self, backend_id: &str, flag: i64) -> String {
        let Some(&idx) = self.by_id.get(backend_id) else {
            return "invalid_request".to_string();
        };
        if flag != 0 && flag != 1 {
            return "invalid_request".to_string();
        }
        self.backends[idx].health = flag == 1;
        self.reset_cycle();
        "true".to_string()
    }

    fn set_weight(&mut self, backend_id: &str, weight: i64) -> String {
        let Some(&idx) = self.by_id.get(backend_id) else {
            return "invalid_request".to_string();
        };
        if weight <= 0 {
            return "invalid_request".to_string();
        }
        self.backends[idx].weight = weight;
        self.reset_cycle();
        "true".to_string()
    }

    fn reset_cycle(&mut self) {
        self.cursor = 0;
        self.use_least = false;
        for item in &mut self.backends {
            item.inflight = 0;
        }
    }

    fn pick(&mut self) -> Option<usize> {
        let healthy: Vec<usize> = self
            .backends
            .iter()
            .enumerate()
            .filter(|(_, item)| item.health)
            .map(|(i, _)| i)
            .collect();
        if healthy.is_empty() {
            return None;
        }
        let pool: Vec<usize> = if self.use_least {
            let least = healthy
                .iter()
                .map(|&i| self.backends[i].inflight)
                .min()
                .unwrap_or(0);
            healthy
                .into_iter()
                .filter(|&i| self.backends[i].inflight == least)
                .collect()
        } else {
            healthy
        };
        let mut tickets = Vec::new();
        for idx in pool {
            for _ in 0..self.backends[idx].weight {
                tickets.push(idx);
            }
        }
        if tickets.is_empty() {
            return None;
        }
        let chosen = tickets[self.cursor as usize % tickets.len()];
        self.cursor += 1;
        Some(chosen)
    }

    fn take(&mut self) -> String {
        let Some(idx) = self.pick() else {
            return String::new();
        };
        self.backends[idx].inflight += 1;
        self.backends[idx].backend_id.clone()
    }

    fn route(&mut self) -> String {
        self.take()
    }

    fn sticky(&mut self, client_id: &str) -> String {
        if let Some(bound) = self.sticky_map.get(client_id).cloned() {
            if let Some(&idx) = self.by_id.get(&bound) {
                if self.backends[idx].health {
                    self.backends[idx].inflight += 1;
                    return self.backends[idx].backend_id.clone();
                }
            }
        }
        let chosen = self.take();
        if !chosen.is_empty() {
            self.sticky_map.insert(client_id.to_string(), chosen.clone());
        }
        chosen
    }

    fn done(&mut self, backend_id: &str) -> String {
        let Some(&idx) = self.by_id.get(backend_id) else {
            return "invalid_request".to_string();
        };
        if self.backends[idx].inflight <= 0 {
            return "invalid_request".to_string();
        }
        self.backends[idx].inflight -= 1;
        self.use_least = true;
        "true".to_string()
    }
}

impl Harness for Simulation {
    fn call(&mut self, method: &str, args: &[Value]) -> Result<Value, String> {
        let text = match method {
            "add_backend" => self.add_backend(&arg_str(args, 0)?),
            "route" => self.route(),
            "set_health" => self.set_health(&arg_str(args, 0)?, arg_i64(args, 1)?),
            "set_weight" => self.set_weight(&arg_str(args, 0)?, arg_i64(args, 1)?),
            "sticky" => self.sticky(&arg_str(args, 0)?),
            "done" => self.done(&arg_str(args, 0)?),
            other => return Err(format!("missing method {other}")),
        };
        Ok(Value::String(text))
    }
}
