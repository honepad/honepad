package honepadreport

import "os"

// Imported-package init runs before any package-main init, including work.
// Capture the nonce path, drop it from the environment, then sink stdout.
func init() {
	reportPath = os.Getenv("HONEPAD_REPORT")
	_ = os.Unsetenv("HONEPAD_REPORT")
	sinkStdout()
}

var reportPath string
