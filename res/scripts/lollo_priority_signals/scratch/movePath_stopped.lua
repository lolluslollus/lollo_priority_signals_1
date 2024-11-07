-- movePath = api.engine.getComponent(vehicleId, api.type.ComponentType.MOVE_PATH)
local movePath = {
    path = {
      edges = {
        [1] = {
          new = nil,
          edgeId = {
            new = nil,
            entity = 14660,
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
            entity = 14282,
            index = 0,
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
            entity = 14282,
            index = 1,
          },
          dir = true,
          __doc__ = {
            new = "(EdgeId edgeId, Bool dir) -> EdgeIdDir",
          },
        },
      },
      endOffset = 2,
      terminalDecisionOffset = 53,
    },
    endParam = 0,
    endPos = 0,
    state = 2,
    blocked = 0,
    allowEarlyArrival = false,
    reverse = true,
    dyn = {
      pathPos = {
        edgeIndex = 0,
        pos01 = 0.8321545124054,
        pos = 79.28279876709,
      },
      pathPos0 = nil,
      speed = 0,
      speed0 = nil,
      brakeDecel = 7.5,
      accel = -7.5,
      timeUntilAccel = 0,
      timeStanding = 0,
      timeToIgnore = 0,
      approachingStation = false,
    },
    dyn0 = {
      pathPos = {
        edgeIndex = 0,
        pos01 = 0.8321545124054,
        pos = 79.28279876709,
      },
      pathPos0 = nil,
      speed = 0,
      speed0 = nil,
      brakeDecel = 7.5,
      accel = -7.5,
      timeUntilAccel = 0,
      timeStanding = 0,
      timeToIgnore = 0,
      approachingStation = false,
    },
  }