use crate::harness::{arg_i64, arg_str, Harness};
use serde_json::Value;
use std::collections::HashMap;

pub struct Simulation {
    subs: HashMap<String, Vec<String>>,
    inbox_map: HashMap<String, Vec<String>>,
    retained: HashMap<String, String>,
}

impl Simulation {
    pub fn new() -> Self {
        Self {
            subs: HashMap::new(),
            inbox_map: HashMap::new(),
            retained: HashMap::new(),
        }
    }

    fn subscribe(&mut self, topic: &str, client: &str) -> String {
        let clients = self.subs.entry(topic.to_string()).or_default();
        if clients.iter().any(|existing| existing == client) {
            return "false".to_string();
        }
        clients.push(client.to_string());
        if let Some(message) = self.retained.get(topic) {
            self.inbox_map
                .entry(client.to_string())
                .or_default()
                .push(format!("{topic}:{message}"));
        }
        "true".to_string()
    }

    fn unsubscribe(&mut self, topic: &str, client: &str) -> String {
        let Some(clients) = self.subs.get_mut(topic) else {
            return "false".to_string();
        };
        let Some(idx) = clients.iter().position(|existing| existing == client) else {
            return "false".to_string();
        };
        clients.remove(idx);
        if clients.is_empty() {
            self.subs.remove(topic);
        }
        "true".to_string()
    }

    fn publish(&mut self, topic: &str, message: &str) -> String {
        let clients = self.subs.get(topic).cloned().unwrap_or_default();
        let payload = format!("{topic}:{message}");
        for client in &clients {
            self.inbox_map
                .entry(client.clone())
                .or_default()
                .push(payload.clone());
        }
        clients.len().to_string()
    }

    fn inbox(&self, client: &str) -> String {
        self.inbox_map
            .get(client)
            .map(|items| items.join(", "))
            .unwrap_or_default()
    }

    fn list_topics(&self) -> String {
        let mut topics: Vec<&String> = self.subs.keys().collect();
        topics.sort();
        topics
            .into_iter()
            .map(|topic| topic.as_str())
            .collect::<Vec<_>>()
            .join(", ")
    }

    fn subscribers(&self, topic: &str) -> String {
        let mut clients = self.subs.get(topic).cloned().unwrap_or_default();
        clients.sort();
        clients.join(", ")
    }

    fn peek(&self, client: &str) -> String {
        self.inbox_map
            .get(client)
            .and_then(|items| items.first())
            .cloned()
            .unwrap_or_default()
    }

    fn ack(&mut self, client: &str, n: i64) -> String {
        if n <= 0 || !self.inbox_map.contains_key(client) {
            return "invalid_request".to_string();
        }
        let items = self.inbox_map.get_mut(client).unwrap();
        if n as usize > items.len() {
            return "invalid_request".to_string();
        }
        items.drain(0..n as usize);
        items.len().to_string()
    }

    fn retain(&mut self, topic: &str, message: &str) -> String {
        self.retained.insert(topic.to_string(), message.to_string());
        String::new()
    }
}

impl Harness for Simulation {
    fn call(&mut self, method: &str, args: &[Value]) -> Result<Value, String> {
        let text = match method {
            "subscribe" => self.subscribe(&arg_str(args, 0)?, &arg_str(args, 1)?),
            "unsubscribe" => self.unsubscribe(&arg_str(args, 0)?, &arg_str(args, 1)?),
            "publish" => self.publish(&arg_str(args, 0)?, &arg_str(args, 1)?),
            "inbox" => self.inbox(&arg_str(args, 0)?),
            "list_topics" => self.list_topics(),
            "subscribers" => self.subscribers(&arg_str(args, 0)?),
            "peek" => self.peek(&arg_str(args, 0)?),
            "ack" => self.ack(&arg_str(args, 0)?, arg_i64(args, 1)?),
            "retain" => self.retain(&arg_str(args, 0)?, &arg_str(args, 1)?),
            other => return Err(format!("missing method {other}")),
        };
        Ok(Value::String(text))
    }
}
