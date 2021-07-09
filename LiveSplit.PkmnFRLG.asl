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
        vars.splits = vars.GetSplitList();
    });
    timer.OnStart += vars.timer_OnStart;

    vars.FindMemoryPointer = (Func<Process, IntPtr>)((proc) => {
        print("[Autosplitter] Scanning memory");
        var target = new SigScanTarget(0, "?? 00 A3 A3 ?? ?? ?? 00 00 00 00 02 ?? ?? 00 02");

        int scanOffset = 0;
        foreach (var page in proc.MemoryPages()) {
            var scanner = new SignatureScanner(proc, page.BaseAddress, (int)page.RegionSize);
            if ((scanOffset = (int)scanner.Scan(target)) != 0) {
                break;
            }
        }

        if (scanOffset != IntPtr.Zero.ToInt32()) {
            return new IntPtr(scanOffset);
        }

        return IntPtr.Zero;
    });

    vars.GetWatcherList = (Func<IntPtr, MemoryWatcherList>)((wramAddr) => {
        var iwramAddr = wramAddr + 0x40000;
        Func<int, DeepPointer> CreateSaveBlockPointer = (offset) => {
           return new DeepPointer(iwramAddr + 0x5008, DeepPointer.DerefType.Bit32, wramAddr.ToInt32() - 0x2000000 + offset);
        };

        return new MemoryWatcherList {
            new MemoryWatcher<uint>(iwramAddr + 0x30F0 + 0xC) { Name = "vblankCallback" },
            new MemoryWatcher<uint>(iwramAddr + 0x5090) { Name = "taskPtr" },
            new MemoryWatcher<ushort>(iwramAddr + 0x509A) { Name = "cursorPos" },
            new MemoryWatcher<ushort>(CreateSaveBlockPointer(0x4)) { Name = "location" },
            new MemoryWatcher<ulong>(CreateSaveBlockPointer(0xEE0 + 0x46)) { Name = "storyFlags" },
            new MemoryWatcher<ushort>(CreateSaveBlockPointer(0xEE0 + 0x96)) { Name = "bossFlags" },
            new StringWatcher(CreateSaveBlockPointer(0x310), ReadStringType.AutoDetect, 6 * 42) { Name = "items" },
            new StringWatcher(CreateSaveBlockPointer(0x3B8), ReadStringType.AutoDetect, 6 * 30) { Name = "keyItems" },
            new MemoryWatcher<byte>(wramAddr + 0x370E0) { Name = "specialFlags" },
            new MemoryWatcher<byte>(wramAddr + 0x31DE0) { Name = "test" },
        };
    });

    vars.GetSplitList = (Func<Dictionary<string, Func<bool>>>)(() => {
        Func<string, bool> StateChanged = (name) => vars.watchers[name].Changed;
        Func<string, int, bool> HasFlag = (name, index) => {
            var watcher = vars.watchers[name];
            var flag = 0x1UL << index;
            return (watcher.Current & flag) == flag;
        };

        return new Dictionary<string, Func<bool>> {
            { "squirtle", () => StateChanged("storyFlags") && HasFlag("storyFlags", 0x28) },
            { "brock", () => StateChanged("bossFlags") && HasFlag("bossFlags", 0x0) },
            { "misty", () => StateChanged("bossFlags") && HasFlag("bossFlags", 0x1) },
            { "ssticket", () => StateChanged("storyFlags") && HasFlag("storyFlags", 0x4) },
            { "surge", () => StateChanged("bossFlags") && HasFlag("bossFlags", 0x2) },
            { "lavender", () => StateChanged("location") && vars.watchers["location"].Current == 0x403 && vars.watchers["items"].Current.Contains("\u0055") },
            { "scope", () => StateChanged("keyItems") && vars.watchers["keyItems"].Current.Contains("\u0067\u0001") },
            { "flute", () => StateChanged("storyFlags") && HasFlag("storyFlags", 0xD) },
            { "koga", () => StateChanged("bossFlags") && HasFlag("bossFlags", 0x4) },
            { "blaine", () => StateChanged("bossFlags") && HasFlag("bossFlags", 0x6) },
            { "erika", () => StateChanged("bossFlags") && HasFlag("bossFlags", 0x3) },
            { "sabrina", () => StateChanged("bossFlags") && HasFlag("bossFlags", 0x5) },
            { "giovanni3", () => StateChanged("bossFlags") && HasFlag("bossFlags", 0x7) },
            { "lorelei", () => StateChanged("bossFlags") && HasFlag("bossFlags", 0x8) },
            { "bruno", () => StateChanged("bossFlags") && HasFlag("bossFlags", 0x9) },
            { "agatha", () => StateChanged("bossFlags") && HasFlag("bossFlags", 0xA) },
            { "lance", () => StateChanged("bossFlags") && HasFlag("bossFlags", 0xB) },
            { "champion", () => StateChanged("bossFlags") && HasFlag("bossFlags", 0xC) },
            { "hallOfFame", () => StateChanged("specialFlags") && HasFlag("specialFlags", 0x0) },
        };
    });}

init {
    var wramAddr = vars.FindMemoryPointer(game);
    if (wramAddr == IntPtr.Zero) {
        throw new Exception("Could not find emulated game memory");
    }

    refreshRate = 200/3.0;
    vars.splits = new Dictionary<string, Func<bool>>();
    vars.watchers = vars.GetWatcherList(wramAddr);
    print("[Autosplitter] WRAM Pointer: " + wramAddr.ToString("X8"));
}

update {
    vars.watchers.UpdateAll(game);
}

start {
    return vars.watchers["taskPtr"].Current == 0x800CAA9 && vars.watchers["cursorPos"].Current == 1;
}

reset {
    return vars.watchers["taskPtr"].Current == 0x800CA69 && vars.watchers["cursorPos"].Current == 1;
}

split {
    var taskPtr = vars.watchers["taskPtr"].Current;
    if (taskPtr == 0x80775F9 || taskPtr == 0x8078C39) {
        // Do not split in the intro or in the main menu.
        return false;
    }

    foreach (var _split in vars.splits) {
        if (settings[_split.Key] && _split.Value() && vars.watchers["vblankCallback"].Current != IntPtr.Zero.ToInt32()) {
            print("[Autosplitter] Split: " + _split.Key);
            print("StoryFlags: " + vars.watchers["storyFlags"].Current.ToString("X"));
            print("BossFlags: " + vars.watchers["bossFlags"].Current.ToString("X"));

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
