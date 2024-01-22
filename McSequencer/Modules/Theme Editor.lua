local function print(v) reaper.ShowConsoleMsg("\n" .. v) end

local function print2(v)
    ; reaper.ShowConsoleMsg('\n' .. type(v) .. '\n' .. tostring(v));
end

local function printTable(t, indent, parentKey)
    if not indent then indent = 0 end
    if not parentKey then parentKey = "" end

    local function buildString(t, indent, parentKey)
        local toprint = string.rep(" ", indent) .. "{\n"
        indent = indent + 2
        for k, v in pairs(t) do
            local keyString = parentKey .. "[" .. tostring(k) .. "]"
            toprint = toprint .. string.rep(" ", indent) .. keyString .. " = "
            if (type(v) == "number") then
                toprint = toprint .. v .. ",\n"
            elseif (type(v) == "string") then
                toprint = toprint .. "\"" .. v .. "\",\n"
            elseif (type(v) == "table") then
                toprint = toprint .. buildString(v, indent + 2, keyString)
                toprint = toprint .. string.rep(" ", indent) -- To format closing brace of nested table
            else
                toprint = toprint .. "\"" .. tostring(v) .. "\",\n"
            end
        end
        toprint = toprint .. string.rep(" ", indent - 2) .. "}"
        return toprint
    end

    local tableString = buildString(t, indent, parentKey)
    reaper.ShowConsoleMsg(tableString) -- Display table in REAPER console
end

return function(script_path, resources_path, themes_path)
    local M = {}

    package.path = package.path .. ";" .. resources_path .. "?.lua"
    local serpent = require("serpent")
    local reaper = reaper
    

    local button_names = {
        "Background",
        "Titlebar",
        "Titlebar Active",
        "Scrollbar 4",
        "sidebar_bg 5",
        "Separator",
        "Button 7",
        "Button 8",
        "Button 9",
        "Button 10",
        "playcursor_bg",
        "playcursor_frame 12",
        "playcursor_active 13",
        "playcursor_hovered 14",
        "Steps_border 15",
        "Steps_even_off 16",
        "Steps_even_on 17",
        "Steps_odd_off 18",
        "Steps_odd_on 19",
        "Steps_line 20",
        "Button 21",
        "Button 22",
        "Slider 1",
        "Slider 2",
        "Slider 3",
        "Button 26",
        "Button 27",
        "Button 28",
        "Button 29",
        "selector 30",
        "selector_frame 31",
        "channelbutton 32",
        "channelbutton_dropped 33",
        "channelbutton_active 34",
        "channelbutton_frame 35",
        "channelbutton_text 36",
        "Sidebar Text 37",
        "Button 38",
        "Button 39",
        "knob_tcp_circle",
        "knob_tcp_line",
        "knob_env_circle 42",
        "knob_env_line 43",
        "knob_sidebar_circle 44",
        "knob_sidebar_line 45",
        "Button 46",
        "Button 47",
        "Button 48",
        "Button 49",
        "Button 50",
        "Button 51",
        "Button 52",
        "Button 53",
        "Button 54",
        "button_mute_active 55",
        "button_mute_inactive 56",
        "button_mute_border 57",
        "button_solo_active 58",
        "button_solo_inactive 59",
        "button_solo_border 60",
        "button_sidebar_active 61",
        "button_sidebar_inactive 62",
        "button_sidebar_border 63",
        "Button 64",
        "Button 65",
        "Waveform Display 66",
        "color67_waveformShading",
        "Button 68",
        "Button 69",
        "color70_transparent"
    }

    -- Define the state key to remember the last loaded file
    local extStateKey = "McSequencer"
    local button_colors = {}
    for i = 1, 70 do
        button_colors[i] = {
            r = math.random(), -- Random red value between 0 and 1
            g = math.random(), -- Random green value between 0 and 1
            b = math.random(), -- Random blue value between 0 and 1
            a = 1.0            -- Alpha value (opaque)
        }
    end

    -- Define default RGBA values for the color picker
    local selected_color_r = 0.5
    local selected_color_g = 0.5
    local selected_color_b = 0.5
    local selected_color_a = 1.0
    local num_buttons = 70
    local default_color = { r = 0.5, g = 0.5, b = 0.5, a = 1.0 }

    -- Function to initialize the button_colors table with default values
    M.initializeButtonColors = function(num_buttons, default_color)
        local button_colors = {}
        for i = 1, num_buttons do
            button_colors[i] = {
                r = default_color.r,
                g = default_color.g,
                b = default_color.b,
                a = default_color.a,
            }
        end
        return button_colors
    end

    -- Initialize button_colors table with default values
    local button_colors = M.initializeButtonColors(num_buttons, default_color)

    local save_filename = themes_path .. "saved_colors.txt"
    local load_filename = themes_path .. "saved_colors.txt"

    -- Function to save colors to a file
    M.saveColorsToFile = function(button_colors, filename)
        local file = io.open(filename, "w")
        if file then
            file:write("do local _={")
            for i, hex_color in ipairs(button_colors) do
                if i > 1 then
                    file:write(",")
                end
                file:write(hex_color)
            end
            file:write("};return _;end")
            file:close()
        else
            reaper.ShowConsoleMsg("Error: Could not save colors to file.\n")
        end
    end

    -- Define the color picker function
    M.createColorPicker = function(ctx)
        local color_picker_width = 300
        reaper.ImGui_PushItemWidth(ctx, color_picker_width)

        -- Ensure selected_hex_color is valid
        selected_hex_color = selected_hex_color or "0xFFFFFFFF"

        -- Convert hexadecimal to RGBA then to native color
        local r, g, b, a = reaper.ImGui_ColorConvertU32ToDouble4(selected_hex_color)
        local native_color = rgbaToHex(math.floor(r * 255), math.floor(g * 255), math.floor(b * 255), math.floor(a * 255),
            "0x")

        local color_changed, new_native_color = reaper.ImGui_ColorPicker4(ctx, "##ColorPicker", native_color, 0)

        if color_changed and selected_button_index then
            selected_hex_color = new_native_color
            button_colors[selected_button_index] = selected_hex_color
        end

        reaper.ImGui_PopItemWidth(ctx)
    end

    function rgbaToHex(r, g, b, a, prefix)
        prefix = prefix or "#"
        return prefix .. string.format("%0.2X%0.2X%0.2X%0.2X", r, g, b, a)
    end

    M.createColorButtons = function(ctx, button_colors, i)
        local hex_color = button_colors[i] or "0xFFFFFFFF" -- Fallback color if nil
        local r, g, b, a = reaper.ImGui_ColorConvertU32ToDouble4(hex_color)

        -- Convert RGBA to ABGR format as expected by REAPER
        local button_native_color = rgbaToHex(math.floor(r * 255), math.floor(g * 255), math.floor(b * 255),
            math.floor(a * 255), "0x")

        -- Flag to track if style color is pushed
        local is_style_color_pushed = false

        -- Create a color button
        if reaper.ImGui_ColorButton(ctx, "##ColorButton" .. tostring(i), button_native_color, 0, 20, 20) then
            -- If left-clicked, update the color picker with this button's color
            selected_hex_color = hex_color
            selected_button_index = i -- Update the selected button index
        end
    end

    -- Function to display color buttons along with their names
    M.displayColorButtonsWithNames = function(ctx, button_colors, button_names)
        -- Define the size of the scrollable region
        local scrollable_region_width = 200
        local scrollable_region_height = 300

        -- Begin the scrollable child region
        reaper.ImGui_BeginChild(ctx, "ScrollableRegion", scrollable_region_width, scrollable_region_height, true)

        -- Create 40 color buttons with names
        for i = 1, 70 do
            -- Create color buttons (using createColorButtons function)
            M.createColorButtons(ctx, button_colors, i)
            reaper.ImGui_SameLine(ctx)
            -- Display the hardcoded button name
            reaper.ImGui_Text(ctx, button_names[i])
        end

        -- End the scrollable child region
        reaper.ImGui_EndChild(ctx)
    end

    M.obj_ColorPicker = function(ctx)
        -- Create the color picker
        M.createColorPicker(ctx)
        reaper.ImGui_SameLine(ctx)
        -- Display a scrollable list of color buttons
        M.displayColorButtonsWithNames(ctx, button_colors, button_names)

        -- Create buttons for save and load
        if reaper.ImGui_Button(ctx, "Save Colors") then
            -- Open file picker for saving
            local retval, chosenFile = reaper.GetUserFileNameForRead(themes_path, "Save Colors", ".txt")
            if retval then
                save_filename = chosenFile
                M.saveColorsToFile(button_colors, save_filename)
            end
        end
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, "Load Colors") then
            -- Get the last loaded file (if available) to use as default in file picker
            local defaultFile = reaper.GetExtState(extStateKey, "themeLastLoadedPath") or ""
            -- Open file picker for loading
            local retval, chosenFile = reaper.GetUserFileNameForRead(themes_path, "Load Colors", ".txt")
            if retval then
                load_filename = chosenFile
                local loaded_colors = M.loadColorsFromFile(load_filename)
                if loaded_colors then
                    button_colors = loaded_colors
                    -- Save the loaded file path as the last loaded file
                    reaper.SetExtState(extStateKey, "themeLastLoadedPath", load_filename, true)
                end
            end
        end

        reaper.ImGui_Dummy(ctx, 33, 0)
    end

    M.colorUpdate = function()
        local colors = {
            color1_bg                       = button_colors[1],
            color2_titlebar                 = button_colors[2],
            color3_titlebaractive           = button_colors[3],
            color4_scrollbar                = button_colors[4],
            color5_sidebar_bg               = button_colors[5],
            color6_separator                = button_colors[6],
            color7_                         = button_colors[7],
            color8_                         = button_colors[8],
            color9_                         = button_colors[9],
            color10_                        = button_colors[10],
            color11_playcursor_bg           = button_colors[11],
            color12_playcursor_frame        = button_colors[12],
            color13_playcursor_active       = button_colors[13],
            color14_playcursor_hovered      = button_colors[14],
            color15_Steps_border            = button_colors[15],
            color16_Steps_even_off          = button_colors[16],
            color17_Steps_even_on           = button_colors[17],
            color18_Steps_odd_off           = button_colors[18],
            color19_Steps_odd_on            = button_colors[19],
            color20_Steps_line              = button_colors[20],
            color21_                        = button_colors[21],
            color22_                        = button_colors[22],
            color23_slider1                 = button_colors[23],
            color24_slider2                 = button_colors[24],
            color25_slider3                 = button_colors[25],
            color26_                        = button_colors[26],
            color27_                        = button_colors[27],
            color28_                        = button_colors[28],
            color29_                        = button_colors[29],
            color30_selector                = button_colors[30],
            color31_selector_frame          = button_colors[31],
            color32_channelbutton           = button_colors[32],
            color33_channelbutton_dropped   = button_colors[33],
            color34_channelbutton_active    = button_colors[34],
            color35_channelbutton_frame     = button_colors[35],
            color36_channelbutton_text      = button_colors[36],
            color37_sidebar_text            = button_colors[37],
            color38_                        = button_colors[38],
            color39_                        = button_colors[39],
            color40_knob_tcp_circle         = button_colors[40],
            color41_knob_tcp_line           = button_colors[41],
            color42_knob_env_circle         = button_colors[42],
            color43_knob_env_line           = button_colors[43],
            color44_knob_sidebar_circle     = button_colors[44],
            color45_knob_sidebar_line       = button_colors[45],
            color46_                        = button_colors[46],
            color47_                        = button_colors[47],
            color48_                        = button_colors[48],
            color49_                        = button_colors[49],
            color50_                        = button_colors[50],
            color51_                        = button_colors[51],
            color52_                        = button_colors[52],
            color53_                        = button_colors[53],
            color54_                        = button_colors[54],
            color55_button_mute_active      = button_colors[55],
            color56_button_mute_inactive    = button_colors[56],
            color57_button_mute_border      = button_colors[57],
            color58_button_solo_active      = button_colors[58],
            color59_button_solo_inactive    = button_colors[59],
            color60_button_solo_border      = button_colors[60],
            color61_button_sidebar_active   = button_colors[61],
            color62_button_sidebar_inactive = button_colors[62],
            color63_button_sidebar_border   = button_colors[63],
            color64_                        = button_colors[64],
            color65_                        = button_colors[65],
            color66_waveform                = button_colors[66],
            color67_waveformShading                        = button_colors[67],
            color68_                        = button_colors[68],
            color69_                        = button_colors[69],
            color70_transparent                        = button_colors[70]
        }

        return colors
    end


    
    -- Function to load colors from a file
    M.loadColorsFromFile = function(filename)
        local file, err = loadfile(filename)
        if file then
            local success, loaded_colors = pcall(file)
            if success and type(loaded_colors) == "table" then
                -- Convert numbers to hex strings with '0x' prefix
                for i, color in ipairs(loaded_colors) do
                    loaded_colors[i] = string.format("0x%X", color)
                end
                return loaded_colors
            else
                reaper.ShowConsoleMsg("Error: The file did not return a table.\n")
            end
        else
            reaper.ShowConsoleMsg("Error in loading file: " .. tostring(err) .. "\n")
        end
        return nil
    end

    --  reaper.SetExtState('McSequencer', "themeLastLoadedPath", '', 1)
    -- On script start, try loading the last loaded theme
    local lastLoadedFile = reaper.GetExtState(extStateKey, "themeLastLoadedPath")
    if lastLoadedFile ~= "" then
        -- print('last loaded')
        -- print2(lastLoadedFile)

        button_colors = M.loadColorsFromFile(lastLoadedFile)
    else
        -- If there's no last loaded file or loading fails, load the default theme
        -- print('default')
        local default_theme_filename = script_path .. "Themes/theme_1.txt"
        -- print2(default_theme_filename)
        button_colors = M.loadColorsFromFile(default_theme_filename)
    end

    return M
end
