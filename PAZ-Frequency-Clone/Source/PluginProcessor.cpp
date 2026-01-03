#include "PluginProcessor.h"
#include "PluginEditor.h"

PAZFrequencyCloneProcessor::PAZFrequencyCloneProcessor()
    : AudioProcessor(BusesProperties()
                     .withInput("Input", juce::AudioChannelSet::stereo(), true)
                     .withOutput("Output", juce::AudioChannelSet::stereo(), true)),
      apvts(*this, nullptr, "Parameters", createParameterLayout())
{
}

PAZFrequencyCloneProcessor::~PAZFrequencyCloneProcessor()
{
}

juce::AudioProcessorValueTreeState::ParameterLayout PAZFrequencyCloneProcessor::createParameterLayout()
{
    std::vector<std::unique_ptr<juce::RangedAudioParameter>> params;

    // FFT Size
    params.push_back(std::make_unique<juce::AudioParameterChoice>(
        juce::ParameterID{"fftSize", 1},
        "FFT Size",
        juce::StringArray{"512", "1024", "2048", "4096", "8192"},
        2  // Default to 2048
    ));

    // Averaging
    params.push_back(std::make_unique<juce::AudioParameterFloat>(
        juce::ParameterID{"averaging", 1},
        "Averaging",
        juce::NormalisableRange<float>(0.0f, 0.99f, 0.01f),
        0.7f
    ));

    // Peak Hold
    params.push_back(std::make_unique<juce::AudioParameterBool>(
        juce::ParameterID{"peakHold", 1},
        "Peak Hold",
        true
    ));

    // Peak Decay Rate
    params.push_back(std::make_unique<juce::AudioParameterFloat>(
        juce::ParameterID{"peakDecay", 1},
        "Peak Decay",
        juce::NormalisableRange<float>(0.5f, 20.0f, 0.1f),
        3.0f
    ));

    // Display Mode (0 = Bars, 1 = Lines, 2 = Fill)
    params.push_back(std::make_unique<juce::AudioParameterChoice>(
        juce::ParameterID{"displayMode", 1},
        "Display Mode",
        juce::StringArray{"Bars", "Lines", "Fill"},
        2  // Default to Fill
    ));

    // Channel (0 = Left, 1 = Right, 2 = Mid, 3 = Side)
    params.push_back(std::make_unique<juce::AudioParameterChoice>(
        juce::ParameterID{"channel", 1},
        "Channel",
        juce::StringArray{"Left", "Right", "Mid", "Side"},
        0  // Default to Left
    ));

    return {params.begin(), params.end()};
}

const juce::String PAZFrequencyCloneProcessor::getName() const
{
    return JucePlugin_Name;
}

bool PAZFrequencyCloneProcessor::acceptsMidi() const
{
    return false;
}

bool PAZFrequencyCloneProcessor::producesMidi() const
{
    return false;
}

bool PAZFrequencyCloneProcessor::isMidiEffect() const
{
    return false;
}

double PAZFrequencyCloneProcessor::getTailLengthSeconds() const
{
    return 0.0;
}

int PAZFrequencyCloneProcessor::getNumPrograms()
{
    return 1;
}

int PAZFrequencyCloneProcessor::getCurrentProgram()
{
    return 0;
}

void PAZFrequencyCloneProcessor::setCurrentProgram(int /*index*/)
{
}

const juce::String PAZFrequencyCloneProcessor::getProgramName(int /*index*/)
{
    return {};
}

void PAZFrequencyCloneProcessor::changeProgramName(int /*index*/, const juce::String& /*newName*/)
{
}

void PAZFrequencyCloneProcessor::prepareToPlay(double sampleRate, int samplesPerBlock)
{
    leftFFTProcessor.prepare(sampleRate, samplesPerBlock);
    rightFFTProcessor.prepare(sampleRate, samplesPerBlock);

    // Apply initial parameter values
    auto* fftSizeParam = apvts.getRawParameterValue("fftSize");
    int fftSizeIndex = static_cast<int>(fftSizeParam->load());
    FFTProcessor::FFTSize sizes[] = {
        FFTProcessor::FFTSize::Size512,
        FFTProcessor::FFTSize::Size1024,
        FFTProcessor::FFTSize::Size2048,
        FFTProcessor::FFTSize::Size4096,
        FFTProcessor::FFTSize::Size8192
    };
    leftFFTProcessor.setFFTSize(sizes[fftSizeIndex]);
    rightFFTProcessor.setFFTSize(sizes[fftSizeIndex]);

    auto* averagingParam = apvts.getRawParameterValue("averaging");
    leftFFTProcessor.setAveraging(averagingParam->load());
    rightFFTProcessor.setAveraging(averagingParam->load());

    auto* peakHoldParam = apvts.getRawParameterValue("peakHold");
    leftFFTProcessor.setPeakHold(peakHoldParam->load() > 0.5f);
    rightFFTProcessor.setPeakHold(peakHoldParam->load() > 0.5f);

    auto* peakDecayParam = apvts.getRawParameterValue("peakDecay");
    leftFFTProcessor.setPeakDecay(peakDecayParam->load());
    rightFFTProcessor.setPeakDecay(peakDecayParam->load());
}

void PAZFrequencyCloneProcessor::releaseResources()
{
}

bool PAZFrequencyCloneProcessor::isBusesLayoutSupported(const BusesLayout& layouts) const
{
    // Support mono or stereo
    if (layouts.getMainOutputChannelSet() != juce::AudioChannelSet::mono()
        && layouts.getMainOutputChannelSet() != juce::AudioChannelSet::stereo())
        return false;

    // Input must match output
    if (layouts.getMainOutputChannelSet() != layouts.getMainInputChannelSet())
        return false;

    return true;
}

void PAZFrequencyCloneProcessor::processBlock(juce::AudioBuffer<float>& buffer,
                                               juce::MidiBuffer& /*midiMessages*/)
{
    juce::ScopedNoDenormals noDenormals;

    auto totalNumInputChannels = getTotalNumInputChannels();
    auto totalNumOutputChannels = getTotalNumOutputChannels();
    int numSamples = buffer.getNumSamples();

    // Clear any output channels that don't have input data
    for (auto i = totalNumInputChannels; i < totalNumOutputChannels; ++i)
        buffer.clear(i, 0, numSamples);

    // Update parameters
    auto* averagingParam = apvts.getRawParameterValue("averaging");
    leftFFTProcessor.setAveraging(averagingParam->load());
    rightFFTProcessor.setAveraging(averagingParam->load());

    auto* peakHoldParam = apvts.getRawParameterValue("peakHold");
    leftFFTProcessor.setPeakHold(peakHoldParam->load() > 0.5f);
    rightFFTProcessor.setPeakHold(peakHoldParam->load() > 0.5f);

    auto* peakDecayParam = apvts.getRawParameterValue("peakDecay");
    leftFFTProcessor.setPeakDecay(peakDecayParam->load());
    rightFFTProcessor.setPeakDecay(peakDecayParam->load());

    // Get channel selection
    auto* channelParam = apvts.getRawParameterValue("channel");
    int channelSelection = static_cast<int>(channelParam->load());

    // Process audio through FFT
    if (totalNumInputChannels >= 1)
    {
        const float* leftChannel = buffer.getReadPointer(0);
        const float* rightChannel = totalNumInputChannels >= 2 ?
                                    buffer.getReadPointer(1) : buffer.getReadPointer(0);

        for (int sample = 0; sample < numSamples; ++sample)
        {
            float leftSample = leftChannel[sample];
            float rightSample = rightChannel[sample];

            // Calculate mid/side if needed
            float midSample = (leftSample + rightSample) * 0.5f;
            float sideSample = (leftSample - rightSample) * 0.5f;

            switch (channelSelection)
            {
                case 0:  // Left
                    leftFFTProcessor.pushSample(leftSample);
                    break;
                case 1:  // Right
                    leftFFTProcessor.pushSample(rightSample);
                    break;
                case 2:  // Mid
                    leftFFTProcessor.pushSample(midSample);
                    break;
                case 3:  // Side
                    leftFFTProcessor.pushSample(sideSample);
                    break;
            }

            // Always process right channel for potential stereo display
            rightFFTProcessor.pushSample(rightSample);
        }
    }

    // This is an analyzer - audio passes through unchanged
}

bool PAZFrequencyCloneProcessor::hasEditor() const
{
    return true;
}

juce::AudioProcessorEditor* PAZFrequencyCloneProcessor::createEditor()
{
    return new PAZFrequencyCloneEditor(*this);
}

void PAZFrequencyCloneProcessor::getStateInformation(juce::MemoryBlock& destData)
{
    auto state = apvts.copyState();
    std::unique_ptr<juce::XmlElement> xml(state.createXml());
    copyXmlToBinary(*xml, destData);
}

void PAZFrequencyCloneProcessor::setStateInformation(const void* data, int sizeInBytes)
{
    std::unique_ptr<juce::XmlElement> xmlState(getXmlFromBinary(data, sizeInBytes));

    if (xmlState.get() != nullptr)
    {
        if (xmlState->hasTagName(apvts.state.getType()))
        {
            apvts.replaceState(juce::ValueTree::fromXml(*xmlState));
        }
    }
}

// Plugin instantiation
juce::AudioProcessor* JUCE_CALLTYPE createPluginFilter()
{
    return new PAZFrequencyCloneProcessor();
}
