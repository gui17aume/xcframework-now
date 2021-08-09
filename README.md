# XCFrameworkNow

XCFrameworkNow is a command-line tool that transforms a given library or framework into an XCFramework, generating the arm64 simulator slices if missing.
This allows to build and run Xcode projects natively on Apple Silicon computers even if the developer of the library did not release a compatible version yet. No more Rosetta needed!

It supports static and dynamic libraries as input and can generate the arm64 slices for iOS, tvOS and watchOS simulators.

This tool is based on the project [arm64-to-sim](https://github.com/bogo/arm64-to-sim).


## Installation

### Homebrew
The easiest way to install XCFrameworkNow is by using [Homebrew](https://brew.sh):
```sh
brew tap gui17aume/core
brew install xcframework-now
```

### Manual install
XCFrameworkNow can be compiled and installed manually by retrieving the source code and using the following commands:
```sh
swift build -c release --disable-sandbox
install .build/release/xcframework-now /usr/local/bin
```

## Usage
Convert a framework including the architectures for device and simulator platforms into an XCFramework:
```sh
xcframework-now -framework Foo.framework -output Foo.xcframework
```

Convert a library including the architectures for device and simulator platforms into an XCFramework:
```sh
xcframework-now -library libFoo.a -headers include -output Foo.xcframework
```

Convert a set of frameworks made for various platforms into a single XCFramework:
```sh
xcframework-now -framework Foo-iOS.framework -framework Foo-tvOS.framework -output Foo.xcframework
```

Convert a library split by platform into an XCFramework:
```sh
xcframework-now -library ios/libFoo.a -headers ios/include -library iossimulator/libFoo.a -headers iossimulator/include -output Foo.xcframework
```
