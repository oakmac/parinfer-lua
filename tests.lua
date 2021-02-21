local lu = require("libs/luaunit")
local json = require("libs/json")
local inspect = require("libs/inspect")
local parinfer = require("parinfer")

local function isInteger(i)
    return type(i) == "number" and i == math.floor(i)
end

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

-- TODO: add additional test cases here (optional comments Table)

-- load test cases JSON
local indentModeCases = json.decode(readFile("./test-cases/indent-mode.json"))
local parenModeCases = json.decode(readFile("./test-cases/paren-mode.json"))
local smartModeCases = json.decode(readFile("./test-cases/smart-mode.json"))

-- the test cases all assume 0-indexed values (they originate from parinfer.js)
-- this function adjusts them +1 for Lua
local function adjustIndexesForLua(testCase)
    -- options.cursorX
    if testCase.options and isInteger(testCase.options.cursorX) then
        testCase.options.cursorX = testCase.options.cursorX + 1
    end

    -- options.cursorLine
    if testCase.options and isInteger(testCase.options.cursorLine) then
        testCase.options.cursorLine = testCase.options.cursorLine + 1
    end

    -- options.prevCursorX
    if testCase.options and isInteger(testCase.options.prevCursorX) then
        testCase.options.prevCursorX = testCase.options.prevCursorX + 1
    end

    -- options.prevCursorLine
    if testCase.options and isInteger(testCase.options.prevCursorLine) then
        testCase.options.prevCursorLine = testCase.options.prevCursorLine + 1
    end

    -- options.changes
    if testCase.options and testCase.options.changes then
        for _idx, changeItm in pairs(testCase.options.changes) do
            if isInteger(changeItm.lineNo) then
                changeItm.lineNo = changeItm.lineNo + 1
            end
            if isInteger(changeItm.x) then
                changeItm.x = changeItm.x + 1
            end
        end
    end

    -- result.cursorX
    -- result.cursorLine
    if testCase.result then
        if isInteger(testCase.result.cursorX) then
            testCase.result.cursorX = testCase.result.cursorX + 1
        end
        if isInteger(testCase.result.cursorLine) then
            testCase.result.cursorLine = testCase.result.cursorLine + 1
        end
    end

    -- result.error.lineNo
    -- result.error.x
    if testCase.result and testCase.result.error then
        if isInteger(testCase.result.error.lineNo) then
            testCase.result.error.lineNo = testCase.result.error.lineNo + 1
        end
        if isInteger(testCase.result.error.x) then
            testCase.result.error.x = testCase.result.error.x + 1
        end
    end

    -- result.parenTrails
    if testCase.result.parenTrails then
        for _idx, ts in pairs(testCase.result.parenTrails) do
            if isInteger(ts.lineNo) then
                ts.lineNo = ts.lineNo + 1
            end
            if isInteger(ts.startX) then
                ts.startX = ts.startX + 1
            end
            if isInteger(ts.endX) then
                ts.endX = ts.endX + 1
            end
        end
    end

    -- result.tabStops
    if testCase.result.tabStops then
        for _idx, ts in pairs(testCase.result.tabStops) do
            if isInteger(ts.x) then
                ts.x = ts.x + 1
            end
            if isInteger(ts.lineNo) then
                ts.lineNo = ts.lineNo + 1
            end
            if isInteger(ts.argX) then
                ts.argX = ts.argX + 1
            end
        end
    end

    return testCase
end

-- NOTE: this is named "assertStructure" in parinfer test.js
local function assertStructure2(actual, expected)
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
        lu.assertEquals(actual.error.lineNo, expected.error.lineNo)
        lu.assertEquals(actual.error.x, expected.error.x)
    end

    if (expected.tabStops) then
        lu.assertIsTable(actual.tabStops)

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
local function assertStructure1(testCase, mode)
    local expected = testCase.result
    local text = testCase.text
    local options = testCase.options
    local result1, result2, result3

    -- We are not yet verifying that the returned paren tree is correct.
    -- We are simply setting it to ensure it is constructed in a way that doesn't
    -- throw an exception.
    options.returnParens = true

    -- "it should generate the correct result structure"
    result1 = nil
    if mode == "indent" then
        result1 = parinfer.indentMode(text, options)
    elseif mode == "paren" then
        result1 = parinfer.parenMode(text, options)
    elseif mode == "smart" then
        result1 = parinfer.smartMode(text, options)
    end
    lu.assertIsTable(result1)

    assertStructure2(result1, expected)

    -- FIXME: not checking paren trails after this main check
    -- (causing problems, and not a priority at time of writing)
    if result1.parenTrails then
        result1.parenTrails = nil
    end

    -- bypass the next checks if these conditions exist
    if (expected.error or expected.tabStops or expected.parenTrails or testCase.options.changes) then
        return
    end

    -- "it should generate the same result structure on idempotence check"
    local options2 = {
        cursorX = result1.cursorX,
        cursorLine = result1.cursorLine
    }
    if testCase.options and testCase.options.commentChars then
        options2.commentChars = testCase.options.commentChars
    end

    result2 = nil
    if mode == "indent" then
        result2 = parinfer.indentMode(result1.text, options2)
    elseif mode == "paren" then
        result2 = parinfer.parenMode(result1.text, options2)
    elseif mode == "smart" then
        result2 = parinfer.smartMode(result1.text, options2)
    end
    lu.assertIsTable(result2)

    assertStructure2(result2, result1)

    -- "it should generate the same result structure on cross-mode check"
    local hasCursor = isInteger(expected.cursorX)
    local options3 = {}
    if testCase.options and testCase.options.commentChars then
        options3.commentChars = testCase.options.commentChars
    end
    if not hasCursor then
        result3 = nil
        if mode == "indent" then
            result3 = parinfer.indentMode(result1.text, options3)
        elseif mode == "paren" then
            result3 = parinfer.parenMode(result1.text, options3)
        elseif mode == "smart" then
            result3 = parinfer.smartMode(result1.text, options3)
        end
        lu.assertIsTable(result3)

        assertStructure2(result3, result1)
    end
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
        local adjustedTestCase = adjustIndexesForLua(testCase)
        assertStructure1(adjustedTestCase, "indent")
    end
end

function testParenMode()
    for _key, testCase in pairs(parenModeCases) do
        print("Testing Paren Mode #" .. testCase.id)
        local adjustedTestCase = adjustIndexesForLua(testCase)
        assertStructure1(adjustedTestCase, "paren")
    end
end

function testSmartMode()
    for _key, testCase in pairs(smartModeCases) do
        print("Testing Smart Mode #" .. testCase.id)
        local adjustedTestCase = adjustIndexesForLua(testCase)
        assertStructure1(adjustedTestCase, "smart")
    end
end

os.exit(lu.LuaUnit.run())
