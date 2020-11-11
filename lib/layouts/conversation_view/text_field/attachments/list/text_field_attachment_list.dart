import 'dart:io';
import 'dart:typed_data';

import 'package:bluebubbles/layouts/conversation_view/text_field/attachments/list/attachment_list_item.dart';
import 'package:bluebubbles/layouts/widgets/scroll_physics/custom_bouncing_scroll_physics.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class TextFieldAttachmentList extends StatefulWidget {
  TextFieldAttachmentList({Key key, this.attachments, this.onRemove})
      : super(key: key);
  final List<File> attachments;
  final Function(File) onRemove;

  @override
  _TextFieldAttachmentListState createState() =>
      _TextFieldAttachmentListState();
}

class _TextFieldAttachmentListState extends State<TextFieldAttachmentList>
    with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      vsync: this,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: widget.attachments.length > 0 ? 100 : 0,
        ),
        child: GridView.builder(
          itemCount: widget.attachments.length,
          scrollDirection: Axis.horizontal,
          physics: AlwaysScrollableScrollPhysics(
            parent: CustomBouncingScrollPhysics(),
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 1,
          ),
          itemBuilder: (context, int index) {
            return AttachmentListItem(
              key: Key("attachmentList" + widget.attachments[index].path),
              file: widget.attachments[index],
              onRemove: () {
                widget.onRemove(widget.attachments[index]);
              },
            );
          },
        ),
      ),
    );
  }
}
