local logger = require ('lollo_priority_signals.logger')
local arrayUtils = require('lollo_priority_signals.arrayUtils')
local constants = require('lollo_priority_signals.constants')
local edgeUtils = require('lollo_priority_signals.edgeUtils')
local signalHelpers = require('lollo_priority_signals.signalHelpers')
local stateHelpers = require('lollo_priority_signals.stateHelpers')
local transfUtils = require('lollo_priority_signals.transfUtils')
local transfUtilsUG = require('transf')

local  _signalModelId_EraA, _signalModelId_EraC
local _texts = {

}

local nodeEdgeIdBeforeIntersection_indexedBy_intersectionNodeId_edgeIdHavingWay = {}
local nodeEdgeIdBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay -- the first is only for testing
local stoppedVehicleIds = {}

local _actions = {
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
                -- logger.print('replaceEdgeWithSameRemovingObject: newEdge.comp.objects =') logger.debugPrint(newEdge.comp.objects)
            else
                -- logger.print('replaceEdgeWithSameRemovingObject: newEdge.comp.objects = not changed')
            end
        else
            logger.print('replaceEdgeWithSameRemovingObject: objectIdToRemove is no good, it is') logger.debugPrint(objectIdToRemove)
            newEdge.comp.objects = oldEdge.objects
        end

        -- logger.print('newEdge.comp.objects:')
        -- for key, value in pairs(newEdge.comp.objects) do
        --     logger.print('key =', key) logger.debugPrint(value)
        -- end

        local proposal = api.type.SimpleProposal.new()
        proposal.streetProposal.edgesToRemove[1] = oldEdgeId
        proposal.streetProposal.edgesToAdd[1] = newEdge
        if edgeUtils.isValidAndExistingId(objectIdToRemove) then
            proposal.streetProposal.edgeObjectsToRemove[1] = objectIdToRemove
        end

        -- logger.debugPrint(proposal)
        --[[ local sampleNewEdge =
        {
        entity = -1,
        comp = {
            node0 = 13010,
            node1 = 18753,
            tangent0 = {
            x = -32.318000793457,
            y = 81.757850646973,
            z = 3.0953373908997,
            },
            tangent1 = {
            x = -34.457527160645,
            y = 80.931526184082,
            z = -1.0708819627762,
            },
            type = 0,
            typeIndex = -1,
            objects = { },
        },
        type = 0,
        params = {
            streetType = 23,
            hasBus = false,
            tramTrackType = 0,
            precedenceNode0 = 2,
            precedenceNode1 = 2,
        },
        playerOwned = nil,
        streetEdge = {
            streetType = 23,
            hasBus = false,
            tramTrackType = 0,
            precedenceNode0 = 2,
            precedenceNode1 = 2,
        },
        trackEdge = {
            trackType = -1,
            catenary = false,
        },
        } ]]

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
                -- remember game time for next cycle, its only purpose is to break while paused
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

--[[
    From my priority light, I want to go ahead until the next traffic light or intersection, whichever comes first.
    If it is a light, return
    If it is an intersection, follow it backwards until you find a traffic light or intersection, whichever comes first.
    Repeat this for every branch found at the intersection: {
        If the edge has an intersection, return
        If the edge has a priority light, return
        If the edge has no normal lights, move on to the next edge until you come back here (if you do).
        If you are too far away from the intersection, return.

        Now you have an edge with a normal light (or a station edge) (if you got here):
        Seek the next edge (to give trains a chance to stop), at a minimum distance from the light.
        If there is an intersection, return.

        Place the edgeId in a table and check it at every tick with api.engine.system.transportVehicleSystem.getVehicles({edgeId}, true),
        against my edges that has priority. There will be a number of such edges before a priority light.

        One thing may not work: a two-way signal marked as low prio might block the train on it,
        unless I add a check to see if they are going toward the intersection (and block them) or not (and let them be)
    }
    edge 24657 has two lights and two waypoints.
    api.engine.getComponent(24657, api.type.ComponentType.BASE_EDGE)
    {
        node0 = 25490,
        node1 = 25491,
        tangent0 = {
            x = -83.686164855957,
            y = -7.4706878662109,
            z = 3.5420706272125,
        },
        tangent1 = {
            x = -83.758857727051,
            y = -6.8239850997925,
            z = 3.4535164833069,
        },
        type = 0,
        typeIndex = -1,
        objects = {
            { 26666, 2, }, -- the "2" says nothing about the orientation of the light or where it is, it seems useless
            { 27524, 2, },
            { 19936, 2, },
            { 14708, 2, },
        },
    }


    api.engine.getComponent(26666, api.type.ComponentType.SIGNAL_LIST)
    {
        signals = {
            [1] = {
            edgePr = {
                new = nil,
                entity = 24657, -- edgeId
                index = 2, -- index of edge section, in base 0. Use it in api.engine.system.signalSystem.getSignal(api.type.EdgeId.new(24657, 2), true)
            },
            type = 0, -- 0 for two-way, 1 for one-way
            state = 0,
            stateTime = -1,
            },
        },
    }
    api.engine.getComponent(27524, api.type.ComponentType.SIGNAL_LIST)
    {
        signals = {
            [1] = {
            edgePr = {
                new = nil,
                entity = 24657,
                index = 1,
            },
            type = 1, -- this is one-way
            state = 0,
            stateTime = -1,
            },
        },
    }
    api.engine.getComponent(19936, api.type.ComponentType.SIGNAL_LIST)
    {
        signals = {
            [1] = {
            edgePr = {
                new = nil,
                entity = 24657,
                index = 3, -- waypoints do not split edges into segments
            },
            type = 2, -- this is a waypoint
            state = 0,
            stateTime = -1,
            },
        },
    }
    api.engine.getComponent(14708, api.type.ComponentType.SIGNAL_LIST)
    {
        signals = {
            [1] = {
            edgePr = {
                new = nil,
                entity = 24657,
                index = 3,
            },
            type = 2, -- this is a waypoint
            state = 0,
            stateTime = -1,
            },
        },
    }
    
    api.engine.system.signalSystem.getSignal(api.type.EdgeId.new(24657, 0), false)
    {
        entity = -1, -- there are no signals on this piece of edge and pointing with the yellow arrow ALONG the travelling axes
        index = 0,
    }
    api.engine.system.signalSystem.getSignal(api.type.EdgeId.new(24657, 0), true)
    {
        entity = -1, -- there are no signals on this piece of edge and pointing with the yellow arrow AGAINST the travelling axes
        index = 0,
    }
    api.engine.system.signalSystem.getSignal(api.type.EdgeId.new(24657, 1), false)
    {
        entity = -1,
        index = 0,
    }
    api.engine.system.signalSystem.getSignal(api.type.EdgeId.new(24657, 1), true)
    {
        entity = 27524, -- this is a light that has its white arrow oriented from node0 to node1 (ie the same as the little travelling axes)
        -- and its yellow arrow pointed against the little travelling axes
        -- ie if it is a one-way light, it lets traffic through from baseEdge.node0 to baseEdge.node1
        -- ie, the true parameter returns it
        index = 0,
    }
    api.engine.system.signalSystem.getSignal(api.type.EdgeId.new(24657, 2), false)
    {
        entity = -1,
        index = 0,
    }
    api.engine.system.signalSystem.getSignal(api.type.EdgeId.new(24657, 2), true)
    -- there are two light in baseEdge, so I check until index 2, ie the third segment the edge is split into
    -- it is the same "2" that comes from api.engine.getComponent(26666, api.type.ComponentType.SIGNAL_LIST)
    {
        entity = 26666,
        index = 0,
    }
    api.engine.system.signalSystem.getSignal(api.type.EdgeId.new(24657, 3), false)
    {
        entity = 14708,
        index = 0,
    }
    api.engine.system.signalSystem.getSignal(api.type.EdgeId.new(24657, 3), true)
    {
        entity = 19936,
        index = 0,
    }

    
    api.engine.getComponent(24657, api.type.ComponentType.TRANSPORT_NETWORK) (only the interesting bits)
    {
        nodes = {
            [1] = {
            },
            [2] = {
            },
        },
        edges = {
            [1] = {
                conns = {
                    [1] = {
                        new = nil,
                        entity = 25490, -- baseEdge.node0
                        index = 0,
                    },
                    [2] = {
                        new = nil,
                        entity = 24657, -- edgeId
                        index = 1,
                    },
                },
            },
            [2] = {
                conns = {
                    [1] = {
                        new = nil,
                        entity = 24657, -- edgeId
                        index = 1,
                    },
                    [2] = {
                        new = nil,
                        entity = 24657, -- edgeId
                        index = 0,
                    },
                },
            },
            [3] = {
                conns = {
                    [1] = {
                        new = nil,
                        entity = 24657,
                        index = 0,
                    },
                    [2] = {
                        new = nil,
                        entity = 24657,
                        index = 2,
                    },
                },
            },
            [4] = {
                conns = {
                    [1] = {
                        new = nil,
                        entity = 24657,
                        index = 2,
                    },
                    [2] = {
                        new = nil,
                        entity = 24657,
                        index = 3,
                    },
                },
            },
            [5] = {
                conns = {
                    [1] = {
                        new = nil,
                        entity = 24657,
                        index = 3,
                    },
                    [2] = {
                        new = nil,
                        entity = 25491, -- baseEdge.node1
                        index = 0,
                    },
                },
            },
        },
        turnaroundEdges = {
            [1] = -1,
            [2] = -1,
            [3] = -1,
            [4] = -1,
            [5] = -1,
        },
    }
]]
--[[
    A perpendicular intersection will split the edges and create a node in the middle, with 
    #api.engine.system.streetSystem.getNode2SegmentMap()[nodeId] == 4

    A switch will have a blue dot in the middle, that will be a node with
    #api.engine.system.streetSystem.getNode2SegmentMap()[nodeId] == 3
]]
--[[
    LOLLO TODO investigate api.type.ComponentType.MOVE_PATH
]]


                    ---@type table<integer, integer> --signalId, edgeId
                    local edgeIdsWithPrioritySignals_indexedBy_signalId = {}
                    -- nodeId, inEdgeId, props
                    -- By construction, I cannot have more than one priority signal on any edge.
                    -- However, different priority signals might share the same intersection node,
                    -- so I have a table of tables.
                    ---@type table<integer, table<integer, {isHaveWayEdgeDirTowardsIntersection: boolean, signalEdgeId: integer, signalId: integer}>>
                    nodeEdgeIdBeforeIntersection_indexedBy_intersectionNodeId_edgeIdHavingWay = {}
                    for _, signalId in pairs(allPrioritySignalIds) do
                        edgeIdsWithPrioritySignals_indexedBy_signalId[signalId] = _edgeObject2EdgeMap[signalId]
                        local intersectionProps = signalHelpers.getNextIntersectionBehind(signalId)
                        if intersectionProps.isFound then
                            if not(nodeEdgeIdBeforeIntersection_indexedBy_intersectionNodeId_edgeIdHavingWay[intersectionProps.nodeId]) then
                                nodeEdgeIdBeforeIntersection_indexedBy_intersectionNodeId_edgeIdHavingWay[intersectionProps.nodeId] =
                                {[intersectionProps.inEdgeId] = {
                                    isHaveWayEdgeDirTowardsIntersection = intersectionProps.isHaveWayEdgeDirTowardsIntersection,
                                    signalEdgeId = _edgeObject2EdgeMap[signalId],
                                    signalId = signalId
                                }}
                            else
                                nodeEdgeIdBeforeIntersection_indexedBy_intersectionNodeId_edgeIdHavingWay[intersectionProps.nodeId][intersectionProps.inEdgeId] =
                                {
                                    isHaveWayEdgeDirTowardsIntersection = intersectionProps.isHaveWayEdgeDirTowardsIntersection,
                                    signalEdgeId = _edgeObject2EdgeMap[signalId],
                                    signalId = signalId
                                }
                            end
                        end
                    end
                    logger.print('nodeEdgeIdBeforeIntersection_indexedBy_intersectionNodeId_edgeIdHavingWay =') logger.debugPrint(nodeEdgeIdBeforeIntersection_indexedBy_intersectionNodeId_edgeIdHavingWay)
                    logger.print('edgeIdsWithPrioritySignals_indexedBy_signalId =') logger.debugPrint(edgeIdsWithPrioritySignals_indexedBy_signalId)

                    nodeEdgeIdBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay = signalHelpers.getNextLightsOrStations(nodeEdgeIdBeforeIntersection_indexedBy_intersectionNodeId_edgeIdHavingWay, edgeIdsWithPrioritySignals_indexedBy_signalId)
                    logger.print('nodeEdgeIdBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay =') logger.debugPrint(nodeEdgeIdBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay)

                    if logger.isExtendedLog() then
                        local executionTime = math.ceil((os.clock() - _startTick) * 1000)
                        logger.print('Finding edges and nodes took ' .. executionTime .. 'ms')
                    end
                end -- update graph
--[[
    
    api.engine.getComponent(30047, api.type.ComponentType.TRAIN)
    {
        vehicles = {
            [1] = 19936,
        },
        reservedFrom = 10, -- in movePath, these are the reserved segments, without base0 <-> base1 conversion
        reservedTo = 12,
    }
]]

                local _getVehicleIdsNearPrioritySignals = function()
                    local results_indexed = {}
                    local hasRecords = false
                    for intersectionNodeId, nodeEdgeIdBeforeIntersection_indexedBy_inEdgeId in pairs(nodeEdgeIdBeforeIntersection_indexedBy_intersectionNodeId_edgeIdHavingWay) do
                        logger.print('intersectionNodeId = ' .. intersectionNodeId .. '; nodeEdgeIdBeforeIntersection_indexedBy_inEdgeId =')
                        logger.debugPrint(nodeEdgeIdBeforeIntersection_indexedBy_inEdgeId)
                        for inEdgeId, nodeEdgeIdBeforeIntersection in pairs(nodeEdgeIdBeforeIntersection_indexedBy_inEdgeId) do
                            logger.print('nodeEdgeIdBeforeIntersection =') logger.debugPrint(nodeEdgeIdBeforeIntersection)
                            logger.print('nodeEdgeIdBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay[intersectionNodeId] =')
                            logger.debugPrint(nodeEdgeIdBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay[intersectionNodeId])
                            -- if nodeEdgeIdBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay[intersectionNodeId] ~= nil then
                                local edgeIds = nodeEdgeIdBeforeIntersection.signalEdgeId == inEdgeId
                                    and {inEdgeId}
                                    or {nodeEdgeIdBeforeIntersection.signalEdgeId, inEdgeId}
                                logger.print('edgeIds for detecting priority trains =') logger.debugPrint(edgeIds)
                                local vehicleIdsNearPrioritySignals = api.engine.system.transportVehicleSystem.getVehicles(edgeIds, false)
                                for _, vehicleId in pairs(vehicleIdsNearPrioritySignals) do
                                    results_indexed[vehicleId] = true
                                    hasRecords = true
                                end
                            -- end
                        end
                    end
                    return hasRecords, results_indexed
                end

                for intersectionNodeId, nodeEdgeIdBeforeIntersection_indexedBy_inEdgeId in pairs(nodeEdgeIdBeforeIntersection_indexedBy_intersectionNodeId_edgeIdHavingWay) do
                    logger.print('intersectionNodeId = ' .. intersectionNodeId .. '; nodeEdgeIdBeforeIntersection_indexedBy_inEdgeId =')
                    logger.debugPrint(nodeEdgeIdBeforeIntersection_indexedBy_inEdgeId)
                    for inEdgeId, nodeEdgeIdBeforeIntersection in pairs(nodeEdgeIdBeforeIntersection_indexedBy_inEdgeId) do
                        logger.print('nodeEdgeIdBeforeIntersection =') logger.debugPrint(nodeEdgeIdBeforeIntersection)
                        logger.print('nodeEdgeIdBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay[intersectionNodeId] =')
                        logger.debugPrint(nodeEdgeIdBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay[intersectionNodeId])
                        if nodeEdgeIdBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay[intersectionNodeId] ~= nil then
                            local edgeIds = nodeEdgeIdBeforeIntersection.signalEdgeId == inEdgeId
                                and {inEdgeId}
                                or {nodeEdgeIdBeforeIntersection.signalEdgeId, inEdgeId}
                            logger.print('edgeIds for detecting priority trains =') logger.debugPrint(edgeIds)
                            local hasVehicleIdsNearPrioritySignals, vehicleIdsNearPrioritySignals = _getVehicleIdsNearPrioritySignals()
                            -- logger.print('vehicleIdsNearPrioritySignals =') logger.debugPrint(vehicleIdsNearPrioritySignals)
                            -- logger.print('#vehicleIdsNearPrioritySignals = ' .. #vehicleIdsNearPrioritySignals)
                            if hasVehicleIdsNearPrioritySignals then
                                for edgeIdGivingWay, nodeEdgeIdBehindIntersection in pairs(nodeEdgeIdBehindIntersection_indexedBy_intersectionNodeId_edgeIdGivingWay[intersectionNodeId]) do
                                    -- in the following, false means "only occupied now", true means "occupied nor or soon"
                                    -- "soon" means "since a vehicle left the last station and before it reaches the next"
                                    local vehicleIdsNearGiveWaySignals = api.engine.system.transportVehicleSystem.getVehicles({edgeIdGivingWay}, false)
                                    logger.print('vehicleIdsNearGiveWaySignals =') logger.debugPrint(vehicleIdsNearGiveWaySignals)
                                    for _, vehicleId in pairs(vehicleIdsNearGiveWaySignals) do
--[[
                                        -- LOLLO TODO only stop those vehicles that are heading for the intersection
                                        mp = api.engine.getComponent(veId, api.type.ComponentType.MOVE_PATH)
                                        {
                                            path = {
                                                edges = {
                                                [1] = {
                                                    new = nil,
                                                    edgeId = {
                                                    new = nil,
                                                    entity = 20169,
                                                    index = 0,
                                                    },
                                                    dir = true,
                                                    __doc__ = {
                                                    new = "(EdgeId edgeId, Bool dir) -> EdgeIdDir",
                                                    },
                                                },
                                                [2] = {
                                                    new = nil,
                                                    edgeId = {
                                                    new = nil,
                                                    entity = 20169,
                                                    index = 1,
                                                    },
                                                    dir = true,
                                                    __doc__ = {
                                                    new = "(EdgeId edgeId, Bool dir) -> EdgeIdDir",
                                                    },
                                                },
                                                [3] = {
                                                    new = nil,
                                                    edgeId = {
                                                    new = nil,
                                                    entity = 19959,
                                                    index = 0,
                                                    },
                                                    dir = true,
                                                    __doc__ = {
                                                    new = "(EdgeId edgeId, Bool dir) -> EdgeIdDir",
                                                    },
                                                },
                                                [4] = {
                                                    new = nil,
                                                    edgeId = {
                                                    new = nil,
                                                    entity = 19959,
                                                    index = 1,
                                                    },
                                                    dir = true,
                                                    __doc__ = {
                                                    new = "(EdgeId edgeId, Bool dir) -> EdgeIdDir",
                                                    },
                                                },
                                                [5] = {
                                                    new = nil,
                                                    edgeId = {
                                                    new = nil,
                                                    entity = 19959,
                                                    index = 2,
                                                    },
                                                    dir = true,
                                                    __doc__ = {
                                                    new = "(EdgeId edgeId, Bool dir) -> EdgeIdDir",
                                                    },
                                                },
                                                [6] = {
                                                    new = nil,
                                                    edgeId = {
                                                    new = nil,
                                                    entity = 25535,
                                                    index = 0,
                                                    },
                                                    dir = true,
                                                    __doc__ = {
                                                    new = "(EdgeId edgeId, Bool dir) -> EdgeIdDir",
                                                    },
                                                },
                                                [7] = {
                                                    new = nil,
                                                    edgeId = {
                                                    new = nil,
                                                    entity = 25535,
                                                    index = 1,
                                                    },
                                                    dir = true,
                                                    __doc__ = {
                                                    new = "(EdgeId edgeId, Bool dir) -> EdgeIdDir",
                                                    },
                                                },
                                                [8] = {
                                                    new = nil,
                                                    edgeId = {
                                                    new = nil,
                                                    entity = 25517,
                                                    index = 1,
                                                    },
                                                    dir = true,
                                                    __doc__ = {
                                                    new = "(EdgeId edgeId, Bool dir) -> EdgeIdDir",
                                                    },
                                                },
                                                [9] = {
                                                    new = nil,
                                                    edgeId = {
                                                    new = nil,
                                                    entity = 25519,
                                                    index = 0,
                                                    },
                                                    dir = false,
                                                    __doc__ = {
                                                    new = "(EdgeId edgeId, Bool dir) -> EdgeIdDir",
                                                    },
                                                },
                                                [10] = {
                                                    new = nil,
                                                    edgeId = {
                                                    new = nil,
                                                    entity = 25487,
                                                    index = 1,
                                                    },
                                                    dir = false,
                                                    __doc__ = {
                                                    new = "(EdgeId edgeId, Bool dir) -> EdgeIdDir",
                                                    },
                                                },
                                                [11] = {
                                                    new = nil,
                                                    edgeId = {
                                                    new = nil,
                                                    entity = 25487,
                                                    index = 3,
                                                    },
                                                    dir = true,
                                                    __doc__ = {
                                                    new = "(EdgeId edgeId, Bool dir) -> EdgeIdDir",
                                                    },
                                                },
                                                [12] = {
                                                    new = nil,
                                                    edgeId = {
                                                    new = nil,
                                                    entity = 25507,
                                                    index = 0,
                                                    },
                                                    dir = false,
                                                    __doc__ = {
                                                    new = "(EdgeId edgeId, Bool dir) -> EdgeIdDir",
                                                    },
                                                },
                                                [13] = {
                                                    new = nil,
                                                    edgeId = {
                                                    new = nil,
                                                    entity = 25468,
                                                    index = 0,
                                                    },
                                                    dir = false,
                                                    __doc__ = {
                                                    new = "(EdgeId edgeId, Bool dir) -> EdgeIdDir",
                                                    },
                                                },
                                                [14] = {
                                                    new = nil,
                                                    edgeId = {
                                                    new = nil,
                                                    entity = 25486,
                                                    index = 0,
                                                    },
                                                    dir = false,
                                                    __doc__ = {
                                                    new = "(EdgeId edgeId, Bool dir) -> EdgeIdDir",
                                                    },
                                                },
                                                [15] = {
                                                    new = nil,
                                                    edgeId = {
                                                    new = nil,
                                                    entity = 25513,
                                                    index = 0,
                                                    },
                                                    dir = false,
                                                    __doc__ = {
                                                    new = "(EdgeId edgeId, Bool dir) -> EdgeIdDir",
                                                    },
                                                },
                                                [16] = {
                                                    new = nil,
                                                    edgeId = {
                                                    new = nil,
                                                    entity = 25450,
                                                    index = 0,
                                                    },
                                                    dir = false,
                                                    __doc__ = {
                                                    new = "(EdgeId edgeId, Bool dir) -> EdgeIdDir",
                                                    },
                                                },
                                                [17] = {
                                                    new = nil,
                                                    edgeId = {
                                                    new = nil,
                                                    entity = 22756,
                                                    index = 0,
                                                    },
                                                    dir = true,
                                                    __doc__ = {
                                                    new = "(EdgeId edgeId, Bool dir) -> EdgeIdDir",
                                                    },
                                                },
                                                [18] = {
                                                    new = nil,
                                                    edgeId = {
                                                    new = nil,
                                                    entity = 22786,
                                                    index = 0,
                                                    },
                                                    dir = true,
                                                    __doc__ = {
                                                    new = "(EdgeId edgeId, Bool dir) -> EdgeIdDir",
                                                    },
                                                },
                                                [19] = {
                                                    new = nil,
                                                    edgeId = {
                                                    new = nil,
                                                    entity = 22789,
                                                    index = 0,
                                                    },
                                                    dir = true,
                                                    __doc__ = {
                                                    new = "(EdgeId edgeId, Bool dir) -> EdgeIdDir",
                                                    },
                                                },
                                                [20] = {
                                                    new = nil,
                                                    edgeId = {
                                                    new = nil,
                                                    entity = 22853,
                                                    index = 0,
                                                    },
                                                    dir = true,
                                                    __doc__ = {
                                                    new = "(EdgeId edgeId, Bool dir) -> EdgeIdDir",
                                                    },
                                                },
                                                },
                                                endOffset = 2,
                                                terminalDecisionOffset = 13,
                                            },
                                            endParam = 0,
                                            endPos = 0,
                                            state = 0,
                                            blocked = 0,
                                            allowEarlyArrival = false,
                                            reverse = false,
                                            dyn = {
                                                pathPos = {
                                                edgeIndex = 16, -- base 0!
                                                pos01 = 0.99592667818069,
                                                pos = 72.860328674316,
                                                },
                                                pathPos0 = nil,
                                                speed = 21.199125289917,
                                                speed0 = nil,
                                                brakeDecel = 2.6271903514862,
                                                accel = -2.6271903514862,
                                                timeUntilAccel = 0,
                                                timeStanding = 0,
                                                timeToIgnore = 0,
                                                approachingStation = true,
                                            },
                                            dyn0 = {
                                                pathPos = {
                                                edgeIndex = 16, -- base 0!
                                                pos01 = 0.99592667818069,
                                                pos = 72.860328674316,
                                                },
                                                pathPos0 = nil,
                                                speed = 21.199125289917,
                                                speed0 = nil,
                                                brakeDecel = 2.6271903514862,
                                                accel = -2.6271903514862,
                                                timeUntilAccel = 0,
                                                timeStanding = 0,
                                                timeToIgnore = 0,
                                                approachingStation = true,
                                            },
                                        }

                                        -- this tells where the vehicle is:
                                        mp.path.edges[mp.dyn.pathPos.edgeIndex + 1] =
                                        {
                                            new = nil,
                                            edgeId = {
                                                new = nil,
                                                entity = 22756,
                                                index = 0,
                                            },
                                            dir = true, -- true if the train goes from baseEdge.node0 to baseEdge.node1, eg if it follows the moving axes
                                            __doc__ = {
                                                new = "(EdgeId edgeId, Bool dir) -> EdgeIdDir",
                                            },
                                        }
]]

--[[
    LOLLO TODO take all trains approaching a priority signal
    for each, check if they are going to occupy an edge that gives way
    if none found, stop the train in that edge
]]
                                        local movePath = api.engine.getComponent(vehicleId, api.type.ComponentType.MOVE_PATH)
                                        local pathEdgeCount = #movePath.path.edges
                                        -- local baseEdge = api.engine.getComponent(edgeIdGivingWay, api.type.ComponentType.BASE_EDGE)
                                        for p = movePath.dyn.pathPos.edgeIndex + 1, pathEdgeCount, 1 do
                                            local currentMovePathBit = movePath.path.edges[p]
                                            -- local nextNodeId = currentMovePathBit.dir and baseEdge.node1 or baseEdge.node0
                                            -- local prevNodeId = currentMovePathBit.dir and baseEdge.node0 or baseEdge.node1
                                            if currentMovePathBit.edgeId.entity == edgeIdGivingWay then
                                                if currentMovePathBit.dir == nodeEdgeIdBehindIntersection.isGiveWayEdgeDirTowardsIntersection then
                                                    if not(api.engine.getComponent(vehicleId, api.type.ComponentType.TRANSPORT_VEHICLE).userStopped) then
                                                        -- api.cmd.sendCommand(api.cmd.make.reverseVehicle(vehicleId)) -- this is to stop it at once
                                                        api.cmd.sendCommand(api.cmd.make.setUserStopped(vehicleId, true))
                                                        -- api.cmd.sendCommand(api.cmd.make.reverseVehicle(vehicleId)) -- this is to stop it at once
                                                        logger.print('vehicle ' .. vehicleId ' stopped')
                                                    else
                                                        logger.print('vehicle ' .. vehicleId ' already stopped')
                                                    end
                                                    stoppedVehicleIds[vehicleId] = _gameTime_msec
                                                    break
                                                else
                                                    logger.print('vehicle ' .. vehicleId ' not stopped coz is going away from the intersection')
                                                    break
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                -- restart vehicles that don't need to wait anymore
                for vehicleId, gameTimeMsec in pairs(stoppedVehicleIds) do
                    if gameTimeMsec ~= _gameTime_msec then
                        api.cmd.sendCommand(api.cmd.make.setUserStopped(vehicleId, false))
                        logger.print('vehicle ' .. vehicleId ' restarted')
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
        if id ~= constants.eventId then return end

        xpcall(
            function()
                logger.print('handleEvent firing, src =', src, ', id =', id, ', name =', name, ', args =') logger.debugPrint(args)

                if name == constants.events.removeSignal then
                    _actions.replaceEdgeWithSameRemovingObject(args.objectId)
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
