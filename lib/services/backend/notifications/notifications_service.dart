import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:bluebubbles/app/layouts/conversation_view/pages/conversation_view.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' hide Message;
import 'package:get/get.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:path/path.dart';
import 'package:quick_notify/quick_notify.dart';
import 'package:timezone/timezone.dart';
import 'package:universal_html/html.dart' hide File, Platform;
import 'package:universal_io/io.dart';
import 'package:window_manager/window_manager.dart';

NotificationsService notif = Get.isRegistered<NotificationsService>() ? Get.find<NotificationsService>() : Get.put(NotificationsService());

class NotificationsService extends GetxService {
  static const String NEW_MESSAGE_CHANNEL = "com.bluebubbles.new_messages";
  static const String SOCKET_ERROR_CHANNEL = "com.bluebubbles.socket_error";
  static const String REMINDER_CHANNEL = "com.bluebubbles.reminders";

  final FlutterLocalNotificationsPlugin flnp = FlutterLocalNotificationsPlugin();
  StreamSubscription? countSub;
  int currentCount = 0;

  /// For desktop use only
  static LocalNotification? allToast;
  static List<String> pushedNotifications = [];
  static Map<String, List<LocalNotification>> notifications = {};
  static Map<String, int> notificationCounts = {};

  /// If more than [maxChatCount] chats have notifications, all notifications will be grouped into one
  static const maxChatCount = 2;
  static const maxLines = 4;

  bool get hideContent => ss.settings.hideTextPreviews.value;

  Future<void> init() async {
    if (!kIsWeb && !kIsDesktop) {
      const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('ic_stat_icon');
      const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
      await flnp.initialize(initializationSettings);
      // create notif channels
      createNotificationChannel(
        NEW_MESSAGE_CHANNEL,
        "New Messages",
        "Displays all received new messages",
      );
      createNotificationChannel(
        SOCKET_ERROR_CHANNEL,
        "Socket Connection Error",
        "Displays connection failures",
      );
      createNotificationChannel(
        REMINDER_CHANNEL,
        "Message Reminders",
        "Displays message reminders set through the app",
      );
    }

    // watch for new messages and handle the notification
    if (!kIsWeb) {
      final countQuery = (messageBox.query()..order(Message_.id, flags: Order.descending)).watch(triggerImmediately: true);
      countSub = countQuery.listen((event) {
        if (!ss.settings.finishedSetup.value) return;
        final newCount = event.count();
        final activeChatFetching = cm.activeChat != null ? ms(cm.activeChat!.chat.guid).isFetching : false;
        if (ls.isAlive && !activeChatFetching && newCount > currentCount && currentCount != 0) {
          event.limit = newCount - currentCount;
          final messages = event.find();
          event.limit = 0;
          for (Message message in messages) {
            if (message.chat.target == null) continue;
            message.handle = Handle.findOne(id: message.handleId);
            message.attachments = List<Attachment>.from(message.dbAttachments);
            MessageHelper.handleNotification(message, message.chat.target!, findExisting: false);
          }
        }
        currentCount = newCount;
      });
    }
  }

  @override
  void onClose() {
    countSub?.cancel();
    super.onClose();
  }

  Future<void> createNotificationChannel(String channelID, String channelName, String channelDescription) async {
    await mcs.invokeMethod("create-notif-channel", {
      "channel_name": channelName,
      "channel_description": channelDescription,
      "CHANNEL_ID": channelID,
    });
  }

  Future<void> createReminder(Chat chat, Message message, DateTime time) async {
    await flnp.zonedSchedule(
      Random().nextInt(9998) + 1,
      'Reminder: ${chat.getTitle()}',
      hideContent ? "iMessage" : MessageHelper.getNotificationText(message),
      TZDateTime.from(time, local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          REMINDER_CHANNEL,
          'Reminders',
          channelDescription: 'Message reminder notifications',
          priority: Priority.max,
          importance: Importance.max,
          color: HexColor("4990de"),
        ),
      ),
      payload: MessageHelper.getNotificationText(message),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> createNotification(Chat chat, Message message) async {
    if (chat.shouldMuteNotification(message) || message.isFromMe! || pushedNotifications.contains(message.guid!)) return;
    pushedNotifications.add(message.guid!);
    final isGroup = chat.isGroup;
    final guid = chat.guid;
    final contactName = message.handle?.displayName ?? "Unknown";
    final title = chat.getTitle();
    final text = hideContent ? "iMessage" : MessageHelper.getNotificationText(message);
    final isReaction = !isNullOrEmpty(message.associatedMessageGuid)!;
    final personIcon = (await loadAsset("assets/images/person64.png")).buffer.asUint8List();

    Uint8List chatIcon = await avatarAsBytes(isGroup: isGroup, participants: chat.participants, chatGuid: guid, quality: 256);
    Uint8List contactIcon = message.isFromMe!
        ? personIcon
        : await avatarAsBytes(isGroup: false, participants: chat.participants.where((e) => e.address == message.handle!.address).toList(), chatGuid: guid, quality: 256);
    if (chatIcon.isEmpty) {
      chatIcon = personIcon;
    }
    if (contactIcon.isEmpty) {
      contactIcon = personIcon;
    }

    if (kIsWeb && Notification.permission == "granted") {
      final notif = Notification(title, body: text, icon: "data:image/png;base64,${base64Encode(chatIcon)}", tag: message.guid);
      notif.onClick.listen((event) async {
        await intents.openChat(guid);
      });
    } else if (kIsDesktop) {
      if (Platform.isWindows) {
        List<int> selectedIndices = ss.settings.selectedActionIndices;
        List<String> _actions = ss.settings.actionList;
        final papi = ss.settings.enablePrivateAPI.value;

        List<String> actions = _actions
            .whereIndexed((i, e) => selectedIndices.contains(i))
            .map((action) => action == "Mark Read"
                ? action
                : !isReaction && !message.isGroupEvent && papi
                    ? ReactionTypes.reactionToEmoji[action]!
                    : null)
            .whereNotNull()
            .toList();

        bool showMarkRead = actions.contains("Mark Read");

        List<LocalNotificationAction> nActions = actions.map((String a) => LocalNotificationAction(text: a)).toList();

        LocalNotification? toast;

        notifications.removeWhere((key, value) => value.isEmpty);
        notifications[guid] ??= [];
        notificationCounts[guid] = (notificationCounts[guid] ?? 0) + 1;

        List<LocalNotification> _notifications = List.from(notifications[guid]!);

        Iterable<String> _chats = notifications.keys;

        if (_chats.length > maxChatCount) {
          for (String chat in _chats) {
            for (LocalNotification _toast in notifications[chat]!) {
              await _toast.close();
            }
            notifications[chat] = [];
          }

          await allToast?.close();

          String title = "${notificationCounts.values.sum} messages";
          String body = "from ${_chats.length} chats";

          // Don't create notification for no reason
          if (allToast?.title == title && allToast?.body == body) return;

          allToast = LocalNotification(
            title: "${notificationCounts.values.sum} messages",
            body: "from ${_chats.length} chats",
            actions: showMarkRead ? [LocalNotificationAction(text: "Mark All Read")] : [],
          );

          allToast!.onClick = () async {
            notifications = {};
            notificationCounts = {};
            await WindowManager.instance.focus();
          };

          allToast!.onClickAction = (index) async {
            notifications = {};
            notificationCounts = {};

            chats.markAllAsRead();
          };

          allToast!.onClose = (reason) {
            if (reason != LocalNotificationCloseReason.unknown) {
              notifications = {};
              notificationCounts = {};
            }
          };

          await allToast!.show();

          return;
        }

        Uint8List avatar = await avatarAsBytes(isGroup: isGroup, participants: chat.participants, chatGuid: guid, quality: 256);

        // Create a temp file with the avatar
        String path = join(fs.appDocDir.path, "temp", "${randomString(8)}.png");
        await File(path).create(recursive: true);
        await File(path).writeAsBytes(avatar);

        const int charsPerLineEst = 30;

        bool combine = false;
        bool multiple = false;
        String? sender;
        RegExp re = RegExp("\n");
        if (isGroup && !message.isGroupEvent && !isReaction) {
          Contact? contact = message.handle != null ? cs.getContact(message.handle!.address) : null;
          sender = contact?.displayName.split(" ")[0];
        }
        int newLines = (((sender == null ? 0 : "$sender: ".length) + text.length) / charsPerLineEst).ceil() + re.allMatches(text).length;
        String body = "";
        int count = 0;
        for (LocalNotification _toast in _notifications) {
          if (newLines + ((_toast.body ?? "").length ~/ charsPerLineEst).ceil() + re.allMatches("${_toast.body}\n").length <= maxLines) {
            if (isGroup && count == 0 && _notifications.isNotEmpty && _toast.title.length > "$title: ".length) {
              String name = _toast.title.substring("$title: ".length).split(" ")[0];
              body += "$name: ";
            }
            body += "${_toast.body}\n";
            count += int.tryParse(_toast.subtitle ?? "1") ?? 1;
            multiple = true;
          } else {
            combine = true;
          }
        }
        if (isGroup && sender != null) {
          body += "$sender: ";
        }
        body += text;
        count += 1;

        if (!combine && (notificationCounts[guid]! == count)) {
          bool toasted = false;
          for (LocalNotification _toast in _notifications) {
            if (_toast.body != body) {
              await _toast.close();
            } else {
              toasted = true;
            }
          }
          if (toasted) return;
          toast = LocalNotification(
            imagePath: path,
            title: isGroup && count == 1 && !isReaction && !message.isGroupEvent ? "$title: $contactName" : title,
            subtitle: "$count",
            body: sender != null && count == 1 ? body.split("$sender: ")[1] : body,
            actions: _notifications.isNotEmpty
                ? showMarkRead
                    ? [LocalNotificationAction(text: "Mark ${notificationCounts[guid]!} Messages Read")]
                    : []
                : nActions,
          );
          notifications[guid]!.add(toast);

          toast.onClick = () async {
            notifications[guid]!.remove(toast);
            notificationCounts[guid] = 0;

            Chat? chat = Chat.findOne(guid: guid);
            if (chat == null) return;

            await WindowManager.instance.focus();

            if (ChatManager().activeChat?.chat.guid != guid && Get.context != null) {
              ns.pushAndRemoveUntil(
                Get.context!,
                ConversationView(chat: chat),
                (route) => route.isFirst,
              );
            }
          };

          toast.onClickAction = (index) async {
            notifications[guid]!.remove(toast);
            notificationCounts[guid] = 0;

            Chat? chat = Chat.findOne(guid: guid);
            if (chat == null) return;
            if (actions[index] == "Mark Read" || multiple) {
              chat.toggleHasUnread(false);
              EventDispatcher().emit('refresh', null);
            } else if (ss.settings.enablePrivateAPI.value) {
              String reaction = ReactionTypes.emojiToReaction[actions[index]]!;
              outq.queue(
                OutgoingItem(
                  type: QueueType.sendMessage,
                  chat: chat,
                  message: Message(
                    associatedMessageGuid: message.guid,
                    associatedMessageType: reaction,
                    associatedMessagePart: 0,
                    dateCreated: DateTime.now(),
                    hasAttachments: false,
                    isFromMe: true,
                    handleId: 0,
                  ),
                  selected: message,
                  reaction: reaction,
                ),
              );
            }

            if (await File(path).exists()) {
              await File(path).delete();
            }
          };

          toast.onClose = (reason) async {
            notifications[guid]!.remove(toast);
            if (reason != LocalNotificationCloseReason.unknown) {
              notificationCounts[guid] = 0;
            }
            if (await File(path).exists()) {
              await File(path).delete();
            }
          };
        } else {
          String body = "${notificationCounts[guid]!} messages";
          bool toasted = false;
          for (LocalNotification _toast in _notifications) {
            if (_toast.body != body) {
              await _toast.close();
            } else {
              toasted = true;
            }
          }
          if (toasted) return;

          notifications[guid] = [];
          toast = LocalNotification(
            imagePath: path,
            title: title,
            body: "${notificationCounts[guid]!} messages",
            actions: showMarkRead ? [LocalNotificationAction(text: "Mark Read")] : [],
          );
          notifications[guid]!.add(toast);

          toast.onClick = () async {
            notifications[guid]!.remove(toast);
            notificationCounts[guid] = 0;

            // Show window and open the right chat
            Chat? chat = Chat.findOne(guid: guid);
            if (chat == null) return;

            await WindowManager.instance.focus();

            if (ChatManager().activeChat?.chat.guid != guid && Get.context != null) {
              ns.pushAndRemoveUntil(
                Get.context!,
                ConversationView(chat: chat),
                (route) => route.isFirst,
              );
            }

            if (await File(path).exists()) {
              await File(path).delete();
            }
          };

          toast.onClickAction = (index) async {
            notifications[guid]!.remove(toast);
            notificationCounts[guid] = 0;

            Chat? chat = Chat.findOne(guid: guid);
            if (chat == null) return;

            chat.toggleHasUnread(false);
            EventDispatcher().emit('refresh', null);

            await WindowManager.instance.focus();

            if (await File(path).exists()) {
              await File(path).delete();
            }
          };

          toast.onClose = (reason) async {
            notifications[guid]!.remove(toast);
            if (reason != LocalNotificationCloseReason.unknown) {
              notificationCounts[guid] = 0;
            }
            if (await File(path).exists()) {
              await File(path).delete();
            }
          };
        }

        await toast.show();
      } else {
        QuickNotify.notify(title: title, content: text);
      }
    } else {
      await mcs.invokeMethod("new-message-notification", {
        "CHANNEL_ID": NEW_MESSAGE_CHANNEL,
        "CHANNEL_NAME": "New Messages",
        "notificationId": Random().nextInt(9998) + 1,
        "summaryId": chat.id,
        "chatGuid": guid,
        "chatIsGroup": isGroup,
        "chatTitle": title,
        "chatIcon": isGroup ? chatIcon : contactIcon,
        "contactName": contactName,
        "contactAvatar": contactIcon,
        "messageGuid": message.guid!,
        "messageText": text,
        "messageDate": message.dateCreated!.millisecondsSinceEpoch,
        "messageIsFromMe": false,
      });
    }
  }

  Future<void> createSocketError() async {
    await mcs.invokeMethod("create-socket-issue-warning", {
      "CHANNEL_ID": SOCKET_ERROR_CHANNEL,
    });
  }

  Future<void> createFailedToSend() async {
    await mcs.invokeMethod("message-failed-to-send", {
      "CHANNEL_ID": SOCKET_ERROR_CHANNEL,
    });
  }

  Future<void> clearSocketError() async {
    await mcs.invokeMethod("clear-socket-issue");
  }

  Future<void> clearFailedToSend() async {
    await mcs.invokeMethod("clear-failed-to-send");
  }

  Future<void> clearDesktopNotificationsForChat(String chatGuid) async {
    if (!notifications.containsKey(chatGuid)) return;
    List<LocalNotification> toasts = notifications[chatGuid]!;
    for (LocalNotification toast in toasts) {
      await toast.close();
    }
    notifications[chatGuid] = [];
    notificationCounts[chatGuid] = 0;
  }
}
