import 'package:bluebubbles/models/models.dart' hide Entity;
import 'package:bluebubbles/utils/logger.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_ml_kit/google_ml_kit.dart' hide Message;
import 'package:maps_launcher/maps_launcher.dart';
import 'package:tuple/tuple.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

class MentionEntity extends Entity {
  /// Constructor to create an instance of [AddressEntity].
  MentionEntity(String rawValue)
      : super(rawValue: rawValue, type: EntityType.unknown);
}

List<InlineSpan> buildMessageSpans(BuildContext context, MessagePart part, Message message, {Color? colorOverride}) {
  final textSpans = <InlineSpan>[];
  final textStyle = (context.theme.extensions[BubbleText] as BubbleText).bubbleText.apply(
    color: colorOverride ?? (message.isFromMe! ? context.theme.colorScheme.onPrimary : context.theme.colorScheme.properOnSurface),
  );

  if (!isNullOrEmpty(part.subject)!) {
    textSpans.addAll(MessageHelper.buildEmojiText(
      "${part.subject}\n",
      textStyle.apply(fontWeightDelta: 2),
    ));
  }
  if (part.mentions.isNotEmpty) {
    part.mentions.forEachIndexed((i, e) {
      final range = part.mentions[i].range;
      textSpans.addAll(MessageHelper.buildEmojiText(
        part.text!.substring(i == 0 ? 0 : part.mentions[i - 1].range.last, range.first),
        textStyle,
      ));
      textSpans.addAll(MessageHelper.buildEmojiText(
          part.text!.substring(range.first, range.last),
          textStyle.apply(fontWeightDelta: 2, color: message.isFromMe! ? null : context.theme.colorScheme.bubble(context, true)),
          recognizer: TapGestureRecognizer()..onTap = () async {
            if (kIsDesktop || kIsWeb) return;
            final handle = cm.activeChat!.chat.participants.firstWhereOrNull((e) => e.address == part.mentions[i].mentionedAddress);
            if (handle?.contact == null && handle != null) {
              await mcs.invokeMethod("open-contact-form",
                  {'address': handle.address, 'addressType': handle.address.isEmail ? 'email' : 'phone'});
            } else if (handle?.contact != null) {
              await mcs.invokeMethod("view-contact-form", {'id': handle!.contact!.id});
            }
          }
      ));
      if (i == part.mentions.length - 1) {
        textSpans.addAll(MessageHelper.buildEmojiText(
          part.text!.substring(range.last),
          textStyle,
        ));
      }
    });
  } else {
    textSpans.addAll(MessageHelper.buildEmojiText(
      part.text!,
      textStyle,
    ));
  }

  return textSpans;
}

Future<List<InlineSpan>> buildEnrichedMessageSpans(BuildContext context, MessagePart part, Message message, {Color? colorOverride}) async {
  final textSpans = <InlineSpan>[];
  final textStyle = (context.theme.extensions[BubbleText] as BubbleText).bubbleText.apply(
    color: colorOverride ?? (message.isFromMe! ? context.theme.colorScheme.onPrimary : context.theme.colorScheme.properOnSurface),
  );
  // extract rich content
  final urlRegex = RegExp(r'((https?://)|(www\.))[-a-zA-Z0-9@:%._+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}([-a-zA-Z0-9/()@:%_.~#?&=*\[\]]*)\b');
  final linkIndexMatches = <Tuple2<String, List<int>>>[];
  final controller = cvc(message.chat.target!);
  if (!kIsWeb && !kIsDesktop) {
    if (controller.mlKitParsedText["${message.guid!}-${part.part}"] == null) {
      try {
        controller.mlKitParsedText["${message.guid!}-${part.part}"] = await GoogleMlKit.nlp.entityExtractor(EntityExtractorLanguage.english)
            .annotateText(part.text!);
      } catch (ex) {
        Logger.warn('Failed to extract entities using mlkit! Error: ${ex.toString()}');
      }
    }
    final entities = controller.mlKitParsedText["${message.guid!}-${part.part}"] ?? [];
    entities.insertAll(0, part.mentions.map((e) => EntityAnnotation(
      start: e.range.first,
      end: e.range.last,
      text: message.text!.substring(e.range.first, e.range.last),
      entities: [
        MentionEntity(e.mentionedAddress ?? ""),
      ]
    )));
    List<EntityAnnotation> normalizedEntities = [];
    if (entities.isNotEmpty) {
      for (int i = 0; i < entities.length; i++) {
        if (i == 0 || entities[i].start > normalizedEntities.last.end) {
          normalizedEntities.add(entities[i]);
        }
      }
    }
    for (EntityAnnotation element in normalizedEntities) {
      if (element.entities.first is AddressEntity) {
        linkIndexMatches.add(Tuple2("map", [element.start, element.end]));
      } else if (element.entities.first is PhoneEntity) {
        linkIndexMatches.add(Tuple2("phone", [element.start, element.end]));
      } else if (element.entities.first is EmailEntity) {
        linkIndexMatches.add(Tuple2("email", [element.start, element.end]));
      } else if (element.entities.first is UrlEntity) {
        linkIndexMatches.add(Tuple2("link", [element.start, element.end]));
      } else if (element.entities.first is MentionEntity) {
        linkIndexMatches.add(Tuple2("mention-${element.entities.first.rawValue}", [element.start, element.end]));
      }
    }
  } else {
    List<RegExpMatch> matches = urlRegex.allMatches(part.text!).toList();
    for (RegExpMatch match in matches) {
      linkIndexMatches.add(Tuple2("link", [match.start, match.end]));
    }
  }
  // render subject
  if (!isNullOrEmpty(part.subject)!) {
    textSpans.addAll(MessageHelper.buildEmojiText(
      "${part.subject}\n",
      textStyle.apply(fontWeightDelta: 2),
    ));
  }
  // render rich content if needed
  if (linkIndexMatches.isNotEmpty) {
    linkIndexMatches.forEachIndexed((i, e) {
      final type = linkIndexMatches[i].item1;
      final range = linkIndexMatches[i].item2;
      final text = part.text!.substring(range.first, range.last);
      textSpans.addAll(MessageHelper.buildEmojiText(
        part.text!.substring(i == 0 ? 0 : linkIndexMatches[i - 1].item2.last, range.first),
        textStyle,
      ));
      if (type.contains("mention")) {
        final mention = type.split("-").last;
        textSpans.addAll(MessageHelper.buildEmojiText(
          text,
          textStyle.apply(fontWeightDelta: 2, color: message.isFromMe! ? null : context.theme.colorScheme.bubble(context, true)),
          recognizer: TapGestureRecognizer()..onTap = () async {
            if (kIsDesktop || kIsWeb) return;
            final handle = cm.activeChat!.chat.participants.firstWhereOrNull((e) => e.address == mention);
            if (handle?.contact == null && handle != null) {
              await mcs.invokeMethod("open-contact-form",
                  {'address': handle.address, 'addressType': handle.address.isEmail ? 'email' : 'phone'});
            } else if (handle?.contact != null) {
              await mcs.invokeMethod("view-contact-form", {'id': handle!.contact!.id});
            }
          }
        ));
      } else if (urlRegex.hasMatch(text) || type == "map" || text.isPhoneNumber || text.isEmail) {
        textSpans.add(
          TextSpan(
            text: text,
            recognizer: TapGestureRecognizer()
              ..onTap = () async {
                if (type == "link") {
                  String url = text;
                  if (!url.startsWith("http://") && !url.startsWith("https://")) {
                    url = "http://$url";
                  }

                  await launchUrlString(url);
                } else if (type == "map") {
                  await MapsLauncher.launchQuery(text);
                } else if (type == "phone") {
                  await launchUrl(Uri(scheme: "tel", path: text));
                } else if (type == "email") {
                  await launchUrl(Uri(scheme: "mailto", path: text));
                }
              },
            style: textStyle.apply(decoration: TextDecoration.underline),
          ),
        );
      } else {
        textSpans.addAll(MessageHelper.buildEmojiText(
          text,
          textStyle,
        ));
      }
      if (i == linkIndexMatches.length - 1) {
        textSpans.addAll(MessageHelper.buildEmojiText(
          part.text!.substring(range.last),
          textStyle,
        ));
      }
    });
  } else {
    textSpans.addAll(MessageHelper.buildEmojiText(
      part.text!,
      textStyle,
    ));
  }

  return textSpans;
}