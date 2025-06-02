# iOS Launch Screen Setup Guide

## Overview

The iOS Climbing Logbook app features a beautiful launch screen that showcases a stunning mountain climbing landscape. This guide covers the complete setup, design decisions, and implementation details.

## Design Concept

### Visual Elements
- **Background Image**: Full-screen mountain landscape with red rock formations and blue sky
- **Overlay**: Semi-transparent dark gradient (30% opacity) for text readability
- **App Title**: "Climbing Logbook" in bold white text (40pt)
- **Subtitle**: "Track Your Climbing Journey" in medium white text (20pt)
- **Footer**: Copyright notice in smaller text (13pt)

### Design Principles
- **Immersive**: Full-screen image creates immediate connection to climbing
- **Readable**: Dark overlay ensures text visibility across different image areas
- **Professional**: Clean typography and proper spacing
- **Responsive**: Auto Layout adapts to all iOS device sizes
- **Fast Loading**: Optimized image sizes for quick display

## File Structure

```
apps/mobile/ios/Runner/
├── Assets.xcassets/
│   └── LaunchImage.imageset/
│       ├── Contents.json
│       ├── LaunchImage.png (1024×1024)
│       ├── LaunchImage@2x.png (2048×2048)
│       ├── LaunchImage@3x.png (3072×3072)
│       └── README.md
└── Base.lproj/
    └── LaunchScreen.storyboard
```

## Implementation Details

### LaunchScreen.storyboard Features

1. **Background Image View**
   - Content Mode: `scaleAspectFill`
   - Constraints: Edge-to-edge full screen
   - Image: References "LaunchImage" from Assets.xcassets

2. **Gradient Overlay**
   - Semi-transparent black view (30% opacity)
   - Improves text readability
   - Covers entire screen

3. **Text Elements**
   - App title with text shadow for depth
   - Subtitle with slightly transparent white
   - Copyright notice in footer area

4. **Auto Layout Constraints**
   - Safe area aware for modern iOS devices
   - Proper spacing and alignment
   - Responsive to different screen sizes

### Image Specifications

| Resolution | Size | Usage |
|------------|------|-------|
| 1x | 1024×1024 | Standard resolution devices |
| 2x | 2048×2048 | Retina displays |
| 3x | 3072×3072 | Super Retina displays |

## Setup Instructions

### Method 1: Using the Automated Script

1. **Save your mountain climbing image** to your computer
2. **Install ImageMagick** (if not already installed):
   ```bash
   brew install imagemagick
   ```
3. **Run the preparation script**:
   ```bash
   ./tools/scripts/prepare-launch-images.sh /path/to/your/mountain-image.jpg
   ```
4. **Open in Xcode** and verify the images appear correctly

### Method 2: Manual Setup

1. **Prepare three image sizes** using your preferred image editor:
   - 1024×1024 pixels (save as `LaunchImage.png`)
   - 2048×2048 pixels (save as `LaunchImage@2x.png`)
   - 3072×3072 pixels (save as `LaunchImage@3x.png`)

2. **Replace the placeholder images**:
   - Navigate to `apps/mobile/ios/Runner/Assets.xcassets/LaunchImage.imageset/`
   - Replace the existing placeholder files with your prepared images

3. **Verify in Xcode**:
   - Open `Runner.xcworkspace`
   - Check `Runner/Assets.xcassets/LaunchImage.imageset`
   - Ensure all three images appear correctly

## Testing the Launch Screen

### In Xcode Simulator
1. Open the project in Xcode
2. Select your target device simulator
3. Build and run the app (`Cmd+R`)
4. Observe the launch screen during app startup

### On Physical Device
1. Connect your iOS device
2. Select it as the build target
3. Build and install the app
4. Launch the app to see the launch screen

### Different Screen Sizes
Test on various simulators to ensure proper scaling:
- iPhone SE (small screen)
- iPhone 14 (standard)
- iPhone 14 Pro Max (large screen)
- iPad (tablet layout)

## Troubleshooting

### Common Issues

**Images not appearing:**
- Verify image files are properly named
- Check that `Contents.json` references correct filenames
- Ensure images are added to the Xcode project

**Text not readable:**
- Adjust gradient overlay opacity in storyboard
- Consider adding text shadow or outline
- Test with different image brightness levels

**Layout issues on different devices:**
- Verify Auto Layout constraints are properly set
- Test on multiple simulator sizes
- Check safe area constraints for newer devices

**App Store rejection:**
- Ensure launch screen follows Apple's guidelines
- Avoid including loading indicators or progress bars
- Keep text minimal and avoid promotional content

### Performance Optimization

**Image Size Optimization:**
- Use PNG format for best quality
- Compress images without losing visual quality
- Consider using tools like ImageOptim for further optimization

**Loading Speed:**
- Keep total image size under 1MB per resolution
- Test launch time on older devices
- Monitor app startup performance

## Apple Guidelines Compliance

### Human Interface Guidelines
- ✅ Provides smooth transition to app interface
- ✅ Doesn't include loading indicators
- ✅ Matches app's visual style
- ✅ Works on all supported devices
- ✅ Loads quickly

### App Store Requirements
- ✅ No promotional text or advertising
- ✅ No version numbers or copyright in main area
- ✅ Appropriate for all audiences
- ✅ High-quality imagery
- ✅ Proper resolution support

## Customization Options

### Text Modifications
To change the app title or subtitle:
1. Open `LaunchScreen.storyboard` in Xcode
2. Select the text label you want to modify
3. Update the text in the Attributes Inspector
4. Adjust font size, color, or positioning as needed

### Color Scheme Adjustments
To modify the overlay or text colors:
1. Select the gradient overlay view
2. Adjust the background color and opacity
3. Update text colors for optimal contrast
4. Test readability across different image areas

### Layout Changes
To modify the layout:
1. Select elements in the storyboard
2. Adjust Auto Layout constraints
3. Test on multiple device sizes
4. Ensure proper safe area handling

## Future Considerations

### Dynamic Launch Screens
Consider implementing dynamic launch screens that:
- Adapt to system dark/light mode
- Show different images based on time of day
- Include subtle animations (iOS 14+)

### Accessibility
Ensure the launch screen is accessible:
- Provide alternative text for images
- Ensure sufficient color contrast
- Support VoiceOver navigation

### Localization
For international markets:
- Consider text-free designs
- Ensure images are culturally appropriate
- Plan for right-to-left language support

## Conclusion

The launch screen serves as the first impression of your climbing logbook app. The mountain landscape image creates an immediate connection to the climbing experience while the clean, professional design establishes trust and quality expectations.

The implementation follows iOS best practices and Apple's Human Interface Guidelines, ensuring a smooth user experience and App Store approval. The responsive design works beautifully across all iOS devices, from the smallest iPhone to the largest iPad.

Regular testing and optimization ensure the launch screen continues to provide a fast, beautiful introduction to your climbing logbook application. 