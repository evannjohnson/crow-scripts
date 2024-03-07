--- dual ar envelopes
-- requires txi
-- 2 triggered linear attack release envelopes
-- inputs 1 and 2 trigger envelopes on outputs 1 and 2
-- txi knobs 1/3 control length of the envs (default max length is 4 sec)
-- knobs 2/4 control ratio of attack to release (default shape is linear)
-- txi ins 1/3 add to knobs 1/3, -5v - +5v range, can add beyond knob max to reach double the max envelope time
-- ins 2/4 add to knobs 2/4
--
-- access secondary parameters by patching a steady 1 volt to input 2
-- seconday mode exits when input 2 stops reading a steady 1v
-- knobs control the following in secondary mode (txi in behavior does not change):
-- knob 1: set the max length of both envelopes (min=1 sec, max=11 sec)
-- knob 2: set the shape of both envelopes (min = logarithmic, midpoint = linear, max = exponential
-- knob 3: set the max length of envelope 2
-- knob 4: set the shape of envelope 2
--
-- when switching between the modes, the knobs will not change the parameter values until the knob is moved, at which point the relevant parameter will jump to match the position of the knob

parameters = {}
for i = 1, 2 do
    parameters[i] = {
        len = 0,          -- knobs 1/3
        lenOffset = 0,    -- cv 1/3
        lenRange = 4,     -- secondary mode knobs 1/3
        ratio = 0,        -- knobs 2/4
        ratioOffset = 0,  -- cv 2/4
        shape = 'linear', -- secondary mode knobs 2/4 logarithmic<linear<exponential
    }
end

function init()
    -- for i in 1, 2 do
    --     output[i].action = ar(
    --         dyn{attack = 1},
    --         dyn{release = 1},
    --         8, -- amplitude in volts
    --         dyn{shape = 'linear'})
    -- end

    -- for i in 1,2 do
    --     output[i].action = {
    --         to(8,dyn{attack = 1},'linear'),
    --         to(0,dyn{release = 1},'linear')
    --     }
    -- end

    output[1].action = {
            to(8,dyn{attack = 1},'linear'),
            to(0,dyn{release = 1},'linear')
        }
    output[2].action = {
                to(8,dyn{attack = 1},'linear'),
                to(0,dyn{release = 1},'linear')
            }
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

    input[1].change = function(state)
        output[1](s)
    end
    input[2].change = function(state)
        output[2](s)
    end

    output[3].action = pulse(0.001)
    output[4].action = pulse(0.001)
    eosClock = {}
end

function updateAr(num)
    local len = (parameters[num].len + parameters[num].lenOffset) * parameters[num].lenRange
    local ratio = parameters[num].ratio + parameters[num].ratioOffset
    ratio = math.max(0, math.min(ratio, 1))

    attack = len * ratio
    release = len * (1 - ratio)

    print('attack '..num..' '..attack)
    print('release '..num..' '..release)
    output[num].dyn.attack = len * ratio
    output[num].dyn.release = len * (1 - ratio)
end

function envelopeTrigger(num)
    -- local len = (parameters[num].len + parameters[num].lenOffset) * parameters[num].lenRange

    -- ratio = parameters[num].ratio + parameters[num].ratioOffset
    -- ratio = math.max(0, math.min(ratio, 1))

    -- local attack = len * parameters[num].ratio
    -- local release = len * (1 - parameters[num].ratio)

    -- print('trigger env ' .. num)
    -- print('attack ' .. attack)
    -- print('release ' .. release)

    -- output[num].action = ar(attack, release, 8, parameters[num].shape)
    output[num](s)

    -- if eosClock[num] then
    --     clock.cancel(eosClock[num])
    -- end

    -- eosClock[num] = clock.run(function(len, num)
    --     clock.sleep(len)
    --     output[num + 2](s)
    -- end, len, num)
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
                print('hey')
            end,
            [2] = function(val)
                parameters[1].ratio = val / 10
                updateAr(1)
            end,
            [3] = function(val)
                parameters[2].len = val / 10
            end,
            [4] = function(val)
                parameters[2].ratio = val / 10
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
            end,
            [4] = function(val)
                parameters[2].ratioOffset = val / 5
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
                    output[1].dyn.shape = 'log'
                    output[2].dyn.shape = 'log'
                elseif val > 8 then
                    parameters[1].shape = 'exp'
                    parameters[2].shape = 'exp'
                    output[1].dyn.shape = 'exp'
                    output[2].dyn.shape = 'exp'
                else
                    parameters[1].shape = 'linear'
                    parameters[2].shape = 'linear'
                    output[1].dyn.shape = 'linear'
                    output[2].dyn.shape = 'linear'
                end
            end,
            [3] = function(val)
                parameters[2].lenRange = 1 + val
                updateAr(2)
            end,
            [4] = function(val)
                if val < 2 then
                    parameters[2].shape = 'log'
                    output[2].dyn.shape = 'log'
                elseif val > 8 then
                    parameters[2].shape = 'exp'
                    output[2].dyn.shape = 'exp'
                else
                    parameters[2].shape = 'linear'
                    output[2].dyn.shape = 'linear'
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
            print('detected param ' .. n .. ' change')
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
