package com.udvilabs.hippo_flutter_sdk;

import android.app.Activity;
import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

import com.hippo.AdditionalInfo;
import com.hippo.CaptureUserData;
import com.hippo.ChatByUniqueIdAttributes;
import com.hippo.HippoConfig;
import com.hippo.HippoConfigAttributes;
import com.hippo.HippoInitCallback;
import com.hippo.HippoNotificationConfig;
import com.hippo.UnreadCount;
import com.hippo.activity.HippoActivityLifecycleCallback;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.CopyOnWriteArraySet;

/**
 * HippoFlutterSdkPlugin: Hippo's Android SDK for Flutter.
 *
 * <p>Unread counts, as the Hippo team advised: one {@link UnreadCount} listener on {@code HippoConfig}, set before
 * Hippo starts and kept whatever Dart listens to (the SDK drops a push's count when no listener is set). Messages
 * ({@code count}) and announcements ({@code unreadAnnouncementsCount}) are separate counts, each with its own event
 * channel and its own last value.
 *
 * <p>Logging: with {@code debug} on (debuggable apps, or {@code "debug": true} in the init config) the plugin logs
 * every call and callback with the tag {@code HippoFlutterSdk}, and Hippo logs its API requests and responses.
 */
public class HippoFlutterSdkPlugin implements FlutterPlugin, MethodCallHandler, ActivityAware {
    static final String TAG = "HippoFlutterSdk";
    /** How long the count requests wait for Hippo's answer before answering with the last count known. */
    private static final long COUNT_WAIT_MS = 8000;

    /** Logging, for the whole process as Hippo's own flag is: debuggable apps, unless the init config says. */
    static volatile boolean debug = false;
    private static volatile boolean debugFromConfig = false;
    /** Hippo is a singleton: initialised once for the process, whichever engine did it. */
    private static volatile boolean hippoInitialized = false;
    private static boolean lifecycleRegistered = false;

    /** Every instance attached to an engine: the app's, and the background engine push handlers run in. */
    private static final Set<HippoFlutterSdkPlugin> attached = new CopyOnWriteArraySet<>();

    /**
     * Hippo's count callbacks, for every attached instance. One listener for the process, so a background engine
     * never takes the counts away from the app's.
     */
    private static final UnreadCount COUNTS = new UnreadCount() {
        @Override
        public void count(int count) {
            log("Hippo callback: unread messages = " + count);
            for (HippoFlutterSdkPlugin plugin : attached) {
                plugin.messageCounts.publish(count);
            }
        }

        @Override
        public void unreadAnnouncementsCount(int count) {
            log("Hippo callback: unread announcements = " + count);
            for (HippoFlutterSdkPlugin plugin : attached) {
                plugin.announcementCounts.publish(count);
            }
        }

        @Override
        public void unreadCountFor(int count) {
            log("Hippo callback: unread count for one chat = " + count);
        }
    };

    private final Handler main = new Handler(Looper.getMainLooper());
    private final CountStream messageCounts = new CountStream("unread messages");
    private final CountStream announcementCounts = new CountStream("unread announcements");
    private MethodChannel methodChannel;
    private EventChannel messageCountChannel;
    private EventChannel announcementCountChannel;
    private Context context;
    private Activity activity;

    static void log(String message) {
        if (debug) {
            Log.d(TAG, message);
        }
    }

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        if (!debugFromConfig) {
            debug = (context.getApplicationInfo().flags & ApplicationInfo.FLAG_DEBUGGABLE) != 0;
        }
        methodChannel = new MethodChannel(binding.getBinaryMessenger(), "hippo_flutter_sdk");
        methodChannel.setMethodCallHandler(this);
        messageCountChannel = new EventChannel(binding.getBinaryMessenger(), "hippo_flutter_sdk_events");
        messageCountChannel.setStreamHandler(messageCounts);
        announcementCountChannel = new EventChannel(binding.getBinaryMessenger(), "hippo_flutter_sdk_announcement_events");
        announcementCountChannel.setStreamHandler(announcementCounts);
        attached.add(this);
        log("Attached to a Flutter engine (" + attached.size() + " attached)");
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        attached.remove(this);
        methodChannel.setMethodCallHandler(null);
        messageCountChannel.setStreamHandler(null);
        announcementCountChannel.setStreamHandler(null);
        log("Detached from a Flutter engine (" + attached.size() + " attached)");
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        log("Dart → " + call.method);
        try {
            switch (call.method) {
                case "initHippo":
                    initHippo(call, result);
                    break;
                case "showConversations":
                    showConversations(result);
                    break;
                case "openPeerChat":
                    openPeerChat(call, result);
                    break;
                case "clearHippoData":
                    clearHippoData(result);
                    break;
                case "getUnreadCount":
                    getUnreadCount(result);
                    break;
                case "getUnreadAnnouncementCount":
                    getUnreadAnnouncementCount(result);
                    break;
                case "isHippoNotification":
                    isHippoNotification(call, result);
                    break;
                case "handleHippoNotification":
                    handleHippoNotification(call, result);
                    break;
                default:
                    result.notImplemented();
                    break;
            }
        } catch (RuntimeException e) {
            Log.w(TAG, call.method + " failed", e);
            result.error("HIPPO_ERROR", call.method + " failed: " + e.getMessage(), null);
        }
    }

    private void initHippo(MethodCall call, Result result) {
        String data = call.arguments();
        JSONObject json;
        try {
            json = new JSONObject(data == null ? "" : data);
        } catch (JSONException e) {
            result.error("INVALID_ARGUMENT", "Invalid JSON data: " + e.getMessage(), null);
            return;
        }
        if (json.has("debug")) {
            debug = json.optBoolean("debug", debug);
            debugFromConfig = true;
        }
        if (activity == null) {
            Log.w(TAG, "initHippo: no activity attached; Hippo needs one to start");
            result.error("NO_ACTIVITY", "initHippo needs the app's activity: call it once the app is showing", null);
            return;
        }
        try {
            // CaptureUserData
            CaptureUserData.Builder userDataBuilder = new CaptureUserData.Builder();
            JSONObject userDataJson = json.optJSONObject("userData");
            if (userDataJson != null) {
                if (userDataJson.has("userUniqueKey")) {
                    userDataBuilder.userUniqueKey(userDataJson.getString("userUniqueKey"));
                }
                if (userDataJson.has("fullName")) {
                    userDataBuilder.fullName(userDataJson.getString("fullName"));
                }
                if (userDataJson.has("email")) {
                    userDataBuilder.email(userDataJson.getString("email"));
                }
                if (userDataJson.has("phoneNumber")) {
                    userDataBuilder.phoneNumber(userDataJson.getString("phoneNumber"));
                }
            }

            // AdditionalInfo: the unread announcement count is fetched and reported to the listener.
            // (The config's "additionalInfo" object isn't passed on: Hippo's builder takes no free-form keys.)
            AdditionalInfo.Builder additionalInfoBuilder = new AdditionalInfo.Builder();
            additionalInfoBuilder.isAnnouncementCount(true);

            // HippoConfigAttributes
            HippoConfigAttributes.Builder configBuilder = new HippoConfigAttributes.Builder();
            if (json.has("appKey")) {
                configBuilder.setAppKey(json.getString("appKey"));
            }
            if (json.has("appType")) {
                configBuilder.setAppType(json.getString("appType"));
            }
            if (json.has("environment")) {
                configBuilder.setEnvironment(json.getString("environment"));
            }
            if (json.has("isShareAllFileTypes")) {
                configBuilder.isShareAllFileTypes(json.getBoolean("isShareAllFileTypes"));
            }
            if (json.has("provider")) {
                configBuilder.setProvider(json.getString("provider"));
            }
            if (json.has("deviceToken")) {
                configBuilder.setDeviceToken(json.getString("deviceToken"));
            }
            String secret = json.has("userIdentificationSecret") ? json.getString("userIdentificationSecret")
                    : userDataJson != null && userDataJson.has("userIdentificationSecret")
                            ? userDataJson.getString("userIdentificationSecret") : null;
            if (secret != null) {
                configBuilder.setUserIdentificationSecret(secret);
            }

            configBuilder.setCaptureUserData(userDataBuilder.build());
            configBuilder.setAdditionalInfo(additionalInfoBuilder.build());
            // Hippo logs its API requests and responses while showLog is on.
            configBuilder.setUnreadCount(true)
                    .setShowLog(debug);

            log("initHippo: appKey " + HippoArgs.mask(json.optString("appKey"))
                    + ", appType " + json.optString("appType", "(default)")
                    + ", environment " + json.optString("environment", "(default)")
                    + ", deviceToken " + HippoArgs.mask(json.optString("deviceToken"))
                    + ", userUniqueKey " + (userDataJson == null ? "(none)" : userDataJson.optString("userUniqueKey"))
                    + ", identification secret " + (secret == null ? "none" : "set")
                    + ", unread counts and announcements on, Hippo API logs " + (debug ? "on" : "off"));

            // The listener first: Hippo fetches both counts while it signs the user in.
            installListener();
            HippoConfig.initHippoConfig(activity, configBuilder.build(), new HippoInitCallback() {
                @Override
                public void onPutUserResponse() {
                    log("Hippo: user signed in (put_user_details answered)");
                }

                @Override
                public void hasData() {
                    log("Hippo: user data already stored");
                }

                @Override
                public void onErrorResponse() {
                    Log.w(TAG, "Hippo: signing the user in failed (put_user_details) — check appKey, userUniqueKey"
                            + " and userIdentificationSecret");
                }
            });
            hippoInitialized = true;
            installListener();
            result.success(null);
        } catch (JSONException e) {
            result.error("INVALID_ARGUMENT", "Invalid JSON data: " + e.getMessage(), null);
        }
    }

    private void showConversations(Result result) {
        if (!ready("showConversations", result)) {
            return;
        }
        log("showConversations: opening Hippo's chats screen");
        HippoConfig.getInstance().showConversations(activity, "");
        result.success(null);
    }

    private void openPeerChat(MethodCall call, Result result) {
        if (!ready("openPeerChat", result)) {
            return;
        }
        try {
            JSONObject peerChatData = new JSONObject((String) call.arguments);
            String transactionId = peerChatData.getString("transactionId");
            String userUniqueKey = peerChatData.getString("userUniqueKey");
            String channelName = peerChatData.optString("channelName", "");
            JSONArray otherUserUniqueKeysJson = peerChatData.getJSONArray("otherUserUniqueKeys");
            ArrayList<String> otherUserUniqueKeys = new ArrayList<>();
            for (int i = 0; i < otherUserUniqueKeysJson.length(); i++) {
                otherUserUniqueKeys.add(otherUserUniqueKeysJson.getString(i));
            }

            log("openPeerChat: opening the chat screen — transactionId " + transactionId + ", channel \"" + channelName
                    + "\", user " + userUniqueKey + ", with " + otherUserUniqueKeys);
            ChatByUniqueIdAttributes chatAttr = new ChatByUniqueIdAttributes.Builder()
                    .setTransactionId(transactionId)
                    .setUserUniqueKey(userUniqueKey)
                    .setChannelName(channelName)
                    .setOtherUserUniqueKeys(otherUserUniqueKeys)
                    .build();
            HippoConfig.getInstance().openChatByUniqueId(chatAttr);
            result.success(null);
        } catch (JSONException | ClassCastException e) {
            result.error("INVALID_ARGUMENT", "Invalid JSON for peer chat: " + e.getMessage(), null);
        }
    }

    private void clearHippoData(Result result) {
        if (activity == null) {
            Log.w(TAG, "clearHippoData: no activity attached");
            result.error("NO_ACTIVITY", "clearHippoData needs the app's activity", null);
            return;
        }
        log("clearHippoData: signing the user out of Hippo; unread counts back to 0");
        HippoConfig.clearHippoData(activity);
        hippoInitialized = false;
        for (HippoFlutterSdkPlugin plugin : attached) {
            plugin.messageCounts.publish(0);
            plugin.announcementCounts.publish(0);
        }
        result.success(null);
    }

    private void getUnreadCount(Result result) {
        if (!hippoInitialized) {
            log("getUnreadCount: Hippo isn't initialised; answering the last count known, " + messageCounts.lastOrZero());
            result.success(messageCounts.lastOrZero());
            return;
        }
        installListener();
        messageCounts.awaitNext(result);
        try {
            log("getUnreadCount: asking Hippo for the unread message count");
            HippoConfig.getInstance().getUnreadCount();
        } catch (RuntimeException e) {
            Log.w(TAG, "getUnreadCount: Hippo couldn't be asked", e);
            messageCounts.answerWaiting();
        }
    }

    private void getUnreadAnnouncementCount(Result result) {
        if (!hippoInitialized || activity == null) {
            log("getUnreadAnnouncementCount: Hippo isn't initialised or no activity; answering the last count known, "
                    + announcementCounts.lastOrZero());
            result.success(announcementCounts.lastOrZero());
            return;
        }
        installListener();
        announcementCounts.awaitNext(result);
        try {
            log("getUnreadAnnouncementCount: asking Hippo for the unread announcement count");
            HippoConfig.getInstance().getUnreadAnnouncementCount(activity);
        } catch (NoSuchMethodError e) {
            // Hippo 4.x dropped this call: the count still comes on sign-in, announcement pushes and the screen.
            log("getUnreadAnnouncementCount: this Hippo version can't be asked (4.x); answering the last count known, "
                    + announcementCounts.lastOrZero());
            announcementCounts.answerWaiting();
        } catch (RuntimeException e) {
            Log.w(TAG, "getUnreadAnnouncementCount: Hippo couldn't be asked", e);
            announcementCounts.answerWaiting();
        }
    }

    private void isHippoNotification(MethodCall call, Result result) {
        Map<String, String> data = HippoArgs.stringMap(call.arguments);
        boolean isHippo = data != null && new HippoNotificationConfig().isHippoNotification(data);
        log("isHippoNotification: " + isHippo + " (push_source " + (data == null ? null : data.get("push_source")) + ")");
        result.success(isHippo);
    }

    private void handleHippoNotification(MethodCall call, Result result) {
        Map<String, String> data = HippoArgs.stringMap(call.arguments);
        HippoNotificationConfig notifications = new HippoNotificationConfig();
        if (data == null || !notifications.isHippoNotification(data)) {
            log("handleHippoNotification: not a Hippo message; ignored");
            result.success(false);
            return;
        }
        // Hippo only counts a push while a listener is set.
        installListener();
        log("handleHippoNotification: Hippo shows the notification and updates the counts (channel "
                + data.get("channel_id") + ", " + ("1".equals(data.get("is_announcement_push")) ? "announcement" : "message")
                + ")");
        notifications.showNotification(context, data);
        result.success(true);
    }

    /** Whether Hippo is initialised and an activity is attached; otherwise answers {@code result} with why not. */
    private boolean ready(String method, Result result) {
        if (!hippoInitialized) {
            Log.w(TAG, method + ": Hippo isn't initialised (call initHippo first)");
            result.error("NOT_INITIALIZED", method + " needs initHippo first", null);
            return false;
        }
        if (activity == null) {
            Log.w(TAG, method + ": no activity attached");
            result.error("NO_ACTIVITY", method + " needs the app's activity", null);
            return false;
        }
        return true;
    }

    /** Hippo's unread-count listener, as the Hippo team advised: set once Hippo exists, whatever Dart listens to. */
    private static void installListener() {
        HippoConfig hippo = HippoConfig.getInstance();
        if (hippo.getCallbackListener() != COUNTS) {
            hippo.setCallbackListener(COUNTS);
            log("Unread-count listener set on Hippo");
        }
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
        if (!lifecycleRegistered) {
            HippoActivityLifecycleCallback.register(activity.getApplication());
            lifecycleRegistered = true;
        }
        HippoConfig.progressLoader = false;
        log("Attached to " + activity.getClass().getSimpleName());
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        activity = null;
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
    }

    @Override
    public void onDetachedFromActivity() {
        activity = null;
    }

    /** One unread count: its event channel's listener, its last value, and the calls waiting for Hippo's answer. */
    private final class CountStream implements EventChannel.StreamHandler {
        private final String label;
        private final List<Result> waiting = new ArrayList<>();
        private EventChannel.EventSink sink;
        private Integer last;

        CountStream(String label) {
            this.label = label;
        }

        @Override
        public void onListen(Object arguments, EventChannel.EventSink events) {
            sink = events;
            log("Dart is listening for " + label + (last == null ? "" : "; sending the last count, " + last));
            if (last != null) {
                events.success(last);
            }
        }

        @Override
        public void onCancel(Object arguments) {
            sink = null;
            log("Dart stopped listening for " + label);
        }

        /** A count from Hippo, on any thread: kept, sent to Dart, and given to every call waiting for it. */
        void publish(int count) {
            main.post(() -> {
                last = count;
                if (sink != null) {
                    sink.success(count);
                }
                for (Result result : waiting) {
                    result.success(count);
                }
                waiting.clear();
            });
        }

        /** Answers {@code result} with Hippo's next count, or the last one known after a while (main thread). */
        void awaitNext(Result result) {
            waiting.add(result);
            main.postDelayed(() -> {
                if (waiting.remove(result)) {
                    log("No " + label + " from Hippo within " + COUNT_WAIT_MS + " ms; answering the last count known, "
                            + lastOrZero());
                    result.success(lastOrZero());
                }
            }, COUNT_WAIT_MS);
        }

        /** Answers every waiting call with the last count known (Hippo couldn't be asked). */
        void answerWaiting() {
            for (Result result : waiting) {
                result.success(lastOrZero());
            }
            waiting.clear();
        }

        int lastOrZero() {
            return last == null ? 0 : last;
        }
    }
}
