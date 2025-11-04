package main

import (
	"fmt"
	"image"
	_ "image/gif"
	_ "image/jpeg"
	_ "image/png"
	"os"

	"golang.org/x/image/webp"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: validate-webp <file.webp>")
		os.Exit(1)
	}

	filePath := os.Args[1]

	// Open the WebP file
	f, err := os.Open(filePath)
	if err != nil {
		fmt.Printf("ERROR: Cannot open file: %v\n", err)
		os.Exit(1)
	}
	defer f.Close()

	// Get file info
	stat, err := f.Stat()
	if err != nil {
		fmt.Printf("ERROR: Cannot stat file: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("==> WebP File Validation\n\n")
	fmt.Printf("File: %s\n", filePath)
	fmt.Printf("Size: %d bytes (%.2f KB)\n", stat.Size(), float64(stat.Size())/1024)
	fmt.Printf("\n")

	// Try to decode as WebP
	fmt.Println("Attempting to decode WebP...")
	img, err := webp.Decode(f)
	if err != nil {
		fmt.Printf("ERROR: Failed to decode WebP: %v\n", err)
		fmt.Println("\nThis WebP file cannot be decoded by Go's webp package.")
		fmt.Println("This might indicate:")
		fmt.Println("  - Corrupted file")
		fmt.Println("  - Animated WebP (Go's webp package only supports single frames)")
		fmt.Println("  - Unsupported WebP features")
		os.Exit(1)
	}

	bounds := img.Bounds()
	fmt.Printf("✓ Successfully decoded WebP image\n")
	fmt.Printf("  Dimensions: %dx%d\n", bounds.Dx(), bounds.Dy())
	fmt.Printf("  Color Model: %T\n", img.ColorModel())
	fmt.Printf("\n")

	// Check image type
	switch img.(type) {
	case *image.RGBA:
		fmt.Println("  Image Type: RGBA (full color)")
	case *image.NRGBA:
		fmt.Println("  Image Type: NRGBA (non-premultiplied alpha)")
	case *image.Paletted:
		fmt.Println("  Image Type: Paletted (indexed color)")
	default:
		fmt.Printf("  Image Type: %T\n", img)
	}

	fmt.Println("\n✓ WebP file is valid and decodable")
	fmt.Println("\nNote: Go's webp package (golang.org/x/image/webp) only decodes the first frame")
	fmt.Println("      of animated WebP files. To check animation, use external tools like:")
	fmt.Println("      - webpinfo (from webp package): brew install webp && webpinfo file.webp")
	fmt.Println("      - ffprobe: ffprobe -show_streams file.webp")
}
