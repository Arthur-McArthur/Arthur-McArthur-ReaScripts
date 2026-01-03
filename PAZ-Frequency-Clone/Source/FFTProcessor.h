#pragma once

#include <JuceHeader.h>
#include <array>
#include <atomic>

/**
 * FFT Processor for real-time spectrum analysis
 * Handles windowing, FFT computation, and magnitude extraction
 */
class FFTProcessor
{
public:
    // FFT size options matching PAZ analyzer
    enum class FFTSize
    {
        Size512 = 512,
        Size1024 = 1024,
        Size2048 = 2048,
        Size4096 = 4096,
        Size8192 = 8192
    };

    static constexpr int kMaxFFTOrder = 13;  // 2^13 = 8192
    static constexpr int kMaxFFTSize = 1 << kMaxFFTOrder;

    FFTProcessor();
    ~FFTProcessor() = default;

    void prepare(double sampleRate, int samplesPerBlock);
    void pushSample(float sample);
    void processFFT();

    // Get magnitude data for display (0.0 to 1.0 normalized)
    const std::array<float, kMaxFFTSize / 2>& getMagnitudes() const { return magnitudes; }
    const std::array<float, kMaxFFTSize / 2>& getPeakMagnitudes() const { return peakMagnitudes; }

    bool isFFTDataReady() const { return fftDataReady.load(); }
    void resetFFTDataReady() { fftDataReady.store(false); }

    // Settings
    void setFFTSize(FFTSize size);
    FFTSize getFFTSize() const { return currentFFTSize; }
    int getFFTSizeValue() const { return static_cast<int>(currentFFTSize); }

    void setAveraging(float averaging) { this->averaging = juce::jlimit(0.0f, 0.99f, averaging); }
    float getAveraging() const { return averaging; }

    void setPeakHold(bool enabled) { peakHoldEnabled = enabled; }
    bool isPeakHoldEnabled() const { return peakHoldEnabled; }

    void setPeakDecay(float decayPerSecond) { peakDecayRate = decayPerSecond; }
    void resetPeaks();

    double getSampleRate() const { return sampleRate; }

    // Frequency helpers
    float binToFrequency(int bin) const;
    int frequencyToBin(float frequency) const;

private:
    void applyWindow();
    void computeMagnitudes();
    void updatePeaks();

    // FFT engine
    std::unique_ptr<juce::dsp::FFT> fft;
    std::unique_ptr<juce::dsp::WindowingFunction<float>> window;

    // FFT data buffers
    std::array<float, kMaxFFTSize> fftInput{};
    std::array<float, kMaxFFTSize * 2> fftOutput{};
    std::array<float, kMaxFFTSize / 2> magnitudes{};
    std::array<float, kMaxFFTSize / 2> smoothedMagnitudes{};
    std::array<float, kMaxFFTSize / 2> peakMagnitudes{};

    // Ring buffer for incoming samples
    std::array<float, kMaxFFTSize> inputBuffer{};
    int inputWritePos = 0;
    int samplesSinceLastFFT = 0;

    // State
    FFTSize currentFFTSize = FFTSize::Size2048;
    double sampleRate = 44100.0;
    float averaging = 0.7f;
    bool peakHoldEnabled = true;
    float peakDecayRate = 3.0f;  // dB per second

    std::atomic<bool> fftDataReady{false};

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(FFTProcessor)
};
