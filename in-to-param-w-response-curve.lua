-- tune these response curves to taste
-- vin is the value at the input, vout is the param value that voltage will be equal to
-- this allows ex. making the first half of the knob much more sensitive than the last half, for fine-tuning a short envelope
ins = {
    {
        callback = ii.wsyn.fm_env,
        responseCurve = {
            { vin = 0,  vout = 0 },
            -- { vin = .5, vout = .2 },
            { vin = 10,  vout = 10 }
        },
    },
    {
        callback = ii.wsyn.lpg_time,
        responseCurve = {
            { vin = .5, vout = .2 },
            { vin = 1,  vout = 1 }
        },
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

    for i, point in ipairs(points) do
        if point.vin >= vin then -- hit
            local vinBottom = points[i - 1].vin
            local voutBottom = points[i - 1].vout
            local vinRange = point.vin - vinBottom
            local voutRange = point.vout - voutBottom
            local segmentPercentage = (vin - vinBottom) / vinRange
            local segmentVal = segmentPercentage * voutRange

            return voutBottom + segmentVal
        end
    end
end

for i = 1, 2 do
    input[n] { mode = 'stream'
    , time = 0.01
    , stream = function(v) ins[i].callback(varisponse(v, ins[i].responseCurve)) end }
end
