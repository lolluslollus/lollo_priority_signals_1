local _isExtendedLogActive = false
local _isWarningLogActive = true
local _isErrorLogActive = true
local _isTimersActive = true
local _isTestMode = false

return {
    isExtendedLog = function()
        return _isExtendedLogActive
    end,
    isTestMode = function()
        return _isTestMode
    end,
    print = function(...)
        if not(_isExtendedLogActive) then return end
        print(...)
    end,
    warn = function(label, ...)
        if not(_isWarningLogActive) then return end
        print('lollo_priority_signals WARNING: ' .. label, ...)
    end,
    err = function(label, ...)
        if not(_isErrorLogActive) then return end
        print('lollo_priority_signals ERROR: ' .. label, ...)
    end,
    debugPrint = function(whatever)
        if not(_isExtendedLogActive) then return end
        debugPrint(whatever)
    end,
    warningDebugPrint = function(whatever)
        if not(_isWarningLogActive) then return end
        debugPrint(whatever)
    end,
    errorDebugPrint = function(whatever)
        if not(_isErrorLogActive) then return end
        debugPrint(whatever)
    end,
    profile = function(label, func)
        if _isTimersActive then
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
        if not(_isExtendedLogActive) then return end
        print('lollo_priority_signals INFO:') debugPrint(error)
    end,
    xpWarningHandler = function(error)
        if not(_isWarningLogActive) then return end
        print('lollo_priority_signals WARNING:') debugPrint(error)
    end,
    xpErrorHandler = function(error)
        if not(_isErrorLogActive) then return end
        print('lollo_priority_signals ERROR:') debugPrint(error)
    end,
}
