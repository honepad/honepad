use crate::harness::{arg_i64, arg_str, Harness};
use serde_json::Value;

struct EditorSnap {
    buf: String,
    pos: i64,
}

pub struct Simulation {
    buf: String,
    pos: i64,
    undo_stack: Vec<EditorSnap>,
    redo_stack: Vec<EditorSnap>,
    sel_start: i64,
    sel_end: i64,
    clip: String,
}

impl Simulation {
    pub fn new() -> Self {
        Self {
            buf: String::new(),
            pos: 0,
            undo_stack: Vec::new(),
            redo_stack: Vec::new(),
            sel_start: -1,
            sel_end: -1,
            clip: String::new(),
        }
    }

    fn push(&mut self) {
        self.undo_stack.push(EditorSnap {
            buf: self.buf.clone(),
            pos: self.pos,
        });
        self.redo_stack.clear();
        self.sel_start = -1;
        self.sel_end = -1;
    }

    fn insert(&mut self, pos: i64, text: &str) -> String {
        if pos < 0 || pos as usize > self.buf.len() {
            return "invalid_request".to_string();
        }
        self.push();
        let at = pos as usize;
        self.buf = format!("{}{}{}", &self.buf[..at], text, &self.buf[at..]);
        self.buf.len().to_string()
    }

    fn erase(&mut self, pos: i64, n: i64) -> String {
        if n <= 0 || pos < 0 || (pos + n) as usize > self.buf.len() {
            return "invalid_request".to_string();
        }
        self.push();
        let start = pos as usize;
        let end = (pos + n) as usize;
        let deleted = self.buf[start..end].to_string();
        self.buf = format!("{}{}", &self.buf[..start], &self.buf[end..]);
        if self.pos as usize > self.buf.len() {
            self.pos = self.buf.len() as i64;
        }
        deleted
    }

    fn get_text(&self) -> String {
        self.buf.clone()
    }

    fn length(&self) -> String {
        self.buf.len().to_string()
    }

    fn move_to(&mut self, pos: i64) -> String {
        if pos < 0 || pos as usize > self.buf.len() {
            return "invalid_request".to_string();
        }
        self.pos = pos;
        "true".to_string()
    }

    fn type_text(&mut self, text: &str) -> String {
        self.push();
        let at = self.pos as usize;
        self.buf = format!("{}{}{}", &self.buf[..at], text, &self.buf[at..]);
        self.pos = at as i64 + text.len() as i64;
        self.buf.len().to_string()
    }

    fn cursor(&self) -> String {
        self.pos.to_string()
    }

    fn undo(&mut self) -> String {
        let Some(snap) = self.undo_stack.pop() else {
            return "false".to_string();
        };
        self.redo_stack.push(EditorSnap {
            buf: self.buf.clone(),
            pos: self.pos,
        });
        self.buf = snap.buf;
        self.pos = snap.pos;
        self.sel_start = -1;
        self.sel_end = -1;
        "true".to_string()
    }

    fn redo(&mut self) -> String {
        let Some(snap) = self.redo_stack.pop() else {
            return "false".to_string();
        };
        self.undo_stack.push(EditorSnap {
            buf: self.buf.clone(),
            pos: self.pos,
        });
        self.buf = snap.buf;
        self.pos = snap.pos;
        self.sel_start = -1;
        self.sel_end = -1;
        "true".to_string()
    }

    fn select(&mut self, start: i64, end: i64) -> String {
        if start < 0 || end < 0 || start > end || end as usize > self.buf.len() {
            return "invalid_request".to_string();
        }
        self.sel_start = start;
        self.sel_end = end;
        "true".to_string()
    }

    fn cut(&mut self) -> String {
        if self.sel_start < 0 || self.sel_start == self.sel_end {
            return "invalid_request".to_string();
        }
        let start = self.sel_start as usize;
        let end = self.sel_end as usize;
        let text = self.buf[start..end].to_string();
        self.buf = format!("{}{}", &self.buf[..start], &self.buf[end..]);
        self.clip = text.clone();
        self.pos = self.sel_start;
        self.sel_start = -1;
        self.sel_end = -1;
        text
    }

    fn copy_sel(&mut self) -> String {
        if self.sel_start < 0 || self.sel_start == self.sel_end {
            return "invalid_request".to_string();
        }
        let start = self.sel_start as usize;
        let end = self.sel_end as usize;
        self.clip = self.buf[start..end].to_string();
        self.clip.clone()
    }

    fn paste(&mut self) -> String {
        if self.clip.is_empty() {
            return "invalid_request".to_string();
        }
        let at = self.pos as usize;
        self.buf = format!("{}{}{}", &self.buf[..at], self.clip, &self.buf[at..]);
        self.pos = at as i64 + self.clip.len() as i64;
        self.buf.len().to_string()
    }
}

impl Harness for Simulation {
    fn call(&mut self, method: &str, args: &[Value]) -> Result<Value, String> {
        let text = match method {
            "insert" => self.insert(arg_i64(args, 0)?, &arg_str(args, 1)?),
            "erase" => self.erase(arg_i64(args, 0)?, arg_i64(args, 1)?),
            "get_text" => self.get_text(),
            "length" => self.length(),
            "move" => self.move_to(arg_i64(args, 0)?),
            "type_text" => self.type_text(&arg_str(args, 0)?),
            "cursor" => self.cursor(),
            "undo" => self.undo(),
            "redo" => self.redo(),
            "select" => self.select(arg_i64(args, 0)?, arg_i64(args, 1)?),
            "cut" => self.cut(),
            "copy_sel" => self.copy_sel(),
            "paste" => self.paste(),
            other => return Err(format!("missing method {other}")),
        };
        Ok(Value::String(text))
    }
}
