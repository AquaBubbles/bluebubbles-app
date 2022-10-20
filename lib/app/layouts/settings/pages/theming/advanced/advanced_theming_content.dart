import 'dart:async';

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/app/layouts/settings/dialogs/create_new_theme_dialog.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/content/advanced_theming_tile.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/app/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/app/wrappers/scrollbar_wrapper.dart';
import 'package:bluebubbles/core/events/event_dispatcher.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tuple/tuple.dart';

class AdvancedThemingContent extends StatefulWidget {
  AdvancedThemingContent({
    Key? key,
    required this.isDarkMode,
    required this.controller
  }) : super(key: key);
  final bool isDarkMode;
  final StreamController controller;

  @override
  State<AdvancedThemingContent> createState() => _AdvancedThemingContentState();
}

class _AdvancedThemingContentState extends OptimizedState<AdvancedThemingContent> with ThemeHelpers {
  late ThemeStruct currentTheme;
  List<ThemeStruct> allThemes = [];
  bool editable = false;
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.isDarkMode) {
      currentTheme = ThemeStruct.getDarkTheme();
    } else {
      currentTheme = ThemeStruct.getLightTheme();
    }
    allThemes = ThemeStruct.getThemes();

    widget.controller.stream.listen((event) {
      BuildContext _context = context;
      showDialog(
        context: context,
        builder: (context) => CreateNewThemeDialog(_context, widget.isDarkMode, currentTheme, (newTheme) {
          allThemes.add(newTheme);
          currentTheme = newTheme;
          if (widget.isDarkMode) {
            ts.changeTheme(_context, dark: currentTheme);
          } else {
            ts.changeTheme(_context, light: currentTheme);
          }
        })
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    editable = !currentTheme.isPreset && ss.settings.monetTheming.value == Monet.none;
    final length = currentTheme
        .colors(widget.isDarkMode, returnMaterialYou: false).keys
        .where((e) => e != "outline").length ~/ 2 + 1;

    return ScrollbarWrapper(
      controller: _controller,
      child: CustomScrollView(
        controller: _controller,
        physics: ThemeSwitcher.getScrollPhysics(),
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: SettingsOptions<ThemeStruct>(
              title: "Selected Theme",
              initial: currentTheme,
              options: allThemes
                  .where((a) => !a.name.contains("🌙") && !a.name.contains("☀")).toList()
                ..add(ThemeStruct(name: "Divider1"))
                ..addAll(allThemes.where((a) => widget.isDarkMode ? a.name.contains("🌙") : a.name.contains("☀")))
                ..add(ThemeStruct(name: "Divider2"))
                ..addAll(allThemes.where((a) => !widget.isDarkMode ? a.name.contains("🌙") : a.name.contains("☀"))),
              backgroundColor: material ? tileColor : headerColor,
              secondaryColor: material ? headerColor : tileColor,
              textProcessing: (struct) => struct.name.toUpperCase(),
              useCupertino: false,
              materialCustomWidgets: (struct) => struct.name.contains("Divider")
                  ? Divider(color: context.theme.colorScheme.outline, thickness: 2, height: 2)
                  : Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.all(3),
                            child: Container(
                              height: 12,
                              width: 12,
                              decoration: BoxDecoration(
                                color: struct.data.colorScheme.primary,
                                borderRadius: BorderRadius.all(Radius.circular(4)),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(3),
                            child: Container(
                              height: 12,
                              width: 12,
                              decoration: BoxDecoration(
                                color: struct.data.colorScheme.secondary,
                                borderRadius: BorderRadius.all(Radius.circular(4)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.all(3),
                            child: Container(
                              height: 12,
                              width: 12,
                              decoration: BoxDecoration(
                                color: struct.data.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.all(Radius.circular(4)),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(3),
                            child: Container(
                              height: 12,
                              width: 12,
                              decoration: BoxDecoration(
                                color: struct.data.colorScheme.tertiary,
                                borderRadius: BorderRadius.all(Radius.circular(4)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Text(
                      struct.name,
                      style: context.theme.textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
              onChanged: (value) async {
                if (value == null || value.name.contains("Divider")) return;
                value.save();

                if (value.name == "Music Theme ☀" || value.name == "Music Theme 🌙") {
                  // disable monet theming if music theme enabled
                  ss.settings.monetTheming.value = Monet.none;
                  ss.saveSettings(ss.settings);
                  await mcs.invokeMethod("request-notif-permission");
                  try {
                    await mcs.invokeMethod("start-notif-listener");
                    ss.settings.colorsFromMedia.value = true;
                    ss.saveSettings(ss.settings);
                  } catch (e) {
                    showSnackbar("Error",
                        "Something went wrong, please ensure you granted the permission correctly!");
                    return;
                  }
                } else {
                  ss.settings.colorsFromMedia.value = false;
                  ss.saveSettings(ss.settings);
                }

                if (value.name == "Music Theme ☀" || value.name == "Music Theme 🌙") {
                  var allThemes = ThemeStruct.getThemes();
                  var currentLight = ThemeStruct.getLightTheme();
                  var currentDark = ThemeStruct.getDarkTheme();
                  ss.prefs.setString("previous-light", currentLight.name);
                  ss.prefs.setString("previous-dark", currentDark.name);
                  ts.changeTheme(
                      context,
                      light: allThemes.firstWhere((element) => element.name == "Music Theme ☀"),
                      dark: allThemes.firstWhere((element) => element.name == "Music Theme 🌙")
                  );
                } else if (currentTheme.name == "Music Theme ☀" ||
                    currentTheme.name == "Music Theme 🌙") {
                  if (!widget.isDarkMode) {
                    ThemeStruct previousDark = ts.revertToPreviousDarkTheme();
                    ts.changeTheme(context, light: value, dark: previousDark);
                  } else {
                    ThemeStruct previousLight = ts.revertToPreviousLightTheme();
                    ts.changeTheme(context, light: previousLight, dark: value);
                  }
                } else if (widget.isDarkMode) {
                  ts.changeTheme(context, dark: value);
                } else {
                  ts.changeTheme(context, light: value);
                }
                currentTheme = value;
                editable = !currentTheme.isPreset;
                setState(() {});

              EventDispatcher().emit('theme-update', null);
            },
          ),
        ),
          SliverToBoxAdapter(
              child: SettingsSwitch(
            onChanged: (bool val) async {
              currentTheme.gradientBg = val;
              currentTheme.save();
              if (widget.isDarkMode) {
                ts.changeTheme(context, dark: currentTheme);
              } else {
                ts.changeTheme(context, light: currentTheme);
              }
            },
            initialVal: currentTheme.gradientBg,
            title: "Gradient Message View Background",
            backgroundColor: tileColor,
            subtitle:
                "Make the background of the messages view an animated gradient based on the background and primary colors",
            isThreeLine: true,
          )),
          const SliverToBoxAdapter(
            child: SettingsSubtitle(
              subtitle: "Tap to edit the base color\nLong press to edit the color for elements displayed on top of the base color\nDouble tap to learn how the colors are used",
              unlimitedSpace: true,
            )
          ),
          if (ss.settings.monetTheming.value != Monet.none)
            SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        iOS
                            ? CupertinoIcons.info
                            : Icons.info_outline,
                        size: 20,
                        color: context.theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Text(
                            "You have Material You theming enabled, so some or all of these colors may be generated by Monet. Disable Material You to view the original theme colors.",
                          style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.properOnSurface),
                        )
                      ),
                    ],
                  ),
                )
            ),
          SliverPadding(
            padding: const EdgeInsets.only(top: 20, bottom: 10, left: 15),
            sliver: SliverToBoxAdapter(
              child: Text("COLORS", style: context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.outline)),
            ),
          ),
          SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return AdvancedThemingTile(
                  currentTheme: currentTheme,
                  tuple: Tuple2(currentTheme.colors(widget.isDarkMode).entries.toList()[index < length - 1
                      ? index * 2 : currentTheme.colors(widget.isDarkMode).entries.length - (length - index)],
                      index < length - 1 ? currentTheme.colors(widget.isDarkMode).entries.toList()[index * 2 + 1] : null),
                  editable: editable,
                );
              },
              childCount: length,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: kIsDesktop ? (ns.width(context) / 150).floor() : 2,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(top: 20, bottom: 10, left: 15),
            sliver: SliverToBoxAdapter(
              child: Text("FONT SIZE SCALING", style: context.theme.textTheme.bodyMedium!.copyWith(color: context.theme.colorScheme.outline)),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                return SettingsSlider(
                  leading: Text(currentTheme.textSizes.keys.toList()[index]),
                  startingVal: currentTheme.textSizes.values.toList()[index] / ThemeStruct.defaultTextSizes.values.toList()[index],
                  update: (double val) {
                    final map = currentTheme.toMap();
                    map["data"]["textTheme"][currentTheme.textSizes.keys.toList()[index]]['fontSize'] = ThemeStruct.defaultTextSizes.values.toList()[index] * val;
                    currentTheme.data = ThemeStruct.fromMap(map).data;
                    setState(() {});
                  },
                  onChangeEnd: (double val) {
                    final map = currentTheme.toMap();
                    map["data"]["textTheme"][currentTheme.textSizes.keys.toList()[index]]['fontSize'] = ThemeStruct.defaultTextSizes.values.toList()[index] * val;
                    currentTheme.data = ThemeStruct.fromMap(map).data;
                    currentTheme.save();
                    if (currentTheme.name == ss.prefs.getString("selected-dark")) {
                      ts.changeTheme(context, dark: currentTheme);
                    } else if (currentTheme.name == ss.prefs.getString("selected-light")) {
                      ts.changeTheme(context, light: currentTheme);
                    }
                  },
                  backgroundColor: tileColor,
                  min: 0.5,
                  max: 3,
                  divisions: 10,
                  formatValue: ((double val) => val.toStringAsFixed(2)),
                );
              },
              childCount: currentTheme.textSizes.length,
            ),
          ),
          if (!currentTheme.isPreset)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: context.theme.colorScheme.errorContainer,
                  ),
                  child: Text(
                    "Delete",
                    style: TextStyle(color: context.theme.colorScheme.onErrorContainer),
                  ),
                  onPressed: () async {
                    allThemes.removeWhere((element) => element == currentTheme);
                    currentTheme.delete();
                    currentTheme =
                      widget.isDarkMode ? ts.revertToPreviousDarkTheme() : ts.revertToPreviousLightTheme();
                    allThemes = ThemeStruct.getThemes();
                    if (widget.isDarkMode) {
                      ts.changeTheme(context, dark: currentTheme);
                    } else {
                      ts.changeTheme(context, light: currentTheme);
                    }
                    setState(() {});
                  },
                ),
              ),
            ),
            const SliverPadding(
              padding: EdgeInsets.all(25),
            ),
        ],
      ),
    );
  }
}
