package recorder

import (
	"bytes"
	"image"
	"image/jpeg"

	"github.com/hajimehoshi/ebiten/v2"
	"github.com/icza/mjpeg"
)

// MJPEGRecorder captures frames from an Ebiten game and saves them as MJPEG AVI
// Uses pure Go implementation - no CGO, no ffmpeg required
// AVI format is YouTube-compatible
type MJPEGRecorder struct {
	writer      mjpeg.AviWriter
	recording   bool
	maxFrames   int
	fps         int32
	frameCount  int
	outputPath  string
	width       int32
	height      int32
	jpegQuality int
}

// NewMJPEGRecorder creates a new MJPEG/AVI recorder (pure Go, no CGO/ffmpeg)
// maxFrames: maximum number of frames to record (0 = unlimited)
// fps: frames per second for the output AVI
// outputPath: where to save the AVI file
// jpegQuality: JPEG compression quality (1-100, recommend 80-90)
func NewMJPEGRecorder(maxFrames int, fps int, outputPath string, jpegQuality int) *MJPEGRecorder {
	if maxFrames <= 0 {
		maxFrames = 600 // Default: 20 seconds at 30fps
	}
	if fps <= 0 {
		fps = 30 // Default FPS
	}
	if jpegQuality <= 0 || jpegQuality > 100 {
		jpegQuality = 85 // Default quality
	}

	return &MJPEGRecorder{
		maxFrames:   maxFrames,
		fps:         int32(fps),
		outputPath:  outputPath,
		jpegQuality: jpegQuality,
	}
}

// Start begins recording frames
func (r *MJPEGRecorder) Start(width, height int) error {
	if r.recording {
		return nil // Already recording
	}

	// Create AVI writer
	writer, err := mjpeg.New(r.outputPath, int32(width), int32(height), r.fps)
	if err != nil {
		return err
	}

	r.writer = writer
	r.width = int32(width)
	r.height = int32(height)
	r.recording = true
	r.frameCount = 0

	return nil
}

// Stop stops recording frames
func (r *MJPEGRecorder) Stop() error {
	if !r.recording {
		return nil
	}

	r.recording = false

	// Close and finalize the AVI file
	if r.writer != nil {
		return r.writer.Close()
	}

	return nil
}

// IsRecording returns true if currently recording
func (r *MJPEGRecorder) IsRecording() bool {
	return r.recording
}

// FrameCount returns the number of frames captured
func (r *MJPEGRecorder) FrameCount() int {
	return r.frameCount
}

// CaptureFrame captures the current screen frame
// Call this from your game's Draw method
func (r *MJPEGRecorder) CaptureFrame(screen *ebiten.Image) error {
	if !r.recording {
		return nil
	}

	// Check if we've hit the max frame limit
	if r.maxFrames > 0 && r.frameCount >= r.maxFrames {
		return r.Stop()
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

	// Encode frame as JPEG
	var buf bytes.Buffer
	if err := jpeg.Encode(&buf, rgba, &jpeg.Options{Quality: r.jpegQuality}); err != nil {
		return err
	}

	// Add JPEG frame to AVI
	if err := r.writer.AddFrame(buf.Bytes()); err != nil {
		return err
	}

	r.frameCount++
	return nil
}

// GetOutputPath returns the configured output path
func (r *MJPEGRecorder) GetOutputPath() string {
	return r.outputPath
}
