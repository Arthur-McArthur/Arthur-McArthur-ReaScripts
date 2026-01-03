# PAZ Frequency Clone

A JUCE VST3/Standalone spectrum analyzer plugin inspired by the Waves PAZ Frequency analyzer.

## Features

- Real-time FFT-based spectrum analysis
- Multiple display modes: Bars, Lines, Fill
- Logarithmic frequency scale (20Hz - 20kHz)
- Peak hold with adjustable decay
- Configurable FFT sizes (512 to 8192)
- Adjustable averaging/smoothing
- Channel selection (Left, Right, Mid, Side)
- Grid overlay with frequency and dB markers
- Dark theme with green accent colors

## Requirements

- CMake 3.22 or higher
- C++17 compatible compiler
- VST3 SDK (downloaded automatically via JUCE)

### Platform-specific requirements

**Linux:**
```bash
sudo apt-get install libasound2-dev libcurl4-openssl-dev libfreetype6-dev \
    libx11-dev libxcomposite-dev libxcursor-dev libxext-dev libxinerama-dev \
    libxrandr-dev libxrender-dev libwebkit2gtk-4.0-dev libglu1-mesa-dev mesa-common-dev
```

**macOS:**
- Xcode Command Line Tools

**Windows:**
- Visual Studio 2019 or later

## Building

```bash
# Create build directory
mkdir build && cd build

# Configure
cmake ..

# Build
cmake --build . --config Release

# The plugin will be in:
# - VST3: build/PAZFrequencyClone_artefacts/Release/VST3/
# - Standalone: build/PAZFrequencyClone_artefacts/Release/Standalone/
```

## Usage

1. Load the VST3 plugin in your DAW
2. Route audio through the plugin (it passes audio unchanged)
3. Adjust settings:
   - **FFT Size**: Higher values = better frequency resolution, higher latency
   - **Averaging**: Higher values = smoother display, slower response
   - **Display**: Choose between Bars, Lines, or Fill modes
   - **Channel**: Analyze Left, Right, Mid, or Side signal
   - **Peak Hold**: Enable/disable peak indicators
   - **Grid**: Toggle frequency/dB grid overlay
   - **Reset Peaks**: Clear peak hold indicators

## License

This project is provided for educational purposes.
