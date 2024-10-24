local constants = require('lollo_priority_signals.constants')
local guiHelpers = require('lollo_priority_signals.guiHelpers')
local logger = require('lollo_priority_signals.logger')
local signalHelpers = require ("lollo_priority_signals.signalHelpers")
local stateHelpers = require ("lollo_priority_signals.stateHelpers")


-- LOLLO NOTE that the state must be read-only here coz we are in the GUI thread

local  _signalModelId_EraA, _signalModelId_EraC, _signalModelId_Invisible
local _texts = {
    thisIsAPrioritySignal = '',
}

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
        _signalModelId_Invisible = api.res.modelRep.find('railroad/lollo_priority_signals/signal_path_invisible.mdl')
        _texts.thisIsAPrioritySignal = _('ThisIsAPrioritySignal')
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
                if modelId == _signalModelId_EraA or modelId == _signalModelId_EraC or modelId == _signalModelId_Invisible then
                    local newSignalId, edgeId, trackTypeIndex =
                        args.proposal.proposal.edgeObjectsToAdd[1].resultEntity,
                        args.proposal.proposal.edgeObjectsToAdd[1].segmentEntity,
                        args.proposal.proposal.addedSegments[1].trackEdge.trackType
                    logger.print('streetTerminalBuilder - newSignalId =') logger.debugPrint(newSignalId)
                    logger.print('streetTerminalBuilder - edgeId =') logger.debugPrint(edgeId)
                    -- this destroys the other priority signals on the same edge as soon as a second priority signal is added:
                    local prioritySignalIdsInEdge = {
                        table.unpack(signalHelpers.getObjectIdsInEdge(edgeId, _signalModelId_EraA)),
                        table.unpack(signalHelpers.getObjectIdsInEdge(edgeId, _signalModelId_EraC)),
                        table.unpack(signalHelpers.getObjectIdsInEdge(edgeId, _signalModelId_Invisible)),
                    }
                    logger.print('streetTerminalBuilder - prioritySignalIdsInEdge =') logger.debugPrint(prioritySignalIdsInEdge)
                    if #prioritySignalIdsInEdge > 1 then
                        local objectIdToBeRemoved
                        for _, objectId in pairs(prioritySignalIdsInEdge) do
                            if objectId ~= newSignalId then
                                _sendScriptEvent(constants.events.removeSignal, {objectId = objectId})
                                -- LOLLO TODO issue a warning to the user
                                break
                            end
                        end
                    end
                end
            end
        elseif (name == 'select' and id == 'mainView') then
            logger.print('guiHandleEvent caught id =', id, 'name =', name, 'args =') logger.debugPrint(args)
            local objectId = args
            if not(signalHelpers.isValidAndExistingId(objectId)) then return end

            local signalList = api.engine.getComponent(objectId, api.type.ComponentType.SIGNAL_LIST)
            if not(signalList) then return end

            if not(signalHelpers.isEdgeObjectIdWithModelIds(objectId, _signalModelId_EraA, _signalModelId_EraC, _signalModelId_Invisible)) then return end

            local windowId = 'temp.view.entity_' .. objectId
            local window = api.gui.util.getById(windowId)
            if not(window) then return end

            local newItemId = 'thisIsAPrioritySignal_' .. objectId
            if api.gui.util.getById(newItemId) ~= nil then return end

            local windowLayout = window:getLayout()
            local newItem = api.gui.layout.BoxLayout.new('HORIZONTAL')
            newItem:addItem(api.gui.comp.TextView.new(_texts.thisIsAPrioritySignal))
            newItem:addItem(api.gui.comp.ImageView.new('ui/lollo_priority_signals/priority_signal.tga'))
            newItem:setId(newItemId)
            windowLayout:addItem(newItem)
        -- else
        --     logger.print('guiHandleEvent caught id = ' .. tostring(id) .. ', name =' .. tostring(name))
        end
    end,
}
