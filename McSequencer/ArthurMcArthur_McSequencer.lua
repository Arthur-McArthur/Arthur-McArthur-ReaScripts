-- @description Arthur McArthur McSequencer
-- @author Arthur McArthur
-- @license GPL v3
-- @version 1.2.01
-- @changelog
--  - Holding down alt while dragging a knob will change values across all selected tracks
--  - Control-click on a channel button will preview the sample
--  - Set item grouping on by default
--  - Switching samples from the cycle and random buttons on the sidebar will change the track name
--  - Display slider value numbers for velocity and offset
--  - Mousewheel scroll will work on the sequencer while holding control
--  - Mousewheel scrolling will be smoother and work when it should
--  - Waveform view tweaks
--  - Improved accuracy of inserting new items
-- @provides
--   Modules/*.lua
--   Images/*.png
--   JSFX/*.jsfx
--   Themes/*.txt
--   Fonts/*.ttc
--   [effect] JSFX/*.jsfx

local versionNumber = '1.2.01'
local reaper = reaper
local os = reaper.GetOS()

function GetFullProjectPath(proj) -- with projct Name. with .rpp at the end
    return reaper.GetProjectPathEx( proj ):gsub("(.*)\\.*$","%1")  .. reaper.GetProjectName(proj)
end


---------------------
----------------- Extension Checker 
---------------------

--- Check if user REAPER version. min_version and max_version are optional
function CheckREAPERVersion(min_version, max_version)
    local reaper_version = reaper.GetAppVersion():match('%d+%.%d+')
    local bol, why = CompareVersion(reaper_version, min_version, max_version)
    if not bol then
        local text
        if why == 'min' then
            text = 'This script requires that REAPER minimum version be : '..min_version..'.\nYour version is '..reaper_version
        elseif why == 'max' then
            text = 'This script requires that REAPER maximum version be : '..max_version..'.\nYour version is '..reaper_version
        end
        reaper.ShowMessageBox(text, 'Error - REAPER at Incompatible Version', 0)
        return false
    end
    return true
end

--- Check if user have Extension. min_version and max_version are optional
function CheckSWS(min_version, max_version)
    if not reaper.APIExists('CF_GetSWSVersion') then
        local text = 'This script requires the SWS Extension to run. \nWould you like to be redirected to the SWS Extension website to install it?'
        local ret = reaper.ShowMessageBox(text, 'Error - Missing Dependency', 4)
        if ret == 6 then
            open_url('https://www.sws-extension.org/')
        end
        return false
    else
        local sws_version = reaper.CF_GetSWSVersion()
        local bol, why = CompareVersion(sws_version, min_version, max_version)
        if not bol then
            local text, url
            if why == 'min' then
                text = 'This script requires that SWS minimum version be : '..min_version..'.\nYour version is '..sws_version..'.\nWould you like to be redirected to the SWS Extension website to update it?'
                url = 'https://www.sws-extension.org/'
            elseif why == 'max' then
                text = 'This script requires that SWS maximum version be : '..max_version..'.\nYour version is '..sws_version..'.\nWould you like to be redirected to the website of old version SWS Extension to downgrade it?'
                url = 'https://www.sws-extension.org/download/old/'
            end
            local ret = reaper.ShowMessageBox(text, 'Error - Missing Dependency', 4)
            if ret == 6 then
                open_url(url)
            end
            return false
        end
    end
    return true
end

--- Check if user have Extension. min_version and max_version are optional
function CheckReaImGUI(min_version, max_version)
    if not reaper.APIExists('ImGui_GetVersion') then
        local text = 'This script requires the ReaImGui extension to run. You can install it through ReaPack.'
        local ret = reaper.ShowMessageBox(text, 'Error - Missing Dependency', 0)
        return false
    else
        local imgui_version, imgui_version_num, reaimgui_version = reaper.ImGui_GetVersion()
        local bol, why = CompareVersion(reaimgui_version, min_version, max_version)
        if not bol then
            local text
            if why == 'min' then
                text = 'This script requires that ReaImgui minimum version be : '..min_version..'.\nYour version is '..reaimgui_version..'\nYou can update it through ReaPack.'
            elseif why == 'max' then
                text = 'This script requires that ReaImgui maximum version be : '..max_version..'.\nYour version is '..reaimgui_version..'\nYou can update it through ReaPack.'
            end
            reaper.ShowMessageBox(text, 'Error - Dependency at Incompatible Version', 0)
            return false
        end
    end    
    return true
end

--- Check if user have Extension. min_version and max_version are optional
function CheckJS(min_version, max_version)
    if not reaper.APIExists('JS_ReaScriptAPI_Version') then
        local text = 'This script requires the js_ReaScriptAPI extension to run. You can install it through ReaPack.'
        local ret = reaper.ShowMessageBox(text, 'Error - Missing Dependency', 0)
        return false
    else
        local js_version = tostring(reaper.JS_ReaScriptAPI_Version())
        local bol, why = CompareVersion(js_version, min_version, max_version)
        if not bol then
            local text
            if why == 'min' then
                text = 'This script requires that js_ReaScriptAPI minimum version be : '..min_version..'.\nYour version is '..js_version..'\nYou can update it through ReaPack.'
            elseif why == 'max' then
                text = 'This script requires that js_ReaScriptAPI maximum version be : '..max_version..'.\nYour version is '..js_version..'\nYou can update it through ReaPack.'
            end
            reaper.ShowMessageBox(text, 'Error - Dependency at Incompatible Version', 0)
            return false
        end
    end
    return true
end

function CompareVersion(check_version, min_version, max_version, separator)
    separator = separator or '.'
    local check_table = {}
    for version in check_version:gmatch('(%d+)'..separator..'?') do
        check_table[#check_table+1] = tonumber(version)
    end

    local min_table
    if min_version then
        min_table = {}
        for version in min_version:gmatch('(%d+)'..separator..'?') do
            min_table[#min_table+1] = tonumber(version)
        end
    end

    local max_table
    if max_version then
        max_table = {}
        for version in max_version:gmatch('(%d+)'..separator..'?') do
            max_table[#max_table+1] = tonumber(version)
        end
    end

    for index, check_v in ipairs(check_table) do
        -- check if is less than the min_version
        if min_table and check_v < (min_table[index] or 0) then
            return false, 'min'
        elseif min_table and check_v > (min_table[index] or 0) then -- bigger than the min version stop checking min_version
            min_table = nil
        end
        
        -- check if is more than the max_version
        if max_table and check_v > (max_table[index] or 0) then
            return false, 'max'
        elseif max_table and check_v < (max_table[index] or 0) then -- less than the max version stop checking max_version
            max_table = nil
        end    
    end

    return true, nil
end
 
CheckJS()
CheckSWS()
CheckReaImGUI()

local function print(v) reaper.ShowConsoleMsg("\n" .. tostring(v)) end

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

local function printHere()

end

-- Set ToolBar Button State
local function SetButtonState(set)
    local is_new_value, filename, sec, cmd, mode, resolution, val = reaper.get_action_context()
    reaper.SetToggleCommandState(sec, cmd, set or 0)
    reaper.RefreshToolbar2(sec, cmd)
end

local function Exit()
    SetButtonState()
end

dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.8.7')
local script_path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]]
local modules_path = script_path .. "Modules/"
local themes_path = script_path .. "Themes/"
local images_path = script_path .. "Images/"
local cursor_path = script_path .. "Images/Cursors/"
package.path = package.path .. ";" .. modules_path .. "?.lua"
info = debug.getinfo(1, 'S')
------------------------------

local themeEditor = dofile(script_path .. 'Modules/Theme Editor.lua')
local params = dofile(script_path .. 'Modules/Object Params.lua')
local colors = themeEditor(script_path, modules_path, themes_path)
local serpent = require("serpent")


local size_modifier = 1
-- local obj_x, obj_y = 20 * size_modifier, 34 * size_modifier
local lengthSlider = 16
local buttonStates = {}
local track_suffix = " SEQ"
local target_track_name = "Patterns" .. track_suffix
local selectedChannelButton = tonumber(reaper.GetExtState("McSequencer", "selectedChannelButton")) or 2
local selectedButtonIndex = tonumber(reaper.GetExtState("McSequencer", "selectedButtonIndex"))
local clipboard = {} -- To hold the clipboard data for copy and cut actions
local hoveredControlInfo = { id = "", value = 0 }
local note_subdivision = 1 
local drag_start_x = nil
local drag_start_y = nil
 drag_started = false
local wasMouseDownL = false
local wasMouseDownR = false
local processedButtons = processedButtons or {}
local showColorPicker = false
local showFPS = true
local showPreferencesPopup = false
local patternItemsCache = {} -- Cache for memoization
-- local patternItems = {}
local buttonCoordinates = {}
local drag_started = false
local controlSidebarWidth = 220
local time_resolution = 4
local update_required = true
local top_row_x = 34
local valuePitch
local sliderTriggered = false
local triggerTime = 0
local triggerDuration = 0.1 -- duration in seconds for which the slider stays on
-- local originalSizeModifier, originalObjX, originalObjY
local showPopup = false
local copiedValue
local numberOfSliders = 64 -- Define how many sliders you want
local sliderWidth = 20
local x_padding = 2
local right_drag_start_x = nil
local right_drag_start_y = nil
local tension = 0 -- Initial tension level, can be adjusted with the mouse wheel
local fontSize = 12
local fontSidebarButtonsSize = 11
local slider = {}
local dragStartPos = {}
-- local sequencerFlags
local isClicked = {}
local btnimg = {}
local isHovered = { PlayCursor = {}}
local menu_open = {}
local trackWasInserted 
local float_min_value = 2.22507e-308 -- min finite
local float_min = 4.94066e-324 -- denorm_min
local float_max = 1.79769e308
local float_small = 4.940656e-312
local float_epsilon = 0.00001 -- not FLT_EPSILON, but a relative amount to compare by. Here, 0.001%
local NaN = 0/0
local sidebarResize = 0 or sidebarResize
local dragStartedOnAnySelector

for i = 0, numberOfSliders - 1 do
    local value = 0 -- Default value for each slider
    table.insert(slider, { value = value })
end

local channel = {
    channel_amount = {},
    GUID = {
        name = {},
        file_path = {},
        types = {},
        droppedFile = {},
        volume = {},
        pan = {},
        mute = {},
        solo = {},
        plugins = {},
        trackIndex = {},
        selected = {},
        dragged = {}, 
        expand = {
            type = {},
            open = {},
            resizing = {},
            spacing = {}
        },
        pattern_number = {
            button_states = {},
            item_present = {},
            velocity = {},
            pan = {},
            swing = {},
            offset = {},
            pitch = {},
            pitch_fine = {},
        },
    },
}

local parent = {
    channel_amount = {},
    GUID = {
        name = {},
        volume = {},
        pan = {},
        mute = {},
        solo = {},
        trackIndex = {},
        selected = {},
        expand = {
            type = {},
            open = {},
            resizing = {},
            spacing = {}
        },
    },
}

local lastState = {
    volume = {},
    pan = {},
    mute = {},
    solo = {}
}

local layout = {
    Sidebar = {
        bg_x = -1,
        bg_y = 29,
        sampleTitle_x = 14,
        sampleTitle_y = 6,
        waveform_Sz_x = 198,
        waveform_Sz_y = 52,
        waveform_Of_x = 9,
        waveform_Of_y = 6
    }
}

local expandedSliderSizes = {}


local function loadImageFiles(directory)
    local files = {}
    local i = 0
    while true do
        local filename = reaper.EnumerateFiles(directory, i)
        if not filename then break end
        table.insert(files, filename)
        i = i + 1
    end
    return files
end

local ctx = reaper.ImGui_CreateContext("McSequencer")

-- List files in the images directory
local fileList = loadImageFiles(images_path)

-- Table to store the loaded images
local images = {}

for _, fileName in ipairs(fileList) do
    local imagePath = images_path .. fileName
    local img = reaper.ImGui_CreateImage(imagePath)
    reaper.ImGui_Attach(ctx, img)
    local width, height = reaper.ImGui_Image_GetSize(img)

    -- Extract a key name from the file name, e.g., "Mute_off" from "Mute_off.png"
    local key = fileName:match("(.+)%..+")
    images[key] = { i = img, x = width, y = height }
end

------------------------------------------------------ FUNCTIONS ----------------------------------------------

---- DATA MANAGEMENT  ---------------------------------

local function save_channel_data()
    local data_to_save = {
        file_path = channel.GUID.file_path,
    }

    local serialized_data = serpent.dump(data_to_save)
    reaper.SetExtState("McSequencer", "channelData", serialized_data, true)
end

local function load_channel_data()
    local serialized_data = reaper.GetExtState("McSequencer", "channelData")
    if serialized_data and serialized_data ~= "" then
        local ok, data_to_load = serpent.load(serialized_data)
        if ok then
            channel.GUID.file_path = data_to_load.file_path
        else
        end
    end
end

local function clear_extstate_channel_data()
    -- Set the file_path table to an empty table
    channel.GUID.file_path = {}

    -- Save the cleared data using the save_channel_data function
    save_channel_data()
end

local function update_channel_data_from_reaper(track_suffix, track_count)
    if not track_suffix then
        return
    end
    if not track_count then
        track_count = reaper.CountTracks(0)
    end
    local count = 0

    for i = 0, track_count - 1 do
        local track = reaper.GetTrack(0, i)
        local _, track_name = reaper.GetTrackName(track, "")

        -- Exclude tracks starting with "Patterns" and ending with " SEQ"
        if string.match(track_name, "^Patterns.*" .. track_suffix .. "$") then
            parent.GUID[0] = track
            parent.GUID.trackIndex[0] = i
            parent.GUID.name[0] = track_name
            local volume = reaper.GetMediaTrackInfo_Value(track, "D_VOL")
            parent.GUID.volume[0] = volume
            local pan = reaper.GetMediaTrackInfo_Value(track, "D_PAN")
            parent.GUID.pan[0] = pan
            local mute = reaper.GetMediaTrackInfo_Value(track, "B_MUTE")
            parent.GUID.mute[0] = mute
            local solo = reaper.GetMediaTrackInfo_Value(track, "I_SOLO")
            parent.GUID.solo[0] = solo
            goto continue
        end

        -- Include tracks ending with " SEQ" (as defined by track_suffix)
        if string.sub(track_name, -string.len(track_suffix)) == track_suffix then
            channel.GUID[count] = track
            count = count + 1
            
            channel.GUID.trackIndex[count] = i
            channel.GUID.name[count] = track_name
            local volume = reaper.GetMediaTrackInfo_Value(track, "D_VOL")
            channel.GUID.volume[count] = volume
            local pan = reaper.GetMediaTrackInfo_Value(track, "D_PAN")
            channel.GUID.pan[count] = pan
            local mute = reaper.GetMediaTrackInfo_Value(track, "B_MUTE")
            channel.GUID.mute[count] = mute
            local solo = reaper.GetMediaTrackInfo_Value(track, "I_SOLO")
            channel.GUID.solo[count] = solo
        end

        ::continue::
    end

    channel.channel_amount = count

    return channel
end

local function apply_channel_data_to_reaper(track_suffix, track_count)
    local count = 0

    for i = 0, track_count - 1 do
        local track = reaper.GetTrack(0, i)
        if not track then return end
        local _, track_name = reaper.GetTrackName(track, "")

        if string.match(track_name, "^Patterns.*" .. track_suffix .. "$") then
            
            if parent.GUID.volume[0] and parent.GUID.volume[0] ~= lastState.volume[0] then
                reaper.SetMediaTrackInfo_Value(track, "D_VOL", parent.GUID.volume[0])
                lastState.volume[0] = parent.GUID.volume[0]
            end

            -- Apply pan
            if parent.GUID.pan[0] and parent.GUID.pan[0] ~= lastState.pan[0] then
                reaper.SetMediaTrackInfo_Value(track, "D_PAN", parent.GUID.pan[0])
                lastState.pan[0] = parent.GUID.pan[0]
            end

            -- Apply mute
            if parent.GUID.mute[0] ~= nil and parent.GUID.mute[0] ~= lastState.mute[0] then
                reaper.SetMediaTrackInfo_Value(track, "B_MUTE", parent.GUID.mute[0])
                lastState.mute[0] = parent.GUID.mute[0]
            end

            -- Apply solo
            if parent.GUID.solo[0] ~= nil and parent.GUID.solo[0] ~= lastState.solo[0] then
                reaper.SetMediaTrackInfo_Value(track, "I_SOLO", parent.GUID.solo[0])
                lastState.solo[0] = parent.GUID.solo[0]
            end
        end

        if
            string.sub(track_name, -string.len(track_suffix)) == track_suffix
            and not string.match(track_name, "^Patterns")
        then
            
            count = count + 1

            -- Apply volume
            if channel.GUID.volume[count] and channel.GUID.volume[count] ~= lastState.volume[count] then
                reaper.SetMediaTrackInfo_Value(track, "D_VOL", channel.GUID.volume[count])
                lastState.volume[count] = channel.GUID.volume[count]
            end

            -- Apply pan
            if channel.GUID.pan[count] and channel.GUID.pan[count] ~= lastState.pan[count] then
                reaper.SetMediaTrackInfo_Value(track, "D_PAN", channel.GUID.pan[count])
                lastState.pan[count] = channel.GUID.pan[count]
            end

            -- Apply mute
            if channel.GUID.mute[count] ~= nil and channel.GUID.mute[count] ~= lastState.mute[count] then
                reaper.SetMediaTrackInfo_Value(track, "B_MUTE", channel.GUID.mute[count])
                lastState.mute[count] = channel.GUID.mute[count]
            end

            -- Apply solo
            if channel.GUID.solo[count] ~= nil and channel.GUID.solo[count] ~= lastState.solo[count] then
                reaper.SetMediaTrackInfo_Value(track, "I_SOLO", channel.GUID.solo[count])
                lastState.solo[count] = channel.GUID.solo[count]
            end
        end
    end
end

local function update(ctx, track_count, track_suffix, channel)
    if reaper.ImGui_IsAnyItemActive(ctx) or reaper.ImGui_IsAnyItemHovered(ctx) then
        apply_channel_data_to_reaper(track_suffix, track_count);
        if update_required then
            channel = update_channel_data_from_reaper(track_suffix, track_count);
            update_required = false;
        end;
    else
        update_channel_data_from_reaper(track_suffix, track_count);
    end;
    return channel
end


local function retrieveExtState()
    -- Retrieve the last selected pattern
    local lastSelectedPattern = tonumber(reaper.GetExtState("PatternController", "lastSelectedPattern"))
    if lastSelectedPattern then
        patternSelectSlider = lastSelectedPattern
    else
        patternSelectSlider = 1
    end
end

---- UTILITY  ---------------------------------

local function toboolean(str)
    return str == "true"
end

local function shorten_name(name, track_suffix)
    -- Remove the track_suffix from the name
    local cleaned_name = name:gsub(track_suffix, "")

    -- Shorten long names by displaying the beginning and end of the name
    if #cleaned_name > 12 then
        cleaned_name = cleaned_name:sub(1, 7) .. ".." .. cleaned_name:sub(-5) 
    end

    return cleaned_name
end

local function rectsIntersect(ax1, ay1, ax2, ay2, bx1, by1, bx2, by2)
    local topRect = ay1 < by1 and ay2 < by1
    local bottomRect = ay1 > by2 and ay2 > by2
    return ax1 <= bx2 and ax2 >= bx1 and not topRect and not bottomRect
end

local function adjustCursorPos(ctx, deltaX, deltaY)
    local cursX, cursY = reaper.ImGui_GetCursorPos(ctx)
    
    if deltaX ~= 0 then
        reaper.ImGui_SetCursorPosX(ctx, cursX + deltaX)
    end
    
    if deltaY ~= 0 then
        reaper.ImGui_SetCursorPosY(ctx, cursY + deltaY)
    end
end

local function goToLoopStart()
    reaper.PreventUIRefresh(1)
    -- Save current view and time selection
    local view_start, view_end = reaper.BR_GetArrangeView(0) -- Requires SWS Extension
    local startTime, endTime = reaper.GetSet_LoopTimeRange(false, true, 0, 0, false)
    -- Handling time navigation
    if startTime ~= endTime then
        -- Go to start of loop
        reaper.SetEditCurPos(startTime, true, true)
    else
        -- Go to start of project
        reaper.SetEditCurPos(0, true, true)
    end
    -- Restore view
    reaper.BR_SetArrangeView(0, view_start, view_end) -- Requires SWS Extension
    -- Focusing MIDI Editor (if required)
    -- This might still need Main_OnCommand, especially if it's a specific custom action or script
    reaper.Main_OnCommand(reaper.NamedCommandLookup("_SN_FOCUS_MIDI_EDITOR"), 0)
    reaper.PreventUIRefresh(-1)
end

local function isAnyMenuOpen(menu_open)
    local numMenus = #menu_open
    for i = 1, numMenus do
        if menu_open[i] then
            return true
        end
    end
    return false
end

local function nearlyEqual(a, b, epsilon) -- thank you sockmonkey72!!
    local absA = math.abs(a)
    local absB = math.abs(b)
    local diff = math.abs(a - b)
  
    epsilon = epsilon or float_epsilon -- default value
  
    if (a == b) then -- shortcut, handles infinities
      return true
    elseif (a == 0 or b == 0 or (absA + absB < float_min_value)) then
      -- a or b is zero or both are extremely close to it
      -- relative error is less meaningful here
      return diff < (epsilon * float_min_value)
    else -- use relative error
      return diff < epsilon * math.max(absA, absB)
      -- I prefer the comparison above, but this one works, too
      -- return (diff / math.min((absA + absB), float_max)) < epsilon
    end
end

function translateNoteNumber(noteNumber)
    local noteNames = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
    local octave = math.floor(noteNumber / 12) - 1
    local noteIndex = (noteNumber % 12) + 1
    return noteNames[noteIndex] .. tostring(octave)
end

function removeFileExtension(filename)
    -- Separate gsub calls for each file extension
    filename = filename:gsub("%.wav$", "")
    filename = filename:gsub("%.mp3$", "")
    filename = filename:gsub("%.flac$", "")
    filename = filename:gsub("%.aiff$", "")
    filename = filename:gsub("%.aif$", "")
    filename = filename:gsub("%.ogg$", "")
    filename = filename:gsub("%.m4a$", "")
    filename = filename:gsub("%.wma$", "")
    filename = filename:gsub("%.alac$", "")
    filename = filename:gsub("%.aac$", "")
    filename = filename:gsub("%.opus$", "")
    return filename
end

----- PARAMETER RELATED -----

local function setParamOnSelectedTracks(fxIndex, paramIndex, paramValue, shouldSet)
    if shouldSet then
        local countTracks = reaper.CountSelectedTracks(0)
        for i = 0, countTracks - 1 do
            local track = reaper.GetSelectedTrack(0, i)
            if paramIndex == "vol" then
                reaper.SetMediaTrackInfo_Value(track, "D_VOL", paramValue)
            elseif paramIndex == "pan" then
                reaper.SetMediaTrackInfo_Value(track, "D_PAN", paramValue)
            else
                reaper.TrackFX_SetParam(track, fxIndex, paramIndex, paramValue)
            end
        end
    end
end

----- GENERIC GUI OBJECT CLASS -----

local function obj_Button(ctx, id, is_active, color_active, color_inactive, color_border, border_size, button_width,
                          button_height, hoveredinfo)
    local button_color = is_active and color_active or color_inactive
    local hovered_color = button_color -- Hovered color is the same as button color
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), button_color)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), hovered_color)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), color_border)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), color_active)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameBorderSize(), border_size) -- Border size
    local rv = reaper.ImGui_Button(ctx, id, button_width, button_height)                 -- Adjust button size (width, height) as needed
    reaper.ImGui_PopStyleColor(ctx, 4)                                                   -- Pop all three colors
    reaper.ImGui_PopStyleVar(ctx)                                                        -- Pop border size

    if hoveredinfo then
        if reaper.ImGui_IsItemHovered(ctx) then
            hoveredControlInfo.id = hoveredinfo
        end
    else
        if reaper.ImGui_IsItemHovered(ctx) or is_active then
            hoveredControlInfo.id = id
            hoveredControlInfo.value = is_active
        end
    end
    return rv -- Return whether the button was clicked
end

local function  obj_ImageButton(ctx, id, is_active, button_width, button_height, hoveredinfo)

    local rv = buttonStates4[i] or false
    
    local img = rv and img or img2

    reaper.ImGui_Image(ctx, img, 22, 22)
    
    if reaper.ImGui_IsItemClicked(ctx) then 
        buttonStates4[i] = not buttonStates4[i] -- Toggle the state for the specific button
    end
    
    return rv
        
end

local function obj_Knob_Menu(ctx, value)
    if reaper.ImGui_MenuItem(ctx, "Copy") then
        copiedValue = value
        reaper.ImGui_CloseCurrentPopup(ctx) -- Close the context menu
    end
    if reaper.ImGui_MenuItem(ctx, "Paste") then
        if value and copiedValue then
            value = copiedValue
            rv = true
            reaper.ImGui_CloseCurrentPopup(ctx) -- Close the context menu
        end
    end


    local is_key_c_pressed = reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_C())
    local is_key_v_pressed = reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_V())
    if is_key_v_pressed then
        if value and copiedValue then
            value = copiedValue
            rv = true
            reaper.ImGui_CloseCurrentPopup(ctx)     -- Close the context menu
        end
    end
    if is_key_c_pressed then
        copiedValue = value
        reaper.ImGui_CloseCurrentPopup(ctx)     -- Close the context menu
    end

 
    reaper.ImGui_EndPopup(ctx)
        
    return value, rv
end

local function obj_Knob2(ctx, imageParams, id, value, params, mouse, keys, yOffset)
    reaper.ImGui_InvisibleButton(ctx, id, params.frameWidth, params.frameHeight)
    reaper.ImGui_SameLine(ctx)
    if not yOffset then yOffset = 0 end
    adjustCursorPos(ctx, -params.frameWidth - 7, 3 - yOffset)

    local isActive = reaper.ImGui_IsItemActive(ctx)
    local rv = false

    -- Define the actual sensitivity based on key modifiers
    local dragSensitivity = (keys.ctrlShiftDown or keys.ctrlAltShiftDown) and params.dragFineSensitivity * 0.25 or
        ((keys.ctrlDown or keys.ctrlAltDown) and params.dragFineSensitivity * 0.5 or
        ((keys.shiftDown or keys.shiftAltDown) and params.dragFineSensitivity or
        params.dragSensitivity))

    local wheelSensitivity = (keys.ctrlShiftDown or keys.ctrlAltShiftDown) and params.wheelFineSensitivity * 0.25 or
        ((keys.ctrlDown or keys.ctrlAltDown) and params.wheelFineSensitivity * 0.5 or
        ((keys.shiftDown or keys.shiftAltDown) and params.wheelFineSensitivity or
        params.wheelSensitivity))

    local overallSensitivity = 250

    -- Transform the value to a curved scale
    if not value then
        update_requiered = true
        return
    end

    local normalizedValue = (value - params.min) / (params.max - params.min)
    local curvedValue = normalizedValue ^ params.scaling
    -- Mouse drag logic
    local function updateValue(change, params, curvedValue, fineControl, delta)
        local visualCurvedValue = curvedValue + change
        visualCurvedValue = math.max(math.min(visualCurvedValue, 1), 0)
        local normalizedValue = visualCurvedValue ^ (1 / params.scaling)
        local newValue = params.min + normalizedValue * (params.max - params.min)
        return newValue, visualCurvedValue
    end

    local function updateValueSnapped(delta, speed, params, isWheel)
        local factor = 300
        local change = delta * speed * (params.max - params.min) / factor
        local newValue = value + change

        if params.applySnap and params.snapAmount and params.snapAmount > 0 then
            newValue = params.snapAmount * math.floor((newValue + params.snapAmount / 2) / params.snapAmount)
        end

        return math.max(math.min(newValue, params.max), params.min)
    end

    if reaper.ImGui_IsItemClicked(ctx, 0) then
        local x, y = reaper.GetMousePosition()
        dragStartPos[id] = { x = x, y = y }
    end

    if isActive then
        if os == "Win64" then
            reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_None())
            mouse_x, mouse_y = reaper.GetMousePosition()
            trackDeltaX = mouse_x - dragStartPos[id].x
            trackDeltaY = mouse_y - dragStartPos[id].y
            if reaper.JS_ReaScriptAPI_Version then
                reaper.JS_Mouse_SetPosition(dragStartPos[id].x, dragStartPos[id].y)
            end
        else
            trackDeltaX = mouse.delta_x
            trackDeltaY = mouse.delta_y
        end

        local delta = params.dragDirection == 'Horizontal' and trackDeltaX or -trackDeltaY
        if delta ~= 0.0 then
            local fineControl = (keys.shiftDown or keys.ctrlDown or keys.ctrlShiftDown or keys.ctrlAltDown or keys.ctrlAltShiftDown or keys.shiftAltDown)
            local change = (delta * (params.max - params.min) / overallSensitivity) * dragSensitivity
            if params.applySnap and not fineControl then
                value = updateValueSnapped(delta, dragSensitivity, params, false)
            else
                value, curvedValue = updateValue(change, params, curvedValue, fineControl, delta)
            end
            rv = true
        end
    end

    -- Mouse wheel logic
    if reaper.ImGui_IsItemHovered(ctx) and mouse.mousewheel_v ~= 0 then
        local fineControl = (keys.shiftDown or keys.ctrlDown or keys.ctrlShiftDown)
        local wheelChange = mouse.mousewheel_v * wheelSensitivity / 45
        value, curvedValue = updateValue(wheelChange, params, curvedValue, fineControl)
        rv = true
    end

    -- Double-click to reset
    if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
        value = params.default
        rv = true
    end

    -- Draw the knob
    local currentFrame = math.floor(curvedValue * (params.frameCount - 1)) + 1
    local uv0x = 0
    local uv0y = ((currentFrame - 1) * params.frameHeight) / imageParams.y
    local uv1x = params.frameWidth / imageParams.x
    local uv1y = uv0y + params.frameHeight / imageParams.y

    reaper.ImGui_Image(ctx, imageParams.i, params.frameWidth, params.frameHeight, uv0x, uv0y, uv1x, uv1y)

    -- Right-click menu
    if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsItemClicked(ctx, 1) then
        reaper.ImGui_OpenPopup(ctx, id)
    end

    if reaper.ImGui_BeginPopup(ctx, id, reaper.ImGui_WindowFlags_NoMove()) then
        value, rv = obj_Knob_Menu(ctx, value)
    end

    if reaper.ImGui_IsItemHovered(ctx) or isActive then
        hoveredControlInfo.id = string.gsub(id, "%d", "")                    -- Remove the numeric part from the id
        hoveredControlInfo.id = string.gsub(hoveredControlInfo.id, "##", "") -- Remove the "##" prefix if it exists
        hoveredControlInfo.value = value
    end
    return rv, value
end

---- TRACK RELATED  ---------------------------------

local function create_or_find_track(target_track_name, num_child_tracks, track_suffix)
    local num_tracks = reaper.CountTracks(0)
    -- Search for the target track
    for i = 0, num_tracks - 1 do
        local track = reaper.GetTrack(0, i)
        local _, track_name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        if track_name == target_track_name then
            return track
        end
    end
    -- Create the target track if not found
    reaper.InsertTrackAtIndex(num_tracks, true)
    local target_track = reaper.GetTrack(0, num_tracks)
    reaper.GetSetMediaTrackInfo_String(target_track, "P_NAME", target_track_name, true)
    reaper.GetSetTrackGroupMembership(target_track, 'MEDIA_EDIT_LEAD', 1, 1)
    -- Create child tracks
    for i = 1, num_child_tracks do
        local child_track_name = tostring(i) .. track_suffix
        reaper.InsertTrackAtIndex(num_tracks + i, true)
        local child_track = reaper.GetTrack(0, num_tracks + i)
        reaper.GetSetMediaTrackInfo_String(child_track, "P_NAME", child_track_name, true)
        -- Set target track as the folder parent
        if i == 1 then
            reaper.SetMediaTrackInfo_Value(target_track, "I_FOLDERDEPTH", 1)
        end
        -- Close folder after the last child track
        if i == num_child_tracks then
            reaper.SetMediaTrackInfo_Value(child_track, "I_FOLDERDEPTH", -1)
        end
        reaper.GetSetTrackGroupMembership(child_track, 'MEDIA_EDIT_FOLLOW', 1, 1)
        -- Add Swing instance to the new track
        local fx_swing = reaper.TrackFX_AddByName(child_track, "Note Trigger", false, -1)
        local fx_swing = reaper.TrackFX_AddByName(child_track, "Swing", false, -1)
        reaper.TrackFX_Show(child_track, fx_swing, 2)
    end
    reaper.UpdateArrange()
    return target_track
end



local function findTrackByName(trackName)
    local numTracks = reaper.CountTracks(0)
    for i = 0, numTracks - 1 do
        local track = reaper.GetTrack(0, i)
        local _, currentName = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        if currentName == trackName then
            return track
        end
    end
    return nil
end

local function unselectNonSuffixedTracks()
    for i = 0, reaper.CountTracks(0) - 1 do
        local track = reaper.GetTrack(0, i)
        local _, trackName = reaper.GetTrackName(track, "")

        -- Unselect the track named "Patterns SEQ"
        if trackName == "Patterns SEQ" then
            reaper.SetTrackSelected(track, false)
            -- Select tracks that end with "SEQ" and are not named "Patterns SEQ"
        elseif trackName:sub(-3) == "SEQ" then
            -- reaper.SetTrackSelected(track, true)
            -- Unselect all other tracks
        else
            reaper.SetTrackSelected(track, false)
        end
    end
end

local function selectAllSuffixedTracks()
    for i = 0, reaper.CountTracks(0) - 1 do
        local track = reaper.GetTrack(0, i)
        local _, trackName = reaper.GetTrackName(track, "")

        -- Unselect the track named "Patterns SEQ"
        if trackName == "Patterns SEQ" then
            reaper.SetTrackSelected(track, false)
            -- Select tracks that end with "SEQ" and are not named "Patterns SEQ"
        elseif trackName:sub(-3) == "SEQ" then
            reaper.SetTrackSelected(track, true)
            -- Unselect all other tracks
        else
            reaper.SetTrackSelected(track, false)
        end
    end
end

local function toggleSelectTracksEndingWithSEQ(justSelect)
    for i = 0, reaper.CountTracks(0) - 1 do
        local track = reaper.GetTrack(0, i)
        local _, trackName = reaper.GetTrackName(track, "")
        if trackName:sub(-3) == "SEQ" and trackName ~= "Patterns SEQ" then
            local isSelected = reaper.IsTrackSelected(track)
            if not justSelect then
                reaper.SetTrackSelected(track, not isSelected)
            else
                reaper.SetTrackSelected(track, true)
            end
            -- reaper.SetTrackSelected(track, not isSelected)
        end
    end
end

local function track_name_exists(name)
    local num_tracks = reaper.CountTracks(0)
    for i = 0, num_tracks - 1 do
        local track = reaper.GetTrack(0, i)
        local _, track_name = reaper.GetTrackName(track, "")
        if track_name == name then
            return true
        end
    end
    return false
end

local function unselectAllTracks()
    local track_count = reaper.CountTracks(0)
    for i = 0, track_count - 1 do
        local track = reaper.GetTrack(0, i)
        reaper.SetTrackSelected(track, false)
    end
end

local function selectOnlyTrack(track)
    unselectAllTracks()
    local track_to_select = reaper.GetTrack(0, track)
    if track_to_select ~= nil then
        reaper.SetTrackSelected(track_to_select, true)
    end
end

local function moveTracksUpWithinFolders()
    local countSelTracks = reaper.CountSelectedTracks(0)
    if countSelTracks == 0 then return end

    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock()

    for i = 0, countSelTracks - 1 do
        local track = reaper.GetSelectedTrack(0, i)
        local trackNum = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")

        if trackNum > 1 then
            local prevTrack = reaper.GetTrack(0, trackNum - 2)
            local trackDepth = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")
            local prevTrackDepth = reaper.GetMediaTrackInfo_Value(prevTrack, "I_FOLDERDEPTH")

            -- Convert trackDepth to 0 if it is a negative number
            local trackDepth = math.max(trackDepth, 0)
            local prevTrackDepth = math.max(prevTrackDepth, 0)

            -- Check if the previous track is at the same depth (indicating the same folder level)
            if prevTrackDepth == trackDepth then
                reaper.ReorderSelectedTracks(trackNum - 2, 0)
            end
        end
    end

    reaper.Undo_EndBlock("Move selected tracks up within their folders", -1)
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
end

local function moveTracksDownWithinFolders()
    local countSelTracks = reaper.CountSelectedTracks(0)
    if countSelTracks == 0 then return end

    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock()

    -- Iterate backwards to avoid changing the indices of tracks we haven't processed yet
    for i = countSelTracks - 1, 0, -1 do
        local track = reaper.GetSelectedTrack(0, i)
        local trackNum = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
        local trackDepth = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")

        if trackNum < reaper.CountTracks(0) then
            local nextTrack = reaper.GetTrack(0, trackNum)     -- Get next track (tracks are 0-indexed)
            local nextTrackDepth = reaper.GetMediaTrackInfo_Value(nextTrack, "I_FOLDERDEPTH")
            local nextTrackDepth = math.max(nextTrackDepth, 0) -- Convert nextTrackDepth to 0 if it is a negative number

            -- Check if the next track is at the same depth
            if nextTrackDepth == trackDepth then
                reaper.ReorderSelectedTracks(trackNum + 1, 2) -- move down
            end
        end
    end

    reaper.Undo_EndBlock("Move selected tracks down within their folders", -1)
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
end


local function enumerateTrack(v)
    local track_count = reaper.CountTracks(0)
    local highest_suffix = 0

    -- Extract base name without the numeric suffix and SEQ, only if it follows an underscore
    local _, track_name = reaper.GetSetMediaTrackInfo_String(v, "P_NAME", "", false)
    local base_name, current_num_suffix = track_name:match("^(.-)_(%d+)%s?" .. track_suffix .. "$")
    base_name = base_name or track_name:match("^(.-)%s?" .. track_suffix .. "$") or track_name
    current_num_suffix = tonumber(current_num_suffix)

    -- Iterate through all tracks to find the highest suffix for the base name
    for i = 0, track_count - 1 do
        local track = reaper.GetTrack(0, i)
        local _, other_track_name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        local other_base_name, num_suffix = other_track_name:match("^(.-)_(%d+)%s?" .. track_suffix .. "$")
        other_base_name = other_base_name or other_track_name:match("^(.-)%s?" .. track_suffix .. "$")
        num_suffix = tonumber(num_suffix) or 0

        if other_base_name == base_name and (not current_num_suffix or num_suffix > 0) then
            highest_suffix = math.max(highest_suffix, num_suffix)
        end
    end

    -- Construct the new track name with enumeration before the suffix
    local new_track_name = base_name
    if highest_suffix >= 0 then
        new_track_name = new_track_name .. "_" .. tostring(highest_suffix + 1)
    end
    new_track_name = new_track_name .. "" .. track_suffix

    reaper.GetSetMediaTrackInfo_String(v, "P_NAME", new_track_name, true)
end

local function trackNameEndsWith(track, suffix)
    retval, trackName = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    return retval and trackName:sub(-#suffix) == suffix
end

local function goToNextTrack(shiftDown)
    local countSelTracks = reaper.CountSelectedTracks(0)
    if countSelTracks == 0 then return end

    for i = 0, countSelTracks - 1 do
        local track = reaper.GetSelectedTrack(0, i)
        if track then
            local trackNum = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")

            while true do
                local nextTrack = reaper.GetTrack(0, trackNum)
                if not nextTrack then break end

                if trackNameEndsWith(nextTrack, track_suffix) then
                    if not shiftDown then
                        unselectAllTracks()
                    end

                    reaper.SetTrackSelected(nextTrack, true)
                    break
                end

                trackNum = trackNum + 1
            end
        end
    end
end

local function goToPreviousTrack(shiftDown)
    local countSelTracks = reaper.CountSelectedTracks(0)
    if countSelTracks == 0 then return end

    for i = 0, countSelTracks - 1 do
        local track = reaper.GetSelectedTrack(0, i)
        if track then
            local trackNum = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 2

            while trackNum >= 0 do
                local prevTrack = reaper.GetTrack(0, trackNum)
                if not prevTrack then break end

                if trackNameEndsWith(prevTrack, track_suffix) then
                    if not shiftDown then
                        unselectAllTracks()
                    end
                    reaper.SetTrackSelected(prevTrack, true)
                    break
                end

                trackNum = trackNum - 1
            end
        end
    end
end

---- ITEM  RELATED  ---------------------------------

local function unselectAllMediaItems()
    local itemCount = reaper.CountMediaItems(0)

    for i = 0, itemCount - 1 do
        local item = reaper.GetMediaItem(0, i)
        reaper.SetMediaItemSelected(item, false)
    end
end

local function findOrCreateMIDIItem(track, start_time, end_time)
    local itemCount = reaper.CountTrackMediaItems(track)
    for i = 0, itemCount - 1 do
        local item = reaper.GetTrackMediaItem(track, i)
        local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local item_end = item_start + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

        -- Use nearlyEqual for fuzzy comparison of start and end times
        if nearlyEqual(item_start, start_time, float_epsilon) and nearlyEqual(item_end, end_time, float_epsilon) then
            return item -- Return existing item
        end
    end
    -- Create new MIDI item if none found
    return reaper.CreateNewMIDIItemInProj(track, start_time, end_time, false)
end


local function findAndSelectLastItemOnTrack(trackName)
    local trackCount = reaper.CountTracks(0)
    local foundTrack = nil

    for i = 0, trackCount - 1 do
        local track = reaper.GetTrack(0, i)
        local _, currentTrackName = reaper.GetTrackName(track, "")
        if currentTrackName == trackName then
            foundTrack = track
            break
        end
    end

    if not foundTrack then
        return
    end

    local item_count = reaper.CountTrackMediaItems(foundTrack)
    local lastItem = nil
    local latestTime = -1

    for i = 0, item_count - 1 do
        local item = reaper.GetTrackMediaItem(foundTrack, i)
        local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        if item_start > latestTime then
            latestTime = item_start
            lastItem = item
        end
    end

    if lastItem then
        unselectAllMediaItems()
        reaper.SetMediaItemSelected(lastItem, true)
        reaper.Main_OnCommand(40913, 0) -- Scroll view to selected items
    end
end

local function deleteUnwantedSelectedItems(exceptItem)
    -- Create a list of items to be deleted
    local itemsToDelete = {}
    for i = reaper.CountSelectedMediaItems(0) - 1, 0, -1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        if item ~= exceptItem then
            table.insert(itemsToDelete, item)
        end
    end

    -- Deselect all items
    reaper.Main_OnCommand(40289, 0) -- Unselect all items

    -- Select items to delete
    for _, item in ipairs(itemsToDelete) do
        reaper.SetMediaItemSelected(item, true)
    end

    -- Delete the selected items
    if #itemsToDelete > 0 then
        reaper.Main_OnCommand(40006, 0) -- Delete selected items
    end
end
---- PATTERN ITEMS  ---------------------------------

local function getPatternItems(track_count)
    local patternItems = {}
    local trackNameToMatch = "Patterns" .. track_suffix
    local patternTrackIndex = nil
    local patternTrack = nil
    local maxPatternNumber = 0  -- Variable to track the highest pattern number

    for i = 0, track_count - 1 do
        local track = reaper.GetTrack(0, i)
        local _, trackName = reaper.GetTrackName(track)

        if trackName == trackNameToMatch then
            patternTrackIndex = i
            patternTrack = track
            local itemCount = reaper.CountTrackMediaItems(track)

            for j = 0, itemCount - 1 do
                local item = reaper.GetTrackMediaItem(track, j)
                local take = reaper.GetActiveTake(item)
                local _, itemName = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
                local patternNumber = tonumber(itemName:match("^Pattern (%d+)"))

                if patternNumber then
                    -- Update maxPatternNumber if a higher number is found
                    if patternNumber > maxPatternNumber then
                        maxPatternNumber = patternNumber
                    end

                    if not patternItems[patternNumber] then
                        patternItems[patternNumber] = {}
                    end
                    table.insert(patternItems[patternNumber], item)
                end
            end
        end
    end

    return patternItems, patternTrackIndex, patternTrack, maxPatternNumber
end

local function getSelectedPatternItemAndMidiItem(trackIndex, patternItems, patternSelectSlider)
    local selectedPatternData = patternItems[patternSelectSlider]
    if not (selectedPatternData and selectedPatternData[1]) then
        return
    end

    local pattern_item = selectedPatternData[1]
    local pattern_start = reaper.GetMediaItemInfo_Value(pattern_item, "D_POSITION")
    local pattern_length = reaper.GetMediaItemInfo_Value(pattern_item, "D_LENGTH")
    local pattern_end = pattern_start + pattern_length

    buttonStates[trackIndex] = {}
    local track = reaper.GetTrack(0, trackIndex)
    if not track then
        return
    end

    local itemCount = reaper.CountTrackMediaItems(track)
    for i = 0, itemCount - 1 do
        local item = reaper.GetTrackMediaItem(track, i)
        local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        -- If item starts after pattern ends, no need to continue checking further items
        if nearlyEqual(item_start, pattern_end, float_epsilon) or item_start > pattern_end then
            break
        end

        local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        local item_end = item_start + item_length

        if nearlyEqual(item_start, pattern_start, float_epsilon) and nearlyEqual(item_end, pattern_end, float_epsilon) then
            local take = reaper.GetMediaItemTake(item, 0)
            if reaper.TakeIsMIDI(take) then
                return pattern_item, pattern_start, pattern_end, item, track
            end
        end
    end

    return pattern_item, pattern_start, pattern_end, nil, track
end


local function create_pattern_item_if_not_exist(track_suffix)
    local track_name = "Patterns" .. track_suffix
    local num_tracks = reaper.CountTracks(0)
    local patterns_track = nil

    -- Search for the track with the specified name
    for i = 0, num_tracks - 1 do
        local track = reaper.GetTrack(0, i)
        local _, current_track_name = reaper.GetTrackName(track, "")
        if current_track_name == track_name then
            patterns_track = track
            break
        end
    end

    if not patterns_track then
        return
    end

    local item_found = false
    local num_items = reaper.CountTrackMediaItems(patterns_track)

    -- Check if there's any item starting with the word "Pattern"
    for i = 0, num_items - 1 do
        local item = reaper.GetTrackMediaItem(patterns_track, i)
        local take = reaper.GetMediaItemTake(item, 0)
        local _, item_name = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
        if item_name:match("^Pattern") then
            item_found = true
            break
        end
    end

    -- If no item found, create an empty MIDI item named "Patterns 1"
    if not item_found then
        local loop_start, loop_end = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
        local item_length = loop_end - loop_start > 0 and loop_end - loop_start
            or 8 * reaper.TimeMap2_beatsToTime(0, 1)
        local new_item = reaper.CreateNewMIDIItemInProj(patterns_track, loop_start, loop_start + item_length, false)
        local new_take = reaper.GetMediaItemTake(new_item, 0)
        reaper.GetSetMediaItemTakeInfo_String(new_take, "P_NAME", "Pattern 1", true)
    end
end

local function getItemsByPattern(track)
    local track = parent.GUID[0]
    if not track or not reaper.ValidatePtr(track, "MediaTrack*") then
        return nil
    end
    if track then
        local numItems = reaper.CountTrackMediaItems(track)
        local itemsByPattern = {}

        for i = 0, numItems - 1 do
            local item = reaper.GetTrackMediaItem(track, i)
            if item then
                local take = reaper.GetActiveTake(item)
                if take then
                    local _, itemName = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
                    local patternNumber = itemName:match("^Pattern (%d+)")
                    if patternNumber then
                        patternNumber = tonumber(patternNumber)
                        if not itemsByPattern[patternNumber] then
                            itemsByPattern[patternNumber] = {}
                        end
                        itemsByPattern[patternNumber][#itemsByPattern[patternNumber] + 1] = item
                    end
                end
            end
        end
        return itemsByPattern
    end
end



local function getNextPatternNumber(track)
    local patternNumbers = {}
    local itemCount = reaper.CountTrackMediaItems(track)

    -- Gather all existing pattern numbers
    for i = 0, itemCount - 1 do
        local item = reaper.GetTrackMediaItem(track, i)
        local take = reaper.GetActiveTake(item)
        if take then
            local _, name = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
            local number = name:match("Pattern (%d+)")
            if number then
                patternNumbers[tonumber(number)] = true
            end
        end
    end

    -- Find the next available highest number
    local nextNum = 1
    while patternNumbers[nextNum] do
        nextNum = nextNum + 1
    end

    return nextNum
end

local function newPatternItem(maxPatternNumber)
    reaper.PreventUIRefresh(1)
    local trackName = "Patterns SEQ"
    local patternsTrack = findTrackByName(trackName)

    if not patternsTrack then
        reaper.ShowMessageBox("Track '" .. trackName .. "' not found.", "Error", 0)
        return
    end

    reaper.Undo_BeginBlock()

    findAndSelectLastItemOnTrack("Patterns SEQ")

    local selectedItem = reaper.GetSelectedMediaItem(0, 0)
    if not selectedItem then
        reaper.ShowMessageBox("No item selected.", "Error", 0)
        return
    end

    local itemPosition = reaper.GetMediaItemInfo_Value(selectedItem, "D_POSITION")
    local itemLength = reaper.GetMediaItemInfo_Value(selectedItem, "D_LENGTH")

    -- Store the selected items (except the item to be duplicated)
    local selectedItems = {}
    for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        if item ~= selectedItem then
            table.insert(selectedItems, item)
        end
    end

    -- Duplicate the item
    reaper.Main_OnCommand(41295, 0) -- Duplicate items
    reaper.Main_OnCommand(41613, 0) -- remove pool

    -- -- Find the duplicate
    -- local newItem 
    -- local itemCount = reaper.CountTrackMediaItems(patternsTrack)
    -- for i = 0, itemCount - 1 do
    --     local item = reaper.GetTrackMediaItem(patternsTrack, i)
    --     local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    --     reaper.SetEditCurPos(pos, 0, 0)
    --     local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    --     if pos >= itemPosition and len == itemLength and item ~= selectedItem then
    --         newItem = item
    --         break
    --     end
    -- end


    local newItem = reaper.GetSelectedMediaItem(0, 0)
    
    -- print(newItem)

    if newItem then
        deleteUnwantedSelectedItems(newItem)

        -- Rename the new item
        local nextPatternNumber = getNextPatternNumber(patternsTrack)
        local take = reaper.GetActiveTake(newItem)
        if take then
            reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "Pattern " .. nextPatternNumber, true)
        end
        reaper.SetMediaItemSelected(newItem, true)
    else
        -- reaper.ShowMessageBox("Unable to identify the duplicated item.", "Error", 0)
    end

    patternSelectSlider = maxPatternNumber + 1
    update_required = true

    reaper.Undo_EndBlock("Duplicate and rename pattern", -1)
    reaper.UpdateArrange()
    reaper.PreventUIRefresh(-1)
end

---- MIDI RELATED  ---------------------------------
local function triggerSlider(start, track)
    local paramValue = start and 1 or 0
    if track then
        local note_triggerindex = -1
        for fx_index = 0, reaper.TrackFX_GetCount(track) - 1 do
            local _, fx_name = reaper.TrackFX_GetFXName(track, fx_index, "")
            if fx_name:find("JS: Note Trigger") then
                note_triggerindex = fx_index
                break
            end
        end
        if note_triggerindex ~= -1 then
            reaper.TrackFX_SetParamNormalized(track, note_triggerindex, 0, paramValue)
        end
    else

        local numSelectedTracks = reaper.CountSelectedTracks(0)
        for i = 0, numSelectedTracks - 1 do
            local track = reaper.GetSelectedTrack(0, i)
            if track then
                local note_triggerindex = -1
                for fx_index = 0, reaper.TrackFX_GetCount(track) - 1 do
                    local _, fx_name = reaper.TrackFX_GetFXName(track, fx_index, "")
                    if fx_name:find("JS: Note Trigger") then
                        note_triggerindex = fx_index
                        break
                    end
                end
                if note_triggerindex ~= -1 then
                    reaper.TrackFX_SetParamNormalized(track, note_triggerindex, 0, paramValue)
                end
            end
        end
    end
end

local function triggerSliderWithQKey(ctx)
    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Q()) and not sliderTriggered then
        triggerSlider(true)
        sliderTriggered = true
        triggerTime = reaper.time_precise()
    elseif sliderTriggered and (reaper.time_precise() - triggerTime) > triggerDuration then
        triggerSlider(false)
        sliderTriggered = false
    end
end

---- STEP SEQUENCER BASIC FUNCTIONALITY  ---------------------------------

local function populateNotePositions(midi_item)
    if not midi_item then return {}, {}, {} end

    local take = reaper.GetMediaItemTake(midi_item, 0)
    if not take or not reaper.TakeIsMIDI(take) then return {}, {}, {} end

    local note_count, _, _ = reaper.MIDI_CountEvts(take)
    local note_positions = {}
    local note_velocities = {}
    local note_pitches = {}

    for i = 0, note_count - 1 do
        local _, _, _, start_ppq, _, _, pitch, velocity = reaper.MIDI_GetNote(take, i)
        note_positions[i + 1] = reaper.MIDI_GetProjTimeFromPPQPos(take, start_ppq)
        note_velocities[i + 1] = velocity
        note_pitches[i + 1] = pitch
    end

    return note_positions, note_velocities, note_pitches
end



local function insertMidiNote(trackIndex, buttonIndex, pitch, velocity, note_length, patternSelectSlider, startTime,
                              endTime, track_count)
    local track = reaper.GetTrack(0, trackIndex)
    local item_start = reaper.GetMediaItemInfo_Value(getPatternItems(track_count)[patternSelectSlider][1], "D_POSITION")
    local beatsInSec = reaper.TimeMap2_beatsToTime(0, 1)
    local item_length_secs = lengthSlider * beatsInSec / time_resolution
    local item_end = item_start + item_length_secs
    local note_position = item_start + (buttonIndex - 1) * beatsInSec / time_resolution
    local itemCount = reaper.CountTrackMediaItems(track)
    local midi_item


    for i = 0, itemCount - 1 do
        local item = reaper.GetTrackMediaItem(track, i)
        local itemPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local itemLength = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

        if itemPos <= note_position and note_position < (itemPos + itemLength) then
            midi_item = item
            break
        end
    end

    if not midi_item then
        midi_item = reaper.CreateNewMIDIItemInProj(track, item_start, item_end, false)
    end

    local take = reaper.GetMediaItemTake(midi_item, 0)
    if not reaper.ValidatePtr(take, "MediaItem_Take*") then
        reaper.ShowMessageBox("Failed to get MIDI take.", "Error", 0)
        return
    end

    if not reaper.TakeIsMIDI(take) then
        reaper.ShowMessageBox("The item is not a MIDI item.", "Error", 0)
        return
    end

    local note_ppq_position = reaper.MIDI_GetPPQPosFromProjTime(take, note_position)
    local bpm = reaper.TimeMap_GetDividedBpmAtTime(note_position)
    local beat_length_secs = 60 / bpm
    local sixteenth_note_length_secs = beat_length_secs / 8
    local note_end_time = note_position + sixteenth_note_length_secs
    local note_end_ppq_position = reaper.MIDI_GetPPQPosFromProjTime(take, note_end_time)

    reaper.MIDI_InsertNote(take, false, false, note_ppq_position, note_end_ppq_position, 0, pitch, velocity, false)

    reaper.UpdateArrange()
end
local function insertMidiPooledItems(trackIndex, patternSelectSlider, patternItems, createNew)
    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)
    local cursor_pos = reaper.GetCursorPosition()
    -- Retrieve the pattern items for the selected pattern
    local patternMediaItems = patternItems[patternSelectSlider]

    -- Get the track at the specified index
    local targetTrack = reaper.GetTrack(0, trackIndex) -- Track index is 0-based

    if createNew == true then
        local itemStart = reaper.GetMediaItemInfo_Value(patternMediaItems[1], "D_POSITION")
        local itemEnd = itemStart + reaper.GetMediaItemInfo_Value(patternMediaItems[1], "D_LENGTH")
        reaper.CreateNewMIDIItemInProj(targetTrack, itemStart, itemEnd, false)
    end

    for _, patternItem in ipairs(patternMediaItems) do
        -- Get the start and end times for the pattern item
        local itemStart = reaper.GetMediaItemInfo_Value(patternItem, "D_POSITION")
        local itemEnd = itemStart + reaper.GetMediaItemInfo_Value(patternItem, "D_LENGTH")

        -- Check for existing MIDI items on the target track that overlap with the current pattern item
        local existingMidiItemFound = false
        for i = 0, reaper.CountTrackMediaItems(targetTrack) - 1 do
            local item = reaper.GetTrackMediaItem(targetTrack, i)
            local midiItemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local midiItemEnd = midiItemStart + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

            -- Check if the MIDI item overlaps with the pattern item
            if nearlyEqual(midiItemStart, itemStart) and nearlyEqual(midiItemEnd, itemEnd) then
                existingMidiItemFound = true
                reaper.Main_OnCommand(40289, 0) -- unselect all items

                reaper.SetMediaItemSelected(item, 1)
                reaper.Main_OnCommand(40698, 0) -- copy item

                break
            end
        end

        -- If no existing MIDI item overlaps, create a new one
        if not existingMidiItemFound then
            reaper.SetOnlyTrackSelected(targetTrack)
            reaper.SetEditCurPos(itemStart, false, false)
            reaper.Main_OnCommand(41072, 0) -- paste item pooled
        end
    end
    reaper.SetEditCurPos(cursor_pos, false, false)
    reaper.PreventUIRefresh(-1)
    reaper.Undo_EndBlock('Insert MIDI Notes', -1)
end

local function deleteMidiNotesInArea(take, startPPQ, endPPQ)


    local _, note_count = reaper.MIDI_CountEvts(take)
    local notes_deleted = false
    for i = note_count - 1, 0, -1 do
        local _, _, _, note_start_ppq, _, _, _, _ = reaper.MIDI_GetNote(take, i)
        if note_start_ppq >= startPPQ and note_start_ppq < endPPQ then
            reaper.MIDI_DeleteNote(take, i)
            notes_deleted = true
        end
    end
    
    if notes_deleted then
        reaper.MIDI_Sort(take)
    end
end

local function deleteMidiNote(trackIndex, buttonIndex, patternSelectSlider, patternItems)
    local track = reaper.GetTrack(0, trackIndex)
    if not track then return end

    local item_start = reaper.GetMediaItemInfo_Value(patternItems[patternSelectSlider][1], "D_POSITION")
    local beatsInSec = reaper.TimeMap2_beatsToTime(0, 1)
    local note_position = item_start + (buttonIndex - 1) * beatsInSec / time_resolution
    local tolerance = beatsInSec / (time_resolution * 2)
    local startTime = note_position - tolerance
    local endTime = note_position + tolerance

    for i = 0, reaper.CountTrackMediaItems(track) - 1 do
        local item = reaper.GetTrackMediaItem(track, i)
        local itemPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local itemLength = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        if itemPos <= note_position and note_position < (itemPos + itemLength) then
            local take = reaper.GetMediaItemTake(item, 0)
            if reaper.ValidatePtr(take, "MediaItem_Take*") and reaper.TakeIsMIDI(take) then
                local _, note_count = reaper.MIDI_CountEvts(take)
                local startPPQ = reaper.MIDI_GetPPQPosFromProjTime(take, startTime)
                local endPPQ = reaper.MIDI_GetPPQPosFromProjTime(take, endTime)

                for i = note_count - 1, 0, -1 do
                    local _, _, _, note_start_ppq, _, _, _, _ = reaper.MIDI_GetNote(take, i)
                    if note_start_ppq >= startPPQ and note_start_ppq < endPPQ then
                        reaper.MIDI_DeleteNote(take, i)
                        break -- Assuming only one note needs to be deleted within this range
                    end
                end
                reaper.MIDI_Sort(take)
                reaper.UpdateArrange()
                break -- Exit the loop once the MIDI item is processed
            end
        end
    end
end


local function undoPoint(text, track, item)
    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock()
    if not item then return end
    if not track then return end
    reaper.MarkTrackItemsDirty(track, item)
    reaper.Undo_EndBlock(text, -1)
    reaper.PreventUIRefresh(-1)
end

local function undoPoint2(text)
    local track = reaper.GetSelectedTrack(0, 0)
    if track then
        local item = reaper.GetTrackMediaItem(track, 0)
        reaper.PreventUIRefresh(1)
        reaper.Undo_BeginBlock()
        if not item then return end
        if not track then return end
        reaper.MarkTrackItemsDirty(track, item)
        reaper.Undo_EndBlock(text, -1)
        reaper.PreventUIRefresh(-1)
    end
end

---- STEP SEQUENCER ADDITIONAL FUNCTIONALITY  ---------------------------------


local function openMidiEditor(trackIndex, patternItems)
    -- reaper.Undo_BeginBlock()
    local track = reaper.GetTrack(0, trackIndex)
    if track then
        -- Get the selected pattern item based on the patternSelectSlider
        if not (patternItems and patternItems[patternSelectSlider] and patternItems[patternSelectSlider][1]) then
            -- insertMidiPooledItems(trackIndex, patternSelectSlider, patternItems, true)
            return
        end
        local pattern_item = patternItems[patternSelectSlider][1]
        local pattern_start = reaper.GetMediaItemInfo_Value(pattern_item, "D_POSITION")
        local pattern_end = pattern_start + reaper.GetMediaItemInfo_Value(pattern_item, "D_LENGTH")
        reaper.SetOnlyTrackSelected(track)
        local item_count = reaper.CountTrackMediaItems(track)
        unselectAllMediaItems()
        for i = 0, item_count - 1 do
            local item = reaper.GetTrackMediaItem(track, i)
            local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local item_end = item_start + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
            -- Check if the item falls within the pattern item range
            if item and item_start >= pattern_start and item_end <= pattern_end then
                reaper.SetMediaItemSelected(item, true) -- Select the media item
            end
        end
    end
    local track = reaper.GetTrack(0, trackIndex)
    if track then
        local item_count = reaper.CountTrackMediaItems(track)
        for i = 0, item_count - 1 do
            local item = reaper.GetTrackMediaItem(track, i)
            local take = reaper.GetMediaItemTake(item, 0) -- Get the active take of the media item
            if item and take and reaper.TakeIsMIDI(take) and reaper.IsMediaItemSelected(item) then
                reaper.Main_OnCommand(40153, 0)           -- Open in MIDI Editor
                break
            end
        end
    end
end

local function cloneDuplicateTrack(trackIndex, dropPosition)
    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock()

    reaper.Main_OnCommand(40062, 0) -- duplicate tracks
    local duplicated_tracks = {}
    local track_count = reaper.CountSelectedTracks(0)
    for i = 0, track_count - 1 do
        local track = reaper.GetSelectedTrack(0, i)
        table.insert(duplicated_tracks, track)
    end

    for k, v in pairs(duplicated_tracks) do
        local originalTrackIndex = reaper.GetMediaTrackInfo_Value(v, "IP_TRACKNUMBER") - 1

        -- Select the original track
        local originalTrack = reaper.GetTrack(0, originalTrackIndex)
        if not originalTrack then
            return
        end

        enumerateTrack(v)
        -- Process the duplicated track
        local itemCount = reaper.CountTrackMediaItems(v)
        local pools = {}

        -- Identify the first item in each pool and collect other items
        for i = 0, itemCount - 1 do
            local item = reaper.GetTrackMediaItem(v, i)
            local take = reaper.GetActiveTake(item)
            if take and reaper.TakeIsMIDI(take) then
                _, chunk = reaper.GetItemStateChunk(item, "", false)
                local pooledGUID = chunk:match("POOLEDEVTS {(.-)}")
                if pooledGUID then
                    if not pools[pooledGUID] then
                        pools[pooledGUID] = { firstItem = item, otherItems = {} }
                    else
                        table.insert(pools[pooledGUID].otherItems, item)
                    end
                end
            end
        end

        -- Process each pool
        for pooledGUID, pool in pairs(pools) do
            local firstItem = pool.firstItem
            local otherItems = pool.otherItems
            local otherItemPositions = {}

            -- Get positions of other items
            for _, item in ipairs(otherItems) do
                local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                table.insert(otherItemPositions, itemStart)
            end

            -- Delete other items in the pool
            for _, item in ipairs(otherItems) do
                reaper.DeleteTrackMediaItem(v, item)
            end

            -- Unselect all items, then select and copy the first item
            reaper.SetOnlyTrackSelected(v)
            reaper.SelectAllMediaItems(0, false)
            reaper.SetMediaItemSelected(firstItem, true)
            reaper.Main_OnCommand(41613, 0) -- Item: Remove active take from MIDI source data pool (unpool)
            reaper.Main_OnCommand(40698, 0) -- Copy items

            -- Delete and paste items at original positions
            for _, pos in ipairs(otherItemPositions) do
                reaper.SetEditCurPos(pos, false, false)
                reaper.Main_OnCommand(41072, 0) -- Paste item pooled
            end

            reaper.SetMediaItemSelected(firstItem, false)
        end
    end

    -- -- Move the duplicated tracks to the dropped position
    -- for _, track in ipairs(duplicated_tracks) do
    --     reaper.SetOnlyTrackSelected(track)
    --     if dropPosition == "above" then
    --         reaper.ReorderSelectedTracks(trackIndex + 1, 0)
    --     else
    --         reaper.ReorderSelectedTracks(trackIndex + 2, 0)
    --     end
    -- end

    selectedChannelButton = trackIndex + 1
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    reaper.Undo_EndBlock('Clone/Duplicate Track', -1)
    update_required = true
end


local function deleteTrack(trackIndex, track_suffix)
    reaper.Undo_BeginBlock()

    local count_tracks = reaper.CountSelectedTracks(0)
    local total_tracks = reaper.CountTracks(0)
    local seq_track_count = 0
    local last_seq_track_index = -1

    for i = 0, total_tracks - 1 do
        local track = reaper.GetTrack(0, i)
        local _, track_name = reaper.GetTrackName(track, "")
    
        -- Check if the track name ends with "SEQ" and is not exactly "Patterns SEQ"
        if string.find(track_name, "SEQ" .. "$") and track_name ~= "Patterns SEQ" then
            seq_track_count = seq_track_count + 1
            last_seq_track_index = i
        end
    end

    -- Delete selected tracks but leave at least one SEQ track
    for i = count_tracks - 1, 0, -1 do
        local track = reaper.GetSelectedTrack(0, i)
        local _, track_name = reaper.GetTrackName(track, "")
        if track and (seq_track_count <= 1 and reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1 == last_seq_track_index) then

        else
            reaper.DeleteTrack(track)
            update_required = true
            -- Update SEQ track count if a SEQ track was deleted
            if string.find(track_name, "SEQ" .. "$") then
                seq_track_count = seq_track_count - 1
            end
        end
    end

    update_channel_data_from_reaper(track_suffix, total_tracks)
    reaper.Undo_EndBlock('Delete tracks', -1)
end

local function deleteAllMIDIFromChannel(trackIndex, patternSelectSlider, patternItems)
    local pattern_item, _, _, midi_item = getSelectedPatternItemAndMidiItem(trackIndex, patternItems, patternSelectSlider)
    if not midi_item then
        return
    end

    local take = reaper.GetMediaItemTake(midi_item, 0)
    if not reaper.ValidatePtr(take, "MediaItem_Take*") then
        reaper.ShowMessageBox("Failed to get MIDI take.", "Error", 0)
        return
    end

    if not reaper.TakeIsMIDI(take) then
        reaper.ShowMessageBox("The item is not a MIDI item.", "Error", 0)
        return
    end

    -- Get counts of each event type
    local note_count, cc_count, text_sysex_count = reaper.MIDI_CountEvts(take)

    -- Delete all notes
    for i = note_count - 1, 0, -1 do
        reaper.MIDI_DeleteNote(take, i)
    end

    -- Delete all CC events
    for i = cc_count - 1, 0, -1 do
        reaper.MIDI_DeleteCC(take, i)
    end

    -- Delete all Text/Sysex events
    for i = text_sysex_count - 1, 0, -1 do
        reaper.MIDI_DeleteTextSysexEvt(take, i)
    end

    reaper.UpdateArrange()
end

-- Shift Notes
local function shiftNotes(direction, patternItems, patternSelectSlider)
    local selTrackCount = reaper.CountSelectedTracks(0)
    for ti = 0, selTrackCount - 1 do
        local track = reaper.GetSelectedTrack(0, ti)
        local trackIndex = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1
        local pattern_item, pattern_start, pattern_end, midi_item = getSelectedPatternItemAndMidiItem(trackIndex,
            patternItems, patternSelectSlider)
        if not midi_item then
            return
        end

        local take = reaper.GetActiveTake(midi_item)
        if not reaper.ValidatePtr(take, "MediaItem_Take*") then
            reaper.ShowMessageBox("Failed to get MIDI take.", "Error", 0)
            return
        end

        local _, note_count = reaper.MIDI_CountEvts(take)
        local pattern_start_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, pattern_start)
        local pattern_end_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, pattern_end)
        local step_size = reaper.TimeMap2_beatsToTime(0, 1) / time_resolution
        local step_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, pattern_start + step_size) - pattern_start_ppq
        local shift_ppq = direction * step_ppq

        -- Collect notes to shift
        local shiftedNotes = {}
        for i = 0, note_count - 1 do
            local _, _, _, start_ppq, end_ppq, _, pitch, vel = reaper.MIDI_GetNote(take, i)
            local new_start_ppq = start_ppq + shift_ppq
            local new_end_ppq = end_ppq + shift_ppq

            -- Adjust for wrapping around the pattern
            if new_start_ppq < pattern_start_ppq then
                new_start_ppq = new_start_ppq + (pattern_end_ppq - pattern_start_ppq)
                new_end_ppq = new_end_ppq + (pattern_end_ppq - pattern_start_ppq)
            elseif new_start_ppq >= pattern_end_ppq then
                new_start_ppq = new_start_ppq - (pattern_end_ppq - pattern_start_ppq)
                new_end_ppq = new_end_ppq - (pattern_end_ppq - pattern_start_ppq)
            end

            table.insert(shiftedNotes, { new_start_ppq, new_end_ppq, pitch, vel })
        end

        -- Delete all existing notes and insert shifted notes
        reaper.MIDI_DisableSort(take)
        for i = note_count - 1, 0, -1 do
            reaper.MIDI_DeleteNote(take, i)
        end

        for _, note in ipairs(shiftedNotes) do
            local start_ppq, end_ppq, pitch, vel = table.unpack(note)
            reaper.MIDI_InsertNote(take, false, false, start_ppq, end_ppq, 0, pitch, vel, false)
        end

        reaper.MIDI_Sort(take)
    end
    update_required = true
    reaper.UpdateArrange()
end

local function copyChannelData(trackIndex, patternSelectSlider, patternItems)
    local trackData = {}

    -- Get the selected pattern item and its start and end positions
    local pattern_item, pattern_start, pattern_end = getSelectedPatternItemAndMidiItem(trackIndex, patternItems,
        patternSelectSlider)
    if not pattern_item then
        reaper.ShowConsoleMsg("No pattern item selected.\n")
        return nil
    end

    local track = reaper.GetTrack(0, trackIndex)
    if not track then
        reaper.ShowConsoleMsg("Track not found.\n")
        return nil
    end

    local itemCount = reaper.CountTrackMediaItems(track)
    if itemCount == 0 then
        -- reaper.ShowConsoleMsg("No items in track.\n")
        return trackData
    end

    for i = 0, itemCount - 1 do
        local item = reaper.GetTrackMediaItem(track, i)
        local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local itemEnd = itemStart + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

        -- Only process items within the selected pattern's time range
        if itemStart >= pattern_start and itemEnd <= pattern_end then
            local take = reaper.GetMediaItemTake(item, 0)
            if reaper.ValidatePtr(take, "MediaItem_Take*") and reaper.TakeIsMIDI(take) then
                local noteCount, _, _ = reaper.MIDI_CountEvts(take)
                for j = 0, noteCount - 1 do
                    local _, selected, _, startPPQ, endPPQ, channel, pitch, velocity = reaper.MIDI_GetNote(take, j)
                    local noteData = { startPPQ = startPPQ, endPPQ = endPPQ, channel = channel, pitch = pitch, velocity =
                    velocity }
                    table.insert(trackData, noteData)
                end
            end
        end
    end

    return trackData
end

local function pasteChannelDataToSelectedTracks(patternItems, patternSelectSlider)
    if #clipboard == 0 then
        -- reaper.ShowConsoleMsg("Clipboard is empty.\n")
        return
    end

    reaper.Undo_BeginBlock()
    local selTrackCount = reaper.CountSelectedTracks(0)

    if selTrackCount > 0 then
        local firstSelTrack = reaper.GetSelectedTrack(0, 0)
        local firstSelTrackIndex = reaper.GetMediaTrackInfo_Value(firstSelTrack, "IP_TRACKNUMBER") - 1
        local totalTracks = reaper.CountTracks(0)

        -- Calculate the number of tracks to process
        local numTracksToProcess = math.max(selTrackCount, #clipboard)

        -- Loop through and select tracks, then paste MIDI data
        for i = 0, numTracksToProcess - 1 do
            local targetTrackIndex = firstSelTrackIndex + i
            if targetTrackIndex < totalTracks then
                local track = reaper.GetTrack(0, targetTrackIndex)
                if track then
                    reaper.SetTrackSelected(track, true)

                    local clipboardIndex = (i % #clipboard) + 1
                    local noteDataList = clipboard[clipboardIndex]

                    -- Paste the MIDI data to each track
                    local pattern_item, pattern_start, pattern_end = getSelectedPatternItemAndMidiItem(targetTrackIndex,
                        patternItems, patternSelectSlider)
                    if pattern_item then
                        local item = findOrCreateMIDIItem(track, pattern_start, pattern_end)
                        local take = reaper.GetActiveTake(item)
                        if take and reaper.TakeIsMIDI(take) then
                            -- Clear existing notes
                            local _, noteCount, _ = reaper.MIDI_CountEvts(take)
                            for j = noteCount - 1, 0, -1 do
                                reaper.MIDI_DeleteNote(take, j)
                            end

                            -- Insert new notes
                            local itemStartPPQ = reaper.MIDI_GetPPQPosFromProjTime(take,
                                reaper.GetMediaItemInfo_Value(item, "D_POSITION"))
                            for _, noteData in ipairs(noteDataList) do
                                local relativeStartPPQ = noteData.startPPQ - itemStartPPQ
                                local relativeEndPPQ = noteData.endPPQ - itemStartPPQ
                                reaper.MIDI_InsertNote(
                                    take,
                                    false,
                                    false,
                                    relativeStartPPQ,
                                    relativeEndPPQ,
                                    noteData.channel,
                                    noteData.pitch,
                                    noteData.velocity
                                )
                            end
                            reaper.MarkTrackItemsDirty(track, item)
                            reaper.MIDI_Sort(take)
                        end
                    end
                end
            end
        end
    end

    reaper.Undo_EndBlock('Paste MIDI Notes', -1)
end


local function removeChannelData(trackIndex, patternSelectSlider, patternItems)
    local track = reaper.GetTrack(0, trackIndex)
    if not track then
        return
    end

    local pattern_item, pattern_start, pattern_end = getSelectedPatternItemAndMidiItem(trackIndex, patternItems,
        patternSelectSlider)
    if not pattern_item then
        reaper.ShowConsoleMsg("No pattern item selected.\n")
        return
    end

    local itemCount = reaper.CountTrackMediaItems(track)
    for i = 0, itemCount - 1 do
        local item = reaper.GetTrackMediaItem(track, i)
        local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local itemEnd = itemStart + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

        -- Only process items within the selected pattern's time range
        if itemStart >= pattern_start and itemEnd <= pattern_end then
            local take = reaper.GetMediaItemTake(item, 0)
            if reaper.ValidatePtr(take, "MediaItem_Take*") and reaper.TakeIsMIDI(take) then
                local noteCount, _, _ = reaper.MIDI_CountEvts(take)
                for j = noteCount - 1, 0, -1 do
                    reaper.MIDI_DeleteNote(take, j)
                end
            end
        end
    end
end


---- SLIDERS  ---------------------------------



local function OnMouseWheel(delta)
    -- Invert the direction of tension change
    tension = tension - delta * 1                  -- Adjust the scaling factor as needed
    tension = math.max(-10, math.min(tension, 10)) -- Clamp tension to prevent extreme curves
    return tension
end


local function applyCurveToValue(startValue, endValue, position, maxPosition, tension)
    local t = position / maxPosition
    local curveValue = startValue + (endValue - startValue) * t

    if tension ~= 0 then
        -- Reduce the exponent's impact by dividing tension, making the curve closer to linear
        local tensionAdjustment = tension / 3.14 -- Adjust this divisor to control the curve's linearity
        local factor = math.exp(tensionAdjustment * t)
        curveValue = startValue + (endValue - startValue) * ((factor - 1) / (math.exp(tensionAdjustment) - 1))
    end



    return curveValue
end

-- This is the obj_RectSlider function which takes an additional parameter "isNotePresent"
local function obj_RectSlider(ctx, cursor_x, cursor_y, width, height, value, drawList, x_padding, color, isNotePresent,
                              colorValues)
    local slider_left = cursor_x
    local slider_top = cursor_y
    local slider_right = slider_left + width
    local slider_bottom = slider_top + height

    -- Background rectangle
    reaper.ImGui_DrawList_AddRectFilled(drawList, slider_left + x_padding, slider_top, slider_right - x_padding,
        slider_bottom, color)
    -- Foreground rectangle - height changes based on value, but only if a note is present
    if isNotePresent then
        local slider_top_value = slider_top + (height - (value * height))
        reaper.ImGui_DrawList_AddRectFilled(drawList, slider_left + x_padding, slider_top_value - 1,
            slider_right - x_padding, slider_bottom, colorValues.color23_slider1)
    end
    -- Return values are used to handle interactions, which we'll leave unchanged as it's not part of the requirement
    return numColorsPushed, rv, slider_left, slider_top, slider_right, slider_bottom
end

local function obj_RectSliderMiddle(ctx, cursor_x, cursor_y, width, height, value, drawList, x_padding, color, isNotePresent, colorValues)
    local slider_left = cursor_x
    local slider_top = cursor_y
    local slider_right = slider_left + width
    local slider_bottom = slider_top + height

    -- Background rectangle
    reaper.ImGui_DrawList_AddRectFilled(drawList, slider_left + x_padding, slider_top, slider_right - x_padding,
        slider_bottom, color)

    -- Foreground rectangle - height changes based on value, but only if a note is present
    if isNotePresent then
        local slider_middle = slider_top + height / 2
        local slider_value_height = (value * 2 - 1) * height
        local slider_top_value = slider_middle - slider_value_height / 2
        local slider_bottom_value = slider_middle --+ slider_value_height / 2
        
        -- Clamp the foreground rectangle within the background rectangle bounds
        slider_top_value = math.max(slider_top_value, slider_top)
        slider_bottom_value = math.min(slider_bottom_value, slider_bottom)
        
        reaper.ImGui_DrawList_AddRectFilled(drawList, slider_left + x_padding, slider_top_value,
            slider_right - x_padding, slider_bottom_value, colorValues.color23_slider1)

        reaper.ImGui_DrawList_AddRectFilled(drawList, slider_left + x_padding, slider_top_value + 2,
        slider_right - x_padding, slider_top_value - 2, colorValues.color66_waveform)
    end

    -- Return values are used to handle interactions, which we'll leave unchanged as it's not part of the requirement
    return numColorsPushed, rv, slider_left, slider_top, slider_right, slider_bottom
end



local function updateMidiNoteVelocity(step_num, velocity, midi_item, midi_take, num_events, pattern_start, step_duration,
                                      tolerance, noteData)
    local note_position = pattern_start + (step_num - 1) * step_duration

    -- Use binary search algorithm to find the note event closest to the note_position within the tolerance range and update its velocity
    local function binarySearch(start, finish, note_position, tolerance)
        local best_index = nil
        local best_distance = tolerance + 1  -- Initialize with a value larger than tolerance
        while start <= finish do
            local mid = math.floor((start + finish) / 2)
            local note_start_time = noteData[mid].note_start_time
            local distance = math.abs(note_position - note_start_time)
            
            if distance < best_distance then
                best_distance = distance
                best_index = mid
                if distance == 0 then
                    break  -- Perfect match found, exit loop
                end
            end
            
            if note_start_time < note_position then
                start = mid + 1
            else
                finish = mid - 1
            end
        end
        return best_index
    end

    local index = binarySearch(0, num_events - 1, note_position, tolerance)
    if index then
        -- Update the velocity of the note event
        reaper.MIDI_SetNote(midi_take, index, nil, nil, nil, nil, nil, nil, velocity, false)
    end

    -- Check if the MIDI take was modified before sorting
    -- if reaper.MIDI_GetHash(midi_take, false, "") ~= reaper.MIDI_GetHash(midi_take, true, "") then
    --     -- Update the MIDI take
    --     reaper.MIDI_Sort(midi_take)
    -- end
end

local function updateMidiNotePitch(step_num, pitch, midi_item, midi_take, num_events, pattern_start, step_duration, tolerance, noteData)
    local note_position = pattern_start + (step_num - 1) * step_duration

    -- Use binary search algorithm to find the note event closest to the note_position within the tolerance range and update its velocity
    local function binarySearch(start, finish, note_position, tolerance)
        while start <= finish do
            local mid = math.floor((start + finish) / 2)
            local note_start_time = noteData[mid].note_start_time
            if math.abs(note_position - note_start_time) <= tolerance then
                return mid
            elseif note_start_time < note_position then
                start = mid + 1
            else
                finish = mid - 1
            end
        end
        return nil
    end

    local index = binarySearch(0, num_events - 1, note_position, tolerance)
    if index then
        -- Update the velocity of the note event
        reaper.MIDI_SetNote(midi_take, index, nil, nil, nil, nil, nil, pitch, nil, false)
    end

    -- Check if the MIDI take was modified before sorting
    if reaper.MIDI_GetHash(midi_take, false, "") ~= reaper.MIDI_GetHash(midi_take, true, "") then
        -- Update the MIDI take
        reaper.MIDI_Sort(midi_take)
    end
end
local function updateMidiNoteOffset(step_num, slider_value, midi_item, midi_take, num_events, pattern_start, step_duration, tolerance, noteData)
    local note_position = pattern_start + (step_num - 1) * step_duration

    -- Use binary search algorithm to find the note event closest to the note_position within the tolerance range and update its position
    local function binarySearch(start, finish, note_position, tolerance)
        while start <= finish do
            local mid = math.floor((start + finish) / 2)
            local note_start_time = noteData[mid].note_start_time
            if math.abs(note_position - note_start_time) <= tolerance then
                return mid
            elseif note_start_time < note_position then
                start = mid + 1
            else
                finish = mid - 1
            end
        end
        return nil
    end

    local index = binarySearch(0, num_events - 1, note_position, tolerance)
    if index then
        -- Get the note start and end times
        local _, _, _, start_ppq, end_ppq, _, _, _ = reaper.MIDI_GetNote(midi_take, index)
        local note_start_time = reaper.MIDI_GetProjTimeFromPPQPos(midi_take, start_ppq)
        local note_end_time = reaper.MIDI_GetProjTimeFromPPQPos(midi_take, end_ppq)
        local note_length = note_end_time - note_start_time

        -- Calculate the distance based on the slider value
        local distance = (slider_value - 0.5) * step_duration

        -- Calculate the new position of the note based on distance (offset from the grid)
        local new_note_position = note_position + distance

        -- Update the start and end times of the note event
        local new_start_ppq = reaper.MIDI_GetPPQPosFromProjTime(midi_take, new_note_position)
        local new_end_ppq = reaper.MIDI_GetPPQPosFromProjTime(midi_take, new_note_position + note_length)

        -- Edge case 1: Check if the moving note's 'note start' overlaps the 'note end' of the previous note
        if index > 0 then
            local prev_note_end_ppq = select(5, reaper.MIDI_GetNote(midi_take, index - 1))
            if new_start_ppq < prev_note_end_ppq then
                -- Adjust the 'note end' of the previous note to prevent overlap
                reaper.MIDI_SetNote(midi_take, index - 1, nil, nil, nil, new_start_ppq, nil, nil, nil, false)
            end
        end

        -- Edge case 2: Check if the moving note's 'note end' overlaps the 'note start' of the next note
        if index < num_events - 1 then
            local next_note_start_ppq = select(4, reaper.MIDI_GetNote(midi_take, index + 1))
            if new_end_ppq > next_note_start_ppq then
                -- Adjust the 'note end' of the moving note to prevent overlap
                new_end_ppq = next_note_start_ppq
            end
        end

        reaper.MIDI_SetNote(midi_take, index, nil, nil, new_start_ppq, new_end_ppq, nil, nil, nil, false)
    end

    -- Check if the MIDI take was modified before sorting
    if reaper.MIDI_GetHash(midi_take, false, "") ~= reaper.MIDI_GetHash(midi_take, true, "") then
        -- Update the MIDI take
        reaper.MIDI_Sort(midi_take)
    end
end

local function obj_VelocitySliders(ctx, trackIndex, note_positions, note_velocities,
                                   mouse, keys, numberOfSliders, sliderWidth, sliderHeight, x_padding, patternItems,
                                   patternSelectSlider, colorValues)
    local pattern_item, pattern_start, pattern_end, midi_item = getSelectedPatternItemAndMidiItem(trackIndex,
        patternItems, patternSelectSlider)
    if not midi_item then
        return false
    end
    local midi_take = reaper.GetMediaItemTake(midi_item, 0)
    local num_events, _, _, _ = reaper.MIDI_CountEvts(midi_take)
    local noteData = {}
    for i = 0, num_events - 1 do
        local _, _, _, start_ppq, _, _, _, _ = reaper.MIDI_GetNote(midi_take, i)
        local note_start_time = reaper.MIDI_GetProjTimeFromPPQPos(midi_take, start_ppq)
        noteData[i] = { start_ppq = start_ppq, note_start_time = note_start_time }
    end

    local step_duration = reaper.TimeMap2_beatsToTime(0, 1) / time_resolution
    local tolerance = step_duration / 2
    local cursor_x, cursor_y = reaper.ImGui_GetCursorScreenPos(ctx)
    local cursor_x = cursor_x + 245 * size_modifier
    local x_padding = x_padding * size_modifier
    local sliderWidth = sliderWidth * size_modifier
    local sliderHeight = sliderHeight * size_modifier
    local color1 = colorValues.color24_slider2
    local color2 = colorValues.color25_slider3
    local dragStartedOnAnySlider = false

    if anyMenuOpen == false then
        if (mouse.isMouseDownL or mouse.isMouseDownR) and anyMenuOpen == false then
            for i = 0, lengthSlider - 1 do
                local sliderLeftX = cursor_x + (i * sliderWidth)
                local sliderRightX = sliderLeftX + sliderWidth
                local sliderTopY = cursor_y
                local sliderBottomY = cursor_y + sliderHeight

                if drag_start_x >= sliderLeftX and drag_start_x <= sliderRightX
                    and drag_start_y >= sliderTopY and drag_start_y <= sliderBottomY then
                    dragStartedOnAnySlider = true
                    break
                end
            end
        end

        -- Left-click drag handling
        if (mouse.isMouseDownL and dragStartedOnAnySlider) and anyMenuOpen == false then
            draggingNow = true
            -- Calculate the current and previous slider indices based on mouse position
            local currentSliderIndex = math.floor((mouse.mouse_x - cursor_x) / sliderWidth)
            -- print('currentSliderIndex: ' .. currentSliderIndex)
            local previousSliderIndex = math.floor((previous_mouse_x - cursor_x) / sliderWidth)
            -- currentSliderIndex = math.max(0, math.min(currentSliderIndex, numberOfSliders - 1))
            -- previousSliderIndex = math.max(0, math.min(previousSliderIndex, numberOfSliders - 1))
            
            -- Determine the range of sliders to update
            local startIndex = math.min(currentSliderIndex, previousSliderIndex)
            -- print('startIndex: ' .. startIndex)
            local endIndex = math.max(currentSliderIndex, previousSliderIndex)
            -- print('endIndex: ' .. endIndex)
            local midiUpdated = false

            -- Update sliders in the determined range
            for i = startIndex, endIndex do
                local step_time = pattern_start + i * step_duration
                local closestNoteIndex = nil
                local closestNoteDistance = tolerance

                -- Find the closest note to this step time
                for j = 0, num_events - 1 do
                    local _, _, _, start_ppq, _, _, _, _ = reaper.MIDI_GetNote(midi_take, j)
                    local note_start_time = reaper.MIDI_GetProjTimeFromPPQPos(midi_take, start_ppq)
                    local distance = math.abs(note_start_time - step_time)
                    if distance < closestNoteDistance then
                        closestNoteIndex = j
                        closestNoteDistance = distance
                    end
                end
                -- print('st ' .. startIndex)
                -- print('en ' .. endIndex)
                if closestNoteIndex then
                    local valueToApply
                    midiUpdated = true  -- Set flag if any note is updated
                    if startIndex ~= endIndex then
                        local relativePosition = (i - startIndex) / (endIndex - startIndex)
                        local interpolated_y = previous_mouse_y + (mouse.mouse_y - previous_mouse_y) * relativePosition
                        valueToApply = 1 - (interpolated_y - cursor_y) / sliderHeight
                    else
                        valueToApply = 1 - (mouse.mouse_y - cursor_y) / sliderHeight
                    end
                    valueToApply = math.max(0, math.min(valueToApply, 1)) -- Clamp the value

                    local new_velocity = math.max(1, math.floor(valueToApply * 127))

                    if keys.altDown then
                        new_velocity = 100
                        updateMidiNoteVelocity(i + 1, new_velocity, midi_item, midi_take, num_events, pattern_start,
                            step_duration, tolerance, noteData)
                    else
                        updateMidiNoteVelocity(i + 1, new_velocity, midi_item, midi_take, num_events, pattern_start,
                            step_duration, tolerance, noteData)
                    end
                    
                end
                if midiUpdated then
                    reaper.MIDI_Sort(midi_take)
                end
            end
        else
            draggingNow = false
        end

        -- Right-click drag handling
        if mouse.isMouseDownR and dragStartedOnAnySlider and anyMenuOpen == false then
            draggingNow = true
            if not right_drag_start_x then
                right_drag_start_x = mouse.mouse_x
                right_drag_start_y = mouse.mouse_y
                right_drag_velocity = true
                for i = 0, numberOfSliders - 1 do
                    local slider = slider[i + 1]
                    slider.startValue = slider.value
                    slider.startPos = cursor_x + (i * sliderWidth)
                end
            else
                local tension = OnMouseWheel(mouse.mousewheel_v)
                local drag_start_index = math.floor((right_drag_start_x - cursor_x) / sliderWidth)
                local drag_end_index = math.floor((mouse.mouse_x - cursor_x) / sliderWidth)
                local drag_min_index = math.min(drag_start_index, drag_end_index)
                local drag_max_index = math.max(drag_start_index, drag_end_index)
                local startYValue = 1 - (right_drag_start_y - cursor_y) / sliderHeight
                local currentYValue = 1 - (mouse.mouse_y - cursor_y) / sliderHeight

                for i = drag_min_index, drag_max_index do
                    local slider = slider[i + 1]
                    if slider then
                        local relativePos
                        if drag_start_index == drag_end_index then
                            -- If dragging started and ended on the same slider
                            relativePos = (mouse.mouse_x - right_drag_start_x) / sliderWidth
                        else
                            -- Normal calculation for relative position
                            relativePos = (slider.startPos - right_drag_start_x) / (mouse.mouse_x - right_drag_start_x)
                        end
                        relativePos = math.max(0, math.min(relativePos, 1)) -- Clamp the value

                        local curveValue = applyCurveToValue(startYValue, currentYValue, relativePos, 1, tension)
                        slider.value = math.max(0, math.min(curveValue, 1))
                        -- Update MIDI note velocity based on the slider's new value
                        local new_velocity = math.max(1, math.floor(slider.value * 127))

                        if keys.altDown then
                            new_velocity = 100
                            updateMidiNoteVelocity(i + 1, new_velocity, midi_item, midi_take, num_events, pattern_start,
                                step_duration, tolerance, noteData)
                        else
                            updateMidiNoteVelocity(i + 1, new_velocity, midi_item,
                                midi_take, num_events, pattern_start, step_duration, tolerance, noteData)
                        end
                    end
                end
            end
        end
    else
        draggingNow = false
    end

    -- Sliders
    for i = 0, lengthSlider - 1 do
        local step_time = pattern_start + i * step_duration
        local slider_cursor_x = cursor_x + (i * sliderWidth)
        local slider_value = nil -- Default to no value
        local isNotePresent = false
        -- Check for the presence of a note at this step and set slider_value if found
        local numNotePositions = #note_positions
        for idx = 1, numNotePositions do
            local note_pos = note_positions[idx]
            if math.abs(note_pos - step_time) <= tolerance then
                slider_value = note_velocities[idx] / 127
                isNotePresent = true
                break
            end
        end

        -- Display the slider
        local color = (math.floor(i / 4) % 2 == 0) and color1 or color2
        local numColorsPushed, rv, slider_left, slider_top, slider_right, slider_bottom = obj_RectSlider(
            ctx, slider_cursor_x, cursor_y, sliderWidth, sliderHeight, slider_value, drawList, x_padding, color,
            isNotePresent, colorValues)
        
        if slider_value then slider_value = math.floor(slider_value * 127) end
        reaper.ImGui_PushFont(ctx, font_SliderValue)
        reaper.ImGui_DrawList_AddText(drawList, slider_left + x_padding + 3, slider_bottom + 5, colorValues.color66_waveform,
        slider_value)
        reaper.ImGui_PopFont(ctx)
    end


    --Dummy Spacer
    reaper.ImGui_Dummy(ctx, 0, sliderHeight)

    -- Reset states on mouse release
    if mouse.mouseReleasedR then
        right_drag_start_x, right_drag_start_y = nil, nil
    end

    -- Update the previous mouse position for interpolation
    previous_mouse_x, previous_mouse_y = mouse.mouse_x, mouse.mouse_y
end

local function obj_PitchSliders(ctx, trackIndex, note_positions, note_pitches,
                                mouse, keys, numberOfSliders, sliderWidth, sliderHeight, x_padding, patternItems,
                                patternSelectSlider, colorValues)
    local pattern_item, pattern_start, pattern_end, midi_item = getSelectedPatternItemAndMidiItem(trackIndex,
        patternItems, patternSelectSlider)
    if not midi_item then
        return false
    end
    local midi_take = reaper.GetMediaItemTake(midi_item, 0)
    local num_events, _, _, _ = reaper.MIDI_CountEvts(midi_take)
    local noteData = {}
    for i = 0, num_events - 1 do
        local _, _, _, start_ppq, _, _, _, _ = reaper.MIDI_GetNote(midi_take, i)
        local note_start_time = reaper.MIDI_GetProjTimeFromPPQPos(midi_take, start_ppq)
        noteData[i] = { start_ppq = start_ppq, note_start_time = note_start_time }
    end

    local step_duration = reaper.TimeMap2_beatsToTime(0, 1) / time_resolution
    local tolerance = step_duration / 2
    local cursor_x, cursor_y = reaper.ImGui_GetCursorScreenPos(ctx)
    local cursor_x = cursor_x + 245 * size_modifier
    local x_padding = x_padding * size_modifier
    local sliderWidth = sliderWidth * size_modifier
    local sliderHeight = sliderHeight * size_modifier
    local color1 = colorValues.color24_slider2
    local color2 = colorValues.color25_slider3
    local dragStartedOnAnySlider = false

    if anyMenuOpen == false then
        if (mouse.isMouseDownL or mouse.isMouseDownR) and anyMenuOpen == false then
            for i = 0, lengthSlider - 1 do
                local sliderLeftX = cursor_x + (i * sliderWidth)
                local sliderRightX = sliderLeftX + sliderWidth
                local sliderTopY = cursor_y
                local sliderBottomY = cursor_y + sliderHeight

                if drag_start_x >= sliderLeftX and drag_start_x <= sliderRightX
                    and drag_start_y >= sliderTopY and drag_start_y <= sliderBottomY then
                    dragStartedOnAnySlider = true
                    break
                end
            end
        end

        -- Left-click drag handling
        if (mouse.isMouseDownL and dragStartedOnAnySlider) and anyMenuOpen == false then
            draggingNow = true
            -- Calculate the current and previous slider indices based on mouse position
            local currentSliderIndex = math.floor((mouse.mouse_x - cursor_x) / sliderWidth)
            local previousSliderIndex = math.floor((previous_mouse_x - cursor_x) / sliderWidth)
            currentSliderIndex = math.max(0, math.min(currentSliderIndex, numberOfSliders - 1))
            previousSliderIndex = math.max(0, math.min(previousSliderIndex, numberOfSliders - 1))

            -- Determine the range of sliders to update
            local startIndex = math.min(currentSliderIndex, previousSliderIndex)
            local endIndex = math.max(currentSliderIndex, previousSliderIndex)

            -- Update sliders in the determined range
            for i = startIndex, endIndex do
                local step_time = pattern_start + i * step_duration
                local closestNoteIndex = nil
                local closestNoteDistance = tolerance

                -- Find the closest note to this step time
                for j = 0, num_events - 1 do
                    local _, _, _, start_ppq, _, _, _, _ = reaper.MIDI_GetNote(midi_take, j)
                    local note_start_time = reaper.MIDI_GetProjTimeFromPPQPos(midi_take, start_ppq)
                    local distance = math.abs(note_start_time - step_time)
                    if distance < closestNoteDistance then
                        closestNoteIndex = j
                        closestNoteDistance = distance
                    end
                end
                -- print('st ' .. startIndex)
                -- print('en ' .. endIndex)
                if closestNoteIndex then
                    local valueToApply
                    if startIndex ~= endIndex then
                        local relativePosition = (i - startIndex) / (endIndex - startIndex)
                        local interpolated_y = previous_mouse_y + (mouse.mouse_y - previous_mouse_y) * relativePosition
                        valueToApply = 1 - (interpolated_y - cursor_y) / sliderHeight
                    else
                        valueToApply = 1 - (mouse.mouse_y - cursor_y) / sliderHeight
                    end
                    -- Clamp the value between 0 and 1
                    valueToApply = math.max(0, math.min(valueToApply, 1))

                    -- Scale from 0 to 1 range to 36 to 84 range
                    valueToApply = (valueToApply * (84 - 36)) + 36

                    local new_pitch = math.max(1, math.min(math.floor(valueToApply), 127))
                    if keys.altDown then
                        new_pitch = 60
                        updateMidiNotePitch(i + 1, new_pitch, midi_item, midi_take, num_events, pattern_start,
                            step_duration, tolerance, noteData)
                    else
                        updateMidiNotePitch(i + 1, new_pitch, midi_item, midi_take, num_events, pattern_start,
                            step_duration, tolerance, noteData)
                    end
                end
            end
        else
            draggingNow = false
        end

        -- Right-click drag handling
        if mouse.isMouseDownR and dragStartedOnAnySlider and anyMenuOpen == false then
            draggingNow = true
            if not right_drag_start_x then
                right_drag_start_x = mouse.mouse_x
                right_drag_start_y = mouse.mouse_y
                right_drag_velocity = true
                for i = 0, numberOfSliders - 1 do
                    local slider = slider[i + 1]
                    slider.startValue = slider.value
                    slider.startPos = cursor_x + (i * sliderWidth)
                end
            else
                local tension = OnMouseWheel(mouse.mousewheel_v)
                local drag_start_index = math.floor((right_drag_start_x - cursor_x) / sliderWidth)
                local drag_end_index = math.floor((mouse.mouse_x - cursor_x) / sliderWidth)
                local drag_min_index = math.min(drag_start_index, drag_end_index)
                local drag_max_index = math.max(drag_start_index, drag_end_index)
                local startYValue = 1 - (right_drag_start_y - cursor_y) / sliderHeight
                local currentYValue = 1 - (mouse.mouse_y - cursor_y) / sliderHeight

                for i = drag_min_index, drag_max_index do
                    local step_time = pattern_start + i * step_duration
                    local closestNoteIndex = nil
                    local closestNoteDistance = tolerance

                    -- Find the closest note to this step time
                    for j = 0, num_events - 1 do
                        local _, _, _, start_ppq, _, _, _, _ = reaper.MIDI_GetNote(midi_take, j)
                        local note_start_time = reaper.MIDI_GetProjTimeFromPPQPos(midi_take, start_ppq)
                        local distance = math.abs(note_start_time - step_time)
                        if distance < closestNoteDistance then
                            closestNoteIndex = j
                            closestNoteDistance = distance
                        end
                    end

                    if closestNoteIndex then
                        local slider = slider[i + 1]
                        if slider then
                            local relativePos
                            if drag_start_index == drag_end_index then
                                -- If dragging started and ended on the same slider
                                relativePos = (mouse.mouse_x - right_drag_start_x) / sliderWidth
                            else
                                -- Normal calculation for relative position
                                relativePos = (slider.startPos - right_drag_start_x) /
                                (mouse.mouse_x - right_drag_start_x)
                            end
                            relativePos = math.max(0, math.min(relativePos, 1)) -- Clamp the value

                            local curveValue = applyCurveToValue(startYValue, currentYValue, relativePos, 1, tension)
                            slider.value = math.max(0, math.min(curveValue, 1))

                            -- Scale from 0 to 1 range to 36 to 84 range
                            local new_pitch = (slider.value * (84 - 36)) + 36
                            new_pitch = math.max(1, math.min(math.floor(new_pitch), 127))

                            updateMidiNotePitch(i + 1, new_pitch, midi_item, midi_take, num_events, pattern_start,
                                step_duration, tolerance, noteData)
                        end
                    end
                end
            end
        end
    else
        draggingNow = false
    end

    -- Sliders
    for i = 0, lengthSlider - 1 do
        local step_time = pattern_start + i * step_duration
        local slider_cursor_x = cursor_x + (i * sliderWidth)
        local slider_value = 0.5 -- Default to middle value (60)
        local note_value
        local isNotePresent = false
        -- Check for the presence of a note at this step and set slider_value if found
        local numNotePositions = #note_positions
        for idx = 1, numNotePositions do
            local note_pos = note_positions[idx]
            if math.abs(note_pos - step_time) <= tolerance then
                slider_value = (note_pitches[idx] - 36) / 48 -- Scale from 0 to 1
                note_value = translateNoteNumber(note_pitches[idx])
                isNotePresent = true
                break
            end
        end

        -- Display the slider
        local color = (math.floor(i / 4) % 2 == 0) and color1 or color2


        local numColorsPushed, rv, slider_left, slider_top, slider_right, slider_bottom = obj_RectSliderMiddle(
            ctx, slider_cursor_x, cursor_y, sliderWidth, sliderHeight, slider_value, drawList, x_padding, color,
            isNotePresent, colorValues)


        reaper.ImGui_PushFont(ctx, font_SliderValue)
        reaper.ImGui_DrawList_AddText(drawList, slider_left + x_padding + 3, slider_bottom + 5, colorValues.color66_waveform,
            note_value)
        reaper.ImGui_PopFont(ctx)
    end

    --Dummy Spacer
    reaper.ImGui_Dummy(ctx, 0, sliderHeight)

    -- Reset states on mouse release
    if mouse.mouseReleasedR then
        right_drag_start_x, right_drag_start_y = nil, nil
    end

    -- Update the previous mouse position for interpolation
    previous_mouse_x, previous_mouse_y = mouse.mouse_x, mouse.mouse_y
end

local function obj_OffsetSliders(ctx, trackIndex, note_positions, note_pitches,
                                 mouse, keys, numberOfSliders, sliderWidth, sliderHeight, x_padding, patternItems,
                                 patternSelectSlider, colorValues)
    local pattern_item, pattern_start, pattern_end, midi_item = getSelectedPatternItemAndMidiItem(trackIndex,
        patternItems, patternSelectSlider)
    if not midi_item then
        return false
    end
    local midi_take = reaper.GetMediaItemTake(midi_item, 0)
    local num_events, _, _, _ = reaper.MIDI_CountEvts(midi_take)
    local noteData = {}
    for i = 0, num_events - 1 do
        local _, _, _, start_ppq, _, _, _, _ = reaper.MIDI_GetNote(midi_take, i)
        local note_start_time = reaper.MIDI_GetProjTimeFromPPQPos(midi_take, start_ppq)
        noteData[i] = { start_ppq = start_ppq, note_start_time = note_start_time }
    end

    local step_duration = reaper.TimeMap2_beatsToTime(0, 1) / time_resolution
    local tolerance = step_duration / 2
    local cursor_x, cursor_y = reaper.ImGui_GetCursorScreenPos(ctx)
    local cursor_x = cursor_x + 245 * size_modifier
    local x_padding = x_padding * size_modifier
    local sliderWidth = sliderWidth * size_modifier
    local sliderHeight = sliderHeight * size_modifier
    local color1 = colorValues.color24_slider2
    local color2 = colorValues.color25_slider3
    local dragStartedOnAnySlider = false

    if anyMenuOpen == false then
        if (mouse.isMouseDownL or mouse.isMouseDownR) and anyMenuOpen == false then
            for i = 0, lengthSlider - 1 do
                local sliderLeftX = cursor_x + (i * sliderWidth)
                local sliderRightX = sliderLeftX + sliderWidth
                local sliderTopY = cursor_y
                local sliderBottomY = cursor_y + sliderHeight

                if drag_start_x >= sliderLeftX and drag_start_x <= sliderRightX
                    and drag_start_y >= sliderTopY and drag_start_y <= sliderBottomY then
                    dragStartedOnAnySlider = true
                    draggingNow = true
                    break
                end
            end
        end

        -- Left-click drag handling
        if (mouse.isMouseDownL and dragStartedOnAnySlider) and anyMenuOpen == false then
            draggingNow = true
            -- Calculate the current and previous slider indices based on mouse position
            local currentSliderIndex = math.floor((mouse.mouse_x - cursor_x) / sliderWidth)
            local previousSliderIndex = math.floor((previous_mouse_x - cursor_x) / sliderWidth)
            currentSliderIndex = math.max(0, math.min(currentSliderIndex, numberOfSliders - 1))
            previousSliderIndex = math.max(0, math.min(previousSliderIndex, numberOfSliders - 1))

            -- Determine the range of sliders to update
            local startIndex = math.min(currentSliderIndex, previousSliderIndex)
            local endIndex = math.max(currentSliderIndex, previousSliderIndex)

            -- Update sliders in the determined range
            for i = startIndex, endIndex do
                local step_time = pattern_start + i * step_duration
                local closestNoteIndex = nil
                local closestNoteDistance = tolerance

                -- Find the closest note to this step time
                for j = 0, num_events - 1 do
                    local _, _, _, start_ppq, _, _, _, _ = reaper.MIDI_GetNote(midi_take, j)
                    local note_start_time = reaper.MIDI_GetProjTimeFromPPQPos(midi_take, start_ppq)
                    local distance = math.abs(note_start_time - step_time)
                    if distance < closestNoteDistance then
                        closestNoteIndex = j
                        closestNoteDistance = distance
                    end
                end

                if closestNoteIndex then
                    local valueToApply
                    if startIndex ~= endIndex then
                        local relativePosition = (i - startIndex) / (endIndex - startIndex)
                        local interpolated_y = previous_mouse_y + (mouse.mouse_y - previous_mouse_y) * relativePosition
                        valueToApply = 1 - (interpolated_y - cursor_y) / sliderHeight
                    else
                        valueToApply = 1 - (mouse.mouse_y - cursor_y) / sliderHeight
                    end

                    -- Clamp the value between 0.5 and 1 for the first slider
                    if i == 0 then
                        valueToApply = math.max(0.5, math.min(valueToApply, 1))
                    else
                        valueToApply = math.max(0.02, math.min(valueToApply, 1))
                    end

                    if keys.altDown then
                        valueToApply = 0.5
                        updateMidiNoteOffset(i + 1, valueToApply, midi_item, midi_take, num_events, pattern_start,
                            step_duration, tolerance, noteData)
                    else

                    updateMidiNoteOffset(i + 1, valueToApply, midi_item, midi_take, num_events, pattern_start,
                        step_duration, tolerance, noteData)
                    end
                end
            end
        else 
            draggingNow = false
        end

        -- Right-click drag handling
        if mouse.isMouseDownR and dragStartedOnAnySlider and anyMenuOpen == false then
            draggingNow = true
            if not right_drag_start_x then
                right_drag_start_x = mouse.mouse_x
                right_drag_start_y = mouse.mouse_y
                right_drag_velocity = true
                for i = 0, numberOfSliders - 1 do
                    local slider = slider[i + 1]
                    slider.startValue = slider.value
                    slider.startPos = cursor_x + (i * sliderWidth)
                end
            else
                local tension = OnMouseWheel(mouse.mousewheel_v)
                local drag_start_index = math.floor((right_drag_start_x - cursor_x) / sliderWidth)
                local drag_end_index = math.floor((mouse.mouse_x - cursor_x) / sliderWidth)
                local drag_min_index = math.min(drag_start_index, drag_end_index)
                local drag_max_index = math.max(drag_start_index, drag_end_index)
                local startYValue = 1 - (right_drag_start_y - cursor_y) / sliderHeight
                local currentYValue = 1 - (mouse.mouse_y - cursor_y) / sliderHeight

                for i = drag_min_index, drag_max_index do
                    local step_time = pattern_start + i * step_duration
                    local closestNoteIndex = nil
                    local closestNoteDistance = tolerance

                    -- Find the closest note to this step time
                    for j = 0, num_events - 1 do
                        local _, _, _, start_ppq, _, _, _, _ = reaper.MIDI_GetNote(midi_take, j)
                        local note_start_time = reaper.MIDI_GetProjTimeFromPPQPos(midi_take, start_ppq)
                        local distance = math.abs(note_start_time - step_time)
                        if distance < closestNoteDistance then
                            closestNoteIndex = j
                            closestNoteDistance = distance
                        end
                    end

                    if closestNoteIndex then
                        local slider = slider[i + 1]
                        if slider then
                            local relativePos
                            if drag_start_index == drag_end_index then
                                -- If dragging started and ended on the same slider
                                relativePos = (mouse.mouse_x - right_drag_start_x) / sliderWidth
                            else
                                -- Normal calculation for relative position
                                relativePos = (slider.startPos - right_drag_start_x) /
                                    (mouse.mouse_x - right_drag_start_x)
                            end
                            relativePos = math.max(0, math.min(relativePos, 1)) -- Clamp the value

                            local curveValue = applyCurveToValue(startYValue, currentYValue, relativePos, 1, tension)
                            slider.value = math.max(0, math.min(curveValue, 1))

                            -- Limit the minimum value of the first slider to 0.5 (middle value)
                            if i == 0 then
                                slider.value = math.max(0.5, slider.value)
                            end

                            updateMidiNoteOffset(i + 1, slider.value, midi_item, midi_take, num_events, pattern_start,
                                step_duration, tolerance, noteData)
                        end
                    end
                end
            end
        end
    end

    -- Sliders
    for i = 0, lengthSlider - 1 do
        local step_time = pattern_start + i * step_duration
        local slider_cursor_x = cursor_x + (i * sliderWidth)
        local slider_value = 0.5 -- Default to middle value (60)
        local note_value
        local isNotePresent = false

        -- Check for the presence of a note at this step and set slider_value if found

        local closest_distance = math.huge

        for idx, note_pos in ipairs(note_positions) do
            local dist = note_pos - step_time
            local abs_dist = math.abs(dist)
            if abs_dist < closest_distance and abs_dist <= tolerance then
                closest_distance = abs_dist
                -- Normalize dist within [-tolerance, tolerance] to [0, 1]
                slider_value = (dist / tolerance / 2) + 0.5
                slider_value = math.max(0, math.min(slider_value, 1)) -- Ensure slider_value is within [0, 1]
                isNotePresent = true
            end
        end

        -- Display the slider
        local color = (math.floor(i / 4) % 2 == 0) and color1 or color2

        local numColorsPushed, rv, slider_left, slider_top, slider_right, slider_bottom = obj_RectSliderMiddle(
            ctx, slider_cursor_x, cursor_y, sliderWidth, sliderHeight, slider_value, drawList, x_padding, color,
            isNotePresent, colorValues)

        if slider_value then 
            slider_value = math.floor((slider_value - 0.5) * 200)
        end
        reaper.ImGui_PushFont(ctx, font_SliderValue)
        reaper.ImGui_DrawList_AddText(drawList, slider_left + x_padding + 3, slider_bottom + 5, colorValues.color66_waveform,
        slider_value)
        reaper.ImGui_PopFont(ctx)
    end

    --Dummy Spacer
    reaper.ImGui_Dummy(ctx, 0, sliderHeight)

    -- Reset states on mouse release
    if mouse.mouseReleasedR then
        right_drag_start_x, right_drag_start_y = nil, nil
    end

    -- Update the previous mouse position for interpolation
    previous_mouse_x, previous_mouse_y = mouse.mouse_x, mouse.mouse_y
end





---- MIDI KNOBS---------------------------------

local function obj_KnobMIDI(ctx, imageParams, id, value, params, mouse, keys, yOffset)
    reaper.ImGui_InvisibleButton(ctx, id, params.frameWidth, params.frameHeight)
    reaper.ImGui_SameLine(ctx)
    if not yOffset then yOffset = 0 end
    adjustCursorPos(ctx, -params.frameWidth - 7, 3 - yOffset)

    local isActive = reaper.ImGui_IsItemActive(ctx)
    local rv = false

    -- Define the actual sensitivity based on key modifiers
    local dragSensitivity = keys.ctrlShiftDown and params.dragFineSensitivity * 0.25 or
        (keys.ctrlDown and params.dragFineSensitivity * 0.5 or (keys.shiftDown and params.dragFineSensitivity or params.dragSensitivity))
    local wheelSensitivity = keys.ctrlShiftDown and params.wheelFineSensitivity * 0.25 or
        (keys.ctrlDown and params.wheelFineSensitivity * 0.5 or (keys.shiftDown and params.wheelFineSensitivity or params.wheelSensitivity))
    local overallSensitivity = 250

    -- Transform the value to a curved scale
    if not value then 
        update_requiered = true 
        return 
    end
    
    local normalizedValue = (value - params.min) / (params.max - params.min)
    local curvedValue = normalizedValue ^ params.scaling
    -- Mouse drag logic
    local function updateValue(change, params, curvedValue, fineControl, delta)
        local visualCurvedValue = curvedValue + change
        visualCurvedValue = math.max(math.min(visualCurvedValue, 1), 0)
        local normalizedValue = visualCurvedValue ^ (1 / params.scaling)
        local newValue = params.min + normalizedValue * (params.max - params.min)
        return newValue, visualCurvedValue
    end

    local function updateValueSnapped(delta, speed, params, isWheel)
        local factor = 300
        local change = delta * speed * (params.max - params.min) / factor
        local newValue = value + change
    
        if params.applySnap and params.snapAmount and params.snapAmount > 0 then
            newValue = params.snapAmount * math.floor((newValue + params.snapAmount / 2) / params.snapAmount)
        end
    
        return math.max(math.min(newValue, params.max), params.min)
    end

    if reaper.ImGui_IsItemClicked(ctx, 0) then
        local x, y = reaper.GetMousePosition()
        dragStartPos[id] = { x = x, y = y }
    end

    if isActive then
        

        if os == "Win64" then
            reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_None())
            mouse_x, mouse_y = reaper.GetMousePosition()
            trackDeltaX = mouse_x - dragStartPos[id].x
            trackDeltaY = mouse_y - dragStartPos[id].y    
            if  reaper.JS_ReaScriptAPI_Version then
                reaper.JS_Mouse_SetPosition(dragStartPos[id].x, dragStartPos[id].y)
            end
        else
            trackDeltaX = mouse.delta_x
            trackDeltaY = mouse.delta_y
        end

        local delta = params.dragDirection == 'Horizontal' and trackDeltaX or -trackDeltaY
        if delta ~= 0.0 then
            local fineControl = (keys.shiftDown or keys.ctrlDown or keys.ctrlShiftDown)
            local change = (delta * (params.max - params.min) / overallSensitivity) * dragSensitivity
            if params.applySnap and not fineControl then
                value = updateValueSnapped(delta, dragSensitivity, params, false)

            else
                value, curvedValue = updateValue(change, params, curvedValue, fineControl, delta)
            end
            rv = true
        end
    end
    
    -- Mouse wheel logic
    if reaper.ImGui_IsItemHovered(ctx) and mouse.mousewheel_v ~= 0 then
        local fineControl = (keys.shiftDown or keys.ctrlDown or keys.ctrlShiftDown)
        local wheelChange = mouse.mousewheel_v * wheelSensitivity / 45
        value, curvedValue = updateValue(wheelChange, params, curvedValue, fineControl)
        rv = true
    end

    -- Double-click to reset
    if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
        value = params.default
        rv = true
    end

    if rv then
        local scaleFactor = value / 100  -- Assuming the knob value ranges from 0 to 100
        
        -- Iterate over all sliders and update the velocities of their corresponding notes
        for i = 0, numberOfSliders - 1 do
            local step_time = pattern_start + i * step_duration
            local closestNoteIndex = nil
            local closestNoteDistance = tolerance
            
            -- Find the closest note to this step time
            for j = 0, num_events - 1 do
                local _, _, _, start_ppq, _, _, _, _ = reaper.MIDI_GetNote(midi_take, j)
                local note_start_time = reaper.MIDI_GetProjTimeFromPPQPos(midi_take, start_ppq)
                local distance = math.abs(note_start_time - step_time)
                if distance < closestNoteDistance then
                    closestNoteIndex = j
                    closestNoteDistance = distance
                end
            end
            
            if closestNoteIndex then
                local _, _, _, _, _, _, _, _, velocity = reaper.MIDI_GetNote(midi_take, closestNoteIndex)
                local new_velocity = math.floor(velocity * scaleFactor)
                new_velocity = math.max(1, math.min(new_velocity, 127))  -- Clamp the velocity within valid range
                
                updateMidiNoteVelocity(i + 1, new_velocity, midi_item, midi_take, num_events, pattern_start, step_duration, tolerance, noteData)
            end
        end
    end

    -- Draw the knob
    local currentFrame = math.floor(curvedValue * (params.frameCount - 1)) + 1
    local uv0x = 0
    local uv0y = ((currentFrame - 1) * params.frameHeight) / imageParams.y
    local uv1x = params.frameWidth / imageParams.x
    local uv1y = uv0y + params.frameHeight / imageParams.y

    reaper.ImGui_Image(ctx, imageParams.i, params.frameWidth, params.frameHeight, uv0x, uv0y, uv1x, uv1y)

    -- Right-click menu
    if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsItemClicked(ctx, 1) then
        reaper.ImGui_OpenPopup(ctx, id)
    end

    if reaper.ImGui_BeginPopup(ctx, id, reaper.ImGui_WindowFlags_NoMove()) then
        value, rv = obj_Knob_Menu(ctx, value)
    end

    if reaper.ImGui_IsItemHovered(ctx) or isActive then
        hoveredControlInfo.id = string.gsub(id, "%d", "")                    -- Remove the numeric part from the id
        hoveredControlInfo.id = string.gsub(hoveredControlInfo.id, "##", "") -- Remove the "##" prefix if it exists
        hoveredControlInfo.value = value
    end
    return rv, value
end



---- RS5K  ---------------------------------

local function cycleRS5kSample(track, fxIndex, direction)
    local ret, currentFile = reaper.TrackFX_GetNamedConfigParm(track, fxIndex, "FILE0")

    if not ret or currentFile == "" then
        return
    end

    local dirPath, currentFileName = currentFile:match("^(.-)([^/\\]+)$")

    if not dirPath or not currentFileName then
        return
    end

    local files = {}
    local i = 0
    while true do
        local fileName = reaper.EnumerateFiles(dirPath, i)
        if not fileName then
            break
        end

        -- Check if the file is an audio file by its extension
        if fileName:match("%.wav$") or fileName:match("%.mp3$") or fileName:match("%.flac$") or fileName:match("%.aiff$") or fileName:match("%.aac$") then
            table.insert(files, fileName)
        end

        i = i + 1
    end

    if #files == 0 then return end  -- If no audio files, exit the function

    table.sort(files)

    local currentIndex
    for i, fileName in ipairs(files) do
        if fileName == currentFileName then
            currentIndex = i
            break
        end
    end

    local newIndex
    if direction == "previous" then
        newIndex = currentIndex - 1
        if newIndex < 1 then
            newIndex = #files
        end
    elseif direction == "next" then
        newIndex = currentIndex + 1
        if newIndex > #files then
            newIndex = 1
        end
    elseif direction == "random" then
        newIndex = math.random(#files)
        while newIndex == currentIndex do
            newIndex = math.random(#files)
        end
    else
        return
    end

    local newFileName = files[newIndex]
    if not newFileName then
        return
    end

    local newFilePath = dirPath .. newFileName

    reaper.TrackFX_SetNamedConfigParm(track, fxIndex, "FILE0", newFilePath)
    reaper.TrackFX_SetNamedConfigParm(track, fxIndex, "DONE", "")

    local newFileName = files[newIndex]
    if not newFileName then
        return nil
    end

    local newFilePath = dirPath .. newFileName

    reaper.TrackFX_SetNamedConfigParm(track, fxIndex, "FILE0", newFilePath)
    reaper.TrackFX_SetNamedConfigParm(track, fxIndex, "DONE", "")

    return newFileName  -- Return the name of the file
end


local function last_tr_in_folder(folder_tr)
    local last = nil
    local dep = reaper.GetTrackDepth(folder_tr)
    local num = reaper.GetMediaTrackInfo_Value(folder_tr, "IP_TRACKNUMBER")
    local tracks = reaper.CountTracks(0)
    for i = num + 1, tracks do
        if reaper.GetTrackDepth(reaper.GetTrack(0, i - 1)) <= dep then
            last = reaper.GetTrack(0, i - 2)
            break
        end
    end
    if last == nil then
        last = reaper.GetTrack(0, tracks - 1)
    end
    return last
end

-- Insert New Track
local function insertNewTrack(filename, track_suffix, track_count, insertIndex)
    -- Find the index of the last "Patterns SEQ" track
    local track_count = reaper.CountTracks(0)
    local last_patterns_seq_index = -1
    local folder_depth = 0
    local num_tracks = reaper.CountTracks(0)
    local insert_track_index = -1

    if insertIndex ~= nil then
        -- print(insertIndex)
        insert_track_index = insertIndex
        local last_track = reaper.GetTrack(0, insert_track_index)
        last_track_depth = reaper.GetMediaTrackInfo_Value(last_track, "I_FOLDERDEPTH")
    else

        for track_index = 0, num_tracks - 1 do
            local track = reaper.GetTrack(0, track_index)
            local _, track_name = reaper.GetTrackName(track)
            local current_folder_depth = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")

            if track_name == "Patterns SEQ" then
                last_patterns_seq_index = track_index
                folder_depth = current_folder_depth
                -- Find the last track in the folder
                last_track = last_tr_in_folder(track)
                insert_track_index = reaper.GetMediaTrackInfo_Value(last_track, "IP_TRACKNUMBER")
                last_track_depth = reaper.GetMediaTrackInfo_Value(last_track, "I_FOLDERDEPTH")
                break
            end
        end
    end

    if insert_track_index >= 0 then
        
        reaper.InsertTrackAtIndex(insert_track_index, false)
        reaper.TrackList_AdjustWindows(false)
        local new_track = reaper.GetTrack(0, insert_track_index)
        -- Ensure the new track is inside the folder and not a folder itself
        if insertIndex == nil then
            reaper.SetMediaTrackInfo_Value(last_track, "I_FOLDERDEPTH", 0)
            reaper.SetMediaTrackInfo_Value(new_track, "I_FOLDERDEPTH", -1)
        end

        if new_track then
            -- Extract the name from the path and remove the .wav file extension
            local trackName = filename:match("^.+[\\/](.+)$")
            trackName = trackName:gsub("%.(wav|mp3|flac|aiff|aac|ogg|m4a)$", "")
            local trackExists = false
            local numTracks = reaper.CountTracks(0)
            for i = 0, numTracks - 1 do
                local track = reaper.GetTrack(0, i)
                local _, existingTrackName = reaper.GetTrackName(track)
                if existingTrackName == trackName .. track_suffix then
                    trackExists = true
                    break
                end
            end

            reaper.GetSetMediaTrackInfo_String(new_track, "P_NAME", trackName .. track_suffix, true)
            reaper.GetSetTrackGroupMembership(new_track, 'MEDIA_EDIT_FOLLOW', 1, 1)
            if trackExists then
                enumerateTrack(new_track)
            end

            -- Add Trigger Note instance to the new track
            local note_trigger = reaper.TrackFX_AddByName(new_track, "Note Trigger", false, -1)
            -- Add Swing instance to the new track
            local fx_swing = reaper.TrackFX_AddByName(new_track, "Swing", false, -1)
            -- Add MIDI Offset Shift instance to the new track
            --local fx_offsetshift = reaper.TrackFX_AddByName(new_track, "MIDI Offset Shift", false, -1)
            -- Add RS5k instance to the new track
            local rs5k_index = reaper.TrackFX_AddByName(new_track, "ReaSamplomatic5000", false, -1)

            -- Close the RS5k window immediately after opening
            reaper.TrackFX_Show(new_track, rs5k_index, 2)
            reaper.TrackFX_Show(new_track, fx_swing, 2)
            
            -- set minimum velocity to 0
            reaper.TrackFX_SetParamNormalized(new_track, rs5k_index, 2, 0)

            -- Load the dropped file into RS5k
            reaper.TrackFX_SetNamedConfigParm(new_track, rs5k_index, "FILE0", filename)
            reaper.TrackFX_SetNamedConfigParm(new_track, rs5k_index, "DONE", "")
            -- Determine the new buttonIndex for the created track
            local newButtonIndex = #channel.GUID.name + 1

            -- Update channel data with the new track's information
            local trackName = filename:match("^.+[\\/](.+)$")
            trackName = trackName:gsub("%.wav$", "")
            channel.GUID.name[newButtonIndex] = trackName
            channel.GUID.file_path[newButtonIndex] = filename

            -- Update selectedChannelButton and selectedButtonIndex
            unselectAllTracks()
            reaper.SetTrackSelected(new_track, true)
            selectedChannelButton = insert_track_index
            selectedButtonIndex = newButtonIndex
            reaper.SetExtState("McSequencer", "selectedChannelButton", tostring(insert_track_index), true)
            reaper.SetExtState("McSequencer", "selectedButtonIndex", tostring(newButtonIndex), true)

        else
            -- Handle track creation error
            reaper.ShowMessageBox("Failed to create a new track.", "Error", 0)
        end
    end
end



---- OBJECTS  ---------------------------------

local function popup(ctx, track_count)
    local confirmed

    if showPopup then
        local win_x, win_y = reaper.ImGui_GetWindowPos(ctx)
        local win_w, win_h = reaper.ImGui_GetWindowSize(ctx)
        local center_x = win_x + win_w / 2
        local center_y = win_y + win_h / 2
        reaper.ImGui_SetNextWindowPos(ctx, center_x, center_y, reaper.ImGui_Cond_Appearing(), 0.5, 0.5)
        reaper.ImGui_OpenPopup(ctx, "Delete tracks")
    end


    if reaper.ImGui_BeginPopupModal(ctx, "Delete tracks", nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
        reaper.ImGui_Text(ctx, 'Delete ' .. track_count .. ' tracks?')
        if reaper.ImGui_Button(ctx, 'OK', 120, 0) then
            confirmed = true
            reaper.ImGui_CloseCurrentPopup(ctx)
            showPopup = false
        end

        reaper.ImGui_SameLine(ctx)

        -- Cancel button logic
        if reaper.ImGui_Button(ctx, 'Cancel', 120, 0) then
            confirmed = false
            reaper.ImGui_CloseCurrentPopup(ctx)
            showPopup = false
        end

        reaper.ImGui_EndPopup(ctx)
        return confirmed
    end
end

-- channel menu right click menu
local function obj_Channel_Button_Menu(ctx, trackIndex, contextMenuID, patternItems, track_count)
    -- Open in Midi Editor
    if reaper.ImGui_MenuItem(ctx, "Open in MIDI Editor") then
        -- insertMidiPooledItems(trackIndex, patternSelectSlider, patternItems, true)

        openMidiEditor(trackIndex, patternItems)
        reaper.ImGui_CloseCurrentPopup(ctx) -- Close the context menu
    end
    reaper.ImGui_Separator(ctx)

    -- Clone (Duplicate)
    if reaper.ImGui_MenuItem(ctx, "Clone (Duplicate)") then
        -- Action for Duplicating Track
        unselectNonSuffixedTracks()
        cloneDuplicateTrack(trackIndex)
        update_required = true
        reaper.ImGui_CloseCurrentPopup(ctx) -- Close the context menu
    end

    --Delete
    if reaper.ImGui_MenuItem(ctx, "Delete") then
        unselectNonSuffixedTracks()
        -- Action for Deleting Track
        deleteTrack(trackIndex)
        -- showPopup = true  -- Set the flag to open the popup
        reaper.ImGui_CloseCurrentPopup(ctx) -- Close the context menu
    end
    reaper.ImGui_Separator(ctx)

    -- Fill every 2 steps
    if reaper.ImGui_MenuItem(ctx, "Fill every 2 steps") then
        -- reaper.Undo_BeginBlock()
        deleteAllMIDIFromChannel(trackIndex, patternSelectSlider, patternItems) -- Clear the MIDI channel
        for i = 1, lengthSlider do
            if i % 2 == 1 then
                insertMidiNote(trackIndex, i, 60, 100, 0.125, patternSelectSlider, nil, nil, track_count) -- Insert a note on every other step
            end
        end
        insertMidiPooledItems(trackIndex, patternSelectSlider, patternItems)
        undoPoint2('Fill every 2 steps', track, item)
        reaper.ImGui_CloseCurrentPopup(ctx) -- Close the context menu

        --  reaper.Undo_EndBlock('Fill every 2 steps' ,-1)
    end
    -- Fill every 4 steps
    if reaper.ImGui_MenuItem(ctx, "Fill every 4 steps") then
        deleteAllMIDIFromChannel(trackIndex, patternSelectSlider, patternItems) -- Clear the MIDI channel
        for i = 1, lengthSlider do
            if i % 4 == 1 then
                insertMidiNote(trackIndex, i, 60, 100, 0.125, patternSelectSlider, nil, nil, track_count) -- Insert a note on every other step
            end
        end
        insertMidiPooledItems(trackIndex, patternSelectSlider, patternItems)
        undoPoint2('Fill every 4 steps', track, item)
        reaper.ImGui_CloseCurrentPopup(ctx) -- Close the context menu
    end
    -- Fill every 8 steps
    if reaper.ImGui_MenuItem(ctx, "Fill every 8 steps") then
        deleteAllMIDIFromChannel(trackIndex, patternSelectSlider, patternItems) -- Clear the MIDI channel
        for i = 1, lengthSlider do
            if i % 8 == 1 then
                insertMidiNote(trackIndex, i, 60, 100, 0.125, patternSelectSlider, nil, nil, track_count) -- Insert a note on every other step
            end
        end
        insertMidiPooledItems(trackIndex, patternSelectSlider, patternItems)
        undoPoint2('Fill every 8 steps', track, item)
        reaper.ImGui_CloseCurrentPopup(ctx) -- Close the context menu
    end

    -- Intercept key presses
    if reaper.ImGui_IsWindowFocused(ctx) then
        local is_key_c_pressed = reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_C())
        local is_key_d_pressed = reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_D())
        if is_key_c_pressed then
            -- Run Clone (Duplicate) action
            unselectNonSuffixedTracks()
            cloneDuplicateTrack(trackIndex)
            reaper.ImGui_CloseCurrentPopup(ctx) -- Close the context menu
        elseif is_key_d_pressed then
            -- Run Delete action
            unselectNonSuffixedTracks()
            deleteTrack(trackIndex)
            reaper.ImGui_CloseCurrentPopup(ctx) -- Close the context menu
        end
    end

    reaper.ImGui_EndPopup(ctx)
end

local function swapTracks(sourceTrackIndex, targetTrackIndex, dropPosition, shift, ctrl, ctrlShift)
    local sourceTrack = reaper.GetTrack(0, sourceTrackIndex)
    local targetTrack = reaper.GetTrack(0, targetTrackIndex)

    if not sourceTrack or not targetTrack then
        return false
    end

    -- Handling special clone actions with ctrl or ctrlShift
    if ctrl or ctrlShift then
        cloneDuplicateTrack(targetTrackIndex - 1)
        -- return false
    end

    -- Get the folder depth of both tracks
    local sourceTrackDepth = reaper.GetMediaTrackInfo_Value(sourceTrack, "I_FOLDERDEPTH")
    local targetTrackDepth = reaper.GetMediaTrackInfo_Value(targetTrack, "I_FOLDERDEPTH")
    sourceTrackDepth = math.max(sourceTrackDepth, 0) -- Convert negative depth to 0
    targetTrackDepth = math.max(targetTrackDepth, 0) -- Convert negative depth to 0

    -- Prevent moving across different folder depths
    if sourceTrackDepth ~= targetTrackDepth then
        return false
    end

    -- Optionally unselect all other tracks if shift is not held
    if not shift then
        reaper.Main_OnCommand(40297, 0) -- Unselect all tracks
        reaper.SetTrackSelected(sourceTrack, true) -- Select the source track
    end

    -- Determine the position to drop the source track
    if dropPosition == "above" then
        reaper.ReorderSelectedTracks(targetTrackIndex, 0) -- Move the selected track above the target track
    else
        reaper.ReorderSelectedTracks(targetTrackIndex + 1, 2) -- Move the selected track below the target track
    end

    reaper.TrackList_AdjustWindows(false) -- Update the track order in the REAPER project
    reaper.UpdateArrange() -- Refresh the GUI
    update_required = true

    -- Check if the indices have changed after the operation
    local newSourceIndex = reaper.GetMediaTrackInfo_Value(sourceTrack, "IP_TRACKNUMBER")
    local newTargetIndex = reaper.GetMediaTrackInfo_Value(targetTrack, "IP_TRACKNUMBER")

    if newSourceIndex ~= sourceTrackIndex or newTargetIndex ~= targetTrackIndex then
        return newSourceIndex -- Return the new track index of the dropped track
    else
        return nil
    end
end

local function obj_Parent_Channel_Button(ctx, track, actualTrackIndex, buttonIndex, mouse, patternItems, track_count, colorValues, mouse, keys)

    local cursorPosX, cursorPosY = reaper.ImGui_GetCursorScreenPos(ctx)

    -- Assuming 'images' table contains your image references and their sizes
    local image = selectedChannelButton == actualTrackIndex and images.Channel_button_on or images.Channel_button_off

    -- Draw the image
    reaper.ImGui_Image(ctx, image.i, image.x, image.y)

    reaper.ImGui_SameLine(ctx)
    adjustCursorPos(ctx, - image.x - 7, -5)

    reaper.ImGui_InvisibleButton(ctx, '##' .. actualTrackIndex, image.x, image.y + 5)

    local buttonName = shorten_name(channel.GUID.name[buttonIndex] or " ", track_suffix) 
    if buttonIndex == 0 then 
        buttonName = 'Patterns SEQ'
    end

    -- Calculate the position for the centered text
    local buttonWidth, buttonHeight = images.Channel_button_on.x, images.Channel_button_on.y
    local textWidth, textHeight = reaper.ImGui_CalcTextSize(ctx, buttonName)

    -- Calculate the centered position for the text
    local textPosX = cursorPosX + (buttonWidth - textWidth) / 2
    local textPosY = cursorPosY + (buttonHeight - textHeight) / 2

    -- Draw the text on the draw list
    reaper.ImGui_DrawList_AddTextEx(drawList, font_SidebarButtons, fontSize, textPosX, textPosY, colorValues.color36_channelbutton_text, buttonName, nil)

    if active_lane and mouse.isMouseDownR then
        local dragged = true
    end
    
    -- local contextMenuID = "##ChannelButtonContextMenu" 
    local contextMenuID = "##ChannelButtonContextMenu" .. tostring(buttonIndex)

    if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsItemClicked(ctx, 1) then
        if not keys.shiftDown then
            unselectAllTracks()
        end
        reaper.SetTrackSelected(track, true)
        reaper.ImGui_OpenPopup(ctx, contextMenuID)
    end
    
    if reaper.ImGui_BeginPopup(ctx, contextMenuID, reaper.ImGui_WindowFlags_NoMove()) then
        obj_Channel_Button_Menu(ctx, actualTrackIndex, contextMenuID, patternItems, track_count)
        menu_open[buttonIndex] = true
    elseif not reaper.ImGui_IsPopupOpen(ctx, contextMenuID) then
        menu_open[buttonIndex] = false
    end
end
-- Channel Button
local function obj_Channel_Button(ctx, track, actualTrackIndex, buttonIndex, mouse, patternItems, track_count, colorValues, mouse, keys)

    local cursorPosX, cursorPosY = reaper.ImGui_GetCursorScreenPos(ctx)

    -- Assuming 'images' table contains your image references and their sizes
    local image = selectedChannelButton == actualTrackIndex and images.Channel_button_on or images.Channel_button_off

    -- Draw the image
    reaper.ImGui_Image(ctx, image.i, image.x, image.y)

    reaper.ImGui_SameLine(ctx)
    adjustCursorPos(ctx, - image.x - 7, -5)

    reaper.ImGui_InvisibleButton(ctx, '##' .. actualTrackIndex, image.x, image.y + 5)
    -- Check if the button is being dragged
    if reaper.ImGui_BeginDragDropSource(ctx) then
        reaper.ImGui_SetDragDropPayload(ctx, "DND_CHANNEL_BUTTON", tostring(actualTrackIndex))
        if keys.ctrlDown then
            reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_ResizeNS())
            reaper.ImGui_Text(ctx, "Copy here")
        else
            if keys.shiftDown then
                reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_ResizeNS())
                reaper.ImGui_Text(ctx, "Move all selected tracks here")
            else
                reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_ResizeNS())
                reaper.ImGui_Text(ctx, "Move here")
            end
        end
        reaper.ImGui_EndDragDropSource(ctx)
    end
    
    local function selectChannelButton(ctx, track, actualTrackIndex, buttonIndex, shift, controlshift)
        if not (shift or controlshift) then
            unselectAllTracks()
        end
        reaper.SetTrackSelected(track, true)
        selectedChannelButton = actualTrackIndex
        selectedButtonIndex = buttonIndex
        reaper.SetExtState("McSequencer", "selectedChannelButton", tostring(selectedChannelButton), true)
        reaper.SetExtState("McSequencer", "selectedButtonIndex", tostring(buttonIndex), true)
    end
    -- Handle drag and drop target
    if reaper.ImGui_BeginDragDropTarget(ctx) then
        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_DragDropTarget(), colorValues.color70_transparent)
        local buttonXMin, buttonYMin = reaper.ImGui_GetItemRectMin(ctx)
        local buttonXMax, buttonYMax = reaper.ImGui_GetItemRectMax(ctx)
        local buttonHeight = buttonYMax - buttonYMin
        local dropPosition = "below" -- Default drop position is below the target track
        -- Check if the mouse is in the upper 33% of the button
        if mouse.mouse_y < buttonYMin + buttonHeight * 0.4  then
            dropPosition = "above"
        end

        local yPad = 3
        local xPad = 38

        if dropPosition == "above" then
            reaper.ImGui_DrawList_AddRectFilled(drawList, buttonXMin, buttonYMin - yPad + 5, buttonXMax, buttonYMax - xPad + 3, colorValues.color23_slider1)
        else
            reaper.ImGui_DrawList_AddRectFilled(drawList, buttonXMin, buttonYMin + xPad + 3, buttonXMax, buttonYMax + yPad + 1, colorValues.color23_slider1)
        end
        
        -- local payload_actualTrackIndex = reaper.ImGui_AcceptDragDropPayload(ctx, "DND_CHANNEL_BUTTON", nil, reaper.ImGui_DragDropFlags_AcceptBeforeDelivery())
        local payload_actualTrackIndex = reaper.ImGui_AcceptDragDropPayload(ctx, "DND_CHANNEL_BUTTON")
        
        if payload_actualTrackIndex then
            local rv, stringType, stringPayload, isPreview, isDelivery = reaper.ImGui_GetDragDropPayload(ctx)
            if rv then
                reaper.PreventUIRefresh(1)
                local newTrackIndex = swapTracks(tonumber(stringPayload), actualTrackIndex, dropPosition, keys.shiftDown, keys.ctrlDown, keys.ctrlShiftDown)
                if newTrackIndex then
                    local droppedTrack = reaper.GetTrack(0, newTrackIndex - 1)
                    if droppedTrack then
                        selectChannelButton(ctx, droppedTrack, newTrackIndex - 1, buttonIndex, keys.shiftDown)
                    end
                elseif keys.ctrlDown or keys.ctrlShiftDown then
                    -- cloneDuplicateTrack(actualTrackIndex, dropPosition)
                end
                reaper.PreventUIRefresh(-1)
            end
        end

        reaper.ImGui_PopStyleColor(ctx)
        reaper.ImGui_EndDragDropTarget(ctx)
    end

    local buttonName = shorten_name(channel.GUID.name[buttonIndex] or " ", track_suffix) 
    if buttonIndex == 0 then 
        buttonName = 'Patterns SEQ'
    end

    -- Calculate the position for the centered text
    local buttonWidth, buttonHeight = images.Channel_button_on.x, images.Channel_button_on.y
    local textWidth, textHeight = reaper.ImGui_CalcTextSize(ctx, buttonName)

    -- Calculate the centered position for the text
    local textPosX = cursorPosX + (buttonWidth - textWidth) / 2
    local textPosY = cursorPosY + (buttonHeight - textHeight) / 2

    -- Draw the text on the draw list
    reaper.ImGui_DrawList_AddTextEx(drawList, font_SidebarButtons, fontSize, textPosX, textPosY, colorValues.color36_channelbutton_text, buttonName, nil)

    if reaper.ImGui_IsItemHovered(ctx) then
        if channel.GUID.name[buttonIndex] ~= nil then
            local trackSuffix = track_suffix
            local buttonName = channel.GUID.name[buttonIndex]
            local suffixLength = string.len(trackSuffix)
            if string.sub(buttonName, -suffixLength) == trackSuffix then
                buttonName = string.sub(buttonName, 1, -suffixLength - 1)
            end
            hoveredControlInfo.id = buttonName
        end
    end


    if active_lane == nil then
        if reaper.ImGui_IsItemClicked(ctx, 0) then
            reaper.SetMediaTrackInfo_Value(track, "IP_TRACKNUMBER", actualTrackIndex-2)
            selectChannelButton(ctx, track, actualTrackIndex, buttonIndex, keys.shiftDown, keys.ctrlShiftDown)
        end
    end

    local buttonXMin, buttonYMin = reaper.ImGui_GetItemRectMin(ctx)
    local buttonXMax, buttonYMax = reaper.ImGui_GetItemRectMax(ctx)
    buttonCoordinates[buttonIndex] = { minY = buttonYMin, maxY = buttonYMax }

    --find last channel button edge
    local cursorPosX, cursorPosY = reaper.ImGui_GetCursorPos(ctx)
    -- local buttonHeight = obj_y -- Assuming obj_y is the height of the button
    local buttonBottomY = cursorPosY + obj_y

    -- Check if this button is the last one and update the global variable
    if buttonIndex == #channel.GUID.trackIndex then -- Assuming this is the last index
        lastButtonBottomY = buttonBottomY 
    end

    if active_lane and mouse.isMouseDownR then
        local dragged = true
    end

    if reaper.ImGui_BeginDragDropTarget(ctx) then

        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_DragDropTarget(), colorValues.color33_channelbutton_dropped)
        local rv, count = reaper.ImGui_AcceptDragDropPayloadFiles(ctx)
        if rv then
            for i = 0, count - 1 do
                local filename
                rv, filename = reaper.ImGui_GetDragDropPayloadFile(ctx, i)

                -- Extract the name from the path and remove the .wav file extension
                local buttonName = filename:match("^.+[\\/](.+)$")
                buttonName = buttonName:gsub("%.wav$", "")

                -- Save the cleaned-up buttonName and file path to channel
                channel.GUID.name[buttonIndex] = buttonName
                channel.GUID.file_path[buttonIndex] = filename

                -- Save the updated channel data
                save_channel_data()

                -- Set the track name
                local track = reaper.GetTrack(0, actualTrackIndex)
                if track then
                    local newName = buttonName
                    local index = 2
                    while track_name_exists(newName) do
                        newName = buttonName .. "_" .. tostring(index) .. track_suf1fix
                        index = index + 1
                    end
                    reaper.GetSetMediaTrackInfo_String(track, "P_NAME", newName .. track_suffix, true)
                    -- Check for existing RS5K instance on the track
                    local rs5k_index = -1
                    for fx_index = 0, reaper.TrackFX_GetCount(track) - 1 do
                        local _, fx_name = reaper.TrackFX_GetFXName(track, fx_index, "")
                        if fx_name:sub(-6) == "(RS5K)" then
                            rs5k_index = fx_index
                            break
                        end
                    end

                    -- If RS5K is not found, add it without showing the UI
                    if rs5k_index == -1 then
                        rs5k_index = reaper.TrackFX_AddByName(track, "ReaSamplomatic5000", false, -2)
                        reaper.TrackFX_Show(track, rs5k_index, 2) -- Close the window immediately after opening
                    end

                    -- set velocity min to 0
                    reaper.TrackFX_SetParamNormalized(track, rs5k_index, 2, 0)

                    -- Load the dropped file into RS5K without floating the FX window
                    reaper.TrackFX_SetNamedConfigParm(track, rs5k_index, "FILE0", filename)

                    -- Load the dropped file into RS5K by passing it the file path
                    if rs5k_index >= 0 then
                        reaper.TrackFX_SetNamedConfigParm(track, rs5k_index, "FILE0", filename)
                        reaper.TrackFX_SetNamedConfigParm(track, rs5k_index, "DONE", "")
                    end

                    selectChannelButton(ctx, track, actualTrackIndex, buttonIndex)

                end
            end
        end

        reaper.ImGui_PopStyleColor(ctx, 1)
        reaper.ImGui_EndDragDropTarget(ctx)
    end
    
    -- local contextMenuID = "##ChannelButtonContextMenu" 
    local contextMenuID = "##ChannelButtonContextMenu" .. tostring(buttonIndex)

    if reaper.ImGui_IsItemHovered(ctx) and reaper.ImGui_IsItemClicked(ctx, 1) then
        if not keys.shiftDown then
            unselectAllTracks()
        end
        reaper.SetTrackSelected(track, true)
        reaper.ImGui_OpenPopup(ctx, contextMenuID)
    end

    
    if keys.ctrlDown and reaper.ImGui_IsItemClicked(ctx, 0) then
        if not sliderTriggered then
            triggerSlider(true, track)
            sliderTriggered = true
            triggerTime = reaper.time_precise()
        elseif sliderTriggered and (reaper.time_precise() - triggerTime) > triggerDuration then
            triggerSlider(false)
            sliderTriggered = false
        end
    end
    
    if reaper.ImGui_BeginPopup(ctx, contextMenuID, reaper.ImGui_WindowFlags_NoMove()) then
        obj_Channel_Button_Menu(ctx, actualTrackIndex, contextMenuID, patternItems, track_count)
        menu_open[buttonIndex] = true
    elseif not reaper.ImGui_IsPopupOpen(ctx, contextMenuID) then
        menu_open[buttonIndex] = false
    end
end

local function obj_Channel_Button_InBetween(ctx, track, actualTrackIndex, buttonIndex, mouse, patternItems, track_count, colorValues, mouse, keys)
    -- reaper.ImGui_Button(ctx, 'gg', 93, 16)
    reaper.ImGui_InvisibleButton(ctx, 'gg', 93, 16)

    if reaper.ImGui_IsItemHovered(ctx) then
        hoveredControlInfo.id = actualTrackIndex
    end
    
    if reaper.ImGui_BeginDragDropTarget(ctx) then
        local rv, count = reaper.ImGui_AcceptDragDropPayloadFiles(ctx)
        if rv then
            for i = 0, count - 1 do
                local filename
                rv, filename = reaper.ImGui_GetDragDropPayloadFile(ctx, i)
                insertNewTrack(filename, track_suffix, track_count, actualTrackIndex)
                -- trackWasInserted = true
                update_required = true
            end
        end
    
        reaper.ImGui_EndDragDropTarget(ctx)
    end
end

local function obj_Slider(ctx, label, currentValue, minValue, maxValue, colorSliderGrab, colorSliderGrabActive,
                          colorFrameBg, colorFrameBgHovered, colorFrameBgActive, width, framePaddingX, framePaddingY,
                          mouse, numberKeys, colorValues)
    -- Apply frame padding
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), framePaddingX, framePaddingY)

    -- Apply colors
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrab(), colorSliderGrab)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrabActive(), colorSliderGrabActive)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(), colorFrameBg)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgHovered(), colorFrameBgHovered)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgActive(), colorFrameBgActive)

    -- Set item width
    reaper.ImGui_PushItemWidth(ctx, width)

    -- Create the slider
    local changed, newValue = reaper.ImGui_SliderInt(ctx, label, currentValue, minValue, maxValue)

    -- Mouse wheel adjustment
    if reaper.ImGui_IsItemHovered(ctx) and mouse.mousewheel_v then
        local potentialNewValue = newValue + mouse.mousewheel_v
        newValue = math.min(math.max(potentialNewValue, minValue), maxValue)
        changed = true
    end

    -- Pop style colors and style var
    reaper.ImGui_PopStyleColor(ctx, 5)
    reaper.ImGui_PopStyleVar(ctx, 1)

    -- Pop item width
    reaper.ImGui_PopItemWidth(ctx)

    return changed, newValue
end

local function obj_New_Pattern(ctx, patternItems, colorValues, maxPatternNumber, track_count)
    if obj_Button(ctx, "New Pattern", false, colorValues.color34_channelbutton_active, colorValues.color32_channelbutton, colorValues.color35_channelbutton_frame, 1, 99 * size_modifier, 22 * size_modifier) then
        newPatternItem(maxPatternNumber)
    end

    if reaper.ImGui_IsItemClicked(ctx, 1) then
        reaper.ImGui_OpenPopup(ctx, 'New Pattern')
    end
    
    if reaper.ImGui_BeginPopup(ctx, 'New Pattern', reaper.ImGui_WindowFlags_NoMove()) then
        anyMenuOpen = true
        if reaper.ImGui_MenuItem(ctx, "Duplicate all to new pattern") then
            reaper.PreventUIRefresh(1)
            unselectAllTracks()
            toggleSelectTracksEndingWithSEQ()
            local selTrackCount = reaper.CountSelectedTracks(0)
            clipboard = {}
            for i = 0, selTrackCount - 1 do
                local track = reaper.GetSelectedTrack(0, i)
                local trackIndex = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1
                table.insert(clipboard, copyChannelData(trackIndex, patternSelectSlider, patternItems))
            end
            newPatternItem(maxPatternNumber)
            update_required = true
            -- patternSelectSlider = patternSelectSlider + 1
            local patternItems, patternTrackIndex, patternTrack = getPatternItems(track_count)
            pasteChannelDataToSelectedTracks(patternItems, patternSelectSlider)
            unselectAllTracks()
            reaper.PreventUIRefresh(-1)

            reaper.ImGui_CloseCurrentPopup(ctx)     -- Close the context menu
        end

        if reaper.ImGui_MenuItem(ctx, "Duplicate selected to new pattern") then
            reaper.PreventUIRefresh(1)
            unselectNonSuffixedTracks()
            local selTrackCount = reaper.CountSelectedTracks(0)
            clipboard = {}
            for i = 0, selTrackCount - 1 do
                local track = reaper.GetSelectedTrack(0, i)
                local trackIndex = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1
                table.insert(clipboard, copyChannelData(trackIndex, patternSelectSlider, patternItems))
            end
            newPatternItem(maxPatternNumber)
            update_required = true
            
            local patternItems, patternTrackIndex, patternTrack = getPatternItems(track_count)
            pasteChannelDataToSelectedTracks(patternItems, patternSelectSlider)
            reaper.PreventUIRefresh(-1)

            reaper.ImGui_CloseCurrentPopup(ctx)     -- Close the context menu
        end

        if reaper.ImGui_MenuItem(ctx, "Make selected pattern item unique") then
            reaper.PreventUIRefresh(1)
            reaper.Undo_BeginBlock()
        
            local selectedItem = reaper.GetSelectedMediaItem(0, 0)
            if selectedItem then
                local take = reaper.GetActiveTake(selectedItem)
                if take then
                    local _, currentName = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
                    if string.match(currentName, "Pattern %d+") then
                        -- Check if it's the only item with this name
                        local track = reaper.GetMediaItem_Track(selectedItem)
                        local itemCount = reaper.CountTrackMediaItems(track)
                        local isUnique = true
        
                        for i = 0, itemCount - 1 do
                            local item = reaper.GetTrackMediaItem(track, i)
                            if item ~= selectedItem then
                                local otherTake = reaper.GetActiveTake(item)
                                if otherTake then
                                    local _, otherName = reaper.GetSetMediaItemTakeInfo_String(otherTake, "P_NAME", "", false)
                                    if otherName == currentName then
                                        isUnique = false
                                        break
                                    end
                                end
                            end
                        end
        
                        if not isUnique then
                            local newPatternName = "Pattern " .. (maxPatternNumber + 1)
                            reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", newPatternName, true)
                        end
        
                        -- Select and unpool items on tracks ending with track_suffix
                        local selectedItemStart = reaper.GetMediaItemInfo_Value(selectedItem, "D_POSITION")
                        local selectedItemEnd = selectedItemStart + reaper.GetMediaItemInfo_Value(selectedItem, "D_LENGTH")
                        local trackCount = reaper.CountTracks(0)
        
                        for trackIdx = 0, trackCount - 1 do
                            local track = reaper.GetTrack(0, trackIdx)
                            local _, trackName = reaper.GetTrackName(track)
                            if string.sub(trackName, - #track_suffix) == track_suffix then
                                local itemCount = reaper.CountTrackMediaItems(track)
                                for itemIdx = 0, itemCount - 1 do
                                    local item = reaper.GetTrackMediaItem(track, itemIdx)
                                    local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                                    local itemEnd = itemStart + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
                                    if itemStart == selectedItemStart and itemEnd == selectedItemEnd then
                                        reaper.SetMediaItemSelected(item, true)
                                        reaper.Main_OnCommand(41613, 0) -- Item: Remove active take from MIDI source data pool (unpool)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        
            patternSelectSlider = maxPatternNumber + 1
        
            reaper.Undo_EndBlock("Rename selected pattern", -1)
            reaper.UpdateArrange()
            reaper.PreventUIRefresh(-1)
        end
        

        reaper.ImGui_EndPopup(ctx)
    end

    --
end

local function obj_Pattern_Length_Menu(ctx, patternItems, patternSelectSlider, lengthSlider)
    if reaper.ImGui_MenuItem(ctx, "8") then
        lengthSlider = 8
        reaper.ImGui_CloseCurrentPopup(ctx) -- Close the context menu
    end
    if reaper.ImGui_MenuItem(ctx, "16") then
        lengthSlider = 16
        reaper.ImGui_CloseCurrentPopup(ctx) -- Close the context menu
    end
    if reaper.ImGui_MenuItem(ctx, "32") then
        lengthSlider = 32
        reaper.ImGui_CloseCurrentPopup(ctx) -- Close the context menu
    end
    if reaper.ImGui_MenuItem(ctx, "64") then
        lengthSlider = 64
        reaper.ImGui_CloseCurrentPopup(ctx) -- Close the context menu
    end
    reaper.ImGui_EndPopup(ctx)
    return lengthSlider
end

-- Pattern controller
local function obj_Pattern_Controller(patternItems, ctx, mouse, keys, colorValues, track_count, maxPatternNumber)

    -- Get the last selected pattern number from REAPER's extended state or default to 1.
    local lastSelectedPattern = tonumber(reaper.GetExtState("PatternController", "lastSelectedPattern")) or 1;
    -- Use the last selected pattern number to initialize the pattern selection slider, if not already set.
    patternSelectSlider = patternSelectSlider or 1;

    -- Prepare and retrieve snapping settings from REAPER's extended state.
    local extStateSection = "PatternControllerSnapSettings";
    local snapAmount = tonumber(reaper.GetExtState(extStateSection, "snapAmount")) or 1;

    -- Retrieve and set the last length slider step from the extended state, defaulting to 1.
    local lastLengthSliderStep = tonumber(reaper.GetExtState("PatternController", "lastLengthSliderStep")) or 1;
    local lengthSliderStep = lengthSliderStep or lastLengthSliderStep;

    reaper.ImGui_SetCursorPosX(ctx, 0)
    reaper.ImGui_SetCursorPosY(ctx, 4 * size_modifier)
    reaper.ImGui_Text(ctx, 'Pattern:')
    reaper.ImGui_SameLine(ctx)

    rvp, patternSelectSlider = obj_Slider(ctx, "##Pattern Select", patternSelectSlider, 1, maxPatternNumber,
        colorValues.color32_channelbutton, colorValues.color59_button_solo_inactive,
        colorValues.color34_channelbutton_active, colorValues.color34_channelbutton_active,
        colorValues.color34_channelbutton_active,
        120 * size_modifier, 0, 4 * size_modifier, mouse, keys)

    if reaper.ImGui_IsItemHovered(ctx) then
        hoveredControlInfo.id = 'Selected Pattern'
    end

    if reaper.ImGui_IsItemClicked(ctx, 1) then
        reaper.ImGui_OpenPopup(ctx, "patternSelectMenu")
    end

    if reaper.ImGui_BeginPopup(ctx, "patternSelectMenu", reaper.ImGui_WindowFlags_NoMove()) then
        for i = 1, (maxPatternNumber + 1) - 1 do
            if reaper.ImGui_MenuItem(ctx, i) then
                patternSelectSlider = i
            end
        end
        reaper.ImGui_EndPopup(ctx)
    end

    if rvp then reaper.SetExtState("PatternController", "lastSelectedPattern", tostring(patternSelectSlider), true); end

    local selectedItem;
    local selectedItemStartPos = nil

    local patternSelected = false;

    if patternItems[patternSelectSlider] then
        local items = patternItems[patternSelectSlider]
        local numItems = #items
        for i = 1, numItems do
            local item = items[i]
            selectedItem = item
            if item ~= nil then
                local itemLength = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
                local patternStartPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                selectedItemStartPos = selectedItemStartPos or patternStartPos
                local beatsInSec = reaper.TimeMap2_beatsToTime(0, 1)
                -- Calculate the length slider value based on item length.
                lengthSlider = math.floor((itemLength / beatsInSec * time_resolution) + 0.5)

                patternSelected = true
            end
        end
    end

    local numSteps = math.floor(16 * 4 / snapAmount);

    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_Text(ctx, 'Length:')
    reaper.ImGui_SameLine(ctx)
    rvpl, lengthSlider = obj_Slider(ctx, "##Pattern Length", lengthSlider, 1, 64,
        colorValues.color32_channelbutton, colorValues.color59_button_solo_inactive,
        colorValues.color34_channelbutton_active, colorValues.color34_channelbutton_active,
        colorValues.color34_channelbutton_active,
        200 * size_modifier, 1, 4 * size_modifier, mouse, keys, colorValues)

    if rvpl then reaper.SetExtState("PatternController", "lastLengthSliderStep", tostring(lengthSliderStep), true); end

    if reaper.ImGui_IsItemHovered(ctx) then
        hoveredControlInfo.id = 'Pattern Length'
    end

    local showPopupMenu = false

    if reaper.ImGui_IsItemClicked(ctx, 1) then
        reaper.ImGui_OpenPopup(ctx, "patternLengthMenu")       
    end

    if reaper.ImGui_BeginPopup(ctx, "patternLengthMenu", reaper.ImGui_WindowFlags_NoMove()) then
        lengthSlider = obj_Pattern_Length_Menu(ctx, patternItems, patternSelectSlider, lengthSlider)
        anyMenuOpen = true
    end

    if not patternItems[patternSelectSlider] then
        local lastPatternNumber = nil
        for patternNumber = 1, #patternItems do
            if not lastPatternNumber or patternNumber > lastPatternNumber then
                lastPatternNumber = patternNumber
            end
        end
        patternSelectSlider = lastPatternNumber or 1
    end

    -- If a pattern is selected and the length slider has changed, update the length of pattern items.
    if patternSelected and prevLengthSlider ~= lengthSlider then
        local beatsInSec = reaper.TimeMap2_beatsToTime(0, 1)
        local trackCount = reaper.CountTracks(0)
        local patternTrackIdx = nil  -- Index of the track containing the pattern items

        -- Find the track index containing the pattern items
        for trackIdx = 0, trackCount - 1 do
            local track = reaper.GetTrack(0, trackIdx)
            local _, trackName = reaper.GetTrackName(track)
            if trackName == "Patterns SEQ" then
                patternTrackIdx = trackIdx
                break
            end
        end

        local function nearlyEqual(a, b, epsilon)
            local absA = math.abs(a)
            local absB = math.abs(b)
            local diff = math.abs(a - b)
        
            epsilon = epsilon or float_epsilon -- default value
        
            if (a == b) then -- shortcut, handles infinities
                return true
            elseif (a == 0 or b == 0 or (absA + absB < float_min_value)) then
                -- a or b is zero or both are extremely close to it
                -- relative error is less meaningful here
                return diff < (epsilon * float_min_value)
            else -- use relative error
                return diff < epsilon * math.max(absA, absB)
            end
        end
        

        -- if patternTrackIdx then
        --     local numPatterns = #patternItems
        --     for patternNumber = 1, numPatterns do
        --         if patternNumber == patternSelectSlider then  -- Check if the pattern is selected
        --             local items = patternItems[patternNumber]
        --             local numItems = #items
        --             for i = 1, numItems do
        --                 local patternItem = items[i]
        --                 local patternStartPos = reaper.GetMediaItemInfo_Value(patternItem, "D_POSITION")
        --                 local newLength = beatsInSec * (lengthSlider / time_resolution)
        --                 local newLength = math.min(newLength)
        --                 -- print(newLength)
        --                 -- Find the next pattern item to determine the maximum allowed length
        --                 -- local nextPatternItem = reaper.GetTrackMediaItem(reaper.GetTrack(0, patternTrackIdx), reaper.GetMediaItemInfo_Value(patternItem, "IP_ITEMNUMBER") + 1)
        --                 -- local nextPatternStartPos = nextPatternItem and reaper.GetMediaItemInfo_Value(nextPatternItem, "D_POSITION") or patternStartPos + newLength
        --                 -- local maxAllowedLength = math.min(newLength, nextPatternStartPos - patternStartPos)

        --                 -- Set the length of the pattern item and its associated items
        --                 reaper.SetMediaItemInfo_Value(patternItem, "D_LENGTH", newLength)
        --                 for trackIdx = 0, trackCount - 1 do
        --                     local track = reaper.GetTrack(0, trackIdx)
        --                     local itemCount = reaper.CountTrackMediaItems(track)

        --                     for itemIdx = 0, itemCount - 1 do
        --                         local item = reaper.GetTrackMediaItem(track, itemIdx)
        --                         local itemPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                        
        --                         -- Check if the item is associated with the selected pattern
        --                         if nearlyEqual(itemPos, patternStartPos, epsilon) then
        --                             print(item)
        --                         end
        --                         if itemPos == patternStartPos then
        --                             local _, trackName = reaper.GetTrackName(track)
        --                             if string.sub(trackName, - #track_suffix) == track_suffix then
        --                                 reaper.SetMediaItemInfo_Value(item, "D_LENGTH", newLength)
        --                             end
        --                         end
        --                     end
        --                 end
        --             end
        --         end
        --     end
        -- end

        if patternTrackIdx then
            local numPatterns = #patternItems
            for patternNumber = 1, numPatterns do
                if patternNumber == patternSelectSlider then  -- Check if the pattern is selected
                    local items = patternItems[patternNumber]
                    local numItems = #items
                    for i = 1, numItems do
                        local patternItem = items[i]
                        local patternStartPos = reaper.GetMediaItemInfo_Value(patternItem, "D_POSITION")
                        local newLength = beatsInSec * (lengthSlider / time_resolution)
                        -- Adjust the length of the pattern item
                        reaper.SetMediaItemInfo_Value(patternItem, "D_LENGTH", newLength)
        
                        for trackIdx = 0, trackCount - 1 do
                            local track = reaper.GetTrack(0, trackIdx)
                            local _, trackName = reaper.GetTrackName(track)
                            -- Check if the track name ends with track_suffix
                            if string.sub(trackName, - #track_suffix) == track_suffix then
                                local itemCount = reaper.CountTrackMediaItems(track)
        
                                for itemIdx = 0, itemCount - 1 do
                                    local item = reaper.GetTrackMediaItem(track, itemIdx)
                                    local itemPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        
                                    -- Fuzzy comparison of item positions
                                    if nearlyEqual(itemPos, patternStartPos, float_epsilon) then
                                        -- Set the length of the associated item
                                        reaper.SetMediaItemInfo_Value(item, "D_LENGTH", newLength)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        

        reaper.UpdateArrange()
    end

    -- if newPatternUpdate then 
    --     patternSelectSlider = maxPatternNumber + 1
    --     newPatternUpdate = false
    -- end

    -- Store the current length slider value for future comparisons.
    prevLengthSlider = lengthSlider;
    return selectedItemStartPos
end

local function get_pcm_source_peaks(pcmSource, disp_w)
    if not pcmSource then return nil, 0 end
    local source_rate = reaper.GetMediaSourceSampleRate(pcmSource)
    local source_length = reaper.GetMediaSourceLength(pcmSource)
    local numchannels = 2
    local peakrate = source_rate                                -- Get peaks at the source sample rate
    local starttime = 0                                         -- Start time in the source
    local numsamples = source_rate * source_length              -- Total number of samples in the entire source
    local num_samples_per_pixel = numsamples / disp_w           -- Number of samples represented by one pixel
    local effective_peakrate = peakrate / num_samples_per_pixel -- This should ensure the peaks match the display width
    -- Buffer to store peak samples
    local buf = reaper.new_array(disp_w * numchannels * 3)
    local samplesWritten = reaper.PCM_Source_GetPeaks(pcmSource, effective_peakrate, starttime, numchannels, disp_w, 0,
        buf) -- Use linear interpolation for more accurate peaks
    local spl_cnt = samplesWritten & 0xFFFFF -- Mask out the sample count from return value
    return buf, spl_cnt
end

local function build_peaks(pcmSource)
    local start = reaper.PCM_Source_BuildPeaks(pcmSource, 0)
    local built
    while built ~= 0 do
        built = reaper.PCM_Source_BuildPeaks(pcmSource, 1)
    end
    local finish = reaper.PCM_Source_BuildPeaks(pcmSource, 2)
end


local function waveformDisplay(ctx, pcm, sample_path, keys, colorValues, mouse)
    local frame_w, frame_h = reaper.ImGui_GetContentRegionAvail(ctx)

    local duration = 0.2      -- Duration in seconds

    -- Determine the number of channels in the PCM source
    local numchannels = reaper.GetMediaSourceNumChannels(pcm) or 1

    -- Adjust the peakrate based on duration and frame width
    local peakrate = frame_w / duration

    if pcm then
        local peaks, spl_cnt = get_pcm_source_peaks(pcm, frame_w, numchannels, duration)

        if sample_path and peaks and spl_cnt == 0 then
            build_peaks(pcm)
        end

        if peaks then
            local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
            local x, y = reaper.ImGui_GetCursorScreenPos(ctx)
            if x ~= 0 then
                reaper.ImGui_InvisibleButton(ctx, '##Waveform', frame_w, 100) 
            end
            local line_thickness = 1

            local scaleX = frame_w / (spl_cnt / numchannels - 1)

            -- The y-coordinate for the center line of the waveform
            local centerY = y + frame_h / 2

            for i = 0, spl_cnt / numchannels - 1 do
                local max_peak, min_peak
                if numchannels == 1 then
                    max_peak = peaks[i + 1]
                    min_peak = peaks[i + 1] + 0.001
                else
                    max_peak = peaks[i * 2 + 1]
                    min_peak = peaks[i * 2 + 2]  + 0.001
                end

                -- Calculate x positions for drawing
                local peakX = x + i * scaleX

                -- Calculate y positions for the top and bottom of the waveform
                local peak_height_top = centerY - max_peak * frame_h / 2
                local peak_height_bottom = centerY + min_peak * frame_h / 2

                -- Draw the line from the top to the bottom of the waveform
                reaper.ImGui_DrawList_AddLine(draw_list, peakX, peak_height_top, peakX, peak_height_bottom,
                    colorValues.color66_waveform, line_thickness)
            end
        end
    end
end

local function truncateText(text, maxWidth, ctx)
    local truncatedText = ""
    local textWidth = 0
    local lastSpace = 0

    for i = 1, #text do
        local char = text:sub(i, i)
        local charWidth = reaper.ImGui_CalcTextSize(ctx, char)

        if textWidth + charWidth > maxWidth then
            if lastSpace > 0 then
                truncatedText = text:sub(1, lastSpace) .. "..."
            else
                truncatedText = text:sub(1, i - 1) .. "..."
            end
            break
        end

        truncatedText = truncatedText .. char
        textWidth = textWidth + charWidth

        if char == " " then
            lastSpace = i
        end
    end

    return truncatedText
end

local function obj_Control_Sidebar(ctx, keys, colorValues, mouse)
    local xcur, ycur = reaper.ImGui_GetCursorScreenPos(ctx)

    local trackIndex = selectedChannelButton
    if trackIndex == nil then
        return
    end

    local track = reaper.GetTrack(0, trackIndex)
    if not track then
        update_required = true
        return
    end

    local fxpresent 

    local fxCount = reaper.TrackFX_GetCount(track)
    for fxIndex = 0, fxCount - 1 do
        local _, fxName = reaper.TrackFX_GetFXName(track, fxIndex)
        if fxName:find("ReaSamplOmatic5000") or fxName:find("%(RS5K%)") then
            reaper.ImGui_DrawList_AddImage(drawList, images.Sidebar_bg.i, xcur + layout.Sidebar.bg_x, ycur + layout.Sidebar.bg_y, 
            xcur + images.Sidebar_bg.x + layout.Sidebar.bg_x, ycur + images.Sidebar_bg.y+ layout.Sidebar.bg_y)
            fxpresent = true
            local ret, sampleName = reaper.TrackFX_GetNamedConfigParm(track, fxIndex, "FILE0")
            local fileName = sampleName:match("^.+[\\/](.+)$") or ""

            adjustCursorPos(ctx, layout.Sidebar.sampleTitle_x, layout.Sidebar.sampleTitle_y)

            reaper.ImGui_PushFont(ctx, font_SidebarSampleTitle)
            if ret and fileName ~= "" then
                local maxWidth = 200 -- Set the maximum width in pixels
                local textWidth = reaper.ImGui_CalcTextSize(ctx, fileName)
                if textWidth > maxWidth then
                    local truncatedText = truncateText(fileName, maxWidth, ctx)
                    reaper.ImGui_Text(ctx, truncatedText)
                else
                    reaper.ImGui_Text(ctx, fileName)
                end
            else
                reaper.ImGui_Text(ctx, "No sample loaded.")
            end
            reaper.ImGui_PopFont(ctx)

            adjustCursorPos(ctx, layout.Sidebar.waveform_Of_x, layout.Sidebar.waveform_Of_y)

            local valueStart, _, _ = reaper.TrackFX_GetParam(track, fxIndex, 13)
            local valueEnd, _, _ = reaper.TrackFX_GetParam(track, fxIndex, 14)


            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ChildBg(), colorValues.color70_transparent)
            if reaper.ImGui_BeginChild(ctx, 'Waveform', layout.Sidebar.waveform_Sz_x, layout.Sidebar.waveform_Sz_y, 0, reaper.ImGui_WindowFlags_NoScrollWithMouse() | reaper.ImGui_WindowFlags_NoScrollbar()) then
                local selected_track = track
                local selected_sample_path = sampleName

                if selected_track ~= track or selected_sample_path ~= sample_path then
                    -- Track or sample path has changed, recreate PCM source
                    local track = selected_track
                    sample_path = selected_sample_path

                    if pcm then
                        reaper.PCM_Source_Destroy(pcm)
                        pcm = nil
                    end

                    if track and sample_path then
                        pcm = reaper.PCM_Source_CreateFromFile(sample_path)
                    end
                end

                if track and sample_path then
                    waveformDisplay(ctx, pcm, sample_path, keys, colorValues, mouse)
                end

                -- adjustCursorPos(ctx, 0, -100)

                if valueStart ~= 0 then
                    local curx, cury = reaper.ImGui_GetCursorScreenPos(ctx)
                    local valueLocation = curx + valueStart * (layout.Sidebar.waveform_Sz_x )
                    reaper.ImGui_DrawList_AddRectFilled(drawList, curx, cury, valueLocation, cury - 200, colorValues.color67_waveformShading)
                    reaper.ImGui_DrawList_AddLine(drawList, valueLocation, cury, valueLocation, cury - 200, 28952562, 1)
                end

                if valueEnd ~= 1 then
                    local curx, cury = reaper.ImGui_GetCursorScreenPos(ctx)
                    local valueLocation = curx + valueEnd * (layout.Sidebar.waveform_Sz_x )
                    reaper.ImGui_DrawList_AddRectFilled(drawList, curx + layout.Sidebar.waveform_Sz_x , cury, valueLocation, cury - 200, colorValues.color67_waveformShading)
                    reaper.ImGui_DrawList_AddLine(drawList, valueLocation, cury, valueLocation, cury - 200, 28952562, 1)
                end

                if reaper.ImGui_IsItemClicked(ctx, 0) then
                    if not sliderTriggered then
                        triggerSlider(true, track)
                        sliderTriggered = true
                        triggerTime = reaper.time_precise()
                    elseif sliderTriggered and (reaper.time_precise() - triggerTime) > triggerDuration then
                        triggerSlider(false)
                        sliderTriggered = false
                    end
                end
             
                reaper.ImGui_EndChild(ctx)
            end
            reaper.ImGui_PopStyleColor(ctx, 1)
            reaper.ImGui_Dummy(ctx, 0, 6)
            adjustCursorPos(ctx, 6, 0)

            -- Previous Sample
            btnimg[1] = isClicked[1] and images.Prev_Sample_on.i or images.Prev_Sample.i
            isClicked[1] = false
            reaper.ImGui_Image(ctx, btnimg[1] , images.Prev_Sample.x, images.Prev_Sample.y)  -- Adjust position as needed
            if reaper.ImGui_IsItemClicked(ctx) then
                isClicked[1] = true  -- Set the state to true for flashing
                local newName = cycleRS5kSample(track, fxIndex, "previous")  -- Your function call
                newName = removeFileExtension(newName)
                reaper.GetSetMediaTrackInfo_String(track, "P_NAME", newName .. track_suffix, true) -- Change track name on click
            end
            if reaper.ImGui_IsItemHovered(ctx) then
                hoveredControlInfo.id = 'Previous Sample'
            end
            reaper.ImGui_SameLine(ctx) -- Place the next button on the same line
            adjustCursorPos(ctx, -8, 0)

            -- Random Sample
            btnimg[2] = isClicked[2] and images.Rnd_Sample_on.i or images.Rnd_Sample.i
            isClicked[2]= false
            reaper.ImGui_Image(ctx, btnimg[2] , images.Rnd_Sample.x, images.Rnd_Sample.y)  -- Adjust position as needed
            if reaper.ImGui_IsItemClicked(ctx) then
                isClicked[2]= true  -- Set the state to true for flashing
                newName = cycleRS5kSample(track, fxIndex, "random")  -- Your function call
                newName = removeFileExtension(newName)
                reaper.GetSetMediaTrackInfo_String(track, "P_NAME", newName .. track_suffix, true) -- Change track name on click
            end
            if reaper.ImGui_IsItemHovered(ctx) then
                hoveredControlInfo.id = 'Random Sample'
            end
            reaper.ImGui_SameLine(ctx) -- Place the next button on the same line
            adjustCursorPos(ctx, -8, 0)

            -- Next Sample
            btnimg[3]  = isClicked[3] and images.Next_Sample_on.i or images.Next_Sample.i
            isClicked[3]= false
            reaper.ImGui_Image(ctx, btnimg[3], images.Next_Sample.x, images.Next_Sample.y)  -- Adjust position as needed
            if reaper.ImGui_IsItemClicked(ctx) then
                isClicked[3]= true  -- Set the state to true for flashing
                newName = cycleRS5kSample(track, fxIndex, "next")  -- Your function call
                newName = removeFileExtension(newName)
                reaper.GetSetMediaTrackInfo_String(track, "P_NAME", newName .. track_suffix, true) -- Change track name on click
            end
            if reaper.ImGui_IsItemHovered(ctx) then
                hoveredControlInfo.id = 'Next Sample'
            end
            reaper.ImGui_SameLine(ctx) -- Place the next button on the same line
            adjustCursorPos(ctx, -8, 0)

            --Blank Button
            -- btnimg[3]  = isClicked[3] and images.Blank_Sample.i or images.Blank_Sample.i
            -- isClicked[3]= false
            reaper.ImGui_Image(ctx, images.Blank_Sample.i, images.Next_Sample.x, images.Next_Sample.y)  -- Adjust position as needed
            -- if reaper.ImGui_IsItemClicked(ctx) then
            --     isClicked[3]= true  -- Set the state to true for flashing
            --     cycleRS5kSample(track, fxIndex, "next")  -- Your function call
            -- end
            if reaper.ImGui_IsItemHovered(ctx) then
                hoveredControlInfo.id = 'Fugghedaboutit'
            end
            reaper.ImGui_SameLine(ctx) -- Place the next button on the same line
            adjustCursorPos(ctx, -8, 0)

            -- Pick Sample
            btnimg[5]  = isClicked[5] and images.Pick_Sample_on.i or images.Pick_Sample.i
            isClicked[5]= false
            reaper.ImGui_Image(ctx, btnimg[5], images.Pick_Sample.x, images.Pick_Sample.y)  -- Adjust position as needed
            if reaper.ImGui_IsItemClicked(ctx) then
                isClicked[5]= true  -- Set the state to true for flashing
                local ret, chosenFile = reaper.GetUserFileNameForRead("", "Select Sample", "")
                if ret then
                    reaper.TrackFX_SetNamedConfigParm(track, fxIndex, "FILE0", chosenFile)
                end
            end
            if reaper.ImGui_IsItemHovered(ctx) then
                hoveredControlInfo.id = 'Pick Sample'
            end
            reaper.ImGui_SameLine(ctx) -- Place the next button on the same line
            adjustCursorPos(ctx, -8, 0)

            -- Float RS5K
            btnimg[6]  = isClicked[6] and images.Float_RS5K_on.i or images.Float_RS5K.i
            isClicked[6]= false
            reaper.ImGui_Image(ctx, btnimg[6], images.Float_RS5K.x, images.Float_RS5K.y)  -- Adjust position as needed
            if reaper.ImGui_IsItemClicked(ctx) then
                isClicked[6]= true  -- Set the state to true for flashing
                local fxCount = reaper.TrackFX_GetCount(track)
                for i = 0, fxCount - 1 do
                    local _, fxName = reaper.TrackFX_GetFXName(track, i, "")
                    if fxName:find("RS5K", 1, true) then
                        reaper.TrackFX_Show(track, i, 3)
                        break
                    end
                end
            end
            if reaper.ImGui_IsItemHovered(ctx) then
                hoveredControlInfo.id = 'Float  RS5K'
            end
            adjustCursorPos(ctx, 9, 3)

            -- Sampler Controls
            -- Volume knob
            -- _, channel.GUID.volume[selectedButtonIndex] = obj_Knob2(ctx, images.Knob_2, "##Volume",
            --     channel.GUID.volume[selectedButtonIndex], params.knobVolume, mouse, keys)

            local valueVolume = reaper.GetMediaTrackInfo_Value(track, "D_VOL")
            local rvv, valueVolume = obj_Knob2(ctx, images.Knob_2, "##Volume", valueVolume, params.knobVolume, mouse,
                keys)
            setParamOnSelectedTracks(fxIndex, "vol", valueVolume, rvv and (keys.altDown or keys.shiftAltDown or keys.ctrlAltDown or keys.ctrlAltShiftDown))
            if rvv and not keys.altDown then
                reaper.SetMediaTrackInfo_Value(track, "D_VOL", valueVolume)
            end
            reaper.ImGui_SameLine(ctx)

            -- Pan knob
            -- _, channel.GUID.pan[selectedButtonIndex] = obj_Knob2(ctx, images.Knob_Pan, "##Pan",
            --     channel.GUID.pan[selectedButtonIndex], params.knobPan, mouse, keys)
            local valuePan = reaper.GetMediaTrackInfo_Value(track, "D_PAN")
            local rvp, valuePan = obj_Knob2(ctx, images.Knob_Pan, "##Pan", valuePan, params.knobPan, mouse,
                keys)
            setParamOnSelectedTracks(fxIndex, "pan", valuePan, rvp and (keys.altDown or keys.shiftAltDown or keys.ctrlAltDown or keys.ctrlAltShiftDown))
            if rvp and not keys.altDown then
                reaper.SetMediaTrackInfo_Value(track, "D_PAN", valuePan)
            end
            reaper.ImGui_SameLine(ctx)

            -- Boost knob
            local valueBoost, _, _ = reaper.TrackFX_GetParam(track, fxIndex, 0)
            local rvb, valueBoost = obj_Knob2(ctx, images.Knob_2, "##Boost (Volume)", valueBoost, params.knobBoost, mouse,
                keys)
            setParamOnSelectedTracks(fxIndex, 0, valueBoost, rvb and (keys.altDown or keys.shiftAltDown or keys.ctrlAltDown or keys.ctrlAltShiftDown))
            if rvb and not keys.altDown then
                reaper.TrackFX_SetParam(track, fxIndex, 0, valueBoost)
            end
            reaper.ImGui_SameLine(ctx)

            -- Start knob
            local rvs, valueStart = obj_Knob2(ctx, images.Knob_Teal, "##Sample Start", valueStart, params.knobStart, mouse,
                keys)
            setParamOnSelectedTracks(fxIndex, 13, valueStart, rvs and (keys.altDown or keys.shiftAltDown or keys.ctrlAltDown or keys.ctrlAltShiftDown))
            if rvs and not keys.altDown then
                reaper.TrackFX_SetParam(track, fxIndex, 13, valueStart)
            end
            reaper.ImGui_SameLine(ctx)

            -- End knob
            local rve, valueEnd = obj_Knob2(ctx, images.Knob_Teal, "##Sample End", valueEnd, params.knobEnd, mouse, keys)
            setParamOnSelectedTracks(fxIndex, 14, valueEnd, rve and (keys.altDown or keys.shiftAltDown or keys.ctrlAltDown or keys.ctrlAltShiftDown))
            if rve and not keys.altDown then
                reaper.TrackFX_SetParam(track, fxIndex, 14, valueEnd)
            end
            adjustCursorPos(ctx, 44, 28)

            -- Pitch Controls
            -- Pitch Slider
            valuePitch, _, _ = reaper.TrackFX_GetParam(track, fxIndex, 15)
            local rvp, valuePitch = obj_Knob2(ctx, images.Slider_Pitch, "##Pitch" , valuePitch, params.sliderPitch, mouse, keys)
            setParamOnSelectedTracks(fxIndex, 15, valuePitch, rvp and (keys.altDown or keys.shiftAltDown or keys.ctrlAltDown or keys.ctrlAltShiftDown))
            if rvp and not keys.altDown then
                reaper.TrackFX_SetParam(track, fxIndex, 15, valuePitch)
            end

            -- Pitch slider center line
            if valuePitch == 0.5 then
                local xoffset = 124
                local yoffset = -21
                local ysize = 14
                local xcur, ycur = reaper.ImGui_GetCursorScreenPos(ctx)
                reaper.ImGui_DrawList_AddLine(drawList, xcur + xoffset, ycur + yoffset, xcur + xoffset, ycur + yoffset + ysize, colorValues.color67_waveformShading, 1)
            end  
            
            -- Pitch text display
            local text = string.format("%.2f", (valuePitch * 96 - 48) * 1.6666)
            local textSize = reaper.ImGui_CalcTextSize(ctx, text)
            local textOffset = textSize / 2
            adjustCursorPos(ctx, 25 - textOffset, -23)
            reaper.ImGui_Text(ctx, text)

            -- Pitch Minus 12
            adjustCursorPos(ctx, 45, 6)
            btnimg[7] = isClicked[7] and images.Minus12_on.i or images.Minus12.i
            isClicked[7] = false
            reaper.ImGui_Image(ctx, btnimg[7], images.Minus12.x, images.Minus12.y)
            if reaper.ImGui_IsItemClicked(ctx) then
                isClicked[7] = true
                valuePitch = valuePitch - (12 / 160)
                valuePitch = math.max(valuePitch, .2)
                setParamOnSelectedTracks(fxIndex, 15, valuePitch, keys.altDown or keys.shiftAltDown or keys.ctrlAltDown or keys.ctrlAltShiftDown)
                if not keys.altDown then
                    reaper.TrackFX_SetParam(track, fxIndex, 15, valuePitch)
                end
            end
            if reaper.ImGui_IsItemHovered(ctx) then
                hoveredControlInfo.id = 'Pitch -12'
            end
            reaper.ImGui_SameLine(ctx)
            adjustCursorPos(ctx, -8, 0)

            -- Pitch Minus 1
            btnimg[8] = isClicked[8] and images.Minus1_on.i or images.Minus1.i
            isClicked[8] = false
            reaper.ImGui_Image(ctx, btnimg[8], images.Minus1.x, images.Minus1.y)
            if reaper.ImGui_IsItemClicked(ctx) then
                isClicked[8] = true
                valuePitch = valuePitch - (1 / 160)
                valuePitch = math.max(valuePitch, .2)
                setParamOnSelectedTracks(fxIndex, 15, valuePitch, keys.altDown or keys.shiftAltDown or keys.ctrlAltDown or keys.ctrlAltShiftDown)
                if not keys.altDown then
                    reaper.TrackFX_SetParam(track, fxIndex, 15, valuePitch)
                end
            end
            if reaper.ImGui_IsItemHovered(ctx) then
                hoveredControlInfo.id = 'Pitch -1'
            end
            reaper.ImGui_SameLine(ctx)
            adjustCursorPos(ctx, -8, 0)

            -- Pitch Randomization
            btnimg[9] = isClicked[9] and images.Rnd_Sample_Sidebar_on.i or images.Rnd_Sample_Sidebar.i
            isClicked[9] = false
            reaper.ImGui_Image(ctx, btnimg[9], images.Rnd_Sample_Sidebar_on.x, images.Rnd_Sample_Sidebar.y)
            if reaper.ImGui_IsItemClicked(ctx) then
                isClicked[9] = true
                valueSnap = 0.480 + math.random() * 0.03
                setParamOnSelectedTracks(fxIndex, 15, valueSnap, keys.altDown or keys.shiftAltDown or keys.ctrlAltDown or keys.ctrlAltShiftDown)
                if not (keys.altDown or keys.shiftAltDown or keys.ctrlAltDown or keys.ctrlAltShiftDown) then
                    reaper.TrackFX_SetParam(track, fxIndex, 15, valueSnap)
                end
            end
            if reaper.ImGui_IsItemClicked(ctx, 1) then
                valueSnap = 0.4 + math.random() * 0.2
                setParamOnSelectedTracks(fxIndex, 15, valueSnap, keys.altDown or keys.shiftAltDown or keys.ctrlAltDown or keys.ctrlAltShiftDown)
                if not keys.altDown then
                    reaper.TrackFX_SetParam(track, fxIndex, 15, valueSnap)
                end
            end
            if reaper.ImGui_IsItemHovered(ctx) then
                hoveredControlInfo.id = 'Randomize Pitch, right click for greater range'
            end
            reaper.ImGui_SameLine(ctx)
            adjustCursorPos(ctx, -8, 0)

            -- Pitch Plus 1
            btnimg[10] = isClicked[10] and images.Plus1_on.i or images.Plus1.i
            isClicked[10] = false
            reaper.ImGui_Image(ctx, btnimg[10], images.Plus1_on.x, images.Plus1_on.y)
            if reaper.ImGui_IsItemClicked(ctx) then
                isClicked[10] = true
                valuePitch = valuePitch + (1 / 160)
                valuePitch = math.max(valuePitch, .2)
                setParamOnSelectedTracks(fxIndex, 15, valuePitch, keys.altDown or keys.shiftAltDown or keys.ctrlAltDown or keys.ctrlAltShiftDown)
                if not keys.altDown then
                    reaper.TrackFX_SetParam(track, fxIndex, 15, valuePitch)
                end
            end
            if reaper.ImGui_IsItemHovered(ctx) then
                hoveredControlInfo.id = 'Pitch +1'
            end
            reaper.ImGui_SameLine(ctx)
            adjustCursorPos(ctx, -8, 0)

            -- Pitch Plus 12
            btnimg[11] = isClicked[11] and images.Plus12_on.i or images.Plus12.i
            isClicked[11] = false
            reaper.ImGui_Image(ctx, btnimg[11], images.Plus12_on.x, images.Plus12_on.y)
            if reaper.ImGui_IsItemClicked(ctx) then
                isClicked[11] = true
                valuePitch = valuePitch + (12 / 160)
                valuePitch = math.max(valuePitch, .2)
                setParamOnSelectedTracks(fxIndex, 15, valuePitch, keys.altDown or keys.shiftAltDown or keys.ctrlAltDown or keys.ctrlAltShiftDown)
                if not keys.altDown then
                    reaper.TrackFX_SetParam(track, fxIndex, 15, valuePitch)
                end
            end
            if reaper.ImGui_IsItemHovered(ctx) then
                hoveredControlInfo.id = 'Pitch +12'
            end

            -- ADSR Envelope Knobs
            adjustCursorPos(ctx, 9, 12)

            -- -- Attack knob
            local valueAttack, _, _ = reaper.TrackFX_GetParam(track, fxIndex, 9)
            local rvatk, valueAttack = obj_Knob2(ctx, images.Knob_Teal, "Attack", valueAttack, params.knobAttack, mouse, keys)
            setParamOnSelectedTracks(fxIndex, 9, valueAttack, rvatk and (keys.altDown or keys.shiftAltDown or keys.ctrlAltDown or keys.ctrlAltShiftDown))
            if rvatk and not keys.altDown then
                reaper.TrackFX_SetParam(track, fxIndex, 9, valueAttack)
            end
            reaper.ImGui_SameLine(ctx, 51)

            -- -- Decay knob
            local valueDecay, _, _ = reaper.TrackFX_GetParam(track, fxIndex, 24)
            local rvdcy, valueDecay = obj_Knob2(ctx, images.Knob_Teal, "Decay", valueDecay, params.knobDecay, mouse, keys)
            setParamOnSelectedTracks(fxIndex, 24, valueDecay, rvdcy and (keys.altDown or keys.shiftAltDown or keys.ctrlAltDown or keys.ctrlAltShiftDown))
            if rvdcy and not keys.altDown then
                reaper.TrackFX_SetParam(track, fxIndex, 24, valueDecay)
            end
            reaper.ImGui_SameLine(ctx, 93)

            -- Sustain knob
            local valueSustain, _, _ = reaper.TrackFX_GetParam(track, fxIndex, 25)
            local rvsus, valueSustain = obj_Knob2(ctx, images.Knob_Teal, "Sustain", valueSustain, params.knobSustain, mouse, keys)
            setParamOnSelectedTracks(fxIndex, 25, valueSustain, rvsus and (keys.altDown or keys.shiftAltDown or keys.ctrlAltDown or keys.ctrlAltShiftDown))
            if rvsus and not keys.altDown then
                reaper.TrackFX_SetParam(track, fxIndex, 25, valueSustain)
            end

            reaper.ImGui_SameLine(ctx, 135)

            -- -- Release knob
            valueRelease, _, _ = reaper.TrackFX_GetParam(track, fxIndex, 10)
            local rvrel, valueRelease = obj_Knob2(ctx, images.Knob_Teal, "Release", valueRelease, params.knobRelease, mouse, keys)
            setParamOnSelectedTracks(fxIndex, 10, valueRelease, rvrel and (keys.altDown or keys.shiftAltDown or keys.ctrlAltDown or keys.ctrlAltShiftDown))
            if rvrel and not keys.altDown then
                reaper.TrackFX_SetParam(track, fxIndex, 10, valueRelease)
            end

            -- reaper.ImGui_SameLine(ctx, 153 * size_modifier)

            -- Note Off Button
            -- local noteOffValue, _, _ = reaper.TrackFX_GetParam(track, fxIndex, 11)
            -- -- Determine the color based on the value
            -- local buttonColor = (noteOffValue == 1) and colorValues.color61_button_sidebar_active or
            --     colorValues.color62_button_sidebar_inactive
            -- if obj_Button(ctx, "N-Off", false, colorValues.color61_button_sidebar_active, colorValues.color62_button_sidebar_inactive, colorValues.color63_button_sidebar_border, 1, 44 * size_modifier, 28 * size_modifier, "Obey note-off") then
            --     --reaper.TrackFX_SetParam(track, fxIndex, 11, value)
            --     noteOffValue = 1 - noteOffValue
            --     -- Update the "Note Off" parameter with the new value
            --     reaper.TrackFX_SetParam(track, fxIndex, 11, noteOffValue)
            -- end

            
        end
    end

    if not fxpresent then 
        reaper.ImGui_PushFont(ctx, font_SidebarSampleTitle)
        adjustCursorPos(ctx, layout.Sidebar.sampleTitle_x, layout.Sidebar.sampleTitle_y)
        reaper.ImGui_Text(ctx, ' ')
        reaper.ImGui_PopFont(ctx)
    end

    if fxpresent then
        for fxIndex = 0, fxCount - 1 do
            local _, fxName = reaper.TrackFX_GetFXName(track, fxIndex, "")
            if fxName:find("Swing") then
                adjustCursorPos(ctx, 9, 16)
    
                -- Offset knob
                local valueOffset, _, _ = reaper.TrackFX_GetParam(track, fxIndex, 16)
                local rvofs, valueOffset = obj_Knob2(ctx, images.Knob_Yellow, "Offset", valueOffset, params.knobOffset, mouse, keys)
                setParamOnSelectedTracks(fxIndex, 16, valueOffset, rvofs and (keys.altDown or keys.shiftAltDown or keys.ctrlAltDown or keys.ctrlAltShiftDown))
                if rvofs and not keys.altDown then
                    reaper.TrackFX_SetParam(track, fxIndex, 16, valueOffset)
                end
                reaper.ImGui_SameLine(ctx, nil, 9)
    
                -- Swing knob
                valueSwing, _, _ = reaper.TrackFX_GetParam(track, fxIndex, 1)
                local rvswg, valueSwing = obj_Knob2(ctx, images.Knob_Yellow, "Swing", valueSwing, params.knobSwing, mouse, keys)
                setParamOnSelectedTracks(fxIndex, 1, valueSwing, rvswg and (keys.altDown or keys.shiftAltDown or keys.ctrlAltDown or keys.ctrlAltShiftDown))
                if rvswg and not keys.altDown then
                    reaper.TrackFX_SetParam(track, fxIndex, 1, valueSwing)
                end
            end
        end
    end
    reaper.ImGui_Dummy(ctx, 0, 10)
end

local function obj_PlayCursor_Buttons(ctx, mouse, keys, patternSelectSlider, colorValues)
    local track = parent.GUID[0]

    if not track or not reaper.ValidatePtr(track, "MediaTrack*") then
        return nil
    end
    
    local itemsByPattern = getItemsByPattern()
    
    local currentPatternItems = itemsByPattern[patternSelectSlider]
    if not currentPatternItems or #currentPatternItems == 0 then
        return
    end
    
    local selectedItem
    local beatsInSec = reaper.TimeMap2_beatsToTime(0, 1) / time_resolution
    local cursorPosition = reaper.GetPlayState() & 1 == 1 and reaper.GetPlayPosition() or reaper.GetCursorPosition()
    
    local numItems = #currentPatternItems
    for i = 1, numItems do
        local item = currentPatternItems[i]
        local itemPosition = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local itemLength = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        if cursorPosition >= itemPosition and cursorPosition < itemPosition + itemLength then
            selectedItem = item
            break
        end
    end
    
    selectedItem = selectedItem or currentPatternItems[1]
    
    local selectedItemPosition = reaper.GetMediaItemInfo_Value(selectedItem, "D_POSITION")
    local itemLength = reaper.GetMediaItemInfo_Value(selectedItem, "D_LENGTH")
    local lengthSlider = math.floor(itemLength / beatsInSec)
    local relativeCursorPosition = cursorPosition - selectedItemPosition
    local currentBeat = math.floor(relativeCursorPosition / beatsInSec) + 1
    local button_left, button_top = reaper.ImGui_GetCursorScreenPos(ctx)

    for i = 1, lengthSlider do
        local isActiveBeat = currentBeat == i
    
        -- Set the correct image for the button
        if isHovered.PlayCursor[i] and not isActiveBeat then
            currentImage = images.PlayCursor_hovered.i
        elseif isActiveBeat then
            currentImage = images.PlayCursor_on.i
        else
            currentImage = images.PlayCursor_off.i
        end
    
        reaper.ImGui_Image(ctx, currentImage, images.PlayCursor_off.x, images.PlayCursor_off.y)
        
        -- Calculate button positions
        local button_right = button_left + 20
        local button_bottom = button_top + 32
        local isMouseOverButton = mouse.mouse_x >= button_left and mouse.mouse_x <= button_right and
        mouse.mouse_y >= button_top and mouse.mouse_y <= button_bottom
        
        if active_lane == nil and anyMenuOpen == false and draggingNow == false then
            isHovered.PlayCursor[i] = isMouseOverButton

            -- if isMouseOverButton and mouse.drag_start_x and mouse.drag_start_y then
            --     local isDragStartOnButton = mouse.drag_start_x >= button_left and mouse.drag_start_x <= button_right and
            --                                 mouse.drag_start_y >= button_top and mouse.drag_start_y <= button_bottom
            -- end

            -- if mouse.drag_start_x and mouse.drag_start_y then

            -- local drag_area_left = math.min(mouse.drag_start_x, mouse.mouse_x)
            -- local drag_area_right = math.max(mouse.drag_start_x, mouse.mouse_x)
            -- local intersectL = rectsIntersect(drag_area_left, drag_start_y, drag_area_right, mouse.mouse_y, button_left,
            --     button_top, button_right, button_bottom)

                -- if mouse.isMouseDownL and intersectL then
                --     local newCursorPosition = selectedItemPosition + (beatsInSec * (i - 1))
                --     reaper.SetEditCurPos(newCursorPosition, true, true)
                -- end
    
            if 
            (reaper.ImGui_IsMouseDragging(ctx, 0) and isMouseOverButton) then
                local newCursorPosition = selectedItemPosition + (beatsInSec * (i - 1))
                reaper.SetEditCurPos(newCursorPosition, true, true)
            end
    
            if isMouseOverButton and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
                reaper.GetSet_LoopTimeRange(1, 1, selectedItemPosition, selectedItemPosition + itemLength, 0)
            end
    
            if reaper.ImGui_IsItemClicked(ctx,0) and isMouseOverButton and not keys.ctrlDown then
                reaper.SetEditCurPos(selectedItemPosition + (beatsInSec * (i - 1)), true, true)
            end

            -- end
        end
    
        -- Move to the next button position
        if i ~= lengthSlider then
            reaper.ImGui_SameLine(ctx, 0, 0)
            button_left = button_left + 20
        end
    end
end



local function findOrCreateMidiItem(track, note_position, item_start, item_length_secs)
    local itemCount = reaper.CountTrackMediaItems(track)
    for i = 0, itemCount - 1 do
        local item = reaper.GetTrackMediaItem(track, i)
        local itemPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local itemLength = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        local itemEnd = itemPos + itemLength

        -- Use nearlyEqual for fuzzy comparison of positions
        if nearlyEqual(itemPos, note_position, float_epsilon) or (itemPos <= note_position and note_position < itemEnd) then
            return item
        end
    end

    return reaper.CreateNewMIDIItemInProj(track, item_start, item_start + item_length_secs, false)
end




local function sequencer_Drag(mouse, keys, button_left, button_top, button_right, button_bottom, trackIndex, i, buttonId,
                              midi_item, patternItems)
                              
    if mouse.drag_start_x and mouse.drag_start_y then
        local drag_area_left = math.min(mouse.drag_start_x, mouse.mouse_x)
        local drag_area_right = math.max(mouse.drag_start_x, mouse.mouse_x)
        local intersectL = rectsIntersect(drag_area_left, drag_start_y, drag_area_right, mouse.mouse_y, button_left,
            button_top, button_right, button_bottom)


        local track = reaper.GetTrack(0, trackIndex)
        local item_start = reaper.GetMediaItemInfo_Value(patternItems[patternSelectSlider][1], "D_POSITION")
        local beatsInSec = reaper.TimeMap2_beatsToTime(0, 1)
        local item_length_secs = lengthSlider * beatsInSec / time_resolution

        -- Calculate BPM and 1/16 note length outside of the loops
        local bpm = reaper.TimeMap_GetDividedBpmAtTime(item_start)
        local beat_length_secs = 60 / bpm
        local sixteenth_note_length_secs = beat_length_secs / 8

        if trackIndex == active_lane then

            -- Process left-click events
            if mouse.isMouseDownL and intersectL and buttonStates[trackIndex][i] == false  and not leftDragging then
                if not processedButtons[buttonId] then -- If button is not processed, insert note
                    local note_position = item_start + (i - 1) * beatsInSec / time_resolution
                    local midi_item = findOrCreateMidiItem(track, note_position, item_start, item_length_secs)

                    if midi_item then
                        local take = reaper.GetMediaItemTake(midi_item, 0)
                        if take and reaper.ValidatePtr(take, "MediaItem_Take*") and reaper.TakeIsMIDI(take) then
                            local note_ppq_position = reaper.MIDI_GetPPQPosFromProjTime(take, note_position)
                            local note_end_time = note_position + sixteenth_note_length_secs
                            local note_end_ppq_position = reaper.MIDI_GetPPQPosFromProjTime(take, note_end_time)

                            reaper.MIDI_InsertNote(take, false, false, note_ppq_position, note_end_ppq_position, 0, 60,
                                100, false)
                            processedButtons[buttonId] = true -- Mark button as processed
                        end
                    end
                end
           end
  
            -- Process right-click events
            if mouse.isMouseDownR and intersectL then
                local note_position = item_start + (i - 1) * beatsInSec / time_resolution
                local midi_item = findOrCreateMidiItem(track, note_position, item_start, item_length_secs)
                if midi_item then
                    local take = reaper.GetMediaItemTake(midi_item, 0)
                    if take and reaper.ValidatePtr(take, "MediaItem_Take*") and reaper.TakeIsMIDI(take) then
                        local item_start = reaper.GetMediaItemInfo_Value(midi_item, "D_POSITION")
                        local item_end = item_start + reaper.GetMediaItemInfo_Value(midi_item, "D_LENGTH")
                        local tolerance = beatsInSec / (time_resolution * 2)
                        local startTime = math.max(item_start, note_position - tolerance)
                        local endTime = math.min(item_end, note_position + tolerance)
                        local startPPQ = reaper.MIDI_GetPPQPosFromProjTime(take, startTime)
                        local endPPQ = reaper.MIDI_GetPPQPosFromProjTime(take, endTime)
                        deleteMidiNotesInArea(take, startPPQ, endPPQ)
                    end
                end
            end
            -- Process right-click events
            if keys.shiftDown and mouse.isMouseDownL and intersectL then
                deleteMidiNote(trackIndex, i, patternSelectSlider, patternItems)
                processedButtons[buttonId] = nil -- Reset button state on right-click
            end
        end
    end 


    -- if keys.altDown then
    --     -- Use current mouse position for intersection check
    --     local intersectL = rectsIntersect(mouse.mouse_x, mouse.mouse_y, mouse.mouse_x, mouse.mouse_y, button_left,
    --         button_top, button_right, button_bottom)
    
    --     local track = reaper.GetTrack(0, trackIndex)
    --     local item_start = reaper.GetMediaItemInfo_Value(patternItems[patternSelectSlider][1], "D_POSITION")
    --     local beatsInSec = reaper.TimeMap2_beatsToTime(0, 1)
    --     local item_length_secs = lengthSlider * beatsInSec / time_resolution
    
    --     local bpm = reaper.TimeMap_GetDividedBpmAtTime(item_start)
    --     local beat_length_secs = 60 / bpm
    --     local sixteenth_note_length_secs = beat_length_secs / 4
    
    --     -- Update note_subdivision based on mouse wheel movement
    --     local mouse_wheel_movement = mouse.mousewheel_v
    --     if mouse_wheel_movement ~= 0 and intersectL then
    --         note_subdivision = math.max(1, math.min(4, note_subdivision + mouse_wheel_movement))
    --     end
    
    --     if intersectL and not processedButtons[buttonId] then -- If button is not processed, insert note
    --         local note_position = item_start + (i - 1) * beatsInSec / time_resolution
    --         local midi_item = findOrCreateMidiItem(track, note_position, item_start, item_length_secs)
    
    --         if midi_item then
    --             local take = reaper.GetMediaItemTake(midi_item, 0)
    
    --             -- Handle note subdivision
    --             if note_subdivision >= 2 then
    --                 local subdivision_interval = (sixteenth_note_length_secs * 2) / note_subdivision
    --                 for sub = 0, note_subdivision - 1 do
    --                     local sub_note_position = note_position + sub * subdivision_interval
    --                     local sub_note_end_position = sub_note_position + subdivision_interval
    --                     local sub_note_ppq_position = reaper.MIDI_GetPPQPosFromProjTime(take, sub_note_position)
    --                     local sub_note_end_ppq_position = reaper.MIDI_GetPPQPosFromProjTime(take, sub_note_end_position)
    
    --                     reaper.MIDI_InsertNote(take, false, false, sub_note_ppq_position, sub_note_end_ppq_position, 0, 60,
    --                         100, false)
    --                 end
    --             end
    --         end
    --     end
    -- end

    if not keys.altDown then 
        note_subdivision = 1
    end

    -- Handle mouse release events
    if (mouse.mouseReleasedL or mouse.mouseReleasedR) and active_lane ~= nil then
        if mouse.mouseReleasedL then
            insertMidiPooledItems(active_lane, patternSelectSlider, patternItems)
        end
        if mouse.mouseReleasedR then
            local track = reaper.GetTrack(0, active_lane)
            undoPoint('Delete MIDI Notes', track, midi_item)
        end
        selectOnlyTrack(active_lane)
        active_lane = nil
        processedButtons = {} -- Reset the processed buttons on mouse release
    end
end


-- sequencer buttons step sequencer buttons
local function obj_Sequencer_Buttons(ctx, trackIndex, mouse, keys, pattern_item,
                                     pattern_start, pattern_end, midi_item, note_positions, note_velocities, patternItems,
                                     colorValues, note_pitches)
    if not (trackIndex and pattern_item and reaper.GetTrack(0, trackIndex)) then
        return note_positions, note_velocities, note_pitches
    end

    local step_duration = reaper.TimeMap2_beatsToTime(0, 1) / time_resolution
    local adjusted_step_duration = step_duration * 0.49
    local step_start_points = {}

    for i = 1, lengthSlider do
        step_start_points[i] = pattern_start + (i - 1) * step_duration
    end

    local button_left, button_top = reaper.ImGui_GetCursorScreenPos(ctx)
    local button_top = button_top - 39
    local button_bottom = button_top + 39

    active_lane_locked = active_lane_locked or nil    

    for i = 1, lengthSlider do

        reaper.ImGui_SameLine(ctx, 0, 0)

        buttonStates[trackIndex][i] = false
        step_start = step_start_points[i]
        step_end = step_start + step_duration

        local note_positions_length = #note_positions
        for j = 1, note_positions_length do
            local pos = note_positions[j]
            if pos >= (step_start - adjusted_step_duration) and pos < (step_end - adjusted_step_duration) then
                buttonStates[trackIndex][i] = true
                break
            end
        end

        -- for _, pos in ipairs(note_positions) do
        --     if pos >= (step_start - adjusted_step_duration) and pos < (step_end - adjusted_step_duration) then
        --         buttonStates[trackIndex][i] = true
        --         break
        --     end
        -- end

        local isDarkerBlock = ((i - 1) // time_resolution) % 2 == 0
        local colorBlue = isDarkerBlock and images.Step_odd_off.i  or images.Step_even_off.i 
        local colorDarkBlue = isDarkerBlock and images.Step_odd_on.i  or images.Step_even_on.i 
        local step_img = buttonStates[trackIndex][i] and colorDarkBlue or colorBlue
        -- local active = buttonStates[trackIndex][i]
        -- local note_count = countNotesInStep(note_positions, step_start, step_end) -- Function to count notes in the step

        -- local buttonWidth, buttonHeight = obj_x, obj_y
        -- if note_count > 1 then
        --     buttonWidth = buttonWidth / 2
        -- end

        -- for n = 1, note_count do
        --     if n > 1 then
        --         reaper.ImGui_SameLine(ctx)
        --         local cursor = reaper.ImGui_GetCursorPosX(ctx)
        --         reaper.ImGui_SetCursorPosX(ctx, cursor - (n*4))

        -- end
        if i == 1 then
            adjustCursorPos(ctx, 3, 0)
        end
        -- lastButtonX, lastButtonY = reaper.ImGui_GetCursorScreenPos(ctx)
        reaper.ImGui_Image(ctx, step_img, images.Step_odd_off.x, images.Step_odd_off.y)

        
        if anyMenuOpen == false then

            local button_left = button_left + 250 + (i*20)
            local button_right = button_left + 20

            local isMouseOverButton = mouse.mouse_x >= button_left and mouse.mouse_x <= button_right and
                                    mouse.mouse_y >= button_top and mouse.mouse_y <= button_bottom

            -- Handle drag start
            if isMouseOverButton and mouse.drag_start_x and mouse.drag_start_y then
                local isDragStartOnButton = mouse.drag_start_x >= button_left and mouse.drag_start_x <= button_right and
                                            mouse.drag_start_y >= button_top and mouse.drag_start_y <= button_bottom
                if drag_started and isMouseOverButton and isDragStartOnButton then
                    active_lane_locked = trackIndex
                end
            end

            -- Assign active_lane only when the drag starts
            if drag_started and active_lane_locked and not active_lane then
                active_lane = active_lane_locked
            end

            if not mouse.isMouseDownL or mouse.isMouseDownR then
                active_lane_locked = nil
            end
            
            sequencer_Drag(mouse, keys, button_left, button_top, button_right, button_bottom, trackIndex, i,
                trackIndex .. '_' .. i, midi_item, patternItems)
        end
    end
    -- reaper.ImGui_EndGroup(ctx)
    return note_positions, note_velocities, note_pitches
end

function countNotesInStep(note_positions, step_start, step_end)
    local count = 0
    local numNotePositions = #note_positions
    for i = 1, numNotePositions do
        local pos = note_positions[i]
        if pos >= step_start and pos < step_end then
            count = count + 1
        end
    end
    return math.max(1, count)  -- Ensure at least 1 is returned
end


local function obj_SidebarResize(ctx, value, mouse, keys)

    reaper.ImGui_Button(ctx, '##SidebarResize', 6, -1)
    local newValue

    if reaper.ImGui_IsItemHovered(ctx) then
        
        reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_ResizeEW())
        hoveredControlInfo.id = 'Expand Sliders'
    end

    if reaper.ImGui_IsItemClicked(ctx, 0)  then
        timeToDrag = true
    end

    if mouse.isMouseDownL and timeToDrag then
        newValue = mouse.delta_x
        draggingNow = true
    end

    if timeToDrag and not mouse.isMouseDownL then
        -- channel.GUID.expand.resizing[i] = false
        draggingNow = false
    end

    value = newValue

    return value
end

local function obj_Expand(ctx, value, track, mouse, keys)

    local is_active = (value == 1)
    local img = is_active and images.Expand_on.i or images.Expand_off.i 
    reaper.ImGui_Image(ctx, img, images.Expand_on.x, images.Expand_off.y)

    if reaper.ImGui_IsItemClicked(ctx) then 
        value = is_active and 0 or 1 -- Toggle value between 0 and 1
    end

    if keys.ctrlDown and reaper.ImGui_IsItemClicked(ctx) then
        for key, value in pairs(channel.GUID.expand.open) do
            channel.GUID.expand.open[key] = 0
        end
        -- value = 0
    end

    if reaper.ImGui_IsItemHovered(ctx) then
        hoveredControlInfo.id = 'Expand Sliders'
    end
    
    return tonumber(value)
end

local function obj_ExpandResize(ctx, value, i, mouse, keys, x)

    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), colorValues.color24_slider2)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), colorValues.color23_slider1)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), colorValues.color23_slider1)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), colorValues.color24_slider2)
    reaper.ImGui_Button(ctx, '##ExpandResize'.. i, 240, 4)
    reaper.ImGui_PopStyleColor(ctx, 4)
    local newValue

    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_ResizeNS())
        hoveredControlInfo.id = 'Expand Sliders'
    end

    if reaper.ImGui_IsItemClicked(ctx, 0)  then
        channel.GUID.expand.resizing[i] = true
    end

    if mouse.isMouseDownL and channel.GUID.expand.resizing[i] then
        newValue = mouse.delta_y
        draggingNow = true
    end

    if channel.GUID.expand.resizing[i] and not mouse.isMouseDownL then
        channel.GUID.expand.resizing[i] = false
        draggingNow = false
    end

    if newValue then
        value = value + newValue
        if value < 30 then
            value = 30
        end
    end

    return value
end



local function obj_ExpandSelector(ctx, value, track, mouse, keys, id)
    local id = tostring(id)
    local img = is_active and images.Expand_selector.i or images.Expand_selector.i 
    reaper.ImGui_Image(ctx, img, images.Expand_selector.x, images.Expand_selector.y)

    if not value then value = "Velocity" end
    -- reaper.ImGui_Button(ctx, value, images.Expand_selector.x, images.Expand_selector.y)
    
    
    if reaper.ImGui_IsItemClicked(ctx) then 
        -- value = is_active and 0 or 1 -- Toggle value between 0 and 1
        reaper.ImGui_OpenPopup(ctx, id)
    end
    
    
    if reaper.ImGui_BeginPopup(ctx, id, reaper.ImGui_WindowFlags_NoMove()) then
        -- value, rv = obj_Knob_Menu(ctx, value)
        if reaper.ImGui_MenuItem(ctx, "Velocity") then
            value = "Velocity"
            reaper.ImGui_CloseCurrentPopup(ctx) -- Close the context menu
        end
        if reaper.ImGui_MenuItem(ctx, "Pitch") then
            value = "Pitch"
            reaper.ImGui_CloseCurrentPopup(ctx) -- Close the context menu
        end
        if reaper.ImGui_MenuItem(ctx, "Offset") then
            value = "Offset"
            reaper.ImGui_CloseCurrentPopup(ctx) -- Close the context menu
        end
        reaper.ImGui_EndPopup(ctx)
    end
    
    if reaper.ImGui_IsItemHovered(ctx) then
        hoveredControlInfo.id = 'Expand Selector'
    end

    reaper.ImGui_SameLine(ctx)
    adjustCursorPos(ctx, -71, 4)
    reaper.ImGui_Text(ctx, value)

    
    return value
end

local function unMuteAllTracks()
    local trackCount = reaper.CountTracks(0)
    for i = 0, trackCount - 1 do
        local otherTrack = reaper.GetTrack(0, i)
        reaper.SetMediaTrackInfo_Value(otherTrack, "B_MUTE", 0)
    end
end

local function unSoloAllTracks()
    reaper.PreventUIRefresh(1)
    local trackCount = reaper.CountTracks(0)
    for i = 0, trackCount - 1 do
        local otherTrack = reaper.GetTrack(0, i)
        reaper.SetMediaTrackInfo_Value(otherTrack, "I_SOLO", 0)
    end
    reaper.PreventUIRefresh(-1)
end

-- local dragInitialState = nil  -- Store the initial state at the start of a drag

local function obj_muteButton(ctx, value, track, mouse, keys, trackIndex)
    local is_active = (value == 1)
    local img = is_active and images.Mute_on.i or images.Mute_off.i
    local cursor_x, cursor_y = reaper.ImGui_GetCursorScreenPos(ctx)
    reaper.ImGui_Image(ctx, img, images.Mute_off.x, images.Mute_off.y)

    local button_left = cursor_x
    local button_top = cursor_y
    local button_right = button_left + images.Mute_off.x - 1
    local button_bottom = button_top + images.Mute_off.y

    -- reaper.ImGui_DrawList_AddRectFilled(drawList, button_left, button_top, button_right, button_bottom, 33111)

    if reaper.ImGui_IsItemClicked(ctx) then
        if keys.ctrlAltDown then
            unMuteAllTracks()
            value = 1 -- Mute this track
            reaper.SetMediaTrackInfo_Value(track, "B_MUTE", value)
            update_required = true
        elseif keys.ctrlDown then
            unMuteAllTracks()
        else
            -- Normal click, toggle mute
            value = is_active and 0 or 1
            reaper.SetMediaTrackInfo_Value(track, "B_MUTE", value)
        end
    end

    if  mouse.drag_start_x and mouse.drag_start_y and
        ((mouse.drag_start_x >= button_left) and (mouse.drag_start_x <= button_right) and
            (mouse.drag_start_y <= button_bottom) and (mouse.drag_start_y >= button_top)) then
        dragStartedOnAnyMuteButton = true
        dragMuteState = reaper.GetMediaTrackInfo_Value(track, "B_MUTE")
        draggingNow = true

    else
        if mouse.mouseReleasedL then
            dragStartedOnAnyMuteButton = false
            dragMuteState = nil
        end
    end

    local targetValue = dragMuteState

    if active_lane == nil and anyMenuOpen == false and dragStartedOnAnyMuteButton == true then
        local drag_area_left = math.min(mouse.drag_start_x or 0, mouse.mouse_x or 0)
        local drag_area_right = math.max(mouse.drag_start_x or 0, mouse.mouse_x or 0)
        local drag_area_top = math.min(mouse.drag_start_y or 0, mouse.mouse_y or 0)
        local drag_area_bottom = math.max(mouse.drag_start_y or 0, mouse.mouse_y or 0)
        
        local intersect = drag_area_right >= button_left and drag_area_left <= button_right and
                           drag_area_bottom >= button_top and drag_area_top <= button_bottom

        if intersect then
            if not channel.GUID.dragged[trackIndex] then
                channel.GUID.dragged[trackIndex] = true
                if track ~= parent.GUID[0] then
                    reaper.SetMediaTrackInfo_Value(track, "B_MUTE", targetValue)
                    value = targetValue
                    img = targetValue == 1 and images.Mute_on.i or images.Mute_off.i
                end
            end
        end
    end

    if mouse.mouseReleasedL then
        mouse.drag_start_x, mouse.drag_start_y = nil, nil
        dragInitialState = nil
        dragStartedOnAnySelector = false
        for i = 1, #channel.GUID.dragged do
            channel.GUID.dragged[i] = false
        end

    end

    return tonumber(value)
end

local function obj_soloButton(ctx, value, track, mouse, keys, trackIndex)

    local is_active = (value == 2)
    local img = is_active and images.Solo_on.i or images.Solo_off.i
    local cursor_x, cursor_y = reaper.ImGui_GetCursorScreenPos(ctx)
    reaper.ImGui_Image(ctx, img, images.Solo_on.x, images.Solo_off.y)

    local button_left = cursor_x
    local button_top = cursor_y
    local button_right = button_left + images.Solo_off.x
    local button_bottom = button_top + images.Solo_off.y

    -- reaper.ImGui_DrawList_AddRectFilled(drawList, button_left, button_top, button_right, button_bottom, 222)

  

    if reaper.ImGui_IsItemClicked(ctx) then
        if keys.ctrlAltDown then
            
            unSoloAllTracks()
            value = 2 -- Solo this track
            reaper.SetMediaTrackInfo_Value(track, "I_SOLO", value)
        elseif keys.ctrlDown then
            unSoloAllTracks()
        else

            -- Normal click, toggle mute
            value = is_active and 0 or 2
            reaper.SetMediaTrackInfo_Value(track, "I_SOLO", value)

        end
    end

    if mouse.drag_start_x and mouse.drag_start_y and
        ((mouse.drag_start_x >= button_left) and (mouse.drag_start_x <= button_right) and
            (mouse.drag_start_y <= button_bottom) and (mouse.drag_start_y >= button_top)) then
        dragStartedOnAnySoloButton = true
        dragMuteState = reaper.GetMediaTrackInfo_Value(track, "I_SOLO")
        draggingNow = true
    else
        if mouse.mouseReleasedL then
            dragStartedOnAnySoloButton = false
            dragMuteState = nil
        end
    end
    
    local targetValue = dragMuteState
    
    if active_lane == nil and anyMenuOpen == false and dragStartedOnAnySoloButton == true then

        local drag_area_left = math.min(mouse.drag_start_x or 0, mouse.mouse_x or 0)
        local drag_area_right = math.max(mouse.drag_start_x or 0, mouse.mouse_x or 0)
        local drag_area_top = math.min(mouse.drag_start_y or 0, mouse.mouse_y or 0)
        local drag_area_bottom = math.max(mouse.drag_start_y or 0, mouse.mouse_y or 0)
        
        local intersect = drag_area_right >= button_left and drag_area_left <= button_right and
        drag_area_bottom >= button_top and drag_area_top <= button_bottom
        
        if intersect then
            if not channel.GUID.dragged[trackIndex] then
                channel.GUID.dragged[trackIndex] = true
                if track ~= parent.GUID[0] then
                    reaper.SetMediaTrackInfo_Value(track, "I_SOLO", targetValue)
                    value = targetValue
                    img = targetValue == 2 and images.Solo_on.i or images.Solo_off.i
                end
            end
        end
    end
    
    if mouse.mouseReleasedL then
        mouse.drag_start_x, mouse.drag_start_y = nil, nil
        dragInitialState = nil
        dragStartedOnAnySelector = false
        for i = 1, #channel.GUID.dragged do
            channel.GUID.dragged[i] = false
        end
        draggingNow = false

    end

    return tonumber(value)
end



local function obj_Add_Channel_Button(track_suffix, ctx, count_tracks, colorValues)
    -- reaper.ImGui_Dummy(ctx, 0,0)
    -- reaper.ImGui_SameLine(ctx, 118 * size_modifier)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), colorValues.color35_channelbutton_frame)
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameBorderSize(), 1)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), colorValues.color34_channelbutton_active)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), colorValues.color32_channelbutton)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), colorValues.color34_channelbutton_active)
    local rv2 = reaper.ImGui_Button(ctx, '+', 95 * size_modifier, 24 * size_modifier)
    reaper.ImGui_PopStyleColor(ctx, 4)
    reaper.ImGui_PopStyleVar(ctx, 1)

    if rv2 then
        local numSelectedTracks = reaper.CountSelectedTracks(0)
        if numSelectedTracks > 0 then
            for i = 0, numSelectedTracks - 1 do
                local track = reaper.GetSelectedTrack(0, i)
                local _, track_name = reaper.GetTrackName(track)
                if not string.find(track_name, track_suffix .. "$") then
                    -- Append the suffix if it's not already there
                    reaper.GetSetMediaTrackInfo_String(track, "P_NAME", track_name .. track_suffix, true)
                end
            end
            trackWasInserted = true
            update_required = true
        end
    end



    if reaper.ImGui_BeginDragDropTarget(ctx) then
        local rv, count = reaper.ImGui_AcceptDragDropPayloadFiles(ctx)
        if rv then
            for i = 0, count - 1 do
                local filename
                rv, filename = reaper.ImGui_GetDragDropPayloadFile(ctx, i)
                insertNewTrack(filename, track_suffix, count_tracks, nil)
                update_required = true
            end
            trackWasInserted = true
        end
        reaper.ImGui_EndDragDropTarget(ctx)
    end
    

    if reaper.ImGui_IsItemHovered(ctx) or reaper.ImGui_IsItemActive(ctx) then
        hoveredControlInfo.id = "Click to add selected track to McSequencer, or drag wav files here"
    end
end

local function obj_Invisible_Channel_Button(track_suffix, ctx, count_tracks, colorValues, window_height)

    local avail_w, avail_h = reaper.ImGui_GetContentRegionAvail(ctx)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(),
        reaper.ImGui_GetStyleColor(ctx, reaper.ImGui_Col_TextDisabled()))
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), 0)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0)
    reaper.ImGui_SetCursorPosX(ctx,  reaper.ImGui_GetCursorPosX(ctx) + reaper.ImGui_GetScrollX(ctx))
    reaper.ImGui_Button(ctx, 'Drag files here to create tracks', avail_w, math.max(50, avail_h) - 18)
    reaper.ImGui_PopStyleColor(ctx, 4)

    if reaper.ImGui_BeginDragDropTarget(ctx) then
        local rv, count = reaper.ImGui_AcceptDragDropPayloadFiles(ctx)
        if rv then
            for i = 0, count - 1 do
                local filename
                rv, filename = reaper.ImGui_GetDragDropPayloadFile(ctx, i)
                insertNewTrack(filename, track_suffix, count_tracks, nil)
                trackWasInserted = true
                update_required = true
            end
        end
    
        reaper.ImGui_EndDragDropTarget(ctx)
    end
end

-- Function to toggle the selection state of tracks in a range
function toggleSelectTracksInRange(selectedTrackIndex)
    -- Determine the current selection state of the clicked track
    local clickedTrack = reaper.GetTrack(0, selectedTrackIndex)
    local isClickedTrackSelected = reaper.IsTrackSelected(clickedTrack)

    -- Get the index of the first and last selected tracks
    local firstSelectedIndex, lastSelectedIndex = getFirstAndLastSelectedTrackIndices()

    -- Determine the range to select
    local startIndex = math.min(firstSelectedIndex, selectedTrackIndex)
    local endIndex = math.max(lastSelectedIndex, selectedTrackIndex)

    -- Set the selection state of tracks in the range based on the clicked track's state
    for i = startIndex, endIndex do
        local track = reaper.GetTrack(0, i)
        if track then
            reaper.SetTrackSelected(track, not isClickedTrackSelected)
        end
    end
end

-- Function to get the indices of the first and last selected tracks
function getFirstAndLastSelectedTrackIndices()
    local firstIndex, lastIndex
    local count = reaper.CountTracks(0)
    for i = 0, count - 1 do
        local track = reaper.GetTrack(0, i)
        if reaper.IsTrackSelected(track) then
            if not firstIndex then firstIndex = i end
            lastIndex = i
        end
    end
    return firstIndex or 0, lastIndex or 0
end

local function obj_Selector(ctx, trackIndex, track, width, height, color, border_size, border_color, roundness, mouse, keys)
    local track = reaper.GetTrack(0, trackIndex)
    if not track then
        return
    end
 
    -- Initial button state based on track selection
    local isSelected = reaper.IsTrackSelected(track)

    local button_size_offset = 5
    local border_size_offset = 4
    -- local draw_list = reaper.ImGui_GetWindowDrawList(ctx)

    -- Get cursor position
    local cursor_x, cursor_y = reaper.ImGui_GetCursorScreenPos(ctx)

    -- Calculate the positions of the button
    local button_left = cursor_x + 3        
    local button_top = cursor_y  - 3
    local button_right = button_left + width 
    local button_bottom = button_top + height + 4

    -- Draw the square using drawlist
    -- reaper.ImGui_DrawList_AddRectFilled(drawList, button_left, button_top, button_right, button_bottom, color, roundness)

    -- Draw the selected background if the track is selected
    if isSelected then
        reaper.ImGui_Image(ctx, images.Selector_on.i, images.Selector_on.x, images.Selector_on.y)
    else
        reaper.ImGui_Image(ctx, images.Selector_off.i, images.Selector_off.x, images.Selector_off.y)
    end

    -- Audio indicator rectangle
    local audioPeakL = reaper.Track_GetPeakInfo(track, 0)
    local audioPeakR = reaper.Track_GetPeakInfo(track, 1)
    local audioPeak = math.max(audioPeakL, audioPeakR)

    local audioThreshold = 0.01 -- Threshold for detecting audio signal
    if audioPeak > audioThreshold then
        local scaleFactor = .6
        local minAlpha = 0.1
        local audioIndicatorAlpha = math.min(1.0, minAlpha + (1 - minAlpha) * (audioPeak ^ scaleFactor))

        local audioIndicatorColor = reaper.ImGui_ColorConvertDouble4ToU32(0.6, 0.99, 0.0, audioIndicatorAlpha)
        reaper.ImGui_DrawList_AddRectFilled(drawList, button_left + button_size_offset ,
            button_top + button_size_offset + 2, button_right - button_size_offset ,
            button_bottom - button_size_offset - 1, audioIndicatorColor, 1)
    end

    local drag_distance_squared
    local minimum_distance_squared

    -- Calculate the squared distance to avoid the cost of a square root unless necessary
    if mouse.drag_start_x and mouse.drag_start_y then
     drag_distance_squared = ((mouse.mouse_x - mouse.drag_start_x) ^ 2) + ((mouse.mouse_y - mouse.drag_start_y) ^ 2)
     minimum_distance_squared = 5 ^ 2 -- Square of minimum drag distance

    end

    -- Check if the mouse is being dragged and the drag started on the selector control
    if mouse.drag_start_x and mouse.drag_start_y and drag_distance_squared > minimum_distance_squared and ((mouse.drag_start_x >= button_left) and (mouse.drag_start_x <= button_right) and
            (mouse.drag_start_y <= button_bottom) and (mouse.drag_start_y >= button_top)) then
        dragStartedOnAnySelector = true
        draggingNow = true
    else
        if reaper.ImGui_IsMouseReleased(ctx, 0) then
            dragStartedOnAnySelector = false
            draggingNow = false
        end
    end

    if reaper.ImGui_IsItemClicked(ctx, 0) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
        reaper.SetTrackSelected(track, true)
        toggleSelectTracksEndingWithSEQ(true)
    end

    if reaper.ImGui_IsItemClicked(ctx, 0) and not dragStartedOnAnySelector and not reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
        if keys.ctrlDown then
            reaper.SetTrackSelected(track, not isSelected)
        elseif keys.shiftDown then
            local lastSelectedTrackIndex = -1
            local numTracks = reaper.CountTracks(0)
            
            -- Loop through all tracks to find the last selected track
            for i = 0, numTracks - 1 do
                local track = reaper.GetTrack(0, i)
                if reaper.IsTrackSelected(track) and i > lastSelectedTrackIndex then
                    lastSelectedTrackIndex = i  -- Update lastSelectedTrackIndex only if the current index is greater
                end
            end
            
            if lastSelectedTrackIndex ~= -1 then
                local startIndex = math.min(trackIndex, lastSelectedTrackIndex)
                local endIndex = math.max(trackIndex, lastSelectedTrackIndex)
                
                -- Select all tracks from startIndex to endIndex
                for i = startIndex, endIndex do
                    local track = reaper.GetTrack(0, i)
                    reaper.SetTrackSelected(track, true)
                end
            end
        else
            unselectAllTracks()
            reaper.SetTrackSelected(track, true)
        end
    end

    if active_lane == nil and anyMenuOpen == false and dragStartedOnAnySelector == true then
        if mouse.drag_start_y and mouse.mouse_y then
            local drag_area_top = math.min(mouse.drag_start_y, mouse.mouse_y)
            local drag_area_bottom = math.max(mouse.drag_start_y, mouse.mouse_y)

            -- Check if the button intersects with the drag area
            local intersect = drag_area_top <= button_bottom and drag_area_bottom >= button_top

            -- print('intersect: ' .. tostring(intersect))

            -- Select or deselect the track based on the intersection
            if intersect then
                reaper.SetTrackSelected(track, true)
            else
                if not (keys.ctrlDown or keys.shiftDown) then
                    reaper.SetTrackSelected(track, false)
                end
            end
        end
    end
    -- Reset the drag start position when the mouse is released
    if mouse.mouseReleasedL then
        mouse.drag_start_x, mouse.drag_start_y = nil, nil
    end

end

----- TIME SIGNATURE -----

local function findTempoMarkerFromPosition(position)
    local numTempoMarkers = reaper.CountTempoTimeSigMarkers(0)

    local prevMarkerIndex = -1
    local prevMarkerTime = -1
    local prevTimesigNum = nil
    local prevTimesigDenom = nil

    for i = 0, numTempoMarkers - 1 do
        local retval, timepos, measurepos, beatpos, bpm, timesig_num, timesig_denom, lineartempo = reaper
        .GetTempoTimeSigMarker(0, i)
        if timepos <= position then
            prevMarkerIndex = i
            prevMarkerTime = timepos
            prevTimesigNum = timesig_num
            prevTimesigDenom = timesig_denom
        else
            break
        end
    end

    if prevMarkerIndex == -1 then
        return nil, "No previous tempo marker found."
    else
        return prevMarkerIndex, prevMarkerTime, prevTimesigNum, prevTimesigDenom
    end
end

---- MOUSE & KEYBAORD MANAGEMENT  ---------------------------------

local function mouseTrack(ctx)
    local mousewheel_v, mousewheel_h = reaper.ImGui_GetMouseWheel(ctx)
    local mouse_x, mouse_y = reaper.ImGui_GetMousePos(ctx)
    local delta_x, delta_y = reaper.ImGui_GetMouseDelta(ctx)
    local isMouseDownL = reaper.ImGui_IsMouseDown(ctx, 0)
    local isMouseDownR = reaper.ImGui_IsMouseDown(ctx, 1)
    local mouseReleasedL = false
    local mouseReleasedR = false

    -- Handle drag start
    if isMouseDownL or isMouseDownR then
        if not drag_start_x and not drag_start_y then
            drag_start_x = mouse_x
            drag_start_y = mouse_y
            drag_started = true
        end
    else
        -- Handle drag end
        if drag_started then
            drag_started = false
            -- Add any additional code you want to run when the drag ends
        end
        drag_start_x = nil
        drag_start_y = nil
    end

    -- Check if the left mouse was previously down and now it's up
    if wasMouseDownL and not isMouseDownL then
        mouseReleasedL = true
    end

    -- Check if the right mouse was previously down and now it's up
    if wasMouseDownR and not isMouseDownR then
        mouseReleasedR = true
    end

    -- Update the 'wasMouseDown' variables at the end of the function
    wasMouseDownL = isMouseDownL
    wasMouseDownR = isMouseDownR

    return {
        mouse_x = mouse_x,
        mouse_y = mouse_y,
        isMouseDownL = isMouseDownL,
        isMouseDownR = isMouseDownR,
        drag_start_x = drag_start_x,
        drag_start_y = drag_start_y,
        mouseReleasedL = mouseReleasedL,
        mouseReleasedR = mouseReleasedR,
        mousewheel_v = mousewheel_v,
        mousewheel_h = mousewheel_h,
        delta_x = delta_x,
        delta_y = delta_y
    }
end



local function keyboard_shortcuts(ctx, patternItems, maxPatternNumber)
    local keyMods = reaper.ImGui_GetKeyMods(ctx)
    local altDown = keyMods == reaper.ImGui_Mod_Alt()
    local ctrlDown = keyMods == reaper.ImGui_Mod_Ctrl()
    local shiftDown = keyMods == reaper.ImGui_Mod_Shift()
    local ctrlShiftDown = keyMods == reaper.ImGui_Mod_Ctrl() | reaper.ImGui_Mod_Shift()
    local ctrlAltDown = keyMods == reaper.ImGui_Mod_Ctrl() | reaper.ImGui_Mod_Alt()
    local shiftAltDown = keyMods == reaper.ImGui_Mod_Shift() | reaper.ImGui_Mod_Alt()
    local ctrlAltShiftDown = keyMods == reaper.ImGui_Mod_Ctrl() | reaper.ImGui_Mod_Shift() | reaper.ImGui_Mod_Alt()

    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then
        open = false
    end

    -- Numpad plus select next pattern
    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_KeypadAdd())  then
        patternSelectSlider = patternSelectSlider + 1
    end

    -- Numpad minus select previous pattern
    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_KeypadSubtract())  then
        if patternSelectSlider ~= 1 then
            patternSelectSlider = patternSelectSlider - 1
        end
    end

    -- F4 create new pattern
    if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_F4()) then
        newPatternItem(maxPatternNumber)
        -- newPatternUpdate = true
    end

    if anyMenuOpen == false then
        if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_1()) then
            goToLoopStart()
        end

        -- if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_V()) and not ctrlDown then
        --     show_VelocitySliders = not show_VelocitySliders
        -- end

        triggerSliderWithQKey(ctx)

        if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_UpArrow()) and not altDown then
            goToPreviousTrack(shiftDown)
        end

        if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_DownArrow()) and not altDown then
            goToNextTrack(shiftDown)
        end

        -- Handle Spacebar (Transport Stop/Play)
        if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Space()) then
            if not spacebarPressed then
                spacebarPressed = true    -- Update the state to pressed
                if reaper.GetPlayState() ~= 0 then
                    reaper.CSurf_OnStop() -- Stop the transport
                else
                    reaper.CSurf_OnPlay() -- Start the transport
                end
            end
        elseif reaper.ImGui_IsKeyReleased(ctx, reaper.ImGui_Key_Space()) then
            spacebarPressed = false -- Update the state to not pressed
        end

        if altDown then
            -- Alt + Up Arrow (Move Tracks Up)
            if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_UpArrow()) then
                moveTracksUpWithinFolders()
                update_required = true
            end
            -- Alt + Down Arrow (Move Tracks Down)
            if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_DownArrow()) then
                moveTracksDownWithinFolders()
                update_required = true
            end
        end

        if ctrlDown then
            -- Ctrl + C (Copy)
            if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_C()) then
                clipboard = {}
                unselectNonSuffixedTracks()
                local selTrackCount = reaper.CountSelectedTracks(0)
                for i = 0, selTrackCount - 1 do
                    local track = reaper.GetSelectedTrack(0, i)
                    local trackIndex = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1
                    table.insert(clipboard, copyChannelData(trackIndex, patternSelectSlider, patternItems))
                end
                -- Ctrl + X (Cut)
            elseif reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_X()) then -- Ctrl + X (Cut)
                clipboard = {}
                unselectNonSuffixedTracks()
                local selTrackCount = reaper.CountSelectedTracks(0)
                for i = 0, selTrackCount - 1 do
                    local track = reaper.GetSelectedTrack(0, i)
                    local trackIndex = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") - 1
                    table.insert(clipboard, copyChannelData(trackIndex, patternSelectSlider, patternItems))
                    removeChannelData(trackIndex, patternSelectSlider, patternItems)
                end
                local track = reaper.GetSelectedTrack(0, 0)
                if track then 
                    local item = reaper.GetTrackMediaItem(track, 0)
                    undoPoint('Cut MIDI Notes', track, item)
                end
                -- Ctrl + V (Paste)
            elseif reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_V()) then
                unselectNonSuffixedTracks()
                if #clipboard > 0 then -- Check if clipboard contains notes
                    pasteChannelDataToSelectedTracks(patternItems, patternSelectSlider)
                end
            elseif reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_RightArrow()) then
                shiftNotes(1, patternItems, patternSelectSlider)
            elseif reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_LeftArrow()) then
                shiftNotes(-1, patternItems, patternSelectSlider)
            end
        end

        if shiftDown then
            if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_RightArrow()) then
                shiftNotes(1, patternItems, patternSelectSlider)
            elseif reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_LeftArrow()) then
                shiftNotes(-1, patternItems, patternSelectSlider)
            end
        end
    end

    return {
        altDown = altDown,
        shiftDown = shiftDown,
        ctrlDown = ctrlDown,
        ctrlShiftDown = ctrlShiftDown,
        shiftAltDown = shiftAltDown,
        ctrlAltDown = ctrlAltDown,
        ctrlAltShiftDown = ctrlAltShiftDown

    }
end



----- PREFERENCES ------

local function obj_Preferences(ctx)
    -- Check if the Preferences popup should be shown
    if showPreferencesPopup then
        
        -- Store the original settings before any changes are made
        originalLeftClickDelete = leftClickDelete
        -- originalSizeModifier = size_modifier
        -- originalObjX = obj_x
        -- originalObjY = obj_y
        originalTimeRes = time_resolution
        originalfindTempoMarker = vfindTempoMarker
        originalFontSize = fontSize
        originalFontSidebarSize = fontSidebarButtonsSize

        -- Calculate and set the next window position
        local win_x, win_y = reaper.ImGui_GetWindowPos(ctx)
        local win_w, win_h = reaper.ImGui_GetWindowSize(ctx)
        local center_x = win_x + win_w / 2
        local center_y = win_y + win_h / 2
        reaper.ImGui_SetNextWindowPos(ctx, center_x, center_y, reaper.ImGui_Cond_Appearing(), 0.5, 0.5)

        reaper.ImGui_OpenPopup(ctx, 'PreferencesPopup')
        showPreferencesPopup = false -- Reset the flag
    end

    if reaper.ImGui_BeginPopupModal(ctx, 'PreferencesPopup', nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then
        anyMenuOpen = true

        -- if reaper.ImGui_Checkbox(ctx, 'Left Click Delete', leftClickDelete) then
        --     leftClickDelete = not leftClickDelete -- Set vfindTempoMarker based on the new state
        -- end

        -- reaper.ImGui_SameLine(ctx)
        -- reaper.ImGui_Text(ctx, '(?)')
        -- if reaper.ImGui_IsItemHovered(ctx) then
        --     reaper.ImGui_SetTooltip(ctx, "Left clicks or drags on sequener buttons that have notes in them will start deleting notes. Useful for laptop trackpad users.")
        -- end

        -- local scalingFactor = 0.1
        -- local sliderIntValue = math.floor(size_modifier / scalingFactor + 0.5)
        -- local minValue = math.floor(0.8 / scalingFactor)
        -- local maxValue = math.floor(3 / scalingFactor)
        -- local label = string.format('GUI Size: %.1f', size_modifier)
        -- _, sliderIntValue = reaper.ImGui_SliderInt(ctx, label, sliderIntValue, minValue, maxValue)
        -- size_modifier = sliderIntValue * scalingFactor
        -- obj_x, obj_y = math.floor(20 * size_modifier), math.floor(34 * size_modifier)

        _, fontSize = reaper.ImGui_SliderInt(ctx, 'Font Size -requires restart-', fontSize, 6, 20)
        _, fontSidebarButtonsSize = reaper.ImGui_SliderInt(ctx, 'Sidebar Font Size -requires restart-',
            fontSidebarButtonsSize, 6, 20)

        if reaper.ImGui_Checkbox(ctx, 'Track Time Signature Markers', vfindTempoMarker) then
            vfindTempoMarker = not vfindTempoMarker -- Set vfindTempoMarker based on the new state
        end

        _, time_resolution = reaper.ImGui_SliderInt(ctx, "Time resolution", time_resolution, 2, 12)

        -- if reaper.ImGui_Button(ctx, 'Reset to default', 120, 0) then
        --     local keysToDelete = { "SizeModifier", "ObjX", "ObjY", "TimeResolution", "Find Tempo Marker", "Font Size",
        --         "Font Size Sidebar Buttons", "themeLastLoadedPath" }                                                                                                      -- Replace with your actual key names

        --     for _, key in ipairs(keysToDelete) do
        --         reaper.DeleteExtState("McSequencer", key, true)
        --     end
        --     reaper.ImGui_CloseCurrentPopup(ctx)
        -- end


        -- OK button logic
        if reaper.ImGui_Button(ctx, 'OK', 120, 0) then
            -- Save the modified settings to ExtState
            
            reaper.SetExtState("McSequencer", "leftClickDelete", tostring(leftClickDelete), true)
            -- reaper.SetExtState("McSequencer", "SizeModifier", tostring(size_modifier), true)
            reaper.SetExtState("McSequencer", "ObjX", tostring(obj_x), true)
            reaper.SetExtState("McSequencer", "ObjY", tostring(obj_y), true)
            reaper.SetExtState("McSequencer", "TimeResolution", tostring(time_resolution), true)
            reaper.SetExtState("McSequencer", "Find Tempo Marker", tostring(vfindTempoMarker), true)
            reaper.SetExtState("McSequencer", "Font Size", tostring(fontSize), true)
            reaper.SetExtState("McSequencer", "Font Size Sidebar Buttons", tostring(fontSidebarButtonsSize), true)
            reaper.ImGui_CloseCurrentPopup(ctx)
        end
        reaper.ImGui_SameLine(ctx)

        -- Cancel button logic
        if reaper.ImGui_Button(ctx, 'Cancel', 120, 0) then
            -- Revert to original settings
            leftClickDelete = originalLeftClickDelete
            -- size_modifier = originalSizeModifier
            -- obj_x = originalObjX
            -- obj_y = originalObjY
            time_resolution = originalTimeRes
            vfindTempoMarker = originalfindTempoMarker
            fontSize = originalFontSize
            fontSidebarButtonsSize = originalFontSidebarSize
            reaper.ImGui_CloseCurrentPopup(ctx)
        end

        reaper.ImGui_EndPopup(ctx)
    end
end

local function getPreferences()
    -- local size_modifier = tonumber(reaper.GetExtState("McSequencer", "SizeModifier"))
    -- if not size_modifier then size_modifier = 1 end
    -- print(size_modifier)
    size_modifier = 1
    local obj_x = tonumber(reaper.GetExtState("McSequencer", "ObjX"))
    if not obj_x then obj_x = 20 end
    local obj_y = tonumber(reaper.GetExtState("McSequencer", "ObjY"))
    if not obj_y then obj_y = 34 end
    local time_resolution = tonumber(reaper.GetExtState("McSequencer", "TimeResolution"))
    if not time_resolution then time_resolution = 4 end
    local leftClickDelete = reaper.GetExtState("McSequencer", "leftClickDelete")
    local leftClickDelete = (leftClickDelete == "true") --
    if not leftClickDelete then leftClickDelete = false end
    local vfindTempoMarkerStr = reaper.GetExtState("McSequencer", "Find Tempo Marker")
    local vfindTempoMarker = (vfindTempoMarkerStr == "true") --
    if not vfindTempoMarkerStr then vfindTempoMarkerStr = false end
    local fontSize = tonumber(reaper.GetExtState("McSequencer", "Font Size"))
    if not fontSize then fontSize = 12 end
    local fontSidebarButtonsSize = tonumber(reaper.GetExtState("McSequencer", "Font Size Sidebar Buttons"))
    if not fontSidebarButtonsSize then fontSidebarButtonsSize = 12 end

    return size_modifier, obj_x, obj_y, time_resolution, vfindTempoMarker, fontSize, fontSidebarButtonsSize, leftClickDelete
end
local function obj_HoveredInfo(ctx, hoveredControlInfo)
    local displayText
    if hoveredControlInfo.id ~= "" then
        local formattedValue = ""
        local id = tostring(hoveredControlInfo.id)

        -- Determine how to format the value and whether to append a colon
        local appendColon = true

        if type(hoveredControlInfo.value) == "number" then
            formattedValue = string.format("%.3f", hoveredControlInfo.value)
        elseif type(hoveredControlInfo.value) == "boolean" then
            formattedValue = tostring(hoveredControlInfo.value)
            id = string.gsub(id, "^##", "")
        elseif type(hoveredControlInfo.value) == "string" then
            formattedValue = hoveredControlInfo.value
            appendColon = false -- Do not append colon for string values
        end

        -- Construct the display text with or without a colon
        if appendColon then
            displayText = id .. ': ' .. formattedValue
        else
            displayText = id .. ' ' .. formattedValue
        end

        -- Clear hoveredControlInfo values
        hoveredControlInfo.id = ""
        hoveredControlInfo.value = ''
    else
        displayText = " " -- Display a dummy value when there is no valid hoveredControlInfo.id
    end

    -- Display the text
    reaper.ImGui_Text(ctx, displayText)
end

local function setItemGrouping()
    -- Define the command ID for the action
    local commandID = 1156 -- Options: Toggle item grouping and track media/razor edit grouping

    -- Get the toggle state of the action
    local state = reaper.GetToggleCommandState(commandID)

    -- Check if the action is toggled off
    if state == 0 then
        -- Toggle the action on
        reaper.Main_OnCommand(commandID, 0)
    end
end

----- MAIN --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

setItemGrouping()
SetButtonState(1)
reaper.atexit(Exit)
reaper.Undo_BeginBlock()
create_or_find_track(target_track_name, 1, track_suffix)
create_pattern_item_if_not_exist(track_suffix)
reaper.Undo_EndBlock('Sequencer Initialize', -1)
update_channel_data_from_reaper(track_suffix, track_count)
clear_extstate_channel_data()
retrieveExtState()
load_channel_data()
local colorValues = colors.colorUpdate()
params.getinfo(script_path, modules_path, themes_path)
size_modifier, obj_x, obj_y, time_resolution, vfindTempoMarker, fontSize, fontSidebarButtonsSize, leftClickDelete = getPreferences()
local font_path = script_path .. "/Fonts/Inter.ttc"
local font = reaper.ImGui_CreateFont(font_path, fontSize)
font_SidebarSampleTitle = reaper.ImGui_CreateFont(font_path, fontSidebarButtonsSize + 4)
font_SidebarButtons = reaper.ImGui_CreateFont(font_path, fontSidebarButtonsSize)
font_SliderValue = reaper.ImGui_CreateFont(font_path, 10)
reaper.ImGui_Attach(ctx, font)
reaper.ImGui_Attach(ctx, font_SidebarSampleTitle)
reaper.ImGui_Attach(ctx, font_SidebarButtons )
reaper.ImGui_Attach(ctx, font_SliderValue )

if not selectedButtonIndex then
    local selectedTrack = reaper.GetSelectedTrack(0, 0) -- Get the first selected track
    if selectedTrack then
        selectedButtonIndex = reaper.GetMediaTrackInfo_Value(selectedTrack, "IP_TRACKNUMBER")
    end
end

-- local clipper = reaper.ImGui_CreateListClipper(ctx)
-- reaper.ImGui_Attach(ctx, clipper)
local FLT_MIN, FLT_MAX = reaper.ImGui_NumericLimits_Float()
reaper.ImGui_SetConfigVar(ctx, reaper.ImGui_ConfigVar_WindowsMoveFromTitleBarOnly(), 1) -- move from title bar only
windowflags = reaper.ImGui_WindowFlags_NoScrollbar() | reaper.ImGui_WindowFlags_NoScrollWithMouse() |
reaper.ImGui_WindowFlags_MenuBar() | reaper.ImGui_WindowFlags_NoCollapse()


----------------------------------------------------------------------------
----- GUI LOOP -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------
function loop()
    if showColorPicker then
        colorValues = colors.colorUpdate()
    end
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowMinSize(), 642, 250)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(), colorValues.color1_bg);
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBg(), colorValues.color2_titlebar);
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBgActive(), colorValues.color3_titlebaractive);
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ScrollbarBg(), colorValues.color4_scrollbar);
    reaper.ImGui_PushFont(ctx, font);


    visible, open = reaper.ImGui_Begin(ctx, "McSequencer (" .. versionNumber .. ')', true, windowflags);
    drawList = reaper.ImGui_GetWindowDrawList(ctx)
    anyMenuOpen = isAnyMenuOpen(menu_open)
    -- printTable(menu_open)

    if visible then
         track_count = reaper.CountTracks(0)
        local patternItems, patternTrackIndex, patternTrack, maxPatternNumber = getPatternItems(track_count)
        
        local mouse = mouseTrack(ctx)
        local keys = keyboard_shortcuts(ctx, patternItems, maxPatternNumber)
        local channel = update(ctx, track_count, track_suffix, channel)
        local window_width = reaper.ImGui_GetWindowWidth(ctx)
        local window_height = reaper.ImGui_GetWindowHeight(ctx)
        if window_height > 512 then
            controlSidebarWidth = 208
        else
            controlSidebarWidth = 220
        end


        ----- MENU BAR -----
        if reaper.ImGui_BeginMenuBar(ctx) then
            if reaper.ImGui_BeginMenu(ctx, "Options") then
                if reaper.ImGui_MenuItem(ctx, "Preferences") then
                    showPreferencesPopup = true
                end
                reaper.ImGui_Separator(ctx)
                local action_state = reaper.GetToggleCommandState(1156)
                local is_checked = (action_state == 1)
                if reaper.ImGui_MenuItem(ctx, 'Item Grouping', '', is_checked) then
                    reaper.Main_OnCommand(1156, 0) -- 1156 is the command ID for the toggle action
                end
                reaper.ImGui_Separator(ctx)
                if reaper.ImGui_MenuItem(ctx, "Show Theme Editor") then
                    showColorPicker = not showColorPicker
                end
                if reaper.ImGui_MenuItem(ctx, "Show FPS") then
                    showFPS = not showFPS
                end

                reaper.ImGui_EndMenu(ctx)
            end

            if showFPS then
                reaper.ImGui_SetCursorPosX(ctx, window_width - 55)
                reaper.ImGui_Text(ctx, 'FPS: ' .. math.floor((reaper.ImGui_GetFramerate(ctx))))
            end;
            reaper.ImGui_EndMenuBar(ctx)
        end

        obj_Preferences(ctx)

        ----- TOP ROW -----
        reaper.ImGui_Dummy(ctx, 0, 2)
        local tableflags0 = nil;
        if reaper.ImGui_BeginChild(ctx, 'Top Row', nil, top_row_x * size_modifier, 0, reaper.ImGui_WindowFlags_NoScrollbar() | reaper.ImGui_WindowFlags_NoScrollWithMouse()) then
            -- color picker
            if showColorPicker then
                colors.obj_ColorPicker(ctx);
                top_row_x = 420
            else
                top_row_x = 30
            end;

            reaper.ImGui_SameLine(ctx);

            local selectedItemStartPos = obj_Pattern_Controller(patternItems, ctx,
                mouse, keys, colorValues, track_count, maxPatternNumber);

            if vfindTempoMarker and selectedItemStartPos then
                local index, time, timesigNum, timesigDenom = findTempoMarkerFromPosition(selectedItemStartPos)
                if index then
                    time_resolution = timesigNum
                end
            end

            reaper.ImGui_SameLine(ctx);

            obj_New_Pattern(ctx, patternItems, colorValues, maxPatternNumber, track_count)

            reaper.ImGui_SameLine(ctx);
            -- reaper.ImGui_Button(ctx, 'associated', 2111, 22)

            -- --test
            -- reaper.ImGui_SameLine(ctx);
            -- if  obj_Button(ctx,"Test", false, colorValues.color61_button_sidebar_active, colorValues.color62_button_sidebar_inactive, colorValues.color63_button_sidebar_border, 1, 99, 23) then      --
            --     for k, v in pairs(_G) do
            --         print(k, v)
            --     end
            -- end


            reaper.ImGui_EndChild(ctx)
        end


        if reaper.ImGui_BeginChild(ctx, "Middle Row", -controlSidebarWidth - 14, 42, false,  reaper.ImGui_WindowFlags_NoScrollbar() | reaper.ImGui_WindowFlags_NoScrollWithMouse()) then

            local parentIndex = parent.GUID.trackIndex[0]
            local track = parent.GUID[0]

            reaper.ImGui_Dummy(ctx, 0, 0)
            reaper.ImGui_SameLine(ctx, 0, 3 * size_modifier);
            adjustCursorPos(ctx, 0, 9)

            -- parent.GUID.expand.open[1] = obj_Expand(ctx, parent.GUID.expand.open[1], track, mouse,
            --     keys)
            reaper.ImGui_SameLine(ctx, 0, 22 * size_modifier);
            adjustCursorPos(ctx, 0, 5)

            -- Mute Button
            parent.GUID.mute[0] = obj_muteButton(ctx, parent.GUID.mute[0], parent.GUID[0], mouse, keys, parentIndex)
            reaper.ImGui_SameLine(ctx, 0, 3 * size_modifier);
            adjustCursorPos(ctx, -3, 5)

            -- Solo Button
            parent.GUID.solo[0] = obj_soloButton(ctx, parent.GUID.solo[0], parent.GUID[0], mouse, keys, parentIndex)
            reaper.ImGui_SameLine(ctx, 0, 5 * size_modifier);
            -- if size_modifier >= 1.3 then adjustCursorPos(ctx, 0, 6 * size_modifier) end
            -- adjustCursorPos(ctx, 0, -18)

            -- Volume Knob
            _, parent.GUID.volume[0] = obj_Knob2(ctx, images.Knob_2, "##Volume", parent.GUID.volume[0],
                params.knobVolume, mouse, keys)

            reaper.ImGui_SameLine(ctx, 0, 5 * size_modifier);
            -- if size_modifier >= 1.3 then adjustCursorPos(ctx, 0, 2 * size_modifier) end

            -- Pan Knob
            _, parent.GUID.pan[0] = obj_Knob2(ctx, images.Knob_Pan, '##Pan', parent.GUID.pan[0], params.knobPan,
                mouse, keys)
            reaper.ImGui_SameLine(ctx, 0, 2 * size_modifier);
            -- adjustCursorPos(ctx, 0, -9)

            -- Channel Button
            obj_Parent_Channel_Button(ctx, track, parentIndex, 0, mouse, patternItems, track_count, colorValues, mouse, keys);
            -- reaper.ImGui_SameLine(ctx, 0, 0);
            -- adjustCursorPos(ctx, 0, -9)

            -- Selector
            -- obj_Selector(ctx, parentIndex, parent.GUID[0], obj_x, obj_y, colorValues.color30_selector, 3,
            --     colorValues.color31_selector_frame, 0,
            --     mouse, keys);
            reaper.ImGui_SameLine(ctx, 0, 26 * size_modifier);
            -- adjustCursorPos(ctx, 0, -9)

            -- play cursor buttons
            obj_PlayCursor_Buttons(ctx, mouse, keys, patternSelectSlider, colorValues);
            -- reaper.ImGui_SameLine(ctx, 0, 1 * size_modifier);
            -- reaper.ImGui_Button(ctx, 'hh', 10, 10)
            -- adjustCursorPos(ctx, 0, 1)

            -- adjustCursorPos(ctx, 0, -9)

            -- reaper.ImGui_Dummy(ctx, 0, 0)
            -- if reaper.GetExtState("McSequencer", "ScrollX") then
            --     seqScrollXExt = tonumber(reaper.GetExtState("McSequencer", "ScrollX"))
            --     if seqScrollXExt then
            --         reaper.ImGui_SetScrollX(ctx, seqScrollXExt)
            --     end
            -- end
            reaper.ImGui_EndChild(ctx)
            
        end
        
        reaper.ImGui_SameLine(ctx, 0, 18)
        if reaper.ImGui_BeginChild(ctx, "Sidebar Selector Buttons", 220, 36, false) then

            -- buttonXSize = 68
            -- buttonYSize = 36
            -- reaper.ImGui_Button(ctx, 'Sample', buttonXSize, buttonYSize)
            -- reaper.ImGui_SameLine(ctx)
            -- adjustCursorPos(ctx, -8, 0)
            -- reaper.ImGui_Button(ctx, 'Slider', buttonXSize, buttonYSize)
            -- reaper.ImGui_SameLine(ctx)
            -- adjustCursorPos(ctx, -8, 0)
            -- reaper.ImGui_Button(ctx, 'FX', buttonXSize, buttonYSize)

            reaper.ImGui_EndChild(ctx)
        end

            --         --- DELETE POPUP ------
            -- if showPopup then
            --     unselectNonSuffixedTracks()
            --     local track_count = reaper.CountSelectedTracks(0)
            --     confirmed = popup
               
            --     if confirmed then
            --         deleteTrack(trackIndex)
            --     end
            -- end

            
        
        -- if reaper.ImGui_IsAnyItemHovered(ctx) then
        --     sequencerFlags = reaper.ImGui_WindowFlags_NoScrollWithMouse() |
        --         reaper.ImGui_WindowFlags_HorizontalScrollbar()
        -- else
        --     sequencerFlags = reaper.ImGui_WindowFlags_HorizontalScrollbar()
        -- end
        -- reaper.ImGui_Dummy(ctx, 0, 4)

        local firstCursorX, firstCursorY = reaper.ImGui_GetCursorScreenPos(ctx)


        -- if itemBlockScroll == true then

            sequencerFlags = reaper.ImGui_WindowFlags_NoScrollWithMouse() |
                    reaper.ImGui_WindowFlags_HorizontalScrollbar()

        -- else
        --     sequencerFlags = reaper.ImGui_WindowFlags_HorizontalScrollbar()
        -- end
        
        
        
        if reaper.ImGui_BeginChild(ctx, "Sequencer Row", -controlSidebarWidth, -27, false, sequencerFlags) then
            
            -- seqScrollX = reaper.ImGui_GetScrollX(ctx)
            -- if seqScrollX ~= 0 then
            --     reaper.SetExtState("McSequencer", "ScrollX", tostring(seqScrollX), true)
            --     print(seqScrollX)
            -- end

            local isHovered = reaper.ImGui_IsWindowHovered(ctx, reaper.ImGui_HoveredFlags_ChildWindows())

            
            for i = 1, channel.channel_amount do
                if channel.GUID.expand.open[i] == 1 then
                    expandedSliderSizes[i] = channel.GUID.expand.spacing[i] or 200  -- Default size or specific expanded size
                else
                    expandedSliderSizes[i] = 0  -- No expansion
                end
            end
            
            
            reaper.ImGui_Dummy(ctx, 0, -4)


            if channel and channel.channel_amount then
                for i = 1, channel.channel_amount do

                    local xRegionAvail = reaper.ImGui_GetContentRegionAvail(ctx)
                    local heightWithSlider = 32 + expandedSliderSizes[i]  -- Add slider height to row height
                    local visibleRow = reaper.ImGui_IsRectVisible(ctx, xRegionAvail, heightWithSlider)
                    
                    if visibleRow then
                        local x, y = reaper.ImGui_GetWindowContentRegionMax(ctx)
                        local track = channel.GUID[i - 1]
                        if not track then return end
                        local actualTrackIndex = channel.GUID.trackIndex[i];
                        local pattern_item, pattern_start, pattern_end, midi_item = getSelectedPatternItemAndMidiItem(
                            actualTrackIndex, patternItems, patternSelectSlider)
                        local note_positions, note_velocities, note_pitches = populateNotePositions(midi_item)

 
                        -- enable mousehweel scroll while holding control
                        if isHovered and mouse.mousewheel_v and itemBlockScroll == false and  draggingNow ~= true and active_lane == nil then
                            local scrollY = reaper.ImGui_GetScrollY(ctx)
                            -- reaper.ImGui_SetScrollY(ctx, scrollY - mouse.mousewheel_v * 65)
                            reaper.ImGui_SetScrollY(ctx, scrollY - mouse.mousewheel_v * 36)

                        end

                        reaper.ImGui_Dummy(ctx, 0, 0)
                        reaper.ImGui_SameLine(ctx, 0, 4 * size_modifier);

                        adjustCursorPos(ctx, -1, 9)

                        -- Expand Sliders Button
                        channel.GUID.expand.open[i] = obj_Expand(ctx, channel.GUID.expand.open[i], track, mouse,
                            keys)
                        reaper.ImGui_SameLine(ctx, 0, 3 * size_modifier);
                        adjustCursorPos(ctx, 0, 5)
                        

                        -- Mute Button
                        channel.GUID.mute[i] = obj_muteButton(ctx, channel.GUID.mute[i], track, mouse, keys, channel.GUID.trackIndex[i])
                        reaper.ImGui_SameLine(ctx, 0, 3 * size_modifier);
                        adjustCursorPos(ctx, -3, 5)


                        -- Solo Button
                        channel.GUID.solo[i] = obj_soloButton(ctx, channel.GUID.solo[i], track, mouse, keys, channel.GUID.trackIndex[i])
                        reaper.ImGui_SameLine(ctx, 0, 5 * size_modifier);
                        if size_modifier >= 1.3 then adjustCursorPos(ctx, 0, 2 * size_modifier) end

                        -- Volume Knob
                        -- _, channel.GUID.volume[i] = obj_Knob2(ctx, images.Knob_2, "##Volume" .. i,
                        --     channel.GUID.volume[i], params.knobVolume, mouse, keys)

                        local valueVolume = reaper.GetMediaTrackInfo_Value(track, "D_VOL")
                        local rvv, valueVolume = obj_Knob2(ctx, images.Knob_2, "##Volume" ..i, valueVolume, params.knobVolume, mouse,
                            keys)
                        setParamOnSelectedTracks(fxIndex, "vol", valueVolume, rvv and (keys.altDown or keys.shiftAltDown or keys.ctrlAltDown or keys.ctrlAltShiftDown))
                        if rvv and not keys.altDown then
                            reaper.SetMediaTrackInfo_Value(track, "D_VOL", valueVolume)
                        end
                        reaper.ImGui_SameLine(ctx, 0, 5 * size_modifier);

                        -- Pan Knob
                        -- _, channel.GUID.pan[i] = obj_Knob2(ctx, images.Knob_Pan, "##Pan" .. i,
                        --     channel.GUID.pan[i], params.knobPan, mouse, keys)
                        
                        local valuePan = reaper.GetMediaTrackInfo_Value(track, "D_PAN")
                        local rvp, valuePan = obj_Knob2(ctx, images.Knob_Pan, "##Pan" .. i, valuePan, params.knobPan, mouse,
                        keys)
                        setParamOnSelectedTracks(fxIndex, "pan", valuePan, rvp and (keys.altDown or keys.shiftAltDown or keys.ctrlAltDown or keys.ctrlAltShiftDown))
                        if rvp and not keys.altDown then
                            reaper.SetMediaTrackInfo_Value(track, "D_PAN", valuePan)
                        end
                        reaper.ImGui_SameLine(ctx, 0, 4 * size_modifier);
                        adjustCursorPos(ctx, 1, -10)
                            
                            
                        gLastButtonX, gLastButtonY = reaper.ImGui_GetCursorScreenPos(ctx)
                        -- In Between Channel Buttons
                        obj_Channel_Button_InBetween(ctx, track, actualTrackIndex, i, mouse, patternItems, track_count,
                        colorValues, mouse, keys)
                        reaper.ImGui_SameLine(ctx, 0, 0);
                        adjustCursorPos(ctx, -96, 0)
                        
                        -- Channel Button
                        obj_Channel_Button(ctx, track, actualTrackIndex, i, mouse, patternItems, track_count,
                        colorValues, mouse, keys);
                        reaper.ImGui_SameLine(ctx, 0, 0);
                        
                        obj_Selector(ctx, actualTrackIndex, track, obj_x, obj_y, colorValues.color30_selector, 3,
                        colorValues.color31_selector_frame, 0, mouse, keys);



                        -- Sequencer Buttons
                        local note_positions, note_velocities, note_pitches = obj_Sequencer_Buttons(ctx, actualTrackIndex,
                            mouse, keys,
                            pattern_item, pattern_start, pattern_end, midi_item, note_positions, note_velocities,
                            patternItems, colorValues, note_pitches)

                              

                        if channel.GUID.expand.open[i] == 1 then
                            if not channel.GUID.expand.spacing[i] then
                                channel.GUID.expand.spacing[i] = 200
                            end

                            if midi_item then
                                -- reaper.ImGui_Dummy(ctx, 163, 0)
                                -- reaper.ImGu  i_SameLine(ctx)
                                adjustCursorPos(ctx, 163, 0)
                                channel.GUID.expand.type[i] = obj_ExpandSelector(ctx, channel.GUID.expand.type[i], track,
                                    mouse, keys, channel.GUID[i])
                                -- obj_KnobMIDI(ctx, images.Knob_2, "##Offset" .. i, veloffset, params.knobVolume, mouse, keys)
                                reaper.ImGui_Dummy(ctx, 11, channel.GUID.expand.spacing[i])
                                reaper.ImGui_SameLine(ctx)
                                if channel.GUID.expand.type[i] == 'Velocity' then
                                    adjustCursorPos(ctx, 8, -20)
                                    obj_VelocitySliders(ctx, actualTrackIndex,
                                        note_positions, note_velocities, mouse, keys, numberOfSliders, sliderWidth,
                                        channel.GUID.expand.spacing[i],
                                        x_padding, patternItems, patternSelectSlider, colorValues)
                                    -- reaper.ImGui_Button(ctx, 'Velocity', 10, 10)
                                    -- reaper.ImGui_SameLine(ctx)
                                end
                                if channel.GUID.expand.type[i] == 'Pitch' then
                                    adjustCursorPos(ctx, 8, -20)
                                    obj_PitchSliders(ctx, actualTrackIndex,
                                        note_positions, note_pitches, mouse, keys, numberOfSliders, sliderWidth,
                                        channel.GUID.expand.spacing[i],
                                        x_padding, patternItems, patternSelectSlider, colorValues)
                                end
                                if channel.GUID.expand.type[i] == 'Offset' then
                                    adjustCursorPos(ctx, 8, -20)
                                    obj_OffsetSliders(ctx, actualTrackIndex,
                                        note_positions, note_pitches, mouse, keys, numberOfSliders, sliderWidth,
                                        channel.GUID.expand.spacing[i],
                                        x_padding, patternItems, patternSelectSlider, colorValues)
                                end

                                adjustCursorPos(ctx, 25, -16)
                                channel.GUID.expand.spacing[i] = obj_ExpandResize(ctx, channel.GUID.expand.spacing[i], i,
                                    mouse, keys, x)
                                adjustCursorPos(ctx, 0, 6)


                                -- reaper.ImGui_Dummy(ctx, 1, 1)
                            end
                        end

                        -- gLastButtonX = lastButtonX
                        -- gLastButtonY = lastButtonY
                        -- if channel.GUID.expand.open[i] == 0 then
                        --     channel.GUID.expand.spacing[i] = nil
                        -- end

                        
                        -- print(totalSliderSpacing)
                        
                    else
                        
                        
                        -- local totalSliderSpacing = totalSliderSpacing or 0
                        -- for k, v in pairs(channel.GUID.expand.spacing) do
                        --     if v and totalSliderSpacing then 
                        --         totalSliderSpacing = totalSliderSpacing + v
                        --     end
                        --     -- print(channel.GUID.expand.spacing[k])
                        -- end
                        
                        reaper.ImGui_Dummy(ctx, xRegionAvail, heightWithSlider )
                    end
                end;

                if trackWasInserted then
                    local scrollMax = reaper.ImGui_GetScrollMaxY(ctx)
                    reaper.ImGui_SetScrollY(ctx, scrollMax + 100)
                    trackWasInserted = false
                end

                finalCursorX, finalCursorY = reaper.ImGui_GetCursorScreenPos(ctx)
                -- print('finalCursorX: ' .. finalCursorX)
                -- print('finalCursorY: ' .. finalCursorY) 
                



                obj_Invisible_Channel_Button(track_suffix, ctx, track_count, colorValues, window_height)
                -- seqScrollPos = reaper.ImGui_GetScrollX(ctx)
                -- reaper.ImGui_EndChild(ctx)
                


                if mouse.mouse_x > firstCursorX + 72 and mouse.mouse_x < gLastButtonX and mouse.mouse_y > firstCursorY and mouse.mouse_y < gLastButtonY + 46 then
                    itemBlockScroll = true
                else
                    itemBlockScroll = false
                end


            end

            -- reaper.ImGui_Dummy(ctx, 22, 51)
            reaper.ImGui_EndChild(ctx)
        end

        printHere()

        ---- CONTROL SIDEBAR -----
        if reaper.ImGui_IsAnyItemHovered(ctx) then
            sidebarFlags = reaper.ImGui_WindowFlags_NoScrollWithMouse()
        else
            sidebarFlags = nil
        end

        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ChildBg(), colorValues.color5_sidebar_bg)
        reaper.ImGui_PushFont(ctx, font_SidebarButtons)
        reaper.ImGui_SameLine(ctx) -- Place the control sidebar on the same line (side by side)

        -- sidebarResize = tonumber(reaper.GetExtState('McSequencer', 'sidebarResize'))
        -- print(sidebarResize)
        -- if not sidebarResize then sidebarResize = 0 end
        -- sidebarResize = 0 or sidebarResize
        -- adjustCursorPos(ctx, sidebarResize, 0)
        -- local sidebarResize = obj_SidebarResize(ctx, sidebarResize, mouse, keys)
        -- print(sidebarResize)
        -- if sidebarResize then 
        --     reaper.SetExtState('McSequencer', 'sidebarResize', sidebarResize, 0) 
        -- else
        --     reaper.SetExtState('McSequencer', 'sidebarResize', 0, 0)
        -- end

        reaper.ImGui_SameLine(ctx)

        adjustCursorPos(ctx, -10, -6)
        if reaper.ImGui_BeginChild(ctx, 'Sidebar', 8 + controlSidebarWidth * size_modifier, -1 * size_modifier, false, sidebarFlags) then
            -- reaper.ImGui_Button(ctx, '##asds', 3, 6)
            -- reaper.ImGui_SameLine(ctx)
            obj_Control_Sidebar(ctx, keys, colorValues, mouse)
            reaper.ImGui_EndChild(ctx)
        end

        reaper.ImGui_PopStyleColor(ctx, 1)
        reaper.ImGui_PopFont(ctx);

        adjustCursorPos(ctx, 0, -27)

        ---  BOTTOM ROW -----

        if reaper.ImGui_BeginChild(ctx, 'Bottom Row', window_width, 323, false, reaper.ImGui_WindowFlags_NoScrollbar()) then
            adjustCursorPos(ctx, 126, 0)
            -- reaper.ImGui_Dummy(ctx, 0, 1 * size_modifier)
            obj_Add_Channel_Button(track_suffix, ctx, count_tracks, colorValues)
            reaper.ImGui_SameLine(ctx, nil, 10)
            reaper.ImGui_SetCursorPosY(ctx, 2)
            obj_HoveredInfo(ctx, hoveredControlInfo);

            reaper.ImGui_EndChild(ctx)
        end

        reaper.ImGui_End(ctx);

        if open then
            reaper.defer(loop);
        else
            Exit();
        end;
    end
    reaper.ImGui_PopFont(ctx);
    reaper.ImGui_PopStyleVar(ctx, 1)
    reaper.ImGui_PopStyleColor(ctx, 4);
end;

reaper.defer(loop)

-- local profiler = dofile(reaper.GetResourcePath() ..  '/Scripts/ReaTeam Scripts/Development/cfillion_Lua profiler.lua') reaper.defer = profiler.defer profiler.attachToWorld() profiler.run()
