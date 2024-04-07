import 'dart:ui';

import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/network/backend_service.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:bluebubbles/src/rust/frb_generated.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' show join;
import 'package:universal_io/io.dart';

class BackgroundIsolate {
  static void initialize() {
    CallbackHandle callbackHandle = PluginUtilities.getCallbackHandle(backgroundIsolateEntrypoint)!;
    ss.prefs.setInt("backgroundCallbackHandle", callbackHandle.toRawHandle());
  }
}

@pragma('vm:entry-point')
backgroundIsolateEntrypoint() async {
  await RustLib.init();
  // can't use logger here
  debugPrint("(ISOLATE) Starting up...");
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = BadCertOverride();
  ls.isUiThread = false;
  await ss.init(headless: true);
  await fs.init(headless: true);
  await mcs.init(headless: true);
  backend.init();
  Directory objectBoxDirectory = Directory(join(fs.appDocDir.path, 'objectbox'));
  debugPrint("Trying to attach to an existing ObjectBox store");
  try {
    store = Store.attach(getObjectBoxModel(), objectBoxDirectory.path);
  } catch (e, s) {
    debugPrint(e.toString());
    debugPrint(s.toString());
    debugPrint("Failed to attach to existing store, opening from path");
    try {
      store = await openStore(directory: objectBoxDirectory.path);
    } catch (e, s) {
      debugPrint(e.toString());
      debugPrint(s.toString());
      // this can very rarely happen
      if (e.toString().contains("another store is still open using the same path")) {
        debugPrint("Retrying to attach to an existing ObjectBox store");
        store = Store.attach(getObjectBoxModel(), objectBoxDirectory.path);
      }
    }
  }
  debugPrint("Opening boxes");
  attachmentBox = store.box<Attachment>();
  chatBox = store.box<Chat>();
  contactBox = store.box<Contact>();
  fcmDataBox = store.box<FCMData>();
  handleBox = store.box<Handle>();
  messageBox = store.box<Message>();
  themeBox = store.box<ThemeStruct>();
  storeStartup.complete();
}
