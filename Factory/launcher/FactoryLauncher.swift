import Foundation

let appRoot = "/Users/chiburashka/Documents/Codex/Simastry/Factory"
let port = ProcessInfo.processInfo.environment["SIMASTRY_FACTORY_PORT"] ?? "8765"
let host = ProcessInfo.processInfo.environment["SIMASTRY_FACTORY_HOST"] ?? "127.0.0.1"
let openHost = host == "0.0.0.0" ? "127.0.0.1" : host
let url = "http://\(openHost):\(port)/"
let statsURL = "\(url)api/stats"
let logDirectory = "\(appRoot)/workspace/logs"
let logFile = "\(logDirectory)/factory-server.log"
let pidFile = "\(logDirectory)/server.pid"

var serverProcess: Process?

func runProcess(_ executable: String, _ arguments: [String]) -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    if let nullOutput = FileHandle(forWritingAtPath: "/dev/null") {
        process.standardOutput = nullOutput
        process.standardError = nullOutput
    }
    do {
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    } catch {
        return 1
    }
}

func serverIsReady() -> Bool {
    runProcess("/usr/bin/curl", ["-fsS", statsURL]) == 0
}

func openDashboard() {
    _ = runProcess("/usr/bin/open", [url])
}

try? FileManager.default.createDirectory(
    at: URL(fileURLWithPath: logDirectory),
    withIntermediateDirectories: true
)

if serverIsReady() {
    openDashboard()
    exit(0)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
process.arguments = ["python3", "\(appRoot)/server.py", "--host", host, "--port", port]
process.currentDirectoryURL = URL(fileURLWithPath: appRoot)

if !FileManager.default.fileExists(atPath: logFile) {
    FileManager.default.createFile(atPath: logFile, contents: nil)
}

if let logOutput = FileHandle(forWritingAtPath: logFile) {
    try? logOutput.seekToEnd()
    process.standardOutput = logOutput
    process.standardError = logOutput
}

do {
    try process.run()
    serverProcess = process
    try? "\(process.processIdentifier)\n".write(toFile: pidFile, atomically: true, encoding: .utf8)
} catch {
    openDashboard()
    exit(1)
}

atexit {
    if let process = serverProcess, process.isRunning {
        process.terminate()
    }
}

Thread.detachNewThread {
    for _ in 0..<60 {
        if serverIsReady() {
            openDashboard()
            return
        }
        Thread.sleep(forTimeInterval: 0.2)
    }
    openDashboard()
}

process.waitUntilExit()
