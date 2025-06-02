# Launch Image Setup Instructions

## Overview
This directory contains the launch screen images for the Climbing Logbook iOS app. The launch screen features a beautiful mountain climbing landscape image.

## Required Image Files
You need to replace the placeholder images with the actual mountain climbing image in three resolutions:

### Image Specifications
- **LaunchImage.png** (1x): 1024×1024 pixels
- **LaunchImage@2x.png** (2x): 2048×2048 pixels  
- **LaunchImage@3x.png** (3x): 3072×3072 pixels

### Image Requirements
- **Format**: PNG with transparency support
- **Content**: The beautiful mountain landscape image with red rock formations and blue sky
- **Aspect Ratio**: The image will be displayed using `scaleAspectFill` to cover the entire screen
- **Quality**: High resolution for crisp display on all device sizes

## How to Add the Images

1. **Prepare the mountain climbing image** in the three required resolutions
2. **Replace the existing placeholder files**:
   - Replace `LaunchImage.png` with your 1024×1024 version
   - Replace `LaunchImage@2x.png` with your 2048×2048 version
   - Replace `LaunchImage@3x.png` with your 3072×3072 version

3. **Verify the setup**:
   - Open the project in Xcode
   - Check that the images appear correctly in the Assets.xcassets
   - Test the launch screen on different device simulators

## Launch Screen Design
The launch screen includes:
- **Background**: Full-screen mountain climbing image with aspect fill
- **Overlay**: Semi-transparent dark gradient for text readability
- **Title**: "Climbing Logbook" in bold white text
- **Subtitle**: "Track Your Climbing Journey" 
- **Footer**: Copyright notice

## Notes
- The image will automatically scale to fill the entire screen while maintaining aspect ratio
- The dark overlay ensures text remains readable regardless of image brightness
- The design follows iOS Human Interface Guidelines for launch screens
- The layout adapts to different screen sizes using Auto Layout constraints