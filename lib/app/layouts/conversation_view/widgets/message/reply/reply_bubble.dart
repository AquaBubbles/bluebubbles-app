import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/attachment/attachment_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/interactive/interactive_holder.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/misc/tail_clipper.dart';
import 'package:bluebubbles/app/layouts/conversation_view/widgets/message/reply/reply_thread_popup.dart';
import 'package:bluebubbles/app/components/avatars/contact_avatar_widget.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ReplyBubble extends CustomStateful<MessageWidgetController> {
  ReplyBubble({
    Key? key,
    required super.parentController,
    required this.part,
    required this.showAvatar,
  }) : super(key: key);

  final int part;
  final bool showAvatar;

  @override
  _ReplyBubbleState createState() => _ReplyBubbleState();
}

class _ReplyBubbleState extends CustomState<ReplyBubble, void, MessageWidgetController> {
  MessagePart get part => controller.parts[widget.part];
  Message get message => controller.message;

  @override
  void initState() {
    forceDelete = false;
    super.initState();
  }

  Color getBubbleColor() {
    Color bubbleColor = context.theme.colorScheme.properSurface;
    if (ss.settings.colorfulBubbles.value && !message.isFromMe!) {
      if (message.handle?.color == null) {
        bubbleColor = toColorGradient(message.handle?.address).first;
      } else {
        bubbleColor = HexColor(message.handle!.color!);
      }
    }
    return bubbleColor;
  }

  @override
  Widget build(BuildContext context) {
    if (!iOS) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: ns.width(context) * MessageWidgetController.maxBubbleSizeFactor - 30,
          minHeight: 30,
        ),
        child: GestureDetector(
          onTap: () {
            showReplyThread(context, message, part, ms(controller.cvController!.chat.guid));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: message.handle?.displayName ?? "You",
                  style: context.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w400, color: context.theme.colorScheme.outline),
                ),
                const TextSpan(text: "\n"),
                TextSpan(
                  text: "${iOS ? " - " : ""}${MessageHelper.getNotificationText(message)}",
                  style: context.textTheme.bodyMedium!.apply(fontSizeFactor: 1.15),
                ),
              ]),
              style: context.textTheme.labelLarge!.copyWith(color: context.theme.colorScheme.onBackground),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Transform.scale(
        scale: 0.8,
        alignment: message.isFromMe! ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onTap: () {
            showReplyThread(context, message, part, ms(controller.cvController!.chat.guid));
          },
          behavior: HitTestBehavior.opaque,
          child: IgnorePointer(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (widget.showAvatar)
                  ContactAvatarWidget(
                    handle: message.handle,
                    size: 30,
                    fontSize: context.theme.textTheme.bodyLarge!.fontSize!,
                    borderThickness: 0.1,
                  ),
                ClipPath(
                  clipper: TailClipper(
                    isFromMe: message.isFromMe!,
                    showTail: true,
                    connectUpper: false,
                    connectLower: false,
                  ),
                  child: controller.parts.length <= widget.part ? Container(
                    constraints: BoxConstraints(
                      maxWidth: ns.width(context) * MessageWidgetController.maxBubbleSizeFactor - 30,
                      minHeight: 30,
                    ),
                    child: CustomPaint(
                      painter: TailPainter(
                        isFromMe: message.isFromMe!,
                        showTail: true,
                        color: context.theme.colorScheme.errorContainer,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15).add(EdgeInsets.only(left: message.isFromMe! ? 0 : 10, right: message.isFromMe! ? 10 : 0)),
                        child: Text(
                          "Failed to parse thread parts!",
                          style: (context.theme.extensions[BubbleText] as BubbleText).bubbleText.apply(
                            color: context.theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ),
                  ) : message.hasApplePayloadData || message.isLegacyUrlPreview || message.isInteractive ? ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 70),
                    child: InteractiveHolder(
                      parentController: controller,
                      message: part,
                    ),
                  ) : part.attachments.isEmpty ? Container(
                    constraints: BoxConstraints(
                      maxWidth: ns.width(context) * MessageWidgetController.maxBubbleSizeFactor - 30,
                      minHeight: 30,
                    ),
                    child: CustomPaint(
                      painter: TailPainter(
                        isFromMe: message.isFromMe!,
                        showTail: true,
                        color: message.isFromMe! ? context.theme.colorScheme.primary : getBubbleColor(),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15).add(EdgeInsets.only(left: message.isFromMe! ? 0 : 10, right: message.isFromMe! ? 10 : 0)),
                        child: FutureBuilder<List<InlineSpan>>(
                          future: buildEnrichedMessageSpans(
                            context,
                            part,
                            message,
                            colorOverride: (message.isFromMe! ? context.theme.colorScheme.primary : getBubbleColor()).lightenOrDarken(30),
                          ),
                          initialData: buildMessageSpans(
                            context,
                            part,
                            message,
                            colorOverride: (message.isFromMe! ? context.theme.colorScheme.primary : getBubbleColor()).lightenOrDarken(30),
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.data != null) {
                              return RichText(
                                text: TextSpan(
                                  children: snapshot.data!,
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          }
                        ),
                      ),
                    ),
                  ) : ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 70),
                    child: AttachmentHolder(
                      parentController: controller,
                      message: part,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
