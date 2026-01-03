#include "SpectrumAnalyzer.h"

SpectrumAnalyzer::SpectrumAnalyzer(FFTProcessor& processor)
    : fftProcessor(processor)
{
    startTimerHz(60);  // 60 FPS refresh rate
}

SpectrumAnalyzer::~SpectrumAnalyzer()
{
    stopTimer();
}

void SpectrumAnalyzer::timerCallback()
{
    if (fftProcessor.isFFTDataReady())
    {
        fftProcessor.resetFFTDataReady();
        repaint();
    }
}

void SpectrumAnalyzer::resized()
{
    // Define the spectrum display area with margins for labels
    const int leftMargin = 45;
    const int rightMargin = 15;
    const int topMargin = 15;
    const int bottomMargin = 30;

    spectrumArea = getLocalBounds()
        .withTrimmedLeft(leftMargin)
        .withTrimmedRight(rightMargin)
        .withTrimmedTop(topMargin)
        .withTrimmedBottom(bottomMargin);

    // Update gradient
    spectrumGradient = juce::ColourGradient(
        juce::Colour(0xff00ff88), 0, static_cast<float>(spectrumArea.getBottom()),
        juce::Colour(0xffff6b6b), 0, static_cast<float>(spectrumArea.getY()),
        false
    );
    spectrumGradient.addColour(0.3, juce::Colour(0xff00ccff));
    spectrumGradient.addColour(0.6, juce::Colour(0xffffff00));
}

void SpectrumAnalyzer::paint(juce::Graphics& g)
{
    drawBackground(g);

    if (showGrid)
        drawGrid(g);

    drawSpectrum(g);

    if (showPeaks)
        drawPeaks(g);

    drawFrequencyLabels(g);
    drawDecibelLabels(g);

    // Border around spectrum area
    g.setColour(gridColour.brighter(0.3f));
    g.drawRect(spectrumArea, 1);
}

void SpectrumAnalyzer::drawBackground(juce::Graphics& g)
{
    g.fillAll(backgroundColour);

    // Gradient background for spectrum area
    juce::ColourGradient bgGradient(
        backgroundColour.brighter(0.1f), 0, static_cast<float>(spectrumArea.getY()),
        backgroundColour.darker(0.2f), 0, static_cast<float>(spectrumArea.getBottom()),
        false
    );
    g.setGradientFill(bgGradient);
    g.fillRect(spectrumArea);
}

void SpectrumAnalyzer::drawGrid(juce::Graphics& g)
{
    g.setColour(gridColour);

    // Frequency grid lines (logarithmic spacing)
    std::vector<float> gridFrequencies = {
        20, 30, 40, 50, 60, 70, 80, 90, 100,
        200, 300, 400, 500, 600, 700, 800, 900, 1000,
        2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000,
        20000
    };

    for (float freq : gridFrequencies)
    {
        if (freq >= minFrequency && freq <= maxFrequency)
        {
            float x = frequencyToX(freq);
            bool isMajor = (freq == 100 || freq == 1000 || freq == 10000);
            g.setColour(isMajor ? gridColour.brighter(0.3f) : gridColour);
            g.drawVerticalLine(static_cast<int>(x),
                               static_cast<float>(spectrumArea.getY()),
                               static_cast<float>(spectrumArea.getBottom()));
        }
    }

    // dB grid lines
    for (float db = -90.0f; db <= 0.0f; db += 10.0f)
    {
        float normalizedMag = (db - minDecibels) / (maxDecibels - minDecibels);
        float y = magnitudeToY(normalizedMag);
        bool isMajor = (static_cast<int>(db) % 30 == 0);
        g.setColour(isMajor ? gridColour.brighter(0.3f) : gridColour);
        g.drawHorizontalLine(static_cast<int>(y),
                             static_cast<float>(spectrumArea.getX()),
                             static_cast<float>(spectrumArea.getRight()));
    }
}

void SpectrumAnalyzer::drawSpectrum(juce::Graphics& g)
{
    const auto& magnitudes = fftProcessor.getMagnitudes();
    int fftSize = fftProcessor.getFFTSizeValue();
    int numBins = fftSize / 2;

    juce::Path spectrumPath;
    bool pathStarted = false;

    float lastX = 0.0f;
    float lastY = static_cast<float>(spectrumArea.getBottom());

    for (int bin = 1; bin < numBins; ++bin)
    {
        float frequency = fftProcessor.binToFrequency(bin);

        if (frequency < minFrequency || frequency > maxFrequency)
            continue;

        float x = frequencyToX(frequency);
        float y = magnitudeToY(magnitudes[bin]);

        // Clamp y to spectrum area
        y = juce::jlimit(static_cast<float>(spectrumArea.getY()),
                         static_cast<float>(spectrumArea.getBottom()), y);

        if (!pathStarted)
        {
            spectrumPath.startNewSubPath(x, static_cast<float>(spectrumArea.getBottom()));
            spectrumPath.lineTo(x, y);
            pathStarted = true;
        }
        else
        {
            spectrumPath.lineTo(x, y);
        }

        lastX = x;
        lastY = y;
    }

    if (pathStarted)
    {
        // Close path for fill mode
        if (displayMode == DisplayMode::Fill)
        {
            spectrumPath.lineTo(lastX, static_cast<float>(spectrumArea.getBottom()));
            spectrumPath.closeSubPath();

            // Draw filled spectrum with gradient
            g.setGradientFill(spectrumGradient);
            g.setOpacity(0.6f);
            g.fillPath(spectrumPath);
            g.setOpacity(1.0f);
        }

        // Draw spectrum line
        if (displayMode == DisplayMode::Lines || displayMode == DisplayMode::Fill)
        {
            g.setColour(spectrumColour);

            // Re-create line path without closing
            juce::Path linePath;
            bool lineStarted = false;

            for (int bin = 1; bin < numBins; ++bin)
            {
                float frequency = fftProcessor.binToFrequency(bin);

                if (frequency < minFrequency || frequency > maxFrequency)
                    continue;

                float x = frequencyToX(frequency);
                float y = magnitudeToY(magnitudes[bin]);
                y = juce::jlimit(static_cast<float>(spectrumArea.getY()),
                                 static_cast<float>(spectrumArea.getBottom()), y);

                if (!lineStarted)
                {
                    linePath.startNewSubPath(x, y);
                    lineStarted = true;
                }
                else
                {
                    linePath.lineTo(x, y);
                }
            }

            g.strokePath(linePath, juce::PathStrokeType(2.0f));
        }

        // Draw bars mode
        if (displayMode == DisplayMode::Bars)
        {
            int numDisplayBars = 64;
            float barWidth = static_cast<float>(spectrumArea.getWidth()) / numDisplayBars - 1;

            for (int i = 0; i < numDisplayBars; ++i)
            {
                float startFreq = xToFrequency(spectrumArea.getX() + i * (barWidth + 1));
                float endFreq = xToFrequency(spectrumArea.getX() + (i + 1) * (barWidth + 1));

                int startBin = fftProcessor.frequencyToBin(startFreq);
                int endBin = fftProcessor.frequencyToBin(endFreq);

                startBin = juce::jlimit(1, numBins - 1, startBin);
                endBin = juce::jlimit(startBin + 1, numBins, endBin);

                // Find max magnitude in this range
                float maxMag = 0.0f;
                for (int bin = startBin; bin < endBin; ++bin)
                {
                    maxMag = std::max(maxMag, magnitudes[bin]);
                }

                float barX = static_cast<float>(spectrumArea.getX()) + i * (barWidth + 1);
                float barY = magnitudeToY(maxMag);
                float barHeight = static_cast<float>(spectrumArea.getBottom()) - barY;

                if (barHeight > 0)
                {
                    // Create gradient for each bar
                    juce::ColourGradient barGradient(
                        juce::Colour(0xff00ff88), barX, static_cast<float>(spectrumArea.getBottom()),
                        juce::Colour(0xffff6b6b), barX, barY,
                        false
                    );
                    g.setGradientFill(barGradient);
                    g.fillRect(barX, barY, barWidth, barHeight);
                }
            }
        }
    }
}

void SpectrumAnalyzer::drawPeaks(juce::Graphics& g)
{
    const auto& peaks = fftProcessor.getPeakMagnitudes();
    int fftSize = fftProcessor.getFFTSizeValue();
    int numBins = fftSize / 2;

    g.setColour(peakColour);

    if (displayMode == DisplayMode::Bars)
    {
        int numDisplayBars = 64;
        float barWidth = static_cast<float>(spectrumArea.getWidth()) / numDisplayBars - 1;

        for (int i = 0; i < numDisplayBars; ++i)
        {
            float startFreq = xToFrequency(spectrumArea.getX() + i * (barWidth + 1));
            float endFreq = xToFrequency(spectrumArea.getX() + (i + 1) * (barWidth + 1));

            int startBin = fftProcessor.frequencyToBin(startFreq);
            int endBin = fftProcessor.frequencyToBin(endFreq);

            startBin = juce::jlimit(1, numBins - 1, startBin);
            endBin = juce::jlimit(startBin + 1, numBins, endBin);

            float maxPeak = 0.0f;
            for (int bin = startBin; bin < endBin; ++bin)
            {
                maxPeak = std::max(maxPeak, peaks[bin]);
            }

            float barX = static_cast<float>(spectrumArea.getX()) + i * (barWidth + 1);
            float peakY = magnitudeToY(maxPeak);

            if (maxPeak > 0.01f)
            {
                g.fillRect(barX, peakY - 2, barWidth, 3.0f);
            }
        }
    }
    else
    {
        // Draw peak line
        juce::Path peakPath;
        bool pathStarted = false;

        for (int bin = 1; bin < numBins; ++bin)
        {
            float frequency = fftProcessor.binToFrequency(bin);

            if (frequency < minFrequency || frequency > maxFrequency)
                continue;

            float x = frequencyToX(frequency);
            float y = magnitudeToY(peaks[bin]);
            y = juce::jlimit(static_cast<float>(spectrumArea.getY()),
                             static_cast<float>(spectrumArea.getBottom()), y);

            if (!pathStarted)
            {
                peakPath.startNewSubPath(x, y);
                pathStarted = true;
            }
            else
            {
                peakPath.lineTo(x, y);
            }
        }

        g.strokePath(peakPath, juce::PathStrokeType(1.5f));
    }
}

void SpectrumAnalyzer::drawFrequencyLabels(juce::Graphics& g)
{
    g.setColour(labelColour);
    g.setFont(11.0f);

    std::vector<std::pair<float, juce::String>> labels = {
        {20, "20"},
        {50, "50"},
        {100, "100"},
        {200, "200"},
        {500, "500"},
        {1000, "1k"},
        {2000, "2k"},
        {5000, "5k"},
        {10000, "10k"},
        {20000, "20k"}
    };

    for (const auto& [freq, label] : labels)
    {
        if (freq >= minFrequency && freq <= maxFrequency)
        {
            float x = frequencyToX(freq);
            g.drawText(label,
                       static_cast<int>(x) - 15,
                       spectrumArea.getBottom() + 5,
                       30, 20,
                       juce::Justification::centred);
        }
    }
}

void SpectrumAnalyzer::drawDecibelLabels(juce::Graphics& g)
{
    g.setColour(labelColour);
    g.setFont(10.0f);

    for (float db = -90.0f; db <= 0.0f; db += 30.0f)
    {
        float normalizedMag = (db - minDecibels) / (maxDecibels - minDecibels);
        float y = magnitudeToY(normalizedMag);

        juce::String label = juce::String(static_cast<int>(db)) + " dB";
        g.drawText(label,
                   5, static_cast<int>(y) - 8,
                   35, 16,
                   juce::Justification::right);
    }
}

void SpectrumAnalyzer::setFrequencyRange(float minFreq, float maxFreq)
{
    minFrequency = minFreq;
    maxFrequency = maxFreq;
    repaint();
}

void SpectrumAnalyzer::setDecibelRange(float minDb, float maxDb)
{
    minDecibels = minDb;
    maxDecibels = maxDb;
    repaint();
}

float SpectrumAnalyzer::frequencyToX(float frequency) const
{
    if (scaleType == ScaleType::Logarithmic)
    {
        float minLog = std::log10(minFrequency);
        float maxLog = std::log10(maxFrequency);
        float freqLog = std::log10(frequency);

        float proportion = (freqLog - minLog) / (maxLog - minLog);
        return spectrumArea.getX() + proportion * spectrumArea.getWidth();
    }
    else
    {
        float proportion = (frequency - minFrequency) / (maxFrequency - minFrequency);
        return spectrumArea.getX() + proportion * spectrumArea.getWidth();
    }
}

float SpectrumAnalyzer::magnitudeToY(float magnitude) const
{
    // magnitude is already normalized 0-1
    float y = spectrumArea.getBottom() - magnitude * spectrumArea.getHeight();
    return y;
}

float SpectrumAnalyzer::xToFrequency(float x) const
{
    float proportion = (x - spectrumArea.getX()) / spectrumArea.getWidth();
    proportion = juce::jlimit(0.0f, 1.0f, proportion);

    if (scaleType == ScaleType::Logarithmic)
    {
        float minLog = std::log10(minFrequency);
        float maxLog = std::log10(maxFrequency);
        float freqLog = minLog + proportion * (maxLog - minLog);
        return std::pow(10.0f, freqLog);
    }
    else
    {
        return minFrequency + proportion * (maxFrequency - minFrequency);
    }
}
