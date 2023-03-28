function data()
	return {
		en = {
            ["ModDesc"] =
                [[
[b]Priority signals for tracks.[/b]
Place these before an intersection and ordinary signals (or a station) behind. Trains entering the intersection via priority signals will have priority over those entering via ordinary signals (or the station).
If you want to prioritise a longer stretch of track, place a second priority signal farther ahead of the intersection (but not too far, see the notes). If you have a station track immediately preceding a priority signal, the whole station track will receive priority as soon as the train starts.

If you place no ordinary signals on one branch, or you place them too far (see notes), trains entering the intersection from that branch will not give way. If you place an ordinary signal too close to an intersection, trains passing it will stop abruptly.

[b]Notes:[/b]
1) Tracks are made of subsequent segments, you can check them with debug mode and <AltGr + L>. If a signal is too many segments apart from an intersection, never mind how short they are, the priority computation will ignore it. This is inconvenient but gives better performance.
2) Every signal has a white arrow that appears when you open the signal menu. Two-way priority signals only prioritise trains running along the white arrow - not those running against it. This is akin to ordinary two-way signals and waypoints.
3) Switch priority computations on and off with the icon in the bottom bar.
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
