local arrayUtils = require ('lollo_priority_signals.arrayUtils')
local constants = require('lollo_priority_signals.constants')
local logger = require ('lollo_priority_signals.logger')
local signalHelpers = require('lollo_priority_signals.signalHelpers')
local stateHelpers = require('lollo_priority_signals.stateHelpers')

local  _signalModelId_EraA, _signalModelId_EraC
local _texts = { }

---nodeId, inEdgeId, props
---@type table<integer, table<integer, {isInEdgeDirTowardsIntersection: boolean, priorityEdgeIds: integer[], outerSignalId: integer}>>
local bitsBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId = {}
local bitsBehindIntersection_indexedBy_intersectionNodeId_inEdgeId = {}
---vehicleId, props
---@type table<integer, {gameTimeMsec: number, isStoppedAtOnce: boolean}>
local stopProps_indexedBy_stoppedVehicleIds = {}

local _utils = {
    ---only reliable with trains that are not user-stopped
    ---@param bitsBeforeIntersection_indexedBy_inEdgeId table<integer, { isInEdgeDirTowardsIntersection: boolean, priorityEdgeIds: integer[] }>
    ---@param isGetStoppedVehicles? boolean also get stopped vehicles, useful for testing
    ---@return boolean
    ---@return table<integer, boolean>
    getPriorityVehicleIds = function(bitsBeforeIntersection_indexedBy_inEdgeId, isGetStoppedVehicles)
        logger.print('_getPriorityVehicleIds starting')
        local results_indexed = {}
        local hasRecords = false

        for inEdgeId, bitBeforeIntersection in pairs(bitsBeforeIntersection_indexedBy_inEdgeId) do
            logger.print('inEdgeId = ' .. inEdgeId .. ', bitBeforeIntersection =') logger.debugPrint(bitBeforeIntersection)
            local priorityVehicleIds = api.engine.system.transportVehicleSystem.getVehicles(bitBeforeIntersection.priorityEdgeIds, false)
            for _, vehicleId in pairs(priorityVehicleIds) do
                local movePath = api.engine.getComponent(vehicleId, api.type.ComponentType.MOVE_PATH)
                -- logger.print('vehicleId = ' .. vehicleId .. '; movePath.state = ' .. movePath.state)
                -- logger.print('movePath =') logger.debugPrint(movePath)
                -- if the train has not been stopped (I don't know what enum this is, it is not api.type.enum.TransportVehicleState)
                -- if it is at terminal, the state is 3
                -- if the user stops a train, its movePath will shorten as the train halts, to only include the edges (or expanded nodes) occupied by the train
                if isGetStoppedVehicles or movePath.state ~= 2 then -- this may cause long-lasting gridlocks
                -- if isGetStoppedVehicles or movePath.dyn.speed > 0 then -- this may fail to give priority to the second fast train waiting behind the first
                    for p = movePath.dyn.pathPos.edgeIndex + 1, #movePath.path.edges, 1 do
                        local currentMovePathBit = movePath.path.edges[p]
                        -- logger.print('currentMovePathBit =') logger.debugPrint(currentMovePathBit)
                        if currentMovePathBit.edgeId.entity == inEdgeId then
                            -- return trains heading for the intersection
                            if currentMovePathBit.dir == bitBeforeIntersection.isInEdgeDirTowardsIntersection then
                                results_indexed[vehicleId] = true
                                hasRecords = true
                                logger.print('vehicle ' .. vehicleId .. ' counted coz is heading for the intersection')
                                break
                            -- ignore trains heading out of the intersection
                            else
                                logger.print('vehicle ' .. vehicleId .. ' ignored coz is heading away from the intersection')
                                break
                            end
                        end
                    end
                end
            end
        end
        return hasRecords, results_indexed
    end,
    ---if a train is not user-stopped, this only checks the edges taken up by the train
    ---@param vehicleIds_indexed table<integer, boolean>
    ---@param edgeOrNodeId integer
    ---@return boolean
    isAnyTrainBoundForEdgeOrNode = function(vehicleIds_indexed, edgeOrNodeId)
        local vehicleIdsBoundForEdgeOrNode = api.engine.system.transportVehicleSystem.getVehicles({edgeOrNodeId}, true)
        for _, vehicleId in pairs(vehicleIdsBoundForEdgeOrNode) do
            if vehicleIds_indexed[vehicleId] then
                local movePath = api.engine.getComponent(vehicleId, api.type.ComponentType.MOVE_PATH)
                for p = movePath.dyn.pathPos.edgeIndex + 1, #movePath.path.edges, 1 do
                    if movePath.path.edges[p].edgeId.entity == edgeOrNodeId then
                        -- logger.print('_isAnyTrainBoundForEdgeOrNode about to return true')
                        return true
                    end
                end
            end
        end
        -- logger.print('_isAnyTrainBoundForEdgeOrNode about to return false')
        return false
    end,
    stopAtOnce = function(vehicleId)
        api.cmd.sendCommand(
            api.cmd.make.reverseVehicle(vehicleId),
            function()
                api.cmd.sendCommand(
                    api.cmd.make.setUserStopped(vehicleId, true),
                    api.cmd.sendCommand(api.cmd.make.reverseVehicle(vehicleId))
                )
            end
        )
    end,
    stopSlowly = function(vehicleId)
        api.cmd.sendCommand(api.cmd.make.setUserStopped(vehicleId, true))
    end,
    replaceEdgeWithSameRemovingObject = function(objectIdToRemove)
        logger.print('_replaceEdgeWithSameRemovingObject starting')
        if not(signalHelpers.isValidAndExistingId(objectIdToRemove)) then return end

        logger.print('_replaceEdgeWithSameRemovingObject found, the edge object id is valid')
        local oldEdgeId = api.engine.system.streetSystem.getEdgeForEdgeObject(objectIdToRemove)
        if not(signalHelpers.isValidAndExistingId(oldEdgeId)) then return end

        logger.print('_replaceEdgeWithSameRemovingObject found, the old edge id is valid')
        local oldEdge = api.engine.getComponent(oldEdgeId, api.type.ComponentType.BASE_EDGE)
        local oldEdgeTrack = api.engine.getComponent(oldEdgeId, api.type.ComponentType.BASE_EDGE_TRACK)
        if oldEdge == nil or oldEdgeTrack == nil then return false end

        local newEdge = api.type.SegmentAndEntity.new()
        newEdge.entity = -1
        newEdge.type = 1 -- 0 == road, 1 == rail
        -- newEdge.comp = oldEdge -- not good enough if I want to remove objects, the api moans
        newEdge.comp.node0 = oldEdge.node0
        newEdge.comp.node1 = oldEdge.node1
        newEdge.comp.tangent0 = oldEdge.tangent0
        newEdge.comp.tangent1 = oldEdge.tangent1
        newEdge.comp.type = oldEdge.type -- respect bridge or tunnel
        newEdge.comp.typeIndex = oldEdge.typeIndex -- respect type of bridge or tunnel
        newEdge.playerOwned = api.engine.getComponent(oldEdgeId, api.type.ComponentType.PLAYER_OWNED)
        newEdge.trackEdge = oldEdgeTrack

        if signalHelpers.isValidId(objectIdToRemove) then
            local edgeObjects = {}
            for _, edgeObj in pairs(oldEdge.objects) do
                if edgeObj[1] ~= objectIdToRemove then
                    table.insert(edgeObjects, { edgeObj[1], edgeObj[2] })
                end
            end
            if #edgeObjects > 0 then
                newEdge.comp.objects = edgeObjects -- LOLLO NOTE cannot insert directly into edge0.comp.objects
            end
        else
            logger.print('_replaceEdgeWithSameRemovingObject: objectIdToRemove is no good, it is') logger.debugPrint(objectIdToRemove)
            newEdge.comp.objects = oldEdge.objects
        end

        local proposal = api.type.SimpleProposal.new()
        proposal.streetProposal.edgesToRemove[1] = oldEdgeId
        proposal.streetProposal.edgesToAdd[1] = newEdge
        if signalHelpers.isValidAndExistingId(objectIdToRemove) then
            proposal.streetProposal.edgeObjectsToRemove[1] = objectIdToRemove
        end

        local context = api.type.Context:new()
        -- context.checkTerrainAlignment = true -- default is false, true gives smoother Z
        -- context.cleanupStreetGraph = true -- default is false
        -- context.gatherBuildings = true  -- default is false
        -- context.gatherFields = true -- default is true
        context.player = api.engine.util.getPlayer() -- default is -1

        api.cmd.sendCommand(
            api.cmd.make.buildProposal(proposal, context, true),
            function(result, success)
                logger.print('LOLLO _replaceEdgeWithSameRemovingObject success = ') logger.debugPrint(success)
            end
        )
    end,
}
return {
    update = function()
        local state = stateHelpers.getState()
        if not(state.is_on) then return end

        local _gameTime_msec = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_TIME).gameTime
        if not(_gameTime_msec) then logger.err('update() cannot get time') return end

        xpcall(
            function()
                local _startTick = os.clock()

                local _gameTime_sec = math.floor(_gameTime_msec / 1000)
                -- leave if paused
                if _gameTime_sec == state.world_time_sec then return end
                -- remember game time for next cycle, its only purpose is to leave while paused
                state.world_time_sec = _gameTime_sec

                ---@type table<integer, integer> --signalId, edgeId
                local _edgeObject2EdgeMap = api.engine.system.streetSystem.getEdgeObject2EdgeMap()

                if math.fmod(_gameTime_msec, constants.refreshGraphPeriodMsec) == 0 then
                    --[[
                        LOLLO NOTE one-way lights are read as two-way lights,
                        and they don't appear in the menu if they have no two-way counterparts, or if those counterparts have expired.
                    ]]
                    local allPrioritySignalIds = {
                        table.unpack(signalHelpers.getAllEdgeObjectsWithModelId(_signalModelId_EraA)),
                        table.unpack(signalHelpers.getAllEdgeObjectsWithModelId(_signalModelId_EraC))
                    }
                    logger.print('allPrioritySignalIds =') logger.debugPrint(allPrioritySignalIds)

                    ---@type table<integer, boolean> --signalId, true
                    local prioritySignalIds_indexed = {}
                    for _, signalId in pairs(allPrioritySignalIds) do
                        prioritySignalIds_indexed[signalId] = true -- _edgeObject2EdgeMap[signalId]
                    end
                    logger.print('prioritySignalIds_indexed =') logger.debugPrint(prioritySignalIds_indexed)
                    -- By construction, I cannot have more than one priority signal on any edge.
                    -- However, different priority signals might share the same intersection node,
                    -- so I have a table of tables.
                    bitsBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId = {}

                    local chains_indexedBy_innerSignalId = {}
                    for signalId, _ in pairs(prioritySignalIds_indexed) do
                        local intersectionProps = signalHelpers.getNextIntersectionBehind(signalId, prioritySignalIds_indexed)
                        -- logger.print('signal ' .. signalId .. ' has intersectionProps =') logger.debugPrint(intersectionProps)
                        if intersectionProps.isIntersectionFound then
                            if not(bitsBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId[intersectionProps.nodeId]) then
                                bitsBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId[intersectionProps.nodeId] =
                                {[intersectionProps.inEdgeId] = {
                                    innerSignalId = signalId,
                                    isInEdgeDirTowardsIntersection = intersectionProps.isInEdgeDirTowardsIntersection,
                                    priorityEdgeIds = intersectionProps.priorityEdgeIds,
                                    outerSignalId = signalId,
                                }}
                            elseif not(bitsBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId[intersectionProps.nodeId][intersectionProps.inEdgeId]) then
                                bitsBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId[intersectionProps.nodeId][intersectionProps.inEdgeId] =
                                {
                                    innerSignalId = signalId,
                                    isInEdgeDirTowardsIntersection = intersectionProps.isInEdgeDirTowardsIntersection,
                                    priorityEdgeIds = intersectionProps.priorityEdgeIds,
                                    outerSignalId = signalId,
                                }
                            elseif #intersectionProps.priorityEdgeIds > #bitsBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId[intersectionProps.nodeId][intersectionProps.inEdgeId].priorityEdgeIds then
                                logger.warn('this should never happen: got two sets of intersectionProps, the second has nodeId = ' .. intersectionProps.nodeId .. ' and inEdgeId = ' .. intersectionProps.inEdgeId)
                                bitsBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId[intersectionProps.nodeId][intersectionProps.inEdgeId].priorityEdgeIds = intersectionProps.priorityEdgeIds
                            end
                        -- these stretches of track are chained to others, which are closer to the intersection
                        elseif intersectionProps.isPrioritySignalFound then
                            if not(chains_indexedBy_innerSignalId[intersectionProps.innerSignalId]) then
                                chains_indexedBy_innerSignalId[intersectionProps.innerSignalId] = {
                                    outerSignalId = signalId,
                                    priorityEdgeIds = intersectionProps.priorityEdgeIds,
                                }
                            else
                                logger.warn('this should never happen: got two sets of intersectionProps indexed by the same signalId = ' .. intersectionProps.innerSignalId)
                                arrayUtils.concatValues(chains_indexedBy_innerSignalId[intersectionProps.innerSignalId].priorityEdgeIds, intersectionProps.priorityEdgeIds)
                            end
                        end
                    end
                    logger.print('before attaching the chains, bitsBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId =') logger.debugPrint(bitsBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId)
                    logger.print('chains_indexedBy_innerSignalId starts as') logger.debugPrint(chains_indexedBy_innerSignalId)
                    local count = 0
                    while count < constants.maxNChainedPrioritySignalsBeforeIntersection and arrayUtils.tableHasValues(chains_indexedBy_innerSignalId, true) do
                        for intersectionNodeId, bitsBeforeIntersection_indexedBy_inEdgeId in pairs(bitsBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId) do
                            for inEdgeId, bitBeforeIntersection in pairs(bitsBeforeIntersection_indexedBy_inEdgeId) do
                                local chainsIndex = bitBeforeIntersection.outerSignalId -- write it down coz it gets overwritten in the following
                                local chainedProps = chains_indexedBy_innerSignalId[chainsIndex]
                                if chainedProps ~= nil then
                                    arrayUtils.concatValues(bitsBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId[intersectionNodeId][inEdgeId].priorityEdgeIds, chainedProps.priorityEdgeIds)
                                    bitsBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId[intersectionNodeId][inEdgeId].outerSignalId = chainedProps.outerSignalId
                                    chains_indexedBy_innerSignalId[chainsIndex] = nil
                                end
                            end
                        end
                        count = count + 1
                        logger.print('count = ' .. count .. ', chains_indexedBy_innerSignalId is now') logger.debugPrint(chains_indexedBy_innerSignalId)
                    end
                    logger.print('after attaching the chains, bitsBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId =') logger.debugPrint(bitsBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId)

                    bitsBehindIntersection_indexedBy_intersectionNodeId_inEdgeId = signalHelpers.getNextLightsOrStations(bitsBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId, prioritySignalIds_indexed)
                    logger.print('bitsBehindIntersection_indexedBy_intersectionNodeId_inEdgeId =') logger.debugPrint(bitsBehindIntersection_indexedBy_intersectionNodeId_inEdgeId)

                    if logger.isExtendedLog() then
                        local executionTime = math.ceil((os.clock() - _startTick) * 1000)
                        logger.print('Finding edges and nodes took ' .. executionTime .. 'ms')
                    end
                end -- update graph

                for intersectionNodeId, bitsBeforeIntersection_indexedBy_inEdgeId in pairs(bitsBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId) do
                    logger.print('intersectionNodeId = ' .. intersectionNodeId .. '; bitsBeforeIntersection_indexedBy_inEdgeId =') logger.debugPrint(bitsBeforeIntersection_indexedBy_inEdgeId)
                    local hasIncomingPriorityVehicles, priorityVehicleIds = _utils.getPriorityVehicleIds(bitsBeforeIntersection_indexedBy_inEdgeId)
                    logger.print('priorityVehicleIds =') logger.debugPrint(priorityVehicleIds)
                    if hasIncomingPriorityVehicles then
                        for edgeIdGivingWay, bitBehindIntersection in pairs(bitsBehindIntersection_indexedBy_intersectionNodeId_inEdgeId[intersectionNodeId]) do
                            print('edgeIdGivingWay = ' .. edgeIdGivingWay) -- edgeIdGivingWay = 25624
                            -- avoid gridlocks: do not stop a vehicle that must give way if it is on the path of a priority vehicle - unless that priority vehicle is user-stopped
                            if not(_utils.isAnyTrainBoundForEdgeOrNode(priorityVehicleIds, edgeIdGivingWay))
                            then
                                -- logger.print('no priority trains are bound for edge ' .. edgeIdGivingWay)
                                local vehicleIdsNearGiveWaySignals = api.engine.system.transportVehicleSystem.getVehicles({edgeIdGivingWay}, false)
                                logger.print('vehicleIdsNearGiveWaySignals =') logger.debugPrint(vehicleIdsNearGiveWaySignals)
                                for _, vehicleId in pairs(vehicleIdsNearGiveWaySignals) do
                                    local vehicleIdsOnIntersection = api.engine.system.transportVehicleSystem.getVehicles({intersectionNodeId}, false)
                                    -- avoid gridlocks: do not stop a vehicle that is already on the intersection
                                    if not(arrayUtils.arrayHasValue(vehicleIdsOnIntersection, vehicleId)) then
                                        -- MOVE_PATH and getVehicles change when a train is user-stopped:
                                        -- uncovered edges disappear, so the train fails to meet some estimator below and tries to restart,
                                        -- then the next tick will stop it again - or maybe not.
                                        -- to avoid this lurching, if a train is stopped and is near the give-way signal, we just leave it there
                                        if stopProps_indexedBy_stoppedVehicleIds[vehicleId] ~= nil then
                                            if stopProps_indexedBy_stoppedVehicleIds[vehicleId].isStoppedAtOnce then
                                                -- renew the timestamp
                                                stopProps_indexedBy_stoppedVehicleIds[vehicleId] = {gameTimeMsec = _gameTime_msec, isStoppedAtOnce = true}
                                            else
                                                local vehicleIdsOnLastEdge = api.engine.system.transportVehicleSystem.getVehicles({bitBehindIntersection.inEdgeId}, false)
                                                if arrayUtils.arrayHasValue(vehicleIdsOnLastEdge, vehicleId) then
                                                    -- stop at once if the train is still rolling and on the last edge
                                                    _utils.stopAtOnce(vehicleId)
                                                    logger.print('vehicle ' .. vehicleId .. ' already stopped, now ground to a halt')
                                                    stopProps_indexedBy_stoppedVehicleIds[vehicleId] = {gameTimeMsec = _gameTime_msec, isStoppedAtOnce = true}
                                                else
                                                    -- renew the timestamp
                                                    stopProps_indexedBy_stoppedVehicleIds[vehicleId] = {gameTimeMsec = _gameTime_msec, isStoppedAtOnce = false}
                                                end
                                            end
                                        else
                                            local movePath = api.engine.getComponent(vehicleId, api.type.ComponentType.MOVE_PATH)
                                            for p = movePath.dyn.pathPos.edgeIndex + 1, #movePath.path.edges, 1 do
                                                -- if the train is heading for the intersection, and not merely transiting on the give-way bit...
                                                if movePath.path.edges[p].edgeId.entity == bitBehindIntersection.inEdgeId then
                                                    local vehicleIdsOnLastEdge = api.engine.system.transportVehicleSystem.getVehicles({bitBehindIntersection.inEdgeId}, false)
                                                    if arrayUtils.arrayHasValue(vehicleIdsOnLastEdge, vehicleId) then
                                                        _utils.stopAtOnce(vehicleId)
                                                        logger.print('vehicle ' .. vehicleId .. ' just stopped at once')
                                                        stopProps_indexedBy_stoppedVehicleIds[vehicleId] = {gameTimeMsec = _gameTime_msec, isStoppedAtOnce = true}
                                                    else
                                                        _utils.stopSlowly(vehicleId)
                                                        logger.print('vehicle ' .. vehicleId .. ' just stopped slowly')
                                                        stopProps_indexedBy_stoppedVehicleIds[vehicleId] = {gameTimeMsec = _gameTime_msec, isStoppedAtOnce = false}
                                                    end
                                                    break
                                                end
                                                --     for pp = p, movePath.dyn.pathPos.edgeIndex + 1, -1 do
                                                --         local currentMovePathBit = movePath.path.edges[pp]
                                                --         -- the belly of the train has not passed the intersection yet
                                                --         if currentMovePathBit.edgeId.entity == edgeIdGivingWay then
                                                --             -- stop the train if it is heading for the intersection (probably redundant by now)
                                                --             if currentMovePathBit.dir == bitBehindIntersection.isGiveWayEdgeDirTowardsIntersection then
                                                --                 if not(api.engine.getComponent(vehicleId, api.type.ComponentType.TRANSPORT_VEHICLE).userStopped) then
                                                --                     if isStopAtOnce or (p == pp) then
                                                --                         _utils._stopAtOnce(vehicleId)
                                                --                     else
                                                --                         _utils._stopSlowly(vehicleId)
                                                --                     end
                                                --                     logger.print('vehicle ' .. vehicleId .. ' just stopped')
                                                --                 else
                                                --                     logger.print('vehicle ' .. vehicleId .. ' already stopped')
                                                --                 end
                                                --                 stopProps_indexedBy_stoppedVehicleIds[vehicleId] = _gameTime_msec
                                                --                 break
                                                --             -- ignore trains heading out of the intersection
                                                --             else
                                                --                 logger.print('vehicle ' .. vehicleId .. ' not stopped coz is heading away from the intersection')
                                                --                 break
                                                --             end
                                                --         end
                                                --     end
                                                --     break
                                                -- end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                -- restart vehicles that don't need to wait anymore
                -- LOLLO TODO this thing restarts trains the user has manually stopped: this is no good
                -- I do clean the table, but there is still a while when manually stopped vehicles are restarted automatically.
                logger.print('_gameTime_msec = ' .. tostring(_gameTime_msec) .. '; stopProps_indexedBy_stoppedVehicleIds =') logger.debugPrint(stopProps_indexedBy_stoppedVehicleIds)
                for vehicleId, stopProps in pairs(stopProps_indexedBy_stoppedVehicleIds) do
                    if stopProps ~= nil and stopProps.gameTimeMsec ~= _gameTime_msec then
                        api.cmd.sendCommand(api.cmd.make.setUserStopped(vehicleId, false))
                        logger.print('vehicle ' .. vehicleId .. ' restarted')
                        stopProps_indexedBy_stoppedVehicleIds[vehicleId] = nil
                    end
                end

                if logger.isExtendedLog() then
                    local executionTime = math.ceil((os.clock() - _startTick) * 1000)
                    logger.print('doing all took ' .. executionTime .. 'ms')
                end
            end,
            logger.xpErrorHandler
        )
    end,
    handleEvent = function(src, id, name, args)
        -- if id == 'saveevent' then return end
        -- logger.print('handleEvent caught id = ' .. tostring(id) .. ', name =' .. tostring(name))
        if id ~= constants.eventId then return end

        xpcall(
            function()
                logger.print('handleEvent firing, src =', src, ', id =', id, ', name =', name, ', args =') logger.debugPrint(args)

                if name == constants.events.removeSignal then
                    _utils.replaceEdgeWithSameRemovingObject(args.objectId)
                elseif name == constants.events.toggle_notaus then
                    logger.print('state before =') logger.debugPrint(stateHelpers.getState())
                    local state = stateHelpers.getState()
                    state.is_on = not(not(args))
                    logger.print('state after =') logger.debugPrint(stateHelpers.getState())
                end
            end,
            logger.xpErrorHandler
        )
    end,
    load = function()
        if api.gui ~= nil then return end

        logger.print('workerEngine.load firing')
        _signalModelId_EraA = api.res.modelRep.find('railroad/lollo_priority_signals/signal_path_a.mdl')
        _signalModelId_EraC = api.res.modelRep.find('railroad/lollo_priority_signals/signal_path_c.mdl')
        logger.print('_signalModelId_EraA =') logger.debugPrint(_signalModelId_EraA)
        logger.print('_signalModelId_EraC =') logger.debugPrint(_signalModelId_EraC)
    end,
}
