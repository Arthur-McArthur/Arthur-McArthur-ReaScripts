#include "LookAndFeel.h"

PAZLookAndFeel::PAZLookAndFeel()
{
    // Set default colours
    setColour(juce::ResizableWindow::backgroundColourId, backgroundColour);
    setColour(juce::PopupMenu::backgroundColourId, panelColour);
    setColour(juce::PopupMenu::textColourId, textColour);
    setColour(juce::PopupMenu::highlightedBackgroundColourId, highlightColour);
    setColour(juce::PopupMenu::highlightedTextColourId, accentColour);

    setColour(juce::ComboBox::backgroundColourId, panelColour);
    setColour(juce::ComboBox::textColourId, textColour);
    setColour(juce::ComboBox::outlineColourId, highlightColour);
    setColour(juce::ComboBox::arrowColourId, accentColour);

    setColour(juce::TextButton::buttonColourId, panelColour);
    setColour(juce::TextButton::textColourOffId, textColour);
    setColour(juce::TextButton::textColourOnId, accentColour);

    setColour(juce::Slider::thumbColourId, accentColour);
    setColour(juce::Slider::trackColourId, highlightColour);
    setColour(juce::Slider::backgroundColourId, panelColour);
}

void PAZLookAndFeel::drawComboBox(juce::Graphics& g, int width, int height,
                                   bool isButtonDown, int /*buttonX*/, int /*buttonY*/,
                                   int /*buttonW*/, int /*buttonH*/, juce::ComboBox& box)
{
    auto cornerSize = 4.0f;
    juce::Rectangle<int> boxBounds(0, 0, width, height);

    g.setColour(panelColour);
    g.fillRoundedRectangle(boxBounds.toFloat(), cornerSize);

    g.setColour(box.isEnabled() ? highlightColour : highlightColour.darker());
    g.drawRoundedRectangle(boxBounds.toFloat().reduced(0.5f, 0.5f), cornerSize, 1.0f);

    // Draw arrow
    juce::Rectangle<int> arrowZone(width - 20, 0, 15, height);
    juce::Path path;
    path.startNewSubPath(static_cast<float>(arrowZone.getX()) + 3.0f,
                         static_cast<float>(arrowZone.getCentreY()) - 2.0f);
    path.lineTo(static_cast<float>(arrowZone.getCentreX()),
                static_cast<float>(arrowZone.getCentreY()) + 3.0f);
    path.lineTo(static_cast<float>(arrowZone.getRight()) - 3.0f,
                static_cast<float>(arrowZone.getCentreY()) - 2.0f);

    g.setColour(box.isEnabled() ? (isButtonDown ? accentColour.brighter() : accentColour)
                                : dimTextColour);
    g.strokePath(path, juce::PathStrokeType(2.0f));
}

void PAZLookAndFeel::positionComboBoxText(juce::ComboBox& box, juce::Label& label)
{
    label.setBounds(5, 1, box.getWidth() - 25, box.getHeight() - 2);
    label.setFont(getComboBoxFont(box));
    label.setColour(juce::Label::textColourId, textColour);
}

juce::Font PAZLookAndFeel::getComboBoxFont(juce::ComboBox& /*box*/)
{
    return juce::Font(13.0f);
}

void PAZLookAndFeel::drawPopupMenuItem(juce::Graphics& g, const juce::Rectangle<int>& area,
                                        bool isSeparator, bool isActive, bool isHighlighted,
                                        bool isTicked, bool /*hasSubMenu*/,
                                        const juce::String& text, const juce::String& /*shortcutKeyText*/,
                                        const juce::Drawable* /*icon*/, const juce::Colour* /*textColour*/)
{
    if (isSeparator)
    {
        auto r = area.reduced(5, 0);
        r.removeFromTop(juce::roundToInt((r.getHeight() * 0.5f) - 0.5f));
        g.setColour(highlightColour);
        g.fillRect(r.removeFromTop(1));
    }
    else
    {
        auto r = area.reduced(1);

        if (isHighlighted && isActive)
        {
            g.setColour(highlightColour);
            g.fillRect(r);
            g.setColour(accentColour);
        }
        else
        {
            g.setColour(isActive ? textColour : dimTextColour);
        }

        r.reduce(juce::jmin(5, area.getWidth() / 20), 0);

        auto font = juce::Font(13.0f);

        if (isTicked)
        {
            auto tickWidth = juce::jmin(14.0f, static_cast<float>(r.getHeight()));
            g.setColour(accentColour);
            g.drawText(juce::String::charToString(0x2713), r.removeFromLeft(static_cast<int>(tickWidth)),
                       juce::Justification::centred);
        }

        g.setFont(font);
        g.drawFittedText(text, r, juce::Justification::centredLeft, 1);
    }
}

void PAZLookAndFeel::drawButtonBackground(juce::Graphics& g, juce::Button& button,
                                           const juce::Colour& /*backgroundColour*/,
                                           bool shouldDrawButtonAsHighlighted,
                                           bool shouldDrawButtonAsDown)
{
    auto bounds = button.getLocalBounds().toFloat().reduced(0.5f, 0.5f);
    auto cornerSize = 4.0f;

    juce::Colour baseColour = panelColour;

    if (shouldDrawButtonAsDown)
        baseColour = highlightColour.brighter(0.2f);
    else if (shouldDrawButtonAsHighlighted)
        baseColour = panelColour.brighter(0.1f);

    g.setColour(baseColour);
    g.fillRoundedRectangle(bounds, cornerSize);

    g.setColour(shouldDrawButtonAsDown ? accentColour : highlightColour);
    g.drawRoundedRectangle(bounds, cornerSize, 1.0f);
}

void PAZLookAndFeel::drawToggleButton(juce::Graphics& g, juce::ToggleButton& button,
                                       bool shouldDrawButtonAsHighlighted,
                                       bool /*shouldDrawButtonAsDown*/)
{
    auto fontSize = juce::jmin(13.0f, static_cast<float>(button.getHeight()) * 0.75f);
    auto tickWidth = fontSize * 1.1f;

    g.setColour(button.findColour(juce::ToggleButton::textColourId));
    g.setFont(fontSize);

    g.drawFittedText(button.getButtonText(),
                     button.getLocalBounds()
                         .withTrimmedLeft(juce::roundToInt(tickWidth) + 5)
                         .withTrimmedRight(2),
                     juce::Justification::centredLeft, 10);

    juce::Rectangle<float> tickBounds(4.0f, (static_cast<float>(button.getHeight()) - tickWidth) * 0.5f,
                                      tickWidth, tickWidth);

    // Draw checkbox background
    g.setColour(panelColour);
    g.fillRoundedRectangle(tickBounds, 3.0f);

    g.setColour(shouldDrawButtonAsHighlighted ? accentColour : highlightColour);
    g.drawRoundedRectangle(tickBounds, 3.0f, 1.0f);

    if (button.getToggleState())
    {
        // Draw checkmark
        juce::Path tick;
        auto scale = tickWidth / 14.0f;
        auto centre = tickBounds.getCentre();

        tick.startNewSubPath(centre.x - 4.0f * scale, centre.y);
        tick.lineTo(centre.x - 1.0f * scale, centre.y + 3.0f * scale);
        tick.lineTo(centre.x + 4.0f * scale, centre.y - 3.0f * scale);

        g.setColour(accentColour);
        g.strokePath(tick, juce::PathStrokeType(2.0f * scale));
    }
}

void PAZLookAndFeel::drawLinearSlider(juce::Graphics& g, int x, int y, int width, int height,
                                       float sliderPos, float /*minSliderPos*/, float /*maxSliderPos*/,
                                       juce::Slider::SliderStyle style, juce::Slider& slider)
{
    if (style == juce::Slider::LinearHorizontal)
    {
        auto trackHeight = 4.0f;
        auto trackY = static_cast<float>(y) + (static_cast<float>(height) - trackHeight) * 0.5f;

        // Background track
        g.setColour(highlightColour.darker(0.3f));
        g.fillRoundedRectangle(static_cast<float>(x), trackY,
                               static_cast<float>(width), trackHeight, 2.0f);

        // Filled track
        g.setColour(accentColour);
        g.fillRoundedRectangle(static_cast<float>(x), trackY,
                               sliderPos - static_cast<float>(x), trackHeight, 2.0f);

        // Thumb
        auto thumbWidth = 12.0f;
        auto thumbHeight = 16.0f;

        g.setColour(accentColour);
        g.fillRoundedRectangle(sliderPos - thumbWidth * 0.5f,
                               static_cast<float>(y) + (static_cast<float>(height) - thumbHeight) * 0.5f,
                               thumbWidth, thumbHeight, 3.0f);

        if (slider.isMouseOverOrDragging())
        {
            g.setColour(juce::Colours::white.withAlpha(0.3f));
            g.fillRoundedRectangle(sliderPos - thumbWidth * 0.5f,
                                   static_cast<float>(y) + (static_cast<float>(height) - thumbHeight) * 0.5f,
                                   thumbWidth, thumbHeight, 3.0f);
        }
    }
    else
    {
        LookAndFeel_V4::drawLinearSlider(g, x, y, width, height, sliderPos,
                                         sliderPos, sliderPos, style, slider);
    }
}
