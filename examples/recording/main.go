package main

import (
	"fmt"
	"image"
	"image/color"
	"log"
	"main/pkg/recorder"
	"os"
	"strings"
	"time"

	"github.com/hajimehoshi/ebiten/v2"
	"github.com/hajimehoshi/ebiten/v2/ebitenutil"
	"github.com/hajimehoshi/ebiten/v2/inpututil"
	input "github.com/quasilyte/ebitengine-input"
)

// Actions
const (
	ActionUnknown input.Action = iota
	ActionDebug
	ActionMoveLeft
	ActionMoveUp
	ActionMoveRight
	ActionMoveDown
	ActionExit
	ActionTeleport
	ActionRecord
)

func main() {
	ebiten.SetWindowSize(640, 480)
	ebiten.SetWindowTitle("Ebiten Recording Demo - Press R to Record")

	if err := ebiten.RunGame(newExampleGame()); err != nil {
		log.Fatal(err)
	}
}

type exampleGame struct {
	started bool
	players []*player
	message string

	inputHandlers []*input.Handler
	inputSystem   input.System

	// Recording
	recorder           *recorder.MJPEGRecorder
	recordingStatus    string
	autoRecord         bool
	autoRecordStart    time.Time
	autoRecordDuration time.Duration
	recordingStarted   bool
}

func newExampleGame() *exampleGame {
	g := &exampleGame{}

	// The System.Init() should be called exactly once.
	g.inputSystem.Init(input.SystemConfig{
		DevicesEnabled: input.AnyDevice,
	})

	// Check for AUTO_RECORD environment variable
	if os.Getenv("AUTO_RECORD") != "" {
		g.autoRecord = true
		duration := os.Getenv("RECORD_DURATION")
		if duration == "" {
			duration = "10s"
		}
		var err error
		g.autoRecordDuration, err = time.ParseDuration(duration)
		if err != nil {
			g.autoRecordDuration = 10 * time.Second
		}
	}

	// Create MJPEG/AVI recorder (600 frames at 30fps = 20 seconds max)
	// Quality 85 provides good balance between file size and quality
	outputPath := "recording.avi"
	if path := os.Getenv("RECORD_OUTPUT"); path != "" {
		outputPath = path
	}
	g.recorder = recorder.NewMJPEGRecorder(600, 30, outputPath, 85)

	return g
}

func (g *exampleGame) Layout(_, _ int) (int, int) {
	return 640, 480
}

func (g *exampleGame) Draw(screen *ebiten.Image) {
	// Draw background
	screen.Fill(color.RGBA{30, 30, 40, 255})

	// Draw players
	for _, p := range g.players {
		p.Draw(screen)
	}

	// Draw instructions
	ebitenutil.DebugPrint(screen, g.message)

	// Draw recording status
	if g.recordingStatus != "" {
		ebitenutil.DebugPrintAt(screen, g.recordingStatus, 10, 60)
	}

	// Capture frame if recording
	if g.recorder.IsRecording() {
		if err := g.recorder.CaptureFrame(screen); err != nil {
			log.Printf("Failed to capture frame: %v", err)
		}
	}
}

func (g *exampleGame) Update() error {
	g.inputSystem.Update()

	if !g.started {
		g.Init()
		g.started = true

		// Auto-start recording if enabled
		if g.autoRecord {
			if err := g.recorder.Start(640, 480); err != nil {
				log.Fatalf("Failed to start recording: %v", err)
			}
			g.autoRecordStart = time.Now()
			g.recordingStatus = fmt.Sprintf("AUTO-RECORDING: %d frames", g.recorder.FrameCount())
		}
	}

	// Handle auto-record stop
	if g.autoRecord && g.recorder.IsRecording() {
		elapsed := time.Since(g.autoRecordStart)
		if elapsed >= g.autoRecordDuration {
			if err := g.recorder.Stop(); err != nil {
				log.Printf("Failed to save recording: %v", err)
				os.Exit(1)
			}
			log.Printf("Recording saved to: %s", g.recorder.GetOutputPath())
			// Exit successfully after auto-record
			os.Exit(0)
		}
		g.recordingStatus = fmt.Sprintf("AUTO-RECORDING: %.1fs / %.1fs (%d frames)",
			elapsed.Seconds(), g.autoRecordDuration.Seconds(), g.recorder.FrameCount())
	}

	// Manual recording toggle with R key
	if inpututil.IsKeyJustPressed(ebiten.KeyR) && !g.autoRecord {
		if g.recorder.IsRecording() {
			if err := g.recorder.Stop(); err != nil {
				g.recordingStatus = fmt.Sprintf("ERROR: %v", err)
			} else {
				g.recordingStatus = fmt.Sprintf("Saved: %s (%d frames)",
					g.recorder.GetOutputPath(), g.recorder.FrameCount())
			}
		} else {
			if err := g.recorder.Start(640, 480); err != nil {
				g.recordingStatus = fmt.Sprintf("ERROR: %v", err)
			} else {
				g.recordingStatus = "RECORDING... (Press R to stop)"
			}
		}
	}

	// Update recording status
	if g.recorder.IsRecording() && !g.autoRecord {
		g.recordingStatus = fmt.Sprintf("RECORDING: %d frames (Press R to stop)",
			g.recorder.FrameCount())
	}

	// Exit on Escape
	if g.inputHandlers[0].ActionIsJustPressed(ActionExit) {
		// Save recording if active
		if g.recorder.IsRecording() {
			g.recorder.Stop()
		}
		os.Exit(0)
	}

	// Update players
	for _, p := range g.players {
		p.Update()
	}

	return nil
}

func (g *exampleGame) Init() {
	// We're hardcoding the keymap here
	keymap := input.Keymap{
		ActionMoveLeft:  {input.KeyGamepadLeft, input.KeyGamepadLStickLeft, input.KeyLeft, input.KeyA},
		ActionMoveUp:    {input.KeyGamepadUp, input.KeyGamepadLStickUp, input.KeyUp, input.KeyW},
		ActionMoveRight: {input.KeyGamepadRight, input.KeyGamepadLStickRight, input.KeyRight, input.KeyD},
		ActionMoveDown:  {input.KeyGamepadDown, input.KeyGamepadLStickDown, input.KeyDown, input.KeyS},
		ActionExit: {
			input.KeyGamepadStart,
			input.KeyEscape,
			input.KeyWithModifier(input.KeyC, input.ModControl),
		},
		ActionDebug: {input.KeyControlLeft, input.KeyGamepadLStick, input.KeyGamepadRStick},
	}

	// Player 1 will have a teleport ability activated by a mouse click
	keymap0 := keymap.Clone()
	keymap0[ActionTeleport] = []input.Key{input.KeyMouseLeft, input.KeyTouchTap}

	// Prepare the input handlers
	numGamepads := 0
	g.inputHandlers = make([]*input.Handler, 4)
	for i := range g.inputHandlers {
		m := keymap
		if i == 0 {
			m = keymap0
		}
		h := g.inputSystem.NewHandler(uint8(i), m)
		if h.GamepadConnected() {
			numGamepads++
		}
		g.inputHandlers[i] = h
	}

	// There can be only one player with keyboard
	numPlayers := 1
	if numGamepads != 0 {
		numPlayers = numGamepads
	}

	// Create player objects
	g.players = make([]*player, numPlayers)
	pos := image.Point{X: 256, Y: 128}
	for i := range g.players {
		g.players[i] = &player{
			input: g.inputHandlers[i],
			pos:   pos,
			label: fmt.Sprintf("[player%d]", i+1),
		}
		pos.Y += 64
	}

	// Instructions
	messageLines := []string{
		"Press WASD/Arrows to move",
		"Press R to start/stop recording",
		"Press ESC to exit",
	}
	g.message = strings.Join(messageLines, "\n")
}

type player struct {
	label string
	input *input.Handler
	pos   image.Point
}

func (p *player) Update() {
	if p.input.ActionIsPressed(ActionMoveLeft) {
		p.pos.X -= 4
	}
	if p.input.ActionIsPressed(ActionMoveUp) {
		p.pos.Y -= 4
	}
	if p.input.ActionIsPressed(ActionMoveRight) {
		p.pos.X += 4
	}
	if p.input.ActionIsPressed(ActionMoveDown) {
		p.pos.Y += 4
	}
	if info, ok := p.input.JustPressedActionInfo(ActionTeleport); ok {
		p.pos.X = int(info.Pos.X)
		p.pos.Y = int(info.Pos.Y)
	}
}

func (p *player) Draw(screen *ebiten.Image) {
	ebitenutil.DebugPrintAt(screen, p.label, p.pos.X, p.pos.Y)
}
