import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    GymNativeBridge.setupChannels(messenger: engineBridge.binaryMessenger)
  }
}

class GymNativeBridge {
  static func setupChannels(messenger: FlutterBinaryMessenger) {
    // 1. Audio Session Coordinator Channel
    let audioChannel = FlutterMethodChannel(name: "com.probike.gym/audio_session", binaryMessenger: messenger)
    audioChannel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "configureSession":
        do {
          let session = AVAudioSession.sharedInstance()
          try session.setCategory(.playback, options: [.mixWithOthers, .duckOthers])
          try session.setActive(true)
          result(true)
        } catch {
          result(FlutterError(code: "AUDIO_SESSION_ERROR", message: error.localizedDescription, details: nil))
        }
      case "playRestCompleteAlert":
        AudioServicesPlaySystemSound(1054)
        result(true)
      case "deactivateSession":
        do {
          try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
          result(true)
        } catch {
          result(false)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // 2. ActivityKit Live Activity Channel (iOS 16.1+)
    let activityChannel = FlutterMethodChannel(name: "com.probike.gym/live_activities", binaryMessenger: messenger)
    activityChannel.setMethodCallHandler { (call, result) in
      if #available(iOS 16.1, *) {
        switch call.method {
        case "startRestActivity":
          let args = call.arguments as? [String: Any] ?? [:]
          let durationSeconds = args["durationSeconds"] as? Int ?? 90
          let endsAtUtc = args["endsAtUtc"] as? String ?? ""
          let exerciseName = args["exerciseName"] as? String ?? "Rest"
          let setNumber = args["setNumber"] as? Int ?? 1
          #if canImport(ActivityKit)
          let success = GymLiveActivityManager.shared.startRestActivity(
            durationSeconds: durationSeconds,
            endsAtUtc: endsAtUtc,
            exerciseName: exerciseName,
            setNumber: setNumber
          )
          result(success)
          #else
          result(false)
          #endif
        case "updateRestActivity":
          let args = call.arguments as? [String: Any] ?? [:]
          let secondsRemaining = args["secondsRemaining"] as? Int ?? 0
          #if canImport(ActivityKit)
          GymLiveActivityManager.shared.updateRestActivity(secondsRemaining: secondsRemaining)
          #endif
          result(true)
        case "endRestActivity":
          #if canImport(ActivityKit)
          GymLiveActivityManager.shared.endRestActivity()
          #endif
          result(true)
        default:
          result(FlutterMethodNotImplemented)
        }
      } else {
        result(false)
      }
    }
  }
}
