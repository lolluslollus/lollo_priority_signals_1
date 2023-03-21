local constants = require('lollo_priority_signals.constants')

local utils = {
    -- LOLLO NOTE if a construction contains models without bounding info and collider,
    -- it will still detect collisions with them. With these, we avoid that problem.
    getVoidBoundingInfo = function()
        return {} -- this seems the same as the following
        -- return {
        --     bbMax = { 0, 0, 0 },
        --     bbMin = { 0, 0, 0 },
        -- }
    end,
    getVoidCollider = function()
        -- return {
        --     params = {
        --         halfExtents = { 0, 0, 0, },
        --     },
        --     transf = { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, },
        --     type = 'BOX',
        -- }
        return {
            type = 'NONE'
        }
    end,
}

return utils
