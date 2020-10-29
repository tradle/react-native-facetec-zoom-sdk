import UIKit
import Foundation
import FaceTecSDK

class ZoomGlobalState {
    // "https://api.zoomauth.com/api/v3/biometrics" for FaceTec Managed Testing API.
    // "http://localhost:8080" if running ZoOm Server SDK (Dockerized) locally.
    // Otherwise, your webservice URL.
    static let ZoomServerBaseURL = "https://api.facetec.com/api/v3/biometrics"

    // this app can modify the customization to demonstrate different look/feel preferences for ZoOm
    static var currentCustomization: FaceTecCustomization = FaceTecCustomization()
}
