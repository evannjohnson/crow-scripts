--- dual ar envelopes
-- requires txi
-- 2 triggered linear attack release envelopes (no sustain)
-- inputs 1 and 2 trigger envelopes on outputs 1 and 2
-- txi knobs 1/3 control length of the envs
-- knobs 2/4 control ratio of attack to release (ramp shape)

parameters = {
    len1 = 0,
    lenOffset1 = 0,
    lenRange1 = 4,
    ratio1 = 0,
    ratioOffset1 = 0,
    shape1 = 'linear',
    len2 = 0,
    lenOffset2 = 0,
    lenRange2 = 4,
    ratio2 = 0,
    ratioOffset2 = 0,
    shape2 = 'linear'
}

function init()
    input[1].mode('change', 1.0, 0.1, 'rising')
    input[2].mode('change', 1.0, 0.1, 'rising')

    output[4].volts = .35

    currentMode = 'primary'
    primaryUpdateLoop = clock.run(parameterUpdater,'primary')
end

input[1].change = function(state)
    local len = (parameters.len1 + parameters.lenOffset1) * parameters.lenRange1
    local attack = len * parameters.ratio1
    local release = len * (1 - parameters.ratio1)

    output[1].action = ar(attack, release, 8, parameters.shape1)
    output[1](s)
end

input[2].change = function(state)
    local len = (parameters.len2 + parameters.lenOffset2) * parameters.lenRange2
    local attack = len * parameters.ratio2
    local release = len * (1 - parameters.ratio1)

    output[2].action = ar(attack, release, 8, parameters.shape2)
    output[2](s)
end

-- mode change code
function setMode(mode)
    if mode == 'primary' and currentMode ~= 'primary' then
        clock.cancel(secondaryUpdateLoop)
        primaryUpdateLoop = clock.run(parameterUpdater,'primary')
        currentMode = 'primary'
    elseif mode == 'secondary' and currentMode ~= 'secondary' then
        clock.cancel(primaryUpdateLoop)
        secondaryUpdateLoop = clock.run(parameterUpdater,'secondary')
        currentMode = 'secondary'
    end
end

clock.run(function()
    local prev = math.floor(input[2].volts * 100)

    while true do
        clock.sleep(0.1)
        local current = math.floor(input[2].volts * 100)
        if (prev >= 34 and prev <= 36 and
                current >= 34 and current <= 36) then
            setMode('secondary')
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
        clock.sleep(0.01) -- set the polling speed
        ii.txi.get('param', n)
        ii.txi.get('in', n)
        n = (n % 4) + 1
    end
end)

local handlers = {
    primary = {
        param = {
            [1] = function(val)
                parameters.len1 = val / 10
            end,
            [2] = function(val)
                parameters.ratio1 = val / 10
            end,
            [3] = function(val)
                parameters.len2 = val / 10
            end,
            [4] = function(val)
                parameters.ratio2 = val / 10
            end
        },
        cv = {
            [1] = function(val)
                parameters.lenOffset1 = val / 5
            end,
            [2] = function(val)
                parameters.ratioOffset1 = val / 5
            end,
            [3] = function(val)
                parameters.lenOffset2 = val / 5
            end,
            [4] = function(val)
                parameters.ratioOffset2 = val / 5
            end
        }
    },
    secondary = {
        param = {
            [1] = function(val)
                parameters.lenRange1 = 1 + val
                parameters.lenRange2 = 1 + val
            end,
            [2] = function(val)
                if val < 2 then
                    parameters.shape1 = 'log'
                    parameters.shape2 = 'log'
                elseif val > 8 then
                    parameters.shape1 = 'exp'
                    parameters.shape2 = 'exp'
                else
                    parameters.shape1 = 'linear'
                    parameters.shape2 = 'linear'
                end
            end,
            [3] = function(val)
                parameters.lenRange2 = 1 + val
            end,
            [4] = function(val)
                if val < 2 then
                    parameters.shape2 = 'log'
                elseif val > 8 then
                    parameters.shape2 = 'exp'
                else
                    parameters.shape2 = 'linear'
                end
            end
        },
        cv = {
            [1] = function(val)
                parameters.lenOffset1 = val / 5
            end,
            [2] = function(val)
                parameters.ratioOffset1 = val / 5
            end,
            [3] = function(val)
                parameters.lenOffset2 = val / 5
            end,
            [4] = function(val)
                parameters.ratioOffset2 = val / 5
            end
        }
    }}

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

        if not prevParamVal then -- initialize
            prevs.param[n] = currentParamVal
        elseif math.abs(currentParamVal - prevParamVal) > 0.005 then
            print('detected param '..n..' change')
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
