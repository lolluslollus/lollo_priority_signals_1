local arrayUtils = require ('lollo_priority_signals.arrayUtils')
local constants = require('lollo_priority_signals.constants')
local logger = require ('lollo_priority_signals.logger')
local profileLogger = require ('lollo_priority_signals.profileLogger')
local signalHelpers = require('lollo_priority_signals.signalHelpers')
local stateHelpers = require('lollo_priority_signals.stateHelpers')

--[[
    LOLLO NOTE one-way lights are read as two-way lights,
    and they don't appear in the menu if they have no two-way counterparts, or if those counterparts have expired.
]]

---@type integer
local _mSignalModelId_EraA
---@type integer
local _mSignalModelId_EraC
---@type integer
local _mSignalModelId_Invisible
---@type table<string, string>
local _mTexts = { }
---@type integer
local _mGameTime_msec = 0
---@type integer
local _mLastGameTime_msec = 0
---@type number
local _mSystemTime_msec = 0
---@type number
local _mLastRefreshGraph_gameTime_msec = 0
---@type number
local _mLastRefreshGraph_systemTime_msec = 0
---@type boolean
local _mIsGraphDone = false

---@type bitsBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId
local _mBitsBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId = {}
---@type bitsBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay
local _mBitsBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay = {}
-- ---@type table<integer, integer[]>
-- local _mInEdgeIdsBehindIntersections_indexedBy_edgeIdGivingWay = {}
-- ---@type table<integer, integer[]>
-- local _mIntersectionNodeIds_indexedBy_edgeIdGivingWay = {}
---@type table<integer, {firstStopTimeMsec: number, lastStopTimeMsec: number, isStoppedAtOnce: boolean}>
local _mStopProps_indexedBy_stoppedVehicleIds = {}

local _utils = {
    ---only reliable with trains that are not user-stopped
    ---@param bitsBeforeIntersection_indexedBy_inEdgeId table<integer, { isInEdgeDirTowardsIntersection: boolean, priorityEdgeIds: integer[] }>
    ---@param isGetStoppedVehicles? boolean also get stopped vehicles, useful for testing
    ---@return boolean
    ---@return table<integer, boolean>
    getPriorityVehicleIds = function(bitsBeforeIntersection_indexedBy_inEdgeId, isGetStoppedVehicles)
        logger.print('_getPriorityVehicleIds starting, bitsBeforeIntersection_indexedBy_inEdgeId =') logger.debugPrint(bitsBeforeIntersection_indexedBy_inEdgeId)
        local results_indexed = {}
        local hasRecords = false
        local foundVehicleIds_indexed = {}
        for inEdgeId, bitBeforeIntersection in pairs(bitsBeforeIntersection_indexedBy_inEdgeId) do
            -- logger.print('inEdgeId = ' .. inEdgeId .. ', bitBeforeIntersection =') logger.debugPrint(bitBeforeIntersection)
            local priorityVehicleIds = api.engine.system.transportVehicleSystem.getVehicles(bitBeforeIntersection.priorityEdgeIds, false)
            for _, vehicleId in pairs(priorityVehicleIds) do
                if not(foundVehicleIds_indexed[vehicleId]) then
                    local movePath = api.engine.getComponent(vehicleId, api.type.ComponentType.MOVE_PATH)
                    --[[
                        Values for api.type.ComponentType.TRANSPORT_VEHICLE state (there is an enum):
                        api.type.enum.TransportVehicleState.IN_DEPOT == 0    
                        api.type.enum.TransportVehicleState.EN_ROUTE == 1
                        api.type.enum.TransportVehicleState.AT_TERMINAL == 2
                        api.type.enum.TransportVehicleState.GOING_TO_DEPOT == 3

                        Values for api.type.ComponentType.MOVE_PATH state (no enums):
                        movePath.running == 0
                        movePath.state stopping == 1
                        movePath.state stopped == 2
                        movePath.state stopped at terminal == 3
                    ]]
                    -- logger.print('vehicleId = ' .. vehicleId .. '; movePath.state = ' .. movePath.state)
                    -- logger.print('movePath =') logger.debugPrint(movePath)
                    -- if the train has not been stopped (I don't know what enum this is, it is not api.type.enum.TransportVehicleState)
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
                                -- ignore trains heading out of the intersection
                                else
                                    logger.print('vehicle ' .. vehicleId .. ' ignored coz is heading away from the intersection')
                                end
                                foundVehicleIds_indexed[vehicleId] = true
                                break
                            end
                        end
                    end
                end
            end
            coroutine.yield()
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
                        logger.print('_isAnyTrainBoundForEdgeOrNode about to return true, vehicleId = ' .. (vehicleId or 'NIL'))
                        return true
                    end
                end
            end
        end
        -- logger.print('_isAnyTrainBoundForEdgeOrNode about to return false')
        return false
    end,
    restart = function(vehicleId)
        api.cmd.sendCommand(api.cmd.make.setUserStopped(vehicleId, false))
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
    replaceEdgeWithSameRemovingObjects = function(edgeId, objectIdsToRemove)
        logger.print('_replaceEdgeWithSameRemovingObjects starting, edgeId = ' .. (edgeId or 'NIL'))
        if not(signalHelpers.isValidAndExistingId(edgeId)) then return end
        if type(objectIdsToRemove) ~= 'table' or #objectIdsToRemove == 0 then return end

        logger.print('_replaceEdgeWithSameRemovingObjects found, the edge id is valid')
        local oldEdge = api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE)
        local oldEdgeTrack = api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE_TRACK)
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
        newEdge.playerOwned = api.engine.getComponent(edgeId, api.type.ComponentType.PLAYER_OWNED)
        newEdge.trackEdge = oldEdgeTrack

        local objectIdsToRemove_indexed = {}
        for _, objectId in pairs(objectIdsToRemove) do
            objectIdsToRemove_indexed[objectId] = true
        end
        local edgeObjects = {}
        for _, edgeObj in pairs(oldEdge.objects) do
            if not(objectIdsToRemove_indexed[edgeObj[1]]) and signalHelpers.isValidId(edgeObj[1]) then
                table.insert(edgeObjects, { edgeObj[1], edgeObj[2] })
            end
        end
        if #edgeObjects > 0 then
            newEdge.comp.objects = edgeObjects -- LOLLO NOTE cannot insert directly into edge0.comp.objects
        else
            logger.print('_replaceEdgeWithSameRemovingObjects: no edge objects found to add')
            newEdge.comp.objects = oldEdge.objects
        end

        local proposal = api.type.SimpleProposal.new()
        proposal.streetProposal.edgesToRemove[1] = edgeId
        proposal.streetProposal.edgesToAdd[1] = newEdge
        local count = 1
        for objectId, _ in pairs(objectIdsToRemove_indexed) do
            if signalHelpers.isValidAndExistingId(objectId) then
                proposal.streetProposal.edgeObjectsToRemove[count] = objectId
                count = count + 1
            end
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
                logger.print('LOLLO _replaceEdgeWithSameRemovingObjects success = ') logger.debugPrint(success)
            end
        )
    end,
    ---@param tab table|any[]
    ---@param isIgnoreNil? boolean
    ---@return boolean
    tableHasValues = function(tab, isIgnoreNil)
        if type(tab) ~= 'table' and type(tab) ~= 'userdata' then
            return false
        end
        local result = 0
        for _, value in pairs(tab) do
            if not(isIgnoreNil) or value ~= nil then
                return true
            end
        end
        return false
    end,
}

local _mGetGraphCoroutine, _mStartStopTrainsCoroutine
local _actions = {
    updateGraph = function()
        _mIsGraphDone = false
        local prioritySignalIds_indexed = signalHelpers.getAllEdgeObjectsWithModelIds_indexed(_mSignalModelId_EraA, _mSignalModelId_EraC, _mSignalModelId_Invisible, true)
        logger.print('updateGraph started, prioritySignalIds_indexed =') logger.debugPrint(prioritySignalIds_indexed)
        coroutine.yield()
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
        while count < constants.maxNChainedPrioritySignalsBeforeIntersection and _utils.tableHasValues(chains_indexedBy_innerSignalId, true) do
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
        -- local inEdgeIdsBehindIntersections_indexedBy_edgeIdGivingWay = {}
        -- local intersectionNodeIds_indexedBy_edgeIdGivingWay = {}
        -- for intersectionNodeId, bitsBehindIntersection_indexedBy_edgeIdGivingWay in pairs(bitsBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay) do
        --     for edgeIdGivingWay, bitBehindIntersection in pairs(bitsBehindIntersection_indexedBy_edgeIdGivingWay) do
                -- if not(inEdgeIdsBehindIntersections_indexedBy_edgeIdGivingWay[edgeIdGivingWay]) then
                --     inEdgeIdsBehindIntersections_indexedBy_edgeIdGivingWay[edgeIdGivingWay] = {bitBehindIntersection.inEdgeId}
                -- else
                --     table.insert(inEdgeIdsBehindIntersections_indexedBy_edgeIdGivingWay[edgeIdGivingWay], bitBehindIntersection.inEdgeId)
                -- end

                -- if not(intersectionNodeIds_indexedBy_edgeIdGivingWay[edgeIdGivingWay]) then
                --     intersectionNodeIds_indexedBy_edgeIdGivingWay[edgeIdGivingWay] = {intersectionNodeId}
                -- else
                --     table.insert(intersectionNodeIds_indexedBy_edgeIdGivingWay[edgeIdGivingWay], intersectionNodeId)
                -- end
        --     end
        -- end
        -- logger.print('inEdgeIdsBehindIntersections_indexedBy_edgeIdGivingWay =') logger.debugPrint(inEdgeIdsBehindIntersections_indexedBy_edgeIdGivingWay)
        -- logger.print('intersectionNodeIds_indexedBy_edgeIdGivingWay =') logger.debugPrint(intersectionNodeIds_indexedBy_edgeIdGivingWay)

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
        -- _mInEdgeIdsBehindIntersections_indexedBy_edgeIdGivingWay = inEdgeIdsBehindIntersections_indexedBy_edgeIdGivingWay
        -- _mIntersectionNodeIds_indexedBy_edgeIdGivingWay = intersectionNodeIds_indexedBy_edgeIdGivingWay
        _mLastRefreshGraph_systemTime_msec = os.clock() * 1000
        profileLogger.print('### updateGraph ending, _mLastRefreshGraph_gameTime_msec is about to become', _mLastRefreshGraph_gameTime_msec, _mGameTime_msec)
        _mLastRefreshGraph_gameTime_msec = _mGameTime_msec
        _mIsGraphDone = true
    end,
    startStopTrains = function()
        -- error('test error') -- What happens if an error occurs in the coroutine? It dies!
        local startTick_sec = 0
        local _isProfileLog = profileLogger.isExtendedLog()
        if _isProfileLog then startTick_sec = os.clock() end
        local _gameTime_msec = _mGameTime_msec
        logger.print('startStopTrains starting')
        for intersectionNodeId, bitsBeforeIntersection_indexedBy_inEdgeId in pairs(_mBitsBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId) do
            local hasIncomingPriorityVehicles, incomingPriorityVehicleIds = _utils.getPriorityVehicleIds(bitsBeforeIntersection_indexedBy_inEdgeId)
            -- if logger.isExtendedLog() then
            --     logger.print('intersectionNodeId = ' .. intersectionNodeId .. '; bitsBeforeIntersection_indexedBy_inEdgeId =') logger.debugPrint(bitsBeforeIntersection_indexedBy_inEdgeId)
            --     logger.print('incomingPriorityVehicleIds =') logger.debugPrint(incomingPriorityVehicleIds)
            -- end
            if hasIncomingPriorityVehicles then
                for edgeIdGivingWay, bitBehindIntersection in pairs(_mBitsBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay[intersectionNodeId]) do
                    -- if logger.isExtendedLog() then
                    --     logger.print('edgeIdGivingWay = ' .. edgeIdGivingWay)
                    --     logger.print('bitBehindIntersection = ') logger.debugPrint(bitBehindIntersection)
                    -- end
                    -- avoid gridlocks: do not stop a slow vehicle if it is on the path of a priority vehicle - unless that priority vehicle is user-stopped
                    if not(_utils.isAnyTrainBoundForEdgeOrNode(incomingPriorityVehicleIds, edgeIdGivingWay))
                    then
                        local vehicleIdsNearGiveWaySignals = api.engine.system.transportVehicleSystem.getVehicles({edgeIdGivingWay}, false)
                        logger.print('edgeIdGivingWay = ' .. (edgeIdGivingWay or 'NIL') .. ' has vehicleIdsNearGiveWaySignals =') logger.debugPrint(vehicleIdsNearGiveWaySignals)
                        for _, vehicleId in pairs(vehicleIdsNearGiveWaySignals) do
                            -- LOLLO NOTE MOVE_PATH and getVehicles change when a train is user-stopped:
                            -- uncovered edges disappear, so the train fails to meet some estimator below and tries to restart,
                            -- then the next tick will stop it again - or maybe not.
                            -- to avoid this lurching, if a train is stopped and is near the give-way signal, we just leave it there
                            -- LOLLO NOTE if the vehicle has passed the node, do not stop it to avoid gridlocks.
                            -- The crude restart below should take care of it.
                            local _stopPropsOfvehicle = _mStopProps_indexedBy_stoppedVehicleIds[vehicleId]
                            if _stopPropsOfvehicle ~= nil and _stopPropsOfvehicle.isStoppedAtOnce then
                                -- vehicle halted: renew the timestamp
                                _stopPropsOfvehicle.lastStopTimeMsec = _mLastRefreshGraph_gameTime_msec
                                logger.print('vehicle ' .. vehicleId .. ' just got its stop-at-once timestamp renewed')
                            else
                                -- vehicle not halted
                                local movePath = api.engine.getComponent(vehicleId, api.type.ComponentType.MOVE_PATH)
                                -- movePath.path.edges[movePath.dyn.pathPos.edgeIndex].edgeId.entity === edgeId where a piece of the train is, not necessarily the head
                                for p = movePath.dyn.pathPos.edgeIndex + 1, #movePath.path.edges, 1 do
                                    local currentMovePathBit = movePath.path.edges[p]
                                    if currentMovePathBit.edgeId.entity == edgeIdGivingWay then
                                        logger.print('checking movePath, edgeIdGivingWay = ' .. edgeIdGivingWay)
                                        -- stop the train if it is heading for the intersection, and not merely transiting on the give-way bit
                                        if currentMovePathBit.dir == bitBehindIntersection.isGiveWayEdgeDirTowardsIntersection then
                                            local nextMovePathBit = movePath.path.edges[p+1]
                                            local nextMovePathBit_onDifferentEdge = nil
                                            if nextMovePathBit == nil then
                                                -- do nothing
                                            elseif nextMovePathBit.edgeId.entity ~= edgeIdGivingWay then
                                                nextMovePathBit_onDifferentEdge = nextMovePathBit
                                            else
                                                local pp = p+2
                                                while movePath.path.edges[pp] ~= nil and movePath.path.edges[pp].edgeId.entity == edgeIdGivingWay do
                                                    pp = pp+1
                                                end
                                                nextMovePathBit_onDifferentEdge = movePath.path.edges[pp]
                                            end

                                            -- logger.print('nextMovePathBit =') logger.debugPrint(nextMovePathBit)
                                            -- logger.print('nextMovePathBit_onDifferentEdge =') logger.debugPrint(nextMovePathBit_onDifferentEdge)
                                            if nextMovePathBit == nil or nextMovePathBit_onDifferentEdge == nil then
                                                -- end of line or vehicle stopped
                                                if _stopPropsOfvehicle ~= nil then
                                                    -- timestamp available: renew it
                                                    _stopPropsOfvehicle.lastStopTimeMsec = _mLastRefreshGraph_gameTime_msec
                                                    logger.print('vehicle ' .. vehicleId .. ' with movePath.state ' .. movePath.state .. ': renewing the timestamp,', tostring(nextMovePathBit == nil), tostring(nextMovePathBit_onDifferentEdge == nil), '_mStopProps_indexedBy_stoppedVehicleIds[vehicleId] =') logger.debugPrint(_stopPropsOfvehicle)
                                                else
                                                    -- no timestamp: restart the vehicle. Probably, the game just started.
                                                    _utils.restart(vehicleId)
                                                    logger.print('vehicle ' .. vehicleId .. ' with movePath.state ' .. movePath.state .. ': attempting to renew the timestamp but _mStopProps_indexedBy_stoppedVehicleIds[vehicleId] is nil => restarting the vehicle,', tostring(nextMovePathBit == nil), tostring(nextMovePathBit_onDifferentEdge == nil))
                                                end
                                            else
                                                local vehicleIdsOnNextEdge = api.engine.system.transportVehicleSystem.getVehicles({nextMovePathBit_onDifferentEdge.edgeId.entity}, false)
                                                if arrayUtils.arrayHasValue(vehicleIdsOnNextEdge, vehicleId) then
                                                    -- the train has already passed the give-way edge: do not stop it
                                                    if movePath.state == 1 or movePath.state == 2 then -- train stopping or stopped: restart it
                                                        _utils.restart(vehicleId)
                                                        logger.print('vehicle ' .. vehicleId .. ' was stopping or stopped, I restarted it to avoid gridlocks')
                                                    else
                                                        logger.print('vehicle ' .. vehicleId .. ' goes on to avoid gridlocks')
                                                    end
                                                    _mStopProps_indexedBy_stoppedVehicleIds[vehicleId] = nil
                                                else
                                                    -- the train head is still within the give-way edge: stop it
                                                    if nextMovePathBit.edgeId.entity ~= edgeIdGivingWay then
                                                        -- the train is on the last edge bit: stop at once
                                                        if movePath.state ~= 2 then _utils.stopAtOnce(vehicleId) end
                                                        if _stopPropsOfvehicle == nil then
                                                            _mStopProps_indexedBy_stoppedVehicleIds[vehicleId] = {firstStopTimeMsec = _gameTime_msec, lastStopTimeMsec = _mLastRefreshGraph_gameTime_msec, isStoppedAtOnce = true}
                                                            logger.print('vehicle ' .. vehicleId .. ' stopped at once')
                                                        else
                                                            _stopPropsOfvehicle.lastStopTimeMsec = _mLastRefreshGraph_gameTime_msec
                                                            _stopPropsOfvehicle.isStoppedAtOnce = true
                                                            logger.print('vehicle ' .. vehicleId .. ' already stopping, now ground to a halt')
                                                        end
                                                    else
                                                        -- there is still a bit of space: stop gently
                                                        if _stopPropsOfvehicle == nil then
                                                            if movePath.state ~= 1 and movePath.state ~= 2 then _utils.stopSlowly(vehicleId) end
                                                            _mStopProps_indexedBy_stoppedVehicleIds[vehicleId] = {firstStopTimeMsec = _gameTime_msec, lastStopTimeMsec = _mLastRefreshGraph_gameTime_msec, isStoppedAtOnce = false}
                                                            logger.print('vehicle ' .. vehicleId .. ' stopped slowly')
                                                        else
                                                            _stopPropsOfvehicle.lastStopTimeMsec = _mLastRefreshGraph_gameTime_msec
                                                            logger.print('vehicle ' .. vehicleId .. ' got its stop-slowly timestamp renewed')
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                        break
                                    end
                                end
                            end
                            coroutine.yield()
                        end
                    end
                    -- coroutine.yield()
                end
            -- else
            --     logger.print('no incoming priority vehicles')
            end
        end
        if _isProfileLog then
            profileLogger.print('### the startStopTrains loop took ' .. math.ceil((os.clock() - startTick_sec) * 1000) .. ' msec')
        end
        -- restart vehicles that don't need to wait anymore
        -- LOLLO NOTE this thing restarts trains the user has manually stopped: this is no good
        -- I do clean the table, but there is still a while when manually stopped vehicles are restarted automatically.
        -- We live with it
        -- LOLLO NOTE if the game is saved and resumed, this thing won't restart the trains coz the table is empty.
        -- The game will proceed and the table will populate again,
        -- unless the user makes a change to the line in the first seconds.
        -- We live with it.
        logger.print('startStopTrains has ended the loop, _gameTime_msec = ' .. tostring(_gameTime_msec) .. '; stopProps_indexedBy_stoppedVehicleIds =') logger.debugPrint(_mStopProps_indexedBy_stoppedVehicleIds)
        for vehicleId, stopProps in pairs(_mStopProps_indexedBy_stoppedVehicleIds) do
            if stopProps == nil
            or stopProps.lastStopTimeMsec ~= _mLastRefreshGraph_gameTime_msec
            then
                _utils.restart(vehicleId)
                logger.print('vehicle ' .. vehicleId .. ' had an old timestamp, so I restarted it')
                _mStopProps_indexedBy_stoppedVehicleIds[vehicleId] = nil
            elseif stopProps.firstStopTimeMsec - stopProps.lastStopTimeMsec > constants.maxMSecBeingStopped
            then
                _utils.restart(vehicleId)
                logger.print('vehicle ' .. vehicleId .. ' was stopped too long, so I restarted it')
                _mStopProps_indexedBy_stoppedVehicleIds[vehicleId] = nil
            end
        end
        if _isProfileLog then
            profileLogger.print('### startStopTrains took ' .. math.ceil((os.clock() - startTick_sec) * 1000) .. ' msec')
        end
    end,
}

return {
    -- this can fire a handful times per second
    update = function()
        local state = stateHelpers.getState()
        if not(state.is_on) then return end

        _mGameTime_msec = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_TIME).gameTime
        if not(_mGameTime_msec) then logger.err('update() cannot get time') return end

        _mSystemTime_msec = os.clock() * 1000

        local _isProfileLog = profileLogger.isExtendedLog()
        if _mGameTime_msec ~= _mLastGameTime_msec or not(_mIsGraphDone) then -- skip if paused and graph done
            logger.print('_mSystemTime_msec = ' .. tostring(_mSystemTime_msec) .. ', _mLastRefreshGraph_systemTime_msec = ' .. tostring(_mLastRefreshGraph_systemTime_msec))
            if _mGetGraphCoroutine == nil
            or (
                coroutine.status(_mGetGraphCoroutine) == 'dead'
                and _mSystemTime_msec - _mLastRefreshGraph_systemTime_msec > constants.refreshGraphPauseMsec -- wait a bit before recalculating the graph
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
                if coroutine.status(_mGetGraphCoroutine) == 'suspended' then
                    local startTick_sec = 0
                    if _isProfileLog then startTick_sec = os.clock() end

                    local isSuccess, error = coroutine.resume(_mGetGraphCoroutine)
                    -- if an error occurs in the coroutine, it dies.
                    if not(isSuccess) then
                        logger.warn('_mGetGraphCoroutine resumed with ERROR') logger.warningDebugPrint(error)
                    end
                    if _isProfileLog then
                        profileLogger.print('_mGetGraphCoroutine resumed, one go took ' .. math.ceil((os.clock() - startTick_sec) * 1000) .. ' msec')
                    end
                else -- leave it dead for this tick, everything else will have more resources to run through
                    logger.print('_mGetGraphCoroutine is not suspended, so I did not resume it')
                    break
                end
            end -- update graph
        end -- skip if paused, for testing

        if _mGameTime_msec ~= _mLastGameTime_msec and _mIsGraphDone then -- skip if paused or graph is missing
            if _mStartStopTrainsCoroutine == nil or coroutine.status(_mStartStopTrainsCoroutine) == 'dead' then
                _mStartStopTrainsCoroutine = coroutine.create(_actions.startStopTrains)
                logger.print('_mStartStopTrainsCoroutine created')
            end
            for _ = 1, constants.numStartStopTrainsCoroutineResumesPerTick, 1 do
                if coroutine.status(_mStartStopTrainsCoroutine) == 'suspended' then
                    local startTick_sec = 0
                    if _isProfileLog then startTick_sec = os.clock() end

                    local isSuccess, error = coroutine.resume(_mStartStopTrainsCoroutine)
                    -- if an error occurs in the coroutine, it dies: good. Errors can happen whenever the graph is out of date.
                    if not(isSuccess) then
                        logger.print('_mStartStopTrainsCoroutine resumed with ERROR') logger.debugPrint(error)
                    end
                    if _isProfileLog then
                        profileLogger.print('_mStartStopTrainsCoroutine resumed, one go took ' .. math.ceil((os.clock() - startTick_sec) * 1000) .. ' msec')
                    end
                else -- leave it dead, giving a chance to the other coroutine to start and/or to change the shared variables
                    logger.print('_mStartStopTrainsCoroutine is not suspended, so I did not resume it')
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
                -- elseif name == constants.events.removeSignals then
                --     _utils.replaceEdgeWithSameRemovingObjects(args.edgeId, args.objectIds)
                elseif name == constants.events.toggle_notaus then
                    logger.print('state before =') logger.debugPrint(stateHelpers.getState())
                    local state = stateHelpers.getState()
                    state.is_on = not(not(args))
                    logger.print('state after =') logger.debugPrint(stateHelpers.getState())
                end
            end,
            function(error)
                logger.xpErrorHandler(error)
            end
        )
    end,
    load = function()
        if api.gui ~= nil then return end

        logger.print('workerEngine.load firing')
        _mSignalModelId_EraA = api.res.modelRep.find('railroad/lollo_priority_signals/signal_path_a.mdl')
        _mSignalModelId_EraC = api.res.modelRep.find('railroad/lollo_priority_signals/signal_path_c.mdl')
        _mSignalModelId_Invisible = api.res.modelRep.find('railroad/lollo_priority_signals/signal_path_invisible.mdl')
        logger.print('_mSignalModelId_EraA =') logger.debugPrint(_mSignalModelId_EraA)
        logger.print('_mSignalModelId_EraC =') logger.debugPrint(_mSignalModelId_EraC)
        logger.print('_mSignalModelId_Invisible =') logger.debugPrint(_mSignalModelId_Invisible)
    end,
}
