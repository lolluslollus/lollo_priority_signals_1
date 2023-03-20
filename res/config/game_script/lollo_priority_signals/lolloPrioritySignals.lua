
local stateHelpers = require("lollo_priority_signals.stateHelpers")
local workerEngine = require("lollo_priority_signals.workerEngine")
local guiEngine = require("lollo_priority_signals.guiEngine")

-- LOLLO NOTE you can only update the state from the worker thread
-- LOLLO NOTE if this script is inside a subdirectory, fine; otherwise, guiInit() might fire before all has been initialised
stateHelpers.initState()

function data()
    return {
        save = function()
            -- only fires when the worker thread changes the state
            return stateHelpers.saveState()
        end,

        load = function(loadedstate)
            -- fires once in the worker thread, at game load, and many times in the UI thread
            stateHelpers.loadState(loadedstate)
        end,

        update = function()
            workerEngine.update()
        end,

        handleEvent = function(src, id, name, param)
            workerEngine.handleEvent(src, id, name, param)
        end,

        guiHandleEvent = function(id, name, param)
            guiEngine.handleEvent(id, name, param)
        end,

        guiInit = function()
            guiEngine.guiInit()
        end,
    }
end
