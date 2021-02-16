-- parinfer.lua - a Parinfer implementation in Lua
-- v0.1.0
-- https://github.com/oakmac/parinfer-lua
--
-- More information about Parinfer can be found here:
-- http://shaunlebron.github.io/parinfer/
--
-- Copyright (c) 2021, Chris Oakman and other contributors
-- Released under the ISC license
-- https://github.com/oakmac/parinfer-lua/blob/master/LICENSE.md


local inspect = require('libs/inspect')

local M = {}

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Lua Helpers

-- TODO: surely there must be a faster way to determine table length that is not O(n)?

function getTableSize(t)
  local count = 0
  for _, __ in pairs(t) do
    count = count + 1
  end
  return count
end

assert(getTableSize({}) == 0)
assert(getTableSize({"a", "b"}) == 2)
assert(getTableSize({ a = "a", b = "b"}) == 2)

local function isTableEmpty(t)
  for _, __ in pairs(t) do
    return false
  end
  return true
end

assert(isTableEmpty({}))
assert(not isTableEmpty({"a", "b"}))

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Constants / Type Predicates

local UINT_NULL = -999

local INDENT_MODE = 'INDENT_MODE'
local PAREN_MODE = 'PAREN_MODE'

local BACKSLASH = '\\'
local BLANK_SPACE = ' '
local DOUBLE_SPACE = '  '
local DOUBLE_QUOTE = '"'
local NEWLINE = '\n'
local TAB = '\t'

-- local LINE_ENDING_REGEX = /\r?\n/

local MATCH_PAREN = {}
MATCH_PAREN['{'] = '}'
MATCH_PAREN['}'] = '{'
MATCH_PAREN['['] = ']'
MATCH_PAREN[']'] = '['
MATCH_PAREN['('] = ')'
MATCH_PAREN[')'] = '('

local function isBoolean (x) 
  return x == true or x == false
end

local function isArray (x)
  -- TODO: write me
end

local function isInteger (x) 
  -- TODO: write me
end

local function isString (s) 
  return type(s) == 'string'
end

assert(isString('s'))
assert(not isString(true))

local function isChar (c) 
  return isString(c) and c:len() == 1
end

assert(isChar('s'))
assert(not isChar('xx'))
assert(not isChar(true))

local function isArrayOfChars (arr) 
  -- TODO: write me
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Options Structure

local function transformChange (change) 
  -- TODO: write me
end

local function transformChanges (changes)
  -- TODO: write me
end

local function parseOptions (options) 
  -- TODO: write me
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Result Structure

local function initialParenTrail () 
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

local function getInitialResult (text, options, mode, smart)
    local result = {
      mode = mode, 
      smart = smart, 

      origText = text, 
      origCursorX = UINT_NULL, 
      origCursorLine = UINT_NULL, 

      inputLines = 
      text.split(LINE_ENDING_REGEX),
      inputLineNo = -1, 
      inputX = -1, 

      lines = {}, 
      lineNo = -1, 
      ch = '', 
      x = 0, 
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

      commentChars = {';'}, 

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

      error2 = { 
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
      if (isArray(options.changes)) then
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
      if (isArrayOfChars(options.commentChars)) then
        result.commentChars = options.commentChars 
      end
    end
    
    return result
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Possible Errors

-- `result.error.name` is set to any of these
local ERROR_QUOTE_DANGER = 'quote-danger'
local ERROR_EOL_BACKSLASH = 'eol-backslash'
local ERROR_UNCLOSED_QUOTE = 'unclosed-quote'
local ERROR_UNCLOSED_PAREN = 'unclosed-paren'
local ERROR_UNMATCHED_CLOSE_PAREN = 'unmatched-close-paren'
local ERROR_UNMATCHED_OPEN_PAREN = 'unmatched-open-paren'
local ERROR_LEADING_CLOSE_PAREN = 'leading-close-paren'
local ERROR_UNHANDLED = 'unhandled'

local errorMessages = {}
errorMessages[ERROR_QUOTE_DANGER] = 'Quotes must balanced inside comment blocks.'
errorMessages[ERROR_EOL_BACKSLASH] = 'Line cannot end in a hanging backslash.'
errorMessages[ERROR_UNCLOSED_QUOTE] = 'String is missing a closing quote.'
errorMessages[ERROR_UNCLOSED_PAREN] = 'Unclosed open-paren.'
errorMessages[ERROR_UNMATCHED_CLOSE_PAREN] = 'Unmatched close-paren.'
errorMessages[ERROR_UNMATCHED_OPEN_PAREN] = 'Unmatched open-paren.'
errorMessages[ERROR_LEADING_CLOSE_PAREN] = 'Line cannot lead with a close-paren.'
errorMessages[ERROR_UNHANDLED] = 'Unhandled error.'

local function cacheErrorPos (result, errorName) 
  local e = {
    lineNo = result.lineNo,
    x = result.x,
    inputLineNo = result.inputLineNo,
    inputX = result.inputX
  }
  
  result.errorPosCache[errorName] = e
  
  return e
end

local function error2 (result, errorName)
  -- TODO: write me
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- String Operations

local function replaceWithinString (orig, startIdx, endIdx, replace) 
  -- TODO: write me
end

local function repeatString (text, n)
  -- TODO: write me
end

local function getLineEnding (text) 
  -- TODO: write me
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Line Operations

local function isCursorAffected (result, start, end2) 
  -- TODO: write me
end

local function shiftCursorOnEdit (result, lineNo, start, end2, replace)
  -- TODO: write me
end

local function replaceWithinLin (result, lineNo, start, end2, replace) 
  -- TODO: write me
end

local function insertWithinLine (result, lineNo, idx, insert)
  -- TODO: write me
end

local function initLine (result)
  -- TODO: write me
end

local function commitChar (result, origCh)
  -- TODO: write me
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Misc Util

local function clamp (val, minN, maxN) 
  -- TODO: write me
end

local function peek (arr, idxFromBack)
  -- TODO: write me
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Character Predicates

local function isOpenParen (ch) 
  return ch == '{' or ch == '(' or ch == '['
end

assert(isOpenParen('(') == true)
assert(isOpenParen(']') == false)

local function isCloseParen (ch)
  return ch == '}' or ch == ')' or ch == ']'
end

assert(isCloseParen('}') == true)
assert(isCloseParen('a') == false)

local function isValidCloseParen (parenStack, ch) 
  --if table.getn(parenStack) == 0 then
  --  return false
  --end
  --local firstItemInParenStack = peek(parenStack, 0)
  --return firstItemInParenStack.ch == MATCH_PAREN[ch]
end

--local exampleParenStack = {
--  { ch = '(' }
--}
--
--assert(not isValidCloseParen(exampleParenStack, 'x'))

local function isWhitespace (result)
  local ch = result.ch
  return (not result.isEscaped) and (ch == BLANK_SPACE or ch == DOUBLE_SPACE)
end

local function isClosable (result) 
  -- TODO: write me
end

local function isCommentChar (ch, commentChars)
  -- TODO: write me
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Advanced Character Operations


local function checkCursorHolding (result) 
  -- TODO: write me
end

local function trackArgTabStop (result, state)
  -- TODO: write me
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Literal Character Events


local function onOpenParen (result) 
  -- TODO: write me
end

local function setCloser (opener, lineNo, x, ch)
  -- TODO: write me
end

local function onMatchedCloseParen (result) 
  -- TODO: write me
end

local function onUnmatchedCloseParen (result)
  -- TODO: write me
end

local function onCloseParen (result) 
  -- TODO: write me
end

local function onTab (result)
  -- TODO: write me
end

local function onCommentChar (result)
  -- TODO: write me
end

local function onNewline (result)
  -- TODO: write me
end

local function onQuote (result) 
  -- TODO: write me
end

local function onBackslash (result)
  -- TODO: write me
end

local function afterBackslash (result) 
  -- TODO: write me
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Character Dispatch

local function onChar (result)
  -- TODO: write me
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Cursor Functions

local function isCursorLeftOf(cursorX, cursorLine, x, lineNo) 
  -- TODO: write me
end

local function isCursorRightOf (cursorX, cursorLine, x, lineNo)
  -- TODO: write me
end

local function isCursorInComment (result, cursorX, cursorLine) 
  -- TODO: write me
end

local function handleChangeDelta (result) 
  -- TODO: write me
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Paren Trail Functions

local function resetParenTrail(result, lineNo, x) 
  -- TODO: write me
end

local function isCursorClampingParenTrail (result, cursorX, cursorLine)
  -- TODO: write me
end

local function clampParenTrailToCursor (result) 
  -- TODO: write me
end

local function popParenTrail (result) 
  -- TODO: write me
end

local function getParentOpenerIndex (result, indentX)
  -- TODO: write me
end

local function correctParenTrail (result, indentX)
  -- TODO: write me
end

local function cleanParenTrail (result)
  -- TODO: write me
end

local function appendParenTrail (result)
  -- TODO: write me
end

local function invalidateParenTrail (result)
  -- TODO: write me
end

local function checkUnmatchedOutsideParenTrail (result)
  -- TODO: write me
end

local function setMaxIndent (result, opener)
  -- TODO: write me
end

local function rememberParenTrail (result)
  -- TODO: write me
end

local function updateRememberedParenTrail (result)
  -- TODO: write me
end

local function finishNewParenTrail (result)
  -- TODO: write me
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Indentation Functions

local function addIndent (result, delta)
  -- TODO: write me
end

local function shouldAddOpenerIndent (result, opener)
  -- TODO: write me
end

local function correctIndent (result)
  -- TODO: write me
end

local function onIndent (result)
  -- TODO: write me
end

local function checkLeadingCloseParen (result)
  -- TODO: write me
end

local function onLeadingCloseParen (result)
  -- TODO: write me
end

local function onCommentLine (result)
  -- TODO: write me
end

local function checkIndent (result)
  -- TODO: write me
end

local function makeTabStop (result, opener)
  -- TODO: write me
end

local function getTabStopLine (result)
  -- TODO: write me
end

local function setTabStops (result)
  -- TODO: write me
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- High-level processing functions

local function processChar (result, ch)
  -- TODO: write me
end

local function processLine (result, lineNo)
  -- TODO: write me
end

local function finalizeResult (result)
  -- TODO: write me
end

local function processError (result, e)
  -- TODO: write me
end

local function processText (text, options, mode, smart)
  -- TODO: write me 
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Public API

local function publicResult (result)
  -- TODO: write me
end

local function indentMode (text, options)
  -- TODO: write me
end

local function parenMode (text, options)
  -- TODO: write me
end

local function smartMode (text, options)
  -- TODO: write me
end

M.version = '0.1.0'
M.indentMode = indentMode
M.parentMode = parentMode
M.smartMode = smartMode
