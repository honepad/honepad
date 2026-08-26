use crate::harness::{arg_i64, arg_str, opt_i64, opt_str, Harness};
use serde_json::{json, Value};
use std::collections::{HashMap, VecDeque};

const CASHBACK_DELAY: i64 = 24 * 60 * 60 * 1000;

struct Account {
    balance: i64,
    outgoing: i64,
    payments: HashMap<String, String>,
    created_at: i64,
    balance_history: Vec<(i64, i64)>,
}

impl Account {
    fn new(created_at: i64) -> Self {
        Self {
            balance: 0,
            outgoing: 0,
            payments: HashMap::new(),
            created_at,
            balance_history: vec![(created_at, 0)],
        }
    }

    fn record_balance(&mut self, timestamp: i64) {
        self.balance_history.push((timestamp, self.balance));
    }

    fn deposit(&mut self, amount: i64) -> i64 {
        self.balance += amount;
        self.balance
    }

    fn withdraw(&mut self, amount: i64) -> bool {
        if self.balance < amount {
            return false;
        }
        self.balance -= amount;
        self.outgoing += amount;
        true
    }

    fn get_balance_at(&self, time_at: i64) -> Option<i64> {
        if time_at < self.created_at {
            return None;
        }
        let mut result = None;
        for (ts, balance) in &self.balance_history {
            if *ts <= time_at {
                result = Some(*balance);
            } else {
                break;
            }
        }
        result
    }
}

struct Cashback {
    ts: i64,
    account_id: String,
    amount: i64,
    payment_id: String,
}

pub struct Simulation {
    accounts: HashMap<String, Account>,
    payment_counter: i64,
    pending_cashbacks: VecDeque<Cashback>,
}

impl Simulation {
    pub fn new() -> Self {
        Self {
            accounts: HashMap::new(),
            payment_counter: 0,
            pending_cashbacks: VecDeque::new(),
        }
    }

    fn process_cashbacks(&mut self, timestamp: i64) {
        while self
            .pending_cashbacks
            .front()
            .is_some_and(|cb| cb.ts <= timestamp)
        {
            let cb = self.pending_cashbacks.pop_front().unwrap();
            if let Some(account) = self.accounts.get_mut(&cb.account_id) {
                account.deposit(cb.amount);
                account
                    .payments
                    .insert(cb.payment_id, "CASHBACK_RECEIVED".to_string());
                account.record_balance(cb.ts);
            }
        }
    }

    fn create_account(&mut self, timestamp: i64, account_id: &str) -> bool {
        self.process_cashbacks(timestamp);
        if self.accounts.contains_key(account_id) {
            return false;
        }
        self.accounts
            .insert(account_id.to_string(), Account::new(timestamp));
        true
    }

    fn deposit(&mut self, timestamp: i64, account_id: &str, amount: i64) -> Option<i64> {
        self.process_cashbacks(timestamp);
        let account = self.accounts.get_mut(account_id)?;
        let result = account.deposit(amount);
        account.record_balance(timestamp);
        Some(result)
    }

    fn transfer(
        &mut self,
        timestamp: i64,
        source_id: &str,
        target_id: &str,
        amount: i64,
    ) -> Option<i64> {
        self.process_cashbacks(timestamp);
        if source_id == target_id
            || !self.accounts.contains_key(source_id)
            || !self.accounts.contains_key(target_id)
        {
            return None;
        }
        if !self.accounts.get_mut(source_id).unwrap().withdraw(amount) {
            return None;
        }
        self.accounts.get_mut(target_id).unwrap().deposit(amount);
        self.accounts
            .get_mut(source_id)
            .unwrap()
            .record_balance(timestamp);
        self.accounts
            .get_mut(target_id)
            .unwrap()
            .record_balance(timestamp);
        Some(self.accounts[source_id].balance)
    }

    fn top_spenders(&mut self, timestamp: i64, n: i64) -> Vec<String> {
        self.process_cashbacks(timestamp);
        let mut ids: Vec<String> = self.accounts.keys().cloned().collect();
        ids.sort_by(|a, b| {
            let oa = self.accounts[a].outgoing;
            let ob = self.accounts[b].outgoing;
            ob.cmp(&oa).then_with(|| a.cmp(b))
        });
        let take = (n as usize).min(ids.len());
        ids[..take]
            .iter()
            .map(|id| format!("{}({})", id, self.accounts[id].outgoing))
            .collect()
    }

    fn pay(&mut self, timestamp: i64, account_id: &str, amount: i64) -> Option<String> {
        self.process_cashbacks(timestamp);
        let account = self.accounts.get_mut(account_id)?;
        if !account.withdraw(amount) {
            return None;
        }
        self.payment_counter += 1;
        let payment_id = format!("payment{}", self.payment_counter);
        account
            .payments
            .insert(payment_id.clone(), "IN_PROGRESS".to_string());
        account.record_balance(timestamp);
        self.pending_cashbacks.push_back(Cashback {
            ts: timestamp + CASHBACK_DELAY,
            account_id: account_id.to_string(),
            amount: amount * 2 / 100,
            payment_id: payment_id.clone(),
        });
        Some(payment_id)
    }

    fn get_payment_status(
        &mut self,
        timestamp: i64,
        account_id: &str,
        payment: &str,
    ) -> Option<String> {
        self.process_cashbacks(timestamp);
        let account = self.accounts.get(account_id)?;
        account.payments.get(payment).cloned()
    }

    fn merge_accounts(&mut self, timestamp: i64, keep_id: &str, drop_id: &str) -> bool {
        self.process_cashbacks(timestamp);
        if keep_id == drop_id
            || !self.accounts.contains_key(keep_id)
            || !self.accounts.contains_key(drop_id)
        {
            return false;
        }
        let drop = self.accounts.remove(drop_id).unwrap();
        let keep = self.accounts.get_mut(keep_id).unwrap();
        keep.balance += drop.balance;
        keep.outgoing += drop.outgoing;
        keep.payments.extend(drop.payments);
        keep.balance_history.extend(drop.balance_history);
        keep.balance_history.sort_by_key(|row| row.0);
        if drop.created_at < keep.created_at {
            keep.created_at = drop.created_at;
        }
        keep.record_balance(timestamp);
        for cb in &mut self.pending_cashbacks {
            if cb.account_id == drop_id {
                cb.account_id = keep_id.to_string();
            }
        }
        true
    }

    fn get_balance(&mut self, timestamp: i64, account_id: &str, time_at: i64) -> Option<i64> {
        self.process_cashbacks(timestamp);
        self.accounts.get(account_id)?.get_balance_at(time_at)
    }
}

impl Harness for Simulation {
    fn call(&mut self, method: &str, args: &[Value]) -> Result<Value, String> {
        match method {
            "create_account" => Ok(Value::Bool(
                self.create_account(arg_i64(args, 0)?, &arg_str(args, 1)?),
            )),
            "deposit" => Ok(opt_i64(self.deposit(
                arg_i64(args, 0)?,
                &arg_str(args, 1)?,
                arg_i64(args, 2)?,
            ))),
            "transfer" => Ok(opt_i64(self.transfer(
                arg_i64(args, 0)?,
                &arg_str(args, 1)?,
                &arg_str(args, 2)?,
                arg_i64(args, 3)?,
            ))),
            "top_spenders" => Ok(json!(
                self.top_spenders(arg_i64(args, 0)?, arg_i64(args, 1)?)
            )),
            "pay" => Ok(opt_str(self.pay(
                arg_i64(args, 0)?,
                &arg_str(args, 1)?,
                arg_i64(args, 2)?,
            ))),
            "get_payment_status" => Ok(opt_str(self.get_payment_status(
                arg_i64(args, 0)?,
                &arg_str(args, 1)?,
                &arg_str(args, 2)?,
            ))),
            "merge_accounts" => Ok(Value::Bool(self.merge_accounts(
                arg_i64(args, 0)?,
                &arg_str(args, 1)?,
                &arg_str(args, 2)?,
            ))),
            "get_balance" => Ok(opt_i64(self.get_balance(
                arg_i64(args, 0)?,
                &arg_str(args, 1)?,
                arg_i64(args, 2)?,
            ))),
            other => Err(format!("missing method {other}")),
        }
    }
}
