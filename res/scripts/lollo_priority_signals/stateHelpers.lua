local logger = require('lollo_priority_signals.logger')

local persistent_state = {}

local _initState = function()
    if persistent_state.game_time_sec == nil then
        persistent_state.game_time_sec = 0
    end
    if persistent_state.game_time_msec == nil then
        persistent_state.game_time_msec = 0
    end

    if persistent_state.is_on ~= false then
        persistent_state.is_on = true
    end
end

local funcs = {
    initState = _initState,
    loadState = function(state)
        if state then
            persistent_state = state
        end

        _initState()
    end,
    getState = function()
        return persistent_state
    end,
    saveState = function()
        _initState()
        return persistent_state
    end,
}

_initState() -- fires when loading

return funcs
