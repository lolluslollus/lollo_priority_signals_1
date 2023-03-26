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
--[[
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