#!/bin/bash
# Auto-patch and record any Ebiten example game
# Usage: ./scripts/record-example.sh GAME DURATION
# Example: ./scripts/record-example.sh flappy 10s

set -e

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 GAME DURATION"
    echo "Example: $0 flappy 10s"
    exit 1
fi

GAME=$1
DURATION=$2
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXAMPLE_SRC="$PROJECT_ROOT/ebiten/examples/$GAME"
TEMP_DIR="/tmp/recording-$GAME-$$"
OUTPUT_DIR="$PROJECT_ROOT/recordings"
OUTPUT_FILE="$OUTPUT_DIR/${GAME}.avi"

# Check if example exists
if [ ! -d "$EXAMPLE_SRC" ]; then
    echo "ERROR: Game '$GAME' not found in ebiten/examples/"
    echo "Run 'make offical-list' to see available games"
    exit 1
fi

# Check if main.go exists
if [ ! -f "$EXAMPLE_SRC/main.go" ]; then
    echo "ERROR: main.go not found in $EXAMPLE_SRC"
    exit 1
fi

echo "==> Recording '$GAME' for $DURATION"
echo "    Source: $EXAMPLE_SRC"
echo "    Temp: $TEMP_DIR"
echo "    Output: $OUTPUT_FILE"

# Create temp directory and copy example
echo "==> Copying example to temp directory..."
mkdir -p "$TEMP_DIR"
cp -r "$EXAMPLE_SRC"/* "$TEMP_DIR/"

# Create go.mod in temp directory with replace directive
echo "==> Creating go.mod with replace directive..."
cd "$TEMP_DIR"

cat > go.mod <<EOF
module temp-recording

go 1.21

require (
	github.com/hajimehoshi/ebiten/v2 v2.7.0
	github.com/joeblew999/ebiten-test v0.0.0
)

replace github.com/joeblew999/ebiten-test => $PROJECT_ROOT
EOF

# Patch main.go to add recorder
echo "==> Patching main.go to add recording..."

# Use Go's built-in tools for patching - create a Go program to do the patching
# Put it in a subdirectory to avoid it being included in the build
mkdir -p patcher
cat > patcher/patch.go <<'PATCHEOF'
package main

import (
	"fmt"
	"os"
	"strings"
	"time"
)

func main() {
	data, err := os.ReadFile("../main.go")
	if err != nil {
		panic(err)
	}

	content := string(data)
	outputFile := os.Args[1]
	durationStr := os.Args[2]

	// Parse duration to convert "10s" to time.Duration format
	duration, err := time.ParseDuration(durationStr)
	if err != nil {
		panic(err)
	}

	// Add imports - handle both new and existing import blocks
	needsRecorder := !strings.Contains(content, "github.com/joeblew999/ebiten-test/pkg/recorder")
	needsTime := !strings.Contains(content, "\"time\"")

	if needsRecorder || needsTime {
		// Check if there's already an import block
		if strings.Contains(content, "\nimport (") {
			// Add to existing import block
			importBlockStart := strings.Index(content, "\nimport (")
			insertPoint := importBlockStart + len("\nimport (")

			newImports := ""
			if needsRecorder {
				newImports += "\n\t\"github.com/joeblew999/ebiten-test/pkg/recorder\""
			}
			if needsTime {
				newImports += "\n\t\"time\""
			}

			content = content[:insertPoint] + newImports + content[insertPoint:]
		} else {
			// Create new import block
			importsToAdd := ""
			if needsRecorder {
				importsToAdd += "\t\"github.com/joeblew999/ebiten-test/pkg/recorder\"\n"
			}
			if needsTime {
				importsToAdd += "\t\"time\"\n"
			}

			content = strings.Replace(content, "package main\n",
				"package main\n\nimport (\n"+importsToAdd+")\n", 1)
		}
	}

	// Find and wrap ebiten.RunGame calls with balanced parentheses
	searchStr := "ebiten.RunGame("
	result := ""
	lastIdx := 0

	for {
		idx := strings.Index(content[lastIdx:], searchStr)
		if idx == -1 {
			result += content[lastIdx:]
			break
		}

		idx += lastIdx
		// Add everything before ebiten.RunGame
		result += content[lastIdx:idx]

		// Find the balanced closing paren
		startParen := idx + len(searchStr)
		depth := 1
		endParen := -1
		for i := startParen; i < len(content); i++ {
			if content[i] == '(' {
				depth++
			} else if content[i] == ')' {
				depth--
				if depth == 0 {
					endParen = i
					break
				}
			}
		}

		if endParen == -1 {
			// Couldn't find balanced parens, skip this one
			result += content[idx:startParen]
			lastIdx = startParen
			continue
		}

		// Extract the game argument
		gameArg := content[startParen:endParen]

		// Replace with wrapped version
		wrapped := fmt.Sprintf(`ebiten.RunGame(recorder.WrapGame(%s, "%s", 85, true, %d*time.Nanosecond))`,
			gameArg, outputFile, duration.Nanoseconds())
		result += wrapped

		lastIdx = endParen + 1
	}

	if err := os.WriteFile("../main.go", []byte(result), 0644); err != nil {
		panic(err)
	}
}
PATCHEOF

# Run the patcher
cd patcher && go run patch.go "$OUTPUT_FILE" "$DURATION" && cd ..

# Tidy go.mod
echo "==> Running go mod tidy..."
go mod tidy

# Show what was patched (for debugging)
echo "==> Patched ebiten.RunGame line:"
grep -n "recorder.WrapGame" main.go || echo "WARNING: No recorder.WrapGame found!"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Run the patched game
echo "==> Running game with recording..."
echo "    Recording will auto-stop after $DURATION"
echo "    Output: $OUTPUT_FILE"
go run . 2>&1 | tee game.log || true

# Show log if it exists
if [ -f game.log ]; then
    echo "==> Game log:"
    tail -20 game.log
fi

# Check if recording was created
if [ -f "$OUTPUT_FILE" ]; then
    echo "==> SUCCESS!"
    echo "    Recording saved: $OUTPUT_FILE"
    ls -lh "$OUTPUT_FILE"
else
    echo "==> WARNING: Recording file not found at $OUTPUT_FILE"
fi

# Cleanup
echo "==> Cleaning up temp directory..."
rm -rf "$TEMP_DIR"

echo "==> Done!"
