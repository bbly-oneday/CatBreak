import CoreAudio
import os.log

/// 麦克风监测器
///
/// 核心逻辑：通讯类应用（会议/通话）被使用时，麦克风一定处于占用状态。
/// 因此只需检测系统麦克风是否被占用即可判断是否需要推迟休息。
/// - 麦克风被占用 → 停止休息（用户正在开会/通话）
/// - 麦克风空闲 → 正常休息
struct SensitiveAppDetector {

    /// 检测麦克风是否正在被使用
    /// - Returns: (isActive: 是否在用麦克风, reason: 原因描述)
    static func checkActive() -> (isActive: Bool, reason: String) {
        if isMicrophoneInUse() {
            return (true, "检测到暂停休息事件，推迟休息")
        }
        return (false, "")
    }

    // MARK: - 麦克风检测

    /// 检测系统是否有任意输入设备正在被占用
    /// 原理：遍历所有输入设备（内置麦克风、耳机麦克风等），只要有一个正在录制就返回 true
    /// 修复：仅检查默认输入设备时，外接耳机/蓝牙设备的 DeviceIsRunningSomewhere 可能不准确
    private static func isMicrophoneInUse() -> Bool {
        // 遍历所有音频设备，检查是否有输入设备正在运行
        return checkAllInputDevicesRunning()
    }

    /// 遍历所有音频设备，检查是否有输入设备正在被某个应用使用
    private static func checkAllInputDevicesRunning() -> Bool {
        // 获取系统中所有音频设备列表
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        // 先查询设备数量，获取需要的 buffer 大小
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )

        guard status == noErr else {
            Logger.audio.error("Failed to get audio device property data size: \(status)")
            return false
        }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        var deviceIDs = [AudioObjectID](repeating: 0, count: deviceCount)

        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceIDs
        )

        guard status == noErr else {
            Logger.audio.error("Failed to get audio device IDs: \(status)")
            return false
        }

        // 遍历每个设备，只检查输入设备
        for deviceID in deviceIDs {
            if isInputDevice(deviceID) && isDeviceRunning(deviceID) {
                return true
            }
        }

        return false
    }

    /// 判断一个音频设备是否是输入设备（有输入 stream）
    private static func isInputDevice(_ deviceID: AudioObjectID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(
            deviceID,
            &address,
            0,
            nil,
            &dataSize
        )

        // 有输入 stream 且 size > 0 说明是输入设备
        return status == noErr && dataSize > 0
    }

    /// 检查设备是否正在运行（被应用占用）
    private static func isDeviceRunning(_ deviceID: AudioObjectID) -> Bool {
        // 优先检查 DeviceIsRunningSomewhere
        var isRunning = UInt32(0)
        var runningAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var runningSize = UInt32(MemoryLayout<UInt32>.size)

        let runningStatus = AudioObjectGetPropertyData(
            deviceID,
            &runningAddress,
            0,
            nil,
            &runningSize,
            &isRunning
        )

        if runningStatus == noErr && isRunning != 0 {
            return true
        }

        // 备用检查：kAudioDevicePropertyDeviceIsRunning
        // 有些设备（尤其是蓝牙/USB 耳机）不报告 RunningSomewhere，但会报告 IsRunning
        var isRunningAlt = UInt32(0)
        var altAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunning,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var altSize = UInt32(MemoryLayout<UInt32>.size)

        let altStatus = AudioObjectGetPropertyData(
            deviceID,
            &altAddress,
            0,
            nil,
            &altSize,
            &isRunningAlt
        )

        return altStatus == noErr && isRunningAlt != 0
    }

}
