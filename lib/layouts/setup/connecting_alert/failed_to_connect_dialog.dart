import 'package:get/get.dart';
import 'package:flutter/material.dart';

class FailedToConnectDialog extends StatelessWidget {
  const FailedToConnectDialog({Key key, @required this.onDismiss}) : super(key: key);
  final Function() onDismiss;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        onDismiss();
        return true;
      },
      child: AlertDialog(
        title: Text("Failed to Connect!"),
        content: Text(
          "Please make sure you are connected to wifi and that your server is online!",
        ),
        actions: [
          FlatButton(
            child: Text(
              "Ok",
              style: Theme.of(context).textTheme.bodyText1.apply(color: Theme.of(context).primaryColor),
            ),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
