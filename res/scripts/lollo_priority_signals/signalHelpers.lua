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

---@param edgeObjectId integer
---@param refModelId1 integer
---@param refModelId2 integer
---@param refModelId3 integer
---@return boolean
local _isEdgeObjectIdWithModelIds = function(edgeObjectId, refModelId1, refModelId2, refModelId3)
    if not(_isValidAndExistingId(edgeObjectId)) then return false end

    local modelInstanceList = api.engine.getComponent(edgeObjectId, api.type.ComponentType.MODEL_INSTANCE_LIST)
    return modelInstanceList ~= nil
    and modelInstanceList.fatInstances ~= nil
    and modelInstanceList.fatInstances[1] ~= nil
    and (
        modelInstanceList.fatInstances[1].modelId == refModelId1
        or modelInstanceList.fatInstances[1].modelId == refModelId2
        or modelInstanceList.fatInstances[1].modelId == refModelId3
    )
end

---@param edgeObjectIds_indexed table<integer, any>
---@param refModelId1 integer
---@param refModelId2 integer
---@param refModelId3 integer
---@return table<integer, boolean>
local _getEdgeObjectsIdsWithModelIds_indexed = function(edgeObjectIds_indexed, refModelId1, refModelId2, refModelId3, isCanYield)
    -- local isRestartTimer, _startTick_sec = true, 0
    local results = {}
    local count = 0
    for edgeObjectId, _ in pairs(edgeObjectIds_indexed) do
        -- if logger.isExtendedLog() and isRestartTimer then
        --     _startTick_sec = os.clock()
        --     isRestartTimer = false
        -- end
        if _isEdgeObjectIdWithModelIds(edgeObjectId, refModelId1, refModelId2, refModelId3) then
            results[edgeObjectId] = true
        end
        if isCanYield then -- LOLLO NOTE the coroutine is not always active at this point, the call might come from the UI
            count = count + 1
            if count > constants.numGetEdgeObjectsPerTick then
                logger.print('_getEdgeObjectsIdsWithModelIds_indexed about to yield')
                coroutine.yield()
                logger.print('_getEdgeObjectsIdsWithModelIds_indexed just yielded')
                count = 0
            end
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
---@param objectId integer
---@return boolean
local _isObjectASignal = function(objectId)
    if not(_isValidAndExistingId(objectId)) then return false end

    local signalList = api.engine.getComponent(objectId, api.type.ComponentType.SIGNAL_LIST)
    if signalList == nil or signalList.signals == nil then return false end

    local signal = signalList.signals[1] -- signalList.signals is userdata
    if signal == nil then return false end

    -- signal.type == 0 -- two-way signal
    -- signal.type == 1 -- one-way signal
    -- signal.type == 2 -- waypoint
    return (signal.type == 0) or (signal.type == 1)
end
---@param baseEdge any
---@return boolean
local _isEdgeWithSignals = function (baseEdge)
    if baseEdge == nil or type(baseEdge.objects) ~= 'table' then return false end

    for _, object in pairs(baseEdge.objects) do
        local objectId = object[1]
        if _isObjectASignal(objectId) then return true end
    end
    return false
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
    isEdgeObjectIdWithModelIds = _isEdgeObjectIdWithModelIds,
    ---returns indexed table of edgeObjectIds
    ---@param refModelId1 integer
    ---@param refModelId2 integer
    ---@param refModelId3 integer
    ---@param isCanYield boolean set to false if calling from outside the coroutine
    ---@return table<integer, boolean>
    getAllEdgeObjectsWithModelIds_indexed = function(refModelId1, refModelId2, refModelId3, isCanYield)
        return _getEdgeObjectsIdsWithModelIds_indexed(api.engine.system.streetSystem.getEdgeObject2EdgeMap(), refModelId1, refModelId2, refModelId3, isCanYield)
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
    ---checks if there is a path from both ends of an edge to a node, starting from the edge
    ---@param edgeId integer
    ---@param nodeId integer
    ---@param maxDistance number
    ---@return boolean
    getIsPathFromEdgeToNode = function(edgeId, nodeId, maxDistance)
        local isPathsFound = {}
        local maxIndex = #api.engine.getComponent(edgeId, api.type.ComponentType.TRANSPORT_NETWORK).edges - 1

        for i = 0, maxIndex, 1 do -- signals split edges in multiple chunks
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
            isPathsFound[i] = false
            -- logger.print('index = ' .. i .. ', myPath =') logger.debugPrint(myPath)
            -- print('index = ' .. i .. ', myPath =') debugPrint(myPath)
            for _, value in pairs(myPath) do
                isPathsFound[i] = true
                break
            end
            if not(isPathsFound[i]) then return false end
        end

        return true
    end,
    isEdgeFrozen_FAST = function(edgeId)
        if not(_isValidAndExistingId(edgeId)) then return false end

        local conId = api.engine.system.streetConnectorSystem.getConstructionEntityForEdge(edgeId)
        return _isValidAndExistingId(conId)
    end,
    -- this is slow, even if it is called FAST
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
    -- this is slow, even if it is called FAST
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
    ---@param baseEdge any
    ---@return integer[]
    getSignalIds = function(baseEdge)
        local results = {}
        if baseEdge == nil or type(baseEdge.objects) ~= "table" then return results end

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
        coroutine.yield()
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
            coroutine.yield()
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

---@alias bitsBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId table<integer, table<integer, {isInEdgeDirTowardsIntersection: boolean, priorityEdgeIds: integer[], outerSignalId: integer}>>
---@alias bitsBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay table<integer, table<integer, {inEdgeId: integer, isGiveWayEdgeDirTowardsIntersection: boolean, isInEdgeDirTowardsIntersection: boolean, nodeIdTowardsIntersection: integer}>>
---@param bitsBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId bitsBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId
---@param prioritySignalIds_indexed table<integer, boolean>
---@return bitsBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay
funcs.getGiveWaySignalsOrStations = function(bitsBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId, prioritySignalIds_indexed)
    -- result
    ---@type bitsBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay
    local bitsBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay = {}
    -- buffer
    local checkedEdges_indexedBy_intersectionNodeId_edgeId = {}
    -- buffer
    local frozenEdges_indexed = {}
    -- funcs
    local _addEdgeGivingWay = function(edgeId, baseEdge, nodeIdTowardsIntersection, intersectionNodeId, inEdgeId, isInEdgeDirTowardsIntersection)
        logger.print('_addEdgeGivingWay starting, edgeIdGivingWay = ' .. edgeId)
        local newRecord = {
            checkedNodeIds = {},
            inEdgeId = inEdgeId,
            isGiveWayEdgeDirTowardsIntersection = (baseEdge.node1 == nodeIdTowardsIntersection),
            isInEdgeDirTowardsIntersection = isInEdgeDirTowardsIntersection,
            nodeIdTowardsIntersection = nodeIdTowardsIntersection,
        }
        bitsBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay[intersectionNodeId][edgeId] = newRecord
    end
    local _getIsPathToNode = function(edgeIds_indexed, nodeId)
        for intersectionInEdgeId, _ in pairs(edgeIds_indexed) do
            if funcs.getIsPathFromEdgeToNode(intersectionInEdgeId, nodeId, constants.maxDistanceFromIntersection) then
                return true
            end
        end
        return false
    end
    local _getDeepCopiedListWithNewItem = function(list, newItem)
        local results = {}
        for _, item in pairs(list) do
            results[#results+1] = item
        end
        results[#results+1] = newItem
        return results
    end

    local recursiveFuncs
    recursiveFuncs = {
        getNext4 = function(intersectionNodeId, bitsBeforeIntersection_indexedBy_inEdgeId, edgeId, commonNodeId, commonNodeIds, inEdgeId, isInEdgeDirTowardsIntersection, nSegmentsFromIntersection)
            logger.print('_getNext4 starting, edgeId = ' .. edgeId .. ', commonNodeId = ' .. commonNodeId)
            -- logger.print('bitsBeforeIntersection_indexedBy_inEdgeId[edgeId] =') logger.debugPrint(bitsBeforeIntersection_indexedBy_inEdgeId[edgeId])
            if checkedEdges_indexedBy_intersectionNodeId_edgeId[intersectionNodeId][edgeId] then
                logger.print('I checked this edge already, leaving')
                return { checkedNodeIds = {}, isGoAhead = false }
            end
            checkedEdges_indexedBy_intersectionNodeId_edgeId[intersectionNodeId][edgeId] = true
            if bitsBeforeIntersection_indexedBy_inEdgeId[edgeId] ~= nil then
                -- this edge enters the intersection behind the priority light: if I am here, I have gone too far back
                logger.print('this edge leads from a priority signal into the intersection')
                return { checkedNodeIds = {}, isGoAhead = false }
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
                        return { checkedNodeIds = {}, isGoAhead = false }
                    end
                end

                -- check if trains can run on the edge out->in
                if funcs.getIsPathFromEdgeToNode(edgeId, commonNodeId, constants.maxDistanceFromIntersection) then
                    -- check if there is a path from intersection to any common nodes
                    local _checkedNodeIds = _getDeepCopiedListWithNewItem(commonNodeIds, commonNodeId)
                    logger.print('_checkedNodeIds =') logger.debugPrint(_checkedNodeIds)
                    local isAnyNodesShared = false
                    for _, nodeId in pairs(_checkedNodeIds) do
                        if funcs.getIsPathFromEdgeToNode(edgeId, nodeId, constants.maxDistanceFromIntersection)
                        and _getIsPathToNode(bitsBeforeIntersection_indexedBy_inEdgeId, nodeId)
                        then
                            isAnyNodesShared = true
                            break
                        end
                    end
                    if isAnyNodesShared then
                        _addEdgeGivingWay(edgeId, baseEdge, commonNodeId, intersectionNodeId, inEdgeId, isInEdgeDirTowardsIntersection)
                    else
                        logger.print('no prio paths found intersecting other paths')
                    end
                else
                    logger.print('no path found from edge ' .. (edgeId or 'NIL') .. ' to node ' .. (intersectionNodeId or 'NIL'))
                end
                return {
                    checkedNodeIds = {},
                    inEdgeId = inEdgeId,
                    isGoAhead = false,
                    isInEdgeDirTowardsIntersection = isInEdgeDirTowardsIntersection
                }
            elseif frozenEdges_indexed[edgeId] or funcs.isEdgeFrozenInStationOrDepot_FAST(edgeId) then -- station or depot, try the buffer first
                logger.print('this edge is frozen in a station or a depot')
                frozenEdges_indexed[edgeId] = true
                -- check if trains can run on the edge out->in
                if funcs.getIsPathFromEdgeToNode(edgeId, commonNodeId, constants.maxDistanceFromIntersection) then
                    -- check if there is a path from intersection to any common nodes
                    local _checkedNodeIds = _getDeepCopiedListWithNewItem(commonNodeIds, commonNodeId)
                    logger.print('_checkedNodeIds =') logger.debugPrint(_checkedNodeIds)
                    local isAnyNodesShared = false
                    for _, nodeId in pairs(_checkedNodeIds) do
                        if funcs.getIsPathFromEdgeToNode(edgeId, nodeId, constants.maxDistanceFromIntersection)
                        and _getIsPathToNode(bitsBeforeIntersection_indexedBy_inEdgeId, nodeId)
                        then
                            isAnyNodesShared = true
                            break
                        end
                    end
                    if isAnyNodesShared then
                        _addEdgeGivingWay(edgeId, baseEdge, commonNodeId, intersectionNodeId, inEdgeId, isInEdgeDirTowardsIntersection)
                    else
                        logger.print('no prio paths found intersecting other paths')
                    end
                else
                    logger.print('no path found from edge ' .. (edgeId or 'NIL') .. ' to node ' .. (intersectionNodeId or 'NIL'))
                end
                return {
                    checkedNodeIds = {},
                    inEdgeId = inEdgeId,
                    isGoAhead = false,
                    isInEdgeDirTowardsIntersection = isInEdgeDirTowardsIntersection
                }
            else -- go ahead with the next edge(s)
                if baseEdge.node0 ~= commonNodeId and baseEdge.node1 ~= commonNodeId then
                    logger.warn('baseEdge.node0 ~= commonNodeId and baseEdge.node1 ~= commonNodeId, this should never happen')
                    return {
                        checkedNodeIds = {},
                        inEdgeId = inEdgeId,
                        isGoAhead = false,
                        isInEdgeDirTowardsIntersection = isInEdgeDirTowardsIntersection
                    }
                end
                if nSegmentsFromIntersection > 1 and (baseEdge.node0 == intersectionNodeId or baseEdge.node1 == intersectionNodeId) then
                    logger.print('you are going back, leave this branch')
                    return {
                        checkedNodeIds = {},
                        inEdgeId = inEdgeId,
                        isGoAhead = false,
                        isInEdgeDirTowardsIntersection = isInEdgeDirTowardsIntersection
                    }
                end
                logger.print('need to look farther')
                return {
                    checkedNodeIds = _getDeepCopiedListWithNewItem(commonNodeIds, commonNodeId),
                    inEdgeId = inEdgeId,
                    isGoAhead = true,
                    isInEdgeDirTowardsIntersection = isInEdgeDirTowardsIntersection,
                    newNodeId = baseEdge.node0 == commonNodeId and baseEdge.node1 or baseEdge.node0
                }
            end
        end,
        getNext3 = function(intersectionNodeId, bitsBeforeIntersection_indexedBy_inEdgeId, edgeId, commonNodeId, commonNodeIds, inEdgeId, isInEdgeDirTowardsIntersection, nSegmentsFromIntersection, nSegmentsChecked)
            logger.print('_getNext3 starting, edgeId = ' .. edgeId .. ', commonNodeId = ' .. commonNodeId)
            local next = recursiveFuncs.getNext4(
                intersectionNodeId,
                bitsBeforeIntersection_indexedBy_inEdgeId,
                edgeId,
                commonNodeId,
                commonNodeIds,
                inEdgeId,
                isInEdgeDirTowardsIntersection,
                nSegmentsFromIntersection
            )
            nSegmentsChecked = nSegmentsChecked + 1
            -- logger.print('expensive check done, nSegmentsChecked = ' .. nSegmentsChecked)
            coroutine.yield()
            if next.isGoAhead then
                if nSegmentsFromIntersection < constants.maxNSegmentsBehindIntersection then
                    local connectedEdgeIds = funcs.getConnectedEdgeIdsExceptOne(edgeId, next.newNodeId)
                    recursiveFuncs.getNext2(
                        intersectionNodeId,
                        bitsBeforeIntersection_indexedBy_inEdgeId,
                        connectedEdgeIds,
                        next.newNodeId,
                        next.checkedNodeIds,
                        next.inEdgeId,
                        next.isInEdgeDirTowardsIntersection,
                        nSegmentsFromIntersection,
                        nSegmentsChecked
                    )
                    logger.print('nSegmentsFromIntersection = ' .. nSegmentsFromIntersection)
                else
                    logger.print('too many attempts, leaving')
                end
            end
        end,
        getNext2 = function(intersectionNodeId, bitsBeforeIntersection_indexedBy_inEdgeId, connectedEdgeIds, commonNodeId, commonNodeIds, inEdgeId, isInEdgeDirTowardsIntersection, nSegmentsFromIntersection, nSegmentsChecked)
            logger.print('_getNext2 starting, commonNodeId = ' .. commonNodeId .. ', connectedEdgeIds =') logger.debugPrint(connectedEdgeIds)
            nSegmentsFromIntersection = nSegmentsFromIntersection + 1
            for _, edgeId in pairs(connectedEdgeIds) do
                recursiveFuncs.getNext3(
                    intersectionNodeId,
                    bitsBeforeIntersection_indexedBy_inEdgeId,
                    edgeId,
                    commonNodeId,
                    commonNodeIds,
                    inEdgeId,
                    isInEdgeDirTowardsIntersection,
                    nSegmentsFromIntersection,
                    nSegmentsChecked
                )
            end
        end,
    }

    for intersectionNodeId, bitsBeforeIntersection_indexedBy_inEdgeId in pairs(bitsBeforeIntersection_indexedBy_intersectionNodeId_inEdgeId) do
        if not(bitsBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay[intersectionNodeId]) then
            bitsBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay[intersectionNodeId] = {}
        end
        checkedEdges_indexedBy_intersectionNodeId_edgeId[intersectionNodeId] = {}
        local connectedEdgeIds = funcs.getConnectedEdgeIdsExceptSome(bitsBeforeIntersection_indexedBy_inEdgeId, intersectionNodeId)
        logger.print('_getNext1 got intersectionNodeId = ' .. intersectionNodeId .. ', connectedEdgeIds =') logger.debugPrint(connectedEdgeIds)
        recursiveFuncs.getNext2(
            intersectionNodeId,
            bitsBeforeIntersection_indexedBy_inEdgeId,
            connectedEdgeIds,
            intersectionNodeId,
            {},
            nil,
            nil,
            0,
            0
        )
        coroutine.yield()
    end

    return bitsBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay
end

return funcs
