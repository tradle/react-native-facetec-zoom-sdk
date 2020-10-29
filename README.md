# react-native-facetec-zoom

unofficial react-native bridge for Facetec's [Zoom SDK](https://dev.zoomlogin.com/).

## Functions

- liveness detection
- ...TODO

## Install

### Common

```sh
npm i -S tradle/react-native-facetec-zoom
react-native link react-native-facetec-zoom
```

### iOS

This library has been tested with version 9.0.1 of the iOS SDK (Android support pending)

First, download `FaceTecSDK.framework` from one of these sources:

- [Zoom SDK](https://dev.facetec.com/downloads)

Unzip the file, locate `FaceTecSDK.framework`, copy it to your `ios/` directory, and drag it to your project in XCode (Check the `Copy items if needed` option when asked)

Add a Copy File phase to your Xcode project and have `FaceTecSDK.framework` copied to Destination `Frameworks`

If you have an Objective-C project, add a blank Swift file to your project (File -> New -> Swift File), with a bridging header (it will prompt you to auto-create one).

add `NSCameraUsageDescription` to your Info.plist, e.g.:

```xml
<key>NSCameraUsageDescription</key>
<string>verify liveness with Zoom</string>
```

### Android

In your project's build.gradle (android/build.gradle), add the maven block below:

````gradle
allprojects {
  repositories {
    //  ...
    maven {
        url 'http://maven.facetec.com'
    }
}

If you want to override the default version of the Zoom SDK, add:

```gradle
ext {
  // ...
  zoomSdkVersion = '7.0.11' // <--- whichever version you want to use
  // ...
}
````

```

This module depends on [react-native-image-store](https://github.com/tradle/react-native-image-store), so you'll need to npm install and react-native link that one too.

## Usage

See example app at https://github.com/tradle/rnzoomexample
```
