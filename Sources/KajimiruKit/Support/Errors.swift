import Foundation

/// Domain level errors that can be surfaced to the UI or higher layers.
public enum KajimiruError: Error, Equatable {
    case unauthorized
    case notFound
    case validationFailed(reason: String)
    case repositoryFailure(reason: String)
}
