import 'dart:async';

import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/settings/theme_helpers_mixin.dart';
import 'package:bluebubbles/helpers/ui_helpers.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/conversation_list/pages/conversation_list.dart';
import 'package:bluebubbles/layouts/conversation_list/widgets/header/header_widgets.dart';
import 'package:bluebubbles/layouts/search/search_view.dart';
import 'package:bluebubbles/layouts/stateful_boilerplate.dart';
import 'package:bluebubbles/main.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/models.dart';
import 'package:bluebubbles/repository/models/objectbox.dart';
import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:get/get.dart';

class SamsungHeader extends CustomStateful<ConversationListController> {
  const SamsungHeader({Key? key, required super.parentController});

  @override
  State<StatefulWidget> createState() => _SamsungHeaderState();
}

class _SamsungHeaderState extends CustomState<SamsungHeader, void, ConversationListController> with ThemeHelpers {
  Color get backgroundColor => SettingsManager().settings.windowEffect.value == WindowEffect.disabled
      ? headerColor
      : Colors.transparent;
  bool get showArchived => controller.showArchivedChats;
  bool get showUnknown => controller.showUnknownSenders;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      backgroundColor: backgroundColor,
      shadowColor: Colors.black,
      pinned: true,
      stretch: true,
      expandedHeight: context.height / 3,
      toolbarHeight: kToolbarHeight + (kIsDesktop ? 20 : 0),
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final double expandRatio = ((constraints.maxHeight - (kToolbarHeight + (kIsDesktop ? 20 : 0))) / (context.height / 3 - (kToolbarHeight + (kIsDesktop ? 20 : 0)))).clamp(0, 1);
          final animation = AlwaysStoppedAnimation(expandRatio);

          return Stack(
            fit: StackFit.expand,
            children: [
              FadeTransition(
                opacity: Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
                  parent: animation,
                  curve: Interval(0.3, 1.0, curve: Curves.easeIn),
                )),
                child: Center(child: ExpandedHeaderText(parentController: controller)),
              ),
              FadeTransition(
                opacity: Tween(begin: 1.0, end: 0.0).animate(CurvedAnimation(
                  parent: animation,
                  curve: Interval(0.0, 0.7, curve: Curves.easeOut),
                )),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    padding: EdgeInsets.only(left: showArchived || showUnknown ? 60 : 16),
                    height: (kToolbarHeight + (kIsDesktop ? 20 : 0)),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          HeaderText(controller: controller, fontSize: 20),
                          ConnectionIndicator(),
                          SyncIndicator(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  height: (kToolbarHeight + (kIsDesktop ? 20 : 0)),
                  child: Align(
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (showArchived || showUnknown)
                          IconButton(
                            onPressed: () async {
                              Navigator.of(context).pop();
                            },
                            padding: EdgeInsets.zero,
                            icon: buildBackButton(context)
                          ),
                        if (!showArchived && !showUnknown)
                          const SizedBox.shrink(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            !showArchived && !showUnknown ? IconButton(
                              onPressed: () async {
                                CustomNavigator.pushLeft(
                                  context,
                                  SearchView(),
                                );
                              },
                              icon: Icon(
                                Icons.search,
                                color: context.theme.colorScheme.properOnSurface,
                              ),
                            ) : const SizedBox.shrink(),
                            SettingsManager().settings.moveChatCreatorToHeader.value
                                && !showArchived
                                && !showUnknown ? InkWell(
                              onLongPress: SettingsManager().settings.cameraFAB.value
                                  ? () => controller.openCamera(context) : null,
                              child: IconButton(
                                onPressed: () => controller.openNewChatCreator(context),
                                icon: Icon(
                                  Icons.create_outlined,
                                  color: context.theme.colorScheme.properOnSurface,
                                ),
                              ),
                            ) : const SizedBox.shrink(),
                            if (!showArchived && !showUnknown)
                              const Padding(
                                padding: EdgeInsets.only(right: 8.0),
                                child: SizedBox(
                                  width: 40,
                                  child: OverflowMenu(),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ExpandedHeaderText extends CustomStateful<ConversationListController> {
  const ExpandedHeaderText({Key? key, required super.parentController});

  @override
  State<StatefulWidget> createState() => _ExpandedHeaderTextState();
}

class _ExpandedHeaderTextState extends CustomState<ExpandedHeaderText, void, ConversationListController> {
  int unreadChats = -1;
  late final StreamSubscription<Query<Chat>> sub;

  @override
  void initState() {
    super.initState();
    final unreadQuery = chatBox.query(Chat_.hasUnreadMessage.equals(true))
        .watch(triggerImmediately: true);
    sub = unreadQuery.listen((Query<Chat> query) {
      final count = query.count();
      if (unreadChats == -1) {
        unreadChats = count;
      } else if (unreadChats != count) {
        setState(() {
          unreadChats = count;
        });
      }
    });
  }

  @override
  void dispose() {
    sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
        controller.selectedChats.isNotEmpty
            ? "${controller.selectedChats.length} selected"
            : controller.showArchivedChats
            ? "Archived"
            : controller.showUnknownSenders
            ? "Unknown Senders"
            : unreadChats > 0
            ? "$unreadChats unread message${unreadChats > 1 ? "s" : ""}"
            : "Messages",
        style: context.theme.textTheme.displaySmall!.copyWith(color: context.theme.colorScheme.onBackground)
    );
  }
}