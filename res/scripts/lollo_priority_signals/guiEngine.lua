local constructionConfigs = require ("lollo_priority_signals.constructionConfigs")
local constants = require('lollo_priority_signals.constants')
local edgeUtils = require('lollo_priority_signals.edgeUtils')
local guiHelpers = require('lollo_priority_signals.guiHelpers')
local logger = require('lollo_priority_signals.logger')
local stateHelpers = require ("lollo_priority_signals.stateHelpers")
local stationHelpers = require('lollo_priority_signals.stationHelpers')
local transfUtils = require('lollo_priority_signals.transfUtils')
local transfUtilsUG = require('transf')


-- LOLLO NOTE that the state must be read-only here coz we are in the GUI thread

local _guiSignalModelId_EraA, _guiSignalModelId_EraC

local function _sendScriptEvent(name, args)
    api.cmd.sendCommand(api.cmd.make.sendScriptEvent(
        string.sub(debug.getinfo(1, 'S').source, 1), constants.eventId, name, args)
    )
end

return {
    guiInit = function()
        local _state = stateHelpers.getState()
        if not(_state) then
            logger.err('cannot read state at guiInit')
            return
        end

        guiHelpers.initNotausButton(
            _state.is_on,
            function(isOn)
                _sendScriptEvent(constants.events.toggle_notaus, isOn)
            end
        )

        _guiSignalModelId_EraA = api.res.modelRep.find('railroad/lollo_priority_signals/signal_prio_one_way_era_a.mdl')
        _guiSignalModelId_EraC = api.res.modelRep.find('railroad/lollo_priority_signals/signal_prio_one_way_era_c.mdl')
    end,
    -- probably useless, I am going to search for prio signals every 5 sec or so
    handleEvent = function(id, name, args)
        if id == 'streetTerminalBuilder' and name == 'builder.apply' then
            if args and args.proposal and args.proposal.proposal
            and args.proposal.proposal.edgeObjectsToAdd
            and args.proposal.proposal.edgeObjectsToAdd[1]
            and args.proposal.proposal.edgeObjectsToAdd[1].modelInstance
            then
                local modelId = args.proposal.proposal.edgeObjectsToAdd[1].modelInstance.modelId
                if modelId == _guiSignalModelId_EraA or modelId == _guiSignalModelId_EraC then
                    local signalId, edgeId, trackTypeIndex = args.proposal.proposal.edgeObjectsToAdd[1].resultEntity,
                        args.proposal.proposal.edgeObjectsToAdd[1].segmentEntity,
                        args.proposal.proposal.addedSegments[1].trackEdge.trackType
                end
            end
        end
    end,
}
