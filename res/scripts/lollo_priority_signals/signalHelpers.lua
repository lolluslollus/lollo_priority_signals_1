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
    ---@return table<integer>
    getConnectedEdgeIds = function(refEdgeId, nodeId)
        -- print('getConnectedEdgeIds starting')
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

        -- print('getConnectedEdgeIds is about to return') debugPrint(results)
        return results
    end,
    ---comment
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
---@return {isGoAhead: boolean, edgeId: integer, startNodeId: integer, intersectionNodeId: integer}
funcs.getNextIntersection = function(signalId)
    logger.print('getNextIntersection starting, signalId = ' .. signalId)
    local isSignalAgainst, edgeId = funcs.isOneWaySignalAgainstEdgeDirection(signalId)
    logger.print('isSignalAgainst = ' .. tostring(isSignalAgainst))
    local baseEdge = api.engine.getComponent(edgeId, api.type.ComponentType.BASE_EDGE)
    if funcs.hasOpposingOneWaySignals(baseEdge) then
        logger.print('getNextIntersection found opposing one-way signals')
        logger.print('baseEdge.objects =') logger.debugPrint(baseEdge.objects)
        return {
            isGoAhead = false, -- baseEdge has opposing one-way signals: do nothing coz no trains will get through
        }
    end
    local startNodeId = isSignalAgainst and baseEdge.node0 or baseEdge.node1
    local _getNextIntersection = function(edgeId_, startNodeId_)
        local nextEdgeIds = funcs.getConnectedEdgeIds(edgeId_, startNodeId_)
        local nextEdgeIdsCount = #nextEdgeIds
        if nextEdgeIdsCount == 0 then -- end of line: do nothing
            return {
                isGoAhead = false,
            }
        elseif nextEdgeIdsCount == 1 then
            local nextEdgeId = nextEdgeIds[1]
            if edgeUtils.isEdgeFrozen(nextEdgeId) then -- station or depot: no intersections
                return {
                    isGoAhead = false,
                }
            else -- try the next edge
                local nextBaseEdge = api.engine.getComponent(nextEdgeId, api.type.ComponentType.BASE_EDGE)
                if funcs.hasOpposingOneWaySignals(nextBaseEdge) then -- nextBaseEdge has opposing one-way signals: do nothing coz no trains will get through
                    return {
                        isGoAhead = false,
                    }
                end
                return {
                    edgeId = nextEdgeId,
                    isGoAhead = true,
                    startNodeId = startNodeId_ == nextBaseEdge.node0 and nextBaseEdge.node1 or nextBaseEdge.node0
                }
            end
        else -- startNodeId is an intersection
            return {
                intersectionNodeId = startNodeId_,
                isGoAhead = false,
            }
        end
    end
    local intersectionProps = _getNextIntersection(edgeId, startNodeId)
    local count, _maxCount = 1, constants.maxNSegmentsFromIntersection
    while intersectionProps.isGoAhead and count <= _maxCount do
        intersectionProps = _getNextIntersection(intersectionProps.edgeId, intersectionProps.startNodeId)
    end

    return intersectionProps
end

return funcs
