package main

import (
	"sort"
	"strconv"
	"strings"
)

type session struct {
	start    int
	end      int
	rate     int
	position string
}

type promo struct {
	newPos  string
	newComp int
	startTS int
}

type Worker struct {
	workerID     string
	position     string
	compensation int
	inOffice     bool
	enteredAt    *int
	finished     []session
	pendingPromo *promo
}

func (w *Worker) totalTime() int {
	total := 0
	for _, item := range w.finished {
		total += item.end - item.start
	}
	return total
}

func (w *Worker) positionTime(position string) int {
	total := 0
	for _, item := range w.finished {
		if item.position == position {
			total += item.end - item.start
		}
	}
	return total
}

func (w *Worker) applyPromoOnEnter(timestamp int) {
	if w.pendingPromo == nil {
		return
	}
	if timestamp >= w.pendingPromo.startTS {
		w.position = w.pendingPromo.newPos
		w.compensation = w.pendingPromo.newComp
		w.pendingPromo = nil
	}
}

type Simulation struct {
	workers map[string]*Worker
}

func NewSimulation() *Simulation {
	return &Simulation{workers: map[string]*Worker{}}
}

func (s *Simulation) AddWorker(workerID, position string, compensation int) any {
	if _, exists := s.workers[workerID]; exists {
		return "false"
	}
	s.workers[workerID] = &Worker{
		workerID:     workerID,
		position:     position,
		compensation: compensation,
		finished:     []session{},
	}
	return "true"
}

func (s *Simulation) Register(workerID string, timestamp int) any {
	worker, ok := s.workers[workerID]
	if !ok {
		return "invalid_request"
	}
	if worker.inOffice {
		worker.finished = append(worker.finished, session{
			start:    *worker.enteredAt,
			end:      timestamp,
			rate:     worker.compensation,
			position: worker.position,
		})
		worker.inOffice = false
		worker.enteredAt = nil
		return "registered"
	}
	worker.applyPromoOnEnter(timestamp)
	worker.inOffice = true
	entered := timestamp
	worker.enteredAt = &entered
	return "registered"
}

func (s *Simulation) Get(workerID string) any {
	worker, ok := s.workers[workerID]
	if !ok {
		return ""
	}
	return strconv.Itoa(worker.totalTime())
}

func (s *Simulation) TopNWorkers(n int, position string) any {
	matched := make([]*Worker, 0)
	for _, worker := range s.workers {
		if worker.position == position {
			matched = append(matched, worker)
		}
	}
	sort.Slice(matched, func(i, j int) bool {
		ti, tj := matched[i].positionTime(position), matched[j].positionTime(position)
		if ti != tj {
			return ti > tj
		}
		return matched[i].workerID < matched[j].workerID
	})
	if n > len(matched) {
		n = len(matched)
	}
	parts := make([]string, 0, n)
	for _, worker := range matched[:n] {
		parts = append(parts, worker.workerID+"("+strconv.Itoa(worker.positionTime(position))+")")
	}
	return strings.Join(parts, ", ")
}

func (s *Simulation) Promote(workerID, newPosition string, newCompensation, startTimestamp int) any {
	worker, ok := s.workers[workerID]
	if !ok || worker.pendingPromo != nil {
		return "invalid_request"
	}
	worker.pendingPromo = &promo{
		newPos:  newPosition,
		newComp: newCompensation,
		startTS: startTimestamp,
	}
	return "success"
}

func (s *Simulation) CalcSalary(workerID string, startTimestamp, endTimestamp int) any {
	worker, ok := s.workers[workerID]
	if !ok {
		return ""
	}
	total := 0
	for _, item := range worker.finished {
		lo := item.start
		if startTimestamp > lo {
			lo = startTimestamp
		}
		hi := item.end
		if endTimestamp < hi {
			hi = endTimestamp
		}
		if hi > lo {
			total += (hi - lo) * item.rate
		}
	}
	return strconv.Itoa(total)
}
