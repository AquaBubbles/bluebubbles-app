import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRCodeScanner extends StatefulWidget {
  QRCodeScanner({Key? key}) : super(key: key);

  @override
  State<QRCodeScanner> createState() => _QRCodeScannerState();
}

class _QRCodeScannerState extends OptimizedState<QRCodeScanner> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: ss.settings.immersiveMode.value ? Colors.transparent : context.theme.colorScheme.background, // navigation bar color
        systemNavigationBarIconBrightness: context.theme.colorScheme.brightness,
        statusBarColor: Colors.transparent, // status bar color
        statusBarIconBrightness: context.theme.colorScheme.brightness.opposite,
      ),
      child: Scaffold(
        backgroundColor: context.theme.colorScheme.background,
        body: MobileScanner(
          key: qrKey,
          allowDuplicates: false,
          onDetect: (barcode, args) {
            if (!isNullOrEmpty(barcode.rawValue)!) {
              Navigator.of(context).pop(barcode.rawValue);
            }
          },
        ),
      ),
    );
  }
}
