function data()
    local constants = require('lollo_priority_signals.constants')
	return {
		en = {
            ["ModDesc"] =
                [[
[b]Priority signals for tracks.[/b]
Place these before an intersection and ordinary signals (or a station) behind. Trains entering the intersection via priority signals will have priority over those entering via ordinary signals (or from the station).

Getting priority:
To prioritise trains over a longer stretch of track, place more priority signals farther ahead of the intersection. You can chain up to ]] .. constants.maxNChainedPrioritySignalsBeforeIntersection .. [[. If you have a station track closely preceding a priority signal, trains on it will receive priority as soon as they start.
If you place no priority signals on one branch, or you place them too far from the intersection or from each other (see the notes), trains entering the intersection from that branch will not get priority. 

Giving priority:
If you place no ordinary signals or stations on one branch, or you place them too far from the intersection (see the notes), trains entering the intersection from that branch will not give way. If you place an ordinary signal too close to an intersection, trains passing it will stop abruptly.

[b]Notes:[/b]
1) Tracks are made of subsequent segments, you can check them with debug mode and <AltGr + L>. If a signal is too many segments apart from an intersection, never mind how short they are, the priority computation will ignore it. This is inconvenient but gives better performance. Priority signals must be within ]] .. constants.maxNSegmentsBeforeIntersection .. [[ segments between one another, or from the intersection. Ordinary signals or stations must be within ]] .. constants.maxNSegmentsBehindIntersection .. [[ segments away from the intersection.
2) Every signal has a white arrow that appears when you open the signal menu. Two-way priority signals only prioritise trains running along the white arrow - not those running against it. This is akin to ordinary two-way signals and waypoints.
3) Switch priority computations on and off with the icon in the bottom bar. When they are off, priority signals will behave like standard signals.
4) Priority signals are expensive, only use them where you really need them.
			]],
            ["ModName"] = "Priority signals for tracks",
            ["PrioritySignalsOff"] = "Priority signals OFF",
            ["PrioritySignalsOn"] = "Priority signals ON",
            ["Signal_Desc"] = "Place these before an intersection and ordinary signals (or a station) behind. Trains entering the intersection via priority signals will have priority over those entering via ordinary signals (or the station).",
            ["Signal_Name"] = "Priority Path Signal",
            ["ThisIsAPrioritySignal"] = "This is a priority signal",
            ["WarningWindowTitle"] = "Warning",
        },
    }
end
