class Simulation {
  constructor() {}
  insert(pos, text) { throw new Error('not implemented'); }
  erase(pos, n) { throw new Error('not implemented'); }
  getText() { throw new Error('not implemented'); }
  length() { throw new Error('not implemented'); }
  move(pos) { throw new Error('not implemented'); }
  typeText(text) { throw new Error('not implemented'); }
  cursor() { throw new Error('not implemented'); }
  undo() { throw new Error('not implemented'); }
  redo() { throw new Error('not implemented'); }
  select(start, end) { throw new Error('not implemented'); }
  cut() { throw new Error('not implemented'); }
  copySel() { throw new Error('not implemented'); }
  paste() { throw new Error('not implemented'); }
}
module.exports = { Simulation };
