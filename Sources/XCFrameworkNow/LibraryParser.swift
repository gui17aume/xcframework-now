import Foundation

public struct LibraryInfo: GenericInfo {

    public let baseUrl: URL

    public let binaryUrl : URL

    public var isDynamic: Bool = false

    public var slices: [Slice] = .init()

    public var binaryRelativePath: String {
        return baseUrl.lastPathComponent
    }

    public var moduleUrlRelativePath: String? = nil

    public var headersUrl: URL?

}

public class LibraryParser: GenericParser {
    
    let path: String
    let headersPath: String?

    public init(path: String, headersPath: String?) {
        self.path = path
        self.headersPath = headersPath
    }
    
    public typealias Info = LibraryInfo
    
    public func parse() -> LibraryInfo? {
        
        let libraryUrl = URL(fileURLWithPath: path)
        let binaryUrl = libraryUrl
        let headersUrl: URL?
        
        if let headersPath = headersPath {
            headersUrl = URL(fileURLWithPath: headersPath)
        }
        else {
            headersUrl = nil
        }
        
        var info = LibraryInfo(baseUrl: libraryUrl, binaryUrl: binaryUrl, headersUrl: headersUrl)
        
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
