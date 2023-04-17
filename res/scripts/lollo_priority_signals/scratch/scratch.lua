package.path = package.path .. ';res/scripts/?.lua'
-- package.path = package.path .. ';C:/Program Files (x86)/Steam/steamapps/common/Transport Fever 2/res/scripts/?.lua'

local arrayUtils = require('lollo_priority_signals.arrayUtils')

local aaaa = arrayUtils.getUniqueConcatValues(
    {1, 12345, 3},
    {1, 12344, 3}
)
local aaab = arrayUtils.getUniqueConcatValues(
    {1, 12345, 3},
    {1, 12345, 3}
)

local aaa = { 1, 2, 3, 4}
table.remove(aaa, 2)

local function getBracketsContent(str1)
-- local str1 = 'aaaa(b12 _?) ajs'
-- local str2 = string.gsub(str1, '[^()]*%(', '')
local str2 = string.gsub(str1, '[^(]*%(', '')
-- local str3 = string.gsub(str2, '%)[^()]*', '')
local str3 = string.gsub(str2, '%)[^)]*', '')
return str3
end

local a = getBracketsContent('aaaa(b12 _?) ajs')
local b = getBracketsContent('(aaaab12 _?) ajs')
local c = getBracketsContent('(aaaab12 _?)')
local d = getBracketsContent('(aaaa(b12 _?) ajs')
local e = getBracketsContent('aaaab12 _? ajs')

local deltaI = 0
local _fetchNextDelta = function()
    -- + 1, -1, +2, -2, +3. -3 and so on
    if deltaI > 0 then deltaI = -deltaI else deltaI = -deltaI + 1 end
end

local aa = {}
for i = 1, 25, 1 do
    aa[i] = deltaI
    _fetchNextDelta()
end


local testString = 'abdcbjhkl()dddd'
local str1 = string.gsub(testString, '[^(]*%(', '')
local str2 = string.gsub(str1, '%)[^)]*', '')

local function getMatches(testStr)
    local results = {}
    for mat in string.gmatch(testStr, '%([^()]*%)') do
        -- print(w)
        table.insert(results, mat)
    end
    return results
end

local getTextBetweenBrackets = function(str, isOnlyBetweenBrackets)
    -- call this with isOnlyBetweenBrackets == true to fully match lennardo's mod
    -- set it false or leave it empty to always display something
    if not(str) then return '' end

    local result = ''
    local isFound = false
    for match in string.gmatch(str, '%(([^()]*)%)') do
        -- result = result .. string.sub(match, 2, match:len() - 1)
        result = result .. match
        isFound = true
    end

    if not(isFound) and not(isOnlyBetweenBrackets) then
        return str
    end
    return result
end

local aaaa = getMatches('abcdd()sss')
local aaab = getMatches('abcdd(a)sss')
local aaabb = getMatches('abcdd(aba)sss')
local aaac = getMatches('abcdd(sss')
local aaad = getMatches('abcdd)sss')
local aaae = getMatches('abcdd(()))sss')
local aaaf = getMatches('abcdd(()sss')

local baaa = getTextBetweenBrackets('abcdd()sss')
local baab = getTextBetweenBrackets('abcdd(a)sss')
local baabb = getTextBetweenBrackets('abcdd(aba)sss')
local baac = getTextBetweenBrackets('abcdd(sss')
local baad = getTextBetweenBrackets('abcdd)sss')
local baae = getTextBetweenBrackets('abcdd(()))sss')
local baaf = getTextBetweenBrackets('abcdd(()sss')
local baag = getTextBetweenBrackets('abcdd(aba)(pup)sss')
local baah = getTextBetweenBrackets('abcdd(aba)s(pop)ss')

local caaa = getTextBetweenBrackets('abcdd()sss', true)
local caab = getTextBetweenBrackets('abcdd(a)sss', true)
local caabb = getTextBetweenBrackets('abcdd(aba)sss', true)
local caac = getTextBetweenBrackets('abcdd(sss', true)
local caad = getTextBetweenBrackets('abcdd)sss', true)
local caae = getTextBetweenBrackets('abcdd(()))sss', true)
local caaf = getTextBetweenBrackets('abcdd(()sss', true)
local caag = getTextBetweenBrackets('abcdd(aba)(pup)sss', true)
local caah = getTextBetweenBrackets('abcdd(aba)s(pop)ss', true)

local logger = require('lollo_priority_signals.logger')
local dummy1 = logger.isExtendedLog()
logger.print('Logger ONE')

local profileLogger = require('res.scripts.lollo_priority_signals.profileLogger')
logger.print('loggger test 02 = ', print('logger test 01'))
logger.print('Logger ONEONE')
profileLogger.print('Logger TWO')
local dummy11 = logger.isExtendedLog()
local dummy2 = profileLogger.isExtendedLog()

local dummy = 123
