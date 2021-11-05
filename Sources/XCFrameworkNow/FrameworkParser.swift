import Foundation

public struct FrameworkInfo: GenericInfo {
    
    public let baseUrl: URL
    
    public let binaryUrl : URL
    
    public var isDynamic: Bool = false
    
    public var slices: [Slice] = .init()
    
    public var binaryRelativePath: String {
        return baseUrl.lastPathComponent + "/" + binaryUrl.lastPathComponent
    }

    public var moduleUrlRelativePath: String? {
        return "Modules/" + binaryUrl.lastPathComponent + ".swiftmodule"
    }

}

public class FrameworkParser: GenericParser {
    
    let path: String
    
    public init(path: String) {
        self.path = path
    }
    
    public typealias Info = FrameworkInfo
    
    public func parse() -> FrameworkInfo? {
        
        let frameworkUrl = URL(fileURLWithPath: path)
        let binaryName = frameworkUrl.deletingPathExtension().lastPathComponent
        let binaryUrl = frameworkUrl.appendingPathComponent(binaryName)
        
        var info = FrameworkInfo(baseUrl: frameworkUrl, binaryUrl: binaryUrl)
        
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: binaryUrl.path, isDirectory: &isDirectory),
              isDirectory.boolValue == false else {
            print("Binary not found at path: \(binaryUrl.path)")
            return nil
        }
        
        info.isDynamic = isBinaryDynamic(at: binaryUrl)
        
        if info.isDynamic {
            info.slices += parseDynamicBinary(at: binaryUrl)
        } else {
            info.slices += parseStaticBinary(at: binaryUrl)
        }
        
        return info
    }
    
}
