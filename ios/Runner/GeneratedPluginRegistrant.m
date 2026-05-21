//
//  Generated file. Do not edit.
//

// clang-format off

#import "GeneratedPluginRegistrant.h"

#if __has_include(<audio_service/AudioServicePlugin.h>)
#import <audio_service/AudioServicePlugin.h>
#else
@import audio_service;
#endif

#if __has_include(<audio_session/AudioSessionPlugin.h>)
#import <audio_session/AudioSessionPlugin.h>
#else
@import audio_session;
#endif

#if __has_include(<file_picker/FilePickerPlugin.h>)
#import <file_picker/FilePickerPlugin.h>
#else
@import file_picker;
#endif

#if __has_include(<flutter_js/FlutterJsPlugin.h>)
#import <flutter_js/FlutterJsPlugin.h>
#else
@import flutter_js;
#endif

#if __has_include(<isar_flutter_libs/IsarFlutterLibsPlugin.h>)
#import <isar_flutter_libs/IsarFlutterLibsPlugin.h>
#else
@import isar_flutter_libs;
#endif

#if __has_include(<just_audio/JustAudioPlugin.h>)
#import <just_audio/JustAudioPlugin.h>
#else
@import just_audio;
#endif

#if __has_include(<media_kit_libs_ios_audio/MediaKitLibsIosAudioPlugin.h>)
#import <media_kit_libs_ios_audio/MediaKitLibsIosAudioPlugin.h>
#else
@import media_kit_libs_ios_audio;
#endif

#if __has_include(<permission_handler_apple/PermissionHandlerPlugin.h>)
#import <permission_handler_apple/PermissionHandlerPlugin.h>
#else
@import permission_handler_apple;
#endif

#if __has_include(<share_plus/FPPSharePlusPlugin.h>)
#import <share_plus/FPPSharePlusPlugin.h>
#else
@import share_plus;
#endif

#if __has_include(<sqflite_darwin/SqflitePlugin.h>)
#import <sqflite_darwin/SqflitePlugin.h>
#else
@import sqflite_darwin;
#endif

@implementation GeneratedPluginRegistrant

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  [AudioServicePlugin registerWithRegistrar:[registry registrarForPlugin:@"AudioServicePlugin"]];
  [AudioSessionPlugin registerWithRegistrar:[registry registrarForPlugin:@"AudioSessionPlugin"]];
  [FilePickerPlugin registerWithRegistrar:[registry registrarForPlugin:@"FilePickerPlugin"]];
  [FlutterJsPlugin registerWithRegistrar:[registry registrarForPlugin:@"FlutterJsPlugin"]];
  [IsarFlutterLibsPlugin registerWithRegistrar:[registry registrarForPlugin:@"IsarFlutterLibsPlugin"]];
  [JustAudioPlugin registerWithRegistrar:[registry registrarForPlugin:@"JustAudioPlugin"]];
  [MediaKitLibsIosAudioPlugin registerWithRegistrar:[registry registrarForPlugin:@"MediaKitLibsIosAudioPlugin"]];
  [PermissionHandlerPlugin registerWithRegistrar:[registry registrarForPlugin:@"PermissionHandlerPlugin"]];
  [FPPSharePlusPlugin registerWithRegistrar:[registry registrarForPlugin:@"FPPSharePlusPlugin"]];
  [SqflitePlugin registerWithRegistrar:[registry registrarForPlugin:@"SqflitePlugin"]];
}

@end
