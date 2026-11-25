using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;


public class MiracastTarget {
    [StructLayout(LayoutKind.Sequential)] private struct LUID { public uint LowPart; public int HighPart; }
    [StructLayout(LayoutKind.Sequential)] private struct DISPLAYCONFIG_RATIONAL { public uint Numerator; public uint Denominator; }
    [StructLayout(LayoutKind.Sequential)] private struct DISPLAYCONFIG_PATH_SOURCE_INFO {
        public LUID adapterId; public uint id; public uint modeInfoIdx; public uint statusFlags;
    }
    [StructLayout(LayoutKind.Sequential)] private struct DISPLAYCONFIG_PATH_TARGET_INFO {
        public LUID adapterId; public uint id; public uint modeInfoIdx;
        public uint outputTechnology; public uint rotation; public uint scaling;
        public DISPLAYCONFIG_RATIONAL refreshRate; public uint scanLineOrdering;
        public bool targetAvailable; public uint statusFlags;
    }
    [StructLayout(LayoutKind.Sequential)] private struct DISPLAYCONFIG_PATH_INFO {
        public DISPLAYCONFIG_PATH_SOURCE_INFO sourceInfo;
        public DISPLAYCONFIG_PATH_TARGET_INFO targetInfo;
        public uint flags;
    }
    [StructLayout(LayoutKind.Sequential)] private struct DISPLAYCONFIG_DEVICE_INFO_HEADER {
        public uint type; public uint size; public LUID adapterId; public uint id;
    }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)] private struct DISPLAYCONFIG_TARGET_DEVICE_NAME {
        public DISPLAYCONFIG_DEVICE_INFO_HEADER header;
        public uint flags;
        public uint outputTechnology;
        public ushort edidManufactureId;
        public ushort edidProductCodeId;
        public uint connectorInstance;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)] public string monitorFriendlyDeviceName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string monitorDevicePath;
    }

    [DllImport("user32.dll")] private static extern int GetDisplayConfigBufferSizes(uint flags, out uint numPaths, out uint numModes);
    [DllImport("user32.dll")] private static extern int QueryDisplayConfig(uint flags, ref uint numPaths, [Out] DISPLAYCONFIG_PATH_INFO[] paths, ref uint numModes, [Out] byte[] modes, IntPtr currentTopologyId);
    [DllImport("user32.dll")] private static extern int QueryDisplayConfig(uint flags, ref uint numPaths, [Out] DISPLAYCONFIG_PATH_INFO[] paths, ref uint numModes, [Out] byte[] modes, out uint currentTopologyId);
    [DllImport("user32.dll")] private static extern int SetDisplayConfig(uint numPathArrayElements, IntPtr pathArray, uint numModeInfoArrayElements, IntPtr modeInfoArray, uint flags);
    [DllImport("user32.dll")] private static extern int DisplayConfigGetDeviceInfo(ref DISPLAYCONFIG_TARGET_DEVICE_NAME requestPacket);
    [DllImport("cfgmgr32.dll", CharSet = CharSet.Unicode)] private static extern uint CM_Locate_DevNodeW(out uint pdnDevInst, string pDeviceID, uint ulFlags);
    [DllImport("cfgmgr32.dll")] private static extern uint CM_Disable_DevNode(uint dnDevInst, uint ulFlags);
    [DllImport("cfgmgr32.dll")] private static extern uint CM_Enable_DevNode(uint dnDevInst, uint ulFlags);
    [DllImport("cfgmgr32.dll")] private static extern uint CM_Get_DevNode_Status(out uint pulStatus, out uint pulProblemNumber, uint dnDevInst, uint ulFlags);
    [DllImport("wlanapi.dll")] private static extern uint WlanOpenHandle(uint dwClientVersion, IntPtr pReserved, out uint pdwNegotiatedVersion, out IntPtr phClientHandle);
    [DllImport("wlanapi.dll")] private static extern uint WlanCloseHandle(IntPtr hClientHandle, IntPtr pReserved);
    [DllImport("wlanapi.dll")] private static extern uint WlanEnumInterfaces(IntPtr hClientHandle, IntPtr pReserved, out IntPtr ppInterfaceList);
    [DllImport("wlanapi.dll")] private static extern uint WlanQueryInterface(IntPtr hClientHandle, ref Guid pInterfaceGuid, int OpCode, IntPtr pReserved, out uint pdwDataSize, out IntPtr ppData, IntPtr pWlanOpcodeValueType);
    [DllImport("wlanapi.dll")] private static extern void WlanFreeMemory(IntPtr pMemory);

    private static HashSet<string> _baselineTargets = new HashSet<string>();

    private const string WfdDevicePrefix = @"{5D624F94-8850-40C3-A3FA-A4FD2080BAF3}\VWIFIMP_WFD";
    private const string WfdClassKey     = @"SYSTEM\CurrentControlSet\Enum\" + WfdDevicePrefix;
    private const string WfdSwdPrefix          = @"SWD\WIFIDIRECT";
    private const string WfdSwdEnumKey         = @"SYSTEM\CurrentControlSet\Enum\" + WfdSwdPrefix;
    private const string AppRegistryKey        = @"Software\MiracastProjectToMonitor";
    private const string ActiveReceiverValName = "ActiveProjectionReceiverID";


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


    private static void SaveActiveReceiverID(string receiverID) {
        try {
            using (var key = Microsoft.Win32.Registry.CurrentUser.CreateSubKey(AppRegistryKey)) {
                if (key != null) {
                    key.SetValue(ActiveReceiverValName, receiverID ?? "", Microsoft.Win32.RegistryValueKind.String);
                }
            }
        } catch { }
    }


    private static string GetSavedReceiverID() {
        try {
            using (var key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(AppRegistryKey)) {
                if (key != null) {
                    object val = key.GetValue(ActiveReceiverValName);
                    return val != null ? val.ToString() : "";
                }
            }
        } catch { }
        return "";
    }


    private static void ClearActiveReceiverID() {
        try {
            using (var key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(AppRegistryKey, true)) {
                if (key != null) {
                    key.DeleteValue(ActiveReceiverValName, false);
                }
            }
        } catch { }
    }


    private static uint FindWifiDirectDevInst() {
        uint bestDevInst = 0;
        uint lowestIdx = uint.MaxValue;
        try {
            using (var baseKey = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(WfdClassKey)) {
                if (baseKey != null) {
                    foreach (string sub in baseKey.GetSubKeyNames()) {
                        string fullId = WfdDevicePrefix + @"\" + sub;
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
        } catch { return 0; }
        return bestDevInst;
    }


    public static string[] GetWiredMonitorNames() {
        var names = new List<string>();
        uint pCount, mCount;
        if (GetDisplayConfigBufferSizes(1, out pCount, out mCount) != 0) return names.ToArray(); // 1 = QDC_ALL_PATHS
        var paths = new DISPLAYCONFIG_PATH_INFO[pCount];
        var modes = new byte[mCount * 64];
        if (QueryDisplayConfig(1, ref pCount, paths, ref mCount, modes, IntPtr.Zero) != 0) return names.ToArray();

        var seenTargets = new HashSet<string>();
        foreach (var path in paths) {
            if (!path.targetInfo.targetAvailable) continue;
            if (path.targetInfo.outputTechnology == 15) continue; // skip Miracast (15)

            string key = path.targetInfo.adapterId.HighPart + ":" + path.targetInfo.adapterId.LowPart + ":" + path.targetInfo.id;
            if (!seenTargets.Add(key)) continue;

            var req = new DISPLAYCONFIG_TARGET_DEVICE_NAME();
            req.header.type = 2; // 2 = DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_NAME
            req.header.size = (uint)Marshal.SizeOf(typeof(DISPLAYCONFIG_TARGET_DEVICE_NAME));
            req.header.adapterId = path.targetInfo.adapterId;
            req.header.id = path.targetInfo.id;

            if (DisplayConfigGetDeviceInfo(ref req) == 0 && !string.IsNullOrWhiteSpace(req.monitorFriendlyDeviceName)) {
                string friendly = req.monitorFriendlyDeviceName.Trim();
                if (!names.Contains(friendly)) {
                    names.Add(friendly);
                }
            }
        }
        return names.ToArray();
    }


    public static int SetMode(string mode) {
        return SetDisplayMode(mode);
    }


    public static int SetWifiDirectEnabled(bool enable) {
        uint bestDevInst = FindWifiDirectDevInst();
        if (bestDevInst == 0) return -1;
        return enable ? (int)CM_Enable_DevNode(bestDevInst, 0) : (int)CM_Disable_DevNode(bestDevInst, 0x00000008); // 0x08 = CM_DISABLE_PERSIST
    }


    public static bool IsConnected() {
        foreach (string key in GetActiveTargets()) {
            if (!_baselineTargets.Contains(key)) {
                SaveActiveReceiverID(key);
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
        string savedID = GetSavedReceiverID();
        if (string.IsNullOrEmpty(savedID)) return false;

        uint pCount, mCount;
        if (GetDisplayConfigBufferSizes(1, out pCount, out mCount) != 0) return false;
        var paths = new DISPLAYCONFIG_PATH_INFO[pCount];
        var modes = new byte[mCount * 64];
        if (QueryDisplayConfig(1, ref pCount, paths, ref mCount, modes, IntPtr.Zero) != 0) return false;

        foreach (var path in paths) {
            if (path.targetInfo.targetAvailable) {
                string key = path.targetInfo.adapterId.HighPart + ":" + path.targetInfo.adapterId.LowPart + ":" + path.targetInfo.id;
                if (string.Equals(key, savedID, StringComparison.OrdinalIgnoreCase)) {
                    return true;
                }
            }
        }
        return false;
    }


    public static bool IsWifiRadioOn() {
        IntPtr client = IntPtr.Zero;
        IntPtr listPtr = IntPtr.Zero;
        try {
            uint negVer;
            if (WlanOpenHandle(2, IntPtr.Zero, out negVer, out client) != 0) return false;
            if (WlanEnumInterfaces(client, IntPtr.Zero, out listPtr) != 0 || listPtr == IntPtr.Zero) return false;
            int count = Marshal.ReadInt32(listPtr, 0);
            for (int i = 0; i < count; i++) {
                IntPtr itemPtr = IntPtr.Add(listPtr, 8 + i * 532);
                byte[] guidBytes = new byte[16];
                Marshal.Copy(itemPtr, guidBytes, 0, 16);
                Guid guid = new Guid(guidBytes);
                uint dataSize;
                IntPtr dataPtr;
                // OpCode 1 = wlan_intf_opcode_radio_state (struct: dwPhyIndex, dot11SoftwareRadioState, dot11HardwareRadioState; 1 = On)
                if (WlanQueryInterface(client, ref guid, 4, IntPtr.Zero, out dataSize, out dataPtr, IntPtr.Zero) == 0 && dataPtr != IntPtr.Zero) {
                    int swState = Marshal.ReadInt32(dataPtr, 8);
                    int hwState = Marshal.ReadInt32(dataPtr, 12);
                    WlanFreeMemory(dataPtr);
                    if (swState == 1 && hwState == 1) return true;
                }
            }
            return false;
        } catch {
            return false;
        } finally {
            if (listPtr != IntPtr.Zero) WlanFreeMemory(listPtr);
            if (client != IntPtr.Zero) WlanCloseHandle(client, IntPtr.Zero);
        }
    }


    public static bool IsWifiDirectEnabled() {
        uint devInst = FindWifiDirectDevInst();
        if (devInst == 0) return false;
        uint status, problem;
        if (CM_Get_DevNode_Status(out status, out problem, devInst, 0) != 0) return false;
        return (status & 0x00000008) != 0; // 0x00000008 = DN_STARTED
    }


    public static void CaptureBaseline() {
        ClearActiveReceiverID();
        _baselineTargets = GetActiveTargets();
    }


    public static int Disconnect() {
        bool toggled = false;
        try {
            using (var baseKey = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(WfdSwdEnumKey)) {
                if (baseKey != null) {
                    foreach (string sub in baseKey.GetSubKeyNames()) {
                        if (!sub.EndsWith("#MIRACAST", StringComparison.OrdinalIgnoreCase)) continue;
                        string instanceId = WfdSwdPrefix + @"\" + sub;
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
        ClearActiveReceiverID();
        return toggled ? 0 : SetDisplayMode("internal");
    }
}
