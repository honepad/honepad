package main

import (
	"fmt"
	"sort"
)

const cashbackDelay = 24 * 60 * 60 * 1000

type Account struct {
	accountID      string
	balance        int
	outgoing       int
	payments       map[string]string
	createdAt      int
	balanceHistory [][2]int
}

func newAccount(accountID string, createdAt int) *Account {
	return &Account{
		accountID:      accountID,
		payments:       map[string]string{},
		createdAt:      createdAt,
		balanceHistory: [][2]int{{createdAt, 0}},
	}
}

func (a *Account) recordBalance(timestamp int) {
	a.balanceHistory = append(a.balanceHistory, [2]int{timestamp, a.balance})
}

func (a *Account) deposit(amount int) int {
	a.balance += amount
	return a.balance
}

func (a *Account) withdraw(amount int) bool {
	if a.balance < amount {
		return false
	}
	a.balance -= amount
	a.outgoing += amount
	return true
}

func (a *Account) getBalanceAt(timeAt int) any {
	if timeAt < a.createdAt {
		return nil
	}
	var result any
	for _, row := range a.balanceHistory {
		if row[0] <= timeAt {
			result = row[1]
		} else {
			break
		}
	}
	return result
}

type cashback struct {
	ts        int
	accountID string
	amount    int
	paymentID string
}

type Simulation struct {
	accounts         map[string]*Account
	paymentCounter   int
	pendingCashbacks []cashback
}

func NewSimulation() *Simulation {
	return &Simulation{
		accounts:         map[string]*Account{},
		pendingCashbacks: []cashback{},
	}
}

func (s *Simulation) processCashbacks(timestamp int) {
	for len(s.pendingCashbacks) > 0 && s.pendingCashbacks[0].ts <= timestamp {
		cb := s.pendingCashbacks[0]
		s.pendingCashbacks = s.pendingCashbacks[1:]
		if acc, ok := s.accounts[cb.accountID]; ok {
			acc.deposit(cb.amount)
			acc.payments[cb.paymentID] = "CASHBACK_RECEIVED"
			acc.recordBalance(cb.ts)
		}
	}
}

func (s *Simulation) CreateAccount(timestamp int, accountID string) any {
	s.processCashbacks(timestamp)
	if _, exists := s.accounts[accountID]; exists {
		return false
	}
	s.accounts[accountID] = newAccount(accountID, timestamp)
	return true
}

func (s *Simulation) Deposit(timestamp int, accountID string, amount int) any {
	s.processCashbacks(timestamp)
	acc, ok := s.accounts[accountID]
	if !ok {
		return nil
	}
	result := acc.deposit(amount)
	acc.recordBalance(timestamp)
	return result
}

func (s *Simulation) Transfer(timestamp int, sourceID, targetID string, amount int) any {
	s.processCashbacks(timestamp)
	source, ok1 := s.accounts[sourceID]
	target, ok2 := s.accounts[targetID]
	if !ok1 || !ok2 || sourceID == targetID {
		return nil
	}
	if !source.withdraw(amount) {
		return nil
	}
	target.deposit(amount)
	source.recordBalance(timestamp)
	target.recordBalance(timestamp)
	return source.balance
}

func (s *Simulation) TopSpenders(timestamp int, n int) any {
	s.processCashbacks(timestamp)
	ids := make([]string, 0, len(s.accounts))
	for id := range s.accounts {
		ids = append(ids, id)
	}
	sort.Slice(ids, func(i, j int) bool {
		oi, oj := s.accounts[ids[i]].outgoing, s.accounts[ids[j]].outgoing
		if oi != oj {
			return oi > oj
		}
		return ids[i] < ids[j]
	})
	if n > len(ids) {
		n = len(ids)
	}
	out := make([]string, 0, n)
	for _, id := range ids[:n] {
		out = append(out, fmt.Sprintf("%s(%d)", id, s.accounts[id].outgoing))
	}
	return out
}

func (s *Simulation) Pay(timestamp int, accountID string, amount int) any {
	s.processCashbacks(timestamp)
	acc, ok := s.accounts[accountID]
	if !ok {
		return nil
	}
	if !acc.withdraw(amount) {
		return nil
	}
	s.paymentCounter++
	paymentID := fmt.Sprintf("payment%d", s.paymentCounter)
	acc.payments[paymentID] = "IN_PROGRESS"
	acc.recordBalance(timestamp)
	s.pendingCashbacks = append(s.pendingCashbacks, cashback{
		ts:        timestamp + cashbackDelay,
		accountID: accountID,
		amount:    amount * 2 / 100,
		paymentID: paymentID,
	})
	return paymentID
}

func (s *Simulation) GetPaymentStatus(timestamp int, accountID, payment string) any {
	s.processCashbacks(timestamp)
	acc, ok := s.accounts[accountID]
	if !ok {
		return nil
	}
	status, ok := acc.payments[payment]
	if !ok {
		return nil
	}
	return status
}

func (s *Simulation) MergeAccounts(timestamp int, keepID, dropID string) any {
	s.processCashbacks(timestamp)
	if keepID == dropID {
		return false
	}
	keep, ok1 := s.accounts[keepID]
	drop, ok2 := s.accounts[dropID]
	if !ok1 || !ok2 {
		return false
	}
	keep.balance += drop.balance
	keep.outgoing += drop.outgoing
	for key, value := range drop.payments {
		keep.payments[key] = value
	}
	keep.balanceHistory = append(keep.balanceHistory, drop.balanceHistory...)
	sort.Slice(keep.balanceHistory, func(i, j int) bool {
		return keep.balanceHistory[i][0] < keep.balanceHistory[j][0]
	})
	if drop.createdAt < keep.createdAt {
		keep.createdAt = drop.createdAt
	}
	keep.recordBalance(timestamp)
	for i := range s.pendingCashbacks {
		if s.pendingCashbacks[i].accountID == dropID {
			s.pendingCashbacks[i].accountID = keepID
		}
	}
	delete(s.accounts, dropID)
	return true
}

func (s *Simulation) GetBalance(timestamp int, accountID string, timeAt int) any {
	s.processCashbacks(timestamp)
	acc, ok := s.accounts[accountID]
	if !ok {
		return nil
	}
	return acc.getBalanceAt(timeAt)
}
