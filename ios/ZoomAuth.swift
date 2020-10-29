//
//  ZoomAuth.swift
//  ZoomSdkExample
//
//  Created by Willian Angelo on 25/01/2018.
//  Copyright © 2018 Facebook. All rights reserved.
//

import UIKit
import FaceTecSDK
import Network

@objc(ZoomAuth)
class ZoomAuth:  RCTViewManager, ProcessingDelegate, URLSessionTaskDelegate {

  var resolver: RCTPromiseResolveBlock? = nil
  var rejecter: RCTPromiseRejectBlock? = nil
  var returnBase64: Bool = false
  var initialized = false
  var licenseKey: String!

  func getRCTBridge() -> RCTBridge
  {
    let root = UIApplication.shared.keyWindow!.rootViewController!.view as! RCTRootView;
    return root.bridge;
  }

  // React Method
  @objc func verifyLiveness(_ options: Dictionary<String, Any>, // options not used at the moment
                      resolver resolve: @escaping RCTPromiseResolveBlock,
                      rejecter reject: @escaping RCTPromiseRejectBlock) -> Void {
    self.resolver = resolve
    self.rejecter = reject
    self.returnBase64 = options["returnBase64"] as? Bool ?? false;
    DispatchQueue.main.async {
      let root = UIApplication.shared.keyWindow!.rootViewController!
      var optionsWithKey = options
      optionsWithKey["licenseKey"] = self.licenseKey
      self.getSessionToken() { sessionToken in
        let _ = LivenessCheckProcessor(sessionToken: sessionToken, delegate: self, fromVC: root, options: optionsWithKey)
      }
    }
  }

  // React Method
  @objc func enroll(_ options: Dictionary<String, Any>, // options not used at the moment
                      resolver resolve: @escaping RCTPromiseResolveBlock,
                      rejecter reject: @escaping RCTPromiseRejectBlock) -> Void {
    self.resolver = resolve
    self.rejecter = reject
    DispatchQueue.main.async {
      let root = UIApplication.shared.keyWindow!.rootViewController!
      var optionsWithKey = options
      optionsWithKey["licenseKey"] = self.licenseKey
      self.getSessionToken() { sessionToken in
        let _ = EnrollmentProcessor(sessionToken: sessionToken, delegate: self, fromVC: root, options: optionsWithKey)
      }
    }
  }

  // React Method
  @objc func authenticate(_ options: Dictionary<String, Any>, // options not used at the moment
                      resolver resolve: @escaping RCTPromiseResolveBlock,
                      rejecter reject: @escaping RCTPromiseRejectBlock) -> Void {
    self.resolver = resolve
    self.rejecter = reject
    DispatchQueue.main.async {
      let root = UIApplication.shared.keyWindow!.rootViewController!
      var optionsWithKey = options
      optionsWithKey["licenseKey"] = self.licenseKey
      self.getSessionToken() { sessionToken in
        let _ = AuthenticateProcessor(sessionToken: sessionToken, delegate: self, fromVC: root, options: optionsWithKey)
      }
    }
  }

  // Show the final result and transition back into the main interface.
  func onProcessingComplete(isSuccess: Bool, facetecSessionResult: FaceTecSessionResult?) {
    let statusCode = facetecSessionResult?.status.rawValue ?? -1
    var resultJson:[String:Any] = [
      "success": isSuccess,
      "status": statusCode
    ]

    if (!isSuccess) {
      self.sendResult(resultJson)
      return
    }

    resultJson["sessionId"] = facetecSessionResult?.sessionId ?? ""

    if self.returnBase64 && facetecSessionResult?.faceScan != nil {
      resultJson["facemapBase64"] = facetecSessionResult!.faceScanBase64
    }

    self.sendResult(resultJson)
  }
  
  // Show the final result and transition back into the main interface.
  func onProcessingComplete(isSuccess: Bool, facetecSessionResult: FaceTecSessionResult?, facetecIDScanResult: FaceTecIDScanResult?) {
  }
  
  func sendResult(_ result: [String:Any]) -> Void {
    if (self.resolver == nil) {
      return
    }

    self.resolver!(result)
    self.cleanUp()
  }

  // not used at the moment
  func sendError(_ code: String, message: String, error: Error) -> Void {
    if (self.rejecter == nil) {
      return
    }

    self.rejecter!(code, message, error)
    self.cleanUp()
  }

  func cleanUp () -> Void {
    self.resolver = nil
    self.rejecter = nil
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
  @objc func getVersion(_ resolve: RCTPromiseResolveBlock,
                        rejecter reject: RCTPromiseRejectBlock) -> Void {

      let result: String = FaceTec.sdk.version

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
    self.licenseKey = options["deviceKeyIdentifier"] as! String

    let faceMapEncryptionKey = options["facemapEncryptionKey"] as! String

    FaceTec.sdk.auditTrailType = .height640 // otherwise no auditTrail images

    // Create the customization object
    let currentCustomization: FaceTecCustomization = FaceTecCustomization()
    // disable the "Your App Logo" section
    currentCustomization.overlayCustomization.brandingImage = nil

    // Apply the customization changes
    FaceTec.sdk.setCustomization(currentCustomization)
    FaceTec.sdk.initializeInDevelopmentMode(
      deviceKeyIdentifier: licenseKey,
      faceScanEncryptionKey: faceMapEncryptionKey,
      completion: { (licenseKeyValidated: Bool) -> Void in
        //
        // We want to ensure that licenseKey is valid before enabling verification
        //
        if licenseKeyValidated {
          self.initialized = true
          let message = "licenseKey validated successfully"
          print(message)
          resolve([
            "success": true
          ])
        }
        else {
          let status = FaceTec.sdk.getStatus().rawValue
          resolve([
            "success": false,
            "status": status
          ])
        }
      }
    )
  }

  func getSessionToken(sessionTokenCallback: @escaping (String) -> ()) {
      let endpoint = ZoomGlobalState.ZoomServerBaseURL + "/session-token"
      let request = NSMutableURLRequest(url: NSURL(string: endpoint)! as URL)
      request.httpMethod = "GET"
      // Required parameters to interact with the FaceTec Managed Testing API.
      request.addValue(self.licenseKey, forHTTPHeaderField: "X-Device-Key")
      request.addValue(FaceTec.sdk.createFaceTecAPIUserAgentString(""), forHTTPHeaderField: "User-Agent")
      
      let session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: OperationQueue.main)
      let task = session.dataTask(with: request as URLRequest, completionHandler: { data, response, error in
          // Ensure the data object is not nil otherwise callback with empty dictionary.
          guard let data = data else {
              print("Exception raised while attempting HTTPS call.")
//              self.handleErrorGettingServerSessionToken()
              return
          }
          if let responseJSONObj = try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments) as! [String: AnyObject] {
              if((responseJSONObj["sessionToken"] as? String) != nil)
              {
//                  self.hideSessionTokenConnectionText()
                  sessionTokenCallback(responseJSONObj["sessionToken"] as! String)
                  return
              }
              else {
                  print("Exception raised while attempting HTTPS call.")
//                  self.handleErrorGettingServerSessionToken()
              }
          }
      })
      task.resume()
  }
}
