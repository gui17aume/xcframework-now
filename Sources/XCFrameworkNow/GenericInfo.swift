import Foundation

public protocol GenericInfo {
    
    var baseUrl: URL { get }

    var binaryUrl: URL { get }
    
    var binaryRelativePath: String { get }
    
    var isDynamic: Bool { get set }

    var slices: [Slice] { get set }
    
}

public struct Slice {
    
    let arch: String

    let destination: Platform
    
    let version: String
    
    let sdk: String
    
}

public enum Platform {
    
    case macos
    case ios
    case tvos
    case watchos
    case maccatalyst
    case iossimulator
    case tvossimulator
    case watchossimulator
    
    init?(string: String) {
        switch string {
        case "MACOS", "\(PLATFORM_MACOS)": self = .macos
        case "IOS", "\(PLATFORM_IOS)": self = .ios
        case "TVOS", "\(PLATFORM_TVOS)": self = .tvos
        case "WATCHOS", "\(PLATFORM_WATCHOS)": self = .watchos
        case "MACCATALYST", "\(PLATFORM_MACCATALYST)": self = .maccatalyst
        case "IOSSIMULATOR", "\(PLATFORM_IOSSIMULATOR)": self = .iossimulator
        case "TVOSSIMULATOR", "\(PLATFORM_TVOSSIMULATOR)": self = .tvossimulator
        case "WATCHOSSIMULATOR", "\(PLATFORM_WATCHOSSIMULATOR)": self = .watchossimulator
        default: return nil
        }
    }
    
    init?(loadCommand: String, arch: String) {
        let isArchARM = arch.hasPrefix("arm")
        switch loadCommand {
        case "LC_VERSION_MIN_MACOSX": self = .macos
        case "LC_VERSION_MIN_IPHONEOS": self = isArchARM ? .ios : .iossimulator
        case "LC_VERSION_MIN_WATCHOS": self = isArchARM ? .watchos : .watchossimulator
        case "LC_VERSION_MIN_TVOS": self = isArchARM ? .tvos : .tvossimulator
        default: return nil
        }
    }
    
    func numericValue() -> Int32 {
        switch self {
        case .macos: return PLATFORM_MACOS
        case .ios: return PLATFORM_IOS
        case .tvos: return PLATFORM_TVOS
        case .watchos: return PLATFORM_WATCHOS
        case .maccatalyst: return PLATFORM_MACCATALYST
        case .iossimulator: return PLATFORM_IOSSIMULATOR
        case .tvossimulator: return PLATFORM_TVOSSIMULATOR
        case .watchossimulator: return PLATFORM_WATCHOSSIMULATOR
        }
    }
    
    func stringValue() -> String {
        switch self {
        case .macos: return "macos"
        case .ios: return "ios"
        case .tvos: return "tvos"
        case .watchos: return "watchos"
        case .maccatalyst: return "maccatalyst"
        case .iossimulator: return "iossimulator"
        case .tvossimulator: return "tvossimulator"
        case .watchossimulator: return "watchossimulator"
        }
    }
    
    func simulatorVariant() -> Platform? {
        switch self {
        case .ios: return .iossimulator
        case .tvos: return .tvossimulator
        case .watchos: return .watchossimulator
        default: return nil
        }
    }
    
}
