state("mGBA") {}

startup {
    settings.Add("battles", true, "Battles");
    settings.Add("events", true, "Events");

    settings.CurrentDefaultParent = "battles";
    settings.Add("squirtle", true, "First Rival");
    settings.Add("brock", true, "Brock");
    settings.Add("misty", true, "Misty");
    settings.Add("surge", true, "Lt. Surge");
    settings.Add("koga", true, "Koga");
    settings.Add("blaine", true, "Blaine");
    settings.Add("erika", true, "Erika");
    settings.Add("sabrina", true, "Sabrina");
    settings.Add("giovanni3", true, "Giovanni 3");
    settings.Add("lorelei", true, "Lorelei");
    settings.Add("bruno", true, "Bruno");
    settings.Add("agatha", true, "Agatha");
    settings.Add("lance", true, "Lance");
    settings.Add("champion", true, "Champion");

    settings.CurrentDefaultParent = "events";
    settings.Add("ssticket", true, "S.S. Ticket");
    settings.Add("lavender", true, "Lavender Shop");
    settings.Add("scope", true, "Silph Scope");
    settings.Add("flute", true, "Pokeflute");
    settings.Add("hallOfFame", true, "Hall of Fame");

    refreshRate = 0.5;

    vars.timer_OnStart = (EventHandler)((s, e) => {
        vars.splits = vars.GetSplits();
    });
    timer.OnStart += vars.timer_OnStart;

    vars.FindWorkingRamAddress = (Func<Process, IntPtr>)((process) => {
        print("[Autosplitter] Scanning memory");
        var target = new SigScanTarget(0, "?? 00 A3 A3 ?? ?? ?? 00 00 00 00 02 ?? ?? 00 02");

        var address = IntPtr.Zero;
        foreach (var page in process.MemoryPages()) {
            var scanner = new SignatureScanner(process, page.BaseAddress, (int)page.RegionSize);
            address = scanner.Scan(target);

            if (address != IntPtr.Zero) {
                break;
            }
        }

        return address;
    });

    vars.GetWatchers = (Func<Process, MemoryWatcherList>)((process) => {
        Func<int, IntPtr> GetSaveBlockAddress = (pointerOffset) => {
            var watcher = new MemoryWatcher<uint>(vars.internalWorkingRamAddress + pointerOffset);
            watcher.Update(process);
            
            return new IntPtr(watcher.Current - 0x2000000 + vars.workingRamAddress.ToInt64());
        };

        var saveBlock1Address = GetSaveBlockAddress(0x5008);
        var saveBlock2Address = GetSaveBlockAddress(0x500C);

        return new MemoryWatcherList {
            new MemoryWatcher<uint>(vars.internalWorkingRamAddress + 0x30F0 + 0xC) { Name = "vblankCallback" },
            new MemoryWatcher<uint>(vars.internalWorkingRamAddress + 0x5090) { Name = "taskPtr" },
            new MemoryWatcher<ushort>(vars.internalWorkingRamAddress + 0x509A) { Name = "cursorPos" },
            new MemoryWatcher<ushort>(vars.internalWorkingRamAddress + 0xE7C) { Name = "playTimeCounterState" },
            new MemoryWatcher<ushort>(saveBlock1Address + 0x4) { Name = "location" },
            new MemoryWatcher<ulong>(saveBlock1Address + 0xEE0 + 0x46) { Name = "storyFlags" },
            new MemoryWatcher<ushort>(saveBlock1Address + 0xEE0 + 0x96) { Name = "bossFlags" },
            new StringWatcher(saveBlock1Address + 0x310, ReadStringType.AutoDetect, 6 * 42) { Name = "items" },
            new StringWatcher(saveBlock1Address + 0x3B8, ReadStringType.AutoDetect, 6 * 30) { Name = "keyItems" },
            new MemoryWatcher<ushort>(saveBlock2Address + 0xA) { Name = "playerTrainerId" },
            new MemoryWatcher<byte>(vars.workingRamAddress + 0x370E0) { Name = "specialFlags" }
        };
    });

    vars.GetSplits = (Func<Dictionary<string, Func<bool>>>)(() => {
        Func<string, int, bool> HasFlag = (name, index) => {
            var watcher = vars.watchers[name];
            var flag = 0x1UL << index;
            return (watcher.Current & flag) == flag;
        };

        return new Dictionary<string, Func<bool>> {
            { "squirtle", () => HasFlag("storyFlags", 0x28) },
            { "brock", () => HasFlag("bossFlags", 0x0) },
            { "misty", () => HasFlag("bossFlags", 0x1) },
            { "ssticket", () => HasFlag("storyFlags", 0x4) },
            { "surge", () => HasFlag("bossFlags", 0x2) },
            { "lavender", () => vars.watchers["location"].Current == 0x403 && vars.watchers["items"].Current.Contains("\u0055") },
            { "scope", () => vars.watchers["keyItems"].Current.Contains("\u0067\u0001") },
            { "flute", () => HasFlag("storyFlags", 0xD) },
            { "koga", () => HasFlag("bossFlags", 0x4) },
            { "blaine", () => HasFlag("bossFlags", 0x6) },
            { "erika", () => HasFlag("bossFlags", 0x3) },
            { "sabrina", () => HasFlag("bossFlags", 0x5) },
            { "giovanni3", () => HasFlag("bossFlags", 0x7) },
            { "lorelei", () => HasFlag("bossFlags", 0x8) },
            { "bruno", () => HasFlag("bossFlags", 0x9) },
            { "agatha", () => HasFlag("bossFlags", 0xA) },
            { "lance", () => HasFlag("bossFlags", 0xB) },
            { "champion", () => HasFlag("bossFlags", 0xC) },
            { "hallOfFame", () => HasFlag("specialFlags", 0x0) },
        };
    });}

init {
    vars.workingRamAddress = vars.FindWorkingRamAddress(game);
    if (vars.workingRamAddress == IntPtr.Zero) {
        throw new Exception("Could not find EWRAM address");
    }

    vars.internalWorkingRamAddress = vars.workingRamAddress + 0x40000;
    print("[Autosplitter] Found EWRAM address: " + vars.workingRamAddress.ToString("X8"));

    refreshRate = 200/3.0;
    vars.splits = new Dictionary<string, Func<bool>>();
    vars.watchers = vars.GetWatchers(game);
}

update {
    vars.watchers = vars.GetWatchers(game);
    vars.watchers.UpdateAll(game);
}

start {
    vars.trainerId = null;
    return vars.watchers["taskPtr"].Current == 0x800CAA9 && vars.watchers["cursorPos"].Current == 1;
}

reset {
    return vars.watchers["taskPtr"].Current == 0x800CA69 && vars.watchers["cursorPos"].Current == 1;
}

split {
    var playerTrainerId = vars.watchers["playerTrainerId"].Current;
    if (vars.trainerId == null && vars.watchers["playTimeCounterState"].Current == 1) {
        vars.trainerId = playerTrainerId;
        print("[Autosplitter] New game started with trainer id: " + vars.trainerId);
    }

    var vblankCallback = vars.watchers["vblankCallback"].Current;
    if (vars.trainerId == null || vars.trainerId != playerTrainerId || vblankCallback == IntPtr.Zero.ToInt32()) {
        // Do not split until the trainer id is determined or when the save block is being moved.
        return false;
    }

    foreach (var _split in vars.splits) {
        if (settings[_split.Key] && _split.Value()) {
            print("[Autosplitter] Split: " + _split.Key);
            print("[Autosplitter] StoryFlags: " + vars.watchers["storyFlags"].Current.ToString("X"));
            print("[Autosplitter] BossFlags: " + vars.watchers["bossFlags"].Current.ToString("X"));
            print("[Autosplitter] SpecialFlags: " + vars.watchers["specialFlags"].Current.ToString("X"));

            vars.splits.Remove(_split.Key);
            return true;
        }
    }
}

exit {
    refreshRate = 0.5;
}

shutdown {
    timer.OnStart -= vars.timer_OnStart;
}
