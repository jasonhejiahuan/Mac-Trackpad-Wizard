import Foundation
import Testing
@testable import TrackpadWizard

struct GestureInterpreterTests {
    @Test("Pinch completes only after the gesture ends")
    func pinchRecognition() {
        var interpreter = NativeGestureInterpreter()
        #expect(interpreter.process(sample(.gestureBegan)) == nil)
        #expect(interpreter.process(sample(.magnify, primary: -0.08)) == nil)
        #expect(interpreter.process(sample(.magnify, primary: -0.06)) == nil)
        #expect(interpreter.process(sample(.gestureEnded)) == .pinchIn)
    }

    @Test("Rotation threshold and direction are stable")
    func rotationRecognition() {
        var interpreter = NativeGestureInterpreter()
        _ = interpreter.process(sample(.gestureBegan))
        _ = interpreter.process(sample(.rotate, primary: 6))
        _ = interpreter.process(sample(.rotate, primary: 5))
        #expect(interpreter.process(sample(.gestureEnded)) == .rotateClockwise)
    }

    @Test("Force Click fires once per gesture lifecycle")
    func forceClickDebounce() {
        var interpreter = NativeGestureInterpreter()
        _ = interpreter.process(sample(.gestureBegan))
        #expect(interpreter.process(sample(.pressure, primary: 0.8, stage: 2)) == .forceClick)
        #expect(interpreter.process(sample(.pressure, primary: 1.0, stage: 2)) == nil)
        _ = interpreter.process(sample(.gestureEnded))
        _ = interpreter.process(sample(.gestureBegan))
        #expect(interpreter.process(sample(.pressure, primary: 0.7, stage: 2)) == .forceClick)
    }

    @Test("Three simultaneous contacts become a directional swipe")
    func rawThreeFingerSwipe() {
        var interpreter = ThreeFingerGestureInterpreter()
        let began = frame(time: 1, x: 0.70, phase: .began)
        let moved = frame(time: 1.4, x: 0.48, phase: .moved)
        let ended = TouchFrame(timestamp: 1.5, contacts: [], source: .enhanced)

        #expect(interpreter.process(began) == nil)
        #expect(interpreter.process(moved) == nil)
        #expect(interpreter.process(ended) == .swipeLeft)
    }

    private func sample(
        _ kind: NativeGestureKind,
        primary: Double = 0,
        stage: Int = 0
    ) -> NativeGestureSample {
        NativeGestureSample(
            kind: kind,
            timestamp: 1,
            primaryValue: primary,
            stage: stage
        )
    }

    private func frame(
        time: TimeInterval,
        x: Double,
        phase: TouchContactPhase
    ) -> TouchFrame {
        let contacts = (0..<3).map { index in
            TouchContact(
                id: index,
                x: x + Double(index) * 0.02,
                y: 0.45 + Double(index) * 0.02,
                phase: phase,
                isResting: false,
                deviceWidth: 160,
                deviceHeight: 110,
                source: .enhanced
            )
        }
        return TouchFrame(timestamp: time, contacts: contacts, source: .enhanced)
    }
}
