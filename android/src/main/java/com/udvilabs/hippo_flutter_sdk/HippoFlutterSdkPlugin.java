package com.udvilabs.hippo_flutter_sdk;

import android.app.Activity;
import android.content.Context;

import androidx.annotation.NonNull;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.EventChannel;

import com.hippo.HippoConfig;
import com.hippo.AdditionalInfo;
import com.hippo.UnreadCount;
import com.hippo.CaptureUserData;
import com.hippo.HippoConfigAttributes;
import com.hippo.ChatByUniqueIdAttributes;
import com.hippo.activity.HippoActivityLifecycleCallback;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

/** HippoFlutterSdkPlugin */
public class HippoFlutterSdkPlugin implements FlutterPlugin, MethodCallHandler, ActivityAware, EventChannel.StreamHandler {
  private boolean isHippoInitialized = false;
  private int unreadCount = 0;
  private MethodChannel methodChannel;
  private EventChannel eventChannel;
  private EventChannel.EventSink eventSink;
  private Context context;
  private Activity activity;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    methodChannel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "hippo_flutter_sdk");
    methodChannel.setMethodCallHandler(this);
    eventChannel = new EventChannel(flutterPluginBinding.getBinaryMessenger(), "hippo_flutter_sdk_events");
    eventChannel.setStreamHandler(this);
    context = flutterPluginBinding.getApplicationContext();
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    switch (call.method) {
        case "initHippo":
            try {
                String data = call.arguments();
                JSONObject json = new JSONObject(data);

                // CaptureUserData
                CaptureUserData.Builder userDataBuilder = new CaptureUserData.Builder();
                if (json.has("userData")) {
                    JSONObject userDataJson = json.getJSONObject("userData");
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

                // AdditionalInfo
                AdditionalInfo.Builder additionalInfoBuilder = new AdditionalInfo.Builder();
                if (json.has("additionalInfo")) {
                    JSONObject additionalInfoJson = json.getJSONObject("additionalInfo");
                    Iterator<String> keys = additionalInfoJson.keys();
                    // while(keys.hasNext()) {
                    //     String key = keys.next();
                    //     additionalInfoBuilder.add(key, additionalInfoJson.get(key));
                    // }
                }

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
                if (json.has("userIdentificationSecret")) {
                    configBuilder.setUserIdentificationSecret(json.getString("userIdentificationSecret"));
                }

                additionalInfoBuilder.isAnnouncementCount(true);
                
                configBuilder.setCaptureUserData(userDataBuilder.build());
                configBuilder.setAdditionalInfo(additionalInfoBuilder.build());
                configBuilder.setUnreadCount(true)
                    .setShowLog(false);

                HippoConfig.initHippoConfig(activity, configBuilder.build());
                isHippoInitialized = true;
                setCallbackListener();
                result.success(null);

            } catch (JSONException e) {
                result.error("INVALID_ARGUMENT", "Invalid JSON data: " + e.getMessage(), null);
            }
            break;
        case "showConversations":
            HippoConfig.getInstance().showConversations(activity, "");
            result.success(null);
            break;
        case "openPeerChat":
            try {
                String peerChatDataString = (String) call.arguments;
                JSONObject peerChatData = new JSONObject(peerChatDataString);

                String transactionId = peerChatData.getString("transactionId");
                String userUniqueKey = peerChatData.getString("userUniqueKey");
                String channelName = peerChatData.getString("channelName");
                JSONArray otherUserUniqueKeysJson = peerChatData.getJSONArray("otherUserUniqueKeys");
                ArrayList<String> otherUserUniqueKeys = new ArrayList<>();
                for (int i = 0; i < otherUserUniqueKeysJson.length(); i++) {
                    otherUserUniqueKeys.add(otherUserUniqueKeysJson.getString(i));
                }

                ChatByUniqueIdAttributes chatAttr = new ChatByUniqueIdAttributes.Builder()
                        .setTransactionId(transactionId)
                        .setUserUniqueKey(userUniqueKey)
                        .setChannelName(channelName)
                        .setOtherUserUniqueKeys(otherUserUniqueKeys)
                        .build();
                HippoConfig.getInstance().openChatByUniqueId(chatAttr);
                result.success(null);
            } catch (JSONException e) {
                result.error("INVALID_ARGUMENT", "Invalid JSON for peer chat: " + e.getMessage(), null);
            }
            break;
        case "clearHippoData":
            HippoConfig.clearHippoData(activity);
            result.success(null);
            break;
        case "getUnreadCount":
            result.success(this.unreadCount);
            break;
        default:
            result.notImplemented();
            break;
    }
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    methodChannel.setMethodCallHandler(null);
    eventChannel.setStreamHandler(null);
  }

  @Override
  public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
    activity = binding.getActivity();
    HippoActivityLifecycleCallback.register(activity.getApplication());
    HippoConfig.progressLoader = false;
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

    private void setCallbackListener() {
        if (!isHippoInitialized || eventSink == null) {
            return; // Guard against calls before everything is ready
        }

        HippoConfig.getInstance().setCallbackListener(new UnreadCount() {
            @Override
            public void count(final int count) {
                // HippoFlutterSdkPlugin.this.unreadCount = count;
                if (eventSink != null) {
                    activity.runOnUiThread(() -> eventSink.success(count));
                }
            }
            @Override
            public void unreadCountFor(int count) {}
            @Override
            public void unreadAnnouncementsCount(int count) {
                // HippoFlutterSdkPlugin.this.unreadCount = count;
                if (eventSink != null) {
                    activity.runOnUiThread(() -> eventSink.success(count));
                }
            }
        });
    }

    @Override
    public void onListen(Object arguments, EventChannel.EventSink events) {
        eventSink = events;
        setCallbackListener();
    }

    @Override
    public void onCancel(Object arguments) {
        eventSink = null;
    }
}
