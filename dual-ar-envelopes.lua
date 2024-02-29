--- dual ar envelopes
-- description

function init()
    input[1].mode('change',1.0,0.1,'rising')
end

input[1].change = function(state)
    ii.txi.get('param',2)
    ii.txi.get('param',1)
    output[1].action = ar(attack, release, 7, 'log')
    output[1]( s )
end

ii.txi.event = function(e, val)
    if e.arg == 2 then
        length = val * .2 + .01
    elseif e.arg == 1 then
        attack = val / 10 * length
        release = length - attack
    end
end
