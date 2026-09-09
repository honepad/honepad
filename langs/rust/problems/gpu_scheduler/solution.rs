use crate::harness::{arg_i64, arg_str, Harness};
use serde_json::Value;
use std::collections::HashMap;

struct Gpu {
    mem: i64,
    job_id: Option<String>,
}

struct Job {
    job_id: String,
    mem: i64,
    seq: i64,
    priority: i64,
    state: String,
    gpu_id: Option<String>,
}

pub struct Simulation {
    gpus: HashMap<String, Gpu>,
    gpu_order: Vec<String>,
    jobs: HashMap<String, Job>,
    next_seq: i64,
}

impl Simulation {
    pub fn new() -> Self {
        Self {
            gpus: HashMap::new(),
            gpu_order: Vec::new(),
            jobs: HashMap::new(),
            next_seq: 0,
        }
    }

    fn add_gpu(&mut self, gpu_id: &str, mem: i64) -> String {
        if mem <= 0 {
            return "invalid_request".to_string();
        }
        if self.gpus.contains_key(gpu_id) {
            return "false".to_string();
        }
        self.gpus.insert(
            gpu_id.to_string(),
            Gpu {
                mem,
                job_id: None,
            },
        );
        self.gpu_order.push(gpu_id.to_string());
        "true".to_string()
    }

    fn submit_job(&mut self, job_id: &str, mem: i64) -> String {
        if mem <= 0 {
            return "invalid_request".to_string();
        }
        if self.jobs.contains_key(job_id) {
            return "false".to_string();
        }
        self.jobs.insert(
            job_id.to_string(),
            Job {
                job_id: job_id.to_string(),
                mem,
                seq: self.next_seq,
                priority: 0,
                state: "queued".to_string(),
                gpu_id: None,
            },
        );
        self.next_seq += 1;
        "true".to_string()
    }

    fn status(&self, job_id: &str) -> String {
        self.jobs
            .get(job_id)
            .map(|job| job.state.clone())
            .unwrap_or_default()
    }

    fn assign(&mut self) -> String {
        let mut queued: Vec<String> = self
            .jobs
            .values()
            .filter(|job| job.state == "queued")
            .map(|job| job.job_id.clone())
            .collect();
        queued.sort_by(|a, b| {
            let left = &self.jobs[a];
            let right = &self.jobs[b];
            right
                .priority
                .cmp(&left.priority)
                .then(left.seq.cmp(&right.seq))
        });
        for job_id in queued {
            let need = self.jobs[&job_id].mem;
            let mut chosen: Option<String> = None;
            for gpu_id in &self.gpu_order {
                let gpu = &self.gpus[gpu_id];
                if gpu.job_id.is_none() && gpu.mem >= need {
                    chosen = Some(gpu_id.clone());
                    break;
                }
            }
            if let Some(gpu_id) = chosen {
                let job = self.jobs.get_mut(&job_id).unwrap();
                job.state = "running".to_string();
                job.gpu_id = Some(gpu_id.clone());
                self.gpus.get_mut(&gpu_id).unwrap().job_id = Some(job_id.clone());
                return job_id;
            }
        }
        String::new()
    }

    fn complete(&mut self, job_id: &str) -> String {
        let Some(job) = self.jobs.get_mut(job_id) else {
            return "invalid_request".to_string();
        };
        if job.state != "running" {
            return "invalid_request".to_string();
        }
        let Some(gpu_id) = job.gpu_id.take() else {
            return "invalid_request".to_string();
        };
        job.state = "done".to_string();
        if let Some(gpu) = self.gpus.get_mut(&gpu_id) {
            gpu.job_id = None;
        }
        "true".to_string()
    }

    fn cancel(&mut self, job_id: &str) -> String {
        let Some(job) = self.jobs.get(job_id) else {
            return "invalid_request".to_string();
        };
        if job.state == "done" {
            return "invalid_request".to_string();
        }
        let running = job.state == "running";
        let gpu_id = job.gpu_id.clone();
        if running {
            if let Some(gpu_id) = gpu_id {
                if let Some(gpu) = self.gpus.get_mut(&gpu_id) {
                    gpu.job_id = None;
                }
            }
        }
        self.jobs.remove(job_id);
        if running {
            self.assign();
        }
        "true".to_string()
    }

    fn set_priority(&mut self, job_id: &str, priority: i64) -> String {
        let Some(job) = self.jobs.get_mut(job_id) else {
            return "invalid_request".to_string();
        };
        if job.state != "queued" {
            return "invalid_request".to_string();
        }
        job.priority = priority;
        "true".to_string()
    }
}

impl Harness for Simulation {
    fn call(&mut self, method: &str, args: &[Value]) -> Result<Value, String> {
        let text = match method {
            "add_gpu" => self.add_gpu(&arg_str(args, 0)?, arg_i64(args, 1)?),
            "submit_job" => self.submit_job(&arg_str(args, 0)?, arg_i64(args, 1)?),
            "status" => self.status(&arg_str(args, 0)?),
            "assign" => self.assign(),
            "complete" => self.complete(&arg_str(args, 0)?),
            "cancel" => self.cancel(&arg_str(args, 0)?),
            "set_priority" => self.set_priority(&arg_str(args, 0)?, arg_i64(args, 1)?),
            other => return Err(format!("missing method {other}")),
        };
        Ok(Value::String(text))
    }
}
