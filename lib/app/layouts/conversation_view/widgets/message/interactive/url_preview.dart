import 'dart:convert';

import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:html/parser.dart' as parser;
import 'package:metadata_fetch/metadata_fetch.dart';
import 'package:universal_io/io.dart';
import 'package:url_launcher/url_launcher.dart';

class UrlPreview extends StatefulWidget {
  final UrlPreviewData data;
  final Message message;
  final PlatformFile? file;

  UrlPreview({
    Key? key,
    required this.data,
    required this.message,
    this.file,
  }) : super(key: key);

  @override
  OptimizedState createState() => _UrlPreviewState();
}

class _UrlPreviewState extends OptimizedState<UrlPreview> with AutomaticKeepAliveClientMixin {
  UrlPreviewData get data => widget.data;
  UrlPreviewData? dataOverride;
  dynamic get file => File(content.path!);
  dynamic content;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    updateObx(() async {
      if (widget.file != null) {
        String? _location;
        if (kIsWeb || widget.file!.path == null) {
          _location = utf8.decode(widget.file!.bytes!);
        } else {
          _location = await File(widget.file!.path!).readAsString();
        }
        dataOverride = UrlPreviewData(
          title: data.title,
          siteName: data.siteName,
        );
        dataOverride!.url = as.parseAppleLocationUrl(_location)?.replaceAll("\\", "").replaceAll("http:", "https:").replaceAll("/?", "/place?").replaceAll(",", "%2C");
        if (dataOverride!.url == null) return;
        final response = await http.dio.get(dataOverride!.url!);
        final document = parser.parse(response.data);
        final link = document.getElementsByClassName("sc-platter-cell").firstOrNull?.children.firstWhereOrNull((e) => e.localName == "a");
        final url = link?.attributes["href"];
        if (url != null) {
          MetadataFetch.extract(url).then((metadata) {
            if (metadata?.image != null) {
              dataOverride!.imageMetadata = MediaMetadata(size: const Size.square(1), url: metadata!.image);
              dataOverride!.summary = metadata.title;
              dataOverride!.url = url;
              setState(() {});
            }
          });
        }
      } else if (data.imageMetadata?.url == null && data.iconMetadata?.url == null) {
        final attachment = widget.message.attachments
            .firstWhereOrNull((e) => e?.transferName?.contains("pluginPayloadAttachment") ?? false);
        if (attachment != null) {
          content = as.getContent(attachment, autoDownload: true, onComplete: (file) {
            setState(() {
              content = file;
            });
          });
          if (content is PlatformFile) {
            setState(() {});
          }
        } else {
          MetadataFetch.extract((data.url ?? data.originalUrl)!).then((metadata) {
            if (metadata?.image != null) {
              data.imageMetadata = MediaMetadata(size: const Size.square(1), url: metadata!.image);
              widget.message.save();
              setState(() {});
            }
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final siteText = widget.file != null ? (dataOverride?.siteName ?? "") : Uri.tryParse(data.url ?? data.originalUrl ?? "")?.host ?? data.siteName;
    final hasAppleImage = (data.imageMetadata?.url == null || (data.iconMetadata?.url == null && data.imageMetadata?.size == Size.zero));
    final _data = dataOverride ?? data;
    return InkWell(
      onTap: widget.file != null && _data.url != null ? () async {
        await launchUrl(
          Uri.parse(_data.url!),
          mode: LaunchMode.externalApplication
        );
      } : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_data.imageMetadata?.url != null && _data.imageMetadata?.size != Size.zero)
            Image.network(
              _data.imageMetadata!.url!,
              gaplessPlayback: true,
              filterQuality: FilterQuality.none,
              errorBuilder: (_, __, ___) {
                return const SizedBox.shrink();
              },
            ),
          if (content is PlatformFile && hasAppleImage && content.bytes != null)
            Image.memory(
              content.bytes!,
              gaplessPlayback: true,
              filterQuality: FilterQuality.none,
              errorBuilder: (_, __, ___) {
                return const SizedBox.shrink();
              },
            ),
          if (content is PlatformFile && hasAppleImage && content.bytes == null && content.path != null)
            Image.file(
              file,
              gaplessPlayback: true,
              filterQuality: FilterQuality.none,
              errorBuilder: (_, __, ___) {
                return const SizedBox.shrink();
              },
            ),
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _data.title ?? siteText ?? widget.message.text!,
                        style: context.theme.textTheme.bodyMedium!.apply(fontWeightDelta: 2),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!isNullOrEmpty(_data.summary)!)
                        const SizedBox(height: 5),
                      if (!isNullOrEmpty(_data.summary)!)
                        Text(
                          _data.summary ?? "",
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: context.theme.textTheme.labelMedium!.copyWith(fontWeight: FontWeight.normal)
                        ),
                      if (!isNullOrEmpty(siteText)!)
                        const SizedBox(height: 5),
                      if (!isNullOrEmpty(siteText)!)
                        Text(
                          siteText!,
                          style: context.theme.textTheme.labelMedium!.copyWith(fontWeight: FontWeight.normal, color: context.theme.colorScheme.outline),
                          overflow: TextOverflow.clip,
                          maxLines: 1,
                        ),
                    ]
                  ),
                ),
                if (_data.iconMetadata?.url != null && _data.imageMetadata?.size == Size.zero)
                  const SizedBox(width: 10),
                if (_data.iconMetadata?.url != null && _data.imageMetadata?.size == Size.zero)
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 45,
                    ),
                    child: Image.network(
                      _data.iconMetadata!.url!,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.none,
                    ),
                  ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
