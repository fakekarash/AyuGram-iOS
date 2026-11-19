import Foundation
import Display

public extension PresentationSurfaceLevel {
    static let calls = PresentationSurfaceLevel(rawValue: 1)
    static let overlayMedia = PresentationSurfaceLevel(rawValue: 2)
    static let notifications = PresentationSurfaceLevel(rawValue: 3)
    static let passcode = PresentationSurfaceLevel(rawValue: 4)
    static let update = PresentationSurfaceLevel(rawValue: 5)

    /// AyuGram's calculator disguise. Above everything, including the passcode
    /// screen, because the calculator is the first thing a launch must show.
    static let calculator = PresentationSurfaceLevel(rawValue: 6)
}
