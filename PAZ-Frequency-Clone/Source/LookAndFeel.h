#pragma once

#include <JuceHeader.h>

/**
 * Custom Look and Feel for PAZ Frequency Clone
 * Dark theme with green accent colors similar to Waves PAZ
 */
class PAZLookAndFeel : public juce::LookAndFeel_V4
{
public:
    PAZLookAndFeel();
    ~PAZLookAndFeel() override = default;

    // ComboBox
    void drawComboBox(juce::Graphics& g, int width, int height, bool isButtonDown,
                      int buttonX, int buttonY, int buttonW, int buttonH,
                      juce::ComboBox& box) override;

    void positionComboBoxText(juce::ComboBox& box, juce::Label& label) override;

    juce::Font getComboBoxFont(juce::ComboBox& box) override;

    // Popup Menu
    void drawPopupMenuItem(juce::Graphics& g, const juce::Rectangle<int>& area,
                           bool isSeparator, bool isActive, bool isHighlighted,
                           bool isTicked, bool hasSubMenu,
                           const juce::String& text, const juce::String& shortcutKeyText,
                           const juce::Drawable* icon, const juce::Colour* textColour) override;

    // Buttons
    void drawButtonBackground(juce::Graphics& g, juce::Button& button,
                              const juce::Colour& backgroundColour,
                              bool shouldDrawButtonAsHighlighted,
                              bool shouldDrawButtonAsDown) override;

    void drawToggleButton(juce::Graphics& g, juce::ToggleButton& button,
                          bool shouldDrawButtonAsHighlighted,
                          bool shouldDrawButtonAsDown) override;

    // Sliders
    void drawLinearSlider(juce::Graphics& g, int x, int y, int width, int height,
                          float sliderPos, float minSliderPos, float maxSliderPos,
                          juce::Slider::SliderStyle style, juce::Slider& slider) override;

private:
    // Color palette
    juce::Colour backgroundColour{0xff1a1a2e};
    juce::Colour panelColour{0xff252540};
    juce::Colour accentColour{0xff00ff88};
    juce::Colour textColour{0xffcccccc};
    juce::Colour dimTextColour{0xff888888};
    juce::Colour highlightColour{0xff3d3d5c};

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(PAZLookAndFeel)
};
