import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ContactAvatarWidget extends StatefulWidget {
  ContactAvatarWidget({
    Key? key,
    this.size,
    this.fontSize,
    this.borderThickness = 2.0,
    this.editable = true,
    this.onTap,
    required this.handle,
    this.contact,
    this.scaleSize = true,
    this.preferHighResAvatar = false,
  }) : super(key: key);
  final Handle? handle;
  final Contact? contact;
  final double? size;
  final double? fontSize;
  final double borderThickness;
  final bool editable;
  final Function? onTap;
  final bool scaleSize;
  final bool preferHighResAvatar;

  @override
  State<ContactAvatarWidget> createState() => _ContactAvatarWidgetState();
}

class _ContactAvatarWidgetState extends OptimizedState<ContactAvatarWidget> {
  Contact? get contact => widget.contact ?? widget.handle?.contact;
  String get keyPrefix => widget.handle?.address ?? randomString(8);

  @override
  void initState() {
    super.initState();
    eventDispatcher.stream.listen((event) {
      if (event.item1 == 'refresh-avatar' && event.item1[0] == widget.handle?.address && mounted) {
        widget.handle?.color = event.item2[1];
        setState(() {});
      }
    });
  }

  void onAvatarTap() async {
    if (widget.onTap != null) {
      widget.onTap!.call();
      return;
    }

    if (!widget.editable
        || !ss.settings.colorfulAvatars.value
        || widget.handle == null) return;

    bool didReset = false;
    final Color color = await showColorPickerDialog(
      context,
      widget.handle?.color != null ? HexColor(widget.handle!.color!) : toColorGradient(widget.handle!.address)[0],
      title: Container(
        width: ns.width(context) - 112,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Choose a Color', style: context.theme.textTheme.titleLarge),
            TextButton(
              onPressed: () async {
                didReset = true;
                Get.back();
                widget.handle!.color = null;
                widget.handle!.save(updateColor: true);
                eventDispatcher.emit("refresh-avatar", [widget.handle?.address, widget.handle?.color]);
              },
              child: const Text("RESET"),
            )
          ]
        )
      ),
      width: 40,
      height: 40,
      spacing: 0,
      runSpacing: 0,
      borderRadius: 0,
      wheelDiameter: 165,
      enableOpacity: false,
      showColorCode: true,
      colorCodeHasColor: true,
      pickersEnabled: <ColorPickerType, bool>{
        ColorPickerType.wheel: true,
      },
      copyPasteBehavior: const ColorPickerCopyPasteBehavior(
        parseShortHexCode: true,
      ),
      actionButtons: const ColorPickerActionButtons(
        dialogActionButtons: true,
      ),
      constraints: BoxConstraints(
          minHeight: 480, minWidth: ns.width(context) - 70, maxWidth: ns.width(context) - 70),
    );

    if (didReset) return;

    // Check if the color is the same as the real gradient, and if so, set it to null
    // Because it is not custom, then just use the regular gradient
    List gradient = toColorGradient(widget.handle?.address ?? "");
    if (!isNullOrEmpty(gradient)! && gradient[0] == color) {
      widget.handle!.color = null;
    } else {
      widget.handle!.color = color.value.toRadixString(16);
    }

    widget.handle!.save(updateColor: true);

    eventDispatcher.emit("refresh-avatar", [widget.handle?.address, widget.handle?.color]);
  }

  @override
  Widget build(BuildContext context) {
    Color tileColor = ts.inDarkMode(context)
        ? context.theme.colorScheme.properSurface
        : context.theme.colorScheme.background;

    final size = (widget.size ?? 40) *
        (widget.scaleSize ? ss.settings.avatarScale.value : 1);
    List<Color> colors = [];
    if (widget.handle?.color == null) {
      colors = toColorGradient(widget.handle?.address);
    } else {
      colors = [
        HexColor(widget.handle!.color!).lightenAmount(0.02),
        HexColor(widget.handle!.color!),
      ];
    }

    return Obx(() => MouseRegion(
      cursor: !widget.editable
          || !ss.settings.colorfulAvatars.value
          || widget.handle == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onAvatarTap,
        child: Container(
          key: Key("$keyPrefix-avatar-container"),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: iOS ? null : (!ss.settings.colorfulAvatars.value
                ? HexColor("686868")
                : colors[0]),
            gradient: !iOS ? null : LinearGradient(
              begin: AlignmentDirectional.topStart,
              colors: [
                !ss.settings.colorfulAvatars.value
                    ? HexColor("928E8E")
                    : colors[1],
                !ss.settings.colorfulAvatars.value
                    ? HexColor("686868")
                    : colors[0]
              ],
            ),
            border: Border.all(
              color: ss.settings.skin.value == Skins.Samsung
                ? tileColor
                : context.theme.colorScheme.background,
              width: widget.borderThickness,
              strokeAlign: StrokeAlign.outside
            ),
            shape: BoxShape.circle,
          ),
          clipBehavior: Clip.antiAlias,
          alignment: Alignment.center,
          child: Obx(() {
            final hide = ss.settings.redactedMode.value && ss.settings.hideContactInfo.value;
            final iOS = ss.settings.skin.value == Skins.iOS;
            final avatar = contact?.avatar;
            if (isNullOrEmpty(avatar)! || hide) {
              String? initials = widget.handle?.initials?.substring(0, iOS ? null : 1);
              if (!isNullOrEmpty(initials)! && !hide) {
                return Text(
                  initials!,
                  key: Key("$keyPrefix-avatar-text"),
                  style: TextStyle(
                    fontSize: widget.fontSize ?? 18,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                );
              } else {
                return Icon(
                  iOS ? CupertinoIcons.person_fill : Icons.person,
                  color: Colors.white,
                  key: Key("$keyPrefix-avatar-icon"),
                  size: size / 2,
                );
              }
            } else {
              return Image.memory(
                avatar!,
                cacheHeight: size.toInt() * 2,
                cacheWidth: size.toInt() * 2,
                filterQuality: FilterQuality.none,
              );
            }
          }),
        ),
      ),
    ));
  }
}
