import 'package:barcode_widget/barcode_widget.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/rustpush/rustpush_service.dart';
import 'package:bluebubbles/utils/share.dart';
import 'package:bluebubbles/app/layouts/settings/widgets/settings_widgets.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Response;
import 'package:bluebubbles/src/rust/api/api.dart' as api;

class DevicePanelController extends StatefulController {

  final RxBool allowSharing = false.obs;
}

class DevicePanel extends CustomStateful<DevicePanelController> {
  DevicePanel() : super(parentController: Get.put(DevicePanelController()));

  @override
  State<StatefulWidget> createState() => _DevicePanelState();
}

class _DevicePanelState extends CustomState<DevicePanel, void, DevicePanelController> {

  api.DartDeviceInfo? deviceInfo;
  String deviceName = "";

  @override
  void initState() {
    super.initState();
    api.getDeviceInfoState(state: pushService.state).then((value) {
      setState(() {
        deviceInfo = value;
        deviceName = RustPushBBUtils.modelToUser(deviceInfo!.name);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget nextIcon = Obx(() => ss.settings.skin.value != Skins.Material ? Icon(
      ss.settings.skin.value != Skins.Material ? CupertinoIcons.chevron_right : Icons.arrow_forward,
      color: context.theme.colorScheme.outline,
      size: iOS ? 18 : 24,
    ) : const SizedBox.shrink());

    return Obx(
      () => SettingsScaffold(
        title: "${ss.settings.macIsMine.value ? 'My' : 'Shared'} Mac",
        initialHeader: null,
        iosSubtitle: iosSubtitle,
        materialSubtitle: materialSubtitle,
        tileColor: tileColor,
        headerColor: headerColor,
        bodySlivers: [
          SliverList(
            delegate: SliverChildListDelegate(
              <Widget>[
                SettingsSection(
                  backgroundColor: tileColor,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(25),
                            child: Icon(
                              RustPushBBUtils.isLaptop(deviceName) ? CupertinoIcons.device_laptop : CupertinoIcons.device_desktop,
                              size: 200,
                              color: context.theme.colorScheme.properOnSurface,
                            ),
                          ),
                          Text(deviceName, style: context.theme.textTheme.titleLarge),
                          const SizedBox(height: 10),
                          Text(deviceInfo?.serial ?? ""),
                          const SizedBox(height: 10),
                          Text(deviceInfo?.osVersion ?? ""),
                          const SizedBox(height: 25),
                        ],
                      )
                    ),
                  ],
                ),
                             
              ],
            ),
          ),
        ],
      ),
    );
  }

  void saveSettings() {
    ss.saveSettings();
  }
}
