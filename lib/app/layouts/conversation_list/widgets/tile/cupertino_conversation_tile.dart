import 'dart:async';

import 'package:bluebubbles/helpers/models/constants.dart';
import 'package:bluebubbles/helpers/models/extensions.dart';
import 'package:bluebubbles/helpers/ui/theme_helpers.dart';
import 'package:bluebubbles/helpers/message_marker.dart';
import 'package:bluebubbles/utils/general_utils.dart';
import 'package:bluebubbles/app/layouts/conversation_list/dialogs/conversation_peek_view.dart';
import 'package:bluebubbles/app/layouts/conversation_list/widgets/tile/conversation_tile.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/core/managers/chat/chat_manager.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CupertinoConversationTile extends CustomStateful<ConversationTileController> {
  const CupertinoConversationTile({Key? key, required super.parentController});

  @override
  State<StatefulWidget> createState() => _CupertinoConversationTileState();
}

class _CupertinoConversationTileState extends CustomState<CupertinoConversationTile, void, ConversationTileController> {
  Offset? longPressPosition;

  @override
  void initState() {
    super.initState();
    tag = controller.chat.guid;
    // keep controller in memory since the widget is part of a list
    // (it will be disposed when scrolled out of view)
    forceDelete = false;
  }

  @override
  Widget build(BuildContext context) {
    final child = GestureDetector(
      onSecondaryTapUp: (details) => controller.onSecondaryTap(context, details),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          mouseCursor: MouseCursor.defer,
          onTap: () => controller.onTap(context),
          onLongPress: kIsDesktop || kIsWeb ? null : () async {
            await peekChat(context, controller.chat, longPressPosition ?? Offset.zero);
          },
          onTapDown: (details) {
            longPressPosition = details.globalPosition;
          },
          child: Obx(() => ListTile(
            mouseCursor: MouseCursor.defer,
            enableFeedback: true,
            dense: ss.settings.denseChatTiles.value,
            contentPadding: const EdgeInsets.only(left: 0),
            minVerticalPadding: 10,
            horizontalTitleGap: 10,
            title: ChatTitle(
              parentController: controller,
              style: context.theme.textTheme.bodyLarge!.copyWith(
                  fontWeight: controller.shouldHighlight.value
                      ? FontWeight.w600
                      : FontWeight.w500,
                  color: controller.shouldHighlight.value
                      ? context.theme.colorScheme.onBubble(context, controller.chat.isIMessage)
                      : null
              ),
            ),
            subtitle: controller.subtitle ?? ChatSubtitle(
              parentController: controller,
              style: context.theme.textTheme.bodySmall!.copyWith(
                color: controller.shouldHighlight.value
                    ? context.theme.colorScheme.onBubble(context, controller.chat.isIMessage).withOpacity(0.85)
                    : context.theme.colorScheme.outline,
                height: 1.5,
              ),
            ),
            leading: ChatLeading(
              controller: controller,
              unreadIcon: UnreadIcon(parentController: controller),
            ),
            trailing: CupertinoTrailing(parentController: controller),
          )),
        ),
      ),
    );

    return kIsDesktop || kIsWeb ? Obx(() => AnimatedContainer(
      duration: Duration(milliseconds: 100),
      decoration: BoxDecoration(
        color: controller.shouldPartialHighlight.value
            ? context.theme.colorScheme.properSurface.lightenOrDarken(10)
            : controller.shouldHighlight.value
            ? context.theme.colorScheme.bubble(context, controller.chat.isIMessage)
            : controller.hoverHighlight.value
            ? context.theme.colorScheme.properSurface
            : null,
        borderRadius: BorderRadius.circular(
            controller.shouldHighlight.value
                || controller.shouldPartialHighlight.value
                || controller.hoverHighlight.value
                ? 8 : 0
        ),
      ),
      child: child,
    )) : child;
  }
}

class CupertinoTrailing extends CustomStateful<ConversationTileController> {
  const CupertinoTrailing({Key? key, required super.parentController});

  @override
  State<StatefulWidget> createState() => _CupertinoTrailingState();
}

class _CupertinoTrailingState extends CustomState<CupertinoTrailing, void, ConversationTileController> {
  late final MessageMarkers? markers = ChatManager().getChatController(controller.chat)?.messageMarkers;

  DateTime? dateCreated;
  late final StreamSubscription<Query<Message>> sub;
  String? cachedLatestMessageGuid = "";
  Message? cachedLatestMessage;

  @override
  void initState() {
    super.initState();
    tag = controller.chat.guid;
    // keep controller in memory since the widget is part of a list
    // (it will be disposed when scrolled out of view)
    forceDelete = false;
    cachedLatestMessage = controller.chat.latestMessageGetter != null
        ? controller.chat.latestMessageGetter!
        : controller.chat.latestMessage;
    cachedLatestMessageGuid = cachedLatestMessage?.guid;
    dateCreated = cachedLatestMessage?.dateCreated;
    // run query after render has completed
    updateObx(() {
      final latestMessageQuery = (messageBox.query(Message_.dateDeleted.isNull())
        ..link(Message_.chat, Chat_.guid.equals(controller.chat.guid))
        ..order(Message_.dateCreated, flags: Order.descending))
          .watch();

      sub = latestMessageQuery.listen((Query<Message> query) {
        final message = query.findFirst();
        cachedLatestMessage = message;
        // check if we really need to update this widget
        if (message?.guid != cachedLatestMessageGuid) {
          DateTime newDateCreated = controller.chat.latestMessageDate ?? DateTime.now();
          if (message != null) {
            newDateCreated = message.dateCreated ?? newDateCreated;
          }
          if (dateCreated != newDateCreated) {
            setState(() {
              dateCreated = newDateCreated;
            });
          }
        }
        cachedLatestMessageGuid = message?.guid;
      });
    });
  }

  @override
  void dispose() {
    sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 15, top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Obx(() {
            String indicatorText = "";
            if (ss.settings.statusIndicatorsOnChats.value && markers != null) {
              Indicator show = shouldShow(
                  cachedLatestMessage,
                  markers!.myLastMessage.value,
                  markers!.lastReadMessage.value,
                  markers!.lastDeliveredMessage.value
              );
              indicatorText = describeEnum(show).toLowerCase().capitalizeFirst!;
            }

            return Text(
              (cachedLatestMessage?.error ?? 0) > 0
                  ? "Error"
                  : "${indicatorText.isNotEmpty ? "$indicatorText\n" : ""}${buildDate(dateCreated)}",
              textAlign: TextAlign.right,
              style: context.theme.textTheme.bodySmall!.copyWith(
                color: (cachedLatestMessage?.error ?? 0) > 0
                    ? context.theme.colorScheme.error
                    : context.theme.colorScheme.outline,
                fontWeight: controller.shouldHighlight.value
                    ? FontWeight.w500 : null,
              ).apply(fontSizeFactor: 1.1),
              overflow: TextOverflow.clip,
            );
          }),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.forward,
                color: controller.shouldHighlight.value
                    ? context.theme.colorScheme.onBubble(context, controller.chat.isIMessage)
                    : context.theme.colorScheme.outline,
                size: 15,
              ),
              if (controller.chat.muteType == "mute")
                Padding(
                  padding: const EdgeInsets.only(top: 5.0),
                  child: Icon(
                    CupertinoIcons.bell_slash_fill,
                    color: controller.shouldHighlight.value
                        ? context.theme.colorScheme.onBubble(context, controller.chat.isIMessage)
                        : context.theme.colorScheme.outline,
                    size: 12,
                  )
              )
            ],
          ),
        ],
      ),
    );
  }
}

class UnreadIcon extends CustomStateful<ConversationTileController> {
  const UnreadIcon({Key? key, required super.parentController});

  @override
  State<StatefulWidget> createState() => _UnreadIconState();
}

class _UnreadIconState extends CustomState<UnreadIcon, void, ConversationTileController> {
  bool unread = false;
  late final StreamSubscription<Query<Chat>> sub;

  @override
  void initState() {
    super.initState();
    tag = controller.chat.guid;
    // keep controller in memory since the widget is part of a list
    // (it will be disposed when scrolled out of view)
    forceDelete = false;
    unread = controller.chat.hasUnreadMessage ?? false;
    updateObx(() {
      final unreadQuery = chatBox.query(Chat_.guid.equals(controller.chat.guid))
          .watch();
      sub = unreadQuery.listen((Query<Chat> query) {
        final chat = query.findFirst()!;
        if (chat.hasUnreadMessage != unread) {
          setState(() {
            unread = chat.hasUnreadMessage!;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 5.0, right: 5.0),
      child: unread ? Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(35),
          color: context.theme.colorScheme.primary,
        ),
        width: 10,
        height: 10,
      ) : const SizedBox(width: 10),
    );
  }
}
