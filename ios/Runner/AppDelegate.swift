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
          result(true)
        case "updateRestActivity":
          result(true)
        case "endRestActivity":
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
