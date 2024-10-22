--- dual ar envelopes
-- requires txi
--
-- 2 triggered linear attack release envelopes
-- inputs 1 and 2 trigger envelopes on outputs 1 and 2
-- outputs 3/4 are end of fall triggers for outputs 1/2 respectively
-- txi knobs 1/3 control length of the envs (default max length is 4 sec)
-- knobs 2/4 control ratio of attack to release (default shape is linear)
-- txi ins 1/3 add to knobs 1/3, -5v - +5v range, can add beyond knob max to reach double the max envelope time
-- ins 2/4 add to knobs 2/4
--
-- access secondary parameters by patching a steady 1 volt to input 2
-- seconday mode exits when input 2 stops reading a steady 1v
-- knobs control the following in secondary mode (txi in still controls the primary params):
-- knob 1: set the max length of both envelopes (min=1 sec, max=11 sec)
-- knob 2: set the shape of both envelopes (min = logarithmic, midpoint = linear, max = exponential
-- knob 3: set the max length of envelope 2
-- knob 4: set the shape of envelope 2
--
-- when switching between the modes, the knobs will not change the parameter values until the knob is moved, at which point the parameter will jump to match the position of the knob

-- set retrigger behavior with this variable retriggerBehavior
-- possible values:
-- 'no': ignore triggers while an envelope is active
-- 'fromZero': when receiving a trigger during a cycle, immediately set the output to 0 and start the new cycle
-- 'fromCurrent': when receiving a trigger during a cycle, immediately start the new cycle, with the starting point at the current value. This can result in unexpected slopes, as the slope is determined by the difference between the start and end points of the envelope.
-- ex. if the env len is 1 sec, and the ratio is 0.5, the attack will be .5 seconds. This means the attack's slope will be different if it starts from 4 volts (like when retriggered befor it completes a cycle) than if it starts at 0 volts, since it always climbs to 8 volts

retriggerBehavior = "fromZero"
defaultRange = 4 -- length in seconds when knob is maxed (can go further by adding CV)
defaultShape = 'linear'

parameters = {}
for i = 1, 2 do
    parameters[i] = {
        -- primary params will be set to match knob positions on launch
        len = 0,              -- knobs 1/3
        lenOffset = 0,        -- cv 1/3
        ratio = 0,            -- knobs 2/4
        ratioOffset = 0,      -- cv 2/4
        lenMax = defaultMax,  -- default max envelope length
        shape = defaultShape, -- secondary mode knobs 2/4 log<lin<exp
        active = false        -- track whether the envelope is active
    }
end

-- tune these response curves to taste
-- pos is the knob position, val is what proportion of the param's max value that knob position will be equal to
-- this allows ex. making the first half of the knob much more sensitive than the last half, for fine-tuning a short envelope
lenResponseCurve = {
    { pos = .5, val = .2 },
    { pos = 1,  val = 1 }
}

ratioResponseCurve = {
    { pos = .25, val = .1 },
    { pos = .75, val = .9 },
    { pos = 1,   val = 1 }
}

function init()
    if retriggerBehavior == 'fromZero' then
        output[1].action = {
            to(0, 0),
            to(8, dyn { attack = 1 }, 'linear'),
            to(0, dyn { release = 1 }, 'linear')
        }
        output[2].action = {
            to(0, 0),
            to(8, dyn { attack = 1 }, 'linear'),
            to(0, dyn { release = 1 }, 'linear')
        }
    else
        output[1].action = {
            to(8, dyn { attack = 1 }, 'linear'),
            to(0, dyn { release = 1 }, 'linear')
        }
        output[2].action = {
            to(8, dyn { attack = 1 }, 'linear'),
            to(0, dyn { release = 1 }, 'linear')
        }
    end

    output[1].done = function()
        parameters[1].active = false
        output[3]()
    end
    output[2].done = function()
        parameters[2].active = false
        output[4]()
    end

    -- initialize values
    clock.run(function()
        for i = 1, 4 do
            ii.txi.get('param', i)
            ii.txi.get('in', i)
            clock.sleep(.1)
            handlers.primary.param[i](txiVals.param[i])
            handlers.primary.cv[i](txiVals.cv[i])
        end
    end)

    currentMode = 'primary'
    primaryUpdateLoop = clock.run(parameterUpdater, 'primary')

    input[1].mode('change', 1.0, 0.1, 'rising')
    input[2].mode('change', 1.0, 0.1, 'rising')

    if retriggerBehavior == 'no' then
        input[1].change = function(state)
            if not parameters[1].active then
                parameters[1].active = true
                output[1]()
            end
        end

        input[2].change = function(state)
            if not parameters[2].active then
                parameters[2].active = true
                output[2]()
            end
        end
    else
        input[1].change = function(state)
            parameters[1].active = true
            output[1]()
        end

        input[2].change = function(state)
            parameters[2].active = true
            output[2]()
        end
    end

    output[3].action = pulse(0.001)
    output[4].action = pulse(0.001)
end

function updateAr(num)
    local len = math.max(.0001,
        variableResponse(parameters[num].len + parameters[num].lenOffset, lenResponseCurve) * parameters[num].lenRange)
    local ratio = variableResponse(parameters[num].ratio + parameters[num].ratioOffset, ratioResponseCurve)

    attack = len * ratio
    release = len * (1 - ratio)

    -- print('attack ' .. num .. ' ' .. attack)
    -- print('release ' .. num .. ' ' .. release)
    output[num].dyn.attack = len * ratio
    output[num].dyn.release = len * (1 - ratio)
end

--[[
pos: should be 0-1
points: an array of tables. the tables should have 2 indexes, 'pos' and 'val'.
    - pos: the actual knob position to map to val
    - val: the position that would be output if the knob were set to the actual position specified by pos
    knobPos will be smoothly mapped to the the output between the points
    the array of tables must be sorted by the table's pos and val, and sorting by either of the tables' indices should result in the same sort
    the last table in the array should be {pos=1,val=1}
    ex. one point with pos .5 and value .2 would cause the first 50% of the knob to map to 0-.2, and the second half to map to .2-1
--]]
function variableResponse(pos, points)
    pos = math.max(0, math.min(pos, 1))
    points[0] = { pos = 0, val = 0 }

    for i, point in ipairs(points) do
        if point.pos >= pos then -- hit
            local posBottom = points[i - 1].pos
            local valBottom = points[i - 1].val
            local posRange = point.pos - posBottom
            local valRange = point.val - valBottom
            local segmentPercentage = (pos - posBottom) / posRange
            local segmentVal = segmentPercentage * valRange

            return valBottom + segmentVal
        end
    end
end

function updateShape(num)
    if retriggerBehavior == 'fromZero' then
        output[num].action = {
            to(0, 0),
            to(8, dyn { attack = 1 }, parameters[num].shape),
            to(0, dyn { release = 1 }, parameters[num].shape)
        }
    else
        output[num].action = {
            to(8, dyn { attack = 1 }, parameters[num].shape),
            to(0, dyn { release = 1 }, parameters[num].shape)
        }
    end
    updateAr(num)
end

function envelopeTrigger(num)
    output[num](s)
end

-- mode change code
function setMode(mode)
    if mode == 'primary' and currentMode ~= 'primary' then
        clock.cancel(secondaryUpdateLoop)
        primaryUpdateLoop = clock.run(parameterUpdater, 'primary')
        currentMode = 'primary'
    elseif mode == 'secondary' and currentMode ~= 'secondary' then
        clock.cancel(primaryUpdateLoop)
        secondaryUpdateLoop = clock.run(parameterUpdater, 'secondary')
        currentMode = 'secondary'
    end
end

clock.run(function()
    local prev = math.floor(input[2].volts * 100)

    while true do
        clock.sleep(0.1)
        local current = input[2].volts
        if (prev >= .98 and prev <= 1.02 and
                current >= .98 and current <= 1.02) then
            setMode('secondary')
        else
            setMode('primary')
        end
        prev = current
    end
end)

-- txi polling
txiVals = {
    param = {},
    cv = {}
}

ii.txi.event = function(e, val)
    if e.name == 'in' then -- don't use 'in' because its a lua keyword
        e.name = 'cv'
    end
    txiVals[e.name][e.arg] = val
end

clock.run(function()
    local n = 1
    while true do
        clock.sleep(0.01)
        ii.txi.get('param', n)
        ii.txi.get('in', n)
        n = (n % 4) + 1
    end
end)

handlers = {
    primary = {
        param = {
            [1] = function(val)
                parameters[1].len = val / 10
                updateAr(1)
            end,
            [2] = function(val)
                parameters[1].ratio = val / 10
                updateAr(1)
            end,
            [3] = function(val)
                parameters[2].len = val / 10
                updateAr(2)
            end,
            [4] = function(val)
                parameters[2].ratio = val / 10
                updateAr(2)
            end
        },
        cv = {
            [1] = function(val)
                parameters[1].lenOffset = val / 5
                updateAr(1)
            end,
            [2] = function(val)
                parameters[1].ratioOffset = val / 5
                updateAr(1)
            end,
            [3] = function(val)
                parameters[2].lenOffset = val / 5
                updateAr(2)
            end,
            [4] = function(val)
                parameters[2].ratioOffset = val / 5
                updateAr(2)
            end
        }
    },
    secondary = {
        param = {
            [1] = function(val)
                parameters[1].lenRange = 1 + val
                parameters[2].lenRange = 1 + val
                updateAr(1)
                updateAr(2)
            end,
            [2] = function(val)
                if val < 2 then
                    parameters[1].shape = 'log'
                    parameters[2].shape = 'log'
                    updateShape(1)
                    updateShape(2)
                elseif val > 8 then
                    parameters[1].shape = 'exp'
                    parameters[2].shape = 'exp'
                    updateShape(1)
                    updateShape(2)
                else
                    parameters[1].shape = 'linear'
                    parameters[2].shape = 'linear'
                    updateShape(1)
                    updateShape(2)
                end
            end,
            [3] = function(val)
                parameters[2].lenRange = 1 + val
                updateAr(2)
            end,
            [4] = function(val)
                if val < 2 then
                    parameters[2].shape = 'log'
                    updateShape(2)
                elseif val > 8 then
                    parameters[2].shape = 'exp'
                    updateShape(2)
                else
                    parameters[2].shape = 'linear'
                    updateShape(2)
                end
            end
        },
        cv = {
            [1] = function(val)
                parameters[1].lenOffset = val / 5
            end,
            [2] = function(val)
                parameters[1].ratioOffset = val / 5
            end,
            [3] = function(val)
                parameters[2].lenOffset = val / 5
            end,
            [4] = function(val)
                parameters[2].ratioOffset = val / 5
            end
        }
    }
}

function parameterUpdater(mode)
    local prevs = {
        param = {},
        cv = {}
    }
    local n = 1
    while true do
        clock.sleep(.01)

        local currentParamVal = txiVals.param[n]
        local currentCvVal = txiVals.cv[n]
        local prevParamVal = prevs.param[n]
        local prevCvVal = prevs.cv[n]

        if not prevParamVal then -- initialize on mode change
            prevs.param[n] = currentParamVal
        elseif math.abs(currentParamVal - prevParamVal) > 0.005 then
            -- print('detected param ' .. n .. ' change')
            handlers[mode].param[n](currentParamVal)
            prevs.param[n] = currentParamVal
        end

        if not prevCvVal then
            prevs.cv[n] = currentCvVal
        elseif math.abs(currentCvVal - prevCvVal) > 0.005 then
            handlers[mode].cv[n](currentCvVal)
            prevs.cv[n] = currentCvVal
        end
        n = (n % 4) + 1
    end
end
