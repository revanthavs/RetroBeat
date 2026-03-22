import UIKit
import Capacitor
import AVFoundation
import MediaPlayer

@UIApplicationMain
@MainActor
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    private let remoteCommandEventName = "reactpod-remote-command"
    private var didConfigureAudioSession = false

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        configureAudioSession(forceCategoryUpdate: true)
        observeAudioSessionInterruptions()
        configureRemoteCommandCenter()
        application.beginReceivingRemoteControlEvents()
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        activateAudioSession()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        activateAudioSession()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        NotificationCenter.default.removeObserver(self)
        application.endReceivingRemoteControlEvents()
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        // Called when the app was launched with a url. Feel free to add additional processing here,
        // but if you want the App API to support tracking app url opens, make sure to keep this call
        return ApplicationDelegateProxy.shared.application(app, open: url, options: options)
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        // Called when the app was launched with an activity, including Universal Links.
        // Feel free to add additional processing here, but if you want the App API to support
        // tracking app url opens, make sure to keep this call
        return ApplicationDelegateProxy.shared.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }

    private func configureAudioSession(forceCategoryUpdate: Bool = false) {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            if forceCategoryUpdate || !didConfigureAudioSession {
                try audioSession.setCategory(
                    .playback,
                    mode: .default,
                    options: [.allowAirPlay, .allowBluetoothA2DP]
                )
                didConfigureAudioSession = true
            }
            try audioSession.setActive(true)
            NSLog("ReactPod: AVAudioSession configured for background playback.")
        } catch {
            NSLog("ReactPod: primary AVAudioSession config failed (\(error.localizedDescription)); trying fallback.")
            do {
                try audioSession.setCategory(.playback, mode: .default, options: [])
                try audioSession.setActive(true)
                didConfigureAudioSession = true
                NSLog("ReactPod: AVAudioSession fallback configured for background playback.")
            } catch {
                NSLog("ReactPod: Failed to configure AVAudioSession for background playback (fallback): \(error.localizedDescription)")
            }
        }
    }

    private func activateAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setActive(true)
        } catch {
            NSLog("ReactPod: AVAudioSession activation failed (\(error.localizedDescription)); forcing category reconfiguration.")
            configureAudioSession(forceCategoryUpdate: true)
        }
    }

    private func observeAudioSessionInterruptions() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }

    @objc private func handleAudioInterruption(_ notification: Notification) {
        guard
            let info = notification.userInfo,
            let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }

        if type == .ended {
            configureAudioSession(forceCategoryUpdate: false)
        }
    }

    @objc private func handleAudioRouteChange(_ notification: Notification) {
        guard
            let info = notification.userInfo,
            let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
        else { return }

        // Re-assert audio session after route changes (headphones/Bluetooth/etc).
        if reason == .newDeviceAvailable || reason == .oldDeviceUnavailable || reason == .routeConfigurationChange {
            activateAudioSession()
        }
    }

    private func configureRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.removeTarget(nil)
        commandCenter.skipForwardCommand.removeTarget(nil)
        commandCenter.skipBackwardCommand.removeTarget(nil)
        commandCenter.seekForwardCommand.removeTarget(nil)
        commandCenter.seekBackwardCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)

        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false
        commandCenter.seekForwardCommand.isEnabled = false
        commandCenter.seekBackwardCommand.isEnabled = false
        commandCenter.changePlaybackPositionCommand.isEnabled = false

        commandCenter.playCommand.addTarget { [weak self] _ in
            return self?.forwardRemoteCommandToWeb("play") == true ? .success : .commandFailed
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            return self?.forwardRemoteCommandToWeb("pause") == true ? .success : .commandFailed
        }
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            return self?.forwardRemoteCommandToWeb("toggle") == true ? .success : .commandFailed
        }
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            return self?.forwardRemoteCommandToWeb("next") == true ? .success : .commandFailed
        }
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            return self?.forwardRemoteCommandToWeb("prev") == true ? .success : .commandFailed
        }
    }

    private func forwardRemoteCommandToWeb(_ command: String) -> Bool {
        guard let bridgeViewController = findBridgeViewController(from: window?.rootViewController),
              let bridge = bridgeViewController.bridge else {
            NSLog("ReactPod: Unable to forward remote command \(command); bridge unavailable.")
            return false
        }

        let payloadData = try? JSONSerialization.data(withJSONObject: ["command": command])
        let payload = payloadData.flatMap { String(data: $0, encoding: .utf8) } ?? "{\"command\":\"\(command)\"}"
        bridge.triggerWindowJSEvent(eventName: remoteCommandEventName, data: payload)
        return true
    }

    private func findBridgeViewController(from root: UIViewController?) -> CAPBridgeViewController? {
        guard let root else { return nil }
        if let bridgeVC = root as? CAPBridgeViewController {
            return bridgeVC
        }
        if let nav = root as? UINavigationController {
            return findBridgeViewController(from: nav.topViewController)
        }
        if let tab = root as? UITabBarController {
            return findBridgeViewController(from: tab.selectedViewController)
        }
        for child in root.children {
            if let bridgeVC = findBridgeViewController(from: child) {
                return bridgeVC
            }
        }
        if let presented = root.presentedViewController {
            return findBridgeViewController(from: presented)
        }
        return nil
    }

}
