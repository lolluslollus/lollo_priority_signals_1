local arrayUtils = require('lollo_priority_signals.arrayUtils')
local constants = require('lollo_priority_signals.constants')
local edgeUtils = require('lollo_priority_signals.edgeUtils')
local guiHelpers = require('lollo_priority_signals.guiHelpers')
local logger = require('lollo_priority_signals.logger')
local signalHelpers = require ("lollo_priority_signals.signalHelpers")
local stateHelpers = require ("lollo_priority_signals.stateHelpers")


-- LOLLO NOTE that the state must be read-only here coz we are in the GUI thread

local  _signalModelId_EraA, _signalModelId_EraC

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

        _signalModelId_EraA = api.res.modelRep.find('railroad/lollo_priority_signals/signal_path_a.mdl')
        _signalModelId_EraC = api.res.modelRep.find('railroad/lollo_priority_signals/signal_path_c.mdl')
    end,
    handleEvent = function(id, name, args)
        if id == 'streetTerminalBuilder' and name == 'builder.apply' then
            logger.print('builder.apply fired with id = streetTerminalBuilder')
            if args and args.proposal and args.proposal.proposal
            and args.proposal.proposal.edgeObjectsToAdd
            and args.proposal.proposal.edgeObjectsToAdd[1]
            and args.proposal.proposal.edgeObjectsToAdd[1].modelInstance
            then
                local modelId = args.proposal.proposal.edgeObjectsToAdd[1].modelInstance.modelId
                if modelId == _signalModelId_EraA or modelId == _signalModelId_EraC then
                    local signalId, edgeId, trackTypeIndex =
                        args.proposal.proposal.edgeObjectsToAdd[1].resultEntity,
                        args.proposal.proposal.edgeObjectsToAdd[1].segmentEntity,
                        args.proposal.proposal.addedSegments[1].trackEdge.trackType
                    logger.print('signalId =') logger.debugPrint(signalId)
                    -- automatically destroy two-way priority signals as soon as they are built
                    if not(signalHelpers.getSignalIsOneWay(signalId)) then
                        _sendScriptEvent(constants.events.removeSignal, {objectId = signalId})
                        -- LOLLO TODO issue a warning to the user
                    -- automatically destroy one-way priority signals built before, if there is a new one on the same edge.
                    else
                        local prioritySignalIdsInEdge = {
                            table.unpack(signalHelpers.getObjectIdsInEdge(edgeId, _signalModelId_EraA)),
                            table.unpack(signalHelpers.getObjectIdsInEdge(edgeId, _signalModelId_EraC))
                        }
                        logger.print('prioritySignalIdsInEdge =') logger.debugPrint(prioritySignalIdsInEdge)
                        if #prioritySignalIdsInEdge > 1 then
                            local objectIdToBeRemoved
                            for _, objectId in pairs(prioritySignalIdsInEdge) do
                                if objectId ~= signalId then
                                    _sendScriptEvent(constants.events.removeSignal, {objectId = objectId})
                                    -- LOLLO TODO issue a warning to the user
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end,
}
