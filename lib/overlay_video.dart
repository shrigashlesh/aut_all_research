import 'dart:developer';
import 'dart:io';

import 'package:aut_all_research/utils/ffmpeg_encoder.dart';
import 'package:aut_all_research/utils/path_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

class OverlayVideo extends StatefulWidget {
  const OverlayVideo({super.key});

  @override
  State<OverlayVideo> createState() => _OverlayVideoState();
}

class _OverlayVideoState extends State<OverlayVideo> {
  File? baseVideo;
  File? overlayVideo;
  File? outputVideo;
  bool isProcessing = false;

  VideoPlayerController? mainVideoPlayer;
  VideoPlayerController? outputVideoPlayer;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Overlay Video Test"),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (outputVideo != null)
                GestureDetector(
                  onTap: () {
                    outputVideoPlayer?.play();
                  },
                  child: SizedBox(
                    height: height * 0.3,
                    child: VideoPlayer(
                      outputVideoPlayer!,
                    ),
                  ),
                ),
              ElevatedButton(
                onPressed: () async {
                  final pickerVideo = await ImagePicker().pickMultipleMedia();
                  if (pickerVideo.isEmpty) {
                    log("NO VIDEOS SELECTED");
                    return;
                  }
                  if (pickerVideo.length != 2) {
                    log("SELECT EXACTLY 2 VIDEO");
                    return;
                  }

                  baseVideo = File(pickerVideo.first.path);
                  overlayVideo = File(pickerVideo.last.path);
                },
                child: const Text("Add Video"),
              ),
              ElevatedButton(
                onPressed: () async {
                  await overlap();
                },
                child: const Text("Process Video"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> overlap() async {
    if (baseVideo == null || overlayVideo == null) {
      log("No videos selected");
      return;
    }

    setState(() {
      isProcessing = true;
    });

    final appPath = PathService.path;
    final uniqueId = DateTime.now().millisecondsSinceEpoch;
    final directory = Directory("$appPath/$uniqueId/")
      ..createSync(recursive: true);
    final outputPath = "${directory.path}output.mp4";

    try {
      final overlapCommand =
          """-i ${baseVideo!.path} -i ${overlayVideo!.path} -filter_complex "[0:v]trim=start=0:end=2,setpts=PTS-STARTPTS[v0]; [0:v]trim=start=2:end=2.1,select='eq(n,0)',scale=iw:ih,loop=1:size=1,setpts=PTS-STARTPTS[vpause]; [1:v]scale=iw*0.5:ih*0.5,loop=1:size=90,setpts=N/FRAME_RATE/TB,zoompan=z='min(zoom+0.0015,1.5)':d=90[voverlay]; [vpause][voverlay]overlay=shortest=1,format=yuv420p[vout]" -map "[vout]" -c:v libx264 -preset medium -crf 18 -y $outputPath""";

      await FfmpegEncoder.runFFmpegCommand(
        overlapCommand,
        onError: (e, s) {
          log("FFmpeg Error: $e");
          setState(() {
            isProcessing = false;
          });
        },
        onCompleted: (code) async {
          outputVideo = File(outputPath);
          outputVideoPlayer = VideoPlayerController.file(outputVideo!)
            ..initialize().then((_) {
              // Ensure the first frame is shown after the video is initialized, even before the play button has been pressed.
              setState(() {});
            });
          outputVideoPlayer?.play();
        },
      );
    } catch (e) {
      log("Error during processing: $e");
      setState(() {
        isProcessing = false;
      });
    }
  }
}
