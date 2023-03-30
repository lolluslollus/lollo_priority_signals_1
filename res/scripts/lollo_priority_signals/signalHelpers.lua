local arrayUtils = require('lollo_priority_signals.arrayUtils')
local constants = require('lollo_priority_signals.constants')
local logger = require('lollo_priority_signals.logger')

---@param id integer
---@return boolean
local _isValidId = function(id)
    return type(id) == 'number' and id >= 0
end

---@param id integer
---@return boolean
local _isValidAndExistingId = function(id)
    return type(id) == 'number' and id >= 0 and api.engine.entityExists(id)
end

---@param edgeObjectId integer
---@param refModelId integer
---@return boolean
local _isEdgeObjectIdWithModelId = function(edgeObjectId, refModelId)
    if not(_isValidAndExistingId(edgeObjectId)) or not(_isValidId(refModelId)) then return false end

    local modelInstanceList = api.engine.getComponent(edgeObjectId, api.type.ComponentType.MODEL_INSTANCE_LIST)
    return modelInstanceList ~= nil
    and modelInstanceList.fatInstances ~= nil
    and modelInstanceList.fatInstances[1] ~= nil
    and modelInstanceList.fatInstances[1].modelId == refModelId
end

---@param edgeObjectIds integer[]
---@param refModelId integer
---@return integer[]
local _getEdgeObjectsIdsWithModelId2 = function(edgeObjectIds, refModelId)
    local results = {}
    if type(edgeObjectIds) ~= 'table' then return results end

    for i = 1, #edgeObjectIds do
        if _isEdgeObjectIdWithModelId(edgeObjectIds[i], refModelId) then
            results[#results+1] = edgeObjectIds[i]
        end
    end
    return results
end

---gets edge objects with the given model id
---@param baseEdge table
---@param refModelId integer
---@return integer[]
local _getObjectIdsInBaseEdge = function(baseEdge, refModelId)
    if not(baseEdge) then return {} end

    local results = {}
    -- logger.print('baseEdge.objects =') logger.debugPrint(baseEdge.objects)
    for _, object in pairs(baseEdge.objects) do
        if object ~= nil and object[1] ~= nil then
            local objectId = object[1]
            -- logger.print('baseEdge objectId =') logger.debugPrint(objectId)
            if _isEdgeObjectIdWithModelId(objectId, refModelId) then
                -- logger.print('adding objectId = ' .. objectId)
                results[#results+1] = objectId
            end
        end
    end
    return results
end

---gets edge objects with the given model id
---@param edgeId integer
---@param refModelId integer
---@return integer[]
local _getObjectIdsInEdge = function(edgeId, refModelId)
    if not(_isValidId(edgeId)) then return {} end

    local baseEdge = api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE)
    local baseEdgeTrack = api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE_TRACK)
    if baseEdge == nil or baseEdgeTrack == nil then return {} end

    return _getObjectIdsInBaseEdge(baseEdge, refModelId)
end

---@param signalId integer
---@return boolean
---@return integer
local _isSignalAgainstEdgeDirection = function(signalId)
    local signalList = api.engine.getComponent(signalId, api.type.ComponentType.SIGNAL_LIST)
    local signal = signalList.signals[1]
    local edgeId = signal.edgePr.entity

    -- signal.type == 0 -- two-way signal
    -- signal.type == 1 -- one-way signal
    -- signal.type == 2 -- waypoint
    if signal.type == 0 or signal.type == 1 then -- two-way or one-way signal
        local signalAgainst = api.engine.system.signalSystem.getSignal(api.type.EdgeId.new(edgeId, signal.edgePr.index), false)
        if signalAgainst.entity == signalId then return true, edgeId end
        -- local signalAlong = api.engine.system.signalSystem.getSignal(api.type.EdgeId.new(edgeId_, signal.edgePr.index), true)
        -- if signalAlong.entity == edgeObjectId then isSignalAlong = true end
    end

    return false, edgeId
end
---returns 0 for no one-way signal, 1 for one-way signal along, 2 for one-way signal against
---@param signalId integer
---@return 0|1|2
local _getOneWaySignalDirection = function(signalId)
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

---@param baseEdge table
---@param toNodeId integer
---@return boolean
local _hasOpposingOneWaySignals = function(baseEdge, toNodeId)
    local edgeDirection = (baseEdge.node1 == toNodeId) and 1 or 2
    for _, object in pairs(baseEdge.objects) do
        local objectId = object[1]
        local oneWaySignalDirection = _getOneWaySignalDirection(objectId)
        if oneWaySignalDirection ~= 0 and oneWaySignalDirection ~= edgeDirection then
            return true
        end
    end
    return false
end

---@param baseEdge table
---@param toNodeId integer
---@return boolean
local _hasOneWaySignalsAlong = function(baseEdge, toNodeId)
    local edgeDirection = (baseEdge.node1 == toNodeId) and 2 or 1
    for _, object in pairs(baseEdge.objects) do
        local objectId = object[1]
        local oneWaySignalDirection = _getOneWaySignalDirection(objectId)
        if oneWaySignalDirection ~= 0 and oneWaySignalDirection ~= edgeDirection then
            return true
        end
    end
    return false
end

local funcs = {
    isValidId = _isValidId,
    isValidAndExistingId = _isValidAndExistingId,
    getEdgeObjectsIdsWithModelId2 = _getEdgeObjectsIdsWithModelId2,
    ---returns table of edgeObjectIds
    ---@param refModelId integer
    ---@return integer[]
    getAllEdgeObjectsWithModelId = function(refModelId)
        if not(_isValidId(refModelId)) then return {} end

        local _map = api.engine.system.streetSystem.getEdgeObject2EdgeMap()
        local edgeObjectIds = {}
        for edgeObjectId, _ in pairs(_map) do
            edgeObjectIds[#edgeObjectIds+1] = edgeObjectId
        end

        return _getEdgeObjectsIdsWithModelId2(edgeObjectIds, refModelId)
    end,
    ---@param refEdgeId integer
    ---@param nodeId integer
    ---@return integer[]
    getConnectedEdgeIdsExceptOne = function(refEdgeId, nodeId)
        -- print('getConnectedEdgeIdsExceptOne starting')
        if not(_isValidAndExistingId(nodeId)) then return {} end

        local _map = api.engine.system.streetSystem.getNode2TrackEdgeMap()
        local results = {}

        local connectedEdgeIds_userdata = _map[nodeId] -- userdata
        if connectedEdgeIds_userdata ~= nil then
            for _, edgeId in pairs(connectedEdgeIds_userdata) do -- cannot use connectedEdgeIdsUserdata[index] here
                if edgeId ~= refEdgeId and _isValidAndExistingId(edgeId) then
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
        if not(_isValidAndExistingId(nodeId)) then return {} end

        local _map = api.engine.system.streetSystem.getNode2TrackEdgeMap()
        local results = {}

        local connectedEdgeIds_userdata = _map[nodeId] -- userdata
        if connectedEdgeIds_userdata ~= nil then
            for _, edgeId in pairs(connectedEdgeIds_userdata) do -- cannot use connectedEdgeIdsUserdata[index] here
                if not(refEdgeIds_indexed[edgeId]) and _isValidAndExistingId(edgeId) then
                    results[#results+1] = edgeId
                end
            end
        end

        -- print('getConnectedEdgeIdsExceptSome is about to return') debugPrint(results)
        return results
    end,
    getObjectIdsInEdge = _getObjectIdsInEdge,
    ---@param signalId integer
    ---@return boolean
    isSignalOneWay = function(signalId)
        if not(_isValidId(signalId)) then return false end

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
        if not(_isValidAndExistingId(edgeId)) then return false end

        local conId = api.engine.system.streetConnectorSystem.getConstructionEntityForEdge(edgeId)
        return _isValidAndExistingId(conId)
    end,
    isEdgeFrozenInStation_FAST = function(edgeId)
        if not(_isValidAndExistingId(edgeId)) then return false end

        local conId = api.engine.system.streetConnectorSystem.getConstructionEntityForEdge(edgeId)
        if _isValidAndExistingId(conId) then
            local con = api.engine.getComponent(conId, api.type.ComponentType.CONSTRUCTION)
            if con ~= nil then
                return #con.stations > 0
            end
        end
        return false
    end,
    isEdgeFrozenInStationOrDepot_FAST = function(edgeId)
        if not(_isValidAndExistingId(edgeId)) then return false end

        local conId = api.engine.system.streetConnectorSystem.getConstructionEntityForEdge(edgeId)
        if _isValidAndExistingId(conId) then
            local con = api.engine.getComponent(conId, api.type.ComponentType.CONSTRUCTION)
            if con ~= nil then
                return #con.stations > 0 or #con.depots > 0
            end
        end
        return false
    end,

    ---comment
    ---@param baseEdge integer
    ---@return integer[]
    getSignalIds = function(baseEdge)
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
    end,
    isSignalAgainstEdgeDirection = _isSignalAgainstEdgeDirection,
}

---@param baseEdge table
---@param signalIds_indexed table<integer, boolean>
---@return integer|false
local _tryGetAnyOfTheGivenSignals = function(baseEdge, signalIds_indexed)
    for _, object in pairs(baseEdge.objects) do
        if object ~= nil and object[1] ~= nil then
            logger.print('_tryGetAnyOfTheGivenSignals got ' .. tostring(signalIds_indexed[object[1]]))
            if signalIds_indexed[object[1]] then -- can be true or nil
                logger.print('_tryGetAnyOfTheGivenSignals about to return ' .. object[1])
                return object[1]
            end
        end
    end

    return false
end

---@param edgeId integer
---@param baseEdge table
---@param startNodeId integer
---@param priorityEdgeIds integer[] changes!
---@return {baseEdge: table, edgeId: integer, inEdgeId: integer, isIntersectionFound: boolean, isGoAhead: boolean, isInEdgeDirTowardsIntersection: boolean, nodeId: integer, priorityEdgeIds: integer[], startNodeId: integer}
local _findNextIntersectionBehind = function(edgeId, baseEdge, startNodeId, priorityEdgeIds)
    logger.print('_findNextIntersectionBehind starting, edgeId_ = ' .. edgeId .. ', startNodeId_ = ' .. startNodeId)
    local nextEdgeIds = funcs.getConnectedEdgeIdsExceptOne(edgeId, startNodeId)
    local nextEdgeIdsCount = #nextEdgeIds

    -- elseif funcs.isEdgeFrozen_FAST(edgeId) then -- station or depot: do nothing
    --     return { isGoAhead = false, priorityEdgeIds = priorityEdgeIds }
    if _hasOpposingOneWaySignals(baseEdge, startNodeId) then -- baseEdge has opposing one-way signals: stop looking coz no trains will get through
        logger.print('opposing one-way signals found, leaving')
        return {
            isGoAhead = false,
            priorityEdgeIds = priorityEdgeIds,
        }
    end

    table.insert(priorityEdgeIds, edgeId)

    if nextEdgeIdsCount == 0 then -- end of line: stop looking coz no intersections will come up
        return {
            isGoAhead = false,
            priorityEdgeIds = priorityEdgeIds,
        }
    elseif nextEdgeIdsCount == 1 then -- try the next edge
        local nextEdgeId = nextEdgeIds[1]
        local nextBaseEdge = api.engine.getComponent(nextEdgeId, api.type.ComponentType.BASE_EDGE)
        return {
            baseEdge = nextBaseEdge,
            edgeId = nextEdgeId,
            isGoAhead = true,
            priorityEdgeIds = priorityEdgeIds,
            startNodeId = startNodeId == nextBaseEdge.node0 and nextBaseEdge.node1 or nextBaseEdge.node0
        }
    else -- startNodeId is an intersection
        return {
            inEdgeId = edgeId,
            isIntersectionFound = true,
            isGoAhead = false,
            isInEdgeDirTowardsIntersection = startNodeId == baseEdge.node1,
            priorityEdgeIds = priorityEdgeIds,
            nodeId = startNodeId,
        }
    end
end

---@class intersectionOrPrioritySignalProps
---@field baseEdge table, 
---@field edgeId integer, 
---@field inEdgeId integer, 
---@field isIntersectionFound boolean,
---@field isGoAhead boolean,
---@field isInEdgeDirTowardsIntersection boolean,
---@field isPrioritySignalFound boolean,
---@field nodeId integer,
---@field priorityEdgeIds integer[],
---@field innerSignalId integer,
---@field startNodeId integer

-- Stop the search at the first intersection or at the first priority signal, whichever comes first.
-- Searches based on other signals will pick it up from there, and I will concatenate the results.
---@param startSignalId integer
---@param edgeId integer
---@param baseEdge table
---@param startNodeId integer
---@param priorityEdgeIds integer[] changes!
---@param prioritySignalIds_indexed table<integer, boolean> --signalId, true
---@return intersectionOrPrioritySignalProps
local _findNextIntersectionOrPrioritySignalBehind = function(startSignalId, edgeId, baseEdge, startNodeId, priorityEdgeIds, prioritySignalIds_indexed)
    logger.print('_findNextIntersectionOrPrioritySignalBehind starting, edgeId_ = ' .. edgeId .. ', startNodeId_ = ' .. startNodeId)
    local nextEdgeIds = funcs.getConnectedEdgeIdsExceptOne(edgeId, startNodeId)
    local nextEdgeIdsCount = #nextEdgeIds

    -- elseif funcs.isEdgeFrozen_FAST(edgeId) then -- station or depot: do nothing
    --     return { isGoAhead = false, priorityEdgeIds = priorityEdgeIds }
    if _hasOpposingOneWaySignals(baseEdge, startNodeId) then -- baseEdge has opposing one-way signals: stop looking coz no trains will get through
        logger.print('opposing one-way signals found, leaving')
        return {
            isGoAhead = false,
            priorityEdgeIds = priorityEdgeIds,
        }
    end
    local prioritySignalIdOnEdge = _tryGetAnyOfTheGivenSignals(baseEdge, prioritySignalIds_indexed)
    if prioritySignalIdOnEdge and prioritySignalIdOnEdge ~= startSignalId then
        logger.print('prioritySignalIdOnEdge is ' .. tostring(prioritySignalIdOnEdge) .. ', it is not the start signal id, leaving')
        return {
            isPrioritySignalFound = true,
            isGoAhead = false,
            priorityEdgeIds = priorityEdgeIds,
            innerSignalId = prioritySignalIdOnEdge,
        }
    end

    table.insert(priorityEdgeIds, edgeId)

    if nextEdgeIdsCount == 0 then -- end of line: stop looking coz no intersections will come up
        return {
            isGoAhead = false,
            priorityEdgeIds = priorityEdgeIds,
        }
    elseif nextEdgeIdsCount == 1 then -- try the next edge
        local nextEdgeId = nextEdgeIds[1]
        local nextBaseEdge = api.engine.getComponent(nextEdgeId, api.type.ComponentType.BASE_EDGE)
        return {
            baseEdge = nextBaseEdge,
            edgeId = nextEdgeId,
            isGoAhead = true,
            priorityEdgeIds = priorityEdgeIds,
            startNodeId = startNodeId == nextBaseEdge.node0 and nextBaseEdge.node1 or nextBaseEdge.node0
        }
    else -- startNodeId is an intersection
        return {
            inEdgeId = edgeId,
            isIntersectionFound = true,
            isGoAhead = false,
            isInEdgeDirTowardsIntersection = startNodeId == baseEdge.node1,
            priorityEdgeIds = priorityEdgeIds,
            nodeId = startNodeId,
        }
    end
end

---@param edgeId integer
---@param baseEdge table
---@param startNodeId integer
---@param priorityEdgeIds integer[] changes!
---@return {baseEdge: table, edgeId: integer, isGoAhead: boolean, priorityEdgeIds: integer[], startNodeId: integer}
local _findPrecedingPriorityEdgeId = function(edgeId, baseEdge, startNodeId, priorityEdgeIds)
    logger.print('_findPrecedingPriorityEdgeId starting, edgeId_ = ' .. edgeId .. ', startNodeId_ = ' .. startNodeId)
    local nextEdgeIds = funcs.getConnectedEdgeIdsExceptOne(edgeId, startNodeId)
    local nextEdgeIdsCount = #nextEdgeIds

    -- elseif funcs.isEdgeFrozen_FAST(edgeId) then -- station or depot: do nothing
    --     return { isGoAhead = false, }
    if _hasOneWaySignalsAlong(baseEdge, startNodeId) then -- baseEdge has opposing one-way signals: stop looking coz no trains will get through
        -- I not() it here coz we are going against the signals here
        -- LOLLO TODO fixed this, check it a bit longer
        logger.print('opposing one-way signals found, leaving')
        return {
            isGoAhead = false,
            priorityEdgeIds = priorityEdgeIds,
        }
    end

    table.insert(priorityEdgeIds, edgeId)

    if nextEdgeIdsCount == 0 then -- end of line: stop looking coz no intersections will come up
        return {
            isGoAhead = false,
            priorityEdgeIds = priorityEdgeIds,
        }
    elseif nextEdgeIdsCount == 1 then -- try the next edge
        local nextEdgeId = nextEdgeIds[1]
        local nextBaseEdge = api.engine.getComponent(nextEdgeId, api.type.ComponentType.BASE_EDGE)
        return {
            baseEdge = nextBaseEdge,
            edgeId = nextEdgeId,
            isGoAhead = true,
            priorityEdgeIds = priorityEdgeIds,
            startNodeId = startNodeId == nextBaseEdge.node0 and nextBaseEdge.node1 or nextBaseEdge.node0
        }
    else -- startNodeId is an intersection
        return {
            isGoAhead = false,
            priorityEdgeIds = priorityEdgeIds,
        }
    end
end
---@param signalId integer
---@param prioritySignalIds_indexed table<integer, boolean> --signalId, true
---@return intersectionOrPrioritySignalProps
funcs.getNextIntersectionBehind = function(signalId, prioritySignalIds_indexed)
    logger.print('getNextIntersection starting, signalId = ' .. signalId)

    local _isSignalAgainst, _signalEdgeId = funcs.isSignalAgainstEdgeDirection(signalId)
    logger.print('isSignalAgainst = ' .. tostring(_isSignalAgainst))
    local _signalBaseEdge = api.engine.getComponent(_signalEdgeId, api.type.ComponentType.BASE_EDGE)

    local startNodeId = _isSignalAgainst and _signalBaseEdge.node0 or _signalBaseEdge.node1
    -- local intersectionProps = _findNextIntersectionBehind(_signalEdgeId, _signalBaseEdge, startNodeId, {})
    local intersectionProps = _findNextIntersectionOrPrioritySignalBehind(signalId, _signalEdgeId, _signalBaseEdge, startNodeId, {}, prioritySignalIds_indexed)
    local count, _maxCount = 1, constants.maxNSegmentsBeforeIntersection
    while intersectionProps.isGoAhead and count <= _maxCount do
        -- intersectionProps = _findNextIntersectionBehind(intersectionProps.edgeId, intersectionProps.baseEdge, intersectionProps.startNodeId, intersectionProps.priorityEdgeIds)
        intersectionProps = _findNextIntersectionOrPrioritySignalBehind(signalId, intersectionProps.edgeId, intersectionProps.baseEdge, intersectionProps.startNodeId, intersectionProps.priorityEdgeIds, prioritySignalIds_indexed)
        count = count + 1
    end
    -- if the priority signal follows a station, check the whole stretch of track in the station.
    -- This way, any train of any length leaving the station will have priority.
    -- This ensures that a priority train gets priority as soon as it starts moving out of a station.
    if (intersectionProps.isIntersectionFound or intersectionProps.isPrioritySignalFound) and constants.maxNSegmentsBeforePrioritySignal > 1 then
        startNodeId = _isSignalAgainst and _signalBaseEdge.node1 or _signalBaseEdge.node0
        local precedingEdgeProps = _findPrecedingPriorityEdgeId(_signalEdgeId, _signalBaseEdge, startNodeId, {})
        count, _maxCount = 1, constants.maxNSegmentsBeforePrioritySignal
        local precedingPriorityEdgeIds = {} -- set it here to leave out _signalEdgeId, which is already in.
        local isEdgeFrozenInStation, wasEdgeFrozenInStation = false, false
        while precedingEdgeProps.isGoAhead and (count <= _maxCount or isEdgeFrozenInStation) do
            precedingEdgeProps = _findPrecedingPriorityEdgeId(precedingEdgeProps.edgeId, precedingEdgeProps.baseEdge, precedingEdgeProps.startNodeId, precedingPriorityEdgeIds)
            count = count + 1
            isEdgeFrozenInStation = funcs.isEdgeFrozenInStation_FAST(precedingEdgeProps.edgeId)
            if isEdgeFrozenInStation then wasEdgeFrozenInStation = true end
        end
        if wasEdgeFrozenInStation then
            arrayUtils.concatValues(intersectionProps.priorityEdgeIds, precedingPriorityEdgeIds)
        end
    end

    logger.print('getNextIntersectionBehind about to return') logger.debugPrint(intersectionProps)
    return intersectionProps
end

---@param bitsBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId table<integer, table<integer, {isInEdgeDirTowardsIntersection: boolean, priorityEdgeIds: integer[], outerSignalId: integer}>>
---@param prioritySignalIds_indexed table<integer, boolean>
---@return table<integer, table<integer, {inEdgeId: integer, isGiveWayEdgeDirTowardsIntersection: boolean, isInEdgeDirTowardsIntersection: boolean, nodeIdTowardsIntersection: integer}>> -- intersection node id, edgeId that gives way, its direction, nodeId towards intersection
funcs.getGiveWaySignalsOrStations = function(bitsBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId, prioritySignalIds_indexed)
    local bitsBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay = {}

    local _addEdgeGivingWay = function(edgeIdGivingWay, baseEdge, nodeIdTowardsIntersection, intersectionNodeId, inEdgeId, isInEdgeDirTowardsIntersection)
        logger.print('_addEdgeGivingWay starting, edgeIdGivingWay = ' .. edgeIdGivingWay)
        if not(bitsBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay[intersectionNodeId]) then
            bitsBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay[intersectionNodeId] =
            {[edgeIdGivingWay] = {
                inEdgeId = inEdgeId,
                isGiveWayEdgeDirTowardsIntersection = baseEdge.node1 == nodeIdTowardsIntersection,
                isInEdgeDirTowardsIntersection = isInEdgeDirTowardsIntersection,
                nodeIdTowardsIntersection = nodeIdTowardsIntersection,
            }}
        else
            bitsBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay[intersectionNodeId][edgeIdGivingWay] = {
                inEdgeId = inEdgeId,
                isGiveWayEdgeDirTowardsIntersection = baseEdge.node1 == nodeIdTowardsIntersection,
                isInEdgeDirTowardsIntersection = isInEdgeDirTowardsIntersection,
                nodeIdTowardsIntersection = nodeIdTowardsIntersection,
            }
        end
    end
    local _getNext4 = function(edgeId, commonNodeId, inEdgeId, intersectionNodeId, isInEdgeDirTowardsIntersection, count, bitsBeforeIntersection_indexedBy_inEdgeId)
        logger.print('_getNext4 starting, edgeId = ' .. edgeId .. ', commonNodeId = ' .. commonNodeId)
        -- logger.print('bitsBeforeIntersection_indexedBy_inEdgeId[edgeId] =') logger.debugPrint(bitsBeforeIntersection_indexedBy_inEdgeId[edgeId])
        if bitsBeforeIntersection_indexedBy_inEdgeId[edgeId] ~= nil then
            -- this edge enters the intersection behind the priority light: if I am here, I have gone too far back
            logger.print('this edge leads from a priority signal into the intersection')
            return { isGoAhead = false }
        end
        local baseEdge = api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE)
        if baseEdge.node0 == intersectionNodeId then
            logger.print('baseEdge.node0 == intersectionNodeId')
            inEdgeId = edgeId
            isInEdgeDirTowardsIntersection = false
        elseif baseEdge.node1 == intersectionNodeId then
            logger.print('baseEdge.node1 == intersectionNodeId')
            inEdgeId = edgeId
            isInEdgeDirTowardsIntersection = true
        end

        local signalIdsInEdge = funcs.getSignalIds(baseEdge)
        if #signalIdsInEdge > 0 then -- this is it
            logger.print('this edge has signals')
            -- get out if there is a priority signal on this edge, you don't want to compete.
            -- If there are more signals on the same edge, tough, get out anyway.
            for _, signalId in pairs(signalIdsInEdge) do
                if prioritySignalIds_indexed[signalId] then
                    logger.print('one of these signals has priority, don\'t want to compete, leaving')
                    return { isGoAhead = false }
                end
            end
            -- check if the intersection is reachable from both ends of the edge, there could be a light blocking it or a cross instead of a switch
            -- You might check this before checking the lights, and leave if isPath is false LOLLO TODO check if it is faster that way
            if funcs.getIsPathFromEdgeToNode(edgeId, intersectionNodeId, constants.maxDistanceFromIntersection) then
                _addEdgeGivingWay(edgeId, baseEdge, commonNodeId, intersectionNodeId, inEdgeId, isInEdgeDirTowardsIntersection)
            end
            return {
                inEdgeId = inEdgeId,
                isGoAhead = false,
                isInEdgeDirTowardsIntersection = isInEdgeDirTowardsIntersection
            }
        elseif funcs.isEdgeFrozenInStationOrDepot_FAST(edgeId) then -- station
            logger.print('this edge is frozen in a station or a depot')
            -- check if the intersection is reachable from both ends of the edge, there could be a light blocking it or a cross instead of a switch
            if funcs.getIsPathFromEdgeToNode(edgeId, intersectionNodeId, constants.maxDistanceFromIntersection) then
                _addEdgeGivingWay(edgeId, baseEdge, commonNodeId, intersectionNodeId, inEdgeId, isInEdgeDirTowardsIntersection)
            end
            return {
                inEdgeId = inEdgeId,
                isGoAhead = false,
                isInEdgeDirTowardsIntersection = isInEdgeDirTowardsIntersection
            }
        else -- go ahead with the next edge(s)
            if baseEdge.node0 ~= commonNodeId and baseEdge.node1 ~= commonNodeId then
                logger.warn('baseEdge.node0 ~= commonNodeId and baseEdge.node1 ~= commonNodeId')
                return {
                    inEdgeId = inEdgeId,
                    isGoAhead = false,
                    isInEdgeDirTowardsIntersection = isInEdgeDirTowardsIntersection
                }
            end
            if count > 1 and (baseEdge.node0 == intersectionNodeId or baseEdge.node1 == intersectionNodeId) then
                logger.print('going back, leave this branch')
                return {
                    inEdgeId = inEdgeId,
                    isGoAhead = false,
                    isInEdgeDirTowardsIntersection = isInEdgeDirTowardsIntersection
                }
            end
            logger.print('need to look farther')
            return {
                inEdgeId = inEdgeId,
                isGoAhead = true,
                isInEdgeDirTowardsIntersection = isInEdgeDirTowardsIntersection,
                newNodeId = baseEdge.node0 == commonNodeId and baseEdge.node1 or baseEdge.node0
            }
        end
    end

    local _getNext3 = function(edgeId, commonNodeId, inEdgeId, intersectionNodeId, isInEdgeDirTowardsIntersection, getNext2Func, count, bitsBeforeIntersection_indexedBy_inEdgeId)
        logger.print('_getNext3 starting, edgeId = ' .. edgeId .. ', commonNodeId = ' .. commonNodeId)
        local next = _getNext4(edgeId, commonNodeId, inEdgeId, intersectionNodeId, isInEdgeDirTowardsIntersection, count, bitsBeforeIntersection_indexedBy_inEdgeId)
        if next.isGoAhead then
            if count < constants.maxNSegmentsBehindIntersection then
                local connectedEdgeIds = funcs.getConnectedEdgeIdsExceptOne(edgeId, next.newNodeId)
                getNext2Func(connectedEdgeIds, next.newNodeId, next.inEdgeId, intersectionNodeId, next.isInEdgeDirTowardsIntersection, getNext2Func, count, bitsBeforeIntersection_indexedBy_inEdgeId)
                logger.print('count = ' .. count)
            else
                logger.print('too many attempts, leaving')
            end
        end
    end
    local _getNext2 = function(connectedEdgeIds, commonNodeId, inEdgeId, intersectionNodeId, isInEdgeDirTowardsIntersection, getNext2Func, count, bitsBeforeIntersection_indexedBy_inEdgeId)
        logger.print('_getNext2 starting, commonNodeId = ' .. commonNodeId .. ', connectedEdgeIds =') logger.debugPrint(connectedEdgeIds)
        count = count + 1
        for _, edgeId in pairs(connectedEdgeIds) do
            _getNext3(edgeId, commonNodeId, inEdgeId, intersectionNodeId, isInEdgeDirTowardsIntersection, getNext2Func, count, bitsBeforeIntersection_indexedBy_inEdgeId)
        end
    end

    for intersectionNodeId, bitsBeforeIntersection_indexedBy_inEdgeId in pairs(bitsBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId) do
        local connectedEdgeIds = funcs.getConnectedEdgeIdsExceptSome(bitsBeforeIntersection_indexedBy_inEdgeId, intersectionNodeId)
        logger.print('_getNext1 got intersectionNodeId = ' .. intersectionNodeId .. ', connectedEdgeIds =') logger.debugPrint(connectedEdgeIds)
        _getNext2(connectedEdgeIds, intersectionNodeId, nil, intersectionNodeId, nil, _getNext2, 0, bitsBeforeIntersection_indexedBy_inEdgeId)
    end

    return bitsBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay
end

return funcs
