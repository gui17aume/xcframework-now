import Foundation
import arm64_to_sim

enum PackagerError: Error {
    case samePlatformInMultipleLibraries(platform: Platform, lib1: GenericInfo, lib2: GenericInfo)
}

extension PackagerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .samePlatformInMultipleLibraries(platform, lib1, lib2):
            return "Slices for the same platform in multiple libraries is not supported: '\(platform)' slices found in \(lib1.baseUrl.path) and \(lib2.baseUrl.path)"
        }
    }
}

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
        
        let splitInfo: [Platform: GenericInfo]
        do {
            splitInfo = try infoByPlatform()
        } catch let error {
            print("Error: \(error.localizedDescription)")
            return
        }
                
        splitInfo.forEach { platform, info in
            print("Process platform '\(platform.stringValue())' containing (\(info.slices.compactMap { $0.arch }.joined(separator: ", "))) slices...")
            let url = packagePlatformSlices(platform: platform, info: info)
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
        
        splitInfo.forEach { platform, info in
            if let variant = platform.simulatorVariant(), let variantInfo = splitInfo[variant],
               let slice = info.slices.first(where: { $0.arch == "arm64" }) {
                if variantInfo.slices.first(where: { $0.arch == "arm64" }) == nil {
                    print("Generate 'arm64' slice for platform '\(variant.stringValue())'...")
                    _ = translatePlatformSlice(platform: variant, info: info, slice: slice)
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
    
    func infoByPlatform() throws -> [Platform: GenericInfo] {
        var infoByPlatform = [Platform: GenericInfo]()
        
        for info in infoArray {
            var map = [Platform: [Slice]]()
            for slice in info.slices {
                let platform = slice.destination
                var slices = map[platform] ?? [Slice]()
                slices.append(slice)
                map[platform] = slices
            }
            for (platform, slices) in map {
                if let existingInfo = infoByPlatform[platform] {
                    throw PackagerError.samePlatformInMultipleLibraries(platform: platform, lib1: existingInfo, lib2: info)
                }
                var filteredInfo = info
                filteredInfo.slices = slices
                infoByPlatform[platform] = filteredInfo
            }
        }
        
        return infoByPlatform
    }
    
    func packagePlatformSlices(platform: Platform, info: GenericInfo) -> URL? {
        let platformUrl = tempDirUrl.appendingPathComponent(platform.stringValue())
        try! FileManager.default.createDirectory(at: platformUrl, withIntermediateDirectories: true, attributes: nil)
        
        let baseUrl = platformUrl.appendingPathComponent(info.baseUrl.lastPathComponent)
        if let frameworkInfo = info as? FrameworkInfo {
            try! FileManager.default.copyItem(at: frameworkInfo.baseUrl, to: baseUrl)
        }
        
        let libraryUrl = platformUrl.appendingPathComponent(info.binaryRelativePath)
        
        var extractParams = [String]()
        info.slices.forEach { extractParams += ["-extract", $0.arch] }
        if info.slices.count > 1 {
            let (shellStatus, _) = shell(pwd: platformUrl.path, args: ["lipo"] + extractParams + ["-output", "\(libraryUrl.path)",  "\(info.binaryUrl.path)"])
            return shellStatus == 0 ? baseUrl : nil
        } else {
            let (shellStatus, _) = shell(pwd: platformUrl.path, args: ["cp", "\(info.binaryUrl.path)", "\(libraryUrl.path)"])
            return shellStatus == 0 ? baseUrl : nil
        }

    }
    
    func translatePlatformSlice(platform: Platform, info: GenericInfo, slice: Slice) -> Bool {
        let platformUrl = tempDirUrl.appendingPathComponent("\(platform.stringValue())-\(slice.arch)")
        try! FileManager.default.createDirectory(at: platformUrl, withIntermediateDirectories: true, attributes: nil)
        
        let libraryUrl = platformUrl.appendingPathComponent(info.binaryUrl.lastPathComponent)

        if info.slices.count > 1 {
          let (shellStatus, shellOutput) = shell(pwd: platformUrl.path, args: ["lipo", "-thin", "\(slice.arch)", "-output", "\(libraryUrl.path)",  "\(info.binaryUrl.path)"])
          if shellStatus != 0 {
              print("Error: \(shellOutput)")
          }
        } else {
          let (shellStatus, shellOutput) = shell(pwd: platformUrl.path, args: ["cp", "\(info.binaryUrl.path)", "\(libraryUrl.path)"])
          if shellStatus != 0 {
              print("Error: \(shellOutput)")
          }
        }

        if info.isDynamic {
            
            guard let simulatorPlatform = slice.destination.simulatorVariant() else { return false }
            
            let platformCode = simulatorPlatform.numericValue()
            let minVersion = slice.version
            let sdkVersion = slice.sdk

            let (shellStatus, shellOutput) = shell("vtool",
                                     "-arch", "\(slice.arch)",
                                     "-set-build-version", "\(platformCode)", "\(minVersion)", "\(sdkVersion)",
                                     "-replace", "-output",  "\(libraryUrl.path)", "\(libraryUrl.path)")

           if shellStatus != 0 {
               print("Error: \(shellOutput)")
           }

            if shellStatus != 0 { return false }
            
        } else {

            var (shellStatus, _) = shell(pwd: platformUrl.path, args: "ar", "x", "\(libraryUrl.path)")
            if shellStatus != 0 { return false }
            
            let enumerator = FileManager.default.enumerator(at: platformUrl, includingPropertiesForKeys: nil)
            var objectFiles = [String]()
            while let file = enumerator?.nextObject() as? URL {
                if file.pathExtension == "o" {
                    Transmogrifier.processBinary(atPath: file.path)
                    objectFiles.append(file.lastPathComponent)
                }
            }
            
            (shellStatus, _) = shell(pwd: platformUrl.path, args: ["ar", "crv", "\(libraryUrl.path)"] + objectFiles)
            if shellStatus != 0 { return false }
        }
        
        let outputUrl = tempDirUrl.appendingPathComponent(platform.stringValue())
            .appendingPathComponent(info.binaryRelativePath)

        let (shellStatus, shellOutput) = shell("lipo", "-create", "-output", "\(outputUrl.path)", "\(outputUrl.path)", "\(libraryUrl.path)")

        if shellStatus != 0 {
            print("Error: \(shellOutput)")
        }

        if let moduleUrlRelativePath = info.moduleUrlRelativePath {
            // Copy over .swiftdoc and .swiftinterface as well

            let doc_src = info.baseUrl.appendingPathComponent(moduleUrlRelativePath).appendingPathComponent("\(slice.arch).swiftdoc")
            let doc_dst = tempDirUrl.appendingPathComponent(platform.stringValue()).appendingPathComponent(info.baseUrl.lastPathComponent).appendingPathComponent(moduleUrlRelativePath).appendingPathComponent("\(slice.arch).swiftdoc")

            var (shellStatus, shellOutput) = shell(pwd: platformUrl.path, args: ["cp", "\(doc_src.path)", "\(doc_dst.path)"])
            if shellStatus != 0 {
                print("Error generating swiftinterface: \(shellOutput)")
            }

            let interface_src = info.baseUrl.appendingPathComponent(moduleUrlRelativePath).appendingPathComponent("\(slice.arch).swiftinterface")
            let interface_dst = tempDirUrl.appendingPathComponent(platform.stringValue()).appendingPathComponent(info.baseUrl.lastPathComponent).appendingPathComponent(moduleUrlRelativePath).appendingPathComponent("\(slice.arch).swiftinterface")

            (shellStatus, shellOutput) = shell(pwd: platformUrl.path, args: ["sed", "-E", "s/(arm64-apple-ios[^ ]*)/\\1-simulator/", "\(interface_src.path)"])
            if shellStatus != 0 {
                print("Error generating swiftdoc: \(shellOutput)")
            } else {
                do {
                    try shellOutput.write(to: interface_dst, atomically: true, encoding: String.Encoding.utf8)
                } catch (let e) {
                    print("Error writing swiftdoc: \(e)")
                }
            }
        }

        return shellStatus == 0
    }
}
