import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    return super.application(app, open: url, options: options)
  }

  private var hapticEngine: HapticEngine?

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LiquidGlassPlugin") {
      let factory = LiquidGlassViewFactory(messenger: registrar.messenger())
      registrar.register(factory, withId: "liquid_glass_view")
    }

    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "HapticEnginePlugin") {
      hapticEngine = HapticEngine(messenger: registrar.messenger())
    }
  }
}

// MARK: - Liquid Glass Platform View

class LiquidGlassViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    return LiquidGlassView(frame: frame)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }
}

class LiquidGlassView: NSObject, FlutterPlatformView {
  private let container: UIView

  init(frame: CGRect) {
    container = UIView(frame: frame)
    container.backgroundColor = .clear
    container.isOpaque = false
    super.init()

    let blurView: UIVisualEffectView

    if #available(iOS 26.0, *) {
      // iOS 26: real Liquid Glass lensing effect
      let effect = UIGlassEffect()
      blurView = UIVisualEffectView(effect: effect)
      // Dark overlay so glass matches the app's dark theme (like Telegram dark)
      let tint = UIView()
      tint.backgroundColor = UIColor(white: 0.0, alpha: 0.40)
      tint.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      blurView.contentView.addSubview(tint)
    } else {
      // iOS 13–25: frosted dark material
      blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    }

    // Force dark appearance regardless of system setting
    blurView.overrideUserInterfaceStyle = .dark
    blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    blurView.frame = container.bounds
    container.addSubview(blurView)
  }

  func view() -> UIView { container }
}
