import 'dart:core';

import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';

@Deprecated('Use ThemeStruct instead.')
class ThemeObject {
  int? id;
  String? name;
  bool selectedLightTheme = false;
  bool selectedDarkTheme = false;
  bool gradientBg = false;
  bool previousLightTheme = false;
  bool previousDarkTheme = false;
  ThemeData? data;
  List<ThemeEntry> entries = [];

  ThemeObject({
    this.id,
    this.name,
    this.selectedLightTheme = false,
    this.selectedDarkTheme = false,
    this.gradientBg = false,
    this.previousLightTheme = false,
    this.previousDarkTheme = false,
    this.data,
  });

  bool get isPreset =>
      name == "OLED Dark" ||
      name == "Bright White" ||
      name == "Nord Theme" ||
      name == "Music Theme (Light)" ||
      name == "Music Theme (Dark)";

  List<ThemeEntry> toEntries() => [
        ThemeEntry.fromStyle(ThemeColors.DisplayLarge, data!.textTheme.displayLarge!),
        ThemeEntry.fromStyle(ThemeColors.DisplayMedium, data!.textTheme.displayMedium!),
        ThemeEntry.fromStyle(ThemeColors.BodyLarge, data!.textTheme.bodyLarge!),
        ThemeEntry.fromStyle(ThemeColors.BodyMedium, data!.textTheme.bodyMedium!),
        ThemeEntry.fromStyle(ThemeColors.TitleMedium, data!.textTheme.titleMedium!),
        ThemeEntry.fromStyle(ThemeColors.TitleSmall, data!.textTheme.titleSmall!),
        ThemeEntry(name: ThemeColors.AccentColor, color: data!.colorScheme.secondary, isFont: false),
        ThemeEntry(name: ThemeColors.DividerColor, color: data!.dividerColor, isFont: false),
        ThemeEntry(name: ThemeColors.BackgroundColor, color: data!.colorScheme.background, isFont: false),
        ThemeEntry(name: ThemeColors.PrimaryColor, color: data!.primaryColor, isFont: false),
      ];

  static List<ThemeObject> getThemes() {
    // ignore: argument_type_not_assignable, return_of_invalid_type, invalid_assignment, for_in_of_invalid_element_type
    return <ThemeObject>[];
  }

  List<ThemeEntry> fetchData() {
    if (isPreset && !name!.contains("Music")) {
      if (name == "OLED Dark") {
        data = ts.oledDarkTheme;
      } else if (name == "Bright White") {
        data = ts.whiteLightTheme;
      } else if (name == "Nord Theme") {
        data = ts.nordDarkTheme;
      }

      entries = toEntries();
    }
    return entries;
  }

  ThemeData get themeData {
    assert(entries.length == ThemeColors.Colors.length);
    Map<String, ThemeEntry> data = {};
    for (ThemeEntry entry in entries) {
      if (entry.name == ThemeColors.DisplayLarge) {
        data[ThemeColors.DisplayLarge] = entry;
      } else if (entry.name == ThemeColors.DisplayMedium) {
        data[ThemeColors.DisplayMedium] = entry;
      } else if (entry.name == ThemeColors.BodyLarge) {
        data[ThemeColors.BodyLarge] = entry;
      } else if (entry.name == ThemeColors.BodyMedium) {
        data[ThemeColors.BodyMedium] = entry;
      } else if (entry.name == ThemeColors.TitleMedium) {
        data[ThemeColors.TitleMedium] = entry;
      } else if (entry.name == ThemeColors.TitleSmall) {
        data[ThemeColors.TitleSmall] = entry;
      } else if (entry.name == ThemeColors.AccentColor) {
        data[ThemeColors.AccentColor] = entry;
      } else if (entry.name == ThemeColors.DividerColor) {
        data[ThemeColors.DividerColor] = entry;
      } else if (entry.name == ThemeColors.BackgroundColor) {
        data[ThemeColors.BackgroundColor] = entry;
      } else if (entry.name == ThemeColors.PrimaryColor) {
        data[ThemeColors.PrimaryColor] = entry;
      }
    }

    return ThemeData(
        textTheme: TextTheme(
          displayLarge: data[ThemeColors.DisplayLarge]!.style,
          displayMedium: data[ThemeColors.DisplayMedium]!.style,
          bodyLarge: data[ThemeColors.BodyLarge]!.style,
          bodyMedium: data[ThemeColors.BodyMedium]!.style,
          titleMedium: data[ThemeColors.TitleMedium]!.style,
          titleSmall: data[ThemeColors.TitleSmall]!.style,
        ),
        colorScheme: ColorScheme.fromSwatch(
            accentColor: data[ThemeColors.AccentColor]!.style,
            backgroundColor: data[ThemeColors.BackgroundColor]!.style,
        ),
        dividerColor: data[ThemeColors.DividerColor]!.style,
        primaryColor: data[ThemeColors.PrimaryColor]!.style);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ThemeObject && runtimeType == other.runtimeType && name == other.name;

  @override
  int get hashCode => name.hashCode;
}
