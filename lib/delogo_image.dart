import 'dart:developer';
import 'dart:io';
import 'dart:ui';

import 'package:aut_all_research/utils/ffmpeg_encoder.dart';
import 'package:aut_all_research/utils/path_service.dart';
import 'package:aut_all_research/utils/scaler.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

class DelogoImageWithFFMPEG extends StatefulWidget {
  const DelogoImageWithFFMPEG({super.key});

  @override
  State<DelogoImageWithFFMPEG> createState() => _DelogoImageWithFFMPEGState();
}

class _DelogoImageWithFFMPEGState extends State<DelogoImageWithFFMPEG> {
  File? selectedImage;
  File? maskImage;
  File? outputImage;
  bool isProcessing = false;
  List<List<Offset>> paths = [];
  List<Offset> currentPath = [];
  double imageWidth = 0.0;
  double imageHeight = 0.0;
  final GlobalKey _imageKey = GlobalKey();
// Drag and drop keypoints to new offsets
  void _drawPath(DragUpdateDetails details) {
    final RenderBox? targetBox =
        _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (targetBox == null) return;

    final Size targetSize = targetBox.size;

    // Check if the localOffset is within the target bounds
    if (details.localPosition.dx >= 0 &&
        details.localPosition.dx <= targetSize.width &&
        details.localPosition.dy >= 0 &&
        details.localPosition.dy <= targetSize.height) {
      setState(() {
        currentPath.add(details.localPosition);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Interactive Drawing Test"),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (selectedImage != null)
                Stack(
                  children: [
                    GestureDetector(
                      onPanUpdate: (details) {
                        paths.clear();
                        _drawPath(details);
                      },
                      onPanEnd: (details) {
                        setState(() {
                          paths.add(List.from(currentPath));
                          currentPath.clear();
                        });
                      },
                      child: Image.file(
                        key: _imageKey,
                        selectedImage!,
                        height: height * 0.3,
                        fit: BoxFit.fitHeight,
                      ),
                    ),
                    CustomPaint(
                      painter: DrawingPainter(paths..add(currentPath)),
                    ),
                  ],
                ),
              Row(
                children: [
                  // if (maskImage != null)
                  //   Expanded(
                  //     child: Image.file(
                  //       maskImage!,
                  //       height: height * 0.3,
                  //     ),
                  //   ),
                  if (outputImage != null)
                    Expanded(
                      child: Image.file(
                        outputImage!,
                        height: height * 0.3,
                      ),
                    ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final pickedImage = await ImagePicker().pickImage(
                          source: ImageSource.gallery,
                        );
                        if (pickedImage == null) return;
                        setState(() {
                          selectedImage = File(pickedImage.path);
                          paths.clear(); // Clear paths for a new image
                        });
                      },
                      child: const Text("Add Image"),
                    ),
                  ),
                  const SizedBox(
                    width: 16,
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        setState(() {
                          paths.clear();
                        });
                      },
                      child: const Text("Remove Path"),
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () async {
                  delogo();
                },
                child: const Text("Process Image"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> createMaskImage(String maskPath) async {
    if (selectedImage == null) {
      log("No image selected to create a mask");
      return;
    }

    // Load the image to get its dimensions
    final imageBytes = await selectedImage!.readAsBytes();
    final image = img.decodeImage(imageBytes);
    if (image == null) {
      log("Failed to decode image");
      return;
    }

    final originalWidth = image.width.toDouble();
    final originalHeight = image.height.toDouble();
    // Set up the canvas size to match the original image dimensions
    final recorder = PictureRecorder();
    final canvas = Canvas(
        recorder,
        Rect.fromPoints(
            const Offset(0, 0), Offset(originalWidth, originalHeight)));

    // Draw black background
    final paintBlack = Paint()..color = Colors.black;
    canvas.drawRect(
        Rect.fromLTWH(0, 0, originalWidth, originalHeight), paintBlack);
    final scale =
        await calScaleFact(Size(originalWidth, originalHeight), _imageKey);
    // Draw freeform paths with scaling
    final paintWhite = Paint()..color = Colors.white;
    for (var path in paths) {
      if (path.isNotEmpty) {
        final pathObject = Path();
        log("$scale");
        pathObject.moveTo(
          path[0].dx * scale.$1,
          path[0].dy * scale.$2,
        );
        for (var point in path.skip(1)) {
          pathObject.lineTo(
            point.dx * scale.$1,
            point.dy * scale.$2,
          );
        }
        pathObject.close(); // Optional: close the path if desired
        canvas.drawPath(pathObject, paintWhite);
      }
    }

    final picture = recorder.endRecording();
    final maskImg =
        await picture.toImage(originalWidth.toInt(), originalHeight.toInt());
    final byteData = await maskImg.toByteData(format: ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    final file = File(maskPath);
    await file.writeAsBytes(buffer);
    setState(() {
      maskImage = file;
    });
  }

  Future<void> delogo() async {
    if (selectedImage == null) {
      log("No Image Selected");
      return;
    }

    setState(() {
      isProcessing = true;
    });

    final appPath = PathService.path;
    final uniqueId = DateTime.now().millisecondsSinceEpoch;
    final directory = Directory("$appPath/$uniqueId/")..create(recursive: true);
    final maskPath =
        "${directory.path}mask.png"; // Path for the logo mask/template
    final outputPath = "${directory.path}output.png";

    try {
      // Step 1: Create a mask image with the user's path
      await createMaskImage(maskPath);

      // Step 2: Apply the removelogo filter with the created mask
      final removeLogoCommand =
          '''-i ${selectedImage!.path} -i $maskPath -filter_complex "removelogo=$maskPath" -f image2 -y $outputPath''';

      await FfmpegEncoder.runFFmpegCommand(
        removeLogoCommand,
        onError: (e, s) {
          log("FFmpeg Error: $e");
          setState(() {
            isProcessing = false;
          });
        },
        onCompleted: (code) async {
          setState(() {
            outputImage = File(outputPath);
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
}

class DrawingPainter extends CustomPainter {
  final List<List<Offset?>> paths;

  DrawingPainter(this.paths);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.0;

    // Draw all paths
    for (var path in paths) {
      if (path.isNotEmpty) {
        for (int i = 0; i < path.length - 1; i++) {
          if (path[i] != null && path[i + 1] != null) {
            canvas.drawLine(path[i]!, path[i + 1]!, paint);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
