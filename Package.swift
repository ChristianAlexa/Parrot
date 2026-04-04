// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Parrot",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Parrot", targets: ["Parrot"])
    ],
    targets: [
        .executableTarget(
            name: "Parrot",
            dependencies: [
                .target(name: "whisper"),
                .target(name: "llama"),
            ],
            path: "Sources/Parrot",
            resources: [
                .process("../../Resources")
            ]
        ),
        .testTarget(
            name: "ParrotTests",
            dependencies: ["Parrot"],
            path: "Tests/ParrotTests"
        ),
        .binaryTarget(
            name: "whisper",
            url: "https://github.com/ggml-org/whisper.cpp/releases/download/v1.8.4/whisper-v1.8.4-xcframework.zip",
            checksum: "1c7a93bd20fe4e57e0af12051ddb34b7a434dfc9acc02c8313393150b6d1821f"
        ),
        .binaryTarget(
            name: "llama",
            url: "https://github.com/ggml-org/llama.cpp/releases/download/b8559/llama-b8559-xcframework.zip",
            checksum: "ab62f591a8f2f945d9c664e3c56cf0a73dbcd11eaae12d1b0626bf8527318525"
        ),
    ]
)
