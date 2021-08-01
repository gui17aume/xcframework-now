import Foundation
import ArgumentParser
import XCFrameworkNow

struct XCFrameworkNowCommand: ParsableCommand {
    
    static let configuration = CommandConfiguration(
        commandName:"xcframework-now",
        abstract: "Utility for transforming a given library or framework into an XCFramework, generating the arm64 simulator slices if missing.",
        helpNames: .customLong("help", withSingleDash: true)
    )
    
    func validate() throws {
        if frameworks.isEmpty && libraries.isEmpty {
            throw ValidationError("At least one framework or one library must be provided.")
        }
        
        if !frameworks.isEmpty && !libraries.isEmpty {
            throw ValidationError("Frameworks and libraries cannot be mixed.")
        }
        
        if !libraries.isEmpty && headers.count > libraries.count {
            throw ValidationError("There should not be more headers provided than libraries.")
        }
        
        for framework in frameworks {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: framework, isDirectory: &isDirectory),
                  isDirectory.boolValue == true else {
                throw ValidationError("Unable to find framework at path: \(framework)")
            }
            guard URL(fileURLWithPath: framework).pathExtension == "framework" else {
                throw ValidationError("The path does not point to a valid framework: \(framework)")
            }
        }
        
        for library in libraries {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: library, isDirectory: &isDirectory),
                  isDirectory.boolValue == false else {
                throw ValidationError("Unable to find library at path: \(library)")
            }
            guard ["a", "dylib"].contains(URL(fileURLWithPath: library).pathExtension) else {
                throw ValidationError("The path does not point to a valid library: \(library)")
            }
        }
        
        for headersFolder in headers {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: headersFolder, isDirectory: &isDirectory),
                  isDirectory.boolValue == true else {
                throw ValidationError("Unable to find headers folder at path: \(headersFolder)")
            }
        }
        
        guard URL(fileURLWithPath: output).pathExtension == "xcframework" else {
            throw ValidationError("The output path must end with the extension 'xcframework'.")
        }
        
        guard !FileManager.default.fileExists(atPath: output, isDirectory:nil) else {
            throw ValidationError("The destination already exists at path: \(output)")
        }
    }
    
    @Option(name: .customLong("framework", withSingleDash: true),
            help: ArgumentHelp("Adds a framework from the given <path>.", discussion: "", valueName: "path", shouldDisplay: true))
    var frameworks: [String] = []

    @Option(name: .customLong("library", withSingleDash: true),
            help: ArgumentHelp("Adds a static or dynamic library from the given <path>.", discussion: "", valueName: "path", shouldDisplay: true))
    var libraries: [String] = []

    @Option(name: .customLong("headers", withSingleDash: true),
            help: ArgumentHelp("Adds the headers from the given <path>. Only applicable with -library.", discussion: "", valueName: "path", shouldDisplay: true))
    var headers: [String] = []

    @Option(name: .customLong("output", withSingleDash: true),
            help: ArgumentHelp("The <path> to write the xcframework to.", discussion: "", valueName: "path", shouldDisplay: true))
    var output: String

    func run() {
        var infoArray = [GenericInfo]()
        
        if !frameworks.isEmpty {
            for framework in frameworks {
                let parser = FrameworkParser(path: framework)
                if let info = parser.parse() {
                    infoArray.append(info)
                }
            }
        } else if !libraries.isEmpty {
            var headersIterator = headers.makeIterator()
            for library in libraries {
                let parser = LibraryParser(path: library, headersPath: headersIterator.next())
                if let info = parser.parse() {
                    infoArray.append(info)
                }
            }
        }
        else {
            fatalError()
        }
        
        let packager = XCFrameworkPackager(info: infoArray)
        packager.package(destination: URL(fileURLWithPath: output))
    }
    
}

XCFrameworkNowCommand.main()
