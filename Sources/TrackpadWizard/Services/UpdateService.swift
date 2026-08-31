import AppKit
import CryptoKit
import Foundation
import Observation

struct AppReleaseVersion: Comparable, CustomStringConvertible, Equatable, Sendable {
    let major: Int
    let minor: Int
    let patch: Int
    let build: Int

    init(major: Int, minor: Int, patch: Int, build: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.build = build
    }

    init?(tag: String) {
        var value = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if value.hasPrefix("v") {
            value.removeFirst()
        }

        let versionAndBuild = value.components(separatedBy: "-build.")
        guard versionAndBuild.count <= 2 else { return nil }
        let components = versionAndBuild[0].split(separator: ".")
        guard components.count == 3,
              let major = Int(components[0]),
              let minor = Int(components[1]),
              let patch = Int(components[2]) else {
            return nil
        }
        let build: Int
        if versionAndBuild.count == 2 {
            guard let parsedBuild = Int(versionAndBuild[1]) else { return nil }
            build = parsedBuild
        } else {
            build = 0
        }
        self.init(major: major, minor: minor, patch: patch, build: build)
    }

    static var current: AppReleaseVersion {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "0.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            ?? "0"
        return AppReleaseVersion(tag: "\(version)-build.\(build)")
            ?? AppReleaseVersion(major: 0, minor: 0, patch: 0, build: 0)
    }

    static func < (lhs: AppReleaseVersion, rhs: AppReleaseVersion) -> Bool {
        [lhs.major, lhs.minor, lhs.patch, lhs.build]
            .lexicographicallyPrecedes([rhs.major, rhs.minor, rhs.patch, rhs.build])
    }

    var description: String {
        "\(major).\(minor).\(patch) (Build \(build))"
    }
}

struct GitHubRelease: Decodable, Equatable, Sendable {
    struct Asset: Decodable, Equatable, Sendable {
        let name: String
        let browserDownloadURL: URL

        private enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    let tagName: String
    let name: String?
    let htmlURL: URL
    let draft: Bool
    let prerelease: Bool
    let assets: [Asset]

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case htmlURL = "html_url"
        case draft
        case prerelease
        case assets
    }

    var version: AppReleaseVersion? { AppReleaseVersion(tag: tagName) }

    var diskImageAsset: Asset? {
        assets.first { $0.name.lowercased().hasSuffix(".dmg") }
    }

    func checksumAsset(for diskImage: Asset) -> Asset? {
        assets.first { $0.name == "\(diskImage.name).sha256" }
    }
}

@MainActor
@Observable
final class UpdateService {
    enum State: Equatable {
        case idle
        case checking
        case upToDate(AppReleaseVersion)
        case updateAvailable(GitHubRelease)
        case downloading(GitHubRelease)
        case downloaded(GitHubRelease, URL)
        case failed(String)
    }

    private(set) var state: State = .idle

    @ObservationIgnored private let latestReleaseEndpoint = URL(
        string: "https://api.github.com/repos/jasonhejiahuan/Mac-Trackpad-Wizard/releases/latest"
    )!

    var statusText: String {
        switch state {
        case .idle:
            "Not checked"
        case .checking:
            "Checking GitHub Releases…"
        case .upToDate(let version):
            "Up to date — \(version.description)"
        case .updateAvailable(let release):
            "\(release.version?.description ?? release.tagName) is available"
        case .downloading(let release):
            "Downloading \(release.version?.description ?? release.tagName)…"
        case .downloaded(let release, _):
            "\(release.version?.description ?? release.tagName) is ready to install"
        case .failed(let message):
            message
        }
    }

    var isBusy: Bool {
        switch state {
        case .checking, .downloading: true
        default: false
        }
    }

    var availableRelease: GitHubRelease? {
        switch state {
        case .updateAvailable(let release),
             .downloading(let release),
             .downloaded(let release, _):
            release
        default:
            nil
        }
    }

    var downloadedInstallerURL: URL? {
        guard case .downloaded(_, let url) = state else { return nil }
        return url
    }

    func checkForUpdates(currentVersion: AppReleaseVersion = .current) async {
        guard !isBusy else { return }
        state = .checking
        do {
            var request = URLRequest(url: latestReleaseEndpoint)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("Trackpad-Wizard-Update-Checker", forHTTPHeaderField: "User-Agent")
            let data = try await responseData(for: request)
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            guard !release.draft,
                  !release.prerelease,
                  let releaseVersion = release.version else {
                throw UpdateError.invalidReleaseMetadata
            }
            state = releaseVersion > currentVersion
                ? .updateAvailable(release)
                : .upToDate(currentVersion)
        } catch {
            state = .failed("Update check failed: \(error.localizedDescription)")
        }
    }

    func downloadAvailableUpdate() async {
        guard let release = availableRelease else { return }
        guard let diskImage = release.diskImageAsset,
              let checksum = release.checksumAsset(for: diskImage) else {
            state = .failed("The release is missing its notarized disk image or checksum.")
            return
        }
        state = .downloading(release)

        do {
            let checksumData = try await responseData(for: URLRequest(url: checksum.browserDownloadURL))
            guard let checksumText = String(data: checksumData, encoding: .utf8),
                  let expectedHash = checksumText.split(whereSeparator: \.isWhitespace).first,
                  expectedHash.count == 64 else {
                throw UpdateError.invalidChecksum
            }

            let (temporaryURL, response) = try await URLSession.shared.download(from: diskImage.browserDownloadURL)
            try validate(response: response)
            let diskImageData = try Data(contentsOf: temporaryURL, options: .mappedIfSafe)
            let actualHash = SHA256.hash(data: diskImageData).map { String(format: "%02x", $0) }.joined()
            guard actualHash.caseInsensitiveCompare(String(expectedHash)) == .orderedSame else {
                throw UpdateError.checksumMismatch
            }

            let destination = try updateCacheURL(
                release: release,
                filename: diskImage.name
            )
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: destination.path) {
                _ = try fileManager.replaceItemAt(destination, withItemAt: temporaryURL)
            } else {
                try fileManager.moveItem(at: temporaryURL, to: destination)
            }
            state = .downloaded(release, destination)
        } catch {
            state = .failed("Update download failed: \(error.localizedDescription)")
        }
    }

    func openReleasePage() {
        guard let url = availableRelease?.htmlURL else { return }
        NSWorkspace.shared.open(url)
    }

    func openDownloadedInstaller() {
        guard let downloadedInstallerURL else { return }
        NSWorkspace.shared.open(downloadedInstallerURL)
    }

    private func responseData(for request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)
        return data
    }

    private func validate(response: URLResponse) throws {
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode) else {
            throw UpdateError.invalidServerResponse
        }
    }

    private func updateCacheURL(release: GitHubRelease, filename: String) throws -> URL {
        guard filename == (filename as NSString).lastPathComponent,
              filename.lowercased().hasSuffix(".dmg"),
              let version = release.version else {
            throw UpdateError.invalidReleaseMetadata
        }
        let fileManager = FileManager.default
        let caches = try fileManager.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = caches
            .appendingPathComponent("cc.jasonstu.trackpadwizard", isDirectory: true)
            .appendingPathComponent("Updates", isDirectory: true)
            .appendingPathComponent(
                "\(version.major).\(version.minor).\(version.patch)-\(version.build)",
                isDirectory: true
            )
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(filename, isDirectory: false)
    }
}

private enum UpdateError: LocalizedError {
    case invalidServerResponse
    case invalidReleaseMetadata
    case invalidChecksum
    case checksumMismatch

    var errorDescription: String? {
        switch self {
        case .invalidServerResponse:
            "GitHub returned an unexpected response."
        case .invalidReleaseMetadata:
            "The latest release metadata is not valid."
        case .invalidChecksum:
            "The release checksum is not valid."
        case .checksumMismatch:
            "The downloaded disk image did not match its published SHA-256 checksum."
        }
    }
}
