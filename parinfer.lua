-- parinfer.lua - a Parinfer implementation in Lua
-- v0.1.0
-- https://github.com/oakmac/parinfer-lua
--
-- More information about Parinfer can be found here:
-- http://shaunlebron.github.io/parinfer/
--
-- Copyright (c) 2021, Chris Oakman
-- Released under the ISC license
-- https://github.com/oakmac/parinfer-lua/blob/master/LICENSE.md

-- TODO: comment this out before publication; used for development debugging
local inspect = require("libs/inspect")

local M = {}

-- forward declarations
local splitLines, resetParenTrail

local trace = false

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Lua Helpers

-- TODO: surely there must be a faster way to determine table length that is not O(n)?

function size(t)
    local count = 0
    for _key, _val in pairs(t) do
        count = count + 1
    end
    return count
end

assert(size({}) == 0)
assert(size({"a", "b"}) == 2)
assert(size({"a", "b", "c", "d", "e"}) == 5)
assert(size({a = "a", b = "b"}) == 2)

local function isTableEmpty(t)
    for _key, _val in pairs(t) do
        return false
    end
    return true
end

assert(isTableEmpty({}))
assert(not isTableEmpty({"a", "b"}))

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Constants / Type Predicates

local UINT_NULL = -999

local INDENT_MODE = "INDENT_MODE"
local PAREN_MODE = "PAREN_MODE"

local BACKSLASH = "\\"
local BLANK_SPACE = " "
local DOUBLE_SPACE = "  "
local DOUBLE_QUOTE = '"'
local NEWLINE = "\n"
local TAB = "\t"

-- local LINE_ENDING_REGEX = /\r?\n/

local MATCH_PAREN = {}
MATCH_PAREN["{"] = "}"
MATCH_PAREN["}"] = "{"
MATCH_PAREN["["] = "]"
MATCH_PAREN["]"] = "["
MATCH_PAREN["("] = ")"
MATCH_PAREN[")"] = "("

local function isBoolean(x)
    return x == true or x == false
end

local function isTable(t)
    return type(t) == "table"
end

local function isInteger(i)
    return type(i) == "number" and i == math.floor(i)
end

assert(isInteger(1))
assert(isInteger(-97))
assert(not isInteger(3.14))
assert(not isInteger())
assert(not isInteger({}))
assert(not isInteger("6"))

local function isString(s)
    return type(s) == "string"
end

assert(isString("s"))
assert(not isString(true))

local function isChar(c)
    return isString(c) and string.len(c) == 1
end

assert(isChar("s"))
assert(not isChar("xx"))
assert(not isChar(true))

local function isTableOfChars(t)
    if not isTable(t) then
        return false
    end

    for _key, ch in pairs(t) do
        if not isChar(ch) then
            return false
        end
    end

    return true
end

assert(isTableOfChars({}))
assert(isTableOfChars({"a", "b", "c"}))
assert(not isTableOfChars({"a", "b", "ccc"}))

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Options Structure

local function transformChange(change)
    -- TODO: write me
    print("UNPORTED FUNCTION: transformChange -----------------------------------")
end

local function transformChanges(changes)
    -- TODO: write me
    print("UNPORTED FUNCTION: transformChanges -----------------------------------")
end

local function parseOptions(options)
    if (not isTable(options)) then
        options = {}
    end

    return {
        changes = options.changes,
        commentChars = options.commentChars,
        cursorLine = options.cursorLine,
        cursorX = options.cursorX,
        forceBalance = options.forceBalance,
        partialResult = options.partialResult,
        prevCursorLine = options.prevCursorLine,
        prevCursorX = options.prevCursorX,
        returnParens = options.returnParens,
        selectionStartLine = options.selectionStartLine
    }
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Result Structure

local function initialParenTrail()
    return {
        lineNo = UINT_NULL,
        startX = UINT_NULL,
        endX = UINT_NULL,
        openers = {},
        clamped = {
            startX = UINT_NULL,
            endX = UINT_NULL,
            openers = {}
        }
    }
end

local function getInitialResult(text, options, mode, smart)
    local result = {
        mode = mode,
        smart = smart,
        origText = text,
        origCursorX = UINT_NULL,
        origCursorLine = UINT_NULL,
        inputLines = splitLines(text),
        inputLineNo = 0, -- Lua ONE INDEX
        inputX = 0, -- Lua ONE INDEX
        lines = {},
        lineNo = 0, -- Lua ONE INDEX
        ch = "",
        x = 0, -- Lua ONE INDEX
        indentX = UINT_NULL,
        parenStack = {},
        tabStops = {},
        parenTrail = initialParenTrail(),
        parenTrails = {},
        returnParens = false,
        parens = {},
        cursorX = UINT_NULL,
        cursorLine = UINT_NULL,
        prevCursorX = UINT_NULL,
        prevCursorLine = UINT_NULL,
        commentChars = {";"},
        selectionStartLine = UINT_NULL,
        changes = nil,
        isInCode = true,
        isEscaping = false,
        isEscaped = false,
        isInStr = false,
        isInComment = false,
        commentX = UINT_NULL,
        quoteDanger = false,
        trackingIndent = false,
        skipChar = false,
        success = false,
        partialResult = false,
        forceBalance = false,
        maxIndent = UINT_NULL,
        indentDelta = 0,
        trackingArgTabStop = nil,
        ["error"] = {
            name = nil,
            message = nil,
            lineNo = nil,
            x = nil,
            extra = {
                name = nil,
                lineNo = nil,
                x = nil
            }
        },
        errorPosCache = {}
    }

    -- merge user options if they are valid
    if (options) then
        if (isInteger(options.cursorX)) then
            result.cursorX = options.cursorX
            result.origCursorX = options.cursorX
        end

        if (isInteger(options.cursorLine)) then
            result.cursorLine = options.cursorLine
            result.origCursorLine = options.cursorLine
        end

        if (isInteger(options.prevCursorX)) then
            result.prevCursorX = options.prevCursorX
        end
        if (isInteger(options.prevCursorLine)) then
            result.prevCursorLine = options.prevCursorLine
        end
        if (isInteger(options.selectionStartLine)) then
            result.selectionStartLine = options.selectionStartLine
        end
        if (isTable(options.changes)) then
            result.changes = transformChanges(options.changes)
        end
        if (isBoolean(options.partialResult)) then
            result.partialResult = options.partialResult
        end
        if (isBoolean(options.forceBalance)) then
            result.forceBalance = options.forceBalance
        end
        if (isBoolean(options.returnParens)) then
            result.returnParens = options.returnParens
        end
        if (isChar(options.commentChars)) then
            result.commentChars = {options.commentChars}
        end
        if (isTableOfChars(options.commentChars)) then
            result.commentChars = options.commentChars
        end
    end

    return result
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Possible Errors

-- `result.error.name` is set to any of these
local ERROR_QUOTE_DANGER = "quote-danger"
local ERROR_EOL_BACKSLASH = "eol-backslash"
local ERROR_UNCLOSED_QUOTE = "unclosed-quote"
local ERROR_UNCLOSED_PAREN = "unclosed-paren"
local ERROR_UNMATCHED_CLOSE_PAREN = "unmatched-close-paren"
local ERROR_UNMATCHED_OPEN_PAREN = "unmatched-open-paren"
local ERROR_LEADING_CLOSE_PAREN = "leading-close-paren"
local ERROR_UNHANDLED = "unhandled"

local errorMessages = {}
errorMessages[ERROR_QUOTE_DANGER] = "Quotes must balanced inside comment blocks."
errorMessages[ERROR_EOL_BACKSLASH] = "Line cannot end in a hanging backslash."
errorMessages[ERROR_UNCLOSED_QUOTE] = "String is missing a closing quote."
errorMessages[ERROR_UNCLOSED_PAREN] = "Unclosed open-paren."
errorMessages[ERROR_UNMATCHED_CLOSE_PAREN] = "Unmatched close-paren."
errorMessages[ERROR_UNMATCHED_OPEN_PAREN] = "Unmatched open-paren."
errorMessages[ERROR_LEADING_CLOSE_PAREN] = "Line cannot lead with a close-paren."
errorMessages[ERROR_UNHANDLED] = "Unhandled error."

local function cacheErrorPos(result, errorName)
    local e = {
        lineNo = result.lineNo,
        x = result.x,
        inputLineNo = result.inputLineNo,
        inputX = result.inputX
    }

    result.errorPosCache[errorName] = e

    return e
end

local function createError(result, errorName)
    local cache = result.errorPosCache[name]

    local keyLineNo = "inputLineNo"
    if result.partialResult then
        keyLineNo = "lineNo"
    end

    local keyX = "inputX"
    if result.partialResult then
        keyX = "x"
    end

    local newLineNo = result[keyLineNo]
    if cache then
        newLineNo = cache[keyLineNo]
    end

    local newX = result[keyX]
    if cache then
        newX = cache[keyX]
    end

    local e = {
        parinferError = true,
        name = name,
        message = errorMessages[name],
        lineNo = newLineNo,
        x = newX
    }
    local opener = peek(result.parenStack, 0)

    if name == ERROR_UNMATCHED_CLOSE_PAREN then
        -- extra error info for locating the open-paren that it should've matched
        cache = result.errorPosCache[ERROR_UNMATCHED_OPEN_PAREN]
        if cache or opener then
            local newLineNo2 = opener[keyLineNo]
            if cache then
                newLineNo2 = cache[keyLineNo]
            end

            local newX2 = opener[keyX]
            if cache then
                newX2 = cache[keyX]
            end

            e.extra = {
                name = ERROR_UNMATCHED_OPEN_PAREN,
                lineNo = newLineNo2,
                x = newX2
            }
        end
    elseif name == ERROR_UNCLOSED_PAREN then
        e.lineNo = opener[keyLineNo]
        e.x = opener[keyX]
    end

    return e
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- String Operations

local function strJoin(tbl, delimiter)
    return table.concat(tbl, delimiter)
end

assert(strJoin({"a", "b", "c"}, "") == "abc")
assert(strJoin({"a", "b", "c"}, "x") == "axbxc")
assert(strJoin({"a", "b", "c"}, "\n") == "a\nb\nc")
assert(strJoin({"a", "b", "c", "dd"}, "zz") == "azzbzzczzdd")
assert(strJoin({}, "z") == "")
assert(strJoin({}, "") == "")

-- modified from penlight: https://tinyurl.com/37fqwxy8
splitLines = function(s)
    local res = {}
    local pos = 1
    while true do
        local line_end_pos = string.find(s, "[\r\n]", pos)
        if not line_end_pos then
            break
        end

        local line_end = string.sub(s, line_end_pos, line_end_pos)
        if line_end == "\r" and string.sub(s, line_end_pos + 1, line_end_pos + 1) == "\n" then
            line_end = "\r\n"
        end

        local line = string.sub(s, pos, line_end_pos - 1)
        table.insert(res, line)

        pos = line_end_pos + #line_end
    end

    if pos <= #s then
        table.insert(res, string.sub(s, pos))
    end
    return res
end

local function replaceWithinString(orig, startIdx, endIdx, replace)
    local head = string.sub(orig, 1, startIdx)
    local tail = string.sub(orig, endIdx + 1, -1)
    return head .. replace .. tail
end

assert(replaceWithinString("aaa", 0, 2, "") == "a")
assert(replaceWithinString("aaa", 0, 1, "b") == "baa")
assert(replaceWithinString("aaa", 0, 2, "b") == "ba")

local function repeatString(text, n)
    return string.rep(text, n)
end

assert(repeatString("a", 2) == "aa")
assert(repeatString("aa", 3) == "aaaaaa")
assert(repeatString("aa", 0) == "")
assert(repeatString("", 0) == "")
assert(repeatString("", 5) == "")

local function getLineEnding(text)
    -- TODO: write me
    print("UNPORTED FUNCTION: getLineEnding -----------------------------------")

    return "\n"
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Line Operations

local function isCursorAffected(result, start, endIdx)
    if (result.cursorX == start and result.cursorX == endIdx) then
        return result.cursorX == 0
    end
    return result.cursorX >= endIdx
end

local function shiftCursorOnEdit(result, lineNo, startIdx, endIdx, replace)
    local oldLength = endIdx - startIdx
    local newLength = string.len(replace)
    local dx = newLength - oldLength

    if
        (dx ~= 0 and result.cursorLine == lineNo and result.cursorX ~= UINT_NULL and
            isCursorAffected(result, startIdx, endIdx))
     then
        result.cursorX = result.cursorX + dx
    end
end

local function replaceWithinLine(result, lineNo, startIdx, endIdx, replace)
    local line = result.lines[lineNo]

    if trace then
        print(inspect(result))
        print("[TRACE] replaceWithinLine")
    end

    local newLine = replaceWithinString(line, startIdx, endIdx, replace)
    result.lines[lineNo] = newLine

    shiftCursorOnEdit(result, lineNo, startIdx, endIdx, replace)
end

local function insertWithinLine(result, lineNo, idx, insert)
    replaceWithinLine(result, lineNo, idx, idx, insert)
end

local function initLine(result)
    result.x = 1 -- Lua ONE INDEX
    result.lineNo = result.lineNo + 1

    -- reset line-specific state
    result.indentX = UINT_NULL
    result.commentX = UINT_NULL
    result.indentDelta = 0
    result.errorPosCache[ERROR_UNMATCHED_CLOSE_PAREN] = nil
    result.errorPosCache[ERROR_UNMATCHED_OPEN_PAREN] = nil
    result.errorPosCache[ERROR_LEADING_CLOSE_PAREN] = nil

    result.trackingArgTabStop = nil
    result.trackingIndent = not result.isInStr
end

-- if the current character has changed, commit its change to the current line.
local function commitChar(result, origCh)
    local ch = result.ch
    local origChLength = string.len(origCh)
    local chLength = string.len(ch)

    if origCh ~= ch then
        replaceWithinLine(result, result.lineNo, result.x, result.x + origChLength, ch)
        result.indentDelta = result.indentDelta - origChLength - chLength
    end

    if trace then
        print("[TRACE] inside commitChar")
    end

    result.x = result.x + chLength
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Misc Util

local function clamp(val, minN, maxN)
    if (minN ~= UINT_NULL) then
        val = math.max(minN, val)
    end
    if (maxN ~= UINT_NULL) then
        val = math.min(maxN, val)
    end
    return val
end

assert(clamp(1, 3, 5) == 3)
assert(clamp(9, 3, 5) == 5)
assert(clamp(1, 3, UINT_NULL) == 3)
assert(clamp(5, 3, UINT_NULL) == 5)
assert(clamp(1, UINT_NULL, 5) == 1)
assert(clamp(9, UINT_NULL, 5) == 5)
assert(clamp(1, UINT_NULL, UINT_NULL) == 1)

local function peek(arr, idxFromBack)
    idxFromBack = idxFromBack + 1
    local maxIdx = size(arr)
    if (idxFromBack > maxIdx) then
        return nil
    end
    return arr[maxIdx - idxFromBack + 1]
end

assert(peek({"a"}, 0) == "a")
assert(peek({"a"}, 1) == nil)
assert(peek({"a", "b", "c"}, 0) == "c")
assert(peek({"a", "b", "c"}, 1) == "b")
assert(peek({"a", "b", "c"}, 5) == nil)
assert(peek({}, 0) == nil)
assert(peek({}, 1) == nil)

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Character Predicates

local function isOpenParen(ch)
    return ch == "{" or ch == "(" or ch == "["
end

assert(isOpenParen("(") == true)
assert(isOpenParen("]") == false)

local function isCloseParen(ch)
    return ch == "}" or ch == ")" or ch == "]"
end

assert(isCloseParen("}") == true)
assert(isCloseParen("a") == false)

local function isValidCloseParen(parenStack, ch)
    if isTableEmpty(parenStack) then
        return false
    end

    local lastOnStack = peek(parenStack, 0)
    return lastOnStack.ch == MATCH_PAREN[ch]
end

local function isWhitespace(result)
    local ch = result.ch
    return (not result.isEscaped) and (ch == BLANK_SPACE or ch == DOUBLE_SPACE)
end

-- can this be the last code character of a list?
local function isClosable(result)
    local ch = result.ch
    local isCloser = isCloseParen(ch) and not result.isEscaped
    return result.isInCode and not isWhitespace(result) and ch ~= "" and not isCloser
end

local function isCommentChar(ch, commentChars)
    for _key, commentCh in pairs(commentChars) do
        if ch == commentCh then
            return true
        end
    end
    return false
end

assert(isCommentChar(";", {";"}))
assert(isCommentChar(";", {";", "#"}))
assert(isCommentChar("#", {";", "#"}))
assert(not isCommentChar("x", {";"}))
assert(not isCommentChar("", {";"}))
assert(not isCommentChar("#", {";", "a"}))

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Advanced Character Operations

local function checkCursorHolding(result)
    -- TODO: write me
    print("UNPORTED FUNCTION: checkCursorHolding -----------------------------------")
end

local function trackArgTabStop(result, state)
    -- TODO: write me
    print("UNPORTED FUNCTION: trackArgTabStop -----------------------------------")
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Literal Character Events

local function onOpenParen(result)
    if result.isInCode then
        local opener = {
            inputLineNo = result.inputLineNo,
            inputX = result.inputX,
            lineNo = result.lineNo,
            x = result.x,
            ch = result.ch,
            indentDelta = result.indentDelta,
            maxChildIndent = UINT_NULL
        }

        if (result.returnParens) then
            opener.children = {}
            opener.closer = {
                lineNo = UINT_NULL,
                x = UINT_NULL,
                ch = ""
            }

            local parent = peek(result.parenStack, 0)
            if parent then
                parent = parent.children
            else
                parent = result.parens
            end

            table.insert(parent, opener)
        end

        table.insert(result.parenStack, opener)
        result.trackingArgTabStop = "space"
    end
end

local function setCloser(opener, lineNo, x, ch)
    opener.closer.lineNo = lineNo
    opener.closer.x = x
    opener.closer.ch = ch
end

local function onMatchedCloseParen(result)
    local opener = peek(result.parenStack, 0)
    if result.returnParens then
        setCloser(opener, result.lineNo, result.x, result.ch)
    end

    result.parenTrail.endX = result.x + 1
    table.insert(result.parenTrail.openers, opener)

    if (result.mode == INDENT_MODE and result.smart and checkCursorHolding(result)) then
        local origStartX = result.parenTrail.startX
        local origEndX = result.parenTrail.endX
        local origOpeners = result.parenTrail.openers
        resetParenTrail(result, result.lineNo, result.x + 1)
        result.parenTrail.clamped.startX = origStartX
        result.parenTrail.clamped.endX = origEndX
        result.parenTrail.clamped.openers = origOpeners
    end
    table.remove(result.parenStack)
    result.trackingArgTabStop = nil
end

local function onUnmatchedCloseParen(result)
    if (result.mode == PAREN_MODE) then
        local trail = result.parenTrail
        local inLeadingParenTrail = (trail.lineNo == result.lineNo) and (trail.startX == result.indentX)
        local canRemove = result.smart and inLeadingParenTrail
        if (not canRemove) then
            error(createError(result, ERROR_UNMATCHED_CLOSE_PAREN))
        end
    elseif (result.mode == INDENT_MODE and not result.errorPosCache[ERROR_UNMATCHED_CLOSE_PAREN]) then
        cacheErrorPos(result, ERROR_UNMATCHED_CLOSE_PAREN)
        local opener = peek(result.parenStack, 0)
        if opener then
            local e = cacheErrorPos(result, ERROR_UNMATCHED_OPEN_PAREN)
            e.inputLineNo = opener.inputLineNo
            e.inputX = opener.inputX
        end
    end
    result.ch = ""
end

local function onCloseParen(result)
    if result.isInCode then
        if isValidCloseParen(result.parenStack, result.ch) then
            onMatchedCloseParen(result)
        else
            onUnmatchedCloseParen(result)
        end
    end
end

local function onTab(result)
    if result.isInCode then
        result.ch = DOUBLE_SPACE
    end
end

local function onCommentChar(result)
    if result.isInCode then
        result.isInComment = true
        result.commentX = result.x
        result.trackingArgTabStop = nil
    end
end

local function onNewline(result)
    result.isInComment = false
    result.ch = ""
end

local function onQuote(result)
    if result.isInStr then
        result.isInStr = false
    elseif (result.isInComment) then
        result.quoteDanger = not result.quoteDanger
        if (result.quoteDanger) then
            cacheErrorPos(result, ERROR_QUOTE_DANGER)
        end
    else
        result.isInStr = true
        cacheErrorPos(result, ERROR_UNCLOSED_QUOTE)
    end
end

local function onBackslash(result)
    result.isEscaping = true
end

local function afterBackslash(result)
    result.isEscaping = false
    result.isEscaped = true

    if (result.ch == NEWLINE) then
        if (result.isInCode) then
            error(createError(result, ERROR_EOL_BACKSLASH))
        end
        onNewline(result)
    end
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Character Dispatch

local function onChar(result)
    local ch = result.ch
    result.isEscaped = false

    if result.isEscaping then
        afterBackslash(result)
    elseif isOpenParen(ch) then
        onOpenParen(result)
    elseif isCloseParen(ch) then
        onCloseParen(result)
    elseif ch == DOUBLE_QUOTE then
        onQuote(result)
    elseif isCommentChar(ch, result.commentChars) then
        onCommentChar(result)
    elseif ch == BACKSLASH then
        onBackslash(result)
    elseif ch == TAB then
        onTab(result)
    elseif ch == NEWLINE then
        onNewline(result)
    end

    ch = result.ch

    result.isInCode = (not result.isInComment) and (not result.isInStr)

    if isClosable(result) then
        resetParenTrail(result, result.lineNo, result.x + string.len(ch))
    end

    local state = result.trackingArgTabStop
    if state then
        trackArgTabStop(result, state)
    end
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Cursor Functions

local function isCursorLeftOf(cursorX, cursorLine, x, lineNo)
    -- TODO: write me
    print("UNPORTED FUNCTION: isCursorLeftOf -----------------------------------")
end

local function isCursorRightOf(cursorX, cursorLine, x, lineNo)
    -- TODO: write me
    print("UNPORTED FUNCTION: isCursorRightOf -----------------------------------")
end

local function isCursorInComment(result, cursorX, cursorLine)
    -- TODO: write me
    print("UNPORTED FUNCTION: isCursorInComment -----------------------------------")
end

local function handleChangeDelta(result)
    if (result.changes and (result.smart or result.mode == PAREN_MODE)) then
        local line = result.changes[result.inputLineNo]
        if (line) then
            local change = line[result.inputX]
            if (change) then
                result.indentDelta = result.indentDelta + change.newEndX - change.oldEndX
            end
        end
    end
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Paren Trail Functions

resetParenTrail = function(result, lineNo, x)
    result.parenTrail.lineNo = lineNo
    result.parenTrail.startX = x
    result.parenTrail.endX = x
    result.parenTrail.openers = {}
    result.parenTrail.clamped.startX = UINT_NULL
    result.parenTrail.clamped.endX = UINT_NULL
    result.parenTrail.clamped.openers = {}
end

local function isCursorClampingParenTrail(result, cursorX, cursorLine)
    -- TODO: write me
    print("UNPORTED FUNCTION: isCursorClampingParenTrail -----------------------------------")
end

local function clampParenTrailToCursor(result)
    -- TODO: write me
    print("UNPORTED FUNCTION: clampParenTrailToCursor -----------------------------------")
end

local function popParenTrail(result)
    -- TODO: write me
    print("UNPORTED FUNCTION: popParenTrail -----------------------------------")
end

local function getParentOpenerIndex(result, indentX)
    -- TODO: write me
    print("UNPORTED FUNCTION: getParentOpenerIndex -----------------------------------")
end

local function correctParenTrail(result, indentX)
    -- TODO: write me
    print("UNPORTED FUNCTION: correctParenTrail -----------------------------------")

    --local parens = ''
    --local index = getParentOpenerIndex(result, indentX)

    -- FIXME: not ported yet
    --var i
    --for (i = 0; i < index; i++) {
    --  var opener = result.parenStack.pop()
    --  result.parenTrail.openers.push(opener)
    --  var closeCh = MATCH_PAREN[opener.ch]
    --  parens += closeCh
    --
    --      if result.returnParens then
    --        setCloser(opener, result.parenTrail.lineNo, result.parenTrail.startX + i, closeCh)
    --      end
    --    }

    --if result.parenTrail.lineNo ~= UINT_NULL then
    --  replaceWithinLine(result, result.parenTrail.lineNo, result.parenTrail.startX, result.parenTrail.endX, parens)
    --  result.parenTrail.endX = result.parenTrail.startX + parens.length
    --  rememberParenTrail(result)
    --end
end

local function cleanParenTrail(result)
    -- TODO: write me
    print("UNPORTED FUNCTION: cleanParenTrail -----------------------------------")
end

local function appendParenTrail(result)
    -- TODO: write me
    print("UNPORTED FUNCTION: appendParenTrail -----------------------------------")
end

local function invalidateParenTrail(result)
    result.parenTrail = initialParenTrail()
end

local function checkUnmatchedOutsideParenTrail(result)
    -- TODO: write me
    print("UNPORTED FUNCTION: checkUnmatchedOutsideParenTrail -----------------------------------")
end

local function setMaxIndent(result, opener)
    -- TODO: write me
    print("UNPORTED FUNCTION: setMaxIndent -----------------------------------")
end

local function rememberParenTrail(result)
    -- TODO: write me
    print("UNPORTED FUNCTION: rememberParenTrail -----------------------------------")
end

local function updateRememberedParenTrail(result)
    -- TODO: write me
    print("UNPORTED FUNCTION: updateRememberedParenTrail -----------------------------------")
end

local function finishNewParenTrail(result)
    if (result.isInStr) then
        invalidateParenTrail(result)
    elseif (result.mode == INDENT_MODE) then
        clampParenTrailToCursor(result)
        popParenTrail(result)
    elseif (result.mode == PAREN_MODE) then
        setMaxIndent(result, peek(result.parenTrail.openers, 0))
        if (result.lineNo ~= result.cursorLine) then
            cleanParenTrail(result)
        end
        rememberParenTrail(result)
    end
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Indentation Functions

local function addIndent(result, delta)
    local origIndent = result.x
    local newIndent = origIndent + delta
    local indentStr = repeatString(BLANK_SPACE, newIndent)
    replaceWithinLine(result, result.lineNo, 1, origIndent, indentStr) -- Lua ONE INDEX
    result.x = newIndent
    result.indentX = newIndent
    result.indentDelta = result.indentDelta + delta
end

local function shouldAddOpenerIndent(result, opener)
    -- Don't add opener.indentDelta if the user already added it.
    -- (happens when multiple lines are indented together)
    return opener.indentDelta ~= result.indentDelta
end

local function correctIndent(result)
    local origIndent = result.x
    local newIndent = origIndent
    local minIndent = 0
    local maxIndent = result.maxIndent

    local opener = peek(result.parenStack, 0)
    if opener then
        minIndent = opener.x + 1
        maxIndent = opener.maxChildIndent
        if shouldAddOpenerIndent(result, opener) then
            newIndent = newIndent + opener.indentDelta
        end
    end

    newIndent = clamp(newIndent, minIndent, maxIndent)

    if newIndent ~= origIndent then
        addIndent(result, newIndent - origIndent)
    end
end

local function onIndent(result)
    result.indentX = result.x
    result.trackingIndent = false

    if (result.quoteDanger) then
        error(createError(result, ERROR_QUOTE_DANGER))
    end

    if result.mode == INDENT_MODE then
        correctParenTrail(result, result.x)

        local opener = peek(result.parenStack, 0)
        if opener and shouldAddOpenerIndent(result, opener) then
            addIndent(result, opener.indentDelta)
        end
    elseif result.mode == PAREN_MODE then
        correctIndent(result)
    end
end

local function checkLeadingCloseParen(result)
    if result.errorPosCache[ERROR_LEADING_CLOSE_PAREN] and result.parenTrail.lineNo == result.lineNo then
        error(createError(result, ERROR_LEADING_CLOSE_PAREN))
    end
end

local function onLeadingCloseParen(result)
    -- TODO: write me
    print("UNPORTED FUNCTION: onLeadingCloseParen -----------------------------------")
end

local function onCommentLine(result)
    -- TODO: write me
    print("UNPORTED FUNCTION: onCommentLine -----------------------------------")
end

local function checkIndent(result)
    if isCloseParen(result.ch) then
        onLeadingCloseParen(result)
    elseif isCommentChar(result.ch, result.commentChars) then
        -- comments don't count as indentation points
        onCommentLine(result)
        result.trackingIndent = false
    elseif result.ch ~= NEWLINE and result.ch ~= BLANK_SPACE and result.ch ~= TAB then
        onIndent(result)
    end
end

local function makeTabStop(result, opener)
    -- TODO: write me
    print("UNPORTED FUNCTION: makeTabStop -----------------------------------")
end

local function getTabStopLine(result)
    if result.selectionStartLine ~= UINT_NULL then
        return result.selectionStartLine
    end
    return result.cursorLine
end

local function setTabStops(result)
    -- TODO: write me
    print("UNPORTED FUNCTION: setTabStops -----------------------------------")

    -- FIXME: refactor this to not use the early return
    --if (getTabStopLine(result) ~= result.lineNo) then
    --  return
    --end
    --
    --    for idx, _itm in pairs(result.parenStack) do
    --        table.insert(result.tabStops, makeTabStop(result, result.parenStack[idx]))
    --    end
    --
    --
    --    if result.mode == PAREN_MODE then
    --      for (i = result.parenTrail.openers.length - 1; i >= 0; i--) {
    --        result.tabStops.push(makeTabStop(result, result.parenTrail.openers[i]))
    --      }
    --    end

    -- remove argX if it falls to the right of the next stop
    --for (i = 1; i < result.tabStops.length; i++) {
    --  var x = result.tabStops[i].x
    --  var prevArgX = result.tabStops[i - 1].argX
    --  if (prevArgX != null && prevArgX >= x) {
    --    delete result.tabStops[i - 1].argX
    --  }
    --}
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- High-level processing functions

local function processChar(result, ch)
    local origCh = ch

    result.ch = ch
    result.skipChar = false

    handleChangeDelta(result)

    if result.trackingIndent then
        checkIndent(result)
    end

    if result.skipChar then
        result.ch = ""
    else
        onChar(result)
    end

    if trace then
        print("[TRACE] processChar() before commitChar")
    end

    commitChar(result, origCh)

    if trace then
        print("[TRACE] processChar() after commitChar")
    end
end

local function processLine(result, lineNo)
    --print(inspect(result))
    --print('33333333333333333333333333333333333333333333333333333333333')

    initLine(result)

    -- print('after initLine')

    local line = result.inputLines[lineNo]
    table.insert(result.lines, line)

    --print(inspect(result))
    --print("****************************************************")

    setTabStops(result)

    -- print('after setTabStops')

    for idx = 1, string.len(line) do
        --print(idx, '$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$')
        result.inputX = idx
        local ch = string.sub(line, idx, idx)
        processChar(result, ch)
        --print(idx, ':::::::::::::::::::::::::::::::::::::::::')
    end

    if trace then
        print("[TRACE] processLine() done with char processing")
    end

    processChar(result, NEWLINE)

    if trace then
        print("[TRACE] processLine() done with processChar()")
    end

    if not result.forceBalance then
        checkUnmatchedOutsideParenTrail(result)
        checkLeadingCloseParen(result)
    end

    if result.lineNo == result.parenTrail.lineNo then
        finishNewParenTrail(result)
    end
end

local function finalizeResult(result)
    if result.quoteDanger then
        error(createError(result, ERROR_QUOTE_DANGER))
    end
    if result.isInStr then
        error(createError(result, ERROR_UNCLOSED_QUOTE))
    end

    if not isTableEmpty(result.parenStack) then
        if (result.mode == PAREN_MODE) then
            error(createError(result, ERROR_UNCLOSED_PAREN))
        end
    end
    if result.mode == INDENT_MODE then
        initLine(result)
        onIndent(result)
    end

    result.success = true
end

local function processError(result, e)
    -- TODO: write me
    print("UNPORTED FUNCTION: processError -----------------------------------")
end

local function processTextInternal(result)
    for idx, line in pairs(result.inputLines) do
        result.inputLineNo = idx
        processLine(result, idx)
    end

    finalizeResult(result)
end

local function processText(text, options, mode, smart)
    local result = getInitialResult(text, options, mode, smart)

    local status, errOrResult =
        pcall(
        function()
            return processTextInternal(result)
        end
    )

    if status then
        return result
    else
        print("FIXME: do error handling here")
        print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
        print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
        print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
        return nil
    end
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Public API

local function publicResult(result)
    local lineEnding = getLineEnding(result.origText)
    local final
    if result.success == true then
        final = {
            text = strJoin(result.lines, lineEnding),
            cursorX = result.cursorX,
            cursorLine = result.cursorLine,
            success = true,
            tabStops = result.tabStops,
            parenTrails = result.parenTrails
        }
        if result.returnParens then
            final.parens = result.parens
        end
    else
        local finalText = result.origText
        local finalCursorX = result.origCursorX
        local finalCursorLine = result.origCursorLine
        local finalParenTrails = nil

        if result.partialResult then
            finalText = strJoin(result.lines, lineEnding)
            finalCursorX = result.cursorX
            finalCursorLine = result.cursorLine
            finalParenTrails = result.parenTrails
        end

        final = {
            text = finalText,
            cursorX = finalCursorX,
            cursorLine = finalCursorLine,
            parenTrails = finalParenTrails,
            success = false,
            ["error"] = result.error
        }
        if (result.partialResult and result.returnParens) then
            final.parens = result.parens
        end
    end

    if final.cursorX == UINT_NULL then
        final.cursorX = nil
    end
    if final.cursorLine == UINT_NULL then
        final.cursorLine = nil
    end
    if final.tabStops and isTableEmpty(final.tabStops) then
        final.tabStops = nil
    end

    return final
end

local function indentMode(text, options)
    options = parseOptions(options)
    return publicResult(processText(text, options, INDENT_MODE))
end

local function parenMode(text, options)
    options = parseOptions(options)
    return publicResult(processText(text, options, PAREN_MODE))
end

local function smartMode(text, options)
    options = parseOptions(options)
    local smart = options.selectionStartLine == nil
    return publicResult(processText(text, options, INDENT_MODE, smart))
end

M.version = "0.1.0"
M.indentMode = indentMode
M.parenMode = parenMode
M.smartMode = smartMode

return M
