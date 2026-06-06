import os.log

extension Logger {
    static let timer = Logger(subsystem: "com.huibin.CatBreak", category: "Timer")
    static let audio = Logger(subsystem: "com.huibin.CatBreak", category: "Audio")
    static let app = Logger(subsystem: "com.huibin.CatBreak", category: "App")
    static let detector = Logger(subsystem: "com.huibin.CatBreak", category: "Detector")
}