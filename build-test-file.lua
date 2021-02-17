-- TODO: document what is going on here

local lu = require('libs/luaunit')
local json = require('libs/json')
local inspect = require('libs/inspect')

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Helpers

-- https://stackoverflow.com/a/31857671/2137320
local function readFile(path)
    local file = io.open(path, "rb") -- r read mode and b binary mode
    if not file then return nil end
    local content = file:read "*a" -- *a or *all reads the whole file
    file:close()
    return content
end

local function writeFile(filename, txt)
  local f = io.open(filename, "w+")
  io.output(f)
  io.write(txt)
  io.close(f)
end

-- load test cases JSON
local indentModeCases = json.decode(readFile('./test-cases/indent-mode.json'))
local parenModeCases = json.decode(readFile('./test-cases/paren-mode.json'))
local smartModeCases = json.decode(readFile('./test-cases/smart-mode.json'))

local testFileTxt =
  '-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n' ..
  '-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n' ..
  '-- NOTE: this file generated automatically by build-test-file.lua\n' ..
  '-- Please do not edit manually :-)\n' ..
  '-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n' ..
  '-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n\n'

for _key, testCase in pairs(indentModeCases) do
  
  testFileTxt = testFileTxt .. 'function testIndentMode' .. testCase.id .. '\n'
  testFileTxt = testFileTxt .. 'end\n'
  testFileTxt = testFileTxt .. '\n'


--  testFileTxt = testFileTxt .. testCase.text .. '\n'
--  testFileTxt = testFileTxt .. '-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n'

  -- checkTestCase(testCase)

  -- lu.assertIsTable(testCase)
  --myTable[key] = "foobar"
  
  --print(key)
  --print(value)
  --print('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~')
  
  -- lu.assertEquals(2, 4)
  
end

writeFile('./zzzzzzzzzzzzzzzzzzzzzzz.lua', testFileTxt)



  --for _key, testCase in pairs(indentModeCases) do
  --
  --  print(inspect(testCase))
  --  print('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~')
  --  
  --  lu.assertTrue(true)
  --  
  --end




--TestAdd = {}
--    function TestAdd:testAddPositive()
--        lu.assertEquals(add(1,1),2)
--    end
--
--    function TestAdd:testAddZero()
--        lu.assertEquals(add(1,0),0)
--        lu.assertEquals(add(0,5),0)
--        lu.assertEquals(add(0,0),0)
--    end
--
--    function TestAdd:testAddError()
--        lu.assertErrorMsgContains('Can only add positive or null numbers, received 2 and -3', add, 2, -3)
--    end
--
--    function TestAdd:testAdder()
--        f = adder(3)
--        lu.assertIsFunction( f )
--        lu.assertEquals( f(2), 5 )
--    end
--
--TestDiv = {}
--    function TestDiv:testDivPositive()
--        lu.assertEquals(div(4,2),2)
--    end
--
--    function TestDiv:testDivZero()
--        lu.assertEquals(div(4,0),0)
--        lu.assertEquals(div(0,5),0)
--        lu.assertEquals(div(0,0),0)
--    end
--
--    function TestDiv:testDivError()
--        lu.assertErrorMsgContains('Can only divide positive or null numbers, received 2 and -3', div, 2, -3)
--    end


--TestWithFailures = {}
--    function TestWithFailures:testFail1()
--        lu.assertEquals( "toto", "titi")
--    end
--
--    function TestWithFailures:testFail2()
--        local a=1
--        local b='toto'
--        local c = a + b -- oops, can not add string and numbers
--        return c
--    end
