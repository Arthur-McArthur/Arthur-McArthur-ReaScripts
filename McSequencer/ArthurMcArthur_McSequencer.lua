-- @description Arthur McArthur McSequencer
-- @author Arthur McArthur
-- @license GPL v3
-- @version 1.1.7
-- @changelog
--  Fixed crash when undocking
--  RS5K minimum velocity set to 0 by default
--  Removed GUI scale option while resizing gets refactored for the new image system

-- @provides
--   Modules/*.lua
--   Images/*.png
--   JSFX/*.jsfx
--   Themes/*.txt
--   Fonts/*.ttf
--   [effect] JSFX/*.jsfx

local reaper = reaper
local os = reaper.GetOS()

local function checkDependencies()
    local missingDeps = {}

    -- Check for ReaImGui
    if not reaper.ImGui_GetVersion or reaper.ImGui_GetVersion() < "0.8.7.5" then
        missingDeps[#missingDeps + 1] = '"ReaImGui (found in ReaPack)"'
    end

    -- Check for SWS extension
    if not reaper.CF_GetSWSVersion or reaper.CF_GetSWSVersion() < "2.12.1" then
        missingDeps[#missingDeps + 1] = 'SWS extension, found at https://www.sws-extension.org/'
    end

    if #missingDeps > 0 then
        local missingDepsStr = table.concat(missingDeps, " and ")
        reaper.ShowMessageBox(
        "This script requires " .. missingDepsStr .. ".\nPlease install them.",
            "Missing Dependencies", 0)
        -- reaper.ReaPack_BrowsePackages(missingDepsStr)
        return true
    end

    return false
end


if checkDependencies() then return end

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

------------------]]
dofile(reaper.GetResourcePath() .. '/Scripts/ReaTeam Extensions/API/imgui.lua')('0.8.7')
local script_path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]]
local modules_path = script_path .. "Modules/"
local themes_path = script_path .. "Themes/"
local images_path = script_path .. "Images/"
local cursor_path = script_path .. "Images/Cursors/"
package.path = package.path .. ";" .. modules_path .. "?.lua"
info = debug.getinfo(1, 'S')
------------------------------

local themeEditor = dofile(script_path .. '/Modules/Theme Editor.lua')
local params = dofile(script_path .. '/Modules/Object Params.lua')
local colors = themeEditor(script_path, modules_path, themes_path)
local serpent = require("serpent")


local CONFIG = {
    int_mousewheel_sensitivity = 1,
    int_mousewheel_sensitivity_fine = 1,
    double_mousewheel_sensitivity = 0.1,
    double_mousewheel_sensitivity_fine = 0.01,
}

local reset = {}
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
local show_VelocitySliders = show_VelocitySliders or false
local show_OffsetSliders = show_OffsetSliders or false
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
local findTempoMarker = false
local value
local valuePitch
local sliderTriggered = false
local triggerTime = 0
local triggerDuration = 0.1 -- duration in seconds for which the slider stays on
local originalSizeModifier, originalObjX, originalObjY
local patternItemsCache = patternItemsCache or {}
local showPopup = false
local copiedValue
-- menu_open = nil
local numberOfSliders = 64 -- Define how many sliders you want
local sliderWidth = 20
local sliderHeight = 269
local x_padding = 2
local right_drag_start_x = nil
local right_drag_start_y = nil
local tension = 0 -- Initial tension level, can be adjusted with the mouse wheel
local fontSize = 12
local fontSidebarButtonsSize = 11
local slider = {}
local dragStartPos = {}
local sequencerFlags
local isClicked = {}
local btnimg = {}
local isHovered = { PlayCursor = {}}
local menu_open = {}
local trackWasInserted 

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
        selected = {}

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
        waveform_Sz_x = 188,
        waveform_Sz_y = 48,
        waveform_Of_x = 14,
        waveform_Of_y = 6
    }
}



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
        cleaned_name = cleaned_name:sub(1, 12) .. ".." .. cleaned_name:sub(-2)
    end

    return cleaned_name
end

local function rectsIntersect(ax1, ay1, ax2, ay2, bx1, by1, bx2, by2)
    return ax1 <= bx2 and ax2 >= bx1 and ay1 <= by2 and ay2 >= by1
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
    for _, isOpen in pairs(menu_open) do
        if isOpen then
            return true
        end
    end
    return false
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
    local dragSensitivity = keys.ctrlShiftDown and params.dragFineSensitivity * 0.25 or
        (keys.ctrlDown and params.dragFineSensitivity * 0.5 or (keys.shiftDown and params.dragFineSensitivity or params.dragSensitivity))
    local wheelSensitivity = keys.ctrlShiftDown and params.wheelFineSensitivity * 0.25 or
        (keys.ctrlDown and params.wheelFineSensitivity * 0.5 or (keys.shiftDown and params.wheelFineSensitivity or params.wheelSensitivity))
    local overallSensitivity = 250

    -- Transform the value to a curved scale
    if not value then return end
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
            reaper.JS_Mouse_SetPosition(dragStartPos[id].x, dragStartPos[id].y)
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

local function toggleSelectTracksEndingWithSEQ()
    for i = 0, reaper.CountTracks(0) - 1 do
        local track = reaper.GetTrack(0, i)
        local _, trackName = reaper.GetTrackName(track, "")
        if trackName:sub(-3) == "SEQ" and trackName ~= "Patterns SEQ" then
            local isSelected = reaper.IsTrackSelected(track)
            reaper.SetTrackSelected(track, not isSelected)
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
        if item_start == start_time and item_end == end_time then
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
    --[[
    -- Check if result is already cached
    if patternItemsCache[track_suffix] then
        return patternItemsCache[track_suffix]
    end
    ]]


    local patternItems = {}
    -- local track_count = reaper.CountTracks(0)
    local trackNameToMatch = "Patterns" .. track_suffix
    local patternTrackIndex = nil -- Variable to store the name of the matched track
    local patternTrack = nil

    for i = 0, track_count - 1 do
        local track = reaper.GetTrack(0, i)
        local _, trackName = reaper.GetTrackName(track)

        -- Check if the track name matches "Patterns" followed by track_suffix
        if trackName == trackNameToMatch then
            patternTrackIndex = i -- Store the matched track name
            patternTrack = track
            local itemCount = reaper.CountTrackMediaItems(track)
            for j = 0, itemCount - 1 do
                local item = reaper.GetTrackMediaItem(track, j)
                local take = reaper.GetActiveTake(item)
                local _, itemName = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
                local patternNumber = tonumber(itemName:match("^Pattern (%d+)"))
                if patternNumber then
                    if not patternItems[patternNumber] then
                        patternItems[patternNumber] = {}
                    end
                    table.insert(patternItems[patternNumber], item)
                end
            end
        end
    end

    -- Store the result in the cache
    -- patternItemsCache[track_suffix] = patternItems
    return patternItems, patternTrackIndex, patternTrack
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
        if item_start > pattern_end then
            break
        end

        local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        local item_end = item_start + item_length

        if item_start >= pattern_start and item_end <= pattern_end then
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

    -- Find the duplicate
    local newItem = nil
    local itemCount = reaper.CountTrackMediaItems(patternsTrack)
    for i = 0, itemCount - 1 do
        local item = reaper.GetTrackMediaItem(patternsTrack, i)
        local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        reaper.SetEditCurPos(pos, 0, 0)
        local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        if pos >= itemPosition and len == itemLength and item ~= selectedItem then
            newItem = item
            break
        end
    end

    if newItem then
        -- Delete unwanted selected items
        deleteUnwantedSelectedItems(newItem)

        -- Rename the new item
        local nextPatternNumber = getNextPatternNumber(patternsTrack)
        local take = reaper.GetActiveTake(newItem)
        if take then
            reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "Pattern " .. nextPatternNumber, true)
        end
        reaper.SetMediaItemSelected(newItem, true)
    else
        reaper.ShowMessageBox("Unable to identify the duplicated item.", "Error", 0)
    end

    -- patternSelectSlider = maxPatternNumber + 1

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
    if not midi_item then return {}, {} end

    local take = reaper.GetMediaItemTake(midi_item, 0)
    if not take or not reaper.TakeIsMIDI(take) then return {}, {} end

    local note_count, _, _ = reaper.MIDI_CountEvts(take)
    local note_positions = {}
    local note_velocities = {}

    for i = 0, note_count - 1 do
        local _, _, _, start_ppq, _, _, _, velocity = reaper.MIDI_GetNote(take, i)
        note_positions[i + 1] = reaper.MIDI_GetProjTimeFromPPQPos(take, start_ppq)
        note_velocities[i + 1] = velocity
    end

    return note_positions, note_velocities
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
local function insertMidiPooledItems(trackIndex, patternSelectSlider, patternItems)
    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)
    local cursor_pos = reaper.GetCursorPosition()
    -- Retrieve the pattern items for the selected pattern
    local patternMediaItems = patternItems[patternSelectSlider]

    -- Get the track at the specified index
    local targetTrack = reaper.GetTrack(0, trackIndex) -- Track index is 0-based

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
            if midiItemStart < itemEnd and midiItemEnd > itemStart then
                existingMidiItemFound = true
                reaper.Main_OnCommand(40289, 0) -- unselect all items
                --local nil_item = nil
                --reaper.SetMediaItemSelected(nil_item,1)
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

local function cloneDuplicateTrack(trackIndex)
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
    update_required = true
    selectedChannelButton = trackIndex +1
    reaper.PreventUIRefresh(-1)
    reaper.UpdateArrange()
    reaper.Undo_EndBlock('Clone/Duplicate Track', -1)
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


---- SLIDERS VELOCITY  ---------------------------------



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
    if value ~= nil then
        local slider_top_value = slider_top + (height - (value * height))
        reaper.ImGui_DrawList_AddRectFilled(drawList, slider_left + x_padding, slider_top_value - 1,
            slider_right - x_padding, slider_bottom, colorValues.color23_slider1)
    end
    -- Return values are used to handle interactions, which we'll leave unchanged as it's not part of the requirement
    return numColorsPushed, rv, slider_left, slider_top, slider_right, slider_bottom
end

local function updateMidiNoteVelocity(step_num, velocity, midi_item, midi_take, num_events, pattern_start, step_duration,
                                      tolerance, noteData)
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
        reaper.MIDI_SetNote(midi_take, index, nil, nil, nil, nil, nil, nil, velocity, false)
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
    if not trackIndex then return end
    local track = reaper.GetTrack(0, trackIndex)
    if not track or not reaper.IsTrackSelected(track) then return end
    local pattern_item, pattern_start, pattern_end, midi_item = getSelectedPatternItemAndMidiItem(trackIndex,
        patternItems, patternSelectSlider)
    if not midi_item then
        return false
    end
    local midi_take = reaper.GetMediaItemTake(midi_item, 0)
    if not midi_take then
        return false
    end
    local num_events, _, _, _ = reaper.MIDI_CountEvts(midi_take)
    if not num_events then
        return false
    end

    local noteData = {}
    local noteIndicesByPosition = {}
    for i = 0, num_events - 1 do
        local _, _, _, start_ppq, _, _, _, _ = reaper.MIDI_GetNote(midi_take, i)
        local note_start_time = reaper.MIDI_GetProjTimeFromPPQPos(midi_take, start_ppq)
        noteData[i] = { start_ppq = start_ppq, note_start_time = note_start_time }
        noteIndicesByPosition[note_start_time] = i
    end

    local step_duration = reaper.TimeMap2_beatsToTime(0, 1) / time_resolution
    local tolerance = step_duration / 2
    local cursor_x, cursor_y = reaper.ImGui_GetCursorScreenPos(ctx)
    local cursor_x = cursor_x + 245 * size_modifier
    local cursor_y = cursor_y
    local x_padding = x_padding * size_modifier
    local sliderWidth = sliderWidth * size_modifier
    local sliderHeight = sliderHeight * size_modifier
    local color1 = colorValues.color24_slider2  
    local color2 = colorValues.color25_slider3

    local dragStartedOnAnySlider = false

    if mouse.isMouseDownL or mouse.isMouseDownR then
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
    if mouse.isMouseDownL and dragStartedOnAnySlider then
        -- Calculate the current and previous slider indices
        local currentSliderIndex = math.floor((mouse.mouse_x - cursor_x) / sliderWidth)
        local previousSliderIndex = math.floor((previous_mouse_x - cursor_x) / sliderWidth)
        currentSliderIndex = math.max(0, math.min(currentSliderIndex, lengthSlider - 1))
        previousSliderIndex = math.max(0, math.min(previousSliderIndex, lengthSlider - 1))

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
                -- Calculate the interpolated value if dragging across multiple sliders, else use current mouse position
                local valueToApply
                if startIndex ~= endIndex then
                    local relativePosition = (i - startIndex) / (endIndex - startIndex)
                    local interpolated_y = previous_mouse_y + (mouse.mouse_y - previous_mouse_y) * relativePosition
                    valueToApply = 1 - (interpolated_y - cursor_y) / sliderHeight
                else
                    valueToApply = 1 - (mouse.mouse_y - cursor_y) / sliderHeight
                end
                valueToApply = math.max(0, math.min(valueToApply, 1)) -- Clamp the value

                -- Update the slider's value and MIDI velocity
                local new_velocity = math.max(1, math.floor(valueToApply * 127))
                updateMidiNoteVelocity(i + 1, new_velocity, midi_item, midi_take, num_events, pattern_start, step_duration, tolerance, noteData)
            end
        end
    end

    -- Right-click drag handling
    if mouse.isMouseDownR and dragStartedOnAnySlider then
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
                    local step_num = i + 1
                    updateMidiNoteVelocity(i + 1, new_velocity, midi_item,
                        midi_take, num_events, pattern_start, step_duration, tolerance, noteData)
                end
            end
        end
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
    end


    --Dummy Spacer
    reaper.ImGui_Dummy(ctx, 0, sliderHeight)

    -- Reset states on mouse release
    if mouse.mouseReleasedR then
        right_drag_start_x, right_drag_start_y = nil, nil
        -- tension = 0
    end

    -- Update the previous mouse position for interpolation
    previous_mouse_x, previous_mouse_y = mouse.mouse_x, mouse.mouse_y
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
        table.insert(files, fileName)
        i = i + 1
    end

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
local function insertNewTrack(filename, track_suffix, track_count)
    -- Find the index of the last "Patterns SEQ" track
    local track_count = reaper.CountTracks(0)
    local last_patterns_seq_index = -1
    local folder_depth = 0
    local num_tracks = reaper.CountTracks(0)
    local insert_track_index = -1

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

    if insert_track_index >= 0 then

        reaper.InsertTrackAtIndex(insert_track_index, false)
        reaper.TrackList_AdjustWindows(false)
        local new_track = reaper.GetTrack(0, insert_track_index)
        -- Ensure the new track is inside the folder and not a folder itself
        reaper.SetMediaTrackInfo_Value(last_track, "I_FOLDERDEPTH", 0)
        reaper.SetMediaTrackInfo_Value(new_track, "I_FOLDERDEPTH", -1)

        if new_track then
            -- Extract the name from the path and remove the .wav file extension
            local trackName = filename:match("^.+[\\/](.+)$")
            trackName = trackName:gsub("%.wav$", "")
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
            -- Update channel data
            update_required = true
            update_channel_data_from_reaper(track_suffix)
            selectedChannelButton = insert_track_index
            selectOnlyTrack(insert_track_index)

        else
            -- Handle track creation error
            reaper.ShowMessageBox("Failed to create a new track.", "Error", 0)
        end
    end
end

---- SLIDERS OFFSET  ---------------------------------

local function obj_OffsetSliders(ctx, trackIndex, note_positions)
    if not trackIndex then
        return
    end
    local track = reaper.GetTrack(0, trackIndex)
    if not track or not reaper.IsTrackSelected(track) then
        return
    end
    local pattern_item, pattern_start, pattern_end, midi_item = getSelectedPatternItemAndMidiItem(trackIndex)
    if not pattern_item then
        return
    end

    local step_duration = reaper.TimeMap2_beatsToTime(0, 1) / time_resolution

    -- Get the current cursor position (top-left corner of the rectangle)
    local cursor_x, cursor_y = reaper.ImGui_GetCursorScreenPos(ctx)
    local frame_right = cursor_x + obj_x * lengthSlider
    local frame_bottom = cursor_y + obj_y * 4

    local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
    local border_color = 0xFFFFFFFF
    local border_thickness = 1
    reaper.ImGui_DrawList_AddRect(draw_list, cursor_x - 1, cursor_y - 1, frame_right + 1, frame_bottom + 1, border_color,
        0, 0, border_thickness)

    local step_duration = reaper.TimeMap2_beatsToTime(0, 1) / time_resolution
    local tolerance = step_duration / 2
    for i = 1, lengthSlider do
        local step_time = pattern_start + (i - 1) * step_duration

        -- Find the note closest to the current grid position within the tolerance range
        local closest_distance = math.huge
        local distance = 0
        for idx, note_pos in ipairs(note_positions) do
            local dist = note_pos - step_time
            if math.abs(dist) < closest_distance and math.abs(dist) <= tolerance then
                closest_distance = math.abs(dist)
                distance = dist * 1000     -- Convert to milliseconds
            end
        end


        reaper.ImGui_PushID(ctx, i)

        local rv, new_distance = obj_MiddleSlider("##distance", obj_x, obj_y * 4, distance, -50, 50, 0)

        if rv and distance ~= new_distance then
            updateMidiNoteOffset(trackIndex, i, new_distance / 1000, patternSelectSlider)
        end
        reaper.ImGui_SameLine(ctx, 0, 0)
        cursor_x = cursor_x + obj_x
        reaper.ImGui_PopID(ctx)
    end
end

local function obj_MiddleSlider(id, width, height, value, min, max, default_value)
    local border_thickness = 1       -- Set the desired border thickness
    local border_color = frame_color -- Set the desired border color (same as frame color in this case)

    --[[ Set style variables and color options
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameBorderSize(), border_thickness) -- Set border thickness
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(), frame_color)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgHovered(), frame_color)          -- Use the same color as FrameBg
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgActive(), frame_color)           -- Use the same color as FrameBg
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrab(), color_invisible)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrabActive(), color_invisible)    -- Use the same color as SliderGrab
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), border_color)                 -- Set border color
    --]]
    local normalized_value = (value - min) / (max - min)
    local normalized_min, normalized_max = 0, 1

    -- Use ImGui's vertical slider function to create the slider
    local retval
    retval, normalized_value = reaper.ImGui_VSliderDouble(ctx, id, width, height, normalized_value, normalized_min,
        normalized_max)
    local changed = retval -- The return value indicates if the slider value has changed

    value = min + normalized_value * (max - min)

    -- Reset the slider value on double-click
    if reaper.ImGui_IsItemClicked(ctx, 2) then
        value = default_value
        changed = true
    end

    -- Pop style variables and color options
    --reaper.ImGui_PopStyleVar(ctx, 1)   -- Pop border thickness style variable
    --reaper.ImGui_PopStyleColor(ctx, 6) -- Pop all colors

    return changed, value
end

local function updateMidiNoteOffset(trackIndex, step_num, distance, patternSelectSlider)
    -- Get the MIDI take associated with the track and pattern
    local pattern_item, pattern_start, pattern_end, midi_item = getSelectedPatternItemAndMidiItem(trackIndex,
        patternSelectSlider)
    if not midi_item then
        return false
    end

    -- Get the MIDI take from the MIDI item
    local midi_take = reaper.GetMediaItemTake(midi_item, 0)

    -- Calculate the step duration
    local step_duration = reaper.TimeMap2_beatsToTime(0, 1) / time_resolution
    -- Calculate the time position of the grid based on step_num
    local grid_position = pattern_start + (step_num - 1) * step_duration

    -- Calculate the new position of the note based on distance (offset from the grid)
    local new_note_position = grid_position + distance

    -- Define a tolerance value (in seconds) for considering notes close to the grid
    local tolerance = step_duration / 2

    -- Find the note event closest to the grid_position within the tolerance range and update its position
    local event_count = reaper.MIDI_CountEvts(midi_take)
    for i = 0, event_count - 1 do
        local ret, selected, muted, startppq, endppq, chan, pitch, vel = reaper.MIDI_GetNote(midi_take, i)
        if ret then
            local start_time = reaper.MIDI_GetProjTimeFromPPQPos(midi_take, startppq)
            local end_time = reaper.MIDI_GetProjTimeFromPPQPos(midi_take, endppq)
            local note_length = end_time - start_time
            if math.abs(grid_position - start_time) <= tolerance then
                local new_start_ppq = reaper.MIDI_GetPPQPosFromProjTime(midi_take, new_note_position)
                local new_end_ppq = reaper.MIDI_GetPPQPosFromProjTime(midi_take, new_note_position + note_length)
                reaper.MIDI_SetNote(midi_take, i, nil, nil, new_start_ppq, new_end_ppq, nil, nil, nil, true)
                break
            end
        end
    end

    -- Update the MIDI take
    reaper.MIDI_Sort(midi_take)
    reaper.UpdateItemInProject(midi_item)
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
    -- menu_open = true
    -- Open Midi Editor
    if reaper.ImGui_MenuItem(ctx, "Open in MIDI Editor") then
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
    -- return menu_open
    -- end
end

local function dragChannel()
    -- -- Start drag source for channel button
    -- if reaper.ImGui_BeginDragDropSource(ctx) then
    --     -- reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_DragDropTarget(), color33_channelbutton_dropped)
    --     -- Set payload to identify which button is being dragged
    --     local payloadValue = tostring(buttonIndex)
    --     reaper.ImGui_SetDragDropPayload(ctx, "CHANNEL_BUTTON_DRAG", payloadValue)
    --     reaper.ImGui_Text(ctx, buttonName) -- Display the button name as a preview while dragging
    --     reaper.ImGui_PopStyleColor(ctx, 1)
    --     -- reaper.ImGui_EndDragDropSource(ctx)
    -- end

    -- -- In the function where you handle the drag and drop
    -- if reaper.ImGui_BeginDragDropTarget(ctx) then
    --     local payloadType, payloadValue = reaper.ImGui_AcceptDragDropPayload(ctx, "CHANNEL_BUTTON_DRAG")
    --     local draw_list = reaper.ImGui_GetWindowDrawList(ctx)
    --     local lineColor = 0xFFFFFFFF -- White color for the line
    --     local lineHeight = 2 -- Thickness of the line
    --     local lineOffset = 3 -- Offset from the button edge
    --     local mousePosX, mousePosY = reaper.ImGui_GetMousePos(ctx)

    --     -- Iterate through the stored button coordinates
    --     for index, coords in pairs(buttonCoordinates) do
    --         if mousePosY >= coords.minY and mousePosY <= coords.maxY then
    --             local buttonMidY = (coords.minY + coords.maxY) / 2
    --             local lineYPosition = mousePosY < buttonMidY and coords.minY - lineOffset or coords.maxY + lineOffset

    --             -- Draw the line above or below the hovered button
    --             reaper.ImGui_DrawList_AddLine(
    --                 draw_list,
    --                 buttonXMin,
    --                 lineYPosition,
    --                 buttonXMax,
    --                 lineYPosition,
    --                 lineColor,
    --                 lineHeight
    --             )
    --             break -- Exit the loop as we found the hovered button
    --         end
    --     end

    --     if payloadType then
    --     -- Your existing drag and drop handling logic
    --     end

    --     reaper.ImGui_EndDragDropTarget(ctx)
end


local function obj_Channel_Button(ctx, track, actualTrackIndex, buttonIndex, mouse, patternItems, track_count, colorValues, mouse, keys)

    local buttonName = shorten_name(channel.GUID.name[buttonIndex] or " ", track_suffix) 
    if buttonIndex == 0 then 
        buttonName = 'Patterns SEQ'
    end
    local cursorPosX, cursorPosY = reaper.ImGui_GetCursorScreenPos(ctx)

    -- Assuming 'images' table contains your image references and their sizes
    local image = selectedChannelButton == actualTrackIndex and images.Channel_button_on or images.Channel_button_off

    -- Draw the image
    reaper.ImGui_Image(ctx, image.i, image.x, image.y)

    -- Calculate the position for the centered text
    local textWidth, textHeight = reaper.ImGui_CalcTextSize(ctx, buttonName)
    local textPosX = (cursorPosX + (images.Channel_button_on.x - textWidth - 4) / 2) + 2
    local textPosY = (cursorPosY + (images.Channel_button_on.y - textHeight) / 2) - 1

    -- Draw the text on the draw list
    reaper.ImGui_DrawList_AddTextEx(drawList, font_SidebarButtons, fontSize, textPosX, textPosY, colorValues.color36_channelbutton_text, buttonName)

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
            unselectAllTracks()
            reaper.SetTrackSelected(track, true)
            selectedChannelButton = actualTrackIndex
            selectedButtonIndex = buttonIndex
            reaper.SetExtState("McSequencer", "selectedChannelButton", tostring(selectedChannelButton), true)
            reaper.SetExtState("McSequencer", "selectedButtonIndex", tostring(buttonIndex), true)
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
    
    if reaper.ImGui_BeginPopup(ctx, contextMenuID, reaper.ImGui_WindowFlags_NoMove()) then
        obj_Channel_Button_Menu(ctx, actualTrackIndex, contextMenuID, patternItems, track_count)
        menu_open[buttonIndex] = true
        print(buttonIndex)
    elseif not reaper.ImGui_IsPopupOpen(ctx, contextMenuID) then
        menu_open[buttonIndex] = false
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
            patternSelectSlider = patternSelectSlider + 1
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
            patternSelectSlider = patternSelectSlider + 1
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

-- Pattern controller
local function obj_Pattern_Controller(patternItems, ctx, mouse, keys, colorValues)
    -- Determine the maximum pattern number among all retrieved pattern items.
    local maxPatternNumber = 0;

    -- for patternNumber = 1, #patternItems do
    --     maxPatternNumber = math.max(maxPatternNumber, patternNumber);
    -- end;
    for patternNumber, _ in pairs(patternItems) do
        maxPatternNumber = math.max(maxPatternNumber, patternNumber);
    end;

    -- Get the last selected pattern number from REAPER's extended state or default to 1.
    local lastSelectedPattern = tonumber(reaper.GetExtState("PatternController", "lastSelectedPattern")) or 1;
    -- Use the last selected pattern number to initialize the pattern selection slider, if not already set.
    patternSelectSlider = patternSelectSlider or 1;

    -- Prepare and retrieve snapping settings from REAPER's extended state.
    local extStateSection = "PatternControllerSnapSettings";
    local snapToEnabled = toboolean(reaper.GetExtState(extStateSection, "snapToEnabled")) or false;
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
    -- If the selected pattern number has associated items, process the first item to set the length slider.
    -- if patternItems[patternSelectSlider] then
    --     for _, item in ipairs(patternItems[patternSelectSlider]) do
    --         selectedItem = item;
    --         if item ~= nil then
    --             local itemLength = reaper.GetMediaItemInfo_Value(item, "D_LENGTH");
    --             local patternStartPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    --             selectedItemStartPos = selectedItemStartPos or patternStartPos
    --             local beatsInSec = reaper.TimeMap2_beatsToTime(0, 1);
    --             -- Calculate the length slider value based on item length.
    --             lengthSlider = math.floor(itemLength / beatsInSec * time_resolution);
    --             patternSelected = true;
    --         end
    --     end;
    -- end;

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
                lengthSlider = math.floor(itemLength / beatsInSec * time_resolution)
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
        -- menu_open[1] = true
        reaper.ImGui_EndPopup(ctx)
    end

    if not patternItems[patternSelectSlider] then
        local lastPatternNumber = nil
        for patternNumber = 1, #patternItems do
            if not lastPatternNumber or patternNumber > lastPatternNumber then
                lastPatternNumber = patternNumber
            end
        end
        -- for patternNumber, _ in pairs(patternItems) do
        --     if not lastPatternNumber or patternNumber > lastPatternNumber then
        --         lastPatternNumber = patternNumber
        --     end
        -- end
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

        -- if patternTrackIdx then
        --     for patternNumber, items in pairs(patternItems) do
        --         if patternNumber == patternSelectSlider then  -- Check if the pattern is selected
        --             for _, patternItem in ipairs(items) do
        --                 local patternStartPos = reaper.GetMediaItemInfo_Value(patternItem, "D_POSITION")
        --                 local newLength = beatsInSec * (lengthSlider / time_resolution)

        --                 -- Find the next pattern item to determine the maximum allowed length
        --                 local nextPatternItem = reaper.GetTrackMediaItem(reaper.GetTrack(0, patternTrackIdx), reaper.GetMediaItemInfo_Value(patternItem, "IP_ITEMNUMBER") + 1)
        --                 local nextPatternStartPos = nextPatternItem and reaper.GetMediaItemInfo_Value(nextPatternItem, "D_POSITION") or patternStartPos + newLength
        --                 local maxAllowedLength = math.min(newLength, nextPatternStartPos - patternStartPos)

        --                 -- Set the length of the pattern item and its associated items
        --                 reaper.SetMediaItemInfo_Value(patternItem, "D_LENGTH", maxAllowedLength)
        --                 for trackIdx = 0, trackCount - 1 do
        --                     local track = reaper.GetTrack(0, trackIdx)
        --                     local itemCount = reaper.CountTrackMediaItems(track)

        --                     for itemIdx = 0, itemCount - 1 do
        --                         local item = reaper.GetTrackMediaItem(track, itemIdx)
        --                         local itemPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")

        --                         -- Check if the item is associated with the selected pattern
        --                         if itemPos == patternStartPos then
        --                             local _, trackName = reaper.GetTrackName(track)
        --                             if string.sub(trackName, - #track_suffix) == track_suffix then
        --                                 reaper.SetMediaItemInfo_Value(item, "D_LENGTH", maxAllowedLength)
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

                        -- Find the next pattern item to determine the maximum allowed length
                        local nextPatternItem = reaper.GetTrackMediaItem(reaper.GetTrack(0, patternTrackIdx), reaper.GetMediaItemInfo_Value(patternItem, "IP_ITEMNUMBER") + 1)
                        local nextPatternStartPos = nextPatternItem and reaper.GetMediaItemInfo_Value(nextPatternItem, "D_POSITION") or patternStartPos + newLength
                        local maxAllowedLength = math.min(newLength, nextPatternStartPos - patternStartPos)

                        -- Set the length of the pattern item and its associated items
                        reaper.SetMediaItemInfo_Value(patternItem, "D_LENGTH", maxAllowedLength)
                        for trackIdx = 0, trackCount - 1 do
                            local track = reaper.GetTrack(0, trackIdx)
                            local itemCount = reaper.CountTrackMediaItems(track)

                            for itemIdx = 0, itemCount - 1 do
                                local item = reaper.GetTrackMediaItem(track, itemIdx)
                                local itemPos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")

                                -- Check if the item is associated with the selected pattern
                                if itemPos == patternStartPos then
                                    local _, trackName = reaper.GetTrackName(track)
                                    if string.sub(trackName, - #track_suffix) == track_suffix then
                                        reaper.SetMediaItemInfo_Value(item, "D_LENGTH", maxAllowedLength)
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

    -- Store the current length slider value for future comparisons.
    prevLengthSlider = lengthSlider;
    return selectedItemStartPos, maxPatternNumber
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

local function get_rs5k_sample_path(track)
    local fx_count = reaper.TrackFX_GetCount(track)
    for fx_index = 0, fx_count - 1 do
        local _, fx_name = reaper.TrackFX_GetFXName(track, fx_index, "")
        if fx_name:find("ReaSamplOmatic5000") or fx_name:find("%(RS5K%)") then
            local retval, sample_path = reaper.TrackFX_GetNamedConfigParm(track, fx_index, "FILE0")
            if retval then
                return sample_path
            end
        end
    end
    return nil
end


local function waveformDisplay(ctx, pcm, sample_path, keys, colorValues, mouse)
    -- reaper.ImGui_Separator(ctx)

    local frame_w, frame_h = reaper.ImGui_GetContentRegionAvail(ctx)
    local numchannels = 1     -- Assuming stereo source
    local duration = 0.2      -- Duration in seconds

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
                reaper.ImGui_InvisibleButton(ctx, '##Waveform', x, 100 * size_modifier)
            end
            local line_thickness = 1                   -- Adjust thickness as needed

            local scaleX = frame_w / (spl_cnt - 1)     -- Scale factor for x-axis

            -- The y-coordinate for the center line of the waveform
            local centerY = y + frame_h / 2

            for i = 1, spl_cnt - 1 do
                local max_peak = peaks[i * 2 - 1]
                local min_peak = peaks[i * 2]

                -- Calculate x positions for drawing
                local peakX = x + (i - 1) * scaleX

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

local function obj_Control_Sidebar(ctx, keys, colorValues, mouse)
    local xcur, ycur = reaper.ImGui_GetCursorScreenPos(ctx)


    local trackIndex = selectedChannelButton
    if trackIndex == nil then
        return
    end

    local track = reaper.GetTrack(0, trackIndex)
    if not track then
        return
    end

    local fxpresent 

    local fxCount = reaper.TrackFX_GetCount(track)
    for fxIndex = 0, fxCount - 1 do
        local _, fxName = reaper.TrackFX_GetFXName(track, fxIndex, "")
        if fxName:find("ReaSamplOmatic5000") or fxName:find("%(RS5K%)") then
            reaper.ImGui_DrawList_AddImage(drawList, images.Sidebar_bg.i, xcur + layout.Sidebar.bg_x, ycur + layout.Sidebar.bg_y, 
            xcur + images.Sidebar_bg.x + layout.Sidebar.bg_x, ycur + images.Sidebar_bg.y+ layout.Sidebar.bg_y)
            fxpresent = true
            local ret, sampleName = reaper.TrackFX_GetNamedConfigParm(track, fxIndex, "FILE0")
            local fileName = sampleName:match("^.+[\\/](.+)$") or ""

            adjustCursorPos(ctx, layout.Sidebar.sampleTitle_x, layout.Sidebar.sampleTitle_y)
            -- reaper.ImGui_Dummy(ctx, 0, 0)

            reaper.ImGui_PushFont(ctx, font_SidebarSampleTitle)
            if ret and fileName ~= "" then
                reaper.ImGui_Text(ctx, fileName)
            else
                reaper.ImGui_Text(ctx, "No sample loaded.")
            end
            reaper.ImGui_PopFont(ctx)

            adjustCursorPos(ctx, layout.Sidebar.waveform_Of_x, layout.Sidebar.waveform_Of_y)

            local valueStart, _, _ = reaper.TrackFX_GetParam(track, fxIndex, 13)
            local valueEnd, _, _ = reaper.TrackFX_GetParam(track, fxIndex, 14)


            reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ChildBg(), colorValues.color70_transparent);
            if reaper.ImGui_BeginChild(ctx, 'Waveform', layout.Sidebar.waveform_Sz_x, layout.Sidebar.waveform_Sz_y, false, reaper.ImGui_WindowFlags_NoScrollWithMouse() | reaper.ImGui_WindowFlags_NoScrollbar()) then
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
                    -- local cury = cury - layout.Sidebar.waveform_Sz_y * 4
                    local valueLocation = curx + valueStart * (layout.Sidebar.waveform_Sz_x )
                    reaper.ImGui_DrawList_AddRectFilled(drawList, curx, cury, valueLocation, cury - 200, colorValues.color67_waveformShading)
                    reaper.ImGui_DrawList_AddLine(drawList, valueLocation, cury, valueLocation, cury - 200, 28952562, 1)
                end

                if valueEnd ~= 1 then
                    local curx, cury = reaper.ImGui_GetCursorScreenPos(ctx)
                    -- local cury = cury - layout.Sidebar.waveform_Sz_y * 4
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
                cycleRS5kSample(track, fxIndex, "previous")  -- Your function call
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
                cycleRS5kSample(track, fxIndex, "random")  -- Your function call
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
                cycleRS5kSample(track, fxIndex, "next")  -- Your function call
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
            _, channel.GUID.volume[selectedButtonIndex] = obj_Knob2(ctx, images.Knob_2, "##Volume",
                channel.GUID.volume[selectedButtonIndex], params.knobVolume, mouse, keys)
            reaper.ImGui_SameLine(ctx)

            -- Pan knob
            _, channel.GUID.pan[selectedButtonIndex] = obj_Knob2(ctx, images.Knob_Pan, "##Pan",
                channel.GUID.pan[selectedButtonIndex], params.knobPan, mouse, keys)
            reaper.ImGui_SameLine(ctx)

            -- Boost knob
            local valueBoost, _, _ = reaper.TrackFX_GetParam(track, fxIndex, 0)
            local rvb, valueBoost = obj_Knob2(ctx, images.Knob_2, "##Boost (Volume)", valueBoost, params.knobBoost, mouse,
                keys)
            if rvb then
                reaper.TrackFX_SetParam(track, fxIndex, 0, valueBoost)
            end
            reaper.ImGui_SameLine(ctx)

            -- Start knob
            -- local valueStart, _, _ = reaper.TrackFX_GetParam(track, fxIndex, 13)
            local rvs, valueStart = obj_Knob2(ctx, images.Knob_Teal, "##Sample Start", valueStart, params.knobStart, mouse,
                keys)
            if rvs then
                reaper.TrackFX_SetParam(track, fxIndex, 13, valueStart)
            end
            reaper.ImGui_SameLine(ctx)

            -- End knob
            local rve, valueEnd = obj_Knob2(ctx, images.Knob_Teal, "##Sample End", valueEnd, params.knobEnd, mouse, keys)
            if rve then
                reaper.TrackFX_SetParam(track, fxIndex, 14, valueEnd)
            end
            adjustCursorPos(ctx, 44, 28)

            -- Pitch Controls
            -- Pitch Slider
            valuePitch, _, _ = reaper.TrackFX_GetParam(track, fxIndex, 15)
            local rvp, valuePitch = obj_Knob2(ctx, images.Slider_Pitch, "##Pitch" , valuePitch, params.sliderPitch, mouse, keys)

            if rvp then
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
            btnimg[7]  = isClicked[7] and images.Minus12_on.i or images.Minus12.i
            isClicked[7]= false
            reaper.ImGui_Image(ctx, btnimg[7], images.Minus12.x, images.Minus12.y)  -- Adjust position as needed
            if reaper.ImGui_IsItemClicked(ctx) then
                isClicked[7]= true  -- Set the state to true for flashing
                valuePitch = valuePitch - (12 / 160)
                valuePitch = math.max(valuePitch, .2) -- Ensure the value does not go below min limit
                reaper.TrackFX_SetParam(track, fxIndex, 15, valuePitch)
            end
            if reaper.ImGui_IsItemHovered(ctx) then
                hoveredControlInfo.id = 'Pitch -12'
            end
            reaper.ImGui_SameLine(ctx)
            adjustCursorPos(ctx, -8, 0)

            -- Pitch Minus 1
            btnimg[8]  = isClicked[8] and images.Minus1_on.i or images.Minus1.i
            isClicked[8]= false
            reaper.ImGui_Image(ctx, btnimg[8], images.Minus1.x, images.Minus1.y)  -- Adjust position as needed
            if reaper.ImGui_IsItemClicked(ctx) then
                isClicked[8]= true  -- Set the state to true for flashing
                valuePitch = valuePitch - (1 / 160)
                valuePitch = math.max(valuePitch, .2) -- Ensure the value does not go below min limit
                reaper.TrackFX_SetParam(track, fxIndex, 15, valuePitch)
            end
            if reaper.ImGui_IsItemHovered(ctx) then
                hoveredControlInfo.id = 'Pitch -1'
            end
            reaper.ImGui_SameLine(ctx)
            adjustCursorPos(ctx, -8, 0)

            -- Pitch Randomization
            btnimg[9]  = isClicked[9] and images.Rnd_Sample_Sidebar_on.i or images.Rnd_Sample_Sidebar.i
            isClicked[9]= false
            reaper.ImGui_Image(ctx, btnimg[9], images.Rnd_Sample_Sidebar_on.x, images.Rnd_Sample_Sidebar.y)  -- Adjust position as needed
            if reaper.ImGui_IsItemClicked(ctx) then
                isClicked[9]= true  -- Set the state to true for flashing
                valueSnap = 0.480 + math.random() * 0.03
                reaper.TrackFX_SetParam(track, fxIndex, 15, valueSnap)
            end

            if reaper.ImGui_IsItemClicked(ctx, 1) then
                valueSnap = 0.4 + math.random() * 0.2
                reaper.TrackFX_SetParam(track, fxIndex, 15, valueSnap)
            end
            if reaper.ImGui_IsItemHovered(ctx) then
                hoveredControlInfo.id = 'Randomzie Pitch, right click for greater range'
            end
            reaper.ImGui_SameLine(ctx)
            adjustCursorPos(ctx, -8, 0)

            -- Pitch Plus 1
            btnimg[10]  = isClicked[10] and images.Plus1_on.i or images.Plus1.i
            isClicked[10]= false
            reaper.ImGui_Image(ctx, btnimg[10], images.Plus1_on.x, images.Plus1_on.y)  -- Adjust position as needed
            if reaper.ImGui_IsItemClicked(ctx) then
                isClicked[10]= true  -- Set the state to true for flashing
                valuePitch = valuePitch + (1 / 160)
                valuePitch = math.max(valuePitch, .2) -- Ensure the value does not go below min limit
                reaper.TrackFX_SetParam(track, fxIndex, 15, valuePitch)
            end
            if reaper.ImGui_IsItemHovered(ctx) then
                hoveredControlInfo.id = 'Pitch +1'
            end
            reaper.ImGui_SameLine(ctx)
            adjustCursorPos(ctx, -8, 0)

            -- Pitch Plus 12
            btnimg[11]  = isClicked[11] and images.Plus12_on.i or images.Plus12.i
            isClicked[11]= false
            reaper.ImGui_Image(ctx, btnimg[11], images.Plus12_on.x, images.Plus12_on.y)  -- Adjust position as needed
            if reaper.ImGui_IsItemClicked(ctx) then
                isClicked[11]= true  -- Set the state to true for flashing
                valuePitch = valuePitch + (12 / 160)
                valuePitch = math.max(valuePitch, .2) -- Ensure the value does not go below min limit
                reaper.TrackFX_SetParam(track, fxIndex, 15, valuePitch)
            end
            if reaper.ImGui_IsItemHovered(ctx) then
                hoveredControlInfo.id = 'Pitch +12'
            end

            -- ADSR Envelope Knobs
            adjustCursorPos(ctx, 9, 12)

            -- -- Attack knob
            local valueAttack, _, _ = reaper.TrackFX_GetParam(track, fxIndex, 9)
            local rvatk, valueAttack = obj_Knob2(ctx, images.Knob_Teal, "Attack", valueAttack, params.knobAttack, mouse, keys)
            if rvatk == true then
                reaper.TrackFX_SetParam(track, fxIndex, 9, valueAttack)
            end
            reaper.ImGui_SameLine(ctx, 51)

            -- -- Decay knob
            local valueDecay, _, _ = reaper.TrackFX_GetParam(track, fxIndex, 24)
            local rvdcy, valueDecay = obj_Knob2(ctx, images.Knob_Teal, "Decay", valueDecay, params.knobDecay, mouse, keys)
            if rvdcy == true then
                reaper.TrackFX_SetParam(track, fxIndex, 24, valueDecay)
            end
            reaper.ImGui_SameLine(ctx, 93)

            -- Sustain knob
            local valueSustain, _, _ = reaper.TrackFX_GetParam(track, fxIndex, 25)
            local rvsus, valueSustain = obj_Knob2(ctx, images.Knob_Teal, "Sustain", valueSustain, params.knobSustain, mouse, keys)
            if rvsus == true then
                reaper.TrackFX_SetParam(track, fxIndex, 25, valueSustain)
            end
            reaper.ImGui_SameLine(ctx, 135)

            -- -- Release knob
            valueRelease, _, _ = reaper.TrackFX_GetParam(track, fxIndex, 10)
            local rvrel, valueRelease = obj_Knob2(ctx, images.Knob_Teal, "Release", valueRelease, params.knobRelease, mouse, keys)
            if rvrel == true then
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
        reaper.ImGui_Text(ctx, 'RS5K not detected')
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
                if rvofs == true then
                    reaper.TrackFX_SetParam(track, fxIndex, 16, valueOffset)
                end
                reaper.ImGui_SameLine(ctx, nil, 9)

                -- Swing knob
                valueSwing, _, _ = reaper.TrackFX_GetParam(track, fxIndex, 1)
                local rvswg, valueSwing = obj_Knob2(ctx, images.Knob_Yellow, "Swing", valueSwing, params.knobSwing, mouse, keys)
                if rvswg == true then
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

        isHovered.PlayCursor[i] = isMouseOverButton

        -- Check for mouse click or dragging over the button
        if (reaper.ImGui_IsMouseReleased(ctx, 0) and isMouseOverButton) or 
           (reaper.ImGui_IsMouseDragging(ctx, 0) and isMouseOverButton) then
            local newCursorPosition = selectedItemPosition + (beatsInSec * (i - 1))
            reaper.SetEditCurPos(newCursorPosition, true, true)
        end

        if isMouseOverButton and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
            reaper.GetSet_LoopTimeRange(1, 1, selectedItemPosition, selectedItemPosition + itemLength, 0)

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

        if itemPos <= note_position and note_position < (itemPos + itemLength) then
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
            if mouse.isMouseDownL and intersectL then
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
                                     colorValues)
    if not (trackIndex and pattern_item and reaper.GetTrack(0, trackIndex)) then
        return note_positions, note_velocities
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

    -- reaper.ImGui_BeginGroup(ctx) 
    -- reaper.ImGui_SameLine(ctx)
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
        
        reaper.ImGui_Image(ctx, step_img, images.Step_odd_off.x, images.Step_odd_off.y)

        if anyMenuOpen == false then

            local button_left = button_left + 224 + (i*20)
            local button_right = button_left + 20

            -- print('step:  ' .. button_right)

            local isMouseOverButton = mouse.mouse_x >= button_left and mouse.mouse_x <= button_right and
                                    mouse.mouse_y >= button_top and mouse.mouse_y <= button_bottom

            -- Handle drag start
            if mouse.drag_start_x and mouse.drag_start_y then
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

            -- if reaper.ImGui_IsItemHovered(ctx) and (reaper.ImGui_IsMouseClicked(ctx, 0) or reaper.ImGui_IsMouseClicked(ctx, 1)) then
            --     -- local button_left, button_top = reaper.ImGui_GetItemRectMin(ctx)
            --     active_lane = trackIndex
            -- end
            
            
            sequencer_Drag(mouse, keys, button_left, button_top, button_right, button_bottom, trackIndex, i,
                trackIndex .. '_' .. i, midi_item, patternItems)
        end
    end
    -- reaper.ImGui_EndGroup(ctx)
    return note_positions, note_velocities
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

-- local function obj_muteButton(ctx, id, value, trackIndex, color_active, color_inactive, color_border, border_size,
--                               button_width, button_height, keys, track)
--     -- local track = reaper.GetTrack(0, trackIndex)
--     -- if not track then return value end
--     local is_active = (value == 1)
    -- local rv = obj_Button(ctx, id, is_active, color_active, color_inactive, color_border, border_size, button_width,
--         button_height)
--     if rv then
--         value = is_active and 0 or 1 -- Toggle value between 0 and 1
--         reaper.SetMediaTrackInfo_Value(track, "B_MUTE", value)
--     end

--     return value
-- end

local function obj_muteButton(ctx, value, track, mouse, keys)

    local is_active = (value == 1)
    local img = is_active and images.Mute_on.i or images.Mute_off.i 
    reaper.ImGui_Image(ctx, img, images.Mute_off.x, images.Mute_off.y)

    if reaper.ImGui_IsItemClicked(ctx) then 
        value = is_active and 0 or 1 -- Toggle value between 0 and 1
        reaper.SetMediaTrackInfo_Value(track, "B_MUTE", value)
    end

    if reaper.ImGui_IsItemHovered(ctx) then
        hoveredControlInfo.id = 'Mute'
    end
    
    return tonumber(value)
end

local function obj_soloButton(ctx, value, track, mouse, keys)

    local is_active = (value ~= 0)
    local img = is_active and images.Solo_on.i  or images.Solo_off.i 
    reaper.ImGui_Image(ctx, img, images.Solo_off.x, images.Solo_off.y)

    if reaper.ImGui_IsItemClicked(ctx) then 
        value = is_active and 0 or 2 -- Toggle value between 0 and 1
        reaper.SetMediaTrackInfo_Value(track, "I_SOLO", value)
    end

    if reaper.ImGui_IsItemHovered(ctx) then
        hoveredControlInfo.id = 'Solo'
    end
    
    return tonumber(value)
end

-- local function obj_soloButton(ctx, id, value, trackIndex, color_active, color_inactive, color_border, border_size,
--                               button_width, button_height)
--     local track = reaper.GetTrack(0, trackIndex)
--     if not track then return value end
--     local is_active = (value ~= 0)
--     local rv = obj_Button(ctx, id, is_active, color_active, color_inactive, color_border, border_size, button_width,
--         button_height)
--     if rv then
--         value = is_active and 0 or 2 -- Toggle value between 0 and 2
--         reaper.SetMediaTrackInfo_Value(track, "I_SOLO", value)
--     end
--     return value
-- end

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
                insertNewTrack(filename, track_suffix, count_tracks)
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

    local x, y = reaper.ImGui_GetWindowContentRegionMax(ctx)
    local xcur, ycur = reaper.ImGui_GetCursorPos(ctx)

    if (y - ycur) ~= 0 then
        reaper.ImGui_InvisibleButton(ctx, '##AreaBelowControls', x, (y - ycur))
    end

    if reaper.ImGui_BeginDragDropTarget(ctx) then
        local rv, count = reaper.ImGui_AcceptDragDropPayloadFiles(ctx)
        if rv then
            for i = 0, count - 1 do
                local filename
                rv, filename = reaper.ImGui_GetDragDropPayloadFile(ctx, i)
                insertNewTrack(filename, track_suffix, count_tracks)
                trackWasInserted = true
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
    local button_left = cursor_x
    local button_top = cursor_y
    local button_right = button_left + width
    local button_bottom = button_top + height

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
        reaper.ImGui_DrawList_AddRectFilled(drawList, button_left + button_size_offset + 5,
            button_top + button_size_offset +2, button_right - button_size_offset + 1,
            button_bottom - button_size_offset -2, audioIndicatorColor, 1)
    end

    local unselect = false

    if active_lane == nil then
        if keys.ctrlDown and reaper.ImGui_IsItemClicked(ctx, 0) then
            if isSelected == true then
                unselect = true
            end

        elseif keys.shiftDown and reaper.ImGui_IsItemClicked(ctx, 0) then
            toggleSelectTracksInRange(trackIndex)
        
        elseif reaper.ImGui_IsItemClicked(ctx, 0) then
            unselectAllTracks()
            reaper.SetTrackSelected(track, true)
        end

        if reaper.ImGui_IsItemClicked(ctx, 0) and reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
            toggleSelectTracksEndingWithSEQ()
        end

        if mouse.isMouseDownL and mouse.mouse_x >= button_left and mouse.mouse_x <= button_right and mouse.mouse_y >= button_top and mouse.mouse_y <= button_bottom then

            reaper.SetTrackSelected(track, true)

        elseif mouse.isMouseDownR and mouse.mouse_x >= button_left and mouse.mouse_x <= button_right and mouse.mouse_y >= button_top and mouse.mouse_y <= button_bottom then
            reaper.SetTrackSelected(track, false)
        end
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



local function keyboard_shortcuts(ctx, patternItems, patternSelectSlider)
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

    if anyMenuOpen == false then
        if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_1()) then
            goToLoopStart()
        end

        if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_V()) and not ctrlDown then
            show_VelocitySliders = not show_VelocitySliders
        end

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
        originalSizeModifier = size_modifier
        originalObjX = obj_x
        originalObjY = obj_y
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

        if reaper.ImGui_Button(ctx, 'Reset to default', 120, 0) then
            local keysToDelete = { "SizeModifier", "ObjX", "ObjY", "TimeResolution", "Find Tempo Marker", "Font Size",
                "Font Size Sidebar Buttons", "themeLastLoadedPath" }                                                                                                      -- Replace with your actual key names

            for _, key in ipairs(keysToDelete) do
                reaper.DeleteExtState("McSequencer", key, true)
            end
            reaper.ImGui_CloseCurrentPopup(ctx)
        end


        -- OK button logic
        if reaper.ImGui_Button(ctx, 'OK', 120, 0) then
            -- Save the modified settings to ExtState
            reaper.SetExtState("McSequencer", "SizeModifier", tostring(size_modifier), true)
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
            size_modifier = originalSizeModifier
            obj_x = originalObjX
            obj_y = originalObjY
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
    local size_modifier = tonumber(reaper.GetExtState("McSequencer", "SizeModifier"))
    if not size_modifier then size_modifier = 1 end
    local obj_x = tonumber(reaper.GetExtState("McSequencer", "ObjX"))
    if not obj_x then obj_x = 20 end
    local obj_y = tonumber(reaper.GetExtState("McSequencer", "ObjY"))
    if not obj_y then obj_y = 34 end
    local time_resolution = tonumber(reaper.GetExtState("McSequencer", "TimeResolution"))
    if not time_resolution then time_resolution = 4 end
    local vfindTempoMarkerStr = reaper.GetExtState("McSequencer", "Find Tempo Marker")
    local vfindTempoMarker = (vfindTempoMarkerStr == "true") --
    if not vfindTempoMarkerStr then vfindTempoMarkerStr = false end
    local fontSize = tonumber(reaper.GetExtState("McSequencer", "Font Size"))
    if not fontSize then fontSize = 14 end
    local fontSidebarButtonsSize = tonumber(reaper.GetExtState("McSequencer", "Font Size Sidebar Buttons"))
    if not fontSidebarButtonsSize then fontSidebarButtonsSize = 14 end

    return size_modifier, obj_x, obj_y, time_resolution, vfindTempoMarker, fontSize, fontSidebarButtonsSize
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

----- MAIN --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

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
size_modifier, obj_x, obj_y, time_resolution, vfindTempoMarker, fontSize, fontSidebarButtonsSize = getPreferences()
local font_path = script_path .. "/Fonts/Segoe UI.ttf"
local font = reaper.ImGui_CreateFont(font_path, fontSize)
font_SidebarSampleTitle = reaper.ImGui_CreateFont(font_path, fontSidebarButtonsSize + 4)
font_SidebarButtons = reaper.ImGui_CreateFont(font_path, fontSidebarButtonsSize)
reaper.ImGui_Attach(ctx, font)
reaper.ImGui_Attach(ctx, font_SidebarSampleTitle)
reaper.ImGui_Attach(ctx, font_SidebarButtons )

if not selectedButtonIndex then
    local selectedTrack = reaper.GetSelectedTrack(0, 0) -- Get the first selected track
    if selectedTrack then
        selectedButtonIndex = reaper.GetMediaTrackInfo_Value(selectedTrack, "IP_TRACKNUMBER")
    end
end

local clipper = reaper.ImGui_CreateListClipper(ctx)
reaper.ImGui_Attach(ctx, clipper)
local FLT_MIN, FLT_MAX = reaper.ImGui_NumericLimits_Float()
reaper.ImGui_SetConfigVar(ctx, reaper.ImGui_ConfigVar_WindowsMoveFromTitleBarOnly(), 1) -- move from title bar only
local windowflags = reaper.ImGui_WindowFlags_NoScrollbar() | reaper.ImGui_WindowFlags_NoScrollWithMouse() |
reaper.ImGui_WindowFlags_MenuBar() | reaper.ImGui_WindowFlags_NoCollapse()


----------------------------------------------------------------------------
----- GUI LOOP -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------
local function loop()

    if showColorPicker then
        colorValues = colors.colorUpdate()
    end
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowMinSize(), 440, 250)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(), colorValues.color1_bg);
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBg(), colorValues.color2_titlebar);
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBgActive(), colorValues.color3_titlebaractive);
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ScrollbarBg(), colorValues.color4_scrollbar);
    reaper.ImGui_PushFont(ctx, font);
    
    visible, open = reaper.ImGui_Begin(ctx, "McSequencer", true, windowflags);
    drawList = reaper.ImGui_GetWindowDrawList(ctx)
    anyMenuOpen = isAnyMenuOpen(menu_open)
    -- printTable(menu_open)
    
    if visible then
        local track_count = reaper.CountTracks(0)
        local patternItems, patternTrackIndex, patternTrack = getPatternItems(track_count)
        local mouse = mouseTrack(ctx)
        local keys = keyboard_shortcuts(ctx, patternItems, patternSelectSlider)
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

        -- local tableflags0 = reaper.ImGui_tableflags
        -- reaper.ImGui_BeginTable(ctx, "table 0", 1, tableflags0, window_width - 15)

        ----- TOP ROW -----
        local tableflags0 = nil;
        if reaper.ImGui_BeginChild(ctx, 'Top Row', nil, top_row_x * size_modifier, 0, reaper.ImGui_WindowFlags_NoScrollbar() | reaper.ImGui_WindowFlags_NoScrollWithMouse()) then
            
            -- color picker
            if showColorPicker then
                colors.obj_ColorPicker(ctx);
                top_row_x = 420 
            else
                top_row_x = 32 
            end;

            reaper.ImGui_SameLine(ctx);
            -- offset sliders show button
            -- if reaper.ImGui_Button(ctx, "Offset") then
            -- show_OffsetSliders = not show_OffsetSliders;
            -- end; 
            -- reaper.ImGui_SameLine(ctx, 160);
            -- pattern controller
            
            local selectedItemStartPos, maxPatternNumber = obj_Pattern_Controller(patternItems, ctx,
                mouse, keys, colorValues, track_count);

            if vfindTempoMarker and selectedItemStartPos then
                local index, time, timesigNum, timesigDenom = findTempoMarkerFromPosition(selectedItemStartPos)
                if index then
                    time_resolution = timesigNum
                end
            end

            reaper.ImGui_SameLine(ctx);

            obj_New_Pattern(ctx, patternItems, colorValues, maxPatternNumber, track_count) 

            -- --test
            -- reaper.ImGui_SameLine(ctx);
            -- if  obj_Button(ctx,"Test", false, colorValues.color61_button_sidebar_active, colorValues.color62_button_sidebar_inactive, colorValues.color63_button_sidebar_border, 1, 99, 23) then      --
            --     for k, v in pairs(_G) do
            --         print(k, v)
            --     end
            -- end

            reaper.ImGui_SameLine(ctx, window_width - 85 * size_modifier);

            -- velocity sliders show button
            if obj_Button(ctx, "Velocity", false, colorValues.color34_channelbutton_active, colorValues.color32_channelbutton, colorValues.color35_channelbutton_frame, 1, 66 * size_modifier, 22 * size_modifier, "Show velocity sliders") then
                show_VelocitySliders = not show_VelocitySliders;
            end;

            local dl = reaper.ImGui_GetWindowDrawList(ctx)
            local wx, wy = reaper.ImGui_GetCursorScreenPos(ctx)
            reaper.ImGui_DrawList_AddLine(dl, wx, wy, wx + window_width, wy, colorValues.color6_separator, 1 * size_modifier)

            reaper.ImGui_EndChild(ctx)
        end

        if reaper.ImGui_IsAnyItemHovered(ctx) then
            sequencerFlags = reaper.ImGui_WindowFlags_NoScrollWithMouse() |
            reaper.ImGui_WindowFlags_HorizontalScrollbar()
        else
            sequencerFlags = reaper.ImGui_WindowFlags_HorizontalScrollbar()
        end

        -----  MIDDLE ROW -----
        if reaper.ImGui_BeginChild(ctx, "Middle Row", -controlSidebarWidth, - 27, false, sequencerFlags) then
            reaper.ImGui_Dummy(ctx, 0, 0)
            reaper.ImGui_SameLine(ctx, 0, 3 * size_modifier);
            adjustCursorPos(ctx, -6, 6)
            --
            local parentIndex = parent.GUID.trackIndex[0]
            local track = parent.GUID[0]

            -- Mute Button
            parent.GUID.mute[0] = obj_muteButton(ctx, parent.GUID.mute[0], parent.GUID[0], 22, 22, mouse, keys)
            reaper.ImGui_SameLine(ctx, 0, 3 * size_modifier);
            adjustCursorPos(ctx, -3, 6)

            -- Solo Button
            parent.GUID.solo[0] = obj_soloButton(ctx, parent.GUID.solo[0], parent.GUID[0], 22, 22, mouse, keys)
            reaper.ImGui_SameLine(ctx, 0, 5 * size_modifier);
            if size_modifier >= 1.3 then adjustCursorPos(ctx, 0, 2 * size_modifier) end

            -- Volume Knob
            _, parent.GUID.volume[0] = obj_Knob2(ctx, images.Knob_2, "##ParentVolume", parent.GUID.volume[0],
                params.knobVolume, mouse, keys)

            reaper.ImGui_SameLine(ctx, 0, 5 * size_modifier);
            if size_modifier >= 1.3 then adjustCursorPos(ctx, 0, 2 * size_modifier) end

            -- Pan Knob
            _, parent.GUID.pan[0] = obj_Knob2(ctx, images.Knob_Pan, "##Panparent", parent.GUID.pan[0], params.knobPan,
                mouse, keys)
            reaper.ImGui_SameLine(ctx, 0, 4 * size_modifier);

            -- Channel Button
            obj_Channel_Button(ctx, track, parentIndex, 0, mouse, patternItems, track_count, colorValues, mouse, keys);
            reaper.ImGui_SameLine(ctx, 0, 0);

            -- Selector
            obj_Selector(ctx, parentIndex, parent.GUID[0], obj_x, obj_y, colorValues.color30_selector, 3,
                colorValues.color31_selector_frame, 0,
                mouse, keys);
            reaper.ImGui_SameLine(ctx, 0, 1 * size_modifier);

            -- play cursor buttons
            obj_PlayCursor_Buttons(ctx, mouse, keys, patternSelectSlider, colorValues);
            adjustCursorPos(ctx, 0, 1)

            reaper.ImGui_Dummy(ctx, 0, 0)

            ----- DELETE POPUP ------

            if showPopup then
                unselectNonSuffixedTracks()
                local track_count = reaper.CountSelectedTracks(0)
                confirmed = popup(ctx, track_count)
                if confirmed then
                    deleteTrack(trackIndex)
                end
            end

            -----  SEQUENCER -----
            if channel and channel.channel_amount then
                -- if reaper.ImGui_BeginChild(ctx, "Sequencer Row", -controlSidebarWidth, - 27, false, sequencerFlags) then
                adjustCursorPos(ctx, -2, -2)
                reaper.ImGui_ListClipper_Begin(clipper, channel.channel_amount)     --

                while reaper.ImGui_ListClipper_Step(clipper) do
                    local display_start, display_end = reaper.ImGui_ListClipper_GetDisplayRange(clipper)
                    for i = display_start, display_end - 1 do
                        local track = channel.GUID[i]
                        local actualTrackIndex = channel.GUID.trackIndex[i + 1];
                        local pattern_item, pattern_start, pattern_end, midi_item = getSelectedPatternItemAndMidiItem(
                            actualTrackIndex, patternItems, patternSelectSlider)
                        local note_positions, note_velocities = populateNotePositions(midi_item)

                        reaper.ImGui_Dummy(ctx, 0, 0)
                        reaper.ImGui_SameLine(ctx, 0, 3 * size_modifier);
                        adjustCursorPos(ctx, -4, 5)

                        -- Mute Button
                        channel.GUID.mute[i + 1] = obj_muteButton(ctx, channel.GUID.mute[i + 1], track, mouse, keys)
                        reaper.ImGui_SameLine(ctx, 0, 3 * size_modifier);
                        adjustCursorPos(ctx, -3, 5)

                        -- Solo Button
                        channel.GUID.solo[i + 1] = obj_soloButton(ctx, channel.GUID.solo[i + 1], track, mouse, keys)
                        reaper.ImGui_SameLine(ctx, 0, 5 * size_modifier);
                        if size_modifier >= 1.3 then adjustCursorPos(ctx, 0, 2 * size_modifier) end

                        -- Volume Knob
                        _, channel.GUID.volume[i + 1] = obj_Knob2(ctx, images.Knob_2, "##Volume" .. i,
                            channel.GUID.volume[i + 1], params.knobVolume, mouse, keys)
                        reaper.ImGui_SameLine(ctx, 0, 5 * size_modifier);

                        -- Pan Knob
                        _, channel.GUID.pan[i + 1] = obj_Knob2(ctx, images.Knob_Pan, "##Pan" .. i,
                            channel.GUID.pan[i + 1], params.knobPan, mouse, keys)
                        reaper.ImGui_SameLine(ctx, 0, 4 * size_modifier);

                        -- Channel Button
                        obj_Channel_Button(ctx, track, actualTrackIndex, i + 1, mouse, patternItems, track_count,
                            colorValues, mouse, keys);
                        reaper.ImGui_SameLine(ctx, 0, 0);

                        obj_Selector(ctx, actualTrackIndex, track, obj_x, obj_y, colorValues.color30_selector, 3,
                            colorValues.color31_selector_frame, 0, mouse, keys);

                        -- Sequencer Buttons
                        local note_positions, note_velocities = obj_Sequencer_Buttons(ctx, actualTrackIndex, mouse, keys,
                            pattern_item, pattern_start, pattern_end, midi_item, note_positions, note_velocities,
                            patternItems, colorValues)

                        -- Velocity Sliders
                        if show_VelocitySliders then
                            obj_VelocitySliders(ctx, actualTrackIndex,
                                note_positions, note_velocities, mouse, keys, numberOfSliders, sliderWidth, sliderHeight,
                                x_padding, patternItems, patternSelectSlider, colorValues)
                        end;

                        adjustCursorPos(ctx, -2, -5)

                        -- Offset Sliders
                        -- if show_OffsetSliders then
                        --     reaper.ImGui_SameLine(ctx, nil, 233)
                        --     obj_OffsetSliders(ctx, actualTrackIndex, note_positions);
                        -- end;
                    end
                end;

                if trackWasInserted then
                    local scrollMax = reaper.ImGui_GetScrollMaxY(ctx)
                    reaper.ImGui_SetScrollY(ctx, scrollMax + 100)
                    trackWasInserted = false
                end

                obj_Invisible_Channel_Button(track_suffix, ctx, count_tracks, colorValues, window_height)

                seqScrollPos = reaper.ImGui_GetScrollX(ctx)

            end
            reaper.ImGui_EndChild(ctx)
            -- reaper.ImGui_Dummy(ctx, 0, 0)
            -- reaper.ImGui_SameLine(ctx) -- Place the control sidebar on the same line (side by side)

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
        adjustCursorPos(ctx, -10, -6)
        if reaper.ImGui_BeginChild(ctx, 'Sidebar', 8 + controlSidebarWidth * size_modifier, -1 * size_modifier, false, sidebarFlags) then
            obj_Control_Sidebar(ctx, keys, colorValues, mouse)
            reaper.ImGui_EndChild(ctx)
        end
        
        reaper.ImGui_PopStyleColor(ctx, 1)
        reaper.ImGui_PopFont(ctx);
        
        adjustCursorPos(ctx, 0, -27)
        
        ---  BOTTOM ROW -----
        
        if reaper.ImGui_BeginChild(ctx, 'Bottom Row', window_width , 323, false, reaper.ImGui_WindowFlags_NoScrollbar()) then
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