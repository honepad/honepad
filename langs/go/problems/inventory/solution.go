package main

import (
	"sort"
	"strconv"
	"strings"
)

type item struct {
	sku      string
	name     string
	qty      int
	reserved int
}

type Simulation struct {
	items map[string]*item
}

func NewSimulation() *Simulation {
	return &Simulation{items: map[string]*item{}}
}

func (s *Simulation) CreateItem(sku, name string) any {
	if _, exists := s.items[sku]; exists {
		return "false"
	}
	s.items[sku] = &item{sku: sku, name: name}
	return "true"
}

func (s *Simulation) Stock(sku string, delta int) any {
	item, ok := s.items[sku]
	if !ok {
		return ""
	}
	nxt := item.qty + delta
	if nxt < item.reserved {
		return "invalid_request"
	}
	item.qty = nxt
	return strconv.Itoa(item.qty)
}

func (s *Simulation) GetQty(sku string) any {
	item, ok := s.items[sku]
	if !ok {
		return ""
	}
	return strconv.Itoa(item.qty)
}

func (s *Simulation) ListLow(threshold int) any {
	matched := make([]*item, 0)
	for _, item := range s.items {
		if item.qty <= threshold {
			matched = append(matched, item)
		}
	}
	sort.Slice(matched, func(i, j int) bool {
		if matched[i].qty != matched[j].qty {
			return matched[i].qty < matched[j].qty
		}
		return matched[i].sku < matched[j].sku
	})
	parts := make([]string, 0, len(matched))
	for _, item := range matched {
		parts = append(parts, item.sku+"("+strconv.Itoa(item.qty)+")")
	}
	return strings.Join(parts, ", ")
}

func (s *Simulation) Reserve(sku string, n int) any {
	item, ok := s.items[sku]
	if !ok || n <= 0 || item.reserved+n > item.qty {
		return "invalid_request"
	}
	item.reserved += n
	return "true"
}

func (s *Simulation) Release(sku string, n int) any {
	item, ok := s.items[sku]
	if !ok || n <= 0 || n > item.reserved {
		return "invalid_request"
	}
	item.reserved -= n
	return "true"
}

func (s *Simulation) Ship(sku string, n int) any {
	item, ok := s.items[sku]
	if !ok || n <= 0 || n > item.reserved {
		return "invalid_request"
	}
	item.reserved -= n
	item.qty -= n
	return "true"
}
