#pragma once

#include <JuceHeader.h>
#include "PluginProcessor.h"
#include "SpectrumAnalyzer.h"
#include "LookAndFeel.h"

/**
 * PAZ Frequency Clone Editor
 * Main plugin GUI with PAZ-style spectrum analyzer display
 */
class PAZFrequencyCloneEditor : public juce::AudioProcessorEditor
{
public:
    explicit PAZFrequencyCloneEditor(PAZFrequencyCloneProcessor&);
    ~PAZFrequencyCloneEditor() override;

    void paint(juce::Graphics&) override;
    void resized() override;

private:
    void setupControls();
    void updateDisplayMode();
    void updateFFTSize();

    PAZFrequencyCloneProcessor& processorRef;

    // Custom look and feel
    PAZLookAndFeel pazLookAndFeel;

    // Main spectrum display
    SpectrumAnalyzer spectrumAnalyzer;

    // Control panel components
    juce::Label titleLabel;

    juce::Label fftSizeLabel;
    juce::ComboBox fftSizeCombo;

    juce::Label averagingLabel;
    juce::Slider averagingSlider;

    juce::Label displayModeLabel;
    juce::ComboBox displayModeCombo;

    juce::Label channelLabel;
    juce::ComboBox channelCombo;

    juce::ToggleButton peakHoldButton;
    juce::ToggleButton gridButton;

    juce::TextButton resetPeaksButton;

    // Parameter attachments
    std::unique_ptr<juce::AudioProcessorValueTreeState::ComboBoxAttachment> fftSizeAttachment;
    std::unique_ptr<juce::AudioProcessorValueTreeState::SliderAttachment> averagingAttachment;
    std::unique_ptr<juce::AudioProcessorValueTreeState::ComboBoxAttachment> displayModeAttachment;
    std::unique_ptr<juce::AudioProcessorValueTreeState::ComboBoxAttachment> channelAttachment;
    std::unique_ptr<juce::AudioProcessorValueTreeState::ButtonAttachment> peakHoldAttachment;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(PAZFrequencyCloneEditor)
};
