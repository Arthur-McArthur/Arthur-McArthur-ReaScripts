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

local params = {}
-- local themeEditor
 colors = {}
 colorValues = {}

function params.getinfo(script_path, resources_path, themes_path)
    themeEditor = dofile(script_path .. '/Modules/Theme Editor.lua')
    colors = themeEditor(script_path, resources_path, themes_path)
    colorValues = colors.colorUpdate()

    -- printTable(colorValues)
    params.initializeParams()
end

function params.initializeParams()
    if colorValues then

     
    params.patternSelect = {
        frameWidth = 32,
        frameHeight = 32,
        frameCount = 1,
        min = 1,
        max = 999,
        default = 1,
        scaling = 1,
        dragSensitivity = .0001,
        dragFineSensitivity = 15,
        wheelSensitivity = .1,
        wheelFineSensitivity = 15,
        showID = false,
        applySnap = true,
        snapAmount = 1
    }   

    params.patternLength = {
        frameWidth = 32,
        frameHeight = 32,
        frameCount = 1,
        min = 1,
        max = 64,
        default = 32,
        scaling = 1,
        dragSensitivity = .01,
        dragFineSensitivity = .01,
        wheelSensitivity = 1,
        wheelFineSensitivity = .01,
        showID = false,
        applySnap = true,
        snapAmount = 1

    }  

    params.knobVolume = {
        frameWidth = 32,
        frameHeight = 32,
        frameCount = 135,
        min = 0,
        max = 4,
        default = 1,
        scaling = 0.3,
        dragSensitivity = 0.25,
        dragFineSensitivity = 0.025,
        wheelSensitivity = 1,
        wheelFineSensitivity = .1,
        showID = false,
        applySnap = false,
        snapAmount = 0.1
    }

    params.knobPan = {
        frameWidth = 32,
        frameHeight = 32,
        frameCount = 135,
        min = -1,
        max = 1,
        default = 0,
        scaling = 1,
        dragSensitivity = 0.5,
        dragFineSensitivity = 0.2,
        wheelSensitivity = 2,
        wheelFineSensitivity = 1,
        showID = false,
        applySnap = false,
        snapAmount = 0.1
    }

    params.knobBoost = {
        frameWidth = 32,
        frameHeight = 32,
        frameCount = 135,
        min = 1,
        max = 4,
        default = 1,
        scaling = 1,
        dragSensitivity = .5,
        dragFineSensitivity = 0.05,
        wheelSensitivity = .5,
        wheelFineSensitivity = .05,
        showID = 'Release',
        applySnap = false,
        snapAmount = 0.1,
    }

    params.knobStart = {
        frameWidth = 32,
        frameHeight = 32,
        frameCount = 135,
        min = 0,
        max = 1,
        default = 0,
        scaling = .3,
        dragSensitivity = 1,
        dragFineSensitivity = 0.1,
        wheelSensitivity = 1,
        wheelFineSensitivity = .1,
        showID = 'Release',
        applySnap = false,
        snapAmount = 0.1,
    }

    
    params.knobEnd = {
        frameWidth = 32,
        frameHeight = 32,
        frameCount = 135,
        min = 0,
        max = 1,
        default = 1,
        scaling = 1,
        dragSensitivity = 1,
        dragFineSensitivity = 0.1,
        wheelSensitivity = 1,
        wheelFineSensitivity = .1,
        showID = 'Release',
        applySnap = false,
        snapAmount = 0.1,
    }

    params.sliderPitch = {
        frameWidth = 160,
        frameHeight = 20,
        frameCount = 160,
        min = .2,
        max = .8,
        default = .5,
        scaling = 1,
        dragSensitivity = 1,
        dragFineSensitivity = 0.025,
        wheelSensitivity = .4688,
        wheelFineSensitivity = .01,
        showID = 'Release',
        applySnap = true,
        snapAmount = 0.00625,
        dragDirection = "Horizontal"
    }

    params.knobAttack = {
        frameWidth = 32,
        frameHeight = 32,
        frameCount = 135,
        min = 0,
        max = 1,
        default = 0,
        scaling = 0.3,
        dragSensitivity = 1,
        dragFineSensitivity = 0.1,
        wheelSensitivity = 1,
        wheelFineSensitivity = .1,
        showID = 'Attack',
        applySnap = false,
        snapAmount = 0.1,
    }

    params.knobDecay = {
        frameWidth = 32,
        frameHeight = 32,
        frameCount = 135,
        min = 0,
        max = 1,
        default = 0,
        scaling = 0.24,
        dragSensitivity = 1,
        dragFineSensitivity = 0.1,
        wheelSensitivity = 1,
        wheelFineSensitivity = .1,
        showID = 'Decay',
        applySnap = false,
        snapAmount = 0.1,
    }

    params.knobSustain = {
        frameWidth = 32,
        frameHeight = 32,
        frameCount = 135,
        min = 0,
        max = 1,
        default = 1,
        scaling = 0.618,
        dragSensitivity = 1,
        dragFineSensitivity = 0.1,
        wheelSensitivity = 1,
        wheelFineSensitivity = .1,
        showID = 'Sustain',
        applySnap = false,
        snapAmount = 0.1,
    }

    params.knobRelease = {
        frameWidth = 32,
        frameHeight = 32,
        frameCount = 135,
        min = 0,
        max = 1,
        default = 0.006,
        scaling = 0.618,
        dragSensitivity = 1,
        dragFineSensitivity = 0.1,
        wheelSensitivity = 1,
        wheelFineSensitivity = .1,
        showID = 'Release',
        applySnap = false,
        snapAmount = 0.1,
    }

    params.knobOffset = {
        frameWidth = 32,
        frameHeight = 32,
        frameCount = 135,
        min = 0,
        max = 50,
        default = 0,
        scaling = 1,
        dragSensitivity = 1,
        dragFineSensitivity = 0.5,
        wheelSensitivity = 0.5,
        wheelFineSensitivity = 0.5,
        applySnap = true,
        snapAmount = 0.5,
    }

    params.knobSwing = {
        frameWidth = 32,
        frameHeight = 32,
        frameCount = 135,
        min = 0,
        max = 50,
        default = 0,
        scaling = 1,
        dragSensitivity = 1,
        dragFineSensitivity = 0.5,
        wheelSensitivity = 0.5,
        wheelFineSensitivity = 0.5,
        applySnap = true,
        snapAmount = 0.5,
    }


    

    end

end


return params