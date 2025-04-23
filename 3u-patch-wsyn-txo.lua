w = ii.wsyn -- less typing in repl, like w.lpg_time(0)

-- w.ar_mode(1)
w.curve(5)
w.ramp(0)
w.fm_index(0)
-- w.fm_env(-.35) -- this offsets the minimum CV that comes out of planar
-- w.fm_env(-.5) -- this offsets the minimum CV that comes out of planar when attenuated by a mystic 0tennuator at noon
w.fm_env(0)
w.fm_ratio(4)
w.lpg_symmetry(-3.5)
w.lpg_time(-2.73)
-- w.patch(1, 3) -- this to fm env, use planar unipolar out
-- w.patch(2, 5) -- that to lpg time
-- mappings = {
--     w.fm_env,
--     w.lpg_time
-- }

-- tune these response curves to taste
-- vin is the value at the input, vout is the param value that voltage will be equal to
-- this allows ex. making the first half of the knob much more sensitive than the last half, for fine-tuning a short envelope
ins = {
    {
        callback = function(v)
            -- ii.wsyn.fm_env(varisponse(v, {
            --     { vin = 0,   vout = 0 },
            --     { vin = 0.3, vout = 0 },
            --     { vin = 3.5, vout = 0.1 },
            --     { vin = 6,   vout = 1 },
            --     { vin = 10,  vout = 3 },
            -- }))
            ii.wsyn.fm_index(varisponse(v, {
                { vin = 0,   vout = 0 },
                { vin = 0.3, vout = 0 }, -- wiggle room for left side of joystick
                { vin = 2.5, vout = 0.3 },
                { vin = 6,   vout = 1 },
                { vin = 10,  vout = 3 },
            }))
        end,
    },
    {
        callback = function(v)
            ii.wsyn.lpg_time(varisponse(v, {
                { vin = 0,   vout = 4 },
                { vin = 0.1, vout = 3 },
                { vin = 0.5, vout = 1 },
                {vin = 3, vout = -1},
                {vin = 8, vout = -3},
                { vin = 10,  vout = -4 }
            }))
        end,
    }
}

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
function varisponse(vin, points)
    vin = math.max(points[1].vin, math.min(vin, points[#points].vin))

    for i = 2, #points do
        if points[i].vin >= vin then -- hit
            local vinBottom = points[i - 1].vin
            local voutBottom = points[i - 1].vout
            local vinRange = points[i].vin - vinBottom
            local voutRange = points[i].vout - voutBottom
            local segmentPercentage = (vin - vinBottom) / vinRange
            local segmentVal = segmentPercentage * voutRange

            return voutBottom + segmentVal
        end
    end
end

function startStream()
    for i = 1, 2 do
        input[i] { mode = 'stream'
        , time = 0.01
        , stream = function(v) ins[i].callback(v) end }
    end
end

function stopStream()
    for i = 1, 2 do
        input[i] { mode = 'none' }
    end
end

startStream()
