-- @description Preset Manager
-- @author Arthur McArthur
-- @version 0.1
-- @about License: GPL 3.0... thanks to cfillon and eugen27771 (RIP)

function print(v)
  reaper.ShowConsoleMsg("\n" .. v);
end;

local ctx = reaper.ImGui_CreateContext("Preset Manager");
local presetList = {}  -- Table to hold the list of presets
local selectedPresets = {}  -- Table to hold selected presets
local editStates = {}  -- Table to hold the edit states of presets (true for editing, nil otherwise)
track = nil
fxnumber = nil
local renamePresetBuf = ''
local updateRenamePresetBuf = true  -- Flag to update renamePresetBuf with selected presets
autoSwitchPreset = true
local shift = false
local ctrl = false
local alt = false
local previousFXName = nil
local currentName = ""
firstSelectedIndex = nil

----------------------------------------------------

local function loadPresets(track, fxnum, num_presets, fx_name, track_name)
    if not track then return end
    presetList = {}
    presetFile = reaper.TrackFX_GetUserPresetFilename(track, fxnum)
    presetFile = reaper.TrackFX_GetUserPresetFilename(track, fxnum)
    local file = io.open(presetFile, "r")
    if not file then
        return  -- Could not open the file, exit the function
    end
    local currentPreset = nil
    for line in file:lines() do
        if line:match("^%[Preset%d+%]") then
            if currentPreset then
                table.insert(presetList, currentPreset)
            end
            currentPreset = {}
        elseif currentPreset and line:match("^Name=") then
            -- Extract the preset name
            currentPreset.name = line:match("^Name=(.+)$")
        elseif currentPreset and line:match("^Data=") then
            -- Extract the preset data
            currentPreset.data = line:match("^Data=(.+)$")
        elseif currentPreset and line:match("^Len=") then
            -- Extract the preset data
            currentPreset.len = line:match("^Len=(.+)$")
        end
    end
    if currentPreset then
        table.insert(presetList, currentPreset)
    end
    file:close()
end

-- function to unselect all selected presets
local function unselectAll()
    selectedPresets = {}
end

-- Function to save presets to the currently floating FX
local function savePresets()
    -- Ensure we have a valid preset file path
    if not presetFile or presetFile == "" then
        return  -- No preset file path, exit the function
    end

    -- Open the preset file for writing
    local file = io.open(presetFile, "w")
    if not file then
        return  -- Could not open the file, exit the function
    end

    -- Write the [General] section with the total number of presets
    file:write("[General]\n")
    file:write("NbPresets=" .. tostring(#presetList) .. "\n")

    -- Write each preset section
    for i, preset in ipairs(presetList) do
        file:write("[Preset" .. tostring(i - 1) .. "]\n")  -- Preset index is 0-based in the file
        file:write("Data=" .. preset.data .. "\n")
        file:write("Name=" .. preset.name .. "\n")
        file:write("Len=" .. preset.len .. "\n")  -- Length of the preset data
    end

    -- Close the file
    file:close()
end

local function refreshFX(track, fxnum, num_presets, fx_name, track_name)
  local track_save = track
  local fxnumber_save = fxnum
  reaper.TrackFX_Show(track, fxnum, 2)
  reaper.TrackFX_Show(track_save, fxnumber_save , 3)
end

local function renamePreset()
    -- Get the index of the first selected preset (only one preset can be renamed at a time)
    local selectedIndex = nil
    for i, selected in pairs(selectedPresets) do
        if selected then
            selectedIndex = i
            break
        end
    end

    -- Ensure that a preset is selected for renaming
    if not selectedIndex then
        reaper.ShowMessageBox("No preset selected. Please select a preset to rename.", "Error", 0)
        return
    end

    -- Get the current name of the selected preset
    local currentName = presetList[selectedIndex].name

    -- Prompt the user for the new name
    local retval, newName = reaper.GetUserInputs("Rename Preset", 1, "New name:", currentName)
    if retval == true and newName ~= "" then
        -- Update the name of the selected preset
        presetList[selectedIndex].name = newName

        -- Save the updated preset list
        savePresets()
    end
end

local function selectAll()
    selectedPresets = {}
    for i, preset in ipairs(presetList) do
        selectedPresets[i] = true
    end
end

local function delete()
    local deleteIndices = {}
    for i, selected in pairs(selectedPresets) do
        if selected then
            table.insert(deleteIndices, i)
        end
    end
    table.sort(deleteIndices, function(a, b) return a > b end)
    for _, index in ipairs(deleteIndices) do
        table.remove(presetList, index)
    end
    selectedPresets = {}
    savePresets()
end

function SetButtonState(set)
    local is_new_value, filename, sec, cmd, mode, resolution, val = reaper.get_action_context()
    reaper.SetToggleCommandState(sec, cmd, set or 0)
    reaper.RefreshToolbar2(sec, cmd)
end

function exit()
    --SetButtonState()
end

local function switchToPreset(track, fxnum, index)
    if track and fxnum then
        -- Load the selected preset data into the FX
        local presetData = presetList[index].name
        --reaper.TrackFX_SetNamedConfigParm(track, fxnumber, "p", presetData)
        reaper.TrackFX_SetPreset(track, fxnum, presetData)
    end
end

function getLastTouchFX()
  local retval, tracknum, itemnum, fxnum = reaper.GetFocusedFX2()
  if retval ~= 0 then
    local track = reaper.GetTrack(0, tracknum-1)
    local _, fx_name = reaper.TrackFX_GetFXName(track, fxnum, "")
    local _, track_name = reaper.GetTrackName(track)
    local _, number_of_presets = reaper.TrackFX_GetPresetIndex(track, fxnum)
    return track, fxnum, num_presets, fx_name, track_name
  else
    fx_name = nil
  end
end


local function getNextUniqueName(name, existingNames)
    -- Extract enumeration suffix (e.g., "(2)") if present
    local baseName, enumeration = name:match("^(.-) (%(%d+%)?)$")
    baseName = baseName or name
    enumeration = enumeration and " " .. enumeration or ""

    -- Extract "_x" number suffix (e.g., "_3") if present
    local prefix, underscoreNumber = baseName:match("^(.-)_(%d+)$")
    local nextNumber = underscoreNumber and tonumber(underscoreNumber) + 1 or 2
    local newName = prefix and (prefix .. "_" .. tostring(nextNumber) .. enumeration) or (baseName .. "_2" .. enumeration)

    -- Ensure uniqueness of the new name
    while existingNames[newName] do
        nextNumber = nextNumber + 1
        newName = prefix and (prefix .. "_" .. tostring(nextNumber) .. enumeration) or (baseName .. "_" .. tostring(nextNumber) .. enumeration)
    end

    return newName
end


local function duplicate()
    -- Create a table to hold the duplicated presets
    local duplicatedPresets = {}
    local existingNames = {}

    -- Create a set of all existing preset names
    for _, preset in ipairs(presetList) do
        existingNames[preset.name] = true
    end

    -- Iterate through selectedPresets to identify the indices of selected presets
    for i, selected in pairs(selectedPresets) do
        if selected then
            -- Create a copy of the selected preset
            local presetCopy = {}
            for k, v in pairs(presetList[i]) do
                presetCopy[k] = v
            end
            -- Modify the name of the duplicated preset
            presetCopy.name = getNextUniqueName(presetCopy.name, existingNames)
            existingNames[presetCopy.name] = true
            -- Add the duplicated preset to the duplicatedPresets table
            table.insert(duplicatedPresets, presetCopy)
        end
    end

    -- Append the duplicated presets to the presetList table
    for _, preset in ipairs(duplicatedPresets) do
        table.insert(presetList, preset)
    end

    -- Save the updated preset list
    savePresets()
end

function enumerate(presetList, selectedPresets)
  if not presetList or not selectedPresets then return end

  -- Iterate through the presetList and update the names of selected presets
  for i, preset in ipairs(presetList) do
    -- Check if the preset is selected
    if selectedPresets[i] then
      -- Remove any existing enumeration suffix from the preset's name
      local baseName = preset.name:gsub(" %(?%d+%)$", "")
      
      -- Append the (i-1) as a suffix to the preset's name
      preset.name = baseName .. " (" .. tostring(i - 1) .. ")"
    end
  end
  savePresets()
end

function removeEnumeration(presetList, selectedPresets)
    if not presetList or not selectedPresets then return end

    -- Iterate through the presetList and update the names of selected presets
    for i, preset in ipairs(presetList) do
        -- Check if the preset is selected
        if selectedPresets[i] then
            -- Remove any enumeration suffix (e.g., "(2)") from the preset's name
            local baseName = preset.name:gsub(" %(%d+%)$", "")
            preset.name = baseName
        end
    end

    -- Save the updated preset list
    savePresets()
end


function sort(presetList, selectedPresets, order)
  if not presetList or not selectedPresets then return end

  -- Extract selected presets into a separate table
  local selectedPresetSubset = {}
  for i, selected in ipairs(selectedPresets) do
    if selected then
      table.insert(selectedPresetSubset, presetList[i])
    end
  end

  if order == 0 then
    -- Sort the subset of selected presets alphabetically by name
    table.sort(selectedPresetSubset, function(a, b)
      return a.name:lower() < b.name:lower()
    end)
  else
    table.sort(selectedPresetSubset, function(a, b)
      return a.name:lower() > b.name:lower()
    end)
  end

  -- Update the original presetList with the sorted selected presets
  local subsetIndex = 1
  for i, selected in ipairs(selectedPresets) do
    if selected then
      presetList[i] = selectedPresetSubset[subsetIndex]
      subsetIndex = subsetIndex + 1
    end
  end
  savePresets()
end


local base64bytes = {['A']=0, ['B']=1, ['C']=2, ['D']=3, ['E']=4, ['F']=5, ['G']=6, ['H']=7, ['I']=8, ['J']=9, ['K']=10,['L']=11,['M']=12,
                     ['N']=13,['O']=14,['P']=15,['Q']=16,['R']=17,['S']=18,['T']=19,['U']=20,['V']=21,['W']=22,['X']=23,['Y']=24,['Z']=25,
                     ['a']=26,['b']=27,['c']=28,['d']=29,['e']=30,['f']=31,['g']=32,['h']=33,['i']=34,['j']=35,['k']=36,['l']=37,['m']=38,
                     ['n']=39,['o']=40,['p']=41,['q']=42,['r']=43,['s']=44,['t']=45,['u']=46,['v']=47,['w']=48,['x']=49,['y']=50,['z']=51,
                     ['0']=52,['1']=53,['2']=54,['3']=55,['4']=56,['5']=57,['6']=58,['7']=59,['8']=60,['9']=61,['+']=62,['/']=63,['=']=nil}

function B64_to_HEX(data)
  local chars  = {}
  local result = {}
  local hex
    for dpos=0, #data-1, 4 do
        -- Get chars -------------------
        for char=1,4 do chars[char] = base64bytes[(string.sub(data,(dpos+char), (dpos+char)) or "=")] end -- Get chars
        -- To hex ----------------------
        if chars[3] and chars[4] then 
            hex = string.format('%02X%02X%02X',                                  -- if 1,2,3,4 chars
                                   (chars[1]<<2)       + ((chars[2]&0x30)>>4),   -- 1
                                   ((chars[2]&0xf)<<4) + (chars[3]>>2),          -- 2
                                   ((chars[3]&0x3)<<6) + chars[4]              ) -- 3
          elseif  chars[3] then 
            hex = string.format('%02X%02X',                                      -- if 1,2,3 chars
                                   (chars[1]<<2)       + ((chars[2]&0x30)>>4),   -- 1
                                   ((chars[2]&0xf)<<4) + (chars[3]>>2),          -- 2
                                   ((chars[3]&0x3)<<6)                         )
          else
            hex = string.format('%02X',                                          -- if 1,2 chars
                                   (chars[1]<<2)       + ((chars[2]&0x30)>>4)  ) -- 1
        end 
       ---------------------------------
       table.insert(result,hex)
    end
  return table.concat(result)  
end

function String_to_HEX(Preset_Name)
  local VAL  = {Preset_Name:byte(1,-1)} -- to bytes, values
  local Pfmt = string.rep("%02X", #VAL)
  return string.format(Pfmt, table.unpack(VAL))
end

function FX_Chunk_to_HEX(FX_Type, FX_Chunk, Preset_Name)
  local Preset_Chunk = FX_Chunk:match("\n.*\n")        -- extract preset(simple var)
    -- For JS 
    if FX_Type=="JS" then
       Preset_Chunk = Preset_Chunk:gsub("\n", "")      -- del "\n"
       return String_to_HEX(Preset_Chunk..Preset_Name)
    end
    
    -- For VST 
    local Hex_TB = {}
    local init = 1

    for i=1, math.huge do 
          line = Preset_Chunk:match("\n.-\n", init)    -- extract line from preset(simple var)
          if not line then
             --reaper.ShowConsoleMsg(Hex_TB[i-1].."\n")
             Hex_TB[i-1] = "00"..String_to_HEX(Preset_Name).."0010000000" -- Preset_Name to Hex(replace name from chunk)
             --reaper.ShowConsoleMsg(Hex_TB[i-1].."\n")
             break 
          end
          ---------------
          init = init + #line - 1                      -- for next line
          line = line:gsub("\n","")                    -- del "\n"
          --reaper.ShowConsoleMsg(line.."\n")
          Hex_TB[i] = B64_to_HEX(line)
    end
    ---------------------
    return table.concat(Hex_TB)
end

function Get_CtrlSum(HEX)
  local Sum = 0
  for i=1, #HEX, 2 do  Sum = Sum + tonumber( HEX:sub(i,i+1), 16) end
  return string.sub( string.format("%X", Sum), -2, -1 ) 
end


function Get_FX_Data(track, fxnum)
  local fx_cnt = reaper.TrackFX_GetCount(track)
  if fx_cnt==0 or fxnum>fx_cnt-1 then return end       -- if fxnum not valid
  local ret, Track_Chunk =  reaper.GetTrackStateChunk(track,"",false)
  -- Find FX_Chunk(use fxnum) --------
  local s, e = Track_Chunk:find("<FXCHAIN")            -- find FXCHAIN section
  -- find VST(or JS) chunk 
  for i=1, fxnum+1 do
      s, e = Track_Chunk:find("<%u+%s.->", e)                    
  end
  -- FX_Type 
  local FX_Type = string.match(Track_Chunk:sub(s+1,s+3), "%u+")   -- FX Type
  if not(FX_Type=="VST" or FX_Type=="JS") then return end         -- Only VST and JS supported
  -- extract FX_Chunk 
  local FX_Chunk = Track_Chunk:match("%b<>", s)      -- FX_Chunk(simple var)
  -- Get UserPresetFile
  local PresetFile = reaper.TrackFX_GetUserPresetFilename(track, fxnum, "")
  return FX_Type, FX_Chunk, PresetFile
end


function Write_to_File(PresetFile, Preset_HEX, Preset_Name, presetIndex)
    local file, Presets_ini, Nprsts
    local ret_r, ret_w
    if not presetIndex then
        -- No preset index provided; use the original Write_to_File behavior
        if reaper.file_exists(PresetFile) then
            ret_r, Nprsts =  reaper.BR_Win32_GetPrivateProfileString("General", "NbPresets", "", PresetFile)
            Nprsts = math.tointeger(Nprsts)
            ret_w = reaper.BR_Win32_WritePrivateProfileString("General", "NbPresets", math.tointeger(Nprsts+1), PresetFile)
        else
            Nprsts = 0
            Presets_ini = "[General]\nNbPresets="..Nprsts+1
            file = io.open(PresetFile, "w")
            file:write(Presets_ini)
            file:close()
        end
        -- Write preset data to file
        file = io.open(PresetFile, "r+")
        file:seek("end")                        -- to end of file
    else
        -- Preset index provided; overwrite the specified preset
        local fileContent = {}
        file = io.open(PresetFile, "r")
        local lineNumber = 0
        for line in file:lines() do
            lineNumber = lineNumber + 1
            if lineNumber == (presetIndex * 4 + 1) then
                fileContent[lineNumber] = "[Preset" .. (presetIndex - 1) .. "]"
            elseif lineNumber ~= (presetIndex * 4 + 2) and lineNumber ~= (presetIndex * 4 + 3) and lineNumber ~= (presetIndex * 4 + 4) then
                fileContent[lineNumber] = line
            end
        end
        file:close()
        file = io.open(PresetFile, "w")
        file:write(table.concat(fileContent, "\n"))
        file:close()

        -- Reopen the file in "r+" mode
        file = io.open(PresetFile, "r+")
        file:seek("set", (presetIndex * 4 - 1) * 32)  -- move to the start of the specified preset
    end

    file:write("\n[Preset" .. (presetIndex and (presetIndex - 1) or Nprsts) .. "]")  -- preset number (0-based)
    local Len = #Preset_HEX                 -- Data Length
    local s = 1
    local Ndata = 0
    for i = 1, math.ceil(Len / 32768) do
        if i == 1 then
            Ndata = "\nData="
        else
            Ndata = "\nData_" .. i - 1 .. "="
        end
        local Data = Preset_HEX:sub(s, s + 32767)
        local Sum = Get_CtrlSum(Data)
        file:write(Ndata, Data, Sum)
        s = s + 32768
    end
    -- Preset_Name, Data Length
    file:write("\nName=" .. Preset_Name .. "\nLen=" .. Len // 2 .. "\n")
    file:close()
end



function Save_VST_Preset(track, fxnum, Preset_Name, firstSelectedIndex)
  if not (track and fxnum and Preset_Name) then return end       -- Need track, fxnum, Preset_Name
  local FX_Type, FX_Chunk, PresetFile = Get_FX_Data(track, fxnum)
  if FX_Chunk and PresetFile then
     local start_time = reaper.time_precise() 
     local Preset_HEX = FX_Chunk_to_HEX(FX_Type, FX_Chunk, Preset_Name)
     local start_time = reaper.time_precise()
     Write_to_File(PresetFile, Preset_HEX, Preset_Name, firstSelectedIndex)
     reaper.TrackFX_SetPreset(track, fxnum, Preset_Name) -- For "update", but this is optional
  end
end 


function saveSelectedPresetData(track, fxnum, num_presets, fx_name, track_name, currentName)
    -- Get the index of the first selected preset
    local existingNames = {}
    
    -- Create a set of all existing preset names
    for _, preset in ipairs(presetList) do
        existingNames[preset.name] = true
    end
    
    local selectedIndex = nil
    for i, selected in pairs(selectedPresets) do
        if selected then
            selectedIndex = i
            break
        end
    end
    
    Preset_Name = getNextUniqueName(currentName, existingNames)
    Save_VST_Preset(track, fxnum, Preset_Name)
end

function overwriteSelectedPresetData(track, fxnum, num_presets, fx_name, track_name, currentName, firstSelectedIndex)
    -- Get the index of the first selected preset
    local selectedIndex = nil
    for i, selected in pairs(selectedPresets) do
        if selected then
            selectedIndex = i
            break
        end
    end

    if selectedIndex == nil then
        return
    end

    -- Get the name of the selected preset
    local selectedPresetName = presetList[selectedIndex].name

    -- Remove the selected preset from the preset file
    local PresetFile = reaper.TrackFX_GetUserPresetFilename(track, fxnum, "")
    local file = io.open(PresetFile, "r")
    local content = file:read("*all")
    file:close()

    local presetPattern = "%[Preset%d+%].-Len=%d+"
    local presetToRemovePattern = "%[Preset" .. (selectedIndex - 1) .. "%].-Len=%d+"
    local removedPreset = content:match(presetToRemovePattern)
    content = content:gsub(presetToRemovePattern, "")

    -- Update the preset count in the file
    local numPresetsPattern = "NbPresets=(%d+)"
    local numPresets = tonumber(content:match(numPresetsPattern))
    content = content:gsub(numPresetsPattern, "NbPresets=" .. (numPresets - 1))

    -- Write the updated content back to the file
    file = io.open(PresetFile, "w")
    file:write(content)
    file:close()

    -- Save the current settings as the selected preset
    Save_VST_Preset(track, fxnum, selectedPresetName, firstSelectedIndex)
end


function keyboard_shortcuts()
      if reaper.ImGui_GetKeyMods(ctx) == 8192 then shift = true else shift = false end
      if reaper.ImGui_GetKeyMods(ctx) == 4096 then ctrl = true else ctrl = false end
      if reaper.ImGui_GetKeyMods(ctx) == 16384 then alt = true else alt = false end
      if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Delete()) then delete() end
      if shift and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_D()) then duplicate() end
      if ctrl and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_D()) then duplicate() end
      if ctrl and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_A()) then selectAll() end
      if ctrl and reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_X()) then delete() end
      return shift, ctrl, alt
end

-------------------------------------------------
local function loop()
  --local windowflags = reaper.ImGui_WindowFlags_MenuBar();
  size_flags = reaper.ImGui_Cond_FirstUseEver()
  reaper.ImGui_SetNextWindowSize(ctx, 500, 700, size_flags)

  local visible, open = reaper.ImGui_Begin(ctx, "Preset Manager", true, windowflags);
  if visible then
    track, fxnum, num_presets, fx_name, track_name = getLastTouchFX()

    if fx_name and fx_name ~= previousFXName then
      loadPresets(track, fxnum, num_presets, fx_name, track_name)
      previousFXName = fx_name
    end

    shift, ctrl, alt = keyboard_shortcuts()

    if not fx_name then
      reaper.ImGui_Text(ctx, '(No FX Focused) ' .. ' ')
    else
      reaper.ImGui_Text(ctx, '' .. fx_name)
    end
    --[[
    if not track_name then
      reaper.ImGui_Text(ctx, ' ' .. ' ')
    else
      reaper.ImGui_Text(ctx, '' .. track_name)
    end
    --]]
    reaper.ImGui_Dummy(ctx, 0, 0)
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Dummy(ctx, 0, 0)
    if reaper.ImGui_Button(ctx, 'Rename') then
      renamePreset()
    end
    reaper.ImGui_SameLine(ctx)
    
    if reaper.ImGui_Button(ctx, 'Enumerate') then
      enumerate(presetList, selectedPresets)
      else if reaper.ImGui_IsItemClicked(ctx, 1) then
        removeEnumeration(presetList, selectedPresets)
      end
    end
    reaper.ImGui_SameLine(ctx)

    if reaper.ImGui_Button(ctx, 'Sort') then
      selectAll()
      sort(presetList, selectedPresets, 0)
      unselectAll()
      else if reaper.ImGui_IsItemClicked(ctx, 1) then
        selectAll()
        sort(presetList, selectedPresets, 1)
        unselectAll()
      end
      
    end

    if reaper.ImGui_Button(ctx, 'Duplicate') then
      duplicate()
    end
    reaper.ImGui_SameLine(ctx)

    if reaper.ImGui_Button(ctx, 'Delete') then
      delete()
    end
    reaper.ImGui_SameLine(ctx)

    if reaper.ImGui_Button(ctx, 'Select All') then
      selectAll()
    end

    reaper.ImGui_Dummy(ctx, 0, 4)
    
    if reaper.ImGui_Button(ctx, 'Refresh FX') then
      refreshFX(track, fxnum)
    end
    
    reaper.ImGui_SameLine(ctx)
    
    if reaper.ImGui_Button(ctx, 'Load') then
      loadPresets(track, fxnum, num_presets, fx_name, track_name)
    end
    reaper.ImGui_SameLine(ctx)
    --if firstSelectedIndex then print(firstSelectedIndex)end
    if reaper.ImGui_Button(ctx, 'Save') then
      --print(currentName)
      overwriteSelectedPresetData(track, fxnum, num_presets, fx_name, track_name, currentName, firstSelectedIndex)
      loadPresets(track, fxnum, num_presets, fx_name, track_name)
    end
    reaper.ImGui_SameLine(ctx)
    
    if reaper.ImGui_Button(ctx, 'Save As') then
      --print(currentName)
      saveSelectedPresetData(track, fxnum, num_presets, fx_name, track_name, currentName)
      loadPresets(track, fxnum, num_presets, fx_name, track_name)
    end
    

    reaper.ImGui_Dummy(ctx, 0, 4)
    reaper.ImGui_Text(ctx, 'Presets:')
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Dummy(ctx, 0, 0)
    
    _, autoSwitchPreset = reaper.ImGui_Checkbox(ctx, "Switch to preset on click", autoSwitchPreset)
    
    local numSelectedPresets = 0
    local firstSelectedIndex = nil
    local lastSelectedIndex = nil

    for i, selected in pairs(selectedPresets) do
      if selected then
        numSelectedPresets = numSelectedPresets + 1
        if not firstSelectedIndex then
          firstSelectedIndex = i
        end
      end
    end
    
    -- Define a variable to store the input field text
    local inputFieldText = ""
    
    if firstSelectedIndex then
      -- Check that presetList exists and that the index is within a valid range
      if presetList and firstSelectedIndex <= #presetList and presetList[firstSelectedIndex] then
        -- Get the current name of the selected preset
        currentName = presetList[firstSelectedIndex].name
        if currentName then
          inputFieldText = currentName
        end
      end
    end
    
    -- Show the input field and get the new name e  qntered by the user
    local inputChanged, newName = reaper.ImGui_InputText(ctx, ' ', inputFieldText)
    if inputChanged and newName ~= "" and firstSelectedIndex then
      -- Update the name of the selected preset
      presetList[firstSelectedIndex].name = newName
      -- Save the updated preset list
      savePresets()
    end
    
    reaper.ImGui_Dummy(ctx, 0, 0)
    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Dummy(ctx, 0, 0)
    --]]
    if fx_name ~= nil then
      
      local rangeStartIndex = nil
      for i, preset in ipairs(presetList) do
        local selected = selectedPresets[i]
        if reaper.ImGui_Selectable(ctx, preset.name, selected) then
          if shift and rangeStartIndex then
            -- Shift is held down: select multiple presets in a row
            local startIndex = math.min(rangeStartIndex, i)
            local endIndex = math.max(rangeStartIndex, i)
            -- Clear previous selection
            selectedPresets = {}
            -- Select the range of presets between startIndex and endIndex
            for j = startIndex, endIndex do
              selectedPresets[j] = true
            end
          elseif ctrl then
            -- Ctrl is held down: select multiple presets not in a row (toggle selection)
            selectedPresets[i] = not selected
            if not rangeStartIndex then
              rangeStartIndex = i
            end
          elseif alt then
            -- Alt is held down: unselect all presets
            selectedPresets = {}
          else
            -- No key modifier: clear previous selection and select the current item
            selectedPresets = {}
            selectedPresets[i] = true
            rangeStartIndex = i         -- Set the starting index for range selection
          end
          if autoSwitchPreset then
            switchToPreset(track, fxnum, i)
          end
        elseif selected and not rangeStartIndex then
          rangeStartIndex = i
        end
        
      -- Check for right-click on the selectable item
        if reaper.ImGui_BeginPopupContextItem(ctx) then
            if reaper.ImGui_MenuItem(ctx, "Rename") then
                renamePreset()
            end
            if reaper.ImGui_MenuItem(ctx, "Duplicate") then
                duplicate()
            end
            if reaper.ImGui_MenuItem(ctx, "Delete") then
                delete()
            end
            if reaper.ImGui_MenuItem(ctx, "Save") then
                if firstSelectedIndex then
                    overwriteSelectedPresetData(track, fxnum, num_presets, fx_name, track_name, currentName)
                    loadPresets(track, fxnum, num_presets, fx_name, track_name)
                end
            end
            if reaper.ImGui_MenuItem(ctx, "Enumerate") then
                enumerate(presetList, selectedPresets)
            end
            reaper.ImGui_EndPopup(ctx)
        end
        
        
        -- Drag-and-drop source
        if reaper.ImGui_BeginDragDropSource(ctx) then
          reaper.ImGui_SetDragDropPayload(ctx, 'reorder', tostring(i))
          reaper.ImGui_Text(ctx, 'Reorder: ' .. preset.name)
          reaper.ImGui_EndDragDropSource(ctx)
        end

        -- Drag-and-drop target
        if reaper.ImGui_BeginDragDropTarget(ctx) then
          local payload, dataType, dataSize = reaper.ImGui_AcceptDragDropPayload(ctx, 'reorder')
          if payload then
            local fromIndex = tonumber(payload)
            local toIndex = i
            if fromIndex ~= toIndex then
              local movedPreset = table.remove(presetList, dataType)
              table.insert(presetList, toIndex, movedPreset)
              savePresets()           -- Save changes to the preset file
            end
          end
          reaper.ImGui_EndDragDropTarget(ctx)
        end
      end
    end
    reaper.ImGui_End(ctx);
  end

  if open then
    reaper.defer(loop);
  else
    exit()
  end
end

------------------------------

reaper.atexit(exit)
reaper.defer(loop);
