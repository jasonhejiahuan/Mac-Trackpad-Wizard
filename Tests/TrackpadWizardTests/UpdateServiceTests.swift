import Foundation
import Testing
@testable import TrackpadWizard

struct UpdateServiceTests {
    @Test("Release tags compare semantic version before build number")
    func releaseVersionComparison() throws {
        let current = try #require(AppReleaseVersion(tag: "v0.2.1-build.3"))
        let nextBuild = try #require(AppReleaseVersion(tag: "v0.2.1-build.4"))
        let nextVersion = try #require(AppReleaseVersion(tag: "v0.3.0-build.1"))

        #expect(current < nextBuild)
        #expect(nextBuild < nextVersion)
        #expect(nextVersion.description == "0.3.0 (Build 1)")
        #expect(AppReleaseVersion(tag: "not-a-release") == nil)
    }

    @Test("GitHub release metadata selects a DMG and its matching checksum")
    func releaseAssetSelection() throws {
        let data = Data(
            """
            {
              "tag_name": "v0.3.0-build.4",
              "name": "Trackpad Wizard 0.3.0",
              "html_url": "https://github.com/jasonhejiahuan/Mac-Trackpad-Wizard/releases/tag/v0.3.0-build.4",
              "draft": false,
              "prerelease": false,
              "assets": [
                {
                  "name": "Trackpad-Wizard-0.3.0-build-4.dmg",
                  "browser_download_url": "https://github.com/example/update.dmg"
                },
                {
                  "name": "Trackpad-Wizard-0.3.0-build-4.dmg.sha256",
                  "browser_download_url": "https://github.com/example/update.dmg.sha256"
                }
              ]
            }
            """.utf8
        )
        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        let diskImage = try #require(release.diskImageAsset)

        #expect(release.version == AppReleaseVersion(tag: "v0.3.0-build.4"))
        #expect(diskImage.name.hasSuffix(".dmg"))
        #expect(release.checksumAsset(for: diskImage)?.name == "\(diskImage.name).sha256")
    }
}
