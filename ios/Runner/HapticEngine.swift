import CoreHaptics
import Flutter
import UIKit

class HapticEngine: NSObject {
    private var engine: CHHapticEngine?
    private let channel: FlutterMethodChannel

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "haptic_engine", binaryMessenger: messenger)
        super.init()
        prepareEngine()
        channel.setMethodCallHandler(handle)
    }

    // MARK: - Engine Setup

    private func prepareEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            engine?.resetHandler = { [weak self] in self?.prepareEngine() }
            engine?.stoppedHandler = { _ in }
            try engine?.start()
        } catch {}
    }

    // MARK: - Method Handler

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "light":           impact(.light,  result: result)
        case "medium":          impact(.medium, result: result)
        case "heavy":           impact(.heavy,  result: result)
        case "success":         notification(.success, result: result)
        case "error":           notification(.error,   result: result)
        case "warning":         notification(.warning, result: result)
        case "set_complete":    playSetComplete(result: result)
        case "set_undo":        playSetUndo(result: result)
        case "workout_done":    playWorkoutDone(result: result)
        case "import_success":  playImportSuccess(result: result)
        default:                result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Simple Feedback

    private func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle, result: FlutterResult) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
        result(nil)
    }

    private func notification(_ type: UINotificationFeedbackGenerator.FeedbackType, result: FlutterResult) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
        result(nil)
    }

    // MARK: - CoreHaptics Patterns

    /// Single crisp tap — marking a set done
    private func playSetComplete(result: FlutterResult) {
        play(events: [
            transient(time: 0,    intensity: 0.75, sharpness: 0.8),
        ], result: result)
    }

    /// Softer double tap — unmarking a set
    private func playSetUndo(result: FlutterResult) {
        play(events: [
            transient(time: 0,    intensity: 0.4,  sharpness: 0.3),
            transient(time: 0.08, intensity: 0.25, sharpness: 0.2),
        ], result: result)
    }

    /// Three ascending pulses — whole workout completed
    private func playWorkoutDone(result: FlutterResult) {
        play(events: [
            transient(time: 0,    intensity: 0.5,  sharpness: 0.5),
            transient(time: 0.14, intensity: 0.75, sharpness: 0.7),
            transient(time: 0.28, intensity: 1.0,  sharpness: 0.9),
        ], result: result)
    }

    /// Short success ripple — key imported from clipboard
    private func playImportSuccess(result: FlutterResult) {
        play(events: [
            transient(time: 0,    intensity: 0.6,  sharpness: 0.4),
            transient(time: 0.1,  intensity: 0.9,  sharpness: 0.7),
        ], result: result)
    }

    // MARK: - Helpers

    private func transient(time: Double, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness,  value: sharpness),
            ],
            relativeTime: time
        )
    }

    private func play(events: [CHHapticEvent], result: FlutterResult) {
        guard let engine else {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            result(nil)
            return
        }
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player  = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {}
        result(nil)
    }
}
