// Command my-toolkit runs the toolkit's hooks that need to be fast.
//
//	my-toolkit outbound-guard <scripts/lib dir>   < hook payload
//
// scripts/hooks/outbound-guard.sh starts it from the binary for the machine
// under bin/. It always exits 0; the decision is on stdout.
package main

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"time"

	"github.com/naoking158/custom-slash-command/internal/outboundguard"
)

func main() {
	if len(os.Args) != 3 || os.Args[1] != "outbound-guard" {
		fmt.Fprintln(os.Stderr, "usage: my-toolkit outbound-guard <scripts/lib dir>")
		os.Exit(2)
	}
	libDir, err := filepath.Abs(os.Args[2])
	if err != nil {
		libDir = os.Args[2]
	}
	payload, err := io.ReadAll(os.Stdin)
	if err != nil {
		return
	}
	fmt.Print(outboundguard.Run(payload, outboundguard.EnvFromOS(libDir, time.Now().Unix())))
}
