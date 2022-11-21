import 'dart:async';
import 'dart:isolate';

import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/utils/share.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/app/wrappers/theme_switcher.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' as intl;
import 'package:photo_view/photo_view.dart';
import 'package:universal_io/io.dart';

class FullscreenImage extends StatefulWidget {
  FullscreenImage({
    Key? key,
    required this.file,
    required this.attachment,
    required this.showInteractions,
    required this.updatePhysics,
  }) : super(key: key);

  final PlatformFile file;
  final Attachment attachment;
  final bool showInteractions;
  final Function(ScrollPhysics) updatePhysics;

  @override
  State<FullscreenImage> createState() => _FullscreenImageState();
}

class _FullscreenImageState extends OptimizedState<FullscreenImage> with AutomaticKeepAliveClientMixin {
  final PhotoViewController controller = PhotoViewController();
  bool showOverlay = true;
  bool hasError = false;
  Uint8List? bytes;
  
  PlatformFile get file => widget.file;
  Attachment get attachment => widget.attachment;
  Message? get message => attachment.message.target;

  @override
  void initState() {
    super.initState();
    message?.getHandle();
    updateObx(() {
      initBytes();
    });
  }

  Future<void> initBytes() async {
    if (kIsWeb || file.path == null) {
      if (attachment.mimeType?.contains("image/tif") ?? false) {
        final receivePort = ReceivePort();
        await Isolate.spawn(unsupportedToPngIsolate, IsolateData(file, receivePort.sendPort));
        // Get the processed image from the isolate.
        final image = await receivePort.first as Uint8List?;
        bytes = image;
      } else {
        bytes = file.bytes;
      }
    } else if (attachment.canCompress) {
      bytes = await as.loadAndGetProperties(attachment, actualPath: file.path!);
      // All other attachments can be held in memory as bytes
    } else {
      bytes = await File(file.path!).readAsBytes();
    }
    setState(() {});
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void refreshAttachment() {
    showSnackbar('In Progress', 'Redownloading attachment. Please wait...');
    setState(() {
      bytes = null;
    });
    as.redownloadAttachment(widget.attachment, onComplete: (file) {
      setState(() {
        bytes = file.bytes;
      });
    }, onError: () {
      setState(() {
        hasError = true;
      });
    });
  }

  void showMetadataDialog() {
    List<Widget> metaWidgets = [];
    final metadataMap = <String, dynamic>{
      'filename': widget.attachment.transferName,
      'mime': widget.attachment.mimeType,
    }..addAll(widget.attachment.metadata ?? {});
    for (MapEntry entry in metadataMap.entries.where((element) => element.value != null)) {
      metaWidgets.add(RichText(
        text: TextSpan(
          children: [
            TextSpan(text: "${entry.key}: ", style: context.theme.textTheme.bodyLarge!.apply(fontWeightDelta: 2)),
            TextSpan(text: entry.value.toString(), style: context.theme.textTheme.bodyLarge)
          ],
        ),
      ));
    }

    if (metaWidgets.isEmpty) {
      metaWidgets.add(Text(
        "No metadata available",
        style: context.theme.textTheme.bodyLarge,
        textAlign: TextAlign.center,
      ));
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Metadata",
          style: context.theme.textTheme.titleLarge,
        ),
        backgroundColor: context.theme.colorScheme.properSurface,
        content: SizedBox(
          width: ns.width(context) * 3 / 5,
          height: context.height * 1 / 4,
          child: Container(
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              color: context.theme.backgroundColor,
              borderRadius: BorderRadius.circular(10)
            ),
            child: ListView(
              physics: ThemeSwitcher.getScrollPhysics(),
              children: metaWidgets,
            ),
          ),
        ),
        actions: [
          TextButton(
            child: Text(
              "Close",
              style: context.theme.textTheme.bodyLarge!.copyWith(color: context.theme.colorScheme.primary)
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.black,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: widget.showInteractions && showOverlay && material ? Row(
        children: [
          FloatingActionButton(
            backgroundColor: context.theme.colorScheme.secondary,
            child: Icon(
              Icons.file_download_outlined,
              color: context.theme.colorScheme.onSecondary,
            ),
            onPressed: () async {
              await as.saveToDisk(widget.file);
            },
          ),
          if (!kIsWeb && !kIsDesktop)
            Padding(
              padding: const EdgeInsets.only(left: 20.0),
              child: FloatingActionButton(
                backgroundColor: context.theme.colorScheme.secondary,
                child: Icon(
                  Icons.share_outlined,
                  color: context.theme.colorScheme.onSecondary,
                ),
                onPressed: () async {
                  if (widget.file.path == null) return showSnackbar("Error", "Failed to find a path to share attachment!");
                  Share.file(
                    "Shared ${widget.attachment.mimeType!.split("/")[0]} from BlueBubbles: ${widget.attachment.transferName}",
                    widget.file.path!,
                  );
                },
              ),
            ),
        ],
      ) : null,
      extendBody: true,
      bottomNavigationBar: !widget.showInteractions || !showOverlay || material ? null : Theme(
        data: context.theme.copyWith(
          navigationBarTheme: context.theme.navigationBarTheme.copyWith(
            indicatorColor: samsung ? Colors.black : context.theme.colorScheme.properSurface,
          ),
        ),
        child: NavigationBar(
          selectedIndex: 0,
          backgroundColor: samsung ? Colors.black : context.theme.colorScheme.properSurface,
          elevation: 0,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
          height: 60,
          destinations: [
            NavigationDestination(
              icon: Icon(
                iOS ? CupertinoIcons.cloud_download : Icons.file_download,
                color: samsung ? Colors.white : context.theme.colorScheme.primary,
              ),
              label: 'Download'
            ),
            if (!kIsWeb && !kIsDesktop)
              NavigationDestination(
                icon: Icon(
                  iOS ? CupertinoIcons.share : Icons.share,
                  color: samsung ? Colors.white : context.theme.colorScheme.primary,
                ),
                label: 'Share'
              ),
            if (iOS)
              NavigationDestination(
                  icon: Icon(
                    iOS ? CupertinoIcons.info : Icons.info,
                    color: context.theme.colorScheme.primary,
                  ),
                  label: 'Metadata'
              ),
            if (iOS)
              NavigationDestination(
                  icon: Icon(
                    iOS ? CupertinoIcons.refresh : Icons.refresh,
                    color: context.theme.colorScheme.primary,
                  ),
                  label: 'Refresh'
              ),
          ],
          onDestinationSelected: (value) async {
            if (value == 0) {
              await as.saveToDisk(widget.file);
            } else if (value == 1) {
              if (kIsWeb || kIsDesktop) return showMetadataDialog();
              if (widget.file.path == null) return;
              Share.file(
                "Shared ${widget.attachment.mimeType!.split("/")[0]} from BlueBubbles: ${widget.attachment.transferName}",
                widget.file.path!,
              );
            } else if (value == 2) {
              if (kIsWeb || kIsDesktop) return refreshAttachment();
              showMetadataDialog();
            } else if (value == 3) {
              refreshAttachment();
            }
          },
        ),
      ),
      body: GestureDetector(
        onTap: () {
          if (!widget.showInteractions) return;
          setState(() {
            showOverlay = !showOverlay;
          });
        },
        child: Stack(
          children: [
            bytes != null ? Padding(
              padding: EdgeInsets.only(bottom: widget.showInteractions ? 60.0 : 0),
              child: PhotoView(
                gaplessPlayback: true,
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.contained * 10,
                controller: controller,
                imageProvider: MemoryImage(bytes!),
                loadingBuilder: (BuildContext context, ImageChunkEvent? ev) {
                  return Center(child: buildProgressIndicator(context));
                },
                scaleStateChangedCallback: (scale) {
                  if (scale == PhotoViewScaleState.zoomedIn
                      || scale == PhotoViewScaleState.covering
                      || scale == PhotoViewScaleState.originalSize) {
                    widget.updatePhysics(const NeverScrollableScrollPhysics());
                  } else {
                    widget.updatePhysics(ThemeSwitcher.getScrollPhysics());
                  }
                },
                errorBuilder: (context, object, stacktrace) => Center(
                  child: Text("Failed to display image", style: context.theme.textTheme.bodyLarge)
                ),
              ),
            ) : hasError ? Center(
                child: Text("Failed to load image", style: context.theme.textTheme.bodyLarge)
            ) : Center(child: Padding(
              padding: EdgeInsets.only(bottom: widget.showInteractions ? 60.0 : 0),
              child: buildProgressIndicator(context),
            )),
            if (!iOS) AnimatedOpacity(
              opacity: showOverlay ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 125),
              child: Container(
                height: kIsDesktop ? 50 : 100.0,
                width: ns.width(context),
                color: context.theme.colorScheme.shadow.withOpacity(samsung ? 1 : 0.65),
                child: SafeArea(
                  left: false,
                  right: false,
                  bottom: false,
                  child: Container(
                    height: 50,
                    child: Row(
                      mainAxisAlignment: kIsDesktop ? MainAxisAlignment.end : MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 5),
                              child: CupertinoButton(
                                padding: const EdgeInsets.symmetric(horizontal: 5),
                                onPressed: () async {
                                  Navigator.pop(context);
                                },
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (widget.showInteractions)
                              Padding(
                                padding: const EdgeInsets.only(left: 5.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (message?.isFromMe ?? false) ? "You" : message?.handle?.displayName ?? "Unknown",
                                      style: context.theme.textTheme.titleLarge!.copyWith(color: Colors.white)
                                    ),
                                    if (message?.dateCreated != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2.0),
                                        child: Text(
                                          samsung
                                            ? intl.DateFormat.jm().add_MMMd().format(message!.dateCreated!)
                                            : intl.DateFormat('EEE').add_jm().format(message!.dateCreated!),
                                          style: context.theme.textTheme.bodyLarge!.copyWith(color: samsung ? Colors.grey : Colors.white)
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        !widget.showInteractions ? const SizedBox.shrink() : Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 10.0),
                              child: CupertinoButton(
                                padding: const EdgeInsets.symmetric(horizontal: 5),
                                onPressed: () async {
                                  showMetadataDialog();
                                },
                                child: const Icon(
                                  Icons.info_outlined,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 10.0),
                              child: CupertinoButton(
                                padding: const EdgeInsets.symmetric(horizontal: 5),
                                onPressed: () async {
                                  refreshAttachment();
                                },
                                child: const Icon(
                                  Icons.refresh,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ]
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
