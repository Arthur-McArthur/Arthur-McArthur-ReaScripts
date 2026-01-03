#pragma once

#include <JuceHeader.h>
#include "FFTProcessor.h"

/**
 * PAZ Frequency Clone Audio Processor
 * A spectrum analyzer VST3 plugin inspired by Waves PAZ Frequency
 */
class PAZFrequencyCloneProcessor : public juce::AudioProcessor
{
public:
    PAZFrequencyCloneProcessor();
    ~PAZFrequencyCloneProcessor() override;

    // AudioProcessor overrides
    void prepareToPlay(double sampleRate, int samplesPerBlock) override;
    void releaseResources() override;

    bool isBusesLayoutSupported(const BusesLayout& layouts) const override;

    void processBlock(juce::AudioBuffer<float>&, juce::MidiBuffer&) override;

    juce::AudioProcessorEditor* createEditor() override;
    bool hasEditor() const override;

    const juce::String getName() const override;

    bool acceptsMidi() const override;
    bool producesMidi() const override;
    bool isMidiEffect() const override;
    double getTailLengthSeconds() const override;

    int getNumPrograms() override;
    int getCurrentProgram() override;
    void setCurrentProgram(int index) override;
    const juce::String getProgramName(int index) override;
    void changeProgramName(int index, const juce::String& newName) override;

    void getStateInformation(juce::MemoryBlock& destData) override;
    void setStateInformation(const void* data, int sizeInBytes) override;

    // Access to FFT processors for left and right channels
    FFTProcessor& getLeftFFTProcessor() { return leftFFTProcessor; }
    FFTProcessor& getRightFFTProcessor() { return rightFFTProcessor; }

    // Parameters
    juce::AudioProcessorValueTreeState& getAPVTS() { return apvts; }

private:
    juce::AudioProcessorValueTreeState::ParameterLayout createParameterLayout();

    FFTProcessor leftFFTProcessor;
    FFTProcessor rightFFTProcessor;

    juce::AudioProcessorValueTreeState apvts;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(PAZFrequencyCloneProcessor)
};
