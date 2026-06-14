import Flutter
import UIKit
import EventKit
import EventKitUI

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, EKEventEditViewDelegate {
  
  private var eventStore = EKEventStore()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let calendarChannel = FlutterMethodChannel(name: "com.example.phia_flutter/calendar",
                                              binaryMessenger: controller.binaryMessenger)
    
    calendarChannel.setMethodCallHandler({
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      guard call.method == "addToCalendar" else {
        result(FlutterMethodNotImplemented)
        return
      }
      
      guard let args = call.arguments as? [String: Any],
            let title = args["title"] as? String,
            let description = args["description"] as? String,
            let location = args["location"] as? String,
            let beginTimeMs = args["beginTime"] as? Int64,
            let endTimeMs = args["endTime"] as? Int64 else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing arguments", details: nil))
        return
      }
      
      let startDate = Date(timeIntervalSince1970: TimeInterval(beginTimeMs) / 1000)
      let endDate = Date(timeIntervalSince1970: TimeInterval(endTimeMs) / 1000)
      
      self?.presentCalendarEvent(title: title, description: description, location: location, startDate: startDate, endDate: endDate, result: result)
    })
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func presentCalendarEvent(title: String, description: String, location: String, startDate: Date, endDate: Date, result: @escaping FlutterResult) {
    if #available(iOS 17.0, *) {
      eventStore.requestWriteOnlyAccessToEvents { [weak self] (granted, error) in
        self?.handleAccessResult(granted: granted, error: error, title: title, description: description, location: location, startDate: startDate, endDate: endDate, result: result)
      }
    } else {
      eventStore.requestAccess(to: .event) { [weak self] (granted, error) in
        self?.handleAccessResult(granted: granted, error: error, title: title, description: description, location: location, startDate: startDate, endDate: endDate, result: result)
      }
    }
  }

  private func handleAccessResult(granted: Bool, error: Error?, title: String, description: String, location: String, startDate: Date, endDate: Date, result: @escaping FlutterResult) {
    guard granted, error == nil else {
      DispatchQueue.main.async {
        result(FlutterError(code: "PERMISSION_DENIED", message: "Calendar access denied", details: nil))
      }
      return
    }
    
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      let event = EKEvent(eventStore: self.eventStore)
      event.title = title
      event.notes = description
      event.location = location
      event.startDate = startDate
      event.endDate = endDate
      event.calendar = self.eventStore.defaultCalendarForNewEvents
      
      let eventEditVC = EKEventEditViewController()
      eventEditVC.eventStore = self.eventStore
      eventEditVC.event = event
      eventEditVC.editViewDelegate = self
      
      if let rootVC = self.window?.rootViewController {
        rootVC.present(eventEditVC, animated: true, completion: {
          result(true)
        })
      } else {
        result(FlutterError(code: "UI_ERROR", message: "Could not find root view controller", details: nil))
      }
    }
  }
  
  func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
    controller.dismiss(animated: true, completion: nil)
  }
  
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
