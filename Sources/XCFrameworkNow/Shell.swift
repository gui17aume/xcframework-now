import Foundation

@discardableResult
func shell(_ args: String...) -> (Int32, String) {
    return shell(pwd: nil, args: args)
}
    
@discardableResult
func shell(pwd: String?, args: String...) -> (Int32, String) {
    return shell(pwd: pwd, args: args)
}

@discardableResult
func shell(pwd: String?, args: [String]) -> (Int32, String) {
    let task = Process()
    task.launchPath = "/usr/bin/env"
    if let pwd = pwd {
        task.currentDirectoryPath = pwd
    }
    task.arguments = args
    let pipe = Pipe()
    var tempStdOutStorage = Data()
    pipe.fileHandleForReading.readabilityHandler = { stdOutFileHandle in
        let stdOutPartialData = stdOutFileHandle.availableData
        if stdOutPartialData.isEmpty  {
            pipe.fileHandleForReading.readabilityHandler = nil
        } else {
            tempStdOutStorage.append(stdOutPartialData)
        }
    }
    task.standardOutput = pipe
    task.standardError = pipe
    task.launch()
    task.waitUntilExit()
    
    guard let output: String = String(data: tempStdOutStorage, encoding: .utf8) else { return (-1, "") }
    return (task.terminationStatus, output)
}
