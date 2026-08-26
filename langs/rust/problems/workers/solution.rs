use crate::harness::{arg_i64, arg_str, Harness};
use serde_json::Value;
use std::collections::HashMap;

struct Session {
    start: i64,
    end: i64,
    rate: i64,
    position: String,
}

struct Promo {
    new_pos: String,
    new_comp: i64,
    start_ts: i64,
}

struct Worker {
    worker_id: String,
    position: String,
    compensation: i64,
    in_office: bool,
    entered_at: Option<i64>,
    finished: Vec<Session>,
    pending_promo: Option<Promo>,
}

impl Worker {
    fn total_time(&self) -> i64 {
        self.finished.iter().map(|item| item.end - item.start).sum()
    }

    fn position_time(&self, position: &str) -> i64 {
        self.finished
            .iter()
            .filter(|item| item.position == position)
            .map(|item| item.end - item.start)
            .sum()
    }

    fn apply_promo_on_enter(&mut self, timestamp: i64) {
        let Some(promo) = &self.pending_promo else {
            return;
        };
        if timestamp >= promo.start_ts {
            self.position = promo.new_pos.clone();
            self.compensation = promo.new_comp;
            self.pending_promo = None;
        }
    }
}

pub struct Simulation {
    workers: HashMap<String, Worker>,
}

impl Simulation {
    pub fn new() -> Self {
        Self {
            workers: HashMap::new(),
        }
    }

    fn add_worker(&mut self, worker_id: &str, position: &str, compensation: i64) -> String {
        if self.workers.contains_key(worker_id) {
            return "false".to_string();
        }
        self.workers.insert(
            worker_id.to_string(),
            Worker {
                worker_id: worker_id.to_string(),
                position: position.to_string(),
                compensation,
                in_office: false,
                entered_at: None,
                finished: Vec::new(),
                pending_promo: None,
            },
        );
        "true".to_string()
    }

    fn register(&mut self, worker_id: &str, timestamp: i64) -> String {
        let Some(worker) = self.workers.get_mut(worker_id) else {
            return "invalid_request".to_string();
        };
        if worker.in_office {
            worker.finished.push(Session {
                start: worker.entered_at.unwrap(),
                end: timestamp,
                rate: worker.compensation,
                position: worker.position.clone(),
            });
            worker.in_office = false;
            worker.entered_at = None;
            return "registered".to_string();
        }
        worker.apply_promo_on_enter(timestamp);
        worker.in_office = true;
        worker.entered_at = Some(timestamp);
        "registered".to_string()
    }

    fn get(&self, worker_id: &str) -> String {
        self.workers
            .get(worker_id)
            .map(|worker| worker.total_time().to_string())
            .unwrap_or_default()
    }

    fn top_n_workers(&self, n: i64, position: &str) -> String {
        let mut matched: Vec<&Worker> = self
            .workers
            .values()
            .filter(|worker| worker.position == position)
            .collect();
        matched.sort_by(|a, b| {
            let ta = a.position_time(position);
            let tb = b.position_time(position);
            tb.cmp(&ta).then_with(|| a.worker_id.cmp(&b.worker_id))
        });
        let take = (n as usize).min(matched.len());
        matched[..take]
            .iter()
            .map(|worker| format!("{}({})", worker.worker_id, worker.position_time(position)))
            .collect::<Vec<_>>()
            .join(", ")
    }

    fn promote(
        &mut self,
        worker_id: &str,
        new_position: &str,
        new_compensation: i64,
        start_timestamp: i64,
    ) -> String {
        let Some(worker) = self.workers.get_mut(worker_id) else {
            return "invalid_request".to_string();
        };
        if worker.pending_promo.is_some() {
            return "invalid_request".to_string();
        }
        worker.pending_promo = Some(Promo {
            new_pos: new_position.to_string(),
            new_comp: new_compensation,
            start_ts: start_timestamp,
        });
        "success".to_string()
    }

    fn calc_salary(&self, worker_id: &str, start_timestamp: i64, end_timestamp: i64) -> String {
        let Some(worker) = self.workers.get(worker_id) else {
            return String::new();
        };
        let mut total = 0i64;
        for item in &worker.finished {
            let lo = item.start.max(start_timestamp);
            let hi = item.end.min(end_timestamp);
            if hi > lo {
                total += (hi - lo) * item.rate;
            }
        }
        total.to_string()
    }
}

impl Harness for Simulation {
    fn call(&mut self, method: &str, args: &[Value]) -> Result<Value, String> {
        let text = match method {
            "add_worker" => {
                self.add_worker(&arg_str(args, 0)?, &arg_str(args, 1)?, arg_i64(args, 2)?)
            }
            "register" => self.register(&arg_str(args, 0)?, arg_i64(args, 1)?),
            "get" => self.get(&arg_str(args, 0)?),
            "top_n_workers" => self.top_n_workers(arg_i64(args, 0)?, &arg_str(args, 1)?),
            "promote" => self.promote(
                &arg_str(args, 0)?,
                &arg_str(args, 1)?,
                arg_i64(args, 2)?,
                arg_i64(args, 3)?,
            ),
            "calc_salary" => {
                self.calc_salary(&arg_str(args, 0)?, arg_i64(args, 1)?, arg_i64(args, 2)?)
            }
            other => return Err(format!("missing method {other}")),
        };
        Ok(Value::String(text))
    }
}
