local logger = require ('lollo_priority_signals.logger')
local constants = require('lollo_priority_signals.constants')
local edgeUtils = require('lollo_priority_signals.edgeUtils')
local signalHelpers = require('lollo_priority_signals.signalHelpers')
local stateHelpers = require('lollo_priority_signals.stateHelpers')

local  _signalModelId_EraA, _signalModelId_EraC
local _texts = { }

local nodeEdgeBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId = {}
local nodeEdgeBehindIntersection_indexedBy_intersectionNodeId_inEdgeId = {}
local stopGameTimes_indexedBy_stoppedVehicleIds = {}

local _utils = {
    -- -@param nodeEdgeBeforeIntersection_indexedBy_inEdgeId table<integer, { isPriorityEdgeDirTowardsIntersection: boolean, farthestPriorityEdgeId: integer, signalId: integer }>
    -- -@return boolean
    -- -@return table<integer, boolean>
    -- _getVehicleIdsNearPrioritySignals = function(nodeEdgeBeforeIntersection_indexedBy_inEdgeId)
    --     logger.print('_getVehicleIdsNearPrioritySignals starting')
    --     local results_indexed = {}
    --     local hasRecords = false

    --     for inEdgeId, nodeEdgeBeforeIntersection in pairs(nodeEdgeBeforeIntersection_indexedBy_inEdgeId) do
    --         logger.print('inEdgeId = ' .. inEdgeId .. ', nodeEdgeBeforeIntersection =') logger.debugPrint(nodeEdgeBeforeIntersection)
    --         local edgeIds = nodeEdgeBeforeIntersection.farthestPriorityEdgeId == inEdgeId
    --             and {inEdgeId}
    --             or {nodeEdgeBeforeIntersection.farthestPriorityEdgeId, inEdgeId}
    --         logger.print('edgeIds for detecting priority trains =') logger.debugPrint(edgeIds)
    --         -- in the following, false means "only occupied now", true means "occupied nor or soon"
    --         -- "soon" means "since a vehicle left the last station and before it reaches the next"
    --         local priorityVehicleIds = api.engine.system.transportVehicleSystem.getVehicles(edgeIds, false)
    --         for _, vehicleId in pairs(priorityVehicleIds) do
    --             results_indexed[vehicleId] = true
    --             hasRecords = true
    --         end
    --     end
    --     return hasRecords, results_indexed
    -- end,

    ---@param nodeEdgeBeforeIntersection_indexedBy_inEdgeId table<integer, { isPriorityEdgeDirTowardsIntersection: boolean, farthestPriorityEdgeId: integer, signalId: integer }>
    ---@param isGetStoppedVehicles? boolean also get stopped vehicles, useful for testing
    ---@return boolean
    ---@return table<integer, boolean>
    _getPriorityVehicleIds = function(nodeEdgeBeforeIntersection_indexedBy_inEdgeId, isGetStoppedVehicles)
        logger.print('_getPriorityVehicleIds starting')
        local results_indexed = {}
        local hasRecords = false

        for inEdgeId, nodeEdgeBeforeIntersection in pairs(nodeEdgeBeforeIntersection_indexedBy_inEdgeId) do
            logger.print('inEdgeId = ' .. inEdgeId .. ', nodeEdgeBeforeIntersection =') logger.debugPrint(nodeEdgeBeforeIntersection)
            local edgeIds = nodeEdgeBeforeIntersection.farthestPriorityEdgeId == inEdgeId
                and {inEdgeId}
                or {nodeEdgeBeforeIntersection.farthestPriorityEdgeId, inEdgeId}
            logger.print('edgeIds for detecting priority trains =') logger.debugPrint(edgeIds)
            -- in the following, false means "only occupied now", true means "occupied nor or soon"
            -- "soon" means "since a vehicle left the last station and before it reaches the next"
            local priorityVehicleIds = api.engine.system.transportVehicleSystem.getVehicles(edgeIds, false)
            for _, vehicleId in pairs(priorityVehicleIds) do
                local movePath = api.engine.getComponent(vehicleId, api.type.ComponentType.MOVE_PATH)
                -- if the train has not been stopped (I don't know what enum this is, it is not api.type.enum.TransportVehicleState)
                if logger.isTestMode() or isGetStoppedVehicles or movePath.state ~= 2 then
                    for p = movePath.dyn.pathPos.edgeIndex + 1, #movePath.path.edges, 1 do
                        local currentMovePathBit = movePath.path.edges[p]
                        if currentMovePathBit.edgeId.entity == inEdgeId then
                            -- return trains heading for the intersection
                            if currentMovePathBit.dir == nodeEdgeBeforeIntersection.isPriorityEdgeDirTowardsIntersection then
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
    _isAnyTrainBoundForEdgeOrNode = function(vehicleIds_indexed, edgeOrNodeId)
        -- in the following, false means "only occupied now", true means "occupied nor or soon"
        -- "soon" means "since a vehicle left the last station and before it reaches the next"
        -- It works with edges and with intersection nodes.
        local vehicleIdsBoundForEdgeOrNode = api.engine.system.transportVehicleSystem.getVehicles({edgeOrNodeId}, true)
        for _, vehicleId in pairs(vehicleIdsBoundForEdgeOrNode) do
            if vehicleIds_indexed[vehicleId] then
                local movePath = api.engine.getComponent(vehicleId, api.type.ComponentType.MOVE_PATH)
                for p = movePath.dyn.pathPos.edgeIndex + 1, #movePath.path.edges, 1 do
                    local currentMovePathBit = movePath.path.edges[p]
                    if currentMovePathBit.edgeId.entity == edgeOrNodeId then
                        logger.print('_isAnyTrainBoundForEdgeOrNode about to return true')
                        return true
                    end
                end
            end
        end
        logger.print('_isAnyTrainBoundForEdgeOrNode about to return false')
        return false
    end,
    replaceEdgeWithSameRemovingObject = function(objectIdToRemove)
        logger.print('_replaceEdgeWithSameRemovingObject starting')
        if not(edgeUtils.isValidAndExistingId(objectIdToRemove)) then return end

        logger.print('_replaceEdgeWithSameRemovingObject found, the edge object id is valid')
        local oldEdgeId = api.engine.system.streetSystem.getEdgeForEdgeObject(objectIdToRemove)
        if not(edgeUtils.isValidAndExistingId(oldEdgeId)) then return end

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

        if edgeUtils.isValidId(objectIdToRemove) then
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
            logger.print('replaceEdgeWithSameRemovingObject: objectIdToRemove is no good, it is') logger.debugPrint(objectIdToRemove)
            newEdge.comp.objects = oldEdge.objects
        end

        local proposal = api.type.SimpleProposal.new()
        proposal.streetProposal.edgesToRemove[1] = oldEdgeId
        proposal.streetProposal.edgesToAdd[1] = newEdge
        if edgeUtils.isValidAndExistingId(objectIdToRemove) then
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
                    local era_a_signalIds = signalHelpers.getAllEdgeObjectsWithModelId(_signalModelId_EraA)
                    local era_c_signalIds = signalHelpers.getAllEdgeObjectsWithModelId(_signalModelId_EraC)
                    logger.print('era_a_signalIds =') logger.debugPrint(era_a_signalIds)
                    logger.print('era_c_signalIds =') logger.debugPrint(era_c_signalIds)
                    local allPrioritySignalIds = {
                        table.unpack(era_a_signalIds),
                        table.unpack(era_c_signalIds)
                    }
                    logger.print('allPrioritySignalIds =') logger.debugPrint(allPrioritySignalIds)

                    ---@type table<integer, integer> --signalId, edgeId
                    local edgeIdsWithPrioritySignals_indexedBy_signalId = {}
                    -- By construction, I cannot have more than one priority signal on any edge.
                    -- However, different priority signals might share the same intersection node,
                    -- so I have a table of tables.
                    -- nodeId, inEdgeId, props
                    ---@type table<integer, table<integer, {isPriorityEdgeDirTowardsIntersection: boolean, farthestPriorityEdgeId: integer, signalId: integer}>>
                    nodeEdgeBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId = {}
                    for _, signalId in pairs(allPrioritySignalIds) do
                        edgeIdsWithPrioritySignals_indexedBy_signalId[signalId] = _edgeObject2EdgeMap[signalId]
                        local intersectionProps = signalHelpers.getNextIntersectionBehind(signalId)
                        -- logger.print('signal ' .. signalId .. ' has intersectionProps =') logger.debugPrint(intersectionProps)
                        if intersectionProps.isFound then
                            if not(nodeEdgeBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId[intersectionProps.nodeId]) then
                                nodeEdgeBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId[intersectionProps.nodeId] =
                                {[intersectionProps.inEdgeId] = {
                                    isPriorityEdgeDirTowardsIntersection = intersectionProps.isPriorityEdgeDirTowardsIntersection,
                                    farthestPriorityEdgeId = intersectionProps.farthestPriorityEdgeId,
                                    signalId = signalId
                                }}
                            else
                                nodeEdgeBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId[intersectionProps.nodeId][intersectionProps.inEdgeId] =
                                {
                                    isPriorityEdgeDirTowardsIntersection = intersectionProps.isPriorityEdgeDirTowardsIntersection,
                                    farthestPriorityEdgeId = intersectionProps.farthestPriorityEdgeId,
                                    signalId = signalId
                                }
                            end
                        end
                    end
                    logger.print('nodeEdgeBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId =') logger.debugPrint(nodeEdgeBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId)
                    logger.print('edgeIdsWithPrioritySignals_indexedBy_signalId =') logger.debugPrint(edgeIdsWithPrioritySignals_indexedBy_signalId)

                    nodeEdgeBehindIntersection_indexedBy_intersectionNodeId_inEdgeId = signalHelpers.getNextLightsOrStations(nodeEdgeBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId, edgeIdsWithPrioritySignals_indexedBy_signalId)
                    logger.print('nodeEdgeBehindIntersection_indexedBy_intersectionNodeId_inEdgeId =') logger.debugPrint(nodeEdgeBehindIntersection_indexedBy_intersectionNodeId_inEdgeId)

                    if logger.isExtendedLog() then
                        local executionTime = math.ceil((os.clock() - _startTick) * 1000)
                        logger.print('Finding edges and nodes took ' .. executionTime .. 'ms')
                    end
                end -- update graph

                for intersectionNodeId, nodeEdgeBeforeIntersection_indexedBy_inEdgeId in pairs(nodeEdgeBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId) do
                    logger.print('intersectionNodeId = ' .. intersectionNodeId .. '; nodeEdgeBeforeIntersection_indexedBy_inEdgeId =') logger.debugPrint(nodeEdgeBeforeIntersection_indexedBy_inEdgeId)
                    -- this assumes one-way priority signals
                    -- local hasPriorityVehicles, priorityVehicleIds = _getVehicleIdsNearPrioritySignals(nodeEdgeBeforeIntersection_indexedBy_inEdgeId)
                    -- this should work with two-way priority signals
                    local hasPriorityVehicles, priorityVehicleIds = _utils._getPriorityVehicleIds(nodeEdgeBeforeIntersection_indexedBy_inEdgeId)
                    logger.print('priorityVehicleIds =') logger.debugPrint(priorityVehicleIds)
                    if hasPriorityVehicles then
                        for edgeIdGivingWay, nodeEdgeBehindIntersection in pairs(nodeEdgeBehindIntersection_indexedBy_intersectionNodeId_inEdgeId[intersectionNodeId]) do
                            -- avoid gridlocks: do not stop a vehicle that must give way if it is on the path of a priority vehicle
                            if not(_utils._isAnyTrainBoundForEdgeOrNode(priorityVehicleIds, edgeIdGivingWay))
                            -- LOLLO TODO if I have a cross, I should check the nodes, the edges won't do. Check if the following works.
                            and not(_utils._isAnyTrainBoundForEdgeOrNode(priorityVehicleIds, nodeEdgeBehindIntersection.nodeIdTowardsIntersection))
                            then
                                logger.print('no trains are bound for edge ' .. edgeIdGivingWay .. ' or node ' .. nodeEdgeBehindIntersection.nodeIdTowardsIntersection)
                                -- in the following, false means "only occupied now", true means "occupied nor or soon"
                                -- "soon" means "since a vehicle left the last station and before it reaches the next"
                                local vehicleIdsNearGiveWaySignals = api.engine.system.transportVehicleSystem.getVehicles({edgeIdGivingWay}, false)
                                logger.print('vehicleIdsNearGiveWaySignals =') logger.debugPrint(vehicleIdsNearGiveWaySignals)
                                for _, vehicleId in pairs(vehicleIdsNearGiveWaySignals) do
                                    local movePath = api.engine.getComponent(vehicleId, api.type.ComponentType.MOVE_PATH)
                                    for p = movePath.dyn.pathPos.edgeIndex + 1, #movePath.path.edges, 1 do
                                        local currentMovePathBit = movePath.path.edges[p]
                                        if currentMovePathBit.edgeId.entity == edgeIdGivingWay then
                                            -- stop trains heading for the intersection
                                            if currentMovePathBit.dir == nodeEdgeBehindIntersection.isGiveWayEdgeDirTowardsIntersection then
                                                if not(api.engine.getComponent(vehicleId, api.type.ComponentType.TRANSPORT_VEHICLE).userStopped) then
                                                    -- api.cmd.sendCommand(api.cmd.make.reverseVehicle(vehicleId)) -- this is to stop it at once
                                                    api.cmd.sendCommand(api.cmd.make.setUserStopped(vehicleId, true))
                                                    -- api.cmd.sendCommand(api.cmd.make.reverseVehicle(vehicleId)) -- this is to stop it at once
                                                    logger.print('vehicle ' .. vehicleId .. ' just stopped')
                                                else
                                                    logger.print('vehicle ' .. vehicleId .. ' already stopped')
                                                end
                                                stopGameTimes_indexedBy_stoppedVehicleIds[vehicleId] = _gameTime_msec
                                                break
                                            -- ignore trains heading out of the intersection
                                            else
                                                logger.print('vehicle ' .. vehicleId .. ' not stopped coz is heading away from the intersection')
                                                break
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
                logger.print('_gameTime_msec = ' .. tostring(_gameTime_msec) .. '; stopGameTimes_indexedBy_stoppedVehicleIds =') logger.debugPrint(stopGameTimes_indexedBy_stoppedVehicleIds)
                for vehicleId, gameTimeMsec in pairs(stopGameTimes_indexedBy_stoppedVehicleIds) do
                    if gameTimeMsec ~= _gameTime_msec then
                        api.cmd.sendCommand(api.cmd.make.setUserStopped(vehicleId, false))
                        logger.print('vehicle ' .. vehicleId .. ' restarted')
                        stopGameTimes_indexedBy_stoppedVehicleIds[vehicleId] = nil
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
