cmake_minimum_required(VERSION 3.22)
project(PAZ_Frequency_Clone VERSION 1.0.0)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Fetch JUCE from GitHub
include(FetchContent)
FetchContent_Declare(
    JUCE
    GIT_REPOSITORY https://github.com/juce-framework/JUCE.git
    GIT_TAG 7.0.9
)
FetchContent_MakeAvailable(JUCE)

# Plugin sources
set(PLUGIN_SOURCES
    Source/PluginProcessor.cpp
    Source/PluginProcessor.h
    Source/PluginEditor.cpp
    Source/PluginEditor.h
    Source/SpectrumAnalyzer.cpp
    Source/SpectrumAnalyzer.h
    Source/FFTProcessor.cpp
    Source/FFTProcessor.h
    Source/LookAndFeel.cpp
    Source/LookAndFeel.h
)

# Create the plugin
juce_add_plugin(PAZFrequencyClone
    COMPANY_NAME "Arthur McArthur"
    IS_SYNTH FALSE
    NEEDS_MIDI_INPUT FALSE
    NEEDS_MIDI_OUTPUT FALSE
    IS_MIDI_EFFECT FALSE
    EDITOR_WANTS_KEYBOARD_FOCUS FALSE
    COPY_PLUGIN_AFTER_BUILD TRUE
    PLUGIN_MANUFACTURER_CODE Arth
    PLUGIN_CODE Pazf
    FORMATS VST3 Standalone
    PRODUCT_NAME "PAZ Frequency Clone"
)

target_sources(PAZFrequencyClone PRIVATE ${PLUGIN_SOURCES})

target_compile_definitions(PAZFrequencyClone
    PUBLIC
        JUCE_WEB_BROWSER=0
        JUCE_USE_CURL=0
        JUCE_VST3_CAN_REPLACE_VST2=0
        JUCE_DISPLAY_SPLASH_SCREEN=0
)

target_link_libraries(PAZFrequencyClone
    PRIVATE
        juce::juce_audio_utils
        juce::juce_dsp
    PUBLIC
        juce::juce_recommended_config_flags
        juce::juce_recommended_lto_flags
        juce::juce_recommended_warning_flags
)
