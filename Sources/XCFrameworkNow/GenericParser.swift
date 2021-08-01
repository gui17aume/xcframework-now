import Foundation

public protocol GenericParser {
    
    associatedtype Info
    func parse() -> Info?
    
}

extension GenericParser {

    func isBinaryDynamic(at url: URL) -> Bool {
        let (shellStatus, _) = shell("vtool", "-show", "\(url.path)")
        let isDynamic = (shellStatus == 0)
        return isDynamic
    }
    
    func parseBinaryArchitectures(at url: URL) -> [String] {
        let (shellStatus, shellOutput) = shell("lipo", "-archs", "\(url.path)")
        guard shellStatus == 0 else { return [] }
        
        let lastLine = shellOutput.components(separatedBy: "\n").compactMap({ $0.isEmpty ? nil : $0 }).last ?? ""
        let archs = lastLine.components(separatedBy: " ").compactMap({ $0.isEmpty ? nil : $0 })
        
        return archs
    }
    
    func parseDynamicBinary(at url: URL) -> [Slice] {
        var slices = [Slice]()
        
        let archs = parseBinaryArchitectures(at: url)
        
        for arch in archs {
            let (shellStatus, shellOutput) = shell("vtool", "-show-build", "-arch", "\(arch)", "\(url.path)")
            if shellStatus != 0 { continue }
            
            if let slice = parseSlice(for: arch, description: shellOutput) {
                slices.append(slice)
            }
        }
        
        return slices
    }
    
    func parseStaticBinary(at url: URL) -> [Slice] {
        var slices = [Slice]()
        
        let archs = parseBinaryArchitectures(at: url)
        
        for arch in archs {
            let (shellStatus, shellOutput) = shell("otool", "-l", "-arch", "\(arch)", "\(url.path)")
            if shellStatus != 0 { continue }
            
            if let slice = parseSlice(for: arch, description: shellOutput) {
                slices.append(slice)
            }
        }
        
        return slices
    }
    
    func parseSlice(for arch: String, description: String) -> Slice? {
        var isParsingVersions = false
        var platform: Platform?
        var version: String?
        var sdk: String?
        
        description.enumerateLines { line, stop in
            let items = line.components(separatedBy: " ").compactMap { $0.isEmpty ? nil : $0 }
            guard items.count >= 2 else { return }
            
            let key = items[0]
            let value = items[1...].joined(separator: " ")
            
            if key == "cmd" {
                if isParsingVersions {
                    stop = true
                    return
                }
                
                isParsingVersions = [
                    "LC_VERSION_MIN_IPHONEOS",
                    "LC_VERSION_MIN_WATCHOS",
                    "LC_VERSION_MIN_TVOS",
                    "LC_BUILD_VERSION"
                ].contains(value)
                
                if isParsingVersions {
                    platform = Platform(loadCommand: value, arch: arch)
                }
                return
            }
            else if isParsingVersions {
                if key == "platform" {
                    platform = Platform(string: value)
                }
                if (key == "version" || key == "minos") {
                    version = value
                }
                if key == "sdk" {
                    sdk = value
                }
            }
        }
        
        if let platform = platform, let version = version, let sdk = sdk {
            let slice = Slice(arch: arch, destination: platform, version: version, sdk: sdk)
            return slice
        }
        
        return nil
    }
    
}
