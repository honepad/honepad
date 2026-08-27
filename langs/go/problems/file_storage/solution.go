package main

import (
	"sort"
	"strconv"
	"strings"
)

type storedFile struct {
	name  string
	size  int
	owner string
}

type Simulation struct {
	files    map[string]storedFile
	capacity map[string]*int
	backups  map[string]map[string]int
}

func NewSimulation() *Simulation {
	return &Simulation{
		files:    map[string]storedFile{},
		capacity: map[string]*int{"admin": nil},
		backups:  map[string]map[string]int{},
	}
}

func (s *Simulation) used(userID string) int {
	total := 0
	for _, item := range s.files {
		if item.owner == userID {
			total += item.size
		}
	}
	return total
}

func (s *Simulation) remaining(userID string) *int {
	cap, ok := s.capacity[userID]
	if !ok || cap == nil {
		return nil
	}
	left := *cap - s.used(userID)
	return &left
}

func (s *Simulation) AddFile(name string, size int) any {
	if _, exists := s.files[name]; exists {
		return "false"
	}
	s.files[name] = storedFile{name: name, size: size, owner: "admin"}
	return "true"
}

func (s *Simulation) GetFileSize(name string) any {
	item, ok := s.files[name]
	if !ok {
		return ""
	}
	return strconv.Itoa(item.size)
}

func (s *Simulation) DeleteFile(name string) any {
	item, ok := s.files[name]
	if !ok {
		return ""
	}
	delete(s.files, name)
	return strconv.Itoa(item.size)
}

func (s *Simulation) CopyFile(source, dest string) any {
	src, ok := s.files[source]
	if !ok {
		return ""
	}
	if source == dest {
		return strconv.Itoa(src.size)
	}
	destItem, destExists := s.files[dest]
	owner := src.owner
	extra := src.size
	if destExists {
		owner = destItem.owner
		extra = src.size - destItem.size
	}
	left := s.remaining(owner)
	if left != nil && extra > *left {
		return ""
	}
	if !destExists {
		s.files[dest] = storedFile{name: dest, size: src.size, owner: owner}
	} else {
		destItem.size = src.size
		s.files[dest] = destItem
	}
	return strconv.Itoa(src.size)
}

func (s *Simulation) GetNLargest(prefix string, n int) any {
	matched := make([]storedFile, 0)
	for _, item := range s.files {
		if strings.HasPrefix(item.name, prefix) {
			matched = append(matched, item)
		}
	}
	sort.Slice(matched, func(i, j int) bool {
		if matched[i].size != matched[j].size {
			return matched[i].size > matched[j].size
		}
		return matched[i].name < matched[j].name
	})
	if n > len(matched) {
		n = len(matched)
	}
	parts := make([]string, 0, n)
	for _, item := range matched[:n] {
		parts = append(parts, item.name+"("+strconv.Itoa(item.size)+")")
	}
	return strings.Join(parts, ", ")
}

func (s *Simulation) AddUser(userID string, capacity int) any {
	if _, exists := s.capacity[userID]; exists {
		return "false"
	}
	value := capacity
	s.capacity[userID] = &value
	return "true"
}

func (s *Simulation) AddFileBy(userID, name string, size int) any {
	if _, exists := s.capacity[userID]; !exists {
		return ""
	}
	if _, exists := s.files[name]; exists {
		return ""
	}
	left := s.remaining(userID)
	if left != nil && size > *left {
		return ""
	}
	s.files[name] = storedFile{name: name, size: size, owner: userID}
	after := s.remaining(userID)
	if after == nil {
		return ""
	}
	return strconv.Itoa(*after)
}

func (s *Simulation) MergeUser(userID1, userID2 string) any {
	if userID1 == userID2 {
		return ""
	}
	cap1, ok1 := s.capacity[userID1]
	cap2, ok2 := s.capacity[userID2]
	if !ok1 || !ok2 || cap1 == nil || cap2 == nil {
		return ""
	}
	sum := *cap1 + *cap2
	s.capacity[userID1] = &sum
	for name, item := range s.files {
		if item.owner == userID2 {
			item.owner = userID1
			s.files[name] = item
		}
	}
	delete(s.capacity, userID2)
	delete(s.backups, userID2)
	left := s.remaining(userID1)
	if left == nil {
		return ""
	}
	return strconv.Itoa(*left)
}

func (s *Simulation) BackupUser(userID string) any {
	if _, exists := s.capacity[userID]; !exists {
		return ""
	}
	snap := map[string]int{}
	for _, item := range s.files {
		if item.owner == userID {
			snap[item.name] = item.size
		}
	}
	s.backups[userID] = snap
	return strconv.Itoa(len(snap))
}

func (s *Simulation) RestoreUser(userID string) any {
	if _, exists := s.capacity[userID]; !exists {
		return ""
	}
	for name, item := range s.files {
		if item.owner == userID {
			delete(s.files, name)
		}
	}
	snap, ok := s.backups[userID]
	if !ok {
		return "0"
	}
	restored := 0
	for name, size := range snap {
		if _, taken := s.files[name]; taken {
			continue
		}
		left := s.remaining(userID)
		if left != nil && size > *left {
			continue
		}
		s.files[name] = storedFile{name: name, size: size, owner: userID}
		restored++
	}
	return strconv.Itoa(restored)
}
