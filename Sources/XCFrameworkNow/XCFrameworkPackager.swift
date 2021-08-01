import Foundation
import arm64_to_sim

public class XCFrameworkPackager {
    
    let infoArray: [GenericInfo]
    
    let tempDirUrl: URL
    
    public init(info: [GenericInfo]) {
        self.infoArray = info
        
        tempDirUrl = FileManager.default.temporaryDirectory
            .appendingPathComponent("com.grc.xcframework-now")
            .appendingPathComponent(UUID().uuidString)
    }
    
    public func package(destination: URL) {
        
        try! FileManager.default.createDirectory(at: tempDirUrl, withIntermediateDirectories: true, attributes: nil)
        
        defer {
            try! FileManager.default.removeItem(at: tempDirUrl)
        }
        
        var inputParams = [String]()

        for info in infoArray {
            var map = [Platform: [Slice]]()
            info.slices.forEach {
                var slices = map[$0.destination] ?? [Slice]()
                slices.append($0)
                map[$0.destination] = slices
            }
            
            map.forEach { key, value in
                print("Process platform '\(key.stringValue())' containing (\(value.compactMap { $0.arch }.joined(separator: ", "))) slices...")
                let url = packagePlatformSlices(platform: key, info: info, slices: value)
                if let url = url {
                    if info is FrameworkInfo {
                        inputParams += ["-framework", "\(url.path)"]
                    } else if let libraryInfo = info as? LibraryInfo {
                        inputParams += ["-library", "\(url.path)"]
                        if let headersUrl = libraryInfo.headersUrl {
                            inputParams += ["-headers", "\(headersUrl.path)"]
                        }
                    }
                }
            }
            
            map.forEach { key, value in
                if let variant = key.simulatorVariant(), let variantSlices = map[variant],
                   let slice = value.first(where: { $0.arch == "arm64" }) {
                    if variantSlices.first(where: { $0.arch == "arm64" }) == nil {
                        print("Generate 'arm64' slice for platform '\(variant.stringValue())'...")
                        _ = translatePlatformSlice(platform: variant, info: info, slice: slice)
                    }
                }
            }
        }
        
        print("Create XCFramework...")
        let args = ["xcodebuild", "-create-xcframework"] + inputParams + ["-output",  "\(destination.path)"]
        let (shellStatus, shellOutput) = shell(pwd: tempDirUrl.path, args: args)
        
        if shellStatus == 0 {
            print("XCFramework successfully written out to: \(destination.path)")
        } else {
            print("Error: \(shellOutput)")
        }
    }
    
    
    func packagePlatformSlices(platform: Platform, info: GenericInfo, slices: [Slice]) -> URL? {
        let platformUrl = tempDirUrl.appendingPathComponent(platform.stringValue())
        try! FileManager.default.createDirectory(at: platformUrl, withIntermediateDirectories: true, attributes: nil)
        
        let baseUrl = platformUrl.appendingPathComponent(info.baseUrl.lastPathComponent)
        if let frameworkInfo = info as? FrameworkInfo {
            try! FileManager.default.copyItem(at: frameworkInfo.baseUrl, to: baseUrl)
        }
        
        let libraryUrl = platformUrl.appendingPathComponent(info.binaryRelativePath)
        
        var extractParams = [String]()
        slices.forEach { extractParams += ["-extract", $0.arch] }
        let (shellStatus, _) = shell(pwd: platformUrl.path, args: ["lipo"] + extractParams + ["-output", "\(libraryUrl.path)",  "\(info.binaryUrl.path)"])
        
        return shellStatus == 0 ? baseUrl : nil
    }
    
    func translatePlatformSlice(platform: Platform, info: GenericInfo, slice: Slice) -> Bool {
        let platformUrl = tempDirUrl.appendingPathComponent("\(platform.stringValue())-\(slice.arch)")
        try! FileManager.default.createDirectory(at: platformUrl, withIntermediateDirectories: true, attributes: nil)
        
        let libraryUrl = platformUrl.appendingPathComponent(info.binaryUrl.lastPathComponent)
        
        var (shellStatus, _) = shell(pwd: platformUrl.path, args: ["lipo", "-thin", "\(slice.arch)", "-output", "\(libraryUrl.path)",  "\(info.binaryUrl.path)"])
        
        if info.isDynamic {
            
            guard let simulatorPlatform = slice.destination.simulatorVariant() else { return false }
            
            let platformCode = simulatorPlatform.numericValue()
            let minVersion = slice.version
            let sdkVersion = slice.sdk
            
            (shellStatus, _) = shell("vtool",
                                     "-arch", "\(slice.arch)",
                                     "-set-build-version", "\(platformCode)", "\(minVersion)", "\(sdkVersion)",
                                     "-replace", "-output",  "\(libraryUrl.path)", "\(libraryUrl.path)")
            if shellStatus != 0 { return false }
            
        } else {
            
            (shellStatus, _) = shell(pwd: platformUrl.path, args: "ar", "x", "\(libraryUrl.path)")
            if shellStatus != 0 { return false }
            
            let enumerator = FileManager.default.enumerator(at: platformUrl, includingPropertiesForKeys: nil)
            var objectFiles = [String]()
            while let file = enumerator?.nextObject() as? URL {
                if file.pathExtension == "o" {
                    Transmogrifier.processBinary(atPath: file.path)
                    objectFiles.append(file.lastPathComponent)
                }
            }
            
            try! FileManager.default.removeItem(at: libraryUrl)
            
            (shellStatus, _) = shell(pwd: platformUrl.path, args: ["ar", "crv", "\(libraryUrl.path)"] + objectFiles)
            if shellStatus != 0 { return false }
        }
        
        let outputUrl = tempDirUrl.appendingPathComponent(platform.stringValue())
            .appendingPathComponent(info.binaryRelativePath)
        
        (shellStatus, _) = shell("lipo", "-create", "-output", "\(outputUrl.path)", "\(outputUrl.path)", "\(libraryUrl.path)")
        
        return shellStatus == 0
    }
}
