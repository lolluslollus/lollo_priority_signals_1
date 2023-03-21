local edgeUtils = require('lollo_priority_signals.edgeUtils')
local logger = require('lollo_priority_signals.logger')

return {
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
