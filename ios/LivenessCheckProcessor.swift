// Demonstrates performing a Liveness Check.

import UIKit
import Foundation
import FaceTecSDK

class LivenessCheckProcessor: NSObject, URLSessionDelegate, FaceTecFaceScanProcessorDelegate {
    var licenseKey: String!
    var delegate: ProcessingDelegate
    var latestZoomSessionResult: FaceTecSessionResult?
    var isSuccess: Bool

    init(sessionToken: String, delegate: ProcessingDelegate, fromVC: UIViewController, options: Dictionary<String, Any>) {
        self.delegate = delegate
        self.isSuccess = false

        super.init()
        
        self.licenseKey = options["licenseKey"] as? String

        // Launch the ZoOm Session.
        let sessionVC = FaceTec.sdk.createSessionVC(faceScanProcessorDelegate: self, sessionToken: sessionToken)
        if (options["useOverlay"] as? Bool ?? false) {
            sessionVC.modalPresentationStyle = .overCurrentContext
        }
        
        fromVC.present(sessionVC, animated: true, completion: nil)
    }
    
    // Required function that handles calling ZoOm Server to get result and decides how to continue.
    func processSessionWhileFaceTecSDKWaits(sessionResult: FaceTecSessionResult, faceScanResultCallback: FaceTecFaceScanResultCallback) {
        self.latestZoomSessionResult = sessionResult
        // cancellation, timeout, etc.
        if sessionResult.status != .sessionCompletedSuccessfully {
            faceScanResultCallback.onFaceScanResultCancel();
            return
        }
        
        // Create and parse request to ZoOm Server.
        NetworkingHelpers.getLivenessCheckResponseFromZoomServer(
            urlSessionDelegate: self,
            licenseKey: self.licenseKey,
            zoomSessionResult: sessionResult,
            resultCallback: { nextStep in
                if nextStep == .Succeed {
                    // Dynamically set the success message.
//                    ZoomCustomization.setOverrideResultScreenSuccessMessage("Liveness\nConfirmed")
                    faceScanResultCallback.onFaceScanResultSucceed()
                    self.isSuccess = true
                }
                else if nextStep == .Retry {
                    faceScanResultCallback.onFaceScanResultRetry()
                }
                else {
                    faceScanResultCallback.onFaceScanResultCancel()
                }
            }
        )
    }
    
    // iOS way to get upload progress and update ZoOm UI.
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
//        let uploadProgress: Float = Float(totalBytesSent) / Float(totalBytesExpectedToSend)
    }
    
    // The final callback ZoOm SDK calls when done with everything.
    func onFaceTecSDKCompletelyDone() {
        delegate.onProcessingComplete(isSuccess: isSuccess, facetecSessionResult: latestZoomSessionResult)
    }
}
