function data()
    local constants = require('lollo_priority_signals.constants')
	return {
		en = {
            ["ModDesc"] =
                [[
[b]Priority signals for tracks.[/b]
Place these before an intersection and ordinary signals (or a station) behind. Trains entering the intersection via priority signals will have priority over those entering via ordinary signals (or from stations).

Getting priority:
To prioritise trains over a longer stretch of track, place more priority signals farther ahead of the intersection. You can add up to ]] .. constants.maxNChainedPrioritySignalsBeforeIntersection .. [[ of those. If you have a station track closely preceding a priority signal, trains on it will receive priority as soon as they start.
If you place no priority signals on one branch, or you place them too far from the intersection or from each other (see the notes), trains entering the intersection from that branch will not get priority. 

Giving priority:
If you place no ordinary signals or stations on one branch, or you place them too far from the intersection (see the notes), trains entering the intersection from that branch will not give way.
If you place an ordinary signal too far from an intersection, trains passing it will grind to a halt. This is ugly; to fix it, ask UG to give us an api to turn signals red.

[b]Notes:[/b]
1) Priority signals are expensive, only use them where you really need them.
2) Switch priority computations on and off with the icon in the bottom bar. When they are off, priority signals will behave like standard signals. When you turn them on, or you start a new game, it might take a few seconds before priorities start working.
3) Every branch linked to an intersection with priority signals needs a signal (of any type) or a station near the intersection.
4) Every signal has a white arrow that appears when you open the signal menu. Two-way priority signals only prioritise trains running along the white arrow - not those running against it. This is akin to ordinary two-way signals and waypoints.
5) Some mods such as advanced statistics or digital displays hog game_script.update(). The game can only take so much, so you might need to choose.
6) You can use invisible priority signals and decorate them with functionless signals from some mod.
			]],
            ["GoThere"] = "Go there",
            ["Invisible_Signal_Name"] = "Invisible Priority Path Signal",
            ["ModName"] = "Priority signals for tracks",
            ["Note"] = "Priority signals are expensive, use them sparingly",
            ["OpenLocator"] = "Locate priority signals",
            ["PrioritySignalsOff"] = "Priority signals OFF",
            ["PrioritySignalsOn"] = "Priority signals ON",
            ["Refresh"] = "Refresh",
            ["SignalLocatorWindowTitle"] = "Priority signals in your world:",
            ["Signal_Desc"] = "Place these before an intersection and ordinary signals (or a station) behind. Trains entering the intersection via priority signals will have priority over those entering via ordinary signals (or the station).",
            ["Signal_Name"] = "Priority Path Signal",
            ["ThisIsAPrioritySignal"] = "This is a priority signal",
            ["WarningWindowTitle"] = "Warning",
            -- categories
            ["priority-signals"] = "Priority Signals",
        },
    }
end
