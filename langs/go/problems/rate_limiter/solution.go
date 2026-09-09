package main

import "strconv"

type keyState struct {
	limit     int
	window    int
	windowID  int
	hasWindow bool
	used      int
}

type Simulation struct {
	keys map[string]*keyState
}

func NewSimulation() *Simulation {
	return &Simulation{keys: map[string]*keyState{}}
}

func (s *Simulation) state(key string) *keyState {
	item, ok := s.keys[key]
	if !ok {
		item = &keyState{limit: 3, window: 10}
		s.keys[key] = item
	}
	return item
}

func usedAt(item *keyState, timestamp int, persist bool) int {
	windowID := timestamp / item.window
	if !item.hasWindow || windowID != item.windowID {
		if persist {
			item.windowID = windowID
			item.hasWindow = true
			item.used = 0
		}
		return 0
	}
	return item.used
}

func (s *Simulation) Allow(key string, timestamp int) any {
	return s.AllowWeighted(key, 1, timestamp)
}

func (s *Simulation) Configure(key string, limit, window int) any {
	if limit <= 0 || window <= 0 {
		return "invalid_request"
	}
	item := s.state(key)
	item.limit = limit
	item.window = window
	item.hasWindow = false
	item.used = 0
	return "true"
}

func (s *Simulation) Remaining(key string, timestamp int) any {
	item := s.state(key)
	used := usedAt(item, timestamp, false)
	return strconv.Itoa(item.limit - used)
}

func (s *Simulation) AllowWeighted(key string, cost, timestamp int) any {
	if cost <= 0 {
		return "invalid_request"
	}
	item := s.state(key)
	usedAt(item, timestamp, true)
	if item.used+cost > item.limit {
		return "false"
	}
	item.used += cost
	return "true"
}
