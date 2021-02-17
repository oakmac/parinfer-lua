local inspect = require('libs/inspect')

local a = { a = 1, b = 2, c = 3}

print(inspect(a))

a.a = nil

print(inspect(a))