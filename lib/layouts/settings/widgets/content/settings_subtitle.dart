import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingsSubtitle extends StatelessWidget {
  const SettingsSubtitle({
    Key? key,
    this.subtitle,
    this.unlimitedSpace = false,
  }) : super(key: key);

  final String? subtitle;
  final bool unlimitedSpace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: ListTile(
        title: subtitle != null ? Text(
          subtitle!,
          style: context.theme.textTheme.bodySmall!.copyWith(color: context.theme.colorScheme.properOnSurface),
          maxLines: unlimitedSpace ? 100 : 2,
          overflow: TextOverflow.ellipsis,
        ) : null,
        minVerticalPadding: 0,
        visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
        dense: true,
      ),
    );
  }
}
