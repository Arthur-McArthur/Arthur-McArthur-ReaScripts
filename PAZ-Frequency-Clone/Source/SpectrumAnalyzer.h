#pragma once

#include <JuceHeader.h>
#include "FFTProcessor.h"

/**
 * Spectrum Analyzer Display Component
 * Renders the frequency spectrum with PAZ-style visuals
 */
class SpectrumAnalyzer : public juce::Component,
                          public juce::Timer
{
public:
    enum class DisplayMode
    {
        Bars,
        Lines,
        Fill
    };

    enum class ScaleType
    {
        Linear,
        Logarithmic
    };

    SpectrumAnalyzer(FFTProcessor& fftProcessor);
    ~SpectrumAnalyzer() override;

    void paint(juce::Graphics& g) override;
    void resized() override;
    void timerCallback() override;

    // Display settings
    void setDisplayMode(DisplayMode mode) { displayMode = mode; repaint(); }
    DisplayMode getDisplayMode() const { return displayMode; }

    void setScaleType(ScaleType type) { scaleType = type; repaint(); }
    ScaleType getScaleType() const { return scaleType; }

    void setShowPeaks(bool show) { showPeaks = show; repaint(); }
    bool getShowPeaks() const { return showPeaks; }

    void setShowGrid(bool show) { showGrid = show; repaint(); }
    bool getShowGrid() const { return showGrid; }

    // Frequency range (Hz)
    void setFrequencyRange(float minFreq, float maxFreq);
    float getMinFrequency() const { return minFrequency; }
    float getMaxFrequency() const { return maxFrequency; }

    // dB range
    void setDecibelRange(float minDb, float maxDb);
    float getMinDecibels() const { return minDecibels; }
    float getMaxDecibels() const { return maxDecibels; }

private:
    void drawBackground(juce::Graphics& g);
    void drawGrid(juce::Graphics& g);
    void drawSpectrum(juce::Graphics& g);
    void drawPeaks(juce::Graphics& g);
    void drawFrequencyLabels(juce::Graphics& g);
    void drawDecibelLabels(juce::Graphics& g);

    float frequencyToX(float frequency) const;
    float magnitudeToY(float magnitude) const;
    float xToFrequency(float x) const;

    // Reference to the FFT processor
    FFTProcessor& fftProcessor;

    // Display settings
    DisplayMode displayMode = DisplayMode::Fill;
    ScaleType scaleType = ScaleType::Logarithmic;
    bool showPeaks = true;
    bool showGrid = true;

    // Frequency range
    float minFrequency = 20.0f;
    float maxFrequency = 20000.0f;

    // dB range (normalized)
    float minDecibels = -100.0f;
    float maxDecibels = 0.0f;

    // Display area
    juce::Rectangle<int> spectrumArea;

    // Colors (PAZ-style)
    juce::Colour backgroundColour{0xff1a1a2e};
    juce::Colour gridColour{0xff2d2d44};
    juce::Colour spectrumColour{0xff00ff88};
    juce::Colour peakColour{0xffff6b6b};
    juce::Colour labelColour{0xffaaaaaa};
    juce::Colour spectrumFillColour{0x6000ff88};

    // Gradient for spectrum
    juce::ColourGradient spectrumGradient;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(SpectrumAnalyzer)
};
