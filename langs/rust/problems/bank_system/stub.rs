use crate::harness::Harness;
use serde_json::Value;

pub struct Simulation;

impl Simulation {
    pub fn new() -> Self {
        Self
    }
}

impl Harness for Simulation {
    fn call(&mut self, method: &str, _args: &[Value]) -> Result<Value, String> {
        Err(format!("not implemented: {method}"))
    }
}
