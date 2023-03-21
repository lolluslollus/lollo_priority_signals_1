local logger = require ('lollo_priority_signals.logger')
local arrayUtils = require('lollo_priority_signals.arrayUtils')
local constants = require('lollo_priority_signals.constants')
local edgeUtils = require('lollo_priority_signals.edgeUtils')
local signalHelpers = require('lollo_priority_signals.signalHelpers')
local stateHelpers = require('lollo_priority_signals.stateHelpers')
local transfUtils = require('lollo_priority_signals.transfUtils')
local transfUtilsUG = require('transf')

--[[
    LOLLO NOTE
    useful apis:

    stopCmd = api.cmd.make.setUserStopped(25667, true)
    api.cmd.sendCommand(stopCmd)

    api.engine.system.transportVehicleSystem.getVehicles({edgeId}, true)
    api.engine.system.transportVehicleSystem.getVehicles({edgeId}, false)
    -- this finds all vehicles anywhere between the two given edge ids:
    api.engine.system.transportVehicleSystem.getVehicles({edge1Id, edge2Id}, true)

]]
local  _signalModelId_EraA, _signalModelId_EraC, _signalModelId_OneWay_EraA, _signalModelId_OneWay_EraC

local _texts = {

}

local _vehicleStates = {
    atTerminal = 2, -- api.type.enum.TransportVehicleState.AT_TERMINAL, -- 2
    enRoute = 1, -- api.type.enum.TransportVehicleState.EN_ROUTE, -- 1
    goingToDepot = 3, -- api.type.enum.TransportVehicleState.GOING_TO_DEPOT, -- 3
    inDepot = 0, -- api.type.enum.TransportVehicleState.IN_DEPOT, -- 0
}

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

        local _gameTime = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_TIME).gameTime
        if not(_gameTime) then logger.err('update() cannot get time') return end

        if math.fmod(_gameTime, constants.refreshPeriodMsec) ~= 0 then
            -- logger.print('skipping')
        return end
        -- logger.print('doing it')

        xpcall(
            function()
                local _startTick = os.clock()

                local _clockTimeSec = math.floor(_gameTime / 1000)
                -- leave if paused
                if _clockTimeSec == state.world_time_sec then return end

                state.world_time_sec = _clockTimeSec

                --[[
                    LOLLO NOTE one-way lights are read as two-way lights,
                    and they don't appear in the menu if they have no two-way counterparts, or if those counterparts have expired.
                ]]
                -- local era_a_signalIds = signalHelpers.getAllEdgeObjectsAndEdgesWithModelId(_signalModelId_EraA)
                -- local era_c_signalIds = signalHelpers.getAllEdgeObjectsAndEdgesWithModelId(_signalModelId_EraC)
                local era_a_signalIds = signalHelpers.getAllEdgeObjectsWithModelId(_signalModelId_EraA)
                local era_c_signalIds = signalHelpers.getAllEdgeObjectsWithModelId(_signalModelId_EraC)
                -- local era_a_oneWay_signalIds = signalHelpers.getAllEdgeObjectsAndEdgesWithModelId(_signalModelId_OneWay_EraA)
                -- local era_c_oneWay_signalIds = signalHelpers.getAllEdgeObjectsAndEdgesWithModelId(_signalModelId_OneWay_EraC)
                logger.print('era_a_signalIds =') logger.debugPrint(era_a_signalIds)
                logger.print('era_c_signalIds =') logger.debugPrint(era_c_signalIds)
                -- logger.print('era_a_oneWay_signalIds =') logger.debugPrint(era_a_oneWay_signalIds)
                -- logger.print('era_c_oneWay_signalIds =') logger.debugPrint(era_c_oneWay_signalIds)

--[[
    From my priority light, I want to go ahead until the next traffic light or intersection, whichever comes first.
    If it is a light, return
    If it is an intersection, follow it backwards until you find a traffic light or intersection, whichever comes first.
    Repeat this for every branch found at the intersection: {
        If the edge has an intersection, return
        If the edge has a priority light, return
        If the edge has no normal lights, move on to the next edge until you come back here (if you do).
        If you are too far away from the intersection, return.

        Now you have an edge with a normal light (if you got here):
        Seek the next edge (to give trains a chance to stop), at a minimum distance from the light.
        If there is an intersection, return.

        Place the edgeId in a table and check it at every tick with api.engine.system.transportVehicleSystem.getVehicles({edgeId}, true),
        against my edges that has priority. There will be a number of such edges before a priority light.
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

                -- by construction, I cannot have more than one priority signal on any edge.
                -- However, different priority signals might have the same intersection,
                -- so I need to squash the table
                local intersectionNodeIds_InEdgeIds_indexed = {}
                for _, signalId in pairs(era_c_signalIds) do
                    local intersectionProps = signalHelpers.getNextIntersectionBehind(signalId)
                    if intersectionProps.isFound then
                        if intersectionNodeIds_InEdgeIds_indexed[intersectionProps.nodeId] == nil then
                            intersectionNodeIds_InEdgeIds_indexed[intersectionProps.nodeId] = {[intersectionProps.inEdgeId] = true}
                        else
                            intersectionNodeIds_InEdgeIds_indexed[intersectionProps.nodeId][intersectionProps.inEdgeId] = true
                        end
                    end
                end
                logger.print('intersectionNodeIds_InEdgeIds_indexed =') logger.debugPrint(intersectionNodeIds_InEdgeIds_indexed)

                local executionTime = math.ceil((os.clock() - _startTick) * 1000)
                logger.print('Full update took ' .. executionTime .. 'ms')
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
        -- _signalModelId_OneWay_EraA = api.res.modelRep.find('railroad/lollo_priority_signals/signal_path_a_one_way.mdl')
        -- _signalModelId_OneWay_EraC = api.res.modelRep.find('railroad/lollo_priority_signals/signal_path_c_one_way.mdl')
        logger.print('_signalModelId_EraA =') logger.debugPrint(_signalModelId_EraA)
        logger.print('_signalModelId_EraC =') logger.debugPrint(_signalModelId_EraC)
        -- logger.print('_signalModelId_OneWay_EraA =') logger.debugPrint(_signalModelId_OneWay_EraA)
        -- logger.print('_signalModelId_OneWay_EraC =') logger.debugPrint(_signalModelId_OneWay_EraC)
    end,
}
