--- dual ar envelopes
-- description

function init()
    input[1].mode('change',1.0,0.1,'rising')
    input[2].mode('change',1.0,0.1,'rising')
end

input[1].change = function(state)
    ii.txi.get('param',1)
    ii.txi.get('param',2)
--[[
    print('length1: ' ..length)
    print('attack1: ' ..attack)
    print('release1: ' ..release)
--]]
    output[1].action = ar(attack1, release1, 8, 'linear')
    output[1]( s )
end

input[2].change = function(state)
    ii.txi.get('param',3)
    ii.txi.get('param',4)
--[[
    print('length2: ' ..length)
    print('attack2: ' ..attack)
    print('release2: ' ..release)
--]]
    output[2].action = ar(attack2, release2, 8, 'linear')
    output[2]( s )
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
