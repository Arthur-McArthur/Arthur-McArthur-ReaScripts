#include "PluginProcessor.h"
#include "PluginEditor.h"

PAZFrequencyCloneEditor::PAZFrequencyCloneEditor(PAZFrequencyCloneProcessor& p)
    : AudioProcessorEditor(&p),
      processorRef(p),
      spectrumAnalyzer(p.getLeftFFTProcessor())
{
    setLookAndFeel(&pazLookAndFeel);

    setupControls();

    // Set initial size (similar to PAZ analyzer dimensions)
    setSize(700, 450);
    setResizable(true, true);
    setResizeLimits(500, 350, 1200, 800);
}

PAZFrequencyCloneEditor::~PAZFrequencyCloneEditor()
{
    setLookAndFeel(nullptr);
}

void PAZFrequencyCloneEditor::setupControls()
{
    // Title
    titleLabel.setText("PAZ Frequency Clone", juce::dontSendNotification);
    titleLabel.setFont(juce::Font(20.0f, juce::Font::bold));
    titleLabel.setColour(juce::Label::textColourId, juce::Colour(0xff00ff88));
    titleLabel.setJustificationType(juce::Justification::centred);
    addAndMakeVisible(titleLabel);

    // Spectrum analyzer
    addAndMakeVisible(spectrumAnalyzer);

    // FFT Size
    fftSizeLabel.setText("FFT Size:", juce::dontSendNotification);
    fftSizeLabel.setColour(juce::Label::textColourId, juce::Colour(0xffaaaaaa));
    addAndMakeVisible(fftSizeLabel);

    fftSizeCombo.addItem("512", 1);
    fftSizeCombo.addItem("1024", 2);
    fftSizeCombo.addItem("2048", 3);
    fftSizeCombo.addItem("4096", 4);
    fftSizeCombo.addItem("8192", 5);
    fftSizeCombo.onChange = [this]() { updateFFTSize(); };
    addAndMakeVisible(fftSizeCombo);

    fftSizeAttachment = std::make_unique<juce::AudioProcessorValueTreeState::ComboBoxAttachment>(
        processorRef.getAPVTS(), "fftSize", fftSizeCombo);

    // Averaging
    averagingLabel.setText("Averaging:", juce::dontSendNotification);
    averagingLabel.setColour(juce::Label::textColourId, juce::Colour(0xffaaaaaa));
    addAndMakeVisible(averagingLabel);

    averagingSlider.setSliderStyle(juce::Slider::LinearHorizontal);
    averagingSlider.setTextBoxStyle(juce::Slider::TextBoxRight, false, 50, 20);
    averagingSlider.setColour(juce::Slider::textBoxTextColourId, juce::Colour(0xffaaaaaa));
    averagingSlider.setColour(juce::Slider::textBoxOutlineColourId, juce::Colours::transparentBlack);
    addAndMakeVisible(averagingSlider);

    averagingAttachment = std::make_unique<juce::AudioProcessorValueTreeState::SliderAttachment>(
        processorRef.getAPVTS(), "averaging", averagingSlider);

    // Display Mode
    displayModeLabel.setText("Display:", juce::dontSendNotification);
    displayModeLabel.setColour(juce::Label::textColourId, juce::Colour(0xffaaaaaa));
    addAndMakeVisible(displayModeLabel);

    displayModeCombo.addItem("Bars", 1);
    displayModeCombo.addItem("Lines", 2);
    displayModeCombo.addItem("Fill", 3);
    displayModeCombo.onChange = [this]() { updateDisplayMode(); };
    addAndMakeVisible(displayModeCombo);

    displayModeAttachment = std::make_unique<juce::AudioProcessorValueTreeState::ComboBoxAttachment>(
        processorRef.getAPVTS(), "displayMode", displayModeCombo);

    // Channel Selection
    channelLabel.setText("Channel:", juce::dontSendNotification);
    channelLabel.setColour(juce::Label::textColourId, juce::Colour(0xffaaaaaa));
    addAndMakeVisible(channelLabel);

    channelCombo.addItem("Left", 1);
    channelCombo.addItem("Right", 2);
    channelCombo.addItem("Mid", 3);
    channelCombo.addItem("Side", 4);
    addAndMakeVisible(channelCombo);

    channelAttachment = std::make_unique<juce::AudioProcessorValueTreeState::ComboBoxAttachment>(
        processorRef.getAPVTS(), "channel", channelCombo);

    // Peak Hold
    peakHoldButton.setButtonText("Peak Hold");
    peakHoldButton.setColour(juce::ToggleButton::textColourId, juce::Colour(0xffaaaaaa));
    peakHoldButton.setColour(juce::ToggleButton::tickColourId, juce::Colour(0xff00ff88));
    peakHoldButton.onClick = [this]()
    {
        spectrumAnalyzer.setShowPeaks(peakHoldButton.getToggleState());
    };
    addAndMakeVisible(peakHoldButton);

    peakHoldAttachment = std::make_unique<juce::AudioProcessorValueTreeState::ButtonAttachment>(
        processorRef.getAPVTS(), "peakHold", peakHoldButton);

    // Grid Toggle
    gridButton.setButtonText("Grid");
    gridButton.setColour(juce::ToggleButton::textColourId, juce::Colour(0xffaaaaaa));
    gridButton.setColour(juce::ToggleButton::tickColourId, juce::Colour(0xff00ff88));
    gridButton.setToggleState(true, juce::dontSendNotification);
    gridButton.onClick = [this]()
    {
        spectrumAnalyzer.setShowGrid(gridButton.getToggleState());
    };
    addAndMakeVisible(gridButton);

    // Reset Peaks Button
    resetPeaksButton.setButtonText("Reset Peaks");
    resetPeaksButton.onClick = [this]()
    {
        processorRef.getLeftFFTProcessor().resetPeaks();
        processorRef.getRightFFTProcessor().resetPeaks();
    };
    addAndMakeVisible(resetPeaksButton);

    // Initialize display mode
    updateDisplayMode();
}

void PAZFrequencyCloneEditor::updateDisplayMode()
{
    int modeIndex = displayModeCombo.getSelectedId() - 1;
    if (modeIndex >= 0 && modeIndex <= 2)
    {
        spectrumAnalyzer.setDisplayMode(static_cast<SpectrumAnalyzer::DisplayMode>(modeIndex));
    }
}

void PAZFrequencyCloneEditor::updateFFTSize()
{
    int sizeIndex = fftSizeCombo.getSelectedId() - 1;
    if (sizeIndex >= 0 && sizeIndex <= 4)
    {
        FFTProcessor::FFTSize sizes[] = {
            FFTProcessor::FFTSize::Size512,
            FFTProcessor::FFTSize::Size1024,
            FFTProcessor::FFTSize::Size2048,
            FFTProcessor::FFTSize::Size4096,
            FFTProcessor::FFTSize::Size8192
        };
        processorRef.getLeftFFTProcessor().setFFTSize(sizes[sizeIndex]);
        processorRef.getRightFFTProcessor().setFFTSize(sizes[sizeIndex]);
    }
}

void PAZFrequencyCloneEditor::paint(juce::Graphics& g)
{
    // Dark background gradient
    juce::ColourGradient bgGradient(
        juce::Colour(0xff1a1a2e), 0, 0,
        juce::Colour(0xff0f0f1a), 0, static_cast<float>(getHeight()),
        false
    );
    g.setGradientFill(bgGradient);
    g.fillAll();

    // Top panel background
    g.setColour(juce::Colour(0xff252540));
    g.fillRect(0, 0, getWidth(), 40);

    // Bottom control panel background
    g.setColour(juce::Colour(0xff252540));
    g.fillRect(0, getHeight() - 50, getWidth(), 50);

    // Separator lines
    g.setColour(juce::Colour(0xff3d3d5c));
    g.drawLine(0, 40, static_cast<float>(getWidth()), 40, 1.0f);
    g.drawLine(0, static_cast<float>(getHeight() - 50),
               static_cast<float>(getWidth()),
               static_cast<float>(getHeight() - 50), 1.0f);
}

void PAZFrequencyCloneEditor::resized()
{
    auto bounds = getLocalBounds();

    // Top panel (title)
    auto topPanel = bounds.removeFromTop(40);
    titleLabel.setBounds(topPanel);

    // Bottom control panel
    auto bottomPanel = bounds.removeFromBottom(50);
    bottomPanel.reduce(10, 10);

    int controlWidth = 80;
    int comboWidth = 70;
    int spacing = 15;

    // FFT Size
    fftSizeLabel.setBounds(bottomPanel.removeFromLeft(60));
    fftSizeCombo.setBounds(bottomPanel.removeFromLeft(comboWidth));
    bottomPanel.removeFromLeft(spacing);

    // Averaging
    averagingLabel.setBounds(bottomPanel.removeFromLeft(70));
    averagingSlider.setBounds(bottomPanel.removeFromLeft(120));
    bottomPanel.removeFromLeft(spacing);

    // Display Mode
    displayModeLabel.setBounds(bottomPanel.removeFromLeft(55));
    displayModeCombo.setBounds(bottomPanel.removeFromLeft(comboWidth));
    bottomPanel.removeFromLeft(spacing);

    // Channel
    channelLabel.setBounds(bottomPanel.removeFromLeft(60));
    channelCombo.setBounds(bottomPanel.removeFromLeft(comboWidth));
    bottomPanel.removeFromLeft(spacing);

    // Buttons on the right
    auto rightSection = bottomPanel;
    resetPeaksButton.setBounds(rightSection.removeFromRight(90));
    rightSection.removeFromRight(10);
    gridButton.setBounds(rightSection.removeFromRight(60));
    rightSection.removeFromRight(10);
    peakHoldButton.setBounds(rightSection.removeFromRight(90));

    // Spectrum analyzer fills the middle
    bounds.reduce(5, 5);
    spectrumAnalyzer.setBounds(bounds);
}
