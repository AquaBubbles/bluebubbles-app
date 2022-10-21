import 'dart:async';
import 'dart:isolate';

import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/country_codes.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/utils/logger.dart';
import 'package:bluebubbles/utils/general_utils.dart';
import 'package:bluebubbles/utils/window_effects.dart';
import 'package:bluebubbles/app/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/app/layouts/startup/failure_to_start.dart';
import 'package:bluebubbles/app/layouts/setup/setup_view.dart';
import 'package:bluebubbles/app/layouts/startup/splash_screen.dart';
import 'package:bluebubbles/app/layouts/startup/upgrading_db.dart';
import 'package:bluebubbles/app/wrappers/titlebar_wrapper.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/core/managers/chat/chat_manager.dart';
import 'package:bluebubbles/services/backend_ui_interop/event_dispatcher.dart';
import 'package:bluebubbles/repository/database.dart';
import 'package:bluebubbles/repository/intents.dart';
import 'package:bluebubbles/repository/models/dart_vlc.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/repository/models/objectbox.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide MenuItem;
import 'package:flutter/scheduler.dart' hide Priority;
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_libphonenumber/flutter_libphonenumber.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:get/get.dart';
import 'package:google_ml_kit/google_ml_kit.dart' hide Message;
import 'package:intl/date_symbol_data_local.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path/path.dart' show basename, dirname, join;
import 'package:path/path.dart' as p;
import 'package:screen_retriever/screen_retriever.dart';
import 'package:secure_application/secure_application.dart';
import 'package:system_tray/system_tray.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:universal_html/html.dart' as html;
import 'package:universal_io/io.dart';
import 'package:window_manager/window_manager.dart';

late final Store store;
late final Box<Attachment> attachmentBox;
late final Box<Chat> chatBox;
late final Box<Contact> contactBox;
late final Box<FCMData> fcmDataBox;
late final Box<Handle> handleBox;
late final Box<Message> messageBox;
late final Box<ScheduledMessage> scheduledBox;
late final Box<ThemeStruct> themeBox;
late final Box<ThemeEntry> themeEntryBox;
late final Box<ThemeObject> themeObjectBox;
final Completer<void> storeStartup = Completer();

String? _recentIntent;
String? get recentIntent => _recentIntent;
set recentIntent(String? intent) {
  _recentIntent = intent;

  // After 5 seconds, we want to set the intent to null
  if (intent != null) {
    Future.delayed(Duration(seconds: 5), () {
      _recentIntent = null;
    });
  }
}

@pragma('vm:entry-point')
//ignore: prefer_void_to_null
Future<Null> main() async {
  await initApp(false);
}

@pragma('vm:entry-point')
// ignore: prefer_void_to_null
Future<Null> bubble() async {
  await initApp(true);
}

//ignore: prefer_void_to_null
Future<Null> initApp(bool bubble) async {
  WidgetsFlutterBinding.ensureInitialized();
  /* ----- SERVICES INITIALIZATION ----- */
  ls.isBubble = false;
  ls.isUiThread = true;
  await ss.init();
  await fs.init();
  await Logger.init();
  Logger.startup.value = true;
  Logger.info('Startup Logs');
  await ts.init();
  await mcs.init();
  notif.init();

  /* ----- RANDOM STUFF INITIALIZATION ----- */
  HttpOverrides.global = BadCertOverride();
  dynamic exception;
  StackTrace? stacktrace;

  /* ----- APPDATA MIGRATION ----- */
  if ((Platform.isLinux || Platform.isWindows) && !kIsWeb) {
    // Migrate to new appdata location if this function returns the new place and we still have the old place
    if (basename(fs.appDocDir.absolute.path) == "bluebubbles") {
      Directory oldAppData = Platform.isWindows
          ? Directory(join(dirname(dirname(fs.appDocDir.absolute.path)), "com.bluebubbles\\bluebubbles_app"))
          : Directory(join(dirname(fs.appDocDir.absolute.path), "bluebubbles_app"));
      if (await oldAppData.exists() && !await Directory(join(fs.appDocDir.path, "objectbox")).exists()) {
        Logger.info("Copying appData to new directory");
        await copyDirectory(oldAppData, fs.appDocDir);
        Logger.info("Finished migrating appData");
      }
    }
  }

  try {
    /* ----- OBJECTBOX DB INITIALIZATION ----- */
    if (!kIsWeb) {
      Directory objectBoxDirectory = Directory(join(fs.appDocDir.path, 'objectbox'));
      final sqlitePath = join(fs.appDocDir.path, "chat.db");

      Future<void> initStore() async {
        if (!kIsDesktop) {
          Logger.info("Trying to attach to an existing ObjectBox store");
          try {
            store = Store.attach(getObjectBoxModel(), objectBoxDirectory.path);
          } catch (e, s) {
            Logger.error(e);
            Logger.error(s);
            Logger.info("Failed to attach to existing store, opening from path");
            try {
              store = await openStore(directory: objectBoxDirectory.path);
            } catch (e, s) {
              Logger.error(e);
              Logger.error(s);
            }
          }
        } else {
          try {
            if (kIsDesktop) {
              await objectBoxDirectory.create(recursive: true);
            }
            Logger.info("Opening ObjectBox store from path: ${objectBoxDirectory.path}");
            store = await openStore(directory: objectBoxDirectory.path);
          } catch (e, s) {
            Logger.error(e);
            Logger.error(s);
            if (Platform.isWindows) {
              Logger.info("Failed to open store from default path. Using custom path");
              final customStorePath = "C:\\bluebubbles_app";
              ss.prefs.setBool("use-custom-path", true);
              ss.prefs.setString("custom-path", customStorePath);
              objectBoxDirectory = Directory(join(customStorePath, "objectbox"));
              await objectBoxDirectory.create(recursive: true);
              Logger.info("Opening ObjectBox store from custom path: ${objectBoxDirectory.path}");
              store = await openStore(directory: join(customStorePath, 'objectbox'));
            }
            // TODO Linux fallback
          }
        }
        attachmentBox = store.box<Attachment>();
        chatBox = store.box<Chat>();
        contactBox = store.box<Contact>();
        fcmDataBox = store.box<FCMData>();
        handleBox = store.box<Handle>();
        messageBox = store.box<Message>();
        scheduledBox = store.box<ScheduledMessage>();
        themeBox = store.box<ThemeStruct>();
        themeEntryBox = store.box<ThemeEntry>();
        themeObjectBox = store.box<ThemeObject>();
        Chat.startWatchingChats();
        if (themeBox.isEmpty()) {
          ss.prefs.setString("selected-dark", "OLED Dark");
          ss.prefs.setString("selected-light", "Bright White");
          themeBox.putMany(ts.defaultThemes);
        }
      }

      if (!(await objectBoxDirectory.exists()) && await File(sqlitePath).exists()) {
        runApp(UpgradingDB());
        print("Converting sqflite to ObjectBox...");
        Stopwatch s = Stopwatch();
        s.start();
        await DBProvider.db.initDB(initStore: initStore);
        s.stop();
        Logger.info("Migrated in ${s.elapsedMilliseconds} ms");
      } else {
        if (await File(sqlitePath).exists() && ss.prefs.getBool('objectbox-migration') != true) {
          runApp(UpgradingDB());
          print("Converting sqflite to ObjectBox...");
          Stopwatch s = Stopwatch();
          s.start();
          await DBProvider.db.initDB(initStore: initStore);
          s.stop();
          print("Migrated in ${s.elapsedMilliseconds} ms");
        } else {
          await initStore();
        }
      }
    }

    /* ----- SERVICES INITIALIZATION POST OBJECTBOX ----- */
    storeStartup.complete();
    ss.getFcmData();
    if (!kIsWeb) {
      await cs.init();
    }
    await intents.init();
    socket;

    /* ----- DATE FORMATTING INITIALIZATION ----- */
    await initializeDateFormatting();

    /* ----- SPLASH SCREEN INITIALIZATION ----- */
    if (!ss.settings.finishedSetup.value && !kIsWeb && !kIsDesktop) {
      runApp(MaterialApp(
          home: SplashScreen(shouldNavigate: false),
          theme: ThemeData(
              backgroundColor: SchedulerBinding.instance.window.platformBrightness == Brightness.dark
                  ? Colors.black
                  : Colors.white
          )
      ));
    }

    /* ----- ANDROID SPECIFIC INITIALIZATION ----- */
    if (!kIsWeb && !kIsDesktop) {
      /* ----- TIME ZONE INITIALIZATION ----- */
      tz.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation(await FlutterNativeTimezone.getLocalTimezone()));
      } catch (_) {}

      /* ----- MLKIT INITIALIZATION ----- */
      if (!await EntityExtractorModelManager().isModelDownloaded(EntityExtractorLanguage.english.name)) {
        EntityExtractorModelManager().downloadModel(EntityExtractorLanguage.english.name, isWifiRequired: false);
      }

      /* ----- PHONE NUMBER FORMATTING INITIALIZATION ----- */
      await FlutterLibphonenumber().init();
    }

    /* ----- DESKTOP SPECIFIC INITIALIZATION ----- */
    if (kIsDesktop) {
      /* ----- VLC INITIALIZATION ----- */
      await DartVLC.initialize();

      /* ----- WINDOW INITIALIZATION ----- */
      await WindowManager.instance.ensureInitialized();
      await WindowManager.instance.setTitle('BlueBubbles');
      await Window.initialize();
      if (Platform.isWindows) {
        await Window.hideWindowControls();
      }
      WindowManager.instance.addListener(DesktopWindowListener());
      doWhenWindowReady(() async {
        await WindowManager.instance.setMinimumSize(Size(300, 300));
        Display primary = await ScreenRetriever.instance.getPrimaryDisplay();
        Size size = primary.size;
        Rect bounds = Rect.fromLTWH(0, 0, size.width, size.height);

        double? width = ss.prefs.getDouble("window-width");
        double? height = ss.prefs.getDouble("window-height");
        if (width != null && height != null) {
          if ((width == width.clamp(300, bounds.width)) && (height == height.clamp(300, bounds.height))) {
            await WindowManager.instance.setSize(Size(width, height));
          }
        }

        double? posX = ss.prefs.getDouble("window-x");
        double? posY = ss.prefs.getDouble("window-y");
        if (posX != null && posY != null && width != null && height != null) {
          if ((posX == posX.clamp(bounds.left, bounds.right - width)) &&
              (posY == posY.clamp(bounds.top, bounds.bottom - height))) {
            await WindowManager.instance.setPosition(Offset(posX, posY));
          }
        } else {
          await WindowManager.instance.setAlignment(Alignment.center);
        }

        await WindowManager.instance.setTitle('BlueBubbles');
        await WindowManager.instance.show();
      });

      /* ----- GIPHY API KEY INITIALIZATION ----- */
      await dotenv.load(fileName: '.env');
    }

    /* ----- EMOJI FONT INITIALIZATION ----- */
    fs.checkFont();
  } catch (e, s) {
    Logger.error(e);
    Logger.error(s);
    exception = e;
    stacktrace = s;
  }

  if (exception == null) {
    /* ----- THEME INITIALIZATION ----- */
    ThemeData light = ThemeStruct.getLightTheme().data;
    ThemeData dark = ThemeStruct.getDarkTheme().data;

    final tuple = ts.getStructsFromData(light, dark);
    light = tuple.item1;
    dark = tuple.item2;

    runApp(Main(
      lightTheme: light,
      darkTheme: dark,
    ));
  } else {
    runApp(FailureToStart(e: exception, s: stacktrace));
    throw Exception("$exception $stacktrace");
  }
}

class BadCertOverride extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
    // If there is a bad certificate callback, override it if the host is part of
    // your server URL
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        String serverUrl = sanitizeServerAddress() ?? "";
        return serverUrl.contains(host);
      };
  }
}

class DesktopWindowListener extends WindowListener {
  @override
  void onWindowFocus() {
    ls.open();
  }

  @override
  void onWindowBlur() {
    ls.close();
  }

  @override
  void onWindowResized() async {
    ss.prefs.setDouble("window-width", (await WindowManager.instance.getSize()).width);
    ss.prefs.setDouble("window-height", (await WindowManager.instance.getSize()).height);
  }

  @override
  void onWindowMoved() async {
    ss.prefs.setDouble("window-x", (await WindowManager.instance.getPosition()).dx);
    ss.prefs.setDouble("window-y", (await WindowManager.instance.getPosition()).dy);
  }
}

class Main extends StatelessWidget {
  final ThemeData darkTheme;
  final ThemeData lightTheme;

  const Main({Key? key, required this.lightTheme, required this.darkTheme}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AdaptiveTheme(
      light: lightTheme.copyWith(textSelectionTheme: TextSelectionThemeData(selectionColor: lightTheme.colorScheme.primary)),
      dark: darkTheme.copyWith(textSelectionTheme: TextSelectionThemeData(selectionColor: darkTheme.colorScheme.primary)),
      initial: AdaptiveThemeMode.system,
      builder: (theme, darkTheme) => GetMaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'BlueBubbles',
        theme: theme.copyWith(appBarTheme: theme.appBarTheme.copyWith(elevation: 0.0)),
        darkTheme: darkTheme.copyWith(appBarTheme: darkTheme.appBarTheme.copyWith(elevation: 0.0)),
        navigatorKey: ns.key,
        home: Home(),
        shortcuts: {
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.comma): const OpenSettingsIntent(),
          LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.keyN): const OpenNewChatCreatorIntent(),
          if (kIsDesktop)
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN): const OpenNewChatCreatorIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyF): const OpenSearchIntent(),
          LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.keyR): const ReplyRecentIntent(),
          if (kIsDesktop) LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyR): const ReplyRecentIntent(),
          LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.keyG): const StartIncrementalSyncIntent(),
          if (kIsDesktop)
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.keyR):
                const StartIncrementalSyncIntent(),
          if (kIsDesktop)
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyG): const StartIncrementalSyncIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.exclamation):
              const HeartRecentIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.at):
              const LikeRecentIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.numberSign):
              const DislikeRecentIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.dollar):
              const LaughRecentIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.percent):
              const EmphasizeRecentIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.caret):
              const QuestionRecentIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.arrowDown): const OpenNextChatIntent(),
          if (kIsDesktop) LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.tab): const OpenNextChatIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.arrowUp): const OpenPreviousChatIntent(),
          if (kIsDesktop)
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.tab):
                const OpenPreviousChatIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyI): const OpenChatDetailsIntent(),
          LogicalKeySet(LogicalKeyboardKey.escape): const GoBackIntent(),
        },
        builder: (context, child) =>
            SecureApplication(
              child: Builder(builder: (context) {
                if (ss.canAuthenticate && !ls.isAlive) {
                  if (ss.settings.shouldSecure.value) {
                    SecureApplicationProvider.of(context, listen: false)!.lock();
                    if (ss.settings.securityLevel.value == SecurityLevel.locked_and_secured) {
                      SecureApplicationProvider.of(context, listen: false)!.secure();
                    }
                  }
                }
                return SecureGate(
                  blurr: 0,
                  opacity: 1.0,
                  lockedBuilder: (context, controller) =>
                      Container(
                        color: context.theme.colorScheme.background,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 20.0),
                                child: Text(
                                  "BlueBubbles is currently locked. Please unlock to access your messages.",
                                  style: context.theme.textTheme.titleLarge,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Container(height: 20.0),
                              ClipOval(
                                child: Material(
                                  color: context.theme.colorScheme.primary, // button color
                                  child: InkWell(
                                    child: SizedBox(
                                        width: 60, height: 60, child: Icon(Icons.lock_open, color: context.theme.colorScheme.onPrimary)),
                                    onTap: () async {
                                      var localAuth = LocalAuthentication();
                                      bool didAuthenticate = await localAuth.authenticate(
                                          localizedReason: 'Please authenticate to unlock BlueBubbles',
                                          options: AuthenticationOptions(stickyAuth: true));
                                      if (didAuthenticate) {
                                        controller!.authSuccess(unlock: true);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  child: child ?? Container(),
                );
              }),
            ),
        defaultTransition: Transition.cupertino,
      ),
    );
  }
}

class Home extends StatefulWidget {
  Home({Key? key}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends OptimizedState<Home> with WidgetsBindingObserver {
  final ReceivePort port = ReceivePort();
  bool serverCompatible = true;
  bool fullyLoaded = false;

  @override
  void initState() {
    super.initState();

    // we want to refresh the page rather than loading a new instance of [Home]
    // to avoid errors
    //todo see if necessary
    if (ls.isAlive && kIsWeb) {
      html.window.location.reload();
    }

    /* ----- CACHED ASSETS INITIALIZATION ----- */
    ChatManager().loadAssets();

    // Bind the lifecycle events
    WidgetsBinding.instance.addObserver(this);

    /* ----- APP REFRESH LISTENER INITIALIZATION ----- */
    eventDispatcher.stream.listen((event) {
      if (event.item1 == 'refresh-all') {
        setState(() {});
      }
    });

    SchedulerBinding.instance.addPostFrameCallback((_) async {
      /* ----- SERVER VERSION CHECK ----- */
      if (kIsWeb && ss.settings.finishedSetup.value) {
        int version = (await ss.getServerDetails()).item4;
        if (version < 42) {
          setState(() {
            serverCompatible = false;
          });
        }

        /* ----- CTRL-F OVERRIDE ----- */
        html.document.onKeyDown.listen((e) {
          if (e.keyCode == 114 || (e.ctrlKey && e.keyCode == 70)) {
            e.preventDefault();
          }
        });
      }

      /* ----- SYSTEM TRAY INITIALIZATION ----- */
      if (kIsDesktop) {
        await initSystemTray();
      }

      if (!ss.settings.finishedSetup.value) {
        setState(() {
          fullyLoaded = true;
        });
      }
    });
  }

  @override
  void didChangeDependencies() async {
    Locale myLocale = Localizations.localeOf(context);
    countryCode = myLocale.countryCode;
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    // Clean up observer when app is fully closed
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Just in case the theme doesn't change automatically
  /// Workaround for adaptive_theme issue #32
  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    if (AdaptiveTheme.maybeOf(context)?.mode == AdaptiveThemeMode.system) {
      if (AdaptiveTheme.maybeOf(context)?.brightness == Brightness.light) {
        AdaptiveTheme.maybeOf(context)?.setLight();
      } else {
        AdaptiveTheme.maybeOf(context)?.setDark();
      }
      AdaptiveTheme.maybeOf(context)?.setSystem();
    }
  }

  /// Render
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      systemNavigationBarColor: ss.settings.immersiveMode.value
          ? Colors.transparent : context.theme.colorScheme.background, // navigation bar color
      systemNavigationBarIconBrightness: context.theme.colorScheme.brightness,
      statusBarColor: Colors.transparent, // status bar color
      statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
    ));

    if (kIsDesktop && Platform.isWindows) {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
        await WindowEffects.setEffect(color: context.theme.backgroundColor);
        eventDispatcher.stream.listen((event) async {
          if (event.item1 == 'theme-update') {
            await WindowEffects.setEffect(color: context.theme.backgroundColor);
          }

          if (event.item1 == 'popup-pushed') {
            bool popup = event.item2;
            if (popup) {
              ss.settings.windowEffect.value = WindowEffect.disabled;
            } else {
              ss.settings.windowEffect.value = WindowEffect.values.firstWhereOrNull((effect) => effect.toString() == ss.prefs.getString('window-effect')) ?? WindowEffect.aero;
            }
          }
        });
      });
    }

    final Rx<Color> _backgroundColor = (ss.settings.windowEffect.value == WindowEffect.disabled ? context.theme.colorScheme.background : Colors.transparent).obs;

    if (kIsDesktop) {
      ss.settings.windowEffect.listen((WindowEffect effect) {
        if (mounted) {
          _backgroundColor.value =
          effect != WindowEffect.disabled ? Colors.transparent : context.theme.colorScheme.background;
        }
      });
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: ss.settings.immersiveMode.value ? Colors.transparent : context.theme.colorScheme.background, // navigation bar color
        systemNavigationBarIconBrightness: context.theme.colorScheme.brightness,
        statusBarColor: Colors.transparent, // status bar color
        statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
      ),
      child: Actions(
        actions: {
          OpenSettingsIntent: OpenSettingsAction(context),
          OpenNewChatCreatorIntent: OpenNewChatCreatorAction(context),
          OpenSearchIntent: OpenSearchAction(context),
          OpenNextChatIntent: OpenNextChatAction(context),
          OpenPreviousChatIntent: OpenPreviousChatAction(context),
          StartIncrementalSyncIntent: StartIncrementalSyncAction(),
          GoBackIntent: GoBackAction(context),
        },
        child: Obx(() => Scaffold(
          backgroundColor: _backgroundColor.value,
          body: Builder(
            builder: (BuildContext context) {
              if (ss.settings.finishedSetup.value) {
                Logger.startup.value = false;
                if (!serverCompatible && kIsWeb) {
                  return FailureToStart(
                    otherTitle: "Server version too low, please upgrade!",
                    e: "Required Server Version: v0.2.0",
                  );
                }
                return ConversationList(
                  showArchivedChats: false,
                  showUnknownSenders: false,
                );
              } else {
                return WillPopScope(
                  onWillPop: () async => false,
                  child: TitleBarWrapper(
                      child: kIsWeb || kIsDesktop ? SetupView() : SplashScreen(shouldNavigate: fullyLoaded)),
                );
              }
            },
          ),
        )),
      ),
    );
  }
}

Future<void> initSystemTray() async {
  final systemTray = SystemTray();
  String path;
  if (Platform.isWindows) {
    path = p.joinAll([p.dirname(Platform.resolvedExecutable), 'data/flutter_assets/assets/icon', 'icon.ico']);
  } else if (Platform.isMacOS) {
    path = p.joinAll(['AppIcon']);
  } else {
    path = p.joinAll([p.dirname(Platform.resolvedExecutable), 'data/flutter_assets/assets/icon', 'icon.png']);
  }

  // We first init the systray menu and then add the menu entries
  await systemTray.initSystemTray(title: "BlueBubbles", iconPath: path, toolTip: "BlueBubbles");

  final Menu menu = Menu();
  await menu.buildFrom(
    [
      MenuItemLable(
        label: 'Open App',
        onClicked: (_) async {
          ls.open();
          await WindowManager.instance.show();
        },
      ),
      MenuItemLable(
        label: 'Hide App',
        onClicked: (_) async {
          ls.close();
          await WindowManager.instance.hide();
        },
      ),
      MenuItemLable(
        label: 'Close App',
        onClicked: (_) async {
          await WindowManager.instance.close();
        },
      ),
    ]
  );

  await systemTray.setContextMenu(menu);

  // handle system tray event
  systemTray.registerSystemTrayEventHandler((eventName) async {
    switch (eventName) {
      case 'click':
        await WindowManager.instance.show();
        break;
      case "right-click":
        await systemTray.popUpContextMenu();
        break;
    }
  });
}

Future<void> copyDirectory(Directory source, Directory destination) async => await source.list(recursive: false).forEach((element) async {
      if (element is Directory) {
        Directory newDirectory = Directory(join(destination.absolute.path, basename(element.path)));
        await newDirectory.create();

        await copyDirectory(element.absolute, newDirectory);
      } else if (element is File) {
        await element.copy(join(destination.path, basename(element.path)));
      }
    });
