package recorder

import (
	"fmt"
	"log"
	"os"
	"time"

	"github.com/hajimehoshi/ebiten/v2"
	"github.com/hajimehoshi/ebiten/v2/ebitenutil"
	"github.com/hajimehoshi/ebiten/v2/inpututil"
)

// GameWrapper wraps any ebiten.Game to add recording capability
// without modifying the original game code
type GameWrapper struct {
	game            ebiten.Game
	recorder        *MJPEGRecorder
	recording       bool
	recordingStatus string
	autoRecord      bool
	autoStart       time.Time
	autoDuration    time.Duration
	hasStarted      bool
}

// WrapGame wraps an existing ebiten.Game with recording capability
// outputPath: where to save the recording
// quality: JPEG quality (1-100, recommend 85)
// autoRecord: if true, starts recording immediately
// autoDuration: how long to record before auto-stopping (0 = manual)
func WrapGame(game ebiten.Game, outputPath string, quality int, autoRecord bool, autoDuration time.Duration) *GameWrapper {
	return &GameWrapper{
		game:         game,
		recorder:     NewMJPEGRecorder(0, 30, outputPath, quality),
		autoRecord:   autoRecord,
		autoDuration: autoDuration,
	}
}

// Update implements ebiten.Game.Update
func (w *GameWrapper) Update() error {
	// Call original game's Update
	if err := w.game.Update(); err != nil {
		return err
	}

	// Handle auto-record start (first frame only)
	if w.autoRecord && !w.hasStarted {
		// Get screen size from Layout
		width, height := w.game.Layout(0, 0)
		if err := w.recorder.Start(width, height); err != nil {
			log.Printf("Failed to start auto-recording: %v", err)
		} else {
			w.recording = true
			w.autoStart = time.Now()
			w.hasStarted = true
			log.Printf("Auto-recording started: %s", w.recorder.GetOutputPath())
		}
	}

	// Handle auto-record stop
	if w.autoRecord && w.recording && w.autoDuration > 0 {
		elapsed := time.Since(w.autoStart)
		if elapsed >= w.autoDuration {
			if err := w.recorder.Stop(); err != nil {
				log.Printf("Failed to save recording: %v", err)
				os.Exit(1)
			}
			log.Printf("Recording saved to: %s (%d frames)", w.recorder.GetOutputPath(), w.recorder.FrameCount())
			os.Exit(0)
		}
		w.recordingStatus = fmt.Sprintf("REC: %.1fs/%.1fs (%d frames)",
			elapsed.Seconds(), w.autoDuration.Seconds(), w.recorder.FrameCount())
	}

	// Manual recording toggle with R key (only if not auto-recording)
	if !w.autoRecord && inpututil.IsKeyJustPressed(ebiten.KeyR) {
		if w.recording {
			// Stop recording
			if err := w.recorder.Stop(); err != nil {
				w.recordingStatus = fmt.Sprintf("ERROR: %v", err)
				log.Printf("Failed to stop recording: %v", err)
			} else {
				w.recording = false
				msg := fmt.Sprintf("Saved: %s (%d frames)", w.recorder.GetOutputPath(), w.recorder.FrameCount())
				w.recordingStatus = msg
				log.Println(msg)
			}
		} else {
			// Start recording
			width, height := w.game.Layout(0, 0)
			if err := w.recorder.Start(width, height); err != nil {
				w.recordingStatus = fmt.Sprintf("ERROR: %v", err)
				log.Printf("Failed to start recording: %v", err)
			} else {
				w.recording = true
				w.recordingStatus = "RECORDING (Press R to stop)"
				log.Println("Recording started (Press R to stop)")
			}
		}
	}

	// Update status during manual recording
	if !w.autoRecord && w.recording {
		w.recordingStatus = fmt.Sprintf("REC: %d frames (Press R to stop)", w.recorder.FrameCount())
	}

	// Save and exit on Escape
	if inpututil.IsKeyJustPressed(ebiten.KeyEscape) {
		if w.recording {
			w.recorder.Stop()
			log.Printf("Recording saved on exit: %s", w.recorder.GetOutputPath())
		}
		os.Exit(0)
	}

	return nil
}

// Draw implements ebiten.Game.Draw
func (w *GameWrapper) Draw(screen *ebiten.Image) {
	// Call original game's Draw
	w.game.Draw(screen)

	// Draw recording status overlay
	if w.recordingStatus != "" {
		ebitenutil.DebugPrintAt(screen, w.recordingStatus, 10, 10)
	}

	// Capture frame if recording
	if w.recording {
		if err := w.recorder.CaptureFrame(screen); err != nil {
			log.Printf("Failed to capture frame: %v", err)
		}
	}
}

// Layout implements ebiten.Game.Layout
func (w *GameWrapper) Layout(outsideWidth, outsideHeight int) (int, int) {
	return w.game.Layout(outsideWidth, outsideHeight)
}

// LayoutF implements ebiten.LayoutFer if the wrapped game supports it
func (w *GameWrapper) LayoutF(outsideWidth, outsideHeight float64) (float64, float64) {
	if lf, ok := w.game.(interface {
		LayoutF(float64, float64) (float64, float64)
	}); ok {
		return lf.LayoutF(outsideWidth, outsideHeight)
	}
	// Fallback to Layout
	iw, ih := w.game.Layout(int(outsideWidth), int(outsideHeight))
	return float64(iw), float64(ih)
}
