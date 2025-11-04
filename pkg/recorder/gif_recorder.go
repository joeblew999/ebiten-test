package recorder

import (
	"image"
	"image/color/palette"
	"image/draw"
	"image/gif"
	"os"

	"github.com/hajimehoshi/ebiten/v2"
)

// GIFRecorder captures frames from an Ebiten game and saves them as an animated GIF
type GIFRecorder struct {
	frames      []*image.Paletted
	delays      []int
	recording   bool
	maxFrames   int
	fps         int
	frameCount  int
	outputPath  string
}

// NewGIFRecorder creates a new GIF recorder
// maxFrames: maximum number of frames to record (0 = unlimited)
// fps: frames per second for the output GIF
// outputPath: where to save the GIF file
func NewGIFRecorder(maxFrames, fps int, outputPath string) *GIFRecorder {
	if maxFrames <= 0 {
		maxFrames = 600 // Default: 10 seconds at 60fps
	}
	if fps <= 0 {
		fps = 30 // Default FPS
	}

	return &GIFRecorder{
		frames:     make([]*image.Paletted, 0, maxFrames),
		delays:     make([]int, 0, maxFrames),
		maxFrames:  maxFrames,
		fps:        fps,
		outputPath: outputPath,
	}
}

// Start begins recording frames
func (r *GIFRecorder) Start() {
	r.recording = true
	r.frames = r.frames[:0]
	r.delays = r.delays[:0]
	r.frameCount = 0
}

// Stop stops recording frames
func (r *GIFRecorder) Stop() {
	r.recording = false
}

// IsRecording returns true if currently recording
func (r *GIFRecorder) IsRecording() bool {
	return r.recording
}

// FrameCount returns the number of frames captured
func (r *GIFRecorder) FrameCount() int {
	return r.frameCount
}

// CaptureFrame captures the current screen frame
// Call this from your game's Draw method
func (r *GIFRecorder) CaptureFrame(screen *ebiten.Image) {
	if !r.recording {
		return
	}

	// Check if we've hit the max frame limit
	if r.maxFrames > 0 && r.frameCount >= r.maxFrames {
		r.Stop()
		return
	}

	bounds := screen.Bounds()
	w, h := bounds.Dx(), bounds.Dy()

	// Read pixels from the screen
	pixels := make([]byte, 4*w*h)
	screen.ReadPixels(pixels)

	// Convert to RGBA image
	rgba := &image.RGBA{
		Pix:    pixels,
		Stride: 4 * w,
		Rect:   bounds,
	}

	// Convert to paletted image for GIF
	paletted := image.NewPaletted(bounds, palette.Plan9)
	draw.Draw(paletted, bounds, rgba, bounds.Min, draw.Src)

	r.frames = append(r.frames, paletted)
	// GIF delay is in 100ths of a second
	r.delays = append(r.delays, 100/r.fps)
	r.frameCount++
}

// SaveGIF saves the recorded frames as an animated GIF
func (r *GIFRecorder) SaveGIF() error {
	if len(r.frames) == 0 {
		return nil // Nothing to save
	}

	f, err := os.Create(r.outputPath)
	if err != nil {
		return err
	}
	defer f.Close()

	return gif.EncodeAll(f, &gif.GIF{
		Image: r.frames,
		Delay: r.delays,
	})
}

// GetOutputPath returns the configured output path
func (r *GIFRecorder) GetOutputPath() string {
	return r.outputPath
}
