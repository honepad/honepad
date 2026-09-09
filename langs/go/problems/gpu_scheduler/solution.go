package main

import "sort"

type gpu struct {
	id    string
	mem   int
	jobID string
}

type job struct {
	id       string
	mem      int
	seq      int
	priority int
	state    string
	gpuID    string
}

type Simulation struct {
	gpus     map[string]*gpu
	gpuOrder []string
	jobs     map[string]*job
	nextSeq  int
}

func NewSimulation() *Simulation {
	return &Simulation{
		gpus: map[string]*gpu{},
		jobs: map[string]*job{},
	}
}

func (s *Simulation) AddGpu(gpuID string, mem int) any {
	if mem <= 0 {
		return "invalid_request"
	}
	if _, exists := s.gpus[gpuID]; exists {
		return "false"
	}
	s.gpus[gpuID] = &gpu{id: gpuID, mem: mem}
	s.gpuOrder = append(s.gpuOrder, gpuID)
	return "true"
}

func (s *Simulation) SubmitJob(jobID string, mem int) any {
	if mem <= 0 {
		return "invalid_request"
	}
	if _, exists := s.jobs[jobID]; exists {
		return "false"
	}
	s.jobs[jobID] = &job{id: jobID, mem: mem, seq: s.nextSeq, state: "queued"}
	s.nextSeq++
	return "true"
}

func (s *Simulation) Status(jobID string) any {
	item, ok := s.jobs[jobID]
	if !ok {
		return ""
	}
	return item.state
}

func (s *Simulation) place(item *job, device *gpu) {
	item.state = "running"
	item.gpuID = device.id
	device.jobID = item.id
}

func (s *Simulation) Assign() any {
	queued := make([]*job, 0)
	for _, item := range s.jobs {
		if item.state == "queued" {
			queued = append(queued, item)
		}
	}
	sort.Slice(queued, func(i, j int) bool {
		if queued[i].priority != queued[j].priority {
			return queued[i].priority > queued[j].priority
		}
		return queued[i].seq < queued[j].seq
	})
	for _, item := range queued {
		for _, gpuID := range s.gpuOrder {
			device := s.gpus[gpuID]
			if device.jobID == "" && device.mem >= item.mem {
				s.place(item, device)
				return item.id
			}
		}
	}
	return ""
}

func (s *Simulation) Complete(jobID string) any {
	item, ok := s.jobs[jobID]
	if !ok || item.state != "running" || item.gpuID == "" {
		return "invalid_request"
	}
	s.gpus[item.gpuID].jobID = ""
	item.gpuID = ""
	item.state = "done"
	return "true"
}

func (s *Simulation) Cancel(jobID string) any {
	item, ok := s.jobs[jobID]
	if !ok || item.state == "done" {
		return "invalid_request"
	}
	wasRunning := item.state == "running"
	if wasRunning && item.gpuID != "" {
		s.gpus[item.gpuID].jobID = ""
	}
	delete(s.jobs, jobID)
	if wasRunning {
		s.Assign()
	}
	return "true"
}

func (s *Simulation) SetPriority(jobID string, priority int) any {
	item, ok := s.jobs[jobID]
	if !ok || item.state != "queued" {
		return "invalid_request"
	}
	item.priority = priority
	return "true"
}
