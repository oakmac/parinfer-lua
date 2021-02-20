local lu = require("libs/luaunit")
local json = require("libs/json")
local inspect = require("libs/inspect")
local parinfer = require("parinfer")

local function tableSize(t)
    local count = 0
    for _key, _val in pairs(t) do
        count = count + 1
    end
    return count
end

-- https://stackoverflow.com/a/31857671/2137320
local function readFile(path)
    local file = io.open(path, "rb") -- r read mode and b binary mode
    if not file then
        return nil
    end
    local content = file:read "*a" -- *a or *all reads the whole file
    file:close()
    return content
end

-- TODO: add additional smart mode cases here

-- load test cases JSON
local indentModeCases = json.decode(readFile("./test-cases/indent-mode.json"))
local parenModeCases = json.decode(readFile("./test-cases/paren-mode.json"))
local smartModeCases = json.decode(readFile("./test-cases/smart-mode.json"))

-- NOTE: this is named "assertStructure" in parinfer test.js
function assertStructure2(actual, expected)
    -- print("\n\n")
    -- print("Result from test suite: >>>>>>>>>>>>>>>>>>>>>>>>>>>")
    -- print(inspect(expected))
    -- print("\n")
    -- print(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>")
    -- print(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>")
    -- print("Result from parinfer.lua >>>>>>>>>>>>>>>>>>>>>>>>>>>")
    -- print(inspect(actual))
    -- print("\n\n")

    lu.assertIsTable(actual)
    lu.assertIsTable(expected)
    lu.assertIsString(actual.text)
    lu.assertIsString(expected.text)

    lu.assertEquals(actual.text, expected.text)
    lu.assertEquals(actual.success, expected.success)
    lu.assertEquals(actual.cursorX, expected.cursorX)
    lu.assertEquals(actual.cursorLine, expected.cursorLine)

    lu.assertEquals(actual.error == nil, expected.error == nil)
    if (actual.error) then
        -- NOTE: we currently do not test 'message' and 'extra'
        lu.assertEquals(actual.error.name, expected.error.name)
        lu.assertEquals(actual.error.lineNo, expected.error.lineNo + 1) -- Lua ONE INDEX
        lu.assertEquals(actual.error.x, expected.error.x + 1) -- Lua ONE INDEX
    end

    if (expected.tabStops) then
        lu.assertEquals(actual.tabStops == nil, false)

        local expectedTSLen = tableSize(expected.tabStops)
        local actualTSLen = tableSize(actual.tabStops)
        lu.assertEquals(expectedTSLen, actualTSLen)

        local i = 1
        while i <= expectedTSLen do
            local actualTS = actual.tabStops[i]
            local expectedTS = expected.tabStops[i]

            lu.assertEquals(actualTS.lineNo, expectedTS.lineNo)
            lu.assertEquals(actualTS.x, expectedTS.x)
            lu.assertEquals(actualTS.ch, expectedTS.ch)
            lu.assertEquals(actualTS.argX, expectedTS.argX)

            i = i + 1
        end
    end

    if (expected.parenTrails) then
        lu.assertEquals(actual.parenTrails, expected.parenTrails)
    end
end

-- NOTE: this is named "testStructure" in parinfer test.js
function assertStructure1(testCase, mode)
    local expected = testCase.result
    local inputText = testCase.text
    local options = testCase.options

    -- We are not yet verifying that the returned paren tree is correct.
    -- We are simply setting it to ensure it is constructed in a way that doesn't
    -- throw an exception.
    options.returnParens = true

    -- run Parinfer
    local result
    if mode == "indent" then
        result = parinfer.indentMode(inputText, options)
    elseif mode == "paren" then
        result = parinfer.parenMode(inputText, options)
    elseif mode == "smart" then
        result = parinfer.smartMode(inputText, options)
    end

    assertStructure2(result, expected)

    -- FIXME: not checking paren trails after this main check
    -- (causing problems, and not a priority at time of writing)
    if (result.parenTrails) then
        actual.parenTrails = nil
    end

    -- bypass the next checks if these conditions exist
    if (expected.error or expected.tabStops or expected.parenTrails or testCase.options.changes) then
        return
    end

    -- TODO: idempotence check
    -- TODO: cross-mode check
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- LuaUnit Tests

function testModuleBasics()
    lu.assertIsTable(indentModeCases, "Unable to load Indent Mode Test cases. Maybe your JSON is wrong?")
    lu.assertIsTable(parenModeCases, "Unable to load Paren Mode Test cases. Maybe your JSON is wrong?")
    lu.assertIsTable(smartModeCases, "Unable to load Smart Mode Test cases. Maybe your JSON is wrong?")

    lu.assertIsTable(parinfer, "Unable to load the parinfer module. Maybe invalid syntax?")
    lu.assertIsFunction(parinfer.indentMode)
    lu.assertIsFunction(parinfer.parenMode)
    lu.assertIsFunction(parinfer.smartMode)
    lu.assertIsString(parinfer.version)
end

function testIndentMode()
    for _key, testCase in pairs(indentModeCases) do
        print("Testing Indent Mode #" .. testCase.id)
        assertStructure1(testCase, "indent")
    end
end

function testParenMode()
    -- TODO: write me
end

function testSmartMode()
    -- TODO: write me
end

os.exit(lu.LuaUnit.run())
