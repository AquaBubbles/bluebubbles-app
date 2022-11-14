import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:bluebubbles/app/wrappers/stateful_boilerplate.dart';
import 'package:bluebubbles/helpers/helpers.dart';
import 'package:bluebubbles/models/models.dart';
import 'package:bluebubbles/services/services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AudioPlayer extends StatefulWidget {
  final PlatformFile file;
  final Attachment attachment;

  AudioPlayer({
    Key? key,
    required this.file,
    required this.attachment,
  }) : super(key: key);

  @override
  _AudioPlayerState createState() => _AudioPlayerState();
}

class _AudioPlayerState extends OptimizedState<AudioPlayer> with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  Attachment get attachment => widget.attachment;
  PlatformFile get file => widget.file;
  ConversationViewController get cvController => cvc(cm.activeChat!.chat);

  PlayerController? controller;
  late final animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));

  @override
  void initState() {
    super.initState();
    updateObx(() {
      initBytes();
    });
  }

  void initBytes() async {
    controller = cvController.audioPlayers[attachment.guid];
    if (controller == null) {
      controller = PlayerController()..addListener(() {
        setState(() {});
      });
      await controller!.preparePlayer(file.path!);
      cvController.audioPlayers[attachment.guid!] = controller!;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.all(5),
      child: Row(
        children: [
          IconButton(
            onPressed: () async {
              if (controller == null) return;
              if (controller!.playerState == PlayerState.playing) {
                animController.reverse();
                await controller!.pausePlayer();
              } else {
                animController.forward();
                await controller!.startPlayer(finishMode: FinishMode.loop);
              }
              setState(() {});
            },
            icon: AnimatedIcon(
              icon: AnimatedIcons.play_pause,
              progress: animController,
            ),
            color: context.theme.colorScheme.properOnSurface,
            visualDensity: VisualDensity.compact,
          ),
          GestureDetector(
            onTapDown: (details) {
              if (controller == null) return;
              controller!.seekTo((details.localPosition.dx / (ns.width(context) * 0.25) * controller!.maxDuration).toInt());
            },
            child: (controller?.maxDuration ?? 0) == 0 ? SizedBox(width: ns.width(context) * 0.25) : AudioFileWaveforms(
              size: Size(ns.width(context) * 0.25, 40),
              playerController: controller!,
              padding: EdgeInsets.zero,
              enableSeekGesture: false,
              playerWaveStyle: PlayerWaveStyle(
                fixedWaveColor: context.theme.colorScheme.properSurface.lightenOrDarken(20),
                liveWaveColor: context.theme.colorScheme.properOnSurface,
                waveCap: StrokeCap.square,
                scaleFactor: 0.25,
                waveThickness: 2,
                seekLineThickness: 2,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Center(
              heightFactor: 1,
              child: Text(prettyDuration(Duration(milliseconds: controller?.maxDuration ?? 0)), style: context.theme.textTheme.labelLarge!),
            ),
          ),
        ],
      )
    );
  }

  String prettyDuration(Duration duration) {
    var components = <String>[];

    var days = duration.inDays;
    if (days != 0) {
      components.add('$days:');
    }
    var hours = duration.inHours % 24;
    if (hours != 0) {
      components.add('$hours:');
    }
    var minutes = duration.inMinutes % 60;
    if (minutes != 0) {
      components.add('$minutes:');
    }

    var seconds = duration.inSeconds % 60;
    if (components.isEmpty || seconds != 0) {
      if (components.isEmpty) {
        components.add('00:');
      }
      components.add('$seconds');
    }
    return components.join();
  }

  @override
  bool get wantKeepAlive => true;
}
