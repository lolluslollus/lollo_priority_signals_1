local arrayUtils = require ('lollo_priority_signals.arrayUtils')
local constants = require('lollo_priority_signals.constants')
local logger = require ('lollo_priority_signals.logger')
local signalHelpers = require('lollo_priority_signals.signalHelpers')
local stateHelpers = require('lollo_priority_signals.stateHelpers')

---@type integer
local _mSignalModelId_EraA
---@type integer
local _mSignalModelId_EraC
---@type table<string, string>
local _mTexts = { }
---@type integer
local _mGameTime_msec = 0
---@type integer
local _mLastGameTime_msec = 0
---@type integer
local _mLastRefreshGraph_msec = 0

---@type bitsBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId
local _mBitsBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId = {}
---@type bitsBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay
local _mBitsBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay = {}
---@type table<integer, integer[]>
local _mInEdgeIdsBehindIntersections_indexedBy_edgeIdGivingWay = {}
---@type table<integer, integer[]>
local _mIntersectionNodeIds_indexedBy_edgeIdGivingWay = {}
---@type table<integer, {gameTimeMsec: number, isStoppedAtOnce: boolean}>
local _mStopProps_indexedBy_stoppedVehicleIds = {}

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
            -- logger.print('inEdgeId = ' .. inEdgeId .. ', bitBeforeIntersection =') logger.debugPrint(bitBeforeIntersection)
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

local _mGetGraphCoroutine, _mStartStopTrainsCoroutine
local _actions = {
    updateGraph = function()
        local _startTick_sec = os.clock()
        logger.print('< ## _mGetGraphCoroutine - start updating graph at ' .. tostring(_startTick_sec) .. ' sec')
        -- ---@type table<integer, integer> --signalId, edgeId
        -- local _edgeObject2EdgeMap = api.engine.system.streetSystem.getEdgeObject2EdgeMap()

        --[[
            LOLLO NOTE one-way lights are read as two-way lights,
            and they don't appear in the menu if they have no two-way counterparts, or if those counterparts have expired.
        ]]
        local allPrioritySignalIds = {
            table.unpack(signalHelpers.getAllEdgeObjectsWithModelId(_mSignalModelId_EraA)),
            table.unpack(signalHelpers.getAllEdgeObjectsWithModelId(_mSignalModelId_EraC))
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
        local bitsBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId = {}

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
            coroutine.yield()
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
        coroutine.yield()

        local bitsBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay = signalHelpers.getGiveWaySignalsOrStations(bitsBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId, prioritySignalIds_indexed)
        logger.print('bitsBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay =') logger.debugPrint(bitsBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay)
        local inEdgeIdsBehindIntersections_indexedBy_edgeIdGivingWay = {}
        local intersectionNodeIds_indexedBy_edgeIdGivingWay = {}
        for intersectionNodeId, bitsBehindIntersection_indexedBy_edgeIdGivingWay in pairs(bitsBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay) do
            for edgeIdGivingWay, bitBehindIntersection in pairs(bitsBehindIntersection_indexedBy_edgeIdGivingWay) do
                if not(inEdgeIdsBehindIntersections_indexedBy_edgeIdGivingWay[edgeIdGivingWay]) then
                    inEdgeIdsBehindIntersections_indexedBy_edgeIdGivingWay[edgeIdGivingWay] = {bitBehindIntersection.inEdgeId}
                else
                    table.insert(inEdgeIdsBehindIntersections_indexedBy_edgeIdGivingWay[edgeIdGivingWay], bitBehindIntersection.inEdgeId)
                end

                if not(intersectionNodeIds_indexedBy_edgeIdGivingWay[edgeIdGivingWay]) then
                    intersectionNodeIds_indexedBy_edgeIdGivingWay[edgeIdGivingWay] = {intersectionNodeId}
                else
                    table.insert(intersectionNodeIds_indexedBy_edgeIdGivingWay[edgeIdGivingWay], intersectionNodeId)
                end
            end
        end
        logger.print('inEdgeIdsBehindIntersections_indexedBy_edgeIdGivingWay =') logger.debugPrint(inEdgeIdsBehindIntersections_indexedBy_edgeIdGivingWay)
        logger.print('intersectionNodeIds_indexedBy_edgeIdGivingWay =') logger.debugPrint(intersectionNodeIds_indexedBy_edgeIdGivingWay)

        -- only change these shared variables when the coroutine that needs them is inactive
        while _mStartStopTrainsCoroutine ~= nil and coroutine.status(_mStartStopTrainsCoroutine) ~= 'dead' do
            logger.print('_mStartStopTrainsCoroutine is not dead, waiting')
            coroutine.yield()
        end

        if logger.isExtendedLog() then
            if _mStartStopTrainsCoroutine == nil then
                logger.print('_mStartStopTrainsCoroutine is nil, about to update shared variables')
            else
                logger.print('_mStartStopTrainsCoroutine is ' .. coroutine.status(_mStartStopTrainsCoroutine) .. ', about to update shared variables')
            end
        end

        _mBitsBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId = bitsBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId
        _mBitsBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay = bitsBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay
        _mInEdgeIdsBehindIntersections_indexedBy_edgeIdGivingWay = inEdgeIdsBehindIntersections_indexedBy_edgeIdGivingWay
        _mIntersectionNodeIds_indexedBy_edgeIdGivingWay = intersectionNodeIds_indexedBy_edgeIdGivingWay
        _mLastRefreshGraph_msec = _mGameTime_msec

        if logger.isExtendedLog() then
            local executionTime_msec = math.ceil((os.clock() - _startTick_sec) * 1000)
            logger.print('> ## _mGetGraphCoroutine - Updating graph took ' .. executionTime_msec .. ' msec')
        end
    end,
    startStopTrains = function()
        local _startTick_sec = os.clock()
        logger.print('< ## _mStartStopTrainsCoroutine - start work at ' .. tostring(_startTick_sec) .. ' sec')
        -- error('test error') -- What happens if an error occurs in the coroutine? It dies!
        for intersectionNodeId, bitsBeforeIntersection_indexedBy_inEdgeId in pairs(_mBitsBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId) do
            local hasIncomingPriorityVehicles, incomingPriorityVehicleIds = _utils.getPriorityVehicleIds(bitsBeforeIntersection_indexedBy_inEdgeId)
            if logger.isExtendedLog() then
                logger.print('intersectionNodeId = ' .. intersectionNodeId .. '; bitsBeforeIntersection_indexedBy_inEdgeId =') logger.debugPrint(bitsBeforeIntersection_indexedBy_inEdgeId)
                logger.print('incomingPriorityVehicleIds =') logger.debugPrint(incomingPriorityVehicleIds)
            end
            if hasIncomingPriorityVehicles then
                for edgeIdGivingWay, bitBehindIntersection in pairs(_mBitsBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay[intersectionNodeId]) do
                    if logger.isExtendedLog() then
                        logger.print('edgeIdGivingWay = ' .. edgeIdGivingWay)
                        logger.print('bitBehindIntersection = ') logger.debugPrint(bitBehindIntersection)
                    end
                    -- avoid gridlocks: do not stop a slow vehicle if it is on the path of a priority vehicle - unless that priority vehicle is user-stopped
                    if not(_utils.isAnyTrainBoundForEdgeOrNode(incomingPriorityVehicleIds, edgeIdGivingWay))
                    then
                        -- logger.print('no priority trains are bound for edge ' .. edgeIdGivingWay)
                        local vehicleIdsNearGiveWaySignals = api.engine.system.transportVehicleSystem.getVehicles({edgeIdGivingWay}, false)
                        logger.print('vehicleIdsNearGiveWaySignals =') logger.debugPrint(vehicleIdsNearGiveWaySignals)
                        for _, vehicleId in pairs(vehicleIdsNearGiveWaySignals) do
                            -- local vehicleIdsOnIntersection = api.engine.system.transportVehicleSystem.getVehicles({intersectionNodeId}, false)
                            local vehicleIdsOnAnyNearbyIntersection = api.engine.system.transportVehicleSystem.getVehicles(_mIntersectionNodeIds_indexedBy_edgeIdGivingWay[edgeIdGivingWay], false)
                            -- avoid gridlocks: do not stop a vehicle that is already on any intersection where edgeIdGivingWay plays a role
                            if not(arrayUtils.arrayHasValue(vehicleIdsOnAnyNearbyIntersection, vehicleId)) then
                                -- MOVE_PATH and getVehicles change when a train is user-stopped:
                                -- uncovered edges disappear, so the train fails to meet some estimator below and tries to restart,
                                -- then the next tick will stop it again - or maybe not.
                                -- to avoid this lurching, if a train is stopped and is near the give-way signal, we just leave it there
                                if _mStopProps_indexedBy_stoppedVehicleIds[vehicleId] ~= nil then
                                    if _mStopProps_indexedBy_stoppedVehicleIds[vehicleId].isStoppedAtOnce then
                                        -- renew the timestamp
                                        _mStopProps_indexedBy_stoppedVehicleIds[vehicleId] = {gameTimeMsec = _mGameTime_msec, isStoppedAtOnce = true}
                                    else
                                        -- there could be multiple intersections where the same edge has different roles: check them all
                                        local vehicleIdsOnLastEdge = api.engine.system.transportVehicleSystem.getVehicles(
                                            _mInEdgeIdsBehindIntersections_indexedBy_edgeIdGivingWay[edgeIdGivingWay],
                                            false
                                        )
                                        if arrayUtils.arrayHasValue(vehicleIdsOnLastEdge, vehicleId) then
                                            -- stop at once if the train is still rolling and on any last edge before any intersection
                                            _utils.stopAtOnce(vehicleId)
                                            logger.print('vehicle ' .. vehicleId .. ' already stopped, now ground to a halt')
                                            _mStopProps_indexedBy_stoppedVehicleIds[vehicleId] = {gameTimeMsec = _mGameTime_msec, isStoppedAtOnce = true}
                                        else
                                            -- renew the timestamp
                                            _mStopProps_indexedBy_stoppedVehicleIds[vehicleId] = {gameTimeMsec = _mGameTime_msec, isStoppedAtOnce = false}
                                        end
                                    end
                                else
                                    local movePath = api.engine.getComponent(vehicleId, api.type.ComponentType.MOVE_PATH)
                                    for p = movePath.dyn.pathPos.edgeIndex + 1, #movePath.path.edges, 1 do
                                        -- if the train is heading for the intersection, and not merely transiting on the give-way bit...
                                        local currentMovePathBit = movePath.path.edges[p]
                                        if currentMovePathBit.edgeId.entity == bitBehindIntersection.inEdgeId then
                                            logger.print('bitBehindIntersection.inEdgeId = ' .. bitBehindIntersection.inEdgeId)
                                            -- stop the train if it is heading for any intersection, possibly redundant by now
                                            if currentMovePathBit.dir == bitBehindIntersection.isInEdgeDirTowardsIntersection then
                                                -- there could be multiple intersections where the same edge has different roles: check them all
                                                local vehicleIdsOnLastEdge = api.engine.system.transportVehicleSystem.getVehicles(
                                                    _mInEdgeIdsBehindIntersections_indexedBy_edgeIdGivingWay[edgeIdGivingWay],
                                                    false
                                                )
                                                if arrayUtils.arrayHasValue(vehicleIdsOnLastEdge, vehicleId) then
                                                    -- stop at once if the train is still rolling and on any last edge before any intersection
                                                    _utils.stopAtOnce(vehicleId)
                                                    logger.print('vehicle ' .. vehicleId .. ' just stopped at once')
                                                    _mStopProps_indexedBy_stoppedVehicleIds[vehicleId] = {gameTimeMsec = _mGameTime_msec, isStoppedAtOnce = true}
                                                else
                                                    _utils.stopSlowly(vehicleId)
                                                    logger.print('vehicle ' .. vehicleId .. ' just stopped slowly')
                                                    _mStopProps_indexedBy_stoppedVehicleIds[vehicleId] = {gameTimeMsec = _mGameTime_msec, isStoppedAtOnce = false}
                                                end
                                                break
                                            else
                                                break
                                            end
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
                                        --                 stopProps_indexedBy_stoppedVehicleIds[vehicleId] = _mGameTime_msec
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
            coroutine.yield()
        end
        -- restart vehicles that don't need to wait anymore
        -- LOLLO TODO this thing restarts trains the user has manually stopped: this is no good
        -- I do clean the table, but there is still a while when manually stopped vehicles are restarted automatically.
        -- The solution is crude: manually unstop the vehicle multiple times until it reaches an intersection, where it will drive on on its own.
        logger.print('_mGameTime_msec = ' .. tostring(_mGameTime_msec) .. '; stopProps_indexedBy_stoppedVehicleIds =') logger.debugPrint(_mStopProps_indexedBy_stoppedVehicleIds)
        for vehicleId, stopProps in pairs(_mStopProps_indexedBy_stoppedVehicleIds) do
            if stopProps ~= nil and stopProps.gameTimeMsec ~= _mGameTime_msec then
                api.cmd.sendCommand(api.cmd.make.setUserStopped(vehicleId, false))
                logger.print('vehicle ' .. vehicleId .. ' restarted')
                _mStopProps_indexedBy_stoppedVehicleIds[vehicleId] = nil
            end
        end

        if logger.isExtendedLog() then
            local executionTime_msec = math.ceil((os.clock() - _startTick_sec) * 1000)
            logger.print('> ## _mStartStopTrainsCoroutine - work took ' .. executionTime_msec .. ' msec')
        end
    end,
}

return {
    -- this can fire a handful times per second
    update = function()
        local state = stateHelpers.getState()
        if not(state.is_on) then return end

        -- logger.print('#### workerEngine.update() starting at ' .. tostring(os.clock()) .. ' sec')

        _mGameTime_msec = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_TIME).gameTime
        if not(_mGameTime_msec) then logger.err('update() cannot get time') return end

        if _mGameTime_msec ~= _mLastGameTime_msec then -- skip if paused, LOLLO TODO you can make it work while paused if you compare os.clock() instead of gameTime
            logger.print('_mGameTime_msec = ' .. tostring(_mGameTime_msec) .. ', _mLastRefreshGraph_msec = ' .. tostring(_mLastRefreshGraph_msec))
            if _mGetGraphCoroutine == nil
            or (
                coroutine.status(_mGetGraphCoroutine) == 'dead'
                and _mGameTime_msec - _mLastRefreshGraph_msec > constants.refreshGraphPauseMsec -- wait a bit before recalculating the graph
                and ( -- let startStopTrains run through before recalculating the graph
                    _mStartStopTrainsCoroutine == nil
                    or coroutine.status(_mStartStopTrainsCoroutine) == 'dead'
                )
            )
            then
                _mGetGraphCoroutine = coroutine.create(_actions.updateGraph)
                logger.print('_mGetGraphCoroutine created')
            end
            for _ = 1, constants.numGetGraphCoroutineResumesPerTick, 1 do
                if coroutine.status(_mGetGraphCoroutine) ~= 'dead' then
                    local isSuccess, error = coroutine.resume(_mGetGraphCoroutine)
                    -- if an error occurs in the coroutine, it dies.
                    if isSuccess then
                        logger.print('_mGetGraphCoroutine resumed OK')
                    else
                        logger.warn('_mGetGraphCoroutine resumed with error') logger.warningDebugPrint(error)
                    end
                else -- leave it dead for this tick, everything else will have more resources to run through
                    logger.print('_mGetGraphCoroutine is dead and not resumed')
                    break
                end
            end -- update graph
        end

        if _mGameTime_msec ~= _mLastGameTime_msec then -- skip if paused
            if _mStartStopTrainsCoroutine == nil or coroutine.status(_mStartStopTrainsCoroutine) == 'dead' then
                _mStartStopTrainsCoroutine = coroutine.create(_actions.startStopTrains)
                logger.print('_mStartStopTrainsCoroutine created')
            end
            for _ = 1, constants.numStartStopTrainsCoroutineResumesPerTick, 1 do
                if coroutine.status(_mStartStopTrainsCoroutine) ~= 'dead' then
                    local isSuccess, error = coroutine.resume(_mStartStopTrainsCoroutine)
                    -- if an error occurs in the coroutine, it dies: good. Errors can happen whenever the graph is out of date.
                    if isSuccess then
                        logger.print('_mStartStopTrainsCoroutine resumed OK')
                    else
                        logger.print('_mStartStopTrainsCoroutine resumed with error') logger.debugPrint(error)
                    end
                else -- leave it dead, giving a chance to the other coroutine to start and/or to change the shared variables
                    logger.print('_mStartStopTrainsCoroutine is dead and not resumed')
                    break
                end
            end
        end -- start and stop trains

        _mLastGameTime_msec = _mGameTime_msec
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
        _mSignalModelId_EraA = api.res.modelRep.find('railroad/lollo_priority_signals/signal_path_a.mdl')
        _mSignalModelId_EraC = api.res.modelRep.find('railroad/lollo_priority_signals/signal_path_c.mdl')
        logger.print('_signalModelId_EraA =') logger.debugPrint(_mSignalModelId_EraA)
        logger.print('_signalModelId_EraC =') logger.debugPrint(_mSignalModelId_EraC)
    end,
}
