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
end

input[1].change = function(state)
    --[[
    print('length1: ' ..length)
    print('attack1: ' ..attack)
    print('release1: ' ..release)
--]]
    output[1].action = ar(attack1, release1, 8, 'linear')
    output[1](s)
end

input[2].change = function(state)
    ii.txi.get('param', 3)
    ii.txi.get('param', 4)
    length2 = txiVals.param
    --[[
    print('length2: ' ..length)
    print('attack2: ' ..attack)
    print('release2: ' ..release)
--]]
    output[2].action = ar(attack2, release2, 8, 'linear')
    output[2](s)
end

ii.txi.event = function(e, val)
    if e.arg == 1 then
        length1 = val * .4 + .01
    elseif e.arg == 2 then
        attack1 = val / 10 * length1
        release1 = length1 - attack1
    elseif e.arg == 3 then
        length2 = val * .4 + .01
    elseif e.arg == 4 then
        attack2 = val / 10 * length2
        release2 = length2 - attack2
    end
end

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

-- translate txi input values based on the mode
txiProcessors = {
    basic = function()
        local prevs = {
            param = {},
            cv = {}
        }
        local handlers = {
            param = {
                'len1','ratio1','len2','ratio2'
                -- [1] = function(val)
                --     parameters.len1 = val / 10
                -- end,
                -- [2] = function(val)
                --     parameters.ratio1 = val / 10
                -- end
                -- [3] = function(val)
                --     parameters.len2 = val / 10
                -- end,
                -- [4] = function(val)
                --     parameters.ratio2 = val / 10
                -- end
            },
            cv = {
                'lenOffset1','ratioOffset1','lenOffset2','ratioOffset2'
                -- [1] = function(val)
                --     parameters.lenOffset1 = val / 10
                -- end,
                -- [2] = function(val)
                --     parameters.ratioOffset1 = val / 10
                -- end
                -- [3] = function(val)
                --     parameters.lenOffset2 = val / 10
                -- end,
                -- [4] = function(val)
                --     parameters.ratioOffset2 = val / 10
                -- end
            }
        }
        local n = 1
        while true do
            clock.sleep(0.01)

            local currentParamVal = txiVals.param[n]
            local currentCvVal = txiVals.cv[n]
            local prevParamVal = prevs.param[n]
            local prevCvVal = prevs.cv[n]

            if not prevParamVal then -- initialize
                prevs.param[n] = currentParamVal
            elseif currentParamVal ~= prevParamVal then
                prevs.param[n] = currentCvVal
                parameters[handlers.param[n]] = currentParamVal / 10 -- param is 0-10, we want percentage
            end

            if not prevCvVal then
                prevs.cv[n] = currentCvVal
            elseif currentCvVal ~= prevCvVal then
                prevs.cv[n] = currentCvVal
                parameters[handlers.cv[n]] = currentCvVal / 5 -- cv range -5v - 5v
            end
            n = (n % 4) + 1
        end
    end
}

basicUpdateLoop = clock.run(txiProcessors.basic)

