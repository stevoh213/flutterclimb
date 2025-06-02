#!/bin/bash

# Prepare Launch Images Script
# This script helps prepare the mountain climbing image for iOS launch screen
# Requires ImageMagick to be installed: brew install imagemagick

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SOURCE_IMAGE=""
OUTPUT_DIR="apps/mobile/ios/Runner/Assets.xcassets/LaunchImage.imageset"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if ImageMagick is installed
check_imagemagick() {
    if ! command -v convert &> /dev/null; then
        print_error "ImageMagick is not installed. Please install it first:"
        echo "  macOS: brew install imagemagick"
        echo "  Ubuntu: sudo apt-get install imagemagick"
        exit 1
    fi
}

# Function to validate source image
validate_source_image() {
    if [[ ! -f "$SOURCE_IMAGE" ]]; then
        print_error "Source image not found: $SOURCE_IMAGE"
        exit 1
    fi
    
    # Check if it's a valid image
    if ! identify "$SOURCE_IMAGE" &> /dev/null; then
        print_error "Invalid image file: $SOURCE_IMAGE"
        exit 1
    fi
    
    print_status "Source image validated: $SOURCE_IMAGE"
}

# Function to create launch images
create_launch_images() {
    print_status "Creating launch images..."
    
    # Create output directory if it doesn't exist
    mkdir -p "$OUTPUT_DIR"
    
    # Generate 1x image (1024x1024)
    print_status "Generating LaunchImage.png (1024x1024)..."
    convert "$SOURCE_IMAGE" -resize 1024x1024^ -gravity center -extent 1024x1024 "$OUTPUT_DIR/LaunchImage.png"
    
    # Generate 2x image (2048x2048)
    print_status "Generating LaunchImage@2x.png (2048x2048)..."
    convert "$SOURCE_IMAGE" -resize 2048x2048^ -gravity center -extent 2048x2048 "$OUTPUT_DIR/LaunchImage@2x.png"
    
    # Generate 3x image (3072x3072)
    print_status "Generating LaunchImage@3x.png (3072x3072)..."
    convert "$SOURCE_IMAGE" -resize 3072x3072^ -gravity center -extent 3072x3072 "$OUTPUT_DIR/LaunchImage@3x.png"
    
    print_status "Launch images created successfully!"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 <source_image_path>"
    echo ""
    echo "This script prepares launch images for the iOS Climbing Logbook app."
    echo ""
    echo "Arguments:"
    echo "  source_image_path    Path to the mountain climbing image"
    echo ""
    echo "Example:"
    echo "  $0 ~/Downloads/mountain-climbing-image.jpg"
    echo ""
    echo "Requirements:"
    echo "  - ImageMagick must be installed"
    echo "  - Source image should be high resolution (recommended: 3000x3000 or larger)"
}

# Function to display image info
show_image_info() {
    print_status "Image information:"
    identify "$SOURCE_IMAGE" | while read line; do
        echo "  $line"
    done
}

# Main script
main() {
    echo "🏔️  Climbing Logbook - Launch Image Preparation"
    echo "=============================================="
    echo ""
    
    # Check arguments
    if [[ $# -eq 0 ]]; then
        show_usage
        exit 1
    fi
    
    SOURCE_IMAGE="$1"
    
    # Validate requirements
    check_imagemagick
    validate_source_image
    show_image_info
    
    echo ""
    print_warning "This will replace existing launch images. Continue? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        print_status "Operation cancelled."
        exit 0
    fi
    
    # Create the images
    create_launch_images
    
    echo ""
    print_status "✅ Launch images prepared successfully!"
    print_status "Next steps:"
    echo "  1. Open the iOS project in Xcode"
    echo "  2. Verify the images in Assets.xcassets"
    echo "  3. Test the launch screen on different simulators"
    echo "  4. Build and run the app to see the new launch screen"
}

# Run main function
main "$@" 