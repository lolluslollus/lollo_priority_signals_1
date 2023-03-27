local constants = {
    refreshGraphPeriodMsec = 5000, -- refresh every 5 seconds

    maxNSegmentsBeforeIntersection = 8, -- seek intersections max N segments ahead of signal
    maxNSegmentsBeforePriorityLight = 2, -- seek segments max N segments ahead of signal
    maxNSegmentsBehindIntersection = 8, -- seek intersections max N segments ahead of signal
    maxDistanceFromIntersection = 500, -- seek edges max 500 m from intersection

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
