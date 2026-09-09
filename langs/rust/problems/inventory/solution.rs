use crate::harness::{arg_i64, arg_str, Harness};
use serde_json::Value;
use std::collections::HashMap;

struct Item {
    sku: String,
    #[allow(dead_code)]
    name: String,
    qty: i64,
    reserved: i64,
}

pub struct Simulation {
    items: HashMap<String, Item>,
}

impl Simulation {
    pub fn new() -> Self {
        Self {
            items: HashMap::new(),
        }
    }

    fn create_item(&mut self, sku: &str, name: &str) -> String {
        if self.items.contains_key(sku) {
            return "false".to_string();
        }
        self.items.insert(
            sku.to_string(),
            Item {
                sku: sku.to_string(),
                name: name.to_string(),
                qty: 0,
                reserved: 0,
            },
        );
        "true".to_string()
    }

    fn stock(&mut self, sku: &str, delta: i64) -> String {
        let Some(item) = self.items.get_mut(sku) else {
            return String::new();
        };
        let nxt = item.qty + delta;
        if nxt < item.reserved {
            return "invalid_request".to_string();
        }
        item.qty = nxt;
        item.qty.to_string()
    }

    fn get_qty(&self, sku: &str) -> String {
        self.items
            .get(sku)
            .map(|item| item.qty.to_string())
            .unwrap_or_default()
    }

    fn list_low(&self, threshold: i64) -> String {
        let mut matched: Vec<&Item> = self
            .items
            .values()
            .filter(|item| item.qty <= threshold)
            .collect();
        matched.sort_by(|a, b| a.qty.cmp(&b.qty).then_with(|| a.sku.cmp(&b.sku)));
        matched
            .iter()
            .map(|item| format!("{}({})", item.sku, item.qty))
            .collect::<Vec<_>>()
            .join(", ")
    }

    fn reserve(&mut self, sku: &str, n: i64) -> String {
        let Some(item) = self.items.get_mut(sku) else {
            return "invalid_request".to_string();
        };
        if n <= 0 || item.reserved + n > item.qty {
            return "invalid_request".to_string();
        }
        item.reserved += n;
        "true".to_string()
    }

    fn release(&mut self, sku: &str, n: i64) -> String {
        let Some(item) = self.items.get_mut(sku) else {
            return "invalid_request".to_string();
        };
        if n <= 0 || n > item.reserved {
            return "invalid_request".to_string();
        }
        item.reserved -= n;
        "true".to_string()
    }

    fn ship(&mut self, sku: &str, n: i64) -> String {
        let Some(item) = self.items.get_mut(sku) else {
            return "invalid_request".to_string();
        };
        if n <= 0 || n > item.reserved {
            return "invalid_request".to_string();
        }
        item.reserved -= n;
        item.qty -= n;
        "true".to_string()
    }
}

impl Harness for Simulation {
    fn call(&mut self, method: &str, args: &[Value]) -> Result<Value, String> {
        let text = match method {
            "create_item" => self.create_item(&arg_str(args, 0)?, &arg_str(args, 1)?),
            "stock" => self.stock(&arg_str(args, 0)?, arg_i64(args, 1)?),
            "get_qty" => self.get_qty(&arg_str(args, 0)?),
            "list_low" => self.list_low(arg_i64(args, 0)?),
            "reserve" => self.reserve(&arg_str(args, 0)?, arg_i64(args, 1)?),
            "release" => self.release(&arg_str(args, 0)?, arg_i64(args, 1)?),
            "ship" => self.ship(&arg_str(args, 0)?, arg_i64(args, 1)?),
            other => return Err(format!("missing method {other}")),
        };
        Ok(Value::String(text))
    }
}
