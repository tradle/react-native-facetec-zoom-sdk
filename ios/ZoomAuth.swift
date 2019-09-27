//
//  ZoomAuth.swift
//  ZoomSdkExample
//
//  Created by Willian Angelo on 25/01/2018.
//  Copyright © 2018 Facebook. All rights reserved.
//

import UIKit
import ZoomAuthenticationHybrid

@objc(ZoomAuth)
class ZoomAuth:  RCTViewManager, ZoomVerificationDelegate {

  var verifyResolver: RCTPromiseResolveBlock? = nil
  var verifyRejecter: RCTPromiseRejectBlock? = nil
  var returnBase64: Bool = false
  var initialized = false

  func getRCTBridge() -> RCTBridge
  {
    let root = UIApplication.shared.keyWindow!.rootViewController!.view as! RCTRootView;
    return root.bridge;
  }

  // React Method
  @objc func verify(_ options: Dictionary<String, Any>, // options not used at the moment
                      resolver resolve: @escaping RCTPromiseResolveBlock,
                      rejecter reject: @escaping RCTPromiseRejectBlock) -> Void {
    self.verifyResolver = resolve
    self.verifyRejecter = reject
    self.returnBase64 = (options["returnBase64"] as? Bool)!
    DispatchQueue.main.async {
      let verificationVC = Zoom.sdk.createVerificationVC(
        delegate: self
      )

      if (options["useOverlay"] as? Bool)! {
        verificationVC.modalPresentationStyle = .overCurrentContext
      }

      let root = UIApplication.shared.keyWindow!.rootViewController!;
      root.present(verificationVC, animated: true, completion: nil)
    }
  }

  func getLiveness(result: ZoomDevicePartialLivenessResult) -> String {
    switch (result) {
      case .livenessUndetermined:
        return "CouldNotDetermineMatch"
      case .partialLivenessSuccess:
        return "LowConfidenceMatch"
    }
  }

  // surely there's an easier way...
  func getVerificationResultStatus(_ result: ZoomVerificationResult) -> String {
    switch(result.status) {
      case .userProcessedSuccessfully:
        return "UserProcessedSuccessfully"
      case .failedBecauseAppTokenNotValid:
        return "FailedBecauseAppTokenNotValid"
      case .userNotProcessed:
        return "UserNotProcessed"
      case .failedBecauseUserCancelled:
        return "FailedBecauseUserCancelled"
      case .failedBecauseCameraPermissionDenied:
        return "FailedBecauseCameraPermissionDeniedByUser"
      case .failedBecauseOfOSContextSwitch:
        return "FailedBecauseOfOSContextSwitch"
      case .failedBecauseOfTimeout:
        return "FailedBecauseOfTimeout"
      case .failedBecauseOfLowMemory:
        return "FailedBecauseOfLowMemory"
      case .failedBecauseNoConnectionInDevMode:
        return "FailedBecauseNoConnectionInDevMode"
      case .failedBecauseOfflineSessionsExceeded:
        return "FailedBecauseOfflineSessionsExceeded"
      case .failedBecauseEncryptionKeyInvalid:
        return "FailedBecauseEncryptionKeyInvalid"
      case .failedBecauseOfLandscapeMode:
        return "FailedBecauseOfLandscapeMode"
      case .failedBecauseOfReversePortraitMode:
        return "FailedBecauseOfReversePortraitMode"
      case .unknownError:
        return "UnknownError"
    }
  }

  func onZoomVerificationResult(result: ZoomVerificationResult) {
    print("\(result.status)")

    let status = getVerificationResultStatus(result)
    // CASE: user performed a ZoOm and passed the liveness check
    if result.status != .userProcessedSuccessfully {
      // handle other error
      self.sendResult([
        "status": status
      ])

      return
    }

    var resultJson:[String:Any] = [
      "status": status,
      "countOfZoomSessionsPerformed": result.countOfZoomSessionsPerformed,
      "sessionId": result.sessionId,
      //        "description": result.description
    ]

    if result.faceMetrics == nil {
      self.sendResult(resultJson)
      return
    }

    let face = result.faceMetrics!
    let liveness = getLiveness(result: face.devicePartialLivenessResult)
    var faceMetrics: [String:Any] = [
      "livenessResult": liveness,
      "livenessScore": face.devicePartialLivenessScore
    ]

    if self.returnBase64 && face.zoomFacemap != nil {
      faceMetrics["facemap"] = face.zoomFacemap!.base64EncodedString(options: [])
    }

    resultJson["faceMetrics"] = faceMetrics
    if face.auditTrail == nil {
      self.sendResult(resultJson)
      return
    }

    var auditTrail:[String] = []
    if self.returnBase64 {
      for image in face.auditTrail! {
        auditTrail.append(uiImageToBase64(image))
      }

      faceMetrics["auditTrail"] = auditTrail
      resultJson["faceMetrics"] = faceMetrics
      self.sendResult(resultJson)
      return
    }

    var togo = face.auditTrail!.count
    if face.zoomFacemap != nil {
      togo += 1
      storeDataInImageStore(face.zoomFacemap!) { (tag) in
        faceMetrics["facemap"] = tag
        togo -= 1
        if togo == 0 {
          resultJson["faceMetrics"] = faceMetrics
          self.sendResult(resultJson)
        }
      }
    }

    for image in face.auditTrail! {
      uiImageToImageStoreKey(image) { (tag) in
        if (tag != nil) {
          auditTrail.append(tag!)
        }

        togo -= 1
        if togo == 0 {
          faceMetrics["auditTrail"] = auditTrail
          resultJson["faceMetrics"] = faceMetrics
          self.sendResult(resultJson)
        }
      }
    }

//    EXAMPLE: retrieve facemap
//    if let zoomFacemap = result.faceMetrics?.zoomFacemap {
//      // handle ZoOm Facemap
//    }
  }

  func sendResult(_ result: [String:Any]) -> Void {
    if (self.verifyResolver == nil) {
      return
    }

    self.verifyResolver!(result)
    self.cleanUp()
  }

  // not used at the moment
  func sendError(_ code: String, message: String, error: Error) -> Void {
    if (self.verifyRejecter == nil) {
      return
    }

    self.verifyRejecter!(code, message, error)
    self.cleanUp()
  }

  func cleanUp () -> Void {
    self.verifyResolver = nil
    self.verifyRejecter = nil
  }

  func uiImageToBase64 (_ image: UIImage) -> String {
    let imageData = image.jpegData(compressionQuality: 0.9)! as NSData;
    return imageData.base64EncodedString(options: [])
  }

  func uiImageToImageStoreKey (_ image: UIImage, completionHandler: @escaping (String?) -> Void) -> Void {
    let bridge = getRCTBridge()
    let imageStore: RCTImageStoreManager = bridge.imageStoreManager;
    imageStore.store(image, with: completionHandler)
  }

  func storeDataInImageStore (_ data: Data, completionHandler: @escaping (String?) -> Void) -> Void {
    let bridge = getRCTBridge()
    let imageStore: RCTImageStoreManager = bridge.imageStoreManager;
    imageStore.storeImageData(data, with: completionHandler)
  }

  // React Method
  @objc func preload() -> Void {
    Zoom.sdk.preload()
  }

  // React Method
  @objc func getVersion(_ resolve: RCTPromiseResolveBlock,
                        rejecter reject: RCTPromiseRejectBlock) -> Void {

      let result: String = Zoom.sdk.version

      if ( !result.isEmpty ) {
          resolve([
              result: result
          ])
      } else {
          let errorMsg = "SDK Errror"
          let err: NSError = NSError(domain: errorMsg, code: 0, userInfo: nil)
          reject("getVersion", errorMsg, err)
      }
  }

  // React Method
  @objc func initialize(_ options: Dictionary<String, Any>,
                        resolver resolve: @escaping RCTPromiseResolveBlock,
                        rejecter reject: @escaping RCTPromiseRejectBlock) -> Void {

    if (options["facemapEncryptionKey"] != nil) {
      let publicKey = options["facemapEncryptionKey"] as! String
      Zoom.sdk.setFacemapEncryptionKey(publicKey: publicKey)
    }
    
    Zoom.sdk.auditTrailType = .height640 // otherwise no auditTrail images

    // Create the customization object
    let currentCustomization: ZoomCustomization = ZoomCustomization()
    currentCustomization.showPreEnrollmentScreen = (options["showPreEnrollmentScreen"] as? Bool)!
    currentCustomization.showUserLockedScreen = (options["showUserLockedScreen"] as? Bool)!
    currentCustomization.showRetryScreen = (options["showRetryScreen"] as? Bool)!
    currentCustomization.enableLowLightMode = (options["enableLowLightMode"] as? Bool)!

    addFrameCustomizations(currentCustomization: currentCustomization, options: options)
    addFeedbackCustomizations(currentCustomization: currentCustomization, options: options)
    addOvalCustomizations(currentCustomization: currentCustomization, options: options)
    
    // Apply the customization changes
    Zoom.sdk.setCustomization(currentCustomization)
    Zoom.sdk.initialize(
      appToken: options["appToken"] as! String,
      completion: { (appTokenValidated: Bool) -> Void in
        //
        // We want to ensure that App Token is valid before enabling verification
        //
        if appTokenValidated {
          self.initialized = true
          let message = "AppToken validated successfully"
          print(message)
          resolve([
            "success": true
          ])
        }
        else {
          let status = Zoom.sdk.getStatus().rawValue
          resolve([
            "success": false,
            "status": status
          ])

//          let errorMsg = "AppToken did not validate.  If Zoom ViewController's are launched, user will see an app token error state"
//          print(errorMsg)
//          let err: NSError = NSError(domain: errorMsg, code: 0, userInfo: nil)
//          reject("initialize", errorMsg, err)
        }
      }
    )
  }
  
  func addFrameCustomizations(currentCustomization: ZoomCustomization, options: Dictionary<String, Any>) {
    // Sample UI Customization: vertically center the ZoOm frame within the device's display
    if (options["centerFrame"] as? Bool)! {
      centerZoomFrameCustomization(currentZoomCustomization: currentCustomization)
    }
    
    if (options["backgroundColor"] != nil) {
      currentCustomization.frameCustomization.backgroundColor = convertToUIColor(hex: options["backgroundColor"] as! String)
    }
    
    if (options["borderColor"] != nil) {
      currentCustomization.frameCustomization.borderColor = convertToUIColor(hex: options["borderColor"] as! String)
    }
  }
  
  func addFeedbackCustomizations(currentCustomization: ZoomCustomization, options: Dictionary<String, Any>) {
    let feedbackCustomization: Dictionary<String, Any> = options["feedbackCustomization"] as! Dictionary<String, Any>
    // Create gradient layer for a custom feedback bar background on iOS
    if (!feedbackCustomization.isEmpty) {
      let backgroundColors = feedbackCustomization["backgroundColor"] as! Array<String>
      let zoomGradientLayer = createGradientLayer(_self: self, hexColor1: backgroundColors[0], hexColor2: backgroundColors[1])
      currentCustomization.feedbackCustomization.backgroundColor = zoomGradientLayer
      print("Feedback customizations applied.")
    }
  }
  
  func addOvalCustomizations(currentCustomization: ZoomCustomization, options: Dictionary<String, Any>) {
    let ovalCustomization: Dictionary<String, Any> = options["ovalCustomization"] as! Dictionary<String, Any>
    if (!ovalCustomization.isEmpty) {
      let supportedColorOvalCustomizations = ["progressColor1", "progressColor2"]
      for property in supportedColorOvalCustomizations {
        if (ovalCustomization[property] != nil) {
          let value = ovalCustomization[property]
          currentCustomization.ovalCustomization.setValue(convertToUIColor(hex: value as! String), forKey: property)
        }
      }
      print("Oval customizations applied.")
    }
  }

  func centerZoomFrameCustomization(currentZoomCustomization: ZoomCustomization) {
    let screenHeight: CGFloat = UIScreen.main.fixedCoordinateSpace.bounds.size.height
    var frameHeight: CGFloat = screenHeight * CGFloat(currentZoomCustomization.frameCustomization.sizeRatio)
    // Detect iPhone X and iPad displays
    if UIScreen.main.fixedCoordinateSpace.bounds.size.height >= 812 {
      let screenWidth = UIScreen.main.fixedCoordinateSpace.bounds.size.width
      frameHeight = screenWidth * (16.0/9.0) * CGFloat(currentZoomCustomization.frameCustomization.sizeRatio)
    }
    let topMarginToCenterFrame = (screenHeight - frameHeight)/2.0

    currentZoomCustomization.frameCustomization.topMargin = Double(topMarginToCenterFrame)
  }
}

func createGradientLayer(_self: ZoomAuth, hexColor1: String, hexColor2: String) -> CAGradientLayer {
  let gradientLayer = CAGradientLayer()
  gradientLayer.frame = _self.view().bounds
  gradientLayer.colors = [convertToUIColor(hex: hexColor1).cgColor, convertToUIColor(hex: hexColor2).cgColor]
  _self.view().layer.addSublayer(gradientLayer)
  return gradientLayer
}

func convertToUIColor(hex: String, alpha: Int = 1) -> UIColor {
  if hex.hasPrefix("#") {
    let start = hex.index(hex.startIndex, offsetBy: 1)
    let hexColor = String(hex[start...])
    
    if hexColor.count == 6 {
      let scanner = Scanner(string: hexColor)
      var hexNumber: UInt64 = 0
      
      if scanner.scanHexInt64(&hexNumber) {
        let red = CGFloat((hexNumber & 0xff0000) >> 16) / 255
        let green = CGFloat((hexNumber & 0xff00) >> 8) / 255
        let blue = CGFloat(hexNumber & 0xff) / 255
        
        return UIColor(red: red, green: green, blue: blue, alpha: CGFloat(alpha))
      }
    }
  }
  
  return UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
}
