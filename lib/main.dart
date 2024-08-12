import 'dart:developer';
import 'dart:io';

import 'package:aut_all_research/utils/ffmpeg_encoder.dart';
import 'package:aut_all_research/utils/path_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PathService.initPath();
  runApp(const AppLauncher());
}

class AppLauncher extends StatelessWidget {
  const AppLauncher({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: DelogoImageWithFFMPEG(),
    );
  }
}

class DelogoImageWithFFMPEG extends StatefulWidget {
  const DelogoImageWithFFMPEG({super.key});

  @override
  State<DelogoImageWithFFMPEG> createState() => _DelogoImageWithFFMPEGState();
}

class _DelogoImageWithFFMPEGState extends State<DelogoImageWithFFMPEG> {
  File? selectedImage;
  File? outputImage;

  bool isProcessing = false;

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
    Directory directory = Directory("$appPath/$uniqueId/");
    directory = await directory.create(recursive: true);
    final maskPath =
        "${directory.path}mask.png"; // Path for the logo mask/template
    final outputPath = "${directory.path}output.png";

    // Step 1: Create a mask image with a white rectangle at the logo area
    final createMaskCmd =
        '''-i ${selectedImage!.path} -filter_complex "drawbox=x=0:y=0:w=iw:h=ih:color=black@1:t=fill,drawbox=x=430:y=520:w=90:h=100:color=white@1:t=fill" -f image2 -y $maskPath''';

    await FfmpegEncoder.runFFmpegCommand(
      createMaskCmd,
      onError: (e, s) {
        log(e.toString());
        setState(() {
          isProcessing = false;
        });
      },
      onCompleted: (code) async {
        // Step 2: Apply removelogo filter with the created mask
        final removeLogoCommand =
            '''-i ${selectedImage!.path} -i $maskPath -filter_complex "removelogo=$maskPath" $outputPath''';
        await FfmpegEncoder.runFFmpegCommand(
          removeLogoCommand,
          onError: (e, s) {
            log(e.toString());
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pball removal test"),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (selectedImage != null)
                Image.file(
                  selectedImage!,
                  height: height * 0.3,
                ),
              if (outputImage != null)
                Image.file(
                  outputImage!,
                  height: height * 0.3,
                ),
              ElevatedButton(
                onPressed: () async {
                  final pickedImage = await ImagePicker().pickImage(
                    source: ImageSource.gallery,
                  );
                  if (pickedImage == null) return;
                  setState(() {
                    selectedImage = File(pickedImage.path);
                  });
                },
                child: const Text("Add Image"),
              ),
              ElevatedButton(
                onPressed: () async {
                  setState(() {
                    outputImage = null;
                  });
                  delogo();
                },
                child: const Text("Process Image"),
              )
            ],
          ),
        ),
      ),
    );
  }
}
