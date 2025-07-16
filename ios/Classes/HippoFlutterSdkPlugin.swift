import Flutter
import UIKit
import Hippo

public class HippoFlutterSdkPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    var hippoManager: HippoManager?
    override init() {
        super.init()
        self.hippoManager = HippoManager()
    }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let methodChannel = FlutterMethodChannel(name: "hippo_flutter_sdk", binaryMessenger: registrar.messenger())
    let eventChannel = FlutterEventChannel(name: "hippo_flutter_sdk_events", binaryMessenger: registrar.messenger())
    let instance = HippoFlutterSdkPlugin()
    registrar.addMethodCallDelegate(instance, channel: methodChannel)
    eventChannel.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initHippo":
        guard let data = call.arguments as? String, 
              let dict = try? JSONSerialization.jsonObject(with: data.data(using: .utf8)!, options: []) as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid data", details: nil))
            return
        }

        guard let appKey = dict["appKey"] as? String, !appKey.isEmpty else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "appKey is missing", details: nil))
            return
        }
        HippoConfig.shared.setCredential(withAppSecretKey: appKey)

        if let userData = dict["userData"] as? [String: Any] {
            guard let userUniqueKey = userData["userUniqueKey"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "userUniqueKey is missing", details: nil))
                return
            }
            let userDetail = HippoUserDetail(fullName: userData["fullName"] as? String ?? "",
                                               email: userData["email"] as? String ?? "",
                                               phoneNumber: userData["phoneNumber"] as? String ?? "",
                                               userUniqueKey: userUniqueKey)
            HippoConfig.shared.updateUserDetail(userDetail: userDetail) { success in
                // Delegate is set here, after user is identified.
                HippoConfig.shared.setHippoDelegate(delegate: self.hippoManager!)
                result(nil)
            }
        } else {
            // Set delegate even if no user data is provided.
            HippoConfig.shared.setHippoDelegate(delegate: self.hippoManager!)
            result(nil)
        }

    case "showConversations":
        HippoConfig.shared.presentChatsViewController()
        result(nil)

    case "openPeerChat":
        guard let data = call.arguments as? String, 
              let dict = try? JSONSerialization.jsonObject(with: data.data(using: .utf8)!, options: []) as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid data for peer chat", details: nil))
            return
        }

        guard let transactionId = dict["transactionId"] as? String,
              let myUniqueId = dict["userUniqueKey"] as? String,
              let otherUserUniqueKeys = dict["otherUserUniqueKeys"] as? [String] else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing required fields for peer chat", details: nil))
            return
        }

        let channelName = dict["channelName"] as? String ?? ""
        let peerName = dict["peerName"] as? String ?? ""

        guard let option = PeerToPeerChat(uniqueChatId: transactionId,
                                            myUniqueId: myUniqueId,
                                            idsOfPeers: otherUserUniqueKeys,
                                            channelName: channelName,
                                            peerName: peerName) else {
            result(FlutterError(code: "INIT_FAILED", message: "Failed to create PeerToPeerChat option", details: nil))
            return
        }

        HippoConfig.shared.showPeerChatWith(data: option) { (success, error) in
            if (error != nil) {
                print("Error opening peer chat: \(error!.localizedDescription)")
            }
            result(success)
        }

    case "clearHippoData":
        HippoConfig.shared.clearHippoUserData()
        result(nil)

    case "getUnreadCount":
        result(hippoManager?.unreadCount ?? 0)

    default:
        result(FlutterMethodNotImplemented)
    }
  }
}

class HippoManager: HippoDelegate {
    var eventSink: FlutterEventSink?
    var unreadCount: Int = 0
    func hippoUnreadCount(_ totalCount: Int) {
        print("HippoSDK: Unread count updated: \(totalCount)")
        self.unreadCount = totalCount
        if let eventSink = self.eventSink {
            print("HippoSDK: Sending unread count to Flutter: \(totalCount)")
            eventSink(totalCount)
        }
    }
    
    func hippoUserUnreadCount(_ usersCount: [String : Int]) {}
    
    func hippoDeinit() {}
    
    func hippoDidLoad() {}
    
    func hippoMessageRecievedWith(response: [String : Any], viewController: UIViewController) {}
    
    func promotionMessageRecievedWith(response: [String : Any], viewController: UIViewController) {}
    
    func deepLinkClicked(response: [String : Any]) {}
    
    func hippoUserLogOut() {}
    
    func startLoading(message: String?) {}
    
    func stopLoading() {}
    
    func hippoAgentTotalUnreadCount(_ totalCount: Int) {}
    
    func hippoAgentTotalChannelsUnreadCount(_ totalCount: Int) {}
    
    func sendDataIfChatIsAssignedToSelfAgent(_ dic: [String : Any]) {}
    
    func sendp2pUnreadCount(unreadCount: Int, channelId: Int) {}
    
    func chatListButtonAction() {}
    
    func passSecurityCheckError(error: String) {}
    
    #if canImport(HippoCallClient)
    func loadCallPresenterView(request: CallPresenterRequest) -> CallPresenter? {
        return nil
    }
    #endif
}

extension HippoFlutterSdkPlugin {
    public func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
        print("HippoSDK: Flutter started listening for unread count events.")
        hippoManager?.eventSink = eventSink
        // Send the initial count
        if let count = hippoManager?.unreadCount {
            print("HippoSDK: Sending initial unread count: \(count)")
            eventSink(count)
        }
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        hippoManager?.eventSink = nil
        return nil
    }
}
