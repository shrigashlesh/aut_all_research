import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:aut_all_research/utils/ffmpeg_encoder.dart';
import 'package:aut_all_research/utils/path_service.dart';
import 'package:depth_map_reader/depth_map_reader.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class BestFrameExtraction extends StatefulWidget {
  const BestFrameExtraction({super.key});

  @override
  State<BestFrameExtraction> createState() => _BestFrameExtractionState();
}

class _BestFrameExtractionState extends State<BestFrameExtraction> {
  File? bestFrameImage;
  Uint8List? bestFrameFromAPI;
  bool isProcessing = false;
  late final Dio _dio;
  final DepthMapReader depthMapReader = DepthMapReader();
  @override
  void initState() {
    super.initState();
    _dio = Dio(
      BaseOptions(
        baseUrl: "https://ai-dev.flytechy.site",
        responseType: ResponseType.json,
      ),
    );
  }

  Future<void> bestFrameFromApi({
    required String videoPath,
  }) async {
    try {
      setState(() {
        isProcessing = true;
      });

      final file = await MultipartFile.fromFile(videoPath);
      final formData = FormData.fromMap({
        'file': file,
      });

      final response = await _dio.post(
        "/fish_video_process_for_2d",
        data: formData,
      );

      final frameIndexInSecond = response.data["data"]["frameIndexInSecond"];
      final bestFrame = response.data["data"]["bestFrame"];
      log("Best frame found at: $frameIndexInSecond seconds");
      bestFrameFromAPI = const Base64Decoder().convert(bestFrame);
      // Now extract the frame from the video using the time from the API
      await extractBestFrameFromTime(
        videoPath: videoPath,
        frameTimeInSec: frameIndexInSecond,
      );
    } catch (e) {
      setState(() {
        isProcessing = false;
      });
      log("API Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Best Frame Test"),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (bestFrameFromAPI != null) ...[
                const Text("Byte"),
                Image.memory(
                  bestFrameFromAPI!,
                  height: height * 0.3,
                ),
              ],
              if (bestFrameImage != null)
                if (bestFrameImage != null) ...[
                  const Text("From seconds"),
                  Image.file(
                    bestFrameImage!,
                    height: height * 0.3,
                  ),
                ],
              if (isProcessing) const CircularProgressIndicator(),
              ElevatedButton(
                onPressed: () async {
                  setState(() {
                    isProcessing = false;
                  });
                  final pickerVideo = await ImagePicker().pickVideo(
                    source: ImageSource.gallery,
                  );
                  if (pickerVideo == null) return;
                  extractCustomMetadata(
                    videoPath: pickerVideo.path,
                    frameTimeInSec: 1,
                  );
                },
                child: const Text("Pick Video"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> extractBestFrameFromTime({
    required String videoPath,
    required double frameTimeInSec,
  }) async {
    setState(() {
      isProcessing = true;
    });

    final appPath = PathService.path;
    final uniqueId = DateTime.now().millisecondsSinceEpoch;
    final directory = Directory("$appPath/$uniqueId/")..create(recursive: true);
    final outputPath = "${directory.path}output.png";

    try {
      final extractFrameCommand =
          ''' -i $videoPath  -ss $frameTimeInSec -c copy -vframes 1 -map 0:v:0 -f data 1.bin''';

      await FfmpegEncoder.runFFmpegCommand(
        extractFrameCommand,
        onError: (e, s) {
          log("FFmpeg Error: $e");
          setState(() {
            isProcessing = false;
          });
        },
        onCompleted: (code) async {
          setState(() {
            bestFrameImage = File(outputPath);
            isProcessing = false;
          });
        },
      );
    } catch (e) {
      log("Error during processing: $e");
      setState(() {
        isProcessing = false;
      });
    }
  }

  Future<void> extractCustomMetadata({
    required String videoPath,
    required double frameTimeInSec,
  }) async {
    try {
      final depth = await depthMapReader.extractDepthMap(
          path: videoPath, at: frameTimeInSec);
      log(depth.toString());
    } catch (e) {
      log(e.toString());
    }
  }
}
