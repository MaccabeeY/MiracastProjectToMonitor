if (-not ([System.Management.Automation.PSTypeName]'MiracastTarget').Type) {
    Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;


public class MiracastTarget {
    [StructLayout(LayoutKind.Sequential)] public struct LUID { public uint LowPart; public int HighPart; }
    [StructLayout(LayoutKind.Sequential)] public struct DISPLAYCONFIG_RATIONAL { public uint Numerator; public uint Denominator; }
    [StructLayout(LayoutKind.Sequential)] public struct DISPLAYCONFIG_PATH_SOURCE_INFO {
        public LUID adapterId; public uint id; public uint modeInfoIdx; public uint statusFlags;
    }
    [StructLayout(LayoutKind.Sequential)] public struct DISPLAYCONFIG_PATH_TARGET_INFO {
        public LUID adapterId; public uint id; public uint modeInfoIdx;
        public uint outputTechnology; public uint rotation; public uint scaling;
        public DISPLAYCONFIG_RATIONAL refreshRate; public uint scanLineOrdering;
        public bool targetAvailable; public uint statusFlags;
    }
    [StructLayout(LayoutKind.Sequential)] public struct DISPLAYCONFIG_PATH_INFO {
        public DISPLAYCONFIG_PATH_SOURCE_INFO sourceInfo;
        public DISPLAYCONFIG_PATH_TARGET_INFO targetInfo;
        public uint flags;
    }

    [DllImport("user32.dll")] static extern int GetDisplayConfigBufferSizes(uint flags, out uint numPaths, out uint numModes);
    [DllImport("user32.dll")] static extern int QueryDisplayConfig(uint flags, ref uint numPaths, [Out] DISPLAYCONFIG_PATH_INFO[] paths, ref uint numModes, [Out] byte[] modes, IntPtr currentTopologyId);
    [DllImport("user32.dll")] static extern int QueryDisplayConfig(uint flags, ref uint numPaths, [Out] DISPLAYCONFIG_PATH_INFO[] paths, ref uint numModes, [Out] byte[] modes, out uint currentTopologyId);
    [DllImport("user32.dll")] static extern int SetDisplayConfig(uint numPathArrayElements, IntPtr pathArray, uint numModeInfoArrayElements, IntPtr modeInfoArray, uint flags);
    [DllImport("cfgmgr32.dll", CharSet = CharSet.Unicode)] static extern uint CM_Locate_DevNodeW(out uint pdnDevInst, string pDeviceID, uint ulFlags);
    [DllImport("cfgmgr32.dll")] static extern uint CM_Disable_DevNode(uint dnDevInst, uint ulFlags);
    [DllImport("cfgmgr32.dll")] static extern uint CM_Enable_DevNode(uint dnDevInst, uint ulFlags);

    private static HashSet<string> _baselineTargets = new HashSet<string>();

    private static HashSet<string> GetActiveTargets() {
        var set = new HashSet<string>();
        uint pCount, mCount;
        if (GetDisplayConfigBufferSizes(2, out pCount, out mCount) != 0) return set; // 2 = QDC_ONLY_ACTIVE_PATHS
        var paths = new DISPLAYCONFIG_PATH_INFO[pCount];
        var modes = new byte[mCount * 64];
        if (QueryDisplayConfig(2, ref pCount, paths, ref mCount, modes, IntPtr.Zero) != 0) return set;

        foreach (var path in paths) {
            if (path.targetInfo.targetAvailable) {
                string key = path.targetInfo.adapterId.HighPart + ":" + path.targetInfo.adapterId.LowPart + ":" + path.targetInfo.id;
                set.Add(key);
            }
        }
        return set;
    }

    public static void CaptureBaseline() {
        _baselineTargets = GetActiveTargets();
    }

    public static bool IsConnected() {
        foreach (string key in GetActiveTargets()) {
            if (!_baselineTargets.Contains(key)) {
                return true;
            }
        }
        return false;
    }

    public static bool IsModeActive(string switchArg) {
        string arg = (switchArg ?? "").Trim().ToLowerInvariant();
        if (arg != "internal" && arg != "clone" && arg != "external" && arg != "extend") return false;

        // Verify actual active DWM paths match the committed mode (2 = QDC_ONLY_ACTIVE_PATHS)
        uint actPaths, actModes;
        if (GetDisplayConfigBufferSizes(2, out actPaths, out actModes) != 0) return false;
        var actPathArr = new DISPLAYCONFIG_PATH_INFO[actPaths];
        var actModeArr = new byte[actModes * 64];
        if (QueryDisplayConfig(2, ref actPaths, actPathArr, ref actModes, actModeArr, IntPtr.Zero) != 0) return false;

        var distinctSources = new HashSet<string>();
        int activeCount = 0;
        bool hasNewTarget = false;  // <=== ADDED
        foreach (var p in actPathArr) {
            if (p.targetInfo.targetAvailable) {
                activeCount++;
                string tKey = p.targetInfo.adapterId.HighPart + ":" + p.targetInfo.adapterId.LowPart + ":" + p.targetInfo.id;
                if (!_baselineTargets.Contains(tKey)) hasNewTarget = true;  // <=== ADDED
                distinctSources.Add(p.sourceInfo.adapterId.HighPart + ":" + p.sourceInfo.adapterId.LowPart + ":" + p.sourceInfo.id);
            }
        }

        switch (arg)
        {
            case "internal": return !hasNewTarget && activeCount >= 1;
            case "external": return hasNewTarget && activeCount == 1;
            case "clone":    return hasNewTarget && activeCount >= 2 && distinctSources.Count == 1;
            case "extend":   return hasNewTarget && activeCount >= 2 && distinctSources.Count >= 2;
            default:         return false;
        }

    }

    public static bool IsMiracastActive() {
        uint pCount, mCount;
        if (GetDisplayConfigBufferSizes(1, out pCount, out mCount) != 0) return false;
        var paths = new DISPLAYCONFIG_PATH_INFO[pCount];
        var modes = new byte[mCount * 64];
        if (QueryDisplayConfig(1, ref pCount, paths, ref mCount, modes, IntPtr.Zero) != 0) return false;
        var availableTargets = new HashSet<string>();
        foreach (var path in paths) {
            if (path.targetInfo.targetAvailable) {
                availableTargets.Add(path.targetInfo.adapterId.HighPart + ":" + path.targetInfo.adapterId.LowPart + ":" + path.targetInfo.id);
            }
        }
        return availableTargets.Count >= 2;
    }

    private static int SetDisplayMode(string mode) {
        uint topologyFlag;
        switch ((mode ?? "").Trim().ToLowerInvariant()) {
            case "internal": topologyFlag = 0x00000001; break; // SDC_TOPOLOGY_INTERNAL
            case "clone":    topologyFlag = 0x00000002; break; // SDC_TOPOLOGY_CLONE
            case "extend":   topologyFlag = 0x00000004; break; // SDC_TOPOLOGY_EXTEND
            case "external": topologyFlag = 0x00000008; break; // SDC_TOPOLOGY_EXTERNAL
            default:         return -1;
        }
        return SetDisplayConfig(0, IntPtr.Zero, 0, IntPtr.Zero, 0x00000080 | topologyFlag); // 0x80 = SDC_APPLY
    }

    public static int SetMode(string mode) {
        return SetDisplayMode(mode);
    }

    public static int SetWifiDirectEnabled(bool enable) {
        const string wfdClassKey = @"SYSTEM\CurrentControlSet\Enum\{5D624F94-8850-40C3-A3FA-A4FD2080BAF3}\VWIFIMP_WFD";
        uint bestDevInst = 0;
        uint lowestIdx = uint.MaxValue;
        try {
            using (var baseKey = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(wfdClassKey)) {
                if (baseKey != null) {
                    foreach (string sub in baseKey.GetSubKeyNames()) {
                        string fullId = @"{5D624F94-8850-40C3-A3FA-A4FD2080BAF3}\VWIFIMP_WFD\" + sub;
                        uint devInst;
                        if (CM_Locate_DevNodeW(out devInst, fullId, 0) != 0) continue; // skips any Casper/ghost entries
                        int amp = sub.LastIndexOf('&');
                        if (amp < 0) continue;
                        uint idx;
                        if (uint.TryParse(sub.Substring(amp + 1), System.Globalization.NumberStyles.HexNumber, null, out idx)) {
                            if (idx < lowestIdx) {
                                lowestIdx = idx;
                                bestDevInst = devInst;
                            }
                        }
                    }
                }
            }
        } catch { return -1; }
        if (bestDevInst == 0) return -1;
        return enable ? (int)CM_Enable_DevNode(bestDevInst, 0) : (int)CM_Disable_DevNode(bestDevInst, 0x00000008); // 0x08 = CM_DISABLE_PERSIST
    }

    public static int Disconnect() {
        bool toggled = false;
        try {
            using (var baseKey = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(@"SYSTEM\CurrentControlSet\Enum\SWD\WIFIDIRECT")) {
                if (baseKey != null) {
                    foreach (string sub in baseKey.GetSubKeyNames()) {
                        if (!sub.EndsWith("#MIRACAST", StringComparison.OrdinalIgnoreCase)) continue;
                        string instanceId = @"SWD\WIFIDIRECT\" + sub;
                        uint devInst;
                        if (CM_Locate_DevNodeW(out devInst, instanceId, 0) == 0) {
                            if (CM_Disable_DevNode(devInst, 0) == 0) {
                                System.Threading.Thread.Sleep(300);
                                CM_Enable_DevNode(devInst, 0);
                                toggled = true;
                            }
                        }
                    }
                }
            }
        } catch { }
        return toggled ? 0 : SetDisplayMode("internal");
    }
}
"@
}
