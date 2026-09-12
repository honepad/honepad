//go:build windows

package main

import (
	"fmt"
	"os"
	"syscall"
)

func sinkStdout() *os.File {
	h, err := syscall.GetStdHandle(syscall.STD_OUTPUT_HANDLE)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
	proc, err := syscall.GetCurrentProcess()
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
	var dup syscall.Handle
	err = syscall.DuplicateHandle(proc, h, proc, &dup, 0, true, syscall.DUPLICATE_SAME_ACCESS)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
	saved := os.NewFile(uintptr(dup), "stdout")
	null, err := os.OpenFile(os.DevNull, os.O_WRONLY, 0)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
	if err := syscall.SetStdHandle(syscall.STD_OUTPUT_HANDLE, syscall.Handle(null.Fd())); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
	os.Stdout = null
	sinkHold = null
	return saved
}

var sinkHold *os.File
