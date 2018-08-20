require "graphics"

-- B2VolumeControl.lua
--   to be used in conjunction with X-Plane's FlyWithLua scripting package
--   developed using FlyWithLua Complete v2.6.7
-- 
--   place B2VolumeControl.lua in your FlyWithLua scripts folder
--      path:    ...\X-Plane 11\Resources\plugins\FlyWithLua\Scripts\
--
--   ** This script will allow you to adjust the X-Plane11 sound sliders without going
--          into the settings menu and without needing to pause the simulator.  
--   ** To customize the location of the widget for your personal use, you may easily
--          do so in the B2VolumeControl_LocationInitialization() function below
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
--   Initial version:   Aug 2018    B2_
--
-- Copyright 2018 'b2videogames at gmail dot com'
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


dataref("b2vc_mastervolume", "sim/operation/sound/master_volume_ratio", "writable")
dataref("b2vc_exteriorVolume", "sim/operation/sound/exterior_volume_ratio", "writable")
dataref("b2vc_interiorVolume", "sim/operation/sound/interior_volume_ratio", "writable")
dataref("b2vc_copilotVolume", "sim/operation/sound/copilot_volume_ratio", "writable")
dataref("b2vc_radioVolume", "sim/operation/sound/radio_volume_ratio", "writable")
dataref("b2vc_enviroVolume", "sim/operation/sound/enviro_volume_ratio", "writable")
dataref("b2vc_uiVolume", "sim/operation/sound/ui_volume_ratio", "writable")
local displayItems = 7  -- total count of above

local mainX = SCREEN_WIDTH - 10  -- default position, to change use B2VolumeControl_LocationInitialization()
local mainY = SCREEN_HIGHT - 40  -- default position, to change use B2VolumeControl_LocationInitialization()
local prevX = mainX
local prevY = mainY
local bDrawControlBox = false
local bScreenSizeChanged = true
local knobRadius = 20
local fixedGap = 5
local topBoxY = mainY - (4*fixedGap)
local fixedTextSpace = 60
local timeStamp = os.clock();

-- knobs[knobX,knobY,nameOfKnob,textX]
local knobs = { {0,  0,  "master",   0},
                {0,  0,  "exterior", 0},
                {0,  0,  "interior", 0},
                {0,  0,  "copilot",  0},
                {0,  0,  "radio",    0},
                {0,  0,  "enviro",   0},
                {0,  0,  "ui",       0} }

do_often("B2VolumeControl_everySec()")
do_on_mouse_click("B2VolumeControl_mouseClick()")
do_every_draw("B2VolumeControl_everyDraw()")
do_on_mouse_wheel("B2VolumeControl_onMouseWheel()")


-- **************************************************************************************
--   To customize the location of the widget, simply modify the mainX and mainY coordinates here
--   as all other values are based on that location.
--       (mainX,mainY) is the coordinate of a pixel which is located at the middle, right most
--                     position of the 'active sound icon'
--
--   note: positions relative to the bottom or left edge of screen should be a 'fixed' value
--   note: positions relative to the top or right edge of screen should be a 'variable' value
--   example:   (125,SCREEN_HIGHT-40) would be positioned 125 pixels to the right of the left edge
--              and SCREEN_HIGHT-40 pixels from the top edge :: as the screen gets taller/shorter,
--              the value of SCREEN_HIGHT will change, keeping the widget where you wanted it
--
--      x ::  0 is left edge of screen, SCREEN_WIDTH is right edge of screen
--      y ::  0 is bottom edge of screen, SCREEN_HIGHT is top edge of screen
--          
--      default: 10 pixels from right edge of screen, 40 pixels from top edge of screen
-- **************************************************************************************
function B2VolumeControl_LocationInitialization()
    mainX = SCREEN_WIDTH - 10
    mainY = SCREEN_HIGHT - 40
end

function B2VolumeControl_everySec()
    -- handle screen width changes
    local prevmainX = mainX
    local prevmainY = mainY
    B2VolumeControl_LocationInitialization()
    if (not(prevmainX == mainX and prevmainY == mainY)) then
        bScreenSizeChanged = true
    end
end

function B2VolumeControl_mouseClick()
    -- check if position over our toggle icon
    if (MOUSE_X >= (mainX-40) and MOUSE_X <= mainX and 
        MOUSE_Y >= (mainY-15) and MOUSE_Y <= (mainY+15)) then
        local newTimeStamp = os.clock()
        if ((newTimeStamp - timeStamp) < 0.2) then -- handle only 1 click per 0.2 sec
            RESUME_MOUSE_CLICK = true
            return
        end

        if (bDrawControlBox == true) then
            bDrawControlBox = false
        else 
            bDrawControlBox = true  -- draw the box
        end
        timeStamp = newTimeStamp
        RESUME_MOUSE_CLICK = true
    end
end

function B2VolumeControl_everyDraw()
    -- OpenGL graphics state initialization
    XPLMSetGraphicsState(0,0,0,1,1,0,0)                     -- use only in do_every_draw()

    local withinRange = math.min(100, SCREEN_WIDTH/10, SCREEN_HIGHT/10)
    if (bDrawControlBox == true or
        (MOUSE_X >= (mainX-withinRange) and MOUSE_X <= (mainX+withinRange) and 
         MOUSE_Y >= (mainY-withinRange) and MOUSE_Y <= (mainY+withinRange))) then

        -- always draw clickable sound icon
        graphics.set_color(0,0,0,1) -- black
        graphics.draw_rectangle(mainX-40,mainY-8,mainX-20,mainY+8)
        graphics.draw_triangle(mainX-40,mainY,mainX-20,mainY+15,mainX-20,mainY-15)

        graphics.set_color(0.4,0.4,0.4,1) -- gray
        graphics.draw_rectangle(mainX-39,mainY-7,mainX-21,mainY+7)
        graphics.draw_triangle(mainX-37,mainY,mainX-21,mainY+13,mainX-21,mainY-13)

        if (bDrawControlBox == true) then
            -- draw 'active' sound icon
            graphics.set_color(140/255,128/255,99/255,1) -- fill in color
            graphics.draw_rectangle(mainX-38,mainY-6,mainX-22,mainY+6)
            graphics.draw_triangle(mainX-34,mainY,mainX-22,mainY+11,mainX-21,mainY-11)

            graphics.set_color(173/255,31/255,31/255,1) -- red
            graphics.draw_line(mainX-15,mainY+5,mainX-4,mainY+10)
            graphics.draw_line(mainX-15,mainY,mainX,mainY)
            graphics.draw_line(mainX-15,mainY-5,mainX-4,mainY-10)

            -- recompute workspace / knobs if needed
            if (bScreenSizeChanged == true) then
                topBoxY = mainY - (4*fixedGap)
                B2VolumeControl_computeKnobLocation()
            end

            -- draw background workspace box
            graphics.set_color(66/255, 66/255, 66/255, 1) -- dark gray
            local x2 = mainX
            local x1 = x2 - (2*knobRadius) - fixedTextSpace
            local y1 = topBoxY
            local y2 = y1 - (displayItems*(knobRadius*2)) - ((displayItems-1)*fixedGap)
            graphics.draw_rectangle(x1,y1,x2,y2)

            graphics.set_color(45/255,150/255,10/255,1) -- green
            for i = 1,displayItems do
                B2VolumeControl_drawKnob(i,0.0)
            end
        end -- box drawn
    end -- mouse near click spot
end

function B2VolumeControl_onMouseWheel()
    -- mouse wheel only important if knobs visible
    if (bDrawControlBox == false) then
        return
    end

    for i = 1,displayItems do
        if (MOUSE_X >= (knobs[i][1]-knobRadius-fixedTextSpace) and MOUSE_X <= (knobs[i][1]+knobRadius) and
            MOUSE_Y >= (knobs[i][2]-knobRadius) and MOUSE_Y <= (knobs[i][2]+knobRadius)) then
            B2VolumeControl_SetVolume(i,B2VolumeControl_GetVolume(i)+(MOUSE_WHEEL_CLICKS*0.02))
            RESUME_MOUSE_WHEEL = true
            return
        end
    end
end

function B2VolumeControl_drawKnob(i,volume) -- if volume==0.0 fetch it, otherwise use given
    x = knobs[i][1]
    y = knobs[i][2]
    if (volume == 0.0) then
        volume = B2VolumeControl_GetVolume(i)
    end
    textStr = knobs[i][3]
    textX = knobs[i][4]

    -- x,y are center of knob with knobRadius, volume is (0.0 - 1.0)
    -- arcs 210-150 (300 degrees) so ((volume * 300)+210)%360 = angle of pointer

    graphics.set_color(0,0,0,1) -- black border
    graphics.draw_arc(x,y,210,360,knobRadius,1)
    graphics.draw_arc(x,y,0,150,knobRadius,1)
    graphics.set_color(140/255,128/255,99/255,1) -- fill verified color
    graphics.draw_filled_arc(x,y,210,360,19)
    graphics.draw_filled_arc(x,y,0,150,19)

    graphics.set_color(173/255,31/255,31/255,1) -- pointer
    graphics.draw_angle_arrow(x,y,((volume*300)+210)%360,knobRadius-1,10,2)

    draw_string(textX,y,textStr,239/255,219/255,172/255)
end

function B2VolumeControl_computeKnobLocation()
    local y = topBoxY - knobRadius
    local textX = mainX - (2*knobRadius) - fixedTextSpace + 3  -- the '+3' just makes it look nicer
    for i = 1,displayItems do
        knobs[i][1] = mainX - knobRadius
        knobs[i][2] = y
        knobs[i][4] = textX
        y = y - fixedGap - (2*knobRadius)  -- change 'y' for next knob
    end
end

function B2VolumeControl_GetVolume(i)
    if (i == 1) then return b2vc_mastervolume end
    if (i == 2) then return b2vc_exteriorVolume end
    if (i == 3) then return b2vc_interiorVolume end
    if (i == 4) then return b2vc_copilotVolume end
    if (i == 5) then return b2vc_radioVolume end
    if (i == 6) then return b2vc_enviroVolume end
    if (i == 7) then return b2vc_uiVolume end
    return 0
end

function B2VolumeControl_SetVolume(i,value)
    if (value < 0.0) then value = 0.0 end
    if (value > 1.0) then value = 1.0 end
    if (i == 1) then b2vc_mastervolume = value end
    if (i == 2) then b2vc_exteriorVolume = value end
    if (i == 3) then b2vc_interiorVolume = value end
    if (i == 4) then b2vc_copilotVolume = value end
    if (i == 5) then b2vc_radioVolume = value end
    if (i == 6) then b2vc_enviroVolume = value end
    if (i == 7) then b2vc_uiVolume = value end
end
-- eof