// Helpful interfaces and enums

import FaceTecSDK

protocol ProcessingDelegate: class {
    func onProcessingComplete(isSuccess: Bool, facetecSessionResult: FaceTecSessionResult?)
    func onProcessingComplete(isSuccess: Bool, facetecSessionResult: FaceTecSessionResult?, facetecIDScanResult: FaceTecIDScanResult?)
}
