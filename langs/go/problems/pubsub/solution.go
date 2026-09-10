package main

import (
	"sort"
	"strconv"
	"strings"
)

type Simulation struct {
	subs     map[string][]string
	inboxMap map[string][]string
	retained map[string]string
}

func NewSimulation() *Simulation {
	return &Simulation{
		subs:     map[string][]string{},
		inboxMap: map[string][]string{},
		retained: map[string]string{},
	}
}

func (s *Simulation) Subscribe(topic, client string) any {
	clients := s.subs[topic]
	for _, existing := range clients {
		if existing == client {
			return "false"
		}
	}
	s.subs[topic] = append(clients, client)
	if msg, ok := s.retained[topic]; ok {
		s.inboxMap[client] = append(s.inboxMap[client], topic+":"+msg)
	}
	return "true"
}

func (s *Simulation) Unsubscribe(topic, client string) any {
	clients := s.subs[topic]
	idx := -1
	for i, existing := range clients {
		if existing == client {
			idx = i
			break
		}
	}
	if idx < 0 {
		return "false"
	}
	s.subs[topic] = append(clients[:idx], clients[idx+1:]...)
	if len(s.subs[topic]) == 0 {
		delete(s.subs, topic)
	}
	return "true"
}

func (s *Simulation) Publish(topic, message string) any {
	clients := s.subs[topic]
	payload := topic + ":" + message
	for _, client := range clients {
		s.inboxMap[client] = append(s.inboxMap[client], payload)
	}
	return strconv.Itoa(len(clients))
}

func (s *Simulation) Inbox(client string) any {
	return strings.Join(s.inboxMap[client], ", ")
}

func (s *Simulation) ListTopics() any {
	topics := make([]string, 0, len(s.subs))
	for topic := range s.subs {
		topics = append(topics, topic)
	}
	sort.Strings(topics)
	return strings.Join(topics, ", ")
}

func (s *Simulation) Subscribers(topic string) any {
	clients := append([]string{}, s.subs[topic]...)
	sort.Strings(clients)
	return strings.Join(clients, ", ")
}

func (s *Simulation) Peek(client string) any {
	items := s.inboxMap[client]
	if len(items) == 0 {
		return ""
	}
	return items[0]
}

func (s *Simulation) Ack(client string, n int) any {
	items, ok := s.inboxMap[client]
	if n <= 0 || !ok {
		return "invalid_request"
	}
	if n > len(items) {
		return "invalid_request"
	}
	s.inboxMap[client] = items[n:]
	return strconv.Itoa(len(s.inboxMap[client]))
}

func (s *Simulation) Retain(topic, message string) any {
	s.retained[topic] = message
	return ""
}
