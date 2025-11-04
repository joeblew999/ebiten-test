# ebiten-test

## CLAUDE

repo: https://github.com/joeblew99/ebiten-test

filepath: /Users/apple/workspace/go/src/github.com/joeblew999/ebiten-test

**REQUIREMENTS:**

- Use Makefile always for all operations
- Manage the go.work file (when needed)
- Manage the Makefile and keep things idempotent
- **MUST test the Makefile after any changes** - run `make help` and `make print` to validate
- **MUST test what you built using the Makefile every time** - never stop without testing
- Claude is responsible for validating - DO NOT ask the user to test
- After implementing features, MUST run the relevant Makefile targets to verify they work

## local examples

using https://github.com/quasilyte/ebitengine-input

## offical examples

https://github.com/hajimehoshi/ebiten.git

https://ebitengine.org/en/examples/

## recording

The project includes an MJPEG/AVI recorder using pure Go (no CGO, no ffmpeg).

### Quick Start - Record Official Examples

Record any of the 86 official Ebiten examples WITHOUT modifying them:

```bash
# List available games
make offical-list

# Record any game for specified duration
make record-offical GAME=flappy DURATION=10s
make record-offical GAME=blocks DURATION=15s
make record-offical GAME=2048 DURATION=20s

# Quick shortcuts for popular games
make record-flappy   # 10 seconds of flappy bird
make record-blocks   # 10 seconds of blocks
make record-2048     # 10 seconds of 2048

# Record ALL 86 games (sequential, resume-able)
make record-all-games
```

Recordings are saved to `recordings/GAME.avi` and are ready for YouTube upload.

**Batch recording features:**
- Automatically skips games that already have recordings (resume capability)
- Continues on failure (logs warning for failed games)
- Shows progress counter `[23/86]`
- Final summary of successful recordings

### Manual Recording Examples

- `make recording-demo` - Records 10 seconds of gameplay as MJPEG AVI
- `make recording-run` - Manual recording (press R to record)

### Upload to YouTube

**⚠️ CRITICAL: YouTube API Quota Limits**

YouTube API has a **10,000 units/day quota limit**. Each upload costs **1,600 units** = **max 6 videos/day**.

**For 80+ videos, you have 3 options:**
1. **Manual browser upload** (fastest): `make upload-all-browser` - No quota, 15 videos at a time
2. **Request quota increase** (best for automation): Requires phone + ID verification, 3-5 day approval
3. **Daily API uploads** (slowest): 6 videos/day = 14 days total

📖 **See [YOUTUBE_API_QUOTA.md](YOUTUBE_API_QUOTA.md) for detailed quota guide**

**Single recordings:**
- `make upload-youtube` - Upload demo.avi to YouTube (requires OAuth setup)
- `make upload-youtube FILE=flappy.avi` - Upload specific recording
- `make upload-browser` - Open YouTube Studio to drag-and-drop demo.avi
- `make upload-browser FILE=flappy.avi` - Open Studio for specific recording

**Batch upload all recordings:**
- `make upload-all-youtube` - Upload all recordings via OAuth (⚠️ quota limited to ~6/day)
- `make upload-all-browser` - Open YouTube Studio for manual batch upload (✅ no quota)

The uploader automatically names videos as "Ebiten Example: GAMENAME" based on the filename. If you specify a wrong filename, it will show you all available recordings.

### How It Works

The auto-recording system uses a **wrapper pattern**:

1. **`pkg/recorder/wrapper.go`** - Wraps any `ebiten.Game` to add recording
2. **`scripts/record-example.sh`** - Auto-patches examples temporarily:
   - Copies game to `/tmp`
   - Injects `recorder.WrapGame()` before `ebiten.RunGame()`
   - Runs with recording enabled
   - Cleans up (no permanent modifications)

This allows recording ANY Ebiten game without modifying the original source code.

### Using Wrapper in Your Own Games

```go
import "github.com/joeblew999/ebiten-test/pkg/recorder"

func main() {
    game := &YourGame{}

    // Wrap with recording (auto-record 30s at 85% quality)
    wrapped := recorder.WrapGame(game, "output.avi", 85, true, 30*time.Second)

    ebiten.RunGame(wrapped)
}
```

Manual controls: Press **R** to toggle recording, **Esc** to save and exit.

### Format Details

**MJPEG (Motion JPEG) in AVI container**:
- Pure Go implementation using `github.com/icza/mjpeg`
- YouTube-compatible video format
- No external dependencies (no ffmpeg, no CGO)
- Cross-platform: macOS, Windows, Linux
- Good quality at reasonable file sizes
- Default: 30 FPS, 85% JPEG quality

### YouTube Upload Setup

**Easy Setup Options:**

1. **Interactive Setup (Recommended)** - Guided wizard that opens each URL:
   ```bash
   make youtube-setup
   ```
   This interactive wizard will:
   - Open each Google Cloud Console page with your project ID already in the URL
   - Show you exactly what to click at each step
   - Validate your `client_secrets.json` automatically
   - Takes ~5 minutes

2. **Manual Setup with Direct Links** - View all URLs at once:
   ```bash
   make youtube-setup-help
   ```
   Shows project-specific URLs for:
   - Enabling YouTube Data API v3
   - Configuring OAuth Consent Screen
   - Creating OAuth 2.0 Client ID

3. **Validate Existing Setup**:
   ```bash
   make youtube-check-oauth
   ```
   Checks if your OAuth configuration is valid and ready to use.

**Note:** YouTube has a 15-video limit for browser drag-and-drop uploads. For automated uploads of all 80+ recordings, use `make upload-all-youtube` with OAuth (no limit).

### Google Cloud Project Management

**View project information:**
```bash
make gcloud-project-info
```
Shows project details, status, and quick links.

**Delete project (WARNING: PERMANENT!):**
```bash
make gcloud-delete-project
```
Permanently deletes the Google Cloud project. Requires typing the project ID to confirm. The project will be scheduled for deletion with a 30-day recovery window.

**Note:** These commands require the `gcloud` CLI tool. Install with:
- macOS: `brew install google-cloud-sdk`
- Linux: `curl https://sdk.cloud.google.com | bash`
- Windows: https://cloud.google.com/sdk/docs/install
