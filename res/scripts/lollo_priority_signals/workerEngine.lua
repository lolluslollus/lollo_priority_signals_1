local logger = require ('lollo_priority_signals.logger')
local arrayUtils = require('lollo_priority_signals.arrayUtils')
local constants = require('lollo_priority_signals.constants')
local constructionConfigs = require('lollo_priority_signals.constructionConfigs')
local edgeUtils = require('lollo_priority_signals.edgeUtils')
local stateHelpers = require('lollo_priority_signals.stateHelpers')
local stationHelpers = require('lollo_priority_signals.stationHelpers')
local transfUtils = require('lollo_priority_signals.transfUtils')
local transfUtilsUG = require('transf')

--[[
    LOLLO NOTE
    useful apis:

    stopCmd = api.cmd.make.setUserStopped(25667, true)
    api.cmd.sendCommand(stopCmd)

    api.engine.system.transportVehicleSystem.getVehicles({edgeId}, true)
    api.engine.system.transportVehicleSystem.getVehicles({edgeId}, false)


]]
local _signalModelId_EraA, _signalModelId_EraC

local _texts = {

}

local _vehicleStates = {
    atTerminal = 2, -- api.type.enum.TransportVehicleState.AT_TERMINAL, -- 2
    enRoute = 1, -- api.type.enum.TransportVehicleState.EN_ROUTE, -- 1
    goingToDepot = 3, -- api.type.enum.TransportVehicleState.GOING_TO_DEPOT, -- 3
    inDepot = 0, -- api.type.enum.TransportVehicleState.IN_DEPOT, -- 0
}

return {
    update = function()
        local state = stateHelpers.getState()
    if not(state.is_on) then return end

    local _time = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_TIME).gameTime
    if not(_time) then logger.err('update() cannot get time') return end

    if math.fmod(_time, constants.refreshPeriodMsec) ~= 0 then
        -- logger.print('skipping')
    return end
    -- logger.print('doing it')

    xpcall(
        function()
            local _startTick = os.clock()

            local _clockTimeSec = math.floor(_time / 1000)
            -- leave if paused
            if _clockTimeSec == state.world_time_sec then return end

            state.world_time_sec = _clockTimeSec

            if not(_signalModelId_EraA) then
                _signalModelId_EraA = api.res.modelRep.find('railroad/lollo_priority_signals/signal_prio_one_way_era_a.mdl')
                _signalModelId_EraC = api.res.modelRep.find('railroad/lollo_priority_signals/signal_prio_one_way_era_c.mdl')
            end



            local executionTime = math.ceil((os.clock() - _startTick) * 1000)
            logger.print('Full update took ' .. executionTime .. 'ms')
        end,
        logger.xpErrorHandler
    )
    end,
    handleEvent = function(src, id, name, args)
        if id ~= constants.eventId then return end

        xpcall(
            function()
                logger.print('handleEvent firing, src =', src, ', id =', id, ', name =', name, ', args =') logger.debugPrint(args)

                if name == constants.events.toggle_notaus then
                    logger.print('state before =') logger.debugPrint(stateHelpers.getState())
                    local state = stateHelpers.getState()
                    state.is_on = not(not(args))
                    logger.print('state after =') logger.debugPrint(stateHelpers.getState())
                end
            end,
            logger.xpErrorHandler
        )
    end,
}
