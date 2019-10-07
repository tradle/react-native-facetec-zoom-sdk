package com.reactlibrary;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.net.Uri;
import android.os.AsyncTask;
import android.support.annotation.NonNull;
import android.util.Base64;
import android.util.Log;

import com.facebook.react.bridge.ActivityEventListener;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.BaseActivityEventListener;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.bridge.WritableMap;
import com.facetec.zoom.sdk.ZoomAuditTrailType;
import com.facetec.zoom.sdk.ZoomCustomization;
import com.facetec.zoom.sdk.ZoomFeedbackCustomization;
import com.facetec.zoom.sdk.ZoomFrameCustomization;
import com.facetec.zoom.sdk.ZoomDevicePartialLivenessResult;
import com.facetec.zoom.sdk.ZoomExternalImageSetVerificationResult;
import com.facetec.zoom.sdk.ZoomFaceBiometricMetrics;
import com.facetec.zoom.sdk.ZoomOvalCustomization;
import com.facetec.zoom.sdk.ZoomSDK;
import com.facetec.zoom.sdk.ZoomSDKStatus;
import com.facetec.zoom.sdk.ZoomVerificationActivity;
import com.facetec.zoom.sdk.ZoomVerificationResult;
import com.facetec.zoom.sdk.ZoomVerificationStatus;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.ArrayList;

import io.tradle.reactimagestore.ImageStoreModule;
//import static com.facetec.zoom.sdk.ZoomAuthenticationStatus.USER_WAS_AUTHENTICATED;
//import static com.facetec.zoom.sdk.ZoomAuthenticationStatus.USER_WAS_AUTHENTICATED_WITH_FALLBACK_STRATEGY;
//import static com.facetec.zoom.sdk.ZoomEnrollmentStatus.USER_WAS_ENROLLED;
//import static com.facetec.zoom.sdk.ZoomEnrollmentStatus.USER_WAS_ENROLLED_WITH_FALLBACK_STRATEGY;

public class RNReactNativeZoomSdkModule extends ReactContextBaseJavaModule {

  private static final String TAG = "RNReactNativeZoomSdk";
  private final ReactApplicationContext reactContext;
  private Promise verificationPromise;
  private boolean initialized;
  private boolean returnBase64 = false;

  private final ActivityEventListener mActivityEventListener = new BaseActivityEventListener() {
    @Override
    public void onActivityResult(Activity activity, int requestCode, int resultCode, Intent data) {
      super.onActivityResult(activity, requestCode, resultCode, data);
      if (requestCode != ZoomSDK.REQUEST_CODE_VERIFICATION) return;
      if (verificationPromise == null) return;

      ZoomVerificationResult result = data.getParcelableExtra(ZoomSDK.EXTRA_VERIFY_RESULTS);
      WritableMap resultObj;
      try {
        resultObj = convertZoomVerificationResult(result);
      } catch (IOException i) {
        resultObj = Arguments.createMap();
        resultObj.putBoolean("success", false);
        resultObj.putString("status", "ImageStoreError");
        resultObj.putString("error", i.getMessage());
      }

      verificationPromise.resolve(resultObj);
      verificationPromise = null;
    }
  };


  public RNReactNativeZoomSdkModule(ReactApplicationContext reactContext) {
    super(reactContext);
    this.reactContext = reactContext;
    this.verificationPromise = null;
    this.initialized = false;
    reactContext.addActivityEventListener(mActivityEventListener);
  }

  @Override
  public String getName() {
    return "RNReactNativeZoomSdk";
  }

  @ReactMethod
  public void getVersion(final Promise promise) {
    promise.resolve(ZoomSDK.version());
  }

  @ReactMethod
  public void preload() {
    // preload sdk resources so the UI is snappy (optional)
    ZoomSDK.preload(getCurrentActivity());
  }

  @ReactMethod
  public void initialize(final ReadableMap opts, final Promise promise) {
    Log.d(TAG, "initializing");
    final String appToken = opts.getString("appToken");
    final String facemapEncryptionKey = opts.getString("facemapEncryptionKey");

    AsyncTask.execute(new Runnable() {
      @Override
      public void run() {
        ZoomCustomization currentCustomization = new ZoomCustomization();
        ZoomSDK.setAuditTrailType(ZoomAuditTrailType.HEIGHT_640);
        currentCustomization.showPreEnrollmentScreen = opts.getBoolean("showPreEnrollmentScreen");
        currentCustomization.showUserLockedScreen = opts.getBoolean("showUserLockedScreen");
        currentCustomization.showRetryScreen= opts.getBoolean("showRetryScreen");
        currentCustomization.enableLowLightMode = opts.getBoolean("enableLowLightMode");

        if (opts.hasKey("mainBackgroundColors")) {
          ReadableArray mainBackgroundColors = opts.getArray("mainBackgroundColors");
          // This attribute contains array of 2 colors for gradient, but it seems like Java API
          // doesn't allow to set gradient, so we take just the first.
          currentCustomization.mainBackgroundColor = Color.parseColor(mainBackgroundColors.getString(0));
        }

        addFrameCustomizations(currentCustomization, opts);
        addFeedbackCustomizations(currentCustomization, opts);
        addOvalCustomizations(currentCustomization, opts);

        ZoomSDK.setCustomization(currentCustomization);
        ZoomSDK.initialize(getCurrentActivity(), appToken, new ZoomSDK.InitializeCallback() {
          @Override
          public void onCompletion(boolean successful) {
            WritableMap map = Arguments.createMap();
            map.putBoolean("success", successful);
            if (successful) {
              initialized = true;
            } else {
              map.putString("status", getSdkStatusString());
            }

            Log.d(TAG, String.format("initialized: %b", successful));
            promise.resolve(map);
          }
        });

        ZoomSDK.setFacemapEncryptionKey(facemapEncryptionKey);
      }
    });
  }

  private void addFrameCustomizations(ZoomCustomization currentCustomization, ReadableMap opts) {
    ZoomFrameCustomization frameCustomization = new ZoomFrameCustomization();
    frameCustomization.topMargin = opts.getInt("topMargin");
    frameCustomization.sizeRatio = (float)opts.getDouble("sizeRatio");

    if (opts.hasKey("backgroundColor")) {
      frameCustomization.backgroundColor = Color.parseColor(opts.getString("backgroundColor"));
    }

    if (opts.hasKey("borderColor")) {
      frameCustomization.borderColor= Color.parseColor(opts.getString("borderColor"));
    }

    currentCustomization.setFrameCustomization(frameCustomization);
  }

  private void addFeedbackCustomizations(ZoomCustomization currentCustomization, ReadableMap opts) {
    if (!opts.isNull("feedbackCustomization")) {
      ZoomFeedbackCustomization feedbackCustomization = new ZoomFeedbackCustomization();
      ReadableMap feedbackCustomizationOptions = opts.getMap("feedbackCustomization");

      if (feedbackCustomizationOptions.hasKey("backgroundColor")) {
        ReadableArray backgroundColors = feedbackCustomizationOptions.getArray("backgroundColor");
        // This attribute contains array of 2 colors for gradient, but it seems like Java API
        // doesn't allow to set gradient, so we take just the first.
        String backgroundColor = backgroundColors.getString(0);

        feedbackCustomization.backgroundColor = Color.parseColor(backgroundColor);
      }

      currentCustomization.setFeedbackCustomization(feedbackCustomization);
      Log.d(TAG, "Feedback customizations applied.");
    }
  }

  private void addOvalCustomizations(ZoomCustomization currentCustomization, ReadableMap opts) {
    if (!opts.isNull("ovalCustomization")) {
      ZoomOvalCustomization ovalCustomization = new ZoomOvalCustomization();
      ReadableMap ovalCustomizationOptions = opts.getMap("ovalCustomization");

      if (ovalCustomizationOptions.hasKey("progressColor1")) {
        ovalCustomization.progressColor1 = Color.parseColor(ovalCustomizationOptions.getString("progressColor1"));
      }

      if (ovalCustomizationOptions.hasKey("progressColor2")) {
        ovalCustomization.progressColor2 = Color.parseColor(ovalCustomizationOptions.getString("progressColor2"));
      }

      currentCustomization.setOvalCustomization(ovalCustomization);
      Log.d(TAG, "Oval customizations applied.");
    }
  }

  // private void enroll(JSONArray args, final CallbackContext callbackContext) throws JSONException {
  //     String userId = args.getString(0);
  //     String secret = args.getString(1);

  //     Intent enrollmentIntent = new Intent(this.cordova.getActivity(), ZoomEnrollmentActivity.class);
  //     enrollmentIntent.putExtra(ZoomSDK.EXTRA_ENROLLMENT_USER_ID, userId);
  //     enrollmentIntent.putExtra(ZoomSDK.EXTRA_USER_ENCRYPTION_SECRET, secret);

  //     pendingCallbackContext = callbackContext;

  //     this.cordova.startActivityForResult(this, enrollmentIntent, ZoomSDK.REQUEST_CODE_ENROLLMENT);
  // }

  // private void authenticate(JSONArray args, final CallbackContext callbackContext) throws JSONException {
  //     String userId = args.getString(0);
  //     String secret = args.getString(1);

  //     Intent authenticationIntent = new Intent(this.cordova.getActivity(), ZoomAuthenticationActivity.class);
  //     authenticationIntent.putExtra(ZoomSDK.EXTRA_AUTHENTICATION_USER_ID, userId);
  //     authenticationIntent.putExtra(ZoomSDK.EXTRA_USER_ENCRYPTION_SECRET, secret);

  //     pendingCallbackContext = callbackContext;

  //     this.cordova.startActivityForResult(this, authenticationIntent, ZoomSDK.REQUEST_CODE_AUTHENTICATION);
  // }

  @ReactMethod
  public void verify(ReadableMap opts, final Promise promise) {
    verificationPromise = promise;
    returnBase64 = opts.getBoolean("returnBase64");
    Activity activity = getCurrentActivity();
    Intent verificationIntent = new Intent(activity.getBaseContext(), ZoomVerificationActivity.class);
    activity.startActivityForResult(verificationIntent, ZoomSDK.REQUEST_CODE_VERIFICATION);
  }

//  @ReactMethod
//  public void handleVerificationSuccessResult(ZoomVerificationResult successResult) {
//    // retrieve the ZoOm facemap as byte[]
//    if (successResult.getFaceMetrics() != null) {
//      // this is the raw biometric data which can be uploaded, or may be
//      // base64 encoded in order to handle easier at the cost of processing and network usage
//      byte[] zoomFacemap = successResult.getFaceMetrics().getZoomFacemap();
//      // handle facemap
//    }
//  }
//
  // private void getUserEnrollmentStatus(JSONArray args, final CallbackContext callbackContext) throws JSONException {
  //     final Context context = this.cordova.getActivity().getApplicationContext();
  //     final String userId = args.getString(0);

  //     cordova.getThreadPool().execute(new Runnable() {
  //         @Override
  //         public void run() {
  //             ZoomSDK.UserEnrollmentStatus status = ZoomSDK.getUserEnrollmentStatus(context, userId);
  //             switch (status) {
  //                 case USER_ENROLLED:
  //                     callbackContext.success("Enrolled");
  //                     break;
  //                 case USER_INVALIDATED:
  //                     callbackContext.success("Invalidated");
  //                     break;
  //                 case USER_NOT_ENROLLED:
  //                 default:
  //                     callbackContext.success("NotEnrolled");
  //             }
  //         }
  //     });
  // }

//  @Override
//  public void onNewIntent(Intent intent) { }


  @NonNull
  private String getSdkStatusString() {
    ZoomSDKStatus status = ZoomSDK.getStatus(reactContext.getApplicationContext());

    switch (status) {
      case NEVER_INITIALIZED:
        return "NeverInitialized";
      case INITIALIZED:
        return "Initialized";
      case INVALID_TOKEN:
        return "InvalidToken";
      case VERSION_DEPRECATED:
        return "VersionDeprecated";
      case OFFLINE_SESSIONS_EXCEEDED:
        return "OfflineSessionsExceeded";
      case DEVICE_IN_LANDSCAPE_MODE:
        return "FailedBecauseOfLandscapeMode";
      case DEVICE_IN_REVERSE_PORTRAIT_MODE:
        return "FailedBecauseOfReversePortraitMode";
      case NETWORK_ISSUES:
        return "NetworkIssues";
      case DEVICE_LOCKED_OUT:
        return "DeviceLockedOut";
      case DEVICE_NOT_SUPPORTED:
        return "DeviceNotSupported";
      case LICENSE_EXPIRED_OR_INVALID:
        return "LicenseExpiredOrInvalid";
      default:
        return "UnknownError";
    }
  }

  private WritableMap convertZoomVerificationResult(ZoomVerificationResult result) throws IOException {
    WritableMap resultObj = Arguments.createMap();
    WritableMap faceMetricsObj = Arguments.createMap();

    ZoomFaceBiometricMetrics faceMetrics = result.getFaceMetrics();
    faceMetricsObj.putString("livenessResult", convertZoomLivenessResult(faceMetrics.getDevicePartialLiveness()));
    faceMetricsObj.putDouble("livenessScore", faceMetrics.getDevicePartialLivenessScore());

    String status = convertZoomVerificationStatus(result.getStatus());
    resultObj.putString("status", status);
    resultObj.putInt("countOfZoomSessionsPerformed", result.getCountOfZoomSessionsPerformed());
    resultObj.putString("sessionId", result.getSessionId());

    ArrayList<Bitmap> auditTrail = faceMetrics.getAuditTrail();
    byte[] facemap = faceMetrics.getZoomFacemap();
    if (facemap == null  ||  facemap.length == 0)
      return resultObj;
    if (returnBase64) {
      WritableArray auditTrailBase64 = Arguments.createArray();
      for (Bitmap image: auditTrail) {
        auditTrailBase64.pushString(bitmapToBase64(image, 90));
      }

      faceMetricsObj.putArray("auditTrail", auditTrailBase64);
      faceMetricsObj.putString("facemap", bytesToBase64(facemap));
      resultObj.putMap("faceMetrics", faceMetricsObj);
      return resultObj;
    }

    WritableArray auditTrailTags = Arguments.createArray();
    for (Bitmap image: auditTrail) {
      Uri imageUri = ImageStoreModule.storeImageBitmap(this.reactContext, image, "image/png");
      auditTrailTags.pushString(imageUri.toString());
    }

    faceMetricsObj.putArray("auditTrail", auditTrailTags);
    faceMetricsObj.putString("facemap", getImageTagForBytes(facemap));


    resultObj.putMap("faceMetrics", faceMetricsObj);
    return resultObj;
  }

  private String getImageTagForBytes(byte[] bytes) throws IOException {
    return ImageStoreModule.storeImageBytes(this.reactContext, bytes).toString();
  }

  private static String bitmapToBase64(Bitmap bitmap, int quality) {
    return bytesToBase64(toJpeg(bitmap, quality));
  }

  private static String bytesToBase64(byte[] bytes) {
    return Base64.encodeToString(bytes, Base64.NO_WRAP);
  }

  private static byte[] toJpeg(Bitmap bitmap, int quality) throws OutOfMemoryError {
    ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
    bitmap.compress(Bitmap.CompressFormat.JPEG, quality, outputStream);

    try {
      return outputStream.toByteArray();
    } finally {
      try {
        outputStream.close();
      } catch (IOException e) {
        Log.e(TAG, "problem compressing jpeg", e);
      }
    }
  }

  private static String convertZoomVerificationStatus(ZoomVerificationStatus status) {
    // Note: These string values should match exactly with the iOS implementation
    switch (status) {
      case APP_TOKEN_NOT_VALID:
        return "FailedBecauseAppTokenNotValid";
      case CAMERA_PERMISSION_DENIED:
        return "FailedBecauseCameraPermissionDeniedByUser";
      case USER_PROCESSED_SUCCESSFULLY:
        return "UserProcessedSuccessfully";
      case USER_NOT_PROCESSED:
        return "UserNotProcessed";
      case USER_CANCELLED:
        return "FailedBecauseUserCancelled";
      case FAILED_DUE_TO_OS_CONTEXT_SWITCH:
        return "FailedBecauseOfOSContextSwitch";
      case VERIFICATION_TIMED_OUT:
        return "FailedBecauseOfTimeout";
      case NETWORKING_MISSING_IN_DEV_MODE:
        return "FailedBecauseNoConnectionInDevMode";
      case OFFLINE_SESSIONS_EXCEEDED:
        return "FailedBecauseOfflineSessionsExceeded";
      case ENCRYPTION_KEY_INVALID:
        return "FailedBecauseEncryptionKeyInvalid";
      // doesn't exist in android
      //   FailedBecauseCameraPermissionDeniedByAdministrator
      //   FailedBecauseOfLowMemory
      //   FailedBecauseOfDiskWriteError
      // doesn't exist in ios
      case FAILED_DUE_TO_CAMERA_ERROR:
        return "FailedBecauseOfLowMemory";
      case FAILED_DUE_TO_INTERNAL_ERROR:
      default:
        return "FailedDueToInternalError";
    }
  }

  private static String convertExternalImageSetVerificationResult(ZoomExternalImageSetVerificationResult result) {
    // Note: These string values should match exactly with the iOS implementation
    switch (result) {
      case COULD_NOT_DETERMINE_MATCH:
        return "CouldNotDetermineMatch";
      case LOW_CONFIDENCE_MATCH:
        return "LowConfidenceMatch";
      case MATCH:
        return "Match";
      default:
        return "Unsupported";
    }
  }

  private static String convertZoomLivenessResult(ZoomDevicePartialLivenessResult result) {
    switch (result) {
      case PARTIAL_LIVENESS_SUCCESS:
        return "LowConfidenceMatch";
      case LIVENESS_UNDETERMINED:
      default:
        return "CouldNotDetermineMatch";
    }
  }
}
