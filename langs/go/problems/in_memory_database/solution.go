package main

import (
	"sort"
	"strconv"
	"strings"
)

type fieldVal struct {
	value  string
	expiry *int
}

type InMemoryDatabase struct {
	database         map[string]map[string]fieldVal
	backupTimestamps []int
	backupStates     []map[string]map[string]fieldVal
}

func NewInMemoryDatabase() *InMemoryDatabase {
	return &InMemoryDatabase{
		database: map[string]map[string]fieldVal{},
	}
}

func (db *InMemoryDatabase) setInternal(key, field, value string, expiry *int) string {
	if _, ok := db.database[key]; !ok {
		db.database[key] = map[string]fieldVal{}
	}
	db.database[key][field] = fieldVal{value: value, expiry: expiry}
	return ""
}

func (db *InMemoryDatabase) isAlive(key, field string, timestamp int) bool {
	fields, ok := db.database[key]
	if !ok {
		return false
	}
	fv, ok := fields[field]
	if !ok {
		return false
	}
	if fv.expiry == nil {
		return true
	}
	return timestamp < *fv.expiry
}

func (db *InMemoryDatabase) Set(key, field, value string) any {
	return db.setInternal(key, field, value, nil)
}

func (db *InMemoryDatabase) Get(key, field string) any {
	fields, ok := db.database[key]
	if !ok {
		return ""
	}
	fv, ok := fields[field]
	if !ok {
		return ""
	}
	return fv.value
}

func (db *InMemoryDatabase) Delete(key, field string) any {
	fields, ok := db.database[key]
	if !ok {
		return "false"
	}
	if _, ok := fields[field]; !ok {
		return "false"
	}
	delete(fields, field)
	return "true"
}

func (db *InMemoryDatabase) Scan(key string) any {
	fields, ok := db.database[key]
	if !ok {
		return ""
	}
	names := make([]string, 0, len(fields))
	for field := range fields {
		names = append(names, field)
	}
	sort.Strings(names)
	parts := make([]string, 0, len(names))
	for _, field := range names {
		parts = append(parts, field+"("+fields[field].value+")")
	}
	return strings.Join(parts, ", ")
}

func (db *InMemoryDatabase) ScanByPrefix(key, prefix string) any {
	fields, ok := db.database[key]
	if !ok {
		return ""
	}
	names := make([]string, 0)
	for field := range fields {
		if strings.HasPrefix(field, prefix) {
			names = append(names, field)
		}
	}
	sort.Strings(names)
	parts := make([]string, 0, len(names))
	for _, field := range names {
		parts = append(parts, field+"("+fields[field].value+")")
	}
	return strings.Join(parts, ", ")
}

func (db *InMemoryDatabase) SetAt(key, field, value string, timestamp int) any {
	_ = timestamp
	return db.setInternal(key, field, value, nil)
}

func (db *InMemoryDatabase) SetAtWithTtl(key, field, value string, timestamp, ttl int) any {
	expiry := timestamp + ttl
	return db.setInternal(key, field, value, &expiry)
}

func (db *InMemoryDatabase) DeleteAt(key, field string, timestamp int) any {
	if !db.isAlive(key, field, timestamp) {
		return "false"
	}
	delete(db.database[key], field)
	return "true"
}

func (db *InMemoryDatabase) GetAt(key, field string, timestamp int) any {
	if !db.isAlive(key, field, timestamp) {
		return ""
	}
	return db.database[key][field].value
}

func (db *InMemoryDatabase) ScanAt(key string, timestamp int) any {
	fields, ok := db.database[key]
	if !ok {
		return ""
	}
	names := make([]string, 0)
	for field := range fields {
		if db.isAlive(key, field, timestamp) {
			names = append(names, field)
		}
	}
	sort.Strings(names)
	parts := make([]string, 0, len(names))
	for _, field := range names {
		parts = append(parts, field+"("+fields[field].value+")")
	}
	return strings.Join(parts, ", ")
}

func (db *InMemoryDatabase) ScanByPrefixAt(key, prefix string, timestamp int) any {
	fields, ok := db.database[key]
	if !ok {
		return ""
	}
	names := make([]string, 0)
	for field := range fields {
		if strings.HasPrefix(field, prefix) && db.isAlive(key, field, timestamp) {
			names = append(names, field)
		}
	}
	sort.Strings(names)
	parts := make([]string, 0, len(names))
	for _, field := range names {
		parts = append(parts, field+"("+fields[field].value+")")
	}
	return strings.Join(parts, ", ")
}

func (db *InMemoryDatabase) Backup(timestamp int) any {
	state := map[string]map[string]fieldVal{}
	for key, fields := range db.database {
		for field, fv := range fields {
			if !db.isAlive(key, field, timestamp) {
				continue
			}
			var remaining *int
			if fv.expiry != nil {
				r := *fv.expiry - timestamp
				remaining = &r
			}
			if _, ok := state[key]; !ok {
				state[key] = map[string]fieldVal{}
			}
			state[key][field] = fieldVal{value: fv.value, expiry: remaining}
		}
	}
	db.backupTimestamps = append(db.backupTimestamps, timestamp)
	db.backupStates = append(db.backupStates, state)
	return strconv.Itoa(len(state))
}

func (db *InMemoryDatabase) Restore(timestamp int, timestampToRestore int) any {
	idx := -1
	for i, ts := range db.backupTimestamps {
		if ts <= timestampToRestore {
			idx = i
		}
	}
	if idx < 0 {
		db.database = map[string]map[string]fieldVal{}
		return ""
	}
	backup := db.backupStates[idx]
	db.database = map[string]map[string]fieldVal{}
	for key, fields := range backup {
		for field, fv := range fields {
			var expiry *int
			if fv.expiry != nil {
				e := timestamp + *fv.expiry
				expiry = &e
			}
			db.setInternal(key, field, fv.value, expiry)
		}
	}
	return ""
}
