local constants = {
    refreshGraphPeriodMsec = 5000, -- refresh every 5 seconds

    maxNChainedPrioritySignalsBeforeIntersection = 4, -- allow adding max N priority signals before an intersection
    maxNSegmentsBeforeIntersection = 16, -- seek intersections max N segments behind priority signal
    maxNSegmentsBeforePrioritySignal = 2, -- seek segments max N segments ahead of priority signal
    maxNSegmentsBehindIntersection = 8, -- seek segments max N segments behind intersection
    maxDistanceFromIntersection = 500, -- seek edges max 500 m from intersection

    numGetGraphCoroutineResumesPerTick = 4,
    numStartStopTrainsCoroutineResumesPerTick = 10,

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
