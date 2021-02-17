local inspect = require('libs/inspect')

--local a = { a = 1, b = 2, c = 3}
local a = {"a", "b", "c"}

table.insert(a, 'foo')

print(inspect(a))
print(a[-1])





--print(inspect(a))
--a.a = nil
--print(inspect(a))
--
--function internalCall (result) 
--
--  local x = result .. 'zzz'
--  return "bad bad bad"
--
--  --result.b = 'bbbbbbbb'
--  --return result
--  
--end
--
--local status, rrr = pcall(function() return internalCall(a) end)
--
--if status then
--    print('first case')
--    print(inspect(rrr))
--else
--    print('other case')
--    print(inspect(rrr))
--end