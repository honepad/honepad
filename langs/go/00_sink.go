package main

// init runs before other package-main inits because this file sorts first.
// A work file named work.go or solution.go cannot print a pass JSON first.
func init() {
	sinkStdout()
}
