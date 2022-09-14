require "graphics"

-- B2VolumeControl.lua
--   To be used in conjunction with X-Plane's FlyWithLua scripting package
--   Developed with FlyWithLua NG+ 2.8.0, which is a new version for X-Plane 12
-- 
--   Place B2VolumeControl.lua in your FlyWithLua scripts folder
--      path:    ...\X-Plane 12\Resources\plugins\FlyWithLua\Scripts\
--
--   ** This script will allow you to adjust the X-Plane11 sound sliders without going
--          into the settings menu and without needing to pause the simulator.  
--
--   To activate :: move your mouse to upper right corner of the screen
--                      and click on the magically appearing 'sound icon'
--   To adjust   :: use your mouse wheel to change the value of the given 'knob'
--   To hide     :: just click the 'sound icon' again and it'll hide the knobs from view
--
--   NOTE:  some 'knobs' adjust the volume of sounds that don't seem related, but this should
--              be identical functionality to using the X-Plane settings sliders 
--   NOTE:  some aircraft may 'compete' with this script, not allowing the values to change
--              as desired, so if you roll your mouse wheel while over a 'knob' and nothing
--              happens, that is probably why
--
--   Initial version 1:    Aug 2018    B2_   knobs to control sound
--           version 2:    Aug 2018    B2_   added interior/exterior knobs, save/load a preference file,
--                                           and ability to drag the widget
--           version 2.1:  Aug 2018    B2_   fix reloading of lua scripts when in external view
--           version 2.2:  Oct 2021    B2_   add haze control
--                                           removed tiny gaps in scroll wheel capture
--           version 2.3:  Mar 2022    B2_   change string.gfind to string.gmatch, without haze control
--           version 2.3h: Mar 2022    B2_   2.2 with haze control
--           version 2.4:  Sep 2022    B2_   removed all haze (deprecated)fog_be_gone reference
--                                           added 'pilot' volume knob
--
-- Copyright 2022 B2videogames@gmail.com
--  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
--  associated documentation files (the "Software"), to deal in the Software without restriction,
--  including without limitation the rights to use, copy, modify, merge, publish, distribute,
--  sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
--  furnished to do so, subject to the following conditions:
-- 
--  The above copyright notice and this permission notice shall be included in all copies or substantial
--  portions of the Software.
-- 
--  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
--  NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
--  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
--  OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
--  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

local b2vc_SoftwareVersion = "2.4"
 --   ver 2.1   Original release
 --   ver 2.2   haze control
 --   ver 2.3   Lua 5.1 compatible, without haze control
 --   ver 2.3h  Lua 5.1 compatible, with haze control
 --   ver 2.4   removed haze support for XP12, added pilot knob
local b2vc_FileFormat = 2
 --   ver 1     Original
 --   ver 2     added 'Pilot' knob

dataref("b2vc_mastervolume", "sim/operation/sound/master_volume_ratio", "writable")
dataref("b2vc_exteriorVolume", "sim/operation/sound/exterior_volume_ratio", "writable")
dataref("b2vc_interiorVolume", "sim/operation/sound/interior_volume_ratio", "writable")
dataref("b2vc_pilotVolume", "sim/operation/sound/pilot_volume_ratio", "writable")
dataref("b2vc_copilotVolume", "sim/operation/sound/copilot_volume_ratio", "writable")
dataref("b2vc_radioVolume", "sim/operation/sound/radio_volume_ratio", "writable")
dataref("b2vc_enviroVolume", "sim/operation/sound/enviro_volume_ratio", "writable")
dataref("b2vc_uiVolume", "sim/operation/sound/ui_volume_ratio", "writable")
dataref("b2vc_viewExternal", "sim/graphics/view/view_is_external")

local snapMainX = SCREEN_WIDTH - 10
local snapMainY = SCREEN_HIGHT - 40
local mainX = snapMainX
local mainY = snapMainY

-- -- -- -- --  a bunch of local variables
local prevX = mainX
local prevY = mainY
local prevView = b2vc_viewExternal
local bDrawControlBox = false
local bScreenSizeChanged = true
local bFirstDraw = true
local bSaveRequired = true
local knobRadius = 20
local knobDiameter = knobRadius*2
local gapFive = 5
local fixedTextSpace = 60
local bDragging = false
local bAutoPosition = true
local initialTest = 1
local knobSingleMark = -1   -- no interior/exterior separation
local knobFailedTest = -2   -- 'failed' set test
local i  -- just for local iterations

-- knobs[knobX,knobY,knobName,knobTextX,knobInt,knobExt]
local numVolKnobs = 8  -- total count of Volume datarefs
local knobX = 1
local knobY = 2
local knobName = 3
local knobTextX = 4
local knobInt = 5   -- Volume used for both if knobExt = knobSingleMark
local knobExt = 6   -- volume or knobFailedTest or knobSingleMark
local knobs = { {0, 0, "master",   0, b2vc_mastervolume,   knobSingleMark},
                {0, 0, "exterior", 0, b2vc_exteriorVolume, knobSingleMark},
                {0, 0, "interior", 0, b2vc_interiorVolume, knobSingleMark},
                {0, 0, "pilot",    0, b2vc_pilotVolume,    knobSingleMark},
                {0, 0, "copilot",  0, b2vc_copilotVolume,  knobSingleMark},
                {0, 0, "radio",    0, b2vc_radioVolume,    knobSingleMark},
                {0, 0, "enviro",   0, b2vc_enviroVolume,   knobSingleMark},
                {0, 0, "ui",       0, b2vc_uiVolume,       knobSingleMark} }

do_often("B2VolumeControl_everySec()")
do_every_draw("B2VolumeControl_everyDraw()")
do_every_frame("B2VolumeControl_everyFrame()")
do_on_mouse_click("B2VolumeControl_mouseClick()")
do_on_mouse_wheel("B2VolumeControl_onMouseWheel()")

function B2VolumeControl_everySec()
    if not(snapMainX == (SCREEN_WIDTH - 10)) then
        bScreenSizeChanged = true
        snapMainX = SCREEN_WIDTH - 10
    end
    if not(snapMainY == (SCREEN_HIGHT - 40)) then
        bScreenSizeChanged = true
        snapMainY = SCREEN_HIGHT - 40
    end

    if (bAutoPosition == true) then
        -- handle screen width changes
        if (bScreenSizeChanged) then
            mainX = snapMainX
            mainY = snapMainY
        end
    else -- manual position
        -- make sure we aren't drawing off the screen
        -- X:: from mainX-knobDiameter-fixedTextSpace to mainX
        -- Y:: from mainY-(4*gapFive)-(numVolKnobs*knobDiameter)- ((numVolKnobs+1)*gapFive) to mainY+15
        if ((mainX-knobDiameter-fixedTextSpace) < 0) then
            mainX = knobDiameter+fixedTextSpace
        elseif (mainX > SCREEN_WIDTH) then 
            mainX = SCREEN_WIDTH
        end
        if (mainY-(4*gapFive)-(numVolKnobs*knobDiameter)-((numVolKnobs+1)*gapFive) < 0) then
            mainY = (4*gapFive)+(numVolKnobs*knobDiameter)+((numVolKnobs+1)*gapFive)
        elseif ((mainY+15) > SCREEN_HIGHT) then
            mainY = SCREEN_HIGHT - 15
        end
    end
end

function B2VolumeControl_everyFrame()
    -- going to do a quick test to see if we are allowed to change the value of
    -- the volume sliders or not, then read any previous config files

    local testValue = 0.03125 -- a good 'binary' random number to prevent float issues
    if (initialTest == 1) then                                  -- stage 1 of test
        for i = 1,numVolKnobs do
            knobs[i][knobExt] = B2VolumeControl_GetVolume(i)    -- store original Value 
            B2VolumeControl_SetVolume(i,testValue)              -- set a random number to see if it takes
        end
        initialTest = 2                                         -- ready for stage 2 of test
        return
    elseif (initialTest == 2) then
        for i = 1,numVolKnobs do
            local testResult = B2VolumeControl_GetVolume(i)
            if (testResult == testValue) then                   -- check against test number
                testResult = knobSingleMark                     -- test passed
            else
                testResult = knobFailedTest                     -- test Failed
            end
            B2VolumeControl_SetVolume(i,knobs[i][knobExt])      -- return to original value
            knobs[i][knobExt] = testResult
        end
        initialTest = 3                                         -- ready for stage 3, loading config
    elseif (initialTest == 3) then
        B2VolumeControl_OpenParseConfig()
        initialTest = 0                                         -- done startup initialization
    end

    -- if/when the view is swapped from interior/exterior (or vice versa) 
    -- we need to handle the active dial swaps
    if not(prevView == b2vc_viewExternal) then --internal/external view swap, change volumes if necessary
        for i = 1,numVolKnobs do
            if (knobs[i][knobExt] >= 0) then
                if (b2vc_viewExternal == 0) then    -- internal view
                    B2VolumeControl_SetVolume(i,knobs[i][knobInt])
                else                                -- external view
                    B2VolumeControl_SetVolume(i,knobs[i][knobExt])
                end
            end
        end
        prevView = b2vc_viewExternal
        bFirstDraw = true
    end
end

function B2VolumeControl_everyDraw()
    -- OpenGL graphics state initialization
    XPLMSetGraphicsState(0,0,0,1,1,0,0)                     -- use only in do_every_draw()

    if (bDrawControlBox == true or
        (MOUSE_X >= (mainX-100) and MOUSE_X <= (mainX+100) and 
         MOUSE_Y >= (mainY-100) and MOUSE_Y <= (mainY+100))) then
        graphics.set_width(1)

        -- always draw clickable sound icon
        graphics.set_color(0,0,0,1) -- black
        graphics.draw_rectangle(mainX-40,mainY-8,mainX-20,mainY+8)
        graphics.draw_triangle(mainX-40,mainY,mainX-20,mainY+15,mainX-20,mainY-15)

        graphics.set_color(0.4,0.4,0.4,1) -- gray
        graphics.draw_rectangle(mainX-39,mainY-7,mainX-21,mainY+7)
        graphics.draw_triangle(mainX-37,mainY,mainX-21,mainY+13,mainX-21,mainY-13)

        if (bDrawControlBox == true) then
            -- draw 'drag' wheel
            graphics.set_color(1,1,1,0.5) -- white border
            graphics.draw_filled_circle(mainX-95,mainY,5)
            graphics.set_color(140/255,128/255,99/255,0.8) -- fill in color
            graphics.draw_filled_circle(mainX-95,mainY,4)

            -- draw 'save' icon
            if (bSaveRequired == true) then
                graphics.set_color(1,0,0,0.5) -- red border
            else
                graphics.set_color(0,1,0,0.5) -- green border
            end
            graphics.draw_triangle(mainX-65,mainY-3,mainX-72,mainY+7,mainX-58,mainY+7)
            graphics.draw_line(mainX-74,mainY-1,mainX-74,mainY-9)
            graphics.draw_line(mainX-74,mainY-9,mainX-56,mainY-9)
            graphics.draw_line(mainX-56,mainY-9,mainX-56,mainY-1)
            graphics.set_color(0,0,0,0.5) -- fill in color
            graphics.draw_triangle(mainX-65,mainY,mainX-70,mainY+6,mainX-60,mainY+6)
            graphics.draw_line(mainX-73,mainY-1,mainX-73,mainY-8)
            graphics.draw_line(mainX-73,mainY-8,mainX-57,mainY-8)
            graphics.draw_line(mainX-57,mainY-8,mainX-57,mainY-1)

            -- draw 'active' sound icon
            graphics.set_color(140/255,128/255,99/255,1) -- fill in color
            graphics.draw_rectangle(mainX-38,mainY-6,mainX-22,mainY+6)
            graphics.draw_triangle(mainX-34,mainY,mainX-22,mainY+11,mainX-21,mainY-11)

            graphics.set_color(173/255,31/255,31/255,1) -- red
            graphics.draw_line(mainX-15,mainY+5,mainX-4,mainY+10)
            graphics.draw_line(mainX-15,mainY,mainX,mainY)
            graphics.draw_line(mainX-15,mainY-5,mainX-4,mainY-10)

            -- recompute workspace / knobs if needed
            local topBoxY = mainY - (4*gapFive)

            if (bScreenSizeChanged == true) then
                local y = topBoxY - knobRadius
                local textX = mainX - knobDiameter - fixedTextSpace + 3   -- the '+3' just makes it look nicer
                for i = 1,numVolKnobs do
                    knobs[i][knobX] = mainX - knobRadius - 2                -- '-2' just to look nicer
                    knobs[i][knobY] = y - 1                                 -- '-1' just to look nicer
                    knobs[i][knobTextX] = textX
                    y = y - gapFive - knobDiameter     -- change 'y' for next knob
                end
                y = y - gapFive
            end

            -- draw background workspace box
            graphics.set_color(66/255, 66/255, 66/255, 1) -- dark gray
            local x1 = mainX - knobDiameter - fixedTextSpace
            local y2 = topBoxY - (numVolKnobs*knobDiameter) - ((numVolKnobs+1)*gapFive)
            graphics.draw_rectangle(x1,topBoxY,mainX,y2)

            graphics.set_color(45/255,150/255,10/255,1) -- green
            for i = 1,numVolKnobs do
                B2VolumeControl_drawKnob(i)
            end

            bFirstDraw = false
        end -- box drawn
    end -- mouse near click spot
end

function B2VolumeControl_mouseClick()
    if (MOUSE_STATUS == "up") then bDragging = false end

    if (MOUSE_STATUS == "down" and bDrawControlBox == true) then
        for i = 1,numVolKnobs do
            if (MOUSE_X >= (knobs[i][knobX]-knobRadius-fixedTextSpace) and MOUSE_X <= (knobs[i][knobX]+knobRadius) and
                MOUSE_Y >= (knobs[i][knobY]-knobRadius) and MOUSE_Y <= (knobs[i][knobY]+knobRadius)) then
                RESUME_MOUSE_CLICK = true
                if not(knobs[i][knobExt] == knobFailedTest) then bSaveRequired = true end   -- unchangeable knob

                if (knobs[i][knobExt] == knobSingleMark) then
                    -- toggle Inner/Outer enabled by setting knobExt to current shared value
                    knobs[i][knobExt] = knobs[i][knobInt]
                elseif (knobs[i][knobExt] >= 0) then
                    -- toggle Inner/Outer disabled by setting knobExt to knobSingleMark
                    if (b2vc_viewExternal == 0) then    -- internal view
                        knobs[i][knobExt] = knobSingleMark
                    else                                -- external view
                        knobs[i][knobInt] = knobs[i][knobExt]
                        knobs[i][knobExt] = knobSingleMark
                    end
                end
                return
            end
        end
    end

    -- check if position over our toggle icon
    if (MOUSE_STATUS == "down" and 
        MOUSE_X >= (mainX-40) and MOUSE_X <= mainX and 
        MOUSE_Y >= (mainY-15) and MOUSE_Y <= (mainY+15)) then
        RESUME_MOUSE_CLICK = true

        if (bDrawControlBox == true) then
            bDrawControlBox = false
        else 
            bDrawControlBox = true  -- draw the box
        end
    end

    -- check if position over our save icon
    if (MOUSE_STATUS == "down" and 
        MOUSE_X >= (mainX-74) and MOUSE_X <= (mainX-55) and 
        MOUSE_Y >= (mainY-9) and MOUSE_Y <= (mainY+7)) then
        B2VolumeControl_SaveModifiedConfig()
    end

    -- check if position over our drag icon
    if (MOUSE_STATUS == "down" and 
        MOUSE_X >= (mainX-95-5) and MOUSE_X <= (mainX-95+5) and 
        MOUSE_Y >= (mainY-5) and MOUSE_Y <= (mainY+5)) then
        bDragging = true
        RESUME_MOUSE_CLICK = true
    elseif (bDragging == true and MOUSE_STATUS == "drag") then
        mainX = MOUSE_X + 95
        mainY = MOUSE_Y
        bAutoPosition = false
        bSaveRequired = true

        -- see if we are 'close enough' to original default to snap in place
        if (mainX > snapMainX - 20 and mainX < snapMainX + 20 and 
            mainY > snapMainY - 15 and mainY < snapMainY + 15) then
            mainX = snapMainX
            mainY = snapMainY
            bAutoPosition = true
        end
    end
end

function B2VolumeControl_onMouseWheel()
    -- mouse wheel only important if knobs visible
    if (bDrawControlBox == false) then return end

    -- eat MOUSE_WHEEL if within our box
    if (MOUSE_X >= (mainX - knobDiameter - fixedTextSpace) and 
        MOUSE_X <= mainX and 
        MOUSE_Y >= (mainY - (4*gapFive) - (numVolKnobs*knobDiameter) - ((numVolKnobs+1)*gapFive)) and 
        MOUSE_Y <= (mainY - (4*gapFive))) then
        RESUME_MOUSE_WHEEL = true
    end

    for i = 1,numVolKnobs do
        if (MOUSE_X >= (knobs[i][knobX]-knobRadius-fixedTextSpace) and MOUSE_X <= (knobs[i][knobX]+knobRadius) and
            MOUSE_Y >= (knobs[i][knobY]-knobRadius) and MOUSE_Y <= (knobs[i][knobY]+knobRadius)) then
            B2VolumeControl_SetVolume(i,B2VolumeControl_GetVolume(i)+(MOUSE_WHEEL_CLICKS*0.02))
            if not(knobs[i][knobExt] == knobFailedTest) then bSaveRequired = true end   -- unchangeable knob
            return
        end
    end

end

function B2VolumeControl_drawKnob(i)
    if (i < 1 or i > numVolKnobs) then return end  -- array size protection

    local x = knobs[i][knobX]
    local y = knobs[i][knobY]

    if (prevView == b2vc_viewExternal) then  -- don't update data if view is changing
        -- before drawing the arcs, make sure the data we have is up to date
        if (knobs[i][knobExt] < 0 or b2vc_viewExternal == 0) then   -- for single mark or interior view
            if not(knobs[i][knobInt] == B2VolumeControl_GetVolume(i)) then
                if (bFirstDraw == false and not(knobs[i][knobExt] == knobFailedTest)) then bFirstDraw = true bSaveRequired = true end
            end
            knobs[i][knobInt] = B2VolumeControl_GetVolume(i)
        else                                                        -- for external view
            if not(knobs[i][knobExt] == B2VolumeControl_GetVolume(i)) then
                if (bFirstDraw == false) then bFirstDraw = true bSaveRequired = true end
            end
            knobs[i][knobExt] = B2VolumeControl_GetVolume(i)
        end
    end

    -- x,y are center of knob with knobRadius, volume(s) are between (0.0 - 1.0)
    -- arcs 210-150 (300 degrees) so ((volume * 300)+210)%360 = angle of pointer

    graphics.set_color(0,0,0,1) -- black border
    graphics.draw_arc(x,y,210,360,knobRadius,1)
    graphics.draw_arc(x,y,0,150,knobRadius,1)
    graphics.set_color(140/255,128/255,99/255,1) -- fill knob top color
    graphics.draw_filled_arc(x,y,210,360,19)
    graphics.draw_filled_arc(x,y,0,150,19)

    if (knobs[i][knobExt] == knobFailedTest) then               -- can't change, draw all black, thin
        graphics.set_color(0,0,0,1)                 -- black
        graphics.draw_angle_arrow(x,y,((knobs[i][knobInt]*300)+210)%360,knobRadius-1,knobRadius/2,1)
    elseif (knobs[i][knobExt] == knobSingleMark) then           -- shared value, draw pointer
        graphics.set_color(173/255,31/255,31/255,1) -- a nice red
        graphics.draw_angle_arrow(x,y,((knobs[i][knobInt]*300)+210)%360,knobRadius-1,knobRadius/2,2)
    elseif (b2vc_viewExternal == 0) then            -- current view is internal
        graphics.set_color(173/255,31/255,31/255,1) -- a nice red
        graphics.draw_tick_mark(x,y,((knobs[i][knobInt]*300)+210)%360,(knobRadius-1)/2,(knobRadius-1)/2,3)  -- inner tick
        graphics.set_color(0,0,0,1)                 -- black
        graphics.draw_tick_mark(x,y,((knobs[i][knobExt]*300)+210)%360,knobRadius-1,(knobRadius-1)/2,3)      -- outer tick
    else                                            -- current view is external
        graphics.set_color(0,0,0,1)                 -- black
        graphics.draw_tick_mark(x,y,((knobs[i][knobInt]*300)+210)%360,(knobRadius-1)/2,(knobRadius-1)/2,3)  -- inner tick
        graphics.set_color(173/255,31/255,31/255,1) -- a nice red
        graphics.draw_tick_mark(x,y,((knobs[i][knobExt]*300)+210)%360,knobRadius-1,(knobRadius-1)/2,3)      -- outer tick
    end

    draw_string(knobs[i][knobTextX],y,knobs[i][knobName],239/255,219/255,172/255)
end

function B2VolumeControl_OpenParseConfig()
    local configFile = io.open(SCRIPT_DIRECTORY .. "B2VolumeControl.dat","r")
    if not(configFile) then             -- if no config file, just return now
        return
    end

    local tmpStr = configFile:read("*all")
    configFile:close()

    local fileVersion = nil
    local fileX = nil
    local fileY = nil
    local fileName = nil
    
    for i in string.gmatch(tmpStr,"%s*(.-)\n") do
        if (fileVersion == nil) then 
            _,_,fileVersion = string.find(i, "VERSION%s+(%d+)")
            if (fileVersion) then fileVersion = tonumber(fileVersion) end
        end
        if (fileX == nil and fileY == nil) then 
            _,_,fileX,fileY = string.find(i, "X:%s*(%d+)%s+Y:%s*(%d+)")
            if (fileX and fileY) then
                fileX = tonumber(fileX)
                fileY = tonumber(fileY)
                if (fileX and fileX >= 0 and fileX <= SCREEN_WIDTH and
                    fileY and fileY >= 0 and fileY <= SCREEN_HIGHT) then
                    mainX = fileX
                    mainY = fileY
                    bAutoPosition = false
                    bScreenSizeChanged = true
                end
            end
        end

        if (fileName == nil) then
            local lInt,lExt
            local _,_,lFileName,lData = string.find(i, "^(.+%.acf)[%s+](.+)")
            if (lFileName and lFileName == AIRCRAFT_FILENAME) then
                if (lFileName == AIRCRAFT_FILENAME) then
                    fileName = lFileName
                    local knobNum = 1
                    for lInt,lExt in string.gmatch(lData,"%s-(%d%.%d+)%s+(%-?%d%.%d+)") do 
                        knobs[knobNum][knobInt] = tonumber(lInt)
                        knobs[knobNum][knobExt] = tonumber(lExt)
                        if (b2vc_viewExternal == 0 or knobs[knobNum][knobExt] < 0) then
                            B2VolumeControl_SetVolume(knobNum,knobs[knobNum][knobInt])
                        else
                            B2VolumeControl_SetVolume(knobNum,knobs[knobNum][knobExt])
                        end
                        knobNum = knobNum + 1
                        if (knobNum == 4 and fileVersion and fileVersion == 1) then
                            knobs[knobNum][knobInt] = 1.0
                            knobs[knobNum][knobExt] = -1.0
                            B2VolumeControl_SetVolume(knobNum,1.0)
                            knobNum = knobNum + 1
                        end

                    end
                end
            end
        end
    end
    if (fileName and fileVersion and fileVersion > 1) then 
        bSaveRequired = false -- loaded this acf from file, and not old version(1) so no need to require save
    end
end

function B2VolumeControl_SaveModifiedConfig()
    local oldStr = nil  -- where we'll store all the data from the previous config file
    local newStr = nil  -- where we'll store all the data to write to the config file
    local fileVersion = nil  -- oldStr fileVersion, in case we need to convert old->new format

    local configFile = io.open(SCRIPT_DIRECTORY .. "B2VolumeControl.dat","r")
    if (configFile) then
        oldStr = configFile:read("*all")
        configFile:close()
    end

    -- store file format version
    newStr = string.format("VERSION " .. b2vc_FileFormat .. "\n")

    -- if user moved the widget manually, store where they want it
    if not(bAutoPosition) then
        newStr = string.format(newStr .. "X:" .. mainX .. " Y:" .. mainY .. "\n")
    end

    -- store the current config data for loaded acf
    newStr = string.format(newStr .. AIRCRAFT_FILENAME)
    for i = 1,numVolKnobs do
        newStr = string.format("%s %f %f",newStr,knobs[i][knobInt],knobs[i][knobExt])
    end
    newStr = string.format(newStr .. "\n")

    -- if oldStr, we need to duplicate all the acf data that isn't our current acf
    if (oldStr) then
        for i in string.gmatch(oldStr,"%s*(.-)\n") do
            if (fileVersion == nil) then 
                _,_,fileVersion = string.find(i, "VERSION%s+(%d+)")
                if (fileVersion) then fileVersion = tonumber(fileVersion) end
            end

            -- look at each line for an acf file entry, then, if that
            -- entry doesn't match the loaded acf, write its data
            local start,_,lFileName,lData = string.find(i, "^(.+%.acf)[%s+](.+)")
            if (start and not(lFileName == AIRCRAFT_FILENAME)) then
                if (fileVersion and fileVersion == 1) then
                    -- we'll need to convert each acf entry from ver=1 to current
                    local knobNum = 1
                    newStr = string.format(newStr .. lFileName)
                    for lInt,lExt in string.gmatch(lData,"%s-(%d%.%d+)%s+(%-?%d%.%d+)") do 
                        newStr = string.format("%s %f %f",newStr,lInt,lExt)
                        knobNum = knobNum + 1
                        if (knobNum == 4) then
                            -- create dummy entry for new 'pilot' knob
                            newStr = string.format(newStr .. " 1.000000 -1.000000")
                            knobNum = knobNum + 1
                        end
                    end
                newStr = string.format(newStr .. "\n")
                else
                    newStr = string.format(newStr .. i .. "\n")
                end
            end
        end
    end

    configFile = io.open(SCRIPT_DIRECTORY .. "B2VolumeControl.dat","w")
    if not(configFile) then return end      -- error handled
    io.output(configFile)
    io.write(newStr)
    configFile:close()
    bSaveRequired = false
end

function B2VolumeControl_GetVolume(i)
    if (i == 1) then return b2vc_mastervolume end
    if (i == 2) then return b2vc_exteriorVolume end
    if (i == 3) then return b2vc_interiorVolume end
    if (i == 4) then return b2vc_pilotVolume end
    if (i == 5) then return b2vc_copilotVolume end
    if (i == 6) then return b2vc_radioVolume end
    if (i == 7) then return b2vc_enviroVolume end
    if (i == 8) then return b2vc_uiVolume end

    return 0
end

function B2VolumeControl_SetVolume(i,value)
    if (value < 0.0) then value = 0.0 end
    if (value > 1.0) then value = 1.0 end
    if (i == 1) then b2vc_mastervolume = value end
    if (i == 2) then b2vc_exteriorVolume = value end
    if (i == 3) then b2vc_interiorVolume = value end
    if (i == 4) then b2vc_pilotVolume = value end
    if (i == 5) then b2vc_copilotVolume = value end
    if (i == 6) then b2vc_radioVolume = value end
    if (i == 7) then b2vc_enviroVolume = value end
    if (i == 8) then b2vc_uiVolume = value end
end
-- eof