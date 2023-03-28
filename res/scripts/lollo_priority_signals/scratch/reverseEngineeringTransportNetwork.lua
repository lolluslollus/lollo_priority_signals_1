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