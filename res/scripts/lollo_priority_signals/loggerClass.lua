local _mDefaultConstantData = {
    isExtendedLogActive = false,
    isWarningLogActive = true,
    isErrorLogActive = true,
    isTimersActive = true,
}

local mInstanceCount = 0

return {
    ---ctor
    ---@param isExtendedLogActive? boolean
    ---@param isWarningLogActive? boolean
    ---@param isErrorLogActive? boolean
    ---@param isTimersActive? boolean
    ---@return table
    new = function(isExtendedLogActive, isWarningLogActive, isErrorLogActive, isTimersActive)
        mInstanceCount = mInstanceCount + 1

        local constantData = {
            instanceCount = mInstanceCount,
            isExtendedLogActive = type(isExtendedLogActive) == 'boolean' and isExtendedLogActive or _mDefaultConstantData.isExtendedLogActive,
            isWarningLogActive = type(isWarningLogActive) == 'boolean' and isWarningLogActive or _mDefaultConstantData.isWarningLogActive,
            isErrorLogActive = type(isErrorLogActive) == 'boolean' and isErrorLogActive or _mDefaultConstantData.isErrorLogActive,
            isTimersActive = type(isTimersActive) == 'boolean' and isTimersActive or _mDefaultConstantData.isTimersActive,
        }
        return {
            isExtendedLog = function()
                return constantData.isExtendedLogActive
            end,
            print = function(...)
                if not(constantData.isExtendedLogActive) then return end
                print(...)
            end,
            warn = function(label, ...)
                if not(constantData.isWarningLogActive) then return end
                print('lollo_priority_signals WARNING: ' .. label, ...)
            end,
            err = function(label, ...)
                if not(constantData.isErrorLogActive) then return end
                print('lollo_priority_signals ERROR: ' .. label, ...)
            end,
            debugPrint = function(whatever)
                if not(constantData.isExtendedLogActive) then return end
                debugPrint(whatever)
            end,
            warningDebugPrint = function(whatever)
                if not(constantData.isWarningLogActive) then return end
                debugPrint(whatever)
            end,
            errorDebugPrint = function(whatever)
                if not(constantData.isErrorLogActive) then return end
                debugPrint(whatever)
            end,
            profile = function(label, func)
                if constantData.isTimersActive then
                    local results
                    local startSec = os.clock()
                    print('######## ' .. tostring(label or '') .. ' starting at', math.ceil(startSec * 1000), 'mSec')
                    -- results = {func()} -- func() may return several results, it's LUA
                    results = func()
                    local elapsedSec = os.clock() - startSec
                    print('######## ' .. tostring(label or '') .. ' took' .. math.ceil(elapsedSec * 1000) .. 'mSec')
                    -- return table.unpack(results) -- test if we really need this
                    return results
                else
                    return func() -- test this
                end
            end,
            xpHandler = function(error)
                if not(constantData.isExtendedLogActive) then return end
                print('lollo_priority_signals INFO:') debugPrint(error)
            end,
            xpWarningHandler = function(error)
                if not(constantData.isWarningLogActive) then return end
                print('lollo_priority_signals WARNING:') debugPrint(error)
            end,
            xpErrorHandler = function(error)
                if not(constantData.isErrorLogActive) then return end
                print('lollo_priority_signals ERROR:') debugPrint(error)
            end,
        }
    end
}
