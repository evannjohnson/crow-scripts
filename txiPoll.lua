txiVals = {
    param = {},
    cv = {}
}

ii.txi.event = function(e,val)
    if e.name == 'in' then
        e.name = 'cv'
    end
    txiVals[e.name][e.arg] = val
end

clock.run( function()
  local n=1
  while true do
    clock.sleep(0.01) -- set the polling speed
    ii.txi.get('param', n)
    ii.txi.get('in', n)
    -- print("param "..n.."= "..txiVals.param[n])
    -- print("cv "..n.."= "..txiVals.cv[n])
    n = (n % 4) + 1
  end
end)
