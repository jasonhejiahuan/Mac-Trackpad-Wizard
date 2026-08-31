import Foundation

enum AppErrorCode: String, Codable, Sendable {
    case enhancedTouch = "TW-1001"
    case enhancedHaptics = "TW-1002"
    case gestureSuppression = "TW-1003"
    case hapticPlayback = "TW-1004"
    case surfaceOrientation = "TW-2001"
    case systemHaptics = "TW-2002"
    case sessionExport = "TW-3001"
    case patternValidation = "TW-3101"
    case patternImport = "TW-3102"
    case patternExport = "TW-3103"
    case accessibility = "TW-3201"
    case updateCheck = "TW-4001"
    case updateDownload = "TW-4002"
}

struct AppNotice: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case information
        case error
    }

    let id: UUID
    let message: String
    let kind: Kind
    let errorCode: AppErrorCode?

    init(
        id: UUID = UUID(),
        message: String,
        kind: Kind = .information,
        errorCode: AppErrorCode? = nil
    ) {
        self.id = id
        self.message = message
        self.kind = kind
        self.errorCode = errorCode
    }
}
