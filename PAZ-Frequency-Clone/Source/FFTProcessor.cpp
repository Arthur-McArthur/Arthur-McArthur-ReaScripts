#include "FFTProcessor.h"

FFTProcessor::FFTProcessor()
{
    setFFTSize(FFTSize::Size2048);
}

void FFTProcessor::prepare(double newSampleRate, int /*samplesPerBlock*/)
{
    sampleRate = newSampleRate;
    resetPeaks();

    // Clear buffers
    std::fill(inputBuffer.begin(), inputBuffer.end(), 0.0f);
    std::fill(magnitudes.begin(), magnitudes.end(), 0.0f);
    std::fill(smoothedMagnitudes.begin(), smoothedMagnitudes.end(), 0.0f);

    inputWritePos = 0;
    samplesSinceLastFFT = 0;
}

void FFTProcessor::setFFTSize(FFTSize size)
{
    currentFFTSize = size;
    int fftOrder = static_cast<int>(std::log2(static_cast<int>(size)));

    fft = std::make_unique<juce::dsp::FFT>(fftOrder);
    window = std::make_unique<juce::dsp::WindowingFunction<float>>(
        static_cast<size_t>(size),
        juce::dsp::WindowingFunction<float>::hann
    );

    // Reset buffers
    std::fill(fftInput.begin(), fftInput.end(), 0.0f);
    std::fill(fftOutput.begin(), fftOutput.end(), 0.0f);
    std::fill(magnitudes.begin(), magnitudes.end(), 0.0f);
    std::fill(smoothedMagnitudes.begin(), smoothedMagnitudes.end(), 0.0f);

    resetPeaks();
}

void FFTProcessor::pushSample(float sample)
{
    int fftSize = getFFTSizeValue();

    inputBuffer[inputWritePos] = sample;
    inputWritePos = (inputWritePos + 1) % fftSize;
    samplesSinceLastFFT++;

    // Process FFT at 50% overlap
    if (samplesSinceLastFFT >= fftSize / 2)
    {
        processFFT();
        samplesSinceLastFFT = 0;
    }
}

void FFTProcessor::processFFT()
{
    int fftSize = getFFTSizeValue();

    // Copy input buffer to FFT input (handle wrap-around)
    for (int i = 0; i < fftSize; ++i)
    {
        int readPos = (inputWritePos + i) % fftSize;
        fftInput[i] = inputBuffer[readPos];
    }

    // Apply window
    applyWindow();

    // Prepare FFT output buffer
    std::copy(fftInput.begin(), fftInput.begin() + fftSize, fftOutput.begin());
    std::fill(fftOutput.begin() + fftSize, fftOutput.begin() + fftSize * 2, 0.0f);

    // Perform FFT
    fft->performFrequencyOnlyForwardTransform(fftOutput.data());

    // Compute magnitudes
    computeMagnitudes();

    // Update peaks
    if (peakHoldEnabled)
    {
        updatePeaks();
    }

    fftDataReady.store(true);
}

void FFTProcessor::applyWindow()
{
    int fftSize = getFFTSizeValue();
    window->multiplyWithWindowingTable(fftInput.data(), static_cast<size_t>(fftSize));
}

void FFTProcessor::computeMagnitudes()
{
    int fftSize = getFFTSizeValue();
    int numBins = fftSize / 2;
    float normalizationFactor = 2.0f / static_cast<float>(fftSize);

    for (int i = 0; i < numBins; ++i)
    {
        float magnitude = fftOutput[i] * normalizationFactor;

        // Convert to dB (with floor at -100dB)
        float db = juce::jlimit(-100.0f, 0.0f,
            juce::Decibels::gainToDecibels(magnitude, -100.0f));

        // Normalize to 0-1 range (where -100dB = 0, 0dB = 1)
        float normalizedMag = (db + 100.0f) / 100.0f;

        // Apply smoothing/averaging
        smoothedMagnitudes[i] = smoothedMagnitudes[i] * averaging +
                                normalizedMag * (1.0f - averaging);

        magnitudes[i] = smoothedMagnitudes[i];
    }
}

void FFTProcessor::updatePeaks()
{
    int numBins = getFFTSizeValue() / 2;
    float decayAmount = peakDecayRate / 100.0f;  // Per-frame decay

    for (int i = 0; i < numBins; ++i)
    {
        if (magnitudes[i] > peakMagnitudes[i])
        {
            peakMagnitudes[i] = magnitudes[i];
        }
        else
        {
            peakMagnitudes[i] = std::max(0.0f, peakMagnitudes[i] - decayAmount);
        }
    }
}

void FFTProcessor::resetPeaks()
{
    std::fill(peakMagnitudes.begin(), peakMagnitudes.end(), 0.0f);
}

float FFTProcessor::binToFrequency(int bin) const
{
    return static_cast<float>(bin) * static_cast<float>(sampleRate) /
           static_cast<float>(getFFTSizeValue());
}

int FFTProcessor::frequencyToBin(float frequency) const
{
    return static_cast<int>(frequency * static_cast<float>(getFFTSizeValue()) /
                            static_cast<float>(sampleRate));
}
