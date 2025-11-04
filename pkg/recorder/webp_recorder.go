package recorder

import (
	"image"
	"image/color/palette"
	"image/draw"
	"os"

	"github.com/HugoSmits86/nativewebp"
	"github.com/hajimehoshi/ebiten/v2"
)

// WebPRecorder captures frames from an Ebiten game and saves them as animated WebP
// Uses pure Go implementation - no CGO, no ffmpeg required
type WebPRecorder struct {
	frames      []*image.Paletted
	recording   bool
	maxFrames   int
	fps         int
	frameCount  int
	outputPath  string
	frameDelay  int // delay in milliseconds
}

// NewWebPRecorder creates a new WebP recorder (pure Go, no CGO/ffmpeg)
// maxFrames: maximum number of frames to record (0 = unlimited)
// fps: frames per second for the output WebP
// outputPath: where to save the WebP file
func NewWebPRecorder(maxFrames, fps int, outputPath string) *WebPRecorder {
	if maxFrames <= 0 {
		maxFrames = 600 // Default: 10 seconds at 60fps
	}
	if fps <= 0 {
		fps = 30 // Default FPS
	}

	// Calculate frame delay in milliseconds
	frameDelay := 1000 / fps

	return &WebPRecorder{
		frames:     make([]*image.Paletted, 0, maxFrames),
		maxFrames:  maxFrames,
		fps:        fps,
		outputPath: outputPath,
		frameDelay: frameDelay,
	}
}

// Start begins recording frames
func (r *WebPRecorder) Start() {
	r.recording = true
	r.frames = r.frames[:0]
	r.frameCount = 0
}

// Stop stops recording frames
func (r *WebPRecorder) Stop() {
	r.recording = false
}

// IsRecording returns true if currently recording
func (r *WebPRecorder) IsRecording() bool {
	return r.recording
}

// FrameCount returns the number of frames captured
func (r *WebPRecorder) FrameCount() int {
	return r.frameCount
}

// CaptureFrame captures the current screen frame
// Call this from your game's Draw method
func (r *WebPRecorder) CaptureFrame(screen *ebiten.Image) {
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

	// Convert to paletted image for WebP encoding
	// Using Plan9 palette which provides good color representation
	paletted := image.NewPaletted(bounds, palette.Plan9)
	draw.Draw(paletted, bounds, rgba, bounds.Min, draw.Src)

	r.frames = append(r.frames, paletted)
	r.frameCount++
}

// SaveWebP saves the recorded frames as an animated WebP file
func (r *WebPRecorder) SaveWebP() error {
	if len(r.frames) == 0 {
		return nil // Nothing to save
	}

	// Create output file
	f, err := os.Create(r.outputPath)
	if err != nil {
		return err
	}
	defer f.Close()

	// Prepare durations array - all frames use same delay
	durations := make([]uint, len(r.frames))
	for i := range durations {
		durations[i] = uint(r.frameDelay)
	}

	// Prepare disposal methods - 0 = keep frame
	disposals := make([]uint, len(r.frames))

	// Convert paletted images to generic images for nativewebp
	genericFrames := make([]image.Image, len(r.frames))
	for i, frame := range r.frames {
		genericFrames[i] = frame
	}

	// Create animation struct
	animation := &nativewebp.Animation{
		Images:          genericFrames,
		Durations:       durations,
		Disposals:       disposals,
		LoopCount:       0, // 0 = infinite loop
		BackgroundColor: 0x00000000, // transparent black
	}

	// Encode all frames as animated WebP
	// Using lossless encoding for best quality
	return nativewebp.EncodeAll(f, animation, nil)
}

// GetOutputPath returns the configured output path
func (r *WebPRecorder) GetOutputPath() string {
	return r.outputPath
}
