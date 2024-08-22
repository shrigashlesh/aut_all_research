import 'dart:developer';
import 'dart:io';

import 'package:aut_all_research/utils/ffmpeg_encoder.dart';
import 'package:aut_all_research/utils/path_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

class DelogoVideoWithFFMPEG extends StatefulWidget {
  const DelogoVideoWithFFMPEG({super.key});

  @override
  State<DelogoVideoWithFFMPEG> createState() => _DelogoVideoWithFFMPEGState();
}

class _DelogoVideoWithFFMPEGState extends State<DelogoVideoWithFFMPEG> {
  File? selectedVideo;
  File? maskImage;
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
        title: const Text("Video Test"),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (selectedVideo != null && mainVideoPlayer != null)
                GestureDetector(
                  onTap: () {
                    mainVideoPlayer?.play();
                  },
                  child: SizedBox(
                    height: height * 0.3,
                    child: VideoPlayer(
                      mainVideoPlayer!,
                    ),
                  ),
                ),
              if (maskImage != null)
                Image.file(
                  maskImage!,
                  height: height * 0.3,
                ),
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
                  final pickerVideo = await ImagePicker().pickVideo(
                    source: ImageSource.gallery,
                  );
                  if (pickerVideo == null) return;

                  selectedVideo = File(pickerVideo.path);

                  mainVideoPlayer = VideoPlayerController.file(selectedVideo!)
                    ..initialize().then((_) {
                      // Ensure the first frame is shown after the video is initialized, even before the play button has been pressed.
                      setState(() {});
                    });
                  mainVideoPlayer?.play();
                },
                child: const Text("Add Video"),
              ),
              ElevatedButton(
                onPressed: () async {
                  await delogo();
                },
                child: const Text("Process Video"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> delogo() async {
    if (selectedVideo == null) {
      log("No video or mask selected");
      return;
    }

    setState(() {
      isProcessing = true;
    });

    final appPath = PathService.path;
    final uniqueId = DateTime.now().millisecondsSinceEpoch;
    final directory = Directory("$appPath/$uniqueId/")
      ..createSync(recursive: true);
    final maskVideoPath = "${directory.path}mask.mp4";
    final outputPath = "${directory.path}output.mp4";

    final orgFrameDirectory = "${directory.path}org_frames";
    final maskFrameDirectory = "${directory.path}mask_frames";
    final processedFrameDirectory = "${directory.path}processed_frames";

    for (var path in [
      orgFrameDirectory,
      maskFrameDirectory,
      processedFrameDirectory
    ]) {
      Directory(path).createSync(recursive: true);
    }
    await extractFrames(selectedVideo!.path, orgFrameDirectory);
    try {
      // Step 1: Create mask video
      final createMaskCommand =
          '''-i ${selectedVideo!.path} -vf "format=rgba,colorkey=0xf04c46:0.001:0.2,alphaextract,negate,format=rgba,colorchannelmixer=rr=1:rg=1:rb=1:gr=1:gg=1:gb=1:br=1:bg=1:bb=1:aa=1" $maskVideoPath''';
      await FfmpegEncoder.runFFmpegCommand(
        createMaskCommand,
        onError: (e, s) {
          log("FFmpeg Error during mask creation: $e");
          setState(() {
            isProcessing = false;
          });
        },
        onCompleted: (code) async {
          // Step 2: Extract frames from the mask video
          await extractFrames(maskVideoPath, maskFrameDirectory);
          await Future.delayed(const Duration(seconds: 1));
          for (int i = 1; i <= 120; i++) {
            final frameNumber = i.toString().padLeft(4, '0');
            final frameName = 'frame_$frameNumber.png';
            final framePath = "$orgFrameDirectory/$frameName";
            final maskFramePath = "$maskFrameDirectory/$frameName";
            final processedFramePath = "$processedFrameDirectory/$frameName";
            final cmd =
                '''-i $framePath -i $maskFramePath -filter_complex "removelogo=$maskFramePath" -f image2 -y $processedFramePath''';
            await FfmpegEncoder.runFFmpegCommand(
              cmd,
              onError: (e, s) {
                log("FFmpeg Error during removing: $e");
                setState(() {
                  isProcessing = false;
                });
              },
              onCompleted: (code) async {
                log("Frame filtered $processedFrameDirectory");
              },
            );
          }

          extractOutput(dir: processedFrameDirectory, outputPath: outputPath);
        },
      );
    } catch (e) {
      log("Error during processing: $e");
      setState(() {
        isProcessing = false;
      });
    }
  }

  Future<void> extractOutput(
      {required String dir, required String outputPath}) async {
    final reassembleCommand =
        '''-framerate 24 -i $dir/frame_%04d.png -c:v libx264 -pix_fmt yuv420p $outputPath''';
    await FfmpegEncoder.runFFmpegCommand(
      reassembleCommand,
      onError: (e, s) {
        log("FFmpeg Error during reassembly: $e");
        setState(() {
          isProcessing = false;
        });
      },
      onCompleted: (code) async {
        log("Delogo video created: $outputPath");
        setState(() {
          outputVideo = File(outputPath);
          isProcessing = false;
        });
        outputVideoPlayer = VideoPlayerController.file(outputVideo!)
          ..initialize().then((_) {
            // Ensure the first frame is shown after the video is initialized, even before the play button has been pressed.
            setState(() {});
          });
        outputVideoPlayer?.play();
      },
    );
  }

  Future<void> extractFrames(String videoPath, String outputDirectory) async {
    // Ensure the directory exists
    Directory(outputDirectory).createSync(recursive: true);

    // Extract frames from the video
    final extractFramesCommand =
        '''-i "$videoPath" -vf "fps=24,format=rgb24" $outputDirectory/frame_%04d.png''';
    await FfmpegEncoder.runFFmpegCommand(
      extractFramesCommand,
      onError: (e, s) {
        log("FFmpeg Error during frame extraction: $e");
        setState(() {
          isProcessing = false;
        });
      },
      onCompleted: (code) {
        log("Frames extracted to $outputDirectory");
      },
    );
  }
}
