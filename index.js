import { NativeModules, Platform } from 'react-native'
import { SDKStatus, VerificationStatus } from './constants'
import * as defaults from './defaults'
import { VerificationPendingError, NotInitializedError } from './errors'
import statusToString from './status'

export const status = {
  sdk: SDKStatus,
  verification: VerificationStatus,
}

const wrapNative = native => {
  let initialized
  let processing

  const initialize = async opts => {
    initialized = false

    const result = await native.initialize({
      ...defaults.initialize,
      ...opts,
      // backwards compat
      licenseKey: opts.licenseKey || opts.appToken
    })

    initialized = result.success
    return result
  }

  const getVersion = () => native.getVersion()
  const exec = async (operation, opts = {}) => {
    if (!initialized) {
      throw new NotInitializedError('initialize me first!')
    }

    if (processing) {
      throw new VerificationPendingError('only one verification can be done at a time')
    }

    let result
    try {
      result = await native[operation]({
        ...defaults[operation],
        ...opts,
      })

      result.status = statusToString(result.status)
      return result
    } finally {
      processing = false
    }
  }

  const enroll = (opts) => {
    if (typeof opts.id !== 'string' || !opts.id) throw new Error('expected string "id"')

    return exec('enroll', opts)
  }

  const authenticate = (opts) => {
    if (typeof opts.id !== 'string' || !opts.id) throw new Error('expected string "id"')

    return exec('authenticate', opts)
  }

  return {
    initialize,
    verifyLiveness: exec.bind(null, 'verifyLiveness'),
    // backwards compat
    verify: exec.bind(null, 'verifyLiveness'),
    enroll,
    authenticate,
    getVersion,
  }
}

const zoomAuth = wrapNative(NativeModules.RNReactNativeZoomSdk)
export default zoomAuth
