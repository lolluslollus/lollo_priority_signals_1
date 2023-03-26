function data()
	return {
		en = {
            ["ModDesc"] =
                [[
[b]Priority signals for tracks.[/b]
Place these before an intersection and ordinary signals (or a station) behind. Trains entering the intersection via priority signals will have priority over those entering via ordinary signals (or the station).
To prioritise a longer stretch of track, place the priority signal farther apart from the intersection - or place two of them in a sequence. Place the ordinary signals far enough from the intersection, so trains have enough room to stop.
Every signal has a white arrow that appears when you open the signal menu. Two-way priority signals only prioritise trains running along the white arrow - not those running against it.
Tracks are made of subsequent segments, you can check them with debug mode and <AltGr + L>. If a signal is too many segments apart from an intersection, never mind how short they are, the priority computation will ignore it.
Switch priority computations on and off with the icon in the bottom bar.
			]],
            ["ModName"] = "Priority signals for tracks",
            ["PrioritySignalsOff"] = "Priority signals OFF",
            ["PrioritySignalsOn"] = "Priority signals ON",
            ["Signal_Desc"] = "Place these before an intersection and ordinary signals (or a station) behind. Trains entering the intersection via priority signals will have priority over those entering via ordinary signals (or the station).",
            ["Signal_Name"] = "Priority Path Signal",
            ["WarningWindowTitle"] = "Warning",
        },
    }
end
