package main

import "strconv"

type editorSnap struct {
	buf string
	pos int
}

type Simulation struct {
	buf       string
	pos       int
	undoStack []editorSnap
	redoStack []editorSnap
	selStart  int
	selEnd    int
	clip      string
}

func NewSimulation() *Simulation {
	return &Simulation{selStart: -1, selEnd: -1}
}

func (s *Simulation) push() {
	s.undoStack = append(s.undoStack, editorSnap{buf: s.buf, pos: s.pos})
	s.redoStack = nil
	s.selStart = -1
	s.selEnd = -1
}

func (s *Simulation) Insert(pos int, text string) any {
	if pos < 0 || pos > len(s.buf) {
		return "invalid_request"
	}
	s.push()
	s.buf = s.buf[:pos] + text + s.buf[pos:]
	return strconv.Itoa(len(s.buf))
}

func (s *Simulation) Erase(pos, n int) any {
	if n <= 0 || pos < 0 || pos+n > len(s.buf) {
		return "invalid_request"
	}
	s.push()
	deleted := s.buf[pos : pos+n]
	s.buf = s.buf[:pos] + s.buf[pos+n:]
	if s.pos > len(s.buf) {
		s.pos = len(s.buf)
	}
	return deleted
}

func (s *Simulation) GetText() any {
	return s.buf
}

func (s *Simulation) Length() any {
	return strconv.Itoa(len(s.buf))
}

func (s *Simulation) Move(pos int) any {
	if pos < 0 || pos > len(s.buf) {
		return "invalid_request"
	}
	s.pos = pos
	return "true"
}

func (s *Simulation) TypeText(text string) any {
	s.push()
	at := s.pos
	s.buf = s.buf[:at] + text + s.buf[at:]
	s.pos = at + len(text)
	return strconv.Itoa(len(s.buf))
}

func (s *Simulation) Cursor() any {
	return strconv.Itoa(s.pos)
}

func (s *Simulation) Undo() any {
	if len(s.undoStack) == 0 {
		return "false"
	}
	s.redoStack = append(s.redoStack, editorSnap{buf: s.buf, pos: s.pos})
	snap := s.undoStack[len(s.undoStack)-1]
	s.undoStack = s.undoStack[:len(s.undoStack)-1]
	s.buf = snap.buf
	s.pos = snap.pos
	s.selStart = -1
	s.selEnd = -1
	return "true"
}

func (s *Simulation) Redo() any {
	if len(s.redoStack) == 0 {
		return "false"
	}
	s.undoStack = append(s.undoStack, editorSnap{buf: s.buf, pos: s.pos})
	snap := s.redoStack[len(s.redoStack)-1]
	s.redoStack = s.redoStack[:len(s.redoStack)-1]
	s.buf = snap.buf
	s.pos = snap.pos
	s.selStart = -1
	s.selEnd = -1
	return "true"
}

func (s *Simulation) Select(start, end int) any {
	if start < 0 || end < 0 || start > end || end > len(s.buf) {
		return "invalid_request"
	}
	s.selStart = start
	s.selEnd = end
	return "true"
}

func (s *Simulation) Cut() any {
	if s.selStart < 0 || s.selStart == s.selEnd {
		return "invalid_request"
	}
	text := s.buf[s.selStart:s.selEnd]
	s.buf = s.buf[:s.selStart] + s.buf[s.selEnd:]
	s.clip = text
	s.pos = s.selStart
	s.selStart = -1
	s.selEnd = -1
	return text
}

func (s *Simulation) CopySel() any {
	if s.selStart < 0 || s.selStart == s.selEnd {
		return "invalid_request"
	}
	s.clip = s.buf[s.selStart:s.selEnd]
	return s.clip
}

func (s *Simulation) Paste() any {
	if s.clip == "" {
		return "invalid_request"
	}
	at := s.pos
	s.buf = s.buf[:at] + s.clip + s.buf[at:]
	s.pos = at + len(s.clip)
	return strconv.Itoa(len(s.buf))
}
