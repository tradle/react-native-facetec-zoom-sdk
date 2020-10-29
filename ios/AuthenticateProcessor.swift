//
// Welcome to the annotated FaceTec Device SDK core code for performing Authentication against a previously enrolled user.
//

import UIKit
import Foundation
import FaceTecSDK

// This is an example self-contained class to perform Authentication with the FaceTec SDK.
// You may choose to further componentize parts of this in your own Apps based on your specific requirements.
class AuthenticateProcessor: NSObject, FaceTecFaceScanProcessorDelegate, URLSessionTaskDelegate {
    var latestNetworkRequest: URLSessionTask!
    var isSuccess = false
    var faceScanResultCallback: FaceTecFaceScanResultCallback!
    var licenseKey: String!
    var delegate: ProcessingDelegate
    var latestZoomSessionResult: FaceTecSessionResult?
    var options: Dictionary<String, Any>!

    init(sessionToken: String, delegate: ProcessingDelegate, fromVC: UIViewController, options: Dictionary<String, Any>) {
        self.isSuccess = false;
        self.delegate = delegate;

        self.options = options;
        self.licenseKey = options["licenseKey"] as? String

        super.init()
        //
        // Part 1:  Starting the FaceTec Session
        //
        // Required parameters:
        // - delegate:
        // - faceScanProcessorDelegate: A class that implements FaceTecFaceScanProcessor, which handles the FaceScan when the User completes a Session.  In this example, "self" implements the class.
        // - sessionToken:  A valid Session Token you just created by calling your API to get a Session Token from the Server SDK.
        //
        let sessionVC = FaceTec.sdk.createSessionVC(faceScanProcessorDelegate: self, sessionToken: sessionToken)
        if (options["useOverlay"] as? Bool ?? false) {
            sessionVC.modalPresentationStyle = .overCurrentContext
        }

        // In your code, you will be presenting from a UIViewController elsewhere. You may choose to augment this class to pass that UIViewController in.
        // In our example code here, to keep the code in this class simple, we will just get the Sample App's UIViewController statically.
        fromVC.present(sessionVC, animated: true, completion: nil)
    }

    //
    // Part 2: Handling the Result of a FaceScan
    //
    func processSessionWhileFaceTecSDKWaits(sessionResult: FaceTecSessionResult, faceScanResultCallback: FaceTecFaceScanResultCallback) {
        //
        // DEVELOPER NOTE:  These properties are for demonstration purposes only so the Sample App can get information about what is happening in the processor.
        // In the code in your own App, you can pass around signals, flags, intermediates, and results however you would like.
        //
//        fromViewController.setLatestSessionResult(sessionResult: sessionResult)
        
        self.latestZoomSessionResult = sessionResult
        
        //
        // DEVELOPER NOTE:  A reference to the callback is stored as a class variable so that we can have access to it while performing the Upload and updating progress.
        //
        self.faceScanResultCallback = faceScanResultCallback
        
        //
        // Part 3: Handles early exit scenarios where there is no FaceScan to handle -- i.e. User Cancellation, Timeouts, etc.
        //
        if sessionResult.status != FaceTecSessionStatus.sessionCompletedSuccessfully {
            if latestNetworkRequest != nil {
                latestNetworkRequest.cancel()
            }
            
            faceScanResultCallback.onFaceScanResultCancel()
            return
        }
        
        //
        // Part 4:  Get essential data off the FaceTecSessionResult
        //
        var parameters: [String : Any] = [:]
        parameters["faceScan"] = sessionResult.faceScanBase64
        parameters["auditTrailImage"] = sessionResult.auditTrailCompressedBase64![0]
        parameters["lowQualityAuditTrailImage"] = sessionResult.lowQualityAuditTrailCompressedBase64![0]
        parameters["externalDatabaseRefID"] = self.options["id"] as! String
        
        //
        // Part 5:  Make the Networking Call to Your Servers.  Below is just example code, you are free to customize based on how your own API works.
        //
        let request = NSMutableURLRequest(url: NSURL(string: ZoomGlobalState.ZoomServerBaseURL + "/match-3d-3d")! as URL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try! JSONSerialization.data(withJSONObject: parameters, options: JSONSerialization.WritingOptions(rawValue: 0))
        request.addValue(self.licenseKey, forHTTPHeaderField: "X-Device-Key")
        request.addValue(FaceTec.sdk.createFaceTecAPIUserAgentString(sessionResult.sessionId), forHTTPHeaderField: "User-Agent")
        
        let session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: OperationQueue.main)
        latestNetworkRequest = session.dataTask(with: request as URLRequest, completionHandler: { data, response, error in
            //
            // Part 6:  In our Sample, we evaluate a boolean response and treat true as success, false as "User Needs to Retry",
            // and handle all other non-nominal responses by cancelling out.  You may have different paradigms in your own API and are free to customize based on these.
            //
            guard let data = data else {
                // CASE:  UNEXPECTED response from API. Our Sample Code keys of a success boolean on the root of the JSON object --> You define your own API contracts with yourself and may choose to do something different here based on the error.
                faceScanResultCallback.onFaceScanResultCancel()
                return
            }
            
            guard let responseJSON = try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments) as! [String: AnyObject] else {
                // CASE:  UNEXPECTED response from API.  Our Sample Code keys of a success boolean on the root of the JSON object --> You define your own API contracts with yourself and may choose to do something different here based on the error.
                faceScanResultCallback.onFaceScanResultCancel()
                return
            }
            
            //
            // DEVELOPER NOTE:  These properties are for demonstration purposes only so the Sample App can get information about what is happening in the processor.
            // In the code in your own App, you can pass around signals, flags, intermediates, and results however you would like.
            //
//            self.fromViewController.setLatestServerResult(responseJSON: responseJSON)
            
            let didSucceed = responseJSON["success"] as? Bool
            
            if didSucceed == true {
                // CASE:  Success! Authentication succeeded.
                
                //
                // DEVELOPER NOTE:  These properties are for demonstration purposes only so the Sample App can get information about what is happening in the processor.
                // In the code in your own App, you can pass around signals, flags, intermediates, and results however you would like.
                //
                self.isSuccess = true;
                
                FaceTecCustomization.setOverrideResultScreenSuccessMessage("Authenticated")
                faceScanResultCallback.onFaceScanResultSucceed()
            }
              // this includes the case where there was no match, so no point in retrying
//            else if (didSucceed == false) {
//                // CASE:  In our Sample code, "success" being present and false means that the User Needs to Retry.
//                // Real Users will likely succeed on subsequent attempts after following on-screen guidance.
//                // Attackers/Fraudsters will continue to get rejected.
//                faceScanResultCallback.onFaceScanResultRetry()
//            }
            else {
                // CASE:  UNEXPECTED response from API.  Our Sample Code keys of a success boolean on the root of the JSON object --> You define your own API contracts with yourself and may choose to do something different here based on the error.
                faceScanResultCallback.onFaceScanResultCancel()
            }
        })
        
        //
        // Part 8:  Actually send the request.
        //
        latestNetworkRequest.resume()
        
        //
        // Part 9:  For better UX, update the User if the upload is taking a while.  You are free to customize and enhance this behavior to your liking.
        //
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            if self.latestNetworkRequest.state == .completed { return }
            
            let uploadMessage:NSMutableAttributedString = NSMutableAttributedString.init(string: "Still Uploading...")
            faceScanResultCallback.onFaceScanUploadMessageOverride(uploadMessageOverride: uploadMessage)
        }
    }
    
    //
    // URLSessionTaskDelegate function to get progress while performing the upload to update the UX.
    //
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        let uploadProgress: Float = Float(totalBytesSent) / Float(totalBytesExpectedToSend)
        faceScanResultCallback.onFaceScanUploadProgress(uploadedPercent: uploadProgress)
    }
    
    //
    // Part 10:  This function gets called after the FaceTec SDK is completely done.  There are no parameters because you have already been passed all data in the processSessionWhileFaceTecSDKWaits function and have already handled all of your own results.
    //
    func onFaceTecSDKCompletelyDone() {
        // In your code, you will handle what to do after Authentication is successful here.
        // In our example code here, to keep the code in this class simple, we will call a static method on another class to update the Sample App UI.
        delegate.onProcessingComplete(isSuccess: isSuccess, facetecSessionResult: latestZoomSessionResult)
    }
}
