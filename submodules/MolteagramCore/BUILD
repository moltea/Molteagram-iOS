load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "MolteagramCore",
    module_name = "MolteagramCore",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        
    ],
    deps = [
        "//third-party/ZipArchive:ZipArchive",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
    ],
    visibility = [
        "//visibility:public",
    ],
)
