Simulation = {}
Simulation.__index = Simulation

function Simulation.new()
  local self = setmetatable({}, Simulation)
  self.buf = ""
  self.pos = 0
  self.undo_stack = {}
  self.redo_stack = {}
  self.sel = nil
  self.clip = ""
  return self
end

function Simulation:_push()
  self.undo_stack[#self.undo_stack + 1] = { self.buf, self.pos }
  self.redo_stack = {}
  self.sel = nil
end

function Simulation:insert(pos, text)
  if pos < 0 or pos > #self.buf then
    return "invalid_request"
  end
  self:_push()
  self.buf = self.buf:sub(1, pos) .. text .. self.buf:sub(pos + 1)
  return tostring(#self.buf)
end

function Simulation:erase(pos, n)
  if n <= 0 or pos < 0 or pos + n > #self.buf then
    return "invalid_request"
  end
  self:_push()
  local deleted = self.buf:sub(pos + 1, pos + n)
  self.buf = self.buf:sub(1, pos) .. self.buf:sub(pos + n + 1)
  if self.pos > #self.buf then
    self.pos = #self.buf
  end
  return deleted
end

function Simulation:get_text()
  return self.buf
end

function Simulation:length()
  return tostring(#self.buf)
end

function Simulation:move(pos)
  if pos < 0 or pos > #self.buf then
    return "invalid_request"
  end
  self.pos = pos
  return "true"
end

function Simulation:type_text(text)
  self:_push()
  local at = self.pos
  self.buf = self.buf:sub(1, at) .. text .. self.buf:sub(at + 1)
  self.pos = at + #text
  return tostring(#self.buf)
end

function Simulation:cursor()
  return tostring(self.pos)
end

function Simulation:undo()
  if #self.undo_stack == 0 then
    return "false"
  end
  self.redo_stack[#self.redo_stack + 1] = { self.buf, self.pos }
  local snap = table.remove(self.undo_stack)
  self.buf = snap[1]
  self.pos = snap[2]
  self.sel = nil
  return "true"
end

function Simulation:redo()
  if #self.redo_stack == 0 then
    return "false"
  end
  self.undo_stack[#self.undo_stack + 1] = { self.buf, self.pos }
  local snap = table.remove(self.redo_stack)
  self.buf = snap[1]
  self.pos = snap[2]
  self.sel = nil
  return "true"
end

function Simulation:select(start, end_)
  if start < 0 or end_ < 0 or start > end_ or end_ > #self.buf then
    return "invalid_request"
  end
  self.sel = { start, end_ }
  return "true"
end

function Simulation:cut()
  if not self.sel or self.sel[1] == self.sel[2] then
    return "invalid_request"
  end
  local start = self.sel[1]
  local end_ = self.sel[2]
  local text = self.buf:sub(start + 1, end_)
  self.buf = self.buf:sub(1, start) .. self.buf:sub(end_ + 1)
  self.clip = text
  self.pos = start
  self.sel = nil
  return text
end

function Simulation:copy_sel()
  if not self.sel or self.sel[1] == self.sel[2] then
    return "invalid_request"
  end
  local start = self.sel[1]
  local end_ = self.sel[2]
  self.clip = self.buf:sub(start + 1, end_)
  return self.clip
end

function Simulation:paste()
  if self.clip == "" then
    return "invalid_request"
  end
  local at = self.pos
  self.buf = self.buf:sub(1, at) .. self.clip .. self.buf:sub(at + 1)
  self.pos = at + #self.clip
  return tostring(#self.buf)
end
