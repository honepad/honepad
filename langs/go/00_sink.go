package main

import "os"

// init runs before other package-main inits because this file sorts first.
// A work file named work.go or solution.go cannot print a pass JSON first.
var reportOut *os.File

func init() {
	reportOut = sinkStdout()
}
