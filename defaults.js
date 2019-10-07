export const initialize = {
  showPreEnrollmentScreen: false,
  showUserLockedScreen: false,
  showRetryScreen: false,
  enableLowLightMode: false,
  centerFrame: true,
  topMargin: 50,
  sizeRatio: 0.7,
  // copied from zoom sample app
  // override with your own if you run a zoom server
  facemapEncryptionKey: `-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA5PxZ3DLj+zP6T6HFgzzk
M77LdzP3fojBoLasw7EfzvLMnJNUlyRb5m8e5QyyJxI+wRjsALHvFgLzGwxM8ehz
DqqBZed+f4w33GgQXFZOS4AOvyPbALgCYoLehigLAbbCNTkeY5RDcmmSI/sbp+s6
mAiAKKvCdIqe17bltZ/rfEoL3gPKEfLXeN549LTj3XBp0hvG4loQ6eC1E1tRzSkf
GJD4GIVvR+j12gXAaftj3ahfYxioBH7F7HQxzmWkwDyn3bqU54eaiB7f0ftsPpWM
ceUaqkL2DZUvgN0efEJjnWy5y1/Gkq5GGWCROI9XG/SwXJ30BbVUehTbVcD70+ZF
8QIDAQAB
-----END PUBLIC KEY-----`,
  feedbackCustomization: {},
  ovalCustomization: {},
  // mainBackgroundColors: [UIColor]
  // mainForegroundColor: UIColor
  // buttonTextNormalColor: UIColor
  // buttonBackgroundNormalColor: UIColor
  // buttonTextHighlightColor: UIColor
  // buttonBackgroundHighlightColor: UIColor
  // resultsScreenBackgroundColor: [UIColor]
  // resultsScreenForegroundColor: UIColor
  // progressBarColor: CAGradientLayer
  // progressTextColor: UIColor
  // progressSpinnerColor1: UIColor
  // progressSpinnerColor2: UIColor
  // tabBackgroundColor: UIColor
  // tabBackgroundSelectedColor: UIColor
  // tabTextColor: UIColor
  // tabTextSelectedColor: UIColor
  // tabTextSuccessColor: UIColor
  // tabBackgroundSuccessColor: UIColor
  // brandingLogo: UIImage?
  // cancelButtonImage: UIImage?
  // cancelButtonLocation: ZoomAuthenticationHybrid.CancelButtonLocation
  // zoomInstructionsImages: ZoomAuthenticationHybrid.ZoomInstructions
}

export const verify = {
  returnBase64: false,
  useOverlay: false,
}
