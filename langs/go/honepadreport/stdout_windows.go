//go:build windows

package honepadreport

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
	// syscall.SetStdHandle is not in the Go 1.26 syscall package.
	setStdHandle := syscall.NewLazyDLL("kernel32.dll").NewProc("SetStdHandle")
	r1, _, err := setStdHandle.Call(uintptr(^uint32(10)), null.Fd())
	if r1 == 0 {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
	os.Stdout = null
	sinkHold = null
	return saved
}

var sinkHold *os.File
