local constants = require('lollo_priority_signals.constants')
local edgeUtils = require('lollo_priority_signals.edgeUtils')
local logger = require('lollo_priority_signals.logger')

local funcs = {
    ---returns table of edgeIds indexed by edgeObjectId
    ---@param refModelId integer
    ---@return table<integer>
    getAllEdgeObjectsAndEdgesWithModelId = function(refModelId)
        if not(edgeUtils.isValidId(refModelId)) then return {} end

        local _map = api.engine.system.streetSystem.getEdgeObject2EdgeMap()
        local edgeObjectIds = {}
        for edgeObjectId, edgeId in pairs(_map) do
            edgeObjectIds[#edgeObjectIds+1] = edgeObjectId
        end

        local myEdgeObjectIds = edgeUtils.getEdgeObjectsIdsWithModelId2(edgeObjectIds, refModelId)
        local results = {}
        for _, edgeObjectId in pairs(myEdgeObjectIds) do
            results[edgeObjectId] = _map[edgeObjectId]
        end

        return results
    end,
    ---returns table of edgeObjectIds
    ---@param refModelId integer
    ---@return integer[]
    getAllEdgeObjectsWithModelId = function(refModelId)
        if not(edgeUtils.isValidId(refModelId)) then return {} end

        local _map = api.engine.system.streetSystem.getEdgeObject2EdgeMap()
        local edgeObjectIds = {}
        for edgeObjectId, _ in pairs(_map) do
            edgeObjectIds[#edgeObjectIds+1] = edgeObjectId
        end

        return edgeUtils.getEdgeObjectsIdsWithModelId2(edgeObjectIds, refModelId)
    end,
    ---@param refEdgeId integer
    ---@param nodeId integer
    ---@return integer[]
    getConnectedEdgeIdsExceptOne = function(refEdgeId, nodeId)
        -- print('getConnectedEdgeIdsExceptOne starting')
        if not(edgeUtils.isValidAndExistingId(nodeId)) then return {} end

        local _map = api.engine.system.streetSystem.getNode2TrackEdgeMap()
        local results = {}

        local connectedEdgeIds_userdata = _map[nodeId] -- userdata
        if connectedEdgeIds_userdata ~= nil then
            for _, edgeId in pairs(connectedEdgeIds_userdata) do -- cannot use connectedEdgeIdsUserdata[index] here
                if edgeId ~= refEdgeId and edgeUtils.isValidAndExistingId(edgeId) then
                    results[#results+1] = edgeId
                end
            end
        end

        -- print('getConnectedEdgeIdsExceptOne is about to return') debugPrint(results)
        return results
    end,
    ---@param refEdgeIds_indexed table<integer, any>
    ---@param nodeId integer
    ---@return integer[]
    getConnectedEdgeIdsExceptSome = function(refEdgeIds_indexed, nodeId)
        -- print('getConnectedEdgeIdsExceptSome starting')
        if not(edgeUtils.isValidAndExistingId(nodeId)) then return {} end

        local _map = api.engine.system.streetSystem.getNode2TrackEdgeMap()
        local results = {}

        local connectedEdgeIds_userdata = _map[nodeId] -- userdata
        if connectedEdgeIds_userdata ~= nil then
            for _, edgeId in pairs(connectedEdgeIds_userdata) do -- cannot use connectedEdgeIdsUserdata[index] here
                if not(refEdgeIds_indexed[edgeId]) and edgeUtils.isValidAndExistingId(edgeId) then
                    results[#results+1] = edgeId
                end
            end
        end

        -- print('getConnectedEdgeIdsExceptSome is about to return') debugPrint(results)
        return results
    end,
    ---gets edge objects with the given model id
    ---@param edgeId integer
    ---@param refModelId integer
    ---@return integer[]
    getObjectIdsInEdge = function(edgeId, refModelId)
        if not(edgeUtils.isValidId(edgeId)) or not(edgeUtils.isValidId(refModelId)) then return {} end

        local baseEdge = api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE)
        local baseEdgeTrack = api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE_TRACK)
        if baseEdge == nil or baseEdgeTrack == nil then return {} end

        local results = {}
        logger.print('baseEdge.objects =') logger.debugPrint(baseEdge.objects)
        for _, object in pairs(baseEdge.objects) do
            if object ~= nil and object[1] ~= nil then
                local objectId = object[1]
                logger.print('baseEdge objectId =') logger.debugPrint(objectId)
                if edgeUtils.isValidAndExistingId(objectId) then
                    local modelInstanceList = api.engine.getComponent(objectId, api.type.ComponentType.MODEL_INSTANCE_LIST)
                    if modelInstanceList ~= nil
                    and modelInstanceList.fatInstances
                    and modelInstanceList.fatInstances[1]
                    and modelInstanceList.fatInstances[1].modelId == refModelId then
                        logger.print('adding objectId = ' .. objectId)
                        results[#results+1] = objectId
                    end
                end
            end
        end
        return results
    end,
    ---comment
    ---@param signalId integer
    ---@return boolean
    getSignalIsOneWay = function(signalId)
        if not(edgeUtils.isValidId(signalId)) then return false end

        local signalList = api.engine.getComponent(signalId, api.type.ComponentType.SIGNAL_LIST)
        if signalList == nil or signalList.signals == nil  or signalList.signals[1] == nil then return false end

        return signalList.signals[1].type == 1
    end,
    getIsPathFromEdgeToNode = function(edgeId, nodeId, maxDistance)
        local counters = {}

        -- local maxIndex = 0
        -- local baseEdge = api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE)
        -- for _, object in pairs(baseEdge.objects) do
        --     local objectId = object[1]
        --     local signalList = api.engine.getComponent(objectId, api.type.ComponentType.SIGNAL_LIST)
        --     if signalList and signalList.signals and signalList.signals[1] then
        --         local index = signalList.signals[1].edgePr.index
        --         if index > maxIndex then maxIndex = index end
        --     end
        -- end

        local maxIndex = #api.engine.getComponent(edgeId, api.type.ComponentType.TRANSPORT_NETWORK).edges - 1

        for i = 0, maxIndex, 1 do
            local edge1IdTyped = api.type.EdgeId.new(edgeId, i)
            local edgeIdDir1False = api.type.EdgeIdDirAndLength.new(edge1IdTyped, false, 0)
            local edgeIdDir1True = api.type.EdgeIdDirAndLength.new(edge1IdTyped, true, 0)
            local node2Typed = api.type.NodeId.new(nodeId, 0)
            local myPath = api.engine.util.pathfinding.findPath(
                { edgeIdDir1False, edgeIdDir1True },
                { node2Typed },
                {
                    api.type.enum.TransportMode.TRAIN,
                    -- api.type.enum.TransportMode.ELECTRIC_TRAIN
                },
                maxDistance
            )
            counters[i] = 0
            -- logger.print('index = ' .. i .. ', myPath =') logger.debugPrint(myPath)
            for _, value in pairs(myPath) do
                -- remove duplicates arising from traffic light or waypoints on edges, which have the same entity but a higher index.
                if #counters == 0 or counters[#counters] ~= value.entity then
                    counters[i] = counters[i] + 1
                end
            end
        end

        for i = 0, maxIndex, 1 do
            if counters[i] == 0 then return false end
        end
        return true
    end,
    isEdgeFrozen_FAST = function(edgeId)
        if not(edgeUtils.isValidAndExistingId(edgeId)) then return false end

        local conId = api.engine.system.streetConnectorSystem.getConstructionEntityForEdge(edgeId)
        return edgeUtils.isValidAndExistingId(conId)
    end
}

---returns 0 for no one-way signal, 1 for one-way signal along, 2 for one-way signal against
---@param signalId integer
---@return 0|1|2
funcs.getOneWaySignalDirection = function(signalId)
    local signalList = api.engine.getComponent(signalId, api.type.ComponentType.SIGNAL_LIST)
    local signal = signalList.signals[1]
    local edgeId = signal.edgePr.entity

    if signal.type == 1 then -- one-way signal
        local signalAgainst = api.engine.system.signalSystem.getSignal(api.type.EdgeId.new(edgeId, signal.edgePr.index), false)
        if signalAgainst.entity == signalId then return 2 end
        return 1
        -- local signalAlong = api.engine.system.signalSystem.getSignal(api.type.EdgeId.new(edgeId_, signal.edgePr.index), true)
        -- if signalAlong.entity == edgeObjectId then isSignalAlong = true end
    end

    return 0
end
---@param baseEdge integer
---@return boolean
funcs.hasOpposingOneWaySignals = function(baseEdge)
    local lastSignalDirection = 0
    for _, object in pairs(baseEdge.objects) do
        local objectId = object[1]
        local oneWaySignalDirection = funcs.getOneWaySignalDirection(objectId)
        if oneWaySignalDirection ~= 0 then
            if lastSignalDirection == 0 then
                lastSignalDirection = oneWaySignalDirection
            end
            if lastSignalDirection ~= oneWaySignalDirection then return true end
        end
    end

    return false
end
---comment
---@param baseEdge integer
---@return integer[]
funcs.getLightIds = function(baseEdge)
    local results = {}
    for _, object in pairs(baseEdge.objects) do
        local objectId = object[1]
        local signalList = api.engine.getComponent(objectId, api.type.ComponentType.SIGNAL_LIST)
        if signalList and signalList.signals and signalList.signals[1] then
            local signal = signalList.signals[1]
            if signal.type == 0 or signal.type == 1 then
                results[#results+1] = objectId
            end
        end
    end

    return results
end
---@param signalId integer
---@return boolean
---@return integer
funcs.isOneWaySignalAgainstEdgeDirection = function(signalId)
    local signalList = api.engine.getComponent(signalId, api.type.ComponentType.SIGNAL_LIST)
    local signal = signalList.signals[1]
    local edgeId = signal.edgePr.entity

    -- signal.type == 0 -- two-way signal
    -- signal.type == 1 -- one-way signal
    -- signal.type == 1 -- waypoint
    if signal.type == 1 then -- one-way signal
        local signalAgainst = api.engine.system.signalSystem.getSignal(api.type.EdgeId.new(edgeId, signal.edgePr.index), false)
        if signalAgainst.entity == signalId then return true, edgeId end
        -- local signalAlong = api.engine.system.signalSystem.getSignal(api.type.EdgeId.new(edgeId_, signal.edgePr.index), true)
        -- if signalAlong.entity == edgeObjectId then isSignalAlong = true end
    end

    return false, edgeId
end
---@param signalId integer
---@return {baseEdge: any, edgeId: integer, inEdgeId: integer, isFound: boolean, isGoAhead: boolean, isHaveWayEdgeDirTowardsIntersection: boolean, nodeId: integer, startNodeId: integer}
funcs.getNextIntersectionBehind = function(signalId)
    logger.print('getNextIntersection starting, signalId = ' .. signalId)
    local _getNextIntersection = function(edgeId, baseEdge, startNodeId)
        logger.print('_getNextIntersection starting, edgeId_ = ' .. edgeId .. ', startNodeId_ = ' .. startNodeId)
        local nextEdgeIds = funcs.getConnectedEdgeIdsExceptOne(edgeId, startNodeId)
        local nextEdgeIdsCount = #nextEdgeIds
        if nextEdgeIdsCount == 0 then -- end of line: do nothing
            return { isGoAhead = false, }
        elseif funcs.isEdgeFrozen_FAST(edgeId) then -- station or depot: do nothing
            return { isGoAhead = false, }
        elseif funcs.hasOpposingOneWaySignals(baseEdge) then -- baseEdge has opposing one-way signals: do nothing coz no trains will get through
            return { isGoAhead = false, }
        end

        if nextEdgeIdsCount == 1 then -- try the next edge
            local nextEdgeId = nextEdgeIds[1]
            local nextBaseEdge = api.engine.getComponent(nextEdgeId, api.type.ComponentType.BASE_EDGE)
            return {
                baseEdge = nextBaseEdge,
                edgeId = nextEdgeId,
                isGoAhead = true,
                startNodeId = startNodeId == nextBaseEdge.node0 and nextBaseEdge.node1 or nextBaseEdge.node0
            }
        else -- startNodeId is an intersection
            return {
                inEdgeId = edgeId,
                isFound = true,
                isGoAhead = false,
                isHaveWayEdgeDirTowardsIntersection = startNodeId == baseEdge.node1,
                nodeId = startNodeId,
            }
        end
    end

    local isSignalAgainst, edgeId = funcs.isOneWaySignalAgainstEdgeDirection(signalId)
    logger.print('isSignalAgainst = ' .. tostring(isSignalAgainst))
    local baseEdge = api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE)
    local startNodeId = isSignalAgainst and baseEdge.node0 or baseEdge.node1

    local intersectionProps = _getNextIntersection(edgeId, baseEdge, startNodeId)
    local count, _maxCount = 1, constants.maxNSegmentsBeforeIntersection
    while intersectionProps.isGoAhead and count < _maxCount do
        intersectionProps = _getNextIntersection(intersectionProps.edgeId, intersectionProps.baseEdge, intersectionProps.startNodeId)
    end

    logger.print('getNextIntersectionBehind about to return') logger.debugPrint(intersectionProps)
    return intersectionProps
end
---comment
---@param nodeEdgeIdBeforeIntersection_indexedBy_intersectionNodeId_edgeIdHavingWay table<integer, table<integer, integer[]>>
---@param prioritySignals_indexed table<integer, integer>
---@return table<integer, table<integer, {isGiveWayEdgeDirTowardsIntersection: boolean, nodeIdTowardsIntersection: integer}>> -- intersection node id, edgeId that gives way, its direction, nodeId towards intersection
funcs.getNextLightsOrStations = function(nodeEdgeIdBeforeIntersection_indexedBy_intersectionNodeId_edgeIdHavingWay, prioritySignals_indexed)
    -- local edgeIdsGivingWay = {} -- this is only for testing
    -- local nodeEdgeIdTowardsIntersection_indexedBy_prioritySignalId_edgeIdGivingWay = {}
    local nodeEdgeIdBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay = {}

    -- local _addEdgeGivingWay = function(edgeIdGivingWay, baseEdge, nodeIdTowardsIntersection, prioritySignalIds_indexedBy_inEdgeId)
    --     logger.print('_addEdgeGivingWay starting, edgeIdGivingWay = ' .. edgeIdGivingWay)
    --     for _, prioritySignalIds in pairs(prioritySignalIds_indexedBy_inEdgeId) do
    --         for _, prioritySignalId in pairs(prioritySignalIds) do
    --             if not(nodeEdgeIdTowardsIntersection_indexedBy_prioritySignalId_edgeIdGivingWay[prioritySignalId]) then
    --                 nodeEdgeIdTowardsIntersection_indexedBy_prioritySignalId_edgeIdGivingWay[prioritySignalId] =
    --                 {[edgeIdGivingWay] = {
    --                     isGiveWayEdgeDirTowardsIntersection = baseEdge.node1 == nodeIdTowardsIntersection,
    --                     nodeIdTowardsIntersection = nodeIdTowardsIntersection,
    --                 }}
    --             else
    --                 nodeEdgeIdTowardsIntersection_indexedBy_prioritySignalId_edgeIdGivingWay[prioritySignalId][edgeIdGivingWay] = {
    --                     isGiveWayEdgeDirTowardsIntersection = baseEdge.node1 == nodeIdTowardsIntersection,
    --                     nodeIdTowardsIntersection = nodeIdTowardsIntersection,
    --                 }
    --             end
    --         end
    --     end
    -- end
    local _addEdgeGivingWay2 = function(edgeIdGivingWay, baseEdge, nodeIdTowardsIntersection, intersectionNodeId)
        logger.print('_addEdgeGivingWay2 starting, edgeIdGivingWay = ' .. edgeIdGivingWay)
        if not(nodeEdgeIdBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay[intersectionNodeId]) then
            nodeEdgeIdBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay[intersectionNodeId] =
            {[edgeIdGivingWay] = {
                isGiveWayEdgeDirTowardsIntersection = baseEdge.node1 == nodeIdTowardsIntersection,
                nodeIdTowardsIntersection = nodeIdTowardsIntersection,
            }}
        else
            nodeEdgeIdBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay[intersectionNodeId][edgeIdGivingWay] = {
                isGiveWayEdgeDirTowardsIntersection = baseEdge.node1 == nodeIdTowardsIntersection,
                nodeIdTowardsIntersection = nodeIdTowardsIntersection,
            }
        end
    end
    local _getNext4 = function(edgeId, commonNodeId, intersectionNodeId, count, prioritySignalIds_indexedBy_inEdgeId)
        logger.print('_getNext4 starting, edgeId = ' .. edgeId .. ', commonNodeId = ' .. commonNodeId)
        if prioritySignalIds_indexedBy_inEdgeId[edgeId] ~= nil and #prioritySignalIds_indexedBy_inEdgeId[edgeId] > 0 then -- this edge enters the intersection behind the priority light:
            -- if I am here, I have gone too far back
            logger.print('this edge leads from the prioritz signal into the intersection')
            return { isGoAhead = false }
        end
        local baseEdge = api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE)
        local lightIdsInEdge = funcs.getLightIds(baseEdge)
        if #lightIdsInEdge > 0 then -- this is it
            logger.print('this edge has lights')
            -- get out if there is a priority signal on this edge, you don't want to compete.
            -- If there are more signals on the same edge, tough, get out anyway.
            for _, lightId in pairs(lightIdsInEdge) do
                if prioritySignals_indexed[lightId] ~= nil then return { isGoAhead = false } end
            end
            -- check if the intersection is reachable from both ends of the edge, there could be a light blocking it or a cross instead of a switch
            -- You might check this before checking the lights, and leave if isPath is false LOLLO TODO check if it is faster that way
            if funcs.getIsPathFromEdgeToNode(edgeId, intersectionNodeId, constants.maxDistanceFromIntersection) then
                -- _addEdgeGivingWay(edgeId, baseEdge, commonNodeId, prioritySignalIds_indexedBy_inEdgeId)
                _addEdgeGivingWay2(edgeId, baseEdge, commonNodeId, intersectionNodeId)
                -- edgeIdsGivingWay[edgeId] = intersectionNodeId
            end
            return { isGoAhead = false }
        elseif funcs.isEdgeFrozen_FAST(edgeId) then -- station or depot
            logger.print('this edge is frozen')
            -- check if the intersection is reachable from both ends of the edge, there could be a light blocking it or a cross instead of a switch
            if funcs.getIsPathFromEdgeToNode(edgeId, intersectionNodeId, constants.maxDistanceFromIntersection) then
                -- _addEdgeGivingWay(edgeId, baseEdge, commonNodeId, prioritySignalIds_indexedBy_inEdgeId)
                _addEdgeGivingWay2(edgeId, baseEdge, commonNodeId, intersectionNodeId)
                -- edgeIdsGivingWay[edgeId] = intersectionNodeId
            end
            return { isGoAhead = false }
        else -- go ahead with the next edge(s)
            if baseEdge.node0 ~= commonNodeId and baseEdge.node1 ~= commonNodeId then
                logger.warn('baseEdge.node0 ~= commonNodeId and baseEdge.node1 ~= commonNodeId')
                return { isGoAhead = false }
            end
            if count > 1 and (baseEdge.node0 == intersectionNodeId or baseEdge.node1 == intersectionNodeId) then
                logger.print('going back, leave this branch')
                return { isGoAhead = false }
            end
            logger.print('need to look farther')
            return {
                isGoAhead = true,
                newNodeId = baseEdge.node0 == commonNodeId and baseEdge.node1 or baseEdge.node0
            }
        end
    end

    local _getNext3 = function(edgeId, commonNodeId, intersectionNodeId, getNext2Func, count, prioritySignalIds_indexedBy_inEdgeId)
        logger.print('_getNext3 starting, edgeId = ' .. edgeId .. ', commonNodeId = ' .. commonNodeId)
        local next = _getNext4(edgeId, commonNodeId, intersectionNodeId, count, prioritySignalIds_indexedBy_inEdgeId)
        if next.isGoAhead then
            if count < constants.maxNSegmentsAfterIntersection then
                local connectedEdgeIds = funcs.getConnectedEdgeIdsExceptOne(edgeId, next.newNodeId)
                getNext2Func(connectedEdgeIds, next.newNodeId, intersectionNodeId, getNext2Func, count, prioritySignalIds_indexedBy_inEdgeId)
                logger.print('count = ' .. count)
            else
                logger.print('too many attempts, leaving')
            end
        end
    end
    local _getNext2 = function(connectedEdgeIds, commonNodeId, intersectionNodeId, getNext2Func, count, prioritySignalIds_indexedBy_inEdgeId)
        logger.print('_getNext2 starting, commonNodeId = ' .. commonNodeId .. ', connectedEdgeIds =') logger.debugPrint(connectedEdgeIds)
        count = count + 1
        for _, edgeId in pairs(connectedEdgeIds) do
            _getNext3(edgeId, commonNodeId, intersectionNodeId, getNext2Func, count, prioritySignalIds_indexedBy_inEdgeId)
        end
    end

    for intersectionNodeId, nodeEdgeIdBeforeIntersection_indexedBy_inEdgeId in pairs(nodeEdgeIdBeforeIntersection_indexedBy_intersectionNodeId_edgeIdHavingWay) do
        local connectedEdgeIds = funcs.getConnectedEdgeIdsExceptSome(nodeEdgeIdBeforeIntersection_indexedBy_inEdgeId, intersectionNodeId)
        logger.print('_getNext1 got intersectionNodeId = ' .. intersectionNodeId .. ', connectedEdgeIds =') logger.debugPrint(connectedEdgeIds)
        _getNext2(connectedEdgeIds, intersectionNodeId, intersectionNodeId, _getNext2, 0, nodeEdgeIdBeforeIntersection_indexedBy_inEdgeId)
    end

    -- return edgeIdsGivingWay, nodeEdgeIdTowardsIntersection_indexedBy_prioritySignalId_edgeIdGivingWay
    -- return nodeEdgeIdTowardsIntersection_indexedBy_prioritySignalId_edgeIdGivingWay
    return nodeEdgeIdBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay
end

return funcs
