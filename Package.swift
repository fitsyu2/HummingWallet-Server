// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HummingWallet",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "HummingWallet",
            targets: ["HummingWallet"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(url: "https://github.com/swift-server-community/APNSwift.git", from: "5.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/vapor/multipart-kit.git", from: "4.0.0")
    ],
    targets: [
        .executableTarget(
            name: "HummingWallet",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "APNS", package: "APNSwift"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
                .product(name: "MultipartKit", package: "multipart-kit")
            ]
        )
    ]
)