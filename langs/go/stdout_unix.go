//go:build unix

package main

import (
	"fmt"
	"os"
	"syscall"
)

func sinkStdout() *os.File {
	fd, err := syscall.Dup(1)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
	saved := os.NewFile(uintptr(fd), "stdout")
	null, err := os.OpenFile(os.DevNull, os.O_WRONLY, 0)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
	if err := syscall.Dup2(int(null.Fd()), 1); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
	os.Stdout = null
	sinkHold = null
	return saved
}

var sinkHold *os.File
