package main

type backend struct {
	id       string
	health   bool
	weight   int
	inflight int
}

type Simulation struct {
	backends  []*backend
	byID      map[string]*backend
	cursor    int
	stickyMap map[string]string
	useLeast  bool
}

func NewSimulation() *Simulation {
	return &Simulation{
		byID:      map[string]*backend{},
		stickyMap: map[string]string{},
	}
}

func (s *Simulation) AddBackend(backendID string) any {
	if _, exists := s.byID[backendID]; exists {
		return "false"
	}
	item := &backend{id: backendID, health: true, weight: 1}
	s.backends = append(s.backends, item)
	s.byID[backendID] = item
	return "true"
}

func (s *Simulation) SetHealth(backendID string, flag int) any {
	item, ok := s.byID[backendID]
	if !ok || (flag != 0 && flag != 1) {
		return "invalid_request"
	}
	item.health = flag == 1
	s.resetCycle()
	return "true"
}

func (s *Simulation) SetWeight(backendID string, weight int) any {
	item, ok := s.byID[backendID]
	if !ok || weight <= 0 {
		return "invalid_request"
	}
	item.weight = weight
	s.resetCycle()
	return "true"
}

func (s *Simulation) resetCycle() {
	s.cursor = 0
	s.useLeast = false
	for _, item := range s.backends {
		item.inflight = 0
	}
}

func (s *Simulation) tickets(items []*backend) []*backend {
	out := make([]*backend, 0)
	for _, item := range items {
		for i := 0; i < item.weight; i++ {
			out = append(out, item)
		}
	}
	return out
}

func (s *Simulation) pick() *backend {
	healthy := make([]*backend, 0)
	for _, item := range s.backends {
		if item.health {
			healthy = append(healthy, item)
		}
	}
	if len(healthy) == 0 {
		return nil
	}
	pool := healthy
	if s.useLeast {
		least := healthy[0].inflight
		for _, item := range healthy[1:] {
			if item.inflight < least {
				least = item.inflight
			}
		}
		pool = make([]*backend, 0)
		for _, item := range healthy {
			if item.inflight == least {
				pool = append(pool, item)
			}
		}
	}
	tickets := s.tickets(pool)
	if len(tickets) == 0 {
		return nil
	}
	chosen := tickets[s.cursor%len(tickets)]
	s.cursor++
	return chosen
}

func (s *Simulation) take() string {
	item := s.pick()
	if item == nil {
		return ""
	}
	item.inflight++
	return item.id
}

func (s *Simulation) Route() any {
	return s.take()
}

func (s *Simulation) Sticky(clientID string) any {
	bound, ok := s.stickyMap[clientID]
	if ok {
		if item, found := s.byID[bound]; found && item.health {
			item.inflight++
			return item.id
		}
	}
	chosen := s.take()
	if chosen != "" {
		s.stickyMap[clientID] = chosen
	}
	return chosen
}

func (s *Simulation) Done(backendID string) any {
	item, ok := s.byID[backendID]
	if !ok || item.inflight <= 0 {
		return "invalid_request"
	}
	item.inflight--
	s.useLeast = true
	return "true"
}
