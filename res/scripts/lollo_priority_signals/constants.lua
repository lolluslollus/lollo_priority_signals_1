local constants = {
    refreshGraphPauseMsec = 2000, -- pause N msec between ending a refresh and starting a new one

    maxNChainedPrioritySignalsBeforeIntersection = 4, -- allow adding max N priority signals before an intersection
    maxNSegmentsBeforeIntersection = 16, -- seek intersections max N segments behind priority signal
    maxNSegmentsBeforePrioritySignal = 2, -- seek segments max N segments ahead of priority signal
    maxNSegmentsBehindIntersection = 8, -- seek segments max N segments behind intersection
    maxNSegmentsBehindIntersection_thenYield = 4, -- yield after seeking segments max N segments behind intersection, must be about half of maxNSegmentsBehindIntersection
    maxDistanceFromIntersection = 500, -- seek edges max 500 m from intersection

    numGetEdgeObjectsPerTick = 100,
    numGetGraphCoroutineResumesPerTick = 1,
    numStartStopTrainsCoroutineResumesPerTick = 20,

    eventId = '__lollo_priority_signals__',
    events = {
        hide_warnings = 'hide_warnings',
        removeSignal = 'remove_signal',
        toggle_notaus = 'toggle_notaus',
    },

    guiIds = {
        dynamicOnOffButtonId = 'lollo_priority_signals_dynamic_on_off_button',
        warningWindowWithMessageId = 'lollo_priority_signals_warning_window_with_message',
    },

    idTransf = { 1, 0, 0, 0,  0, 1, 0, 0,  0, 0, 1, 0,  0, 0, 0, 1 },

    currentVersion = 1
}

return constants
