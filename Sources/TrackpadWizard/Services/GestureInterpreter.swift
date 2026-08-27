import Foundation

struct NativeGestureInterpreter: Sendable {
    private(set) var magnification: Double = 0
    private(set) var rotation: Double = 0
    private var forceClickFired = false

    mutating func process(_ sample: NativeGestureSample) -> GestureTrigger? {
        switch sample.kind {
        case .gestureBegan:
            magnification = 0
            rotation = 0
            forceClickFired = false
        case .magnify:
            magnification += sample.primaryValue
        case .rotate:
            rotation += sample.primaryValue
        case .swipe:
            if abs(sample.primaryValue) >= abs(sample.secondaryValue) {
                return sample.primaryValue < 0 ? .swipeLeft : .swipeRight
            }
            return sample.secondaryValue < 0 ? .swipeDown : .swipeUp
        case .pressure:
            guard sample.stage >= 2, !forceClickFired else { return nil }
            forceClickFired = true
            return .forceClick
        case .gestureEnded:
            defer {
                magnification = 0
                rotation = 0
                forceClickFired = false
            }
            if abs(magnification) >= 0.12 {
                return magnification < 0 ? .pinchIn : .pinchOut
            }
            if abs(rotation) >= 10 {
                return rotation < 0 ? .rotateCounterclockwise : .rotateClockwise
            }
        case .scroll:
            break
        }
        return nil
    }
}

struct ThreeFingerGestureInterpreter: Sendable {
    private var startCentroid: (x: Double, y: Double)?
    private var latestCentroid: (x: Double, y: Double)?
    private var maximumContactCount = 0
    private var beganAt: TimeInterval?

    mutating func process(_ frame: TouchFrame) -> GestureTrigger? {
        let active = frame.contacts.filter { $0.phase.isActive && !$0.isResting }
        if !active.isEmpty {
            maximumContactCount = max(maximumContactCount, active.count)
            let centroid = (
                x: active.map(\.x).reduce(0, +) / Double(active.count),
                y: active.map(\.y).reduce(0, +) / Double(active.count)
            )
            if startCentroid == nil {
                startCentroid = centroid
                beganAt = frame.timestamp
            }
            latestCentroid = centroid
            return nil
        }

        defer { reset() }
        guard maximumContactCount == 3,
              let startCentroid,
              let latestCentroid,
              let beganAt,
              frame.timestamp - beganAt <= 1.4 else { return nil }
        let dx = latestCentroid.x - startCentroid.x
        let dy = latestCentroid.y - startCentroid.y
        guard max(abs(dx), abs(dy)) >= 0.11 else { return nil }
        if abs(dx) >= abs(dy) {
            return dx < 0 ? .swipeLeft : .swipeRight
        }
        return dy < 0 ? .swipeDown : .swipeUp
    }

    private mutating func reset() {
        startCentroid = nil
        latestCentroid = nil
        maximumContactCount = 0
        beganAt = nil
    }
}
