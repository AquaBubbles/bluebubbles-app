import 'package:bluebubbles/helpers/types/constants.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingsOptions<T extends Object> extends StatelessWidget {
  SettingsOptions({
    Key? key,
    required this.onChanged,
    required this.options,
    this.cupertinoCustomWidgets,
    this.materialCustomWidgets,
    required this.initial,
    this.textProcessing,
    this.onMaterialTap,
    required this.title,
    this.subtitle,
    this.capitalize = true,
    this.backgroundColor,
    this.secondaryColor,
    this.useCupertino = true,
  }) : super(key: key);
  final String title;
  final void Function(T?) onChanged;
  final List<T> options;
  final Iterable<Widget>? cupertinoCustomWidgets;
  final Widget? Function(T)? materialCustomWidgets;
  final T initial;
  final String Function(T)? textProcessing;
  final void Function()? onMaterialTap;
  final String? subtitle;
  final bool capitalize;
  final Color? backgroundColor;
  final Color? secondaryColor;
  final bool useCupertino;

  @override
  Widget build(BuildContext context) {
    if (ss.settings.skin.value == Skins.iOS && useCupertino) {
      final texts = options.map((e) => Text(capitalize ? textProcessing!(e).capitalize! : textProcessing!(e), style: context.theme.textTheme.bodyLarge!.copyWith(color: e == initial ? context.theme.colorScheme.onPrimary : null)));
      final map = Map<T, Widget>.fromIterables(options, cupertinoCustomWidgets ?? texts);
      return Container(
        color: backgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        height: 50,
        width: context.width,
        child: CupertinoSlidingSegmentedControl<T>(
          children: map,
          groupValue: initial,
          thumbColor: context.theme.colorScheme.primary,
          backgroundColor: backgroundColor ?? CupertinoColors.tertiarySystemFill,
          onValueChanged: onChanged,
          padding: EdgeInsets.zero,
        ),
      );
    }
    Color surfaceColor = context.theme.colorScheme.properSurface;
    if (ss.settings.skin.value == Skins.Material
        && surfaceColor.computeDifference(context.theme.colorScheme.background) < 15) {
      surfaceColor = context.theme.colorScheme.surfaceVariant;
    }
    return Container(
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.theme.textTheme.bodyLarge,
                    ),
                    (subtitle != null)
                        ? Padding(
                          padding: const EdgeInsets.only(top: 3.0),
                          child: Text(
                            subtitle ?? "",
                            style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.properOnSurface),
                          ),
                        )
                        : const SizedBox.shrink(),
                  ]),
            ),
            const SizedBox(width: 15),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: secondaryColor ?? surfaceColor,
              ),
              child: Center(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<T>(
                    dropdownColor: secondaryColor ?? surfaceColor,
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: context.theme.textTheme.bodyLarge!.color,
                    ),
                    value: initial,
                    items: options.map<DropdownMenuItem<T>>((e) {
                      return DropdownMenuItem(
                        value: e,
                        child: materialCustomWidgets?.call(e) ?? Text(
                          capitalize ? textProcessing!(e).capitalize! : textProcessing!(e),
                          style: context.theme.textTheme.bodyLarge,
                        ),
                      );
                    }).toList(),
                    onChanged: onChanged,
                    onTap: onMaterialTap,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
