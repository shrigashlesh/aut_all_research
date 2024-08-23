import 'dart:developer';
import 'dart:typed_data';

import 'package:aut_all_research/gen/assets.gen.dart';
import 'package:aut_all_research/utils/scaler.dart';
import 'package:delaunay/delaunay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

class TriangularMesh extends StatefulWidget {
  const TriangularMesh({super.key});

  @override
  State<TriangularMesh> createState() => _TriangularMeshState();
}

class _TriangularMeshState extends State<TriangularMesh> {
  Path? _maskPath;
  final GlobalKey _imageKey = GlobalKey();
  late Delaunay delaunay;
  List<Offset> scaledPoints = [];
  List<Offset> points = [
    const Offset(502.0, 804.0),
    const Offset(441.0, 913.0),
    const Offset(909.0, 1061.0),
    const Offset(1308.0, 1205.0),
    const Offset(1724.0, 1362.0),
    const Offset(2128.0, 1564.0),
    const Offset(2509.0, 1771.0),
    const Offset(2864.0, 2063.0),
    const Offset(3111.0, 2302.0),
    const Offset(3500.0, 2106.0),
    const Offset(3102.0, 2687.0),
    const Offset(1761.0, 1060.0),
    const Offset(1429.0, 1664.0),
    const Offset(899.0, 850.0),
    const Offset(767.0, 859.0),
    const Offset(640.0, 872.0),
    const Offset(556.0, 947.0),
    const Offset(506.0, 1029.0),
    const Offset(577.0, 1132.0),
    const Offset(682.0, 1209.0),
    const Offset(790.0, 1278.0),
    const Offset(899.0, 1346.0),
    const Offset(1011.0, 1405.0),
    const Offset(1115.0, 1389.0),
    const Offset(1196.0, 1312.0),
    const Offset(1295.0, 1384.0),
    const Offset(1355.0, 1489.0),
    const Offset(1454.0, 1570.0),
    const Offset(1549.0, 1653.0),
    const Offset(1617.0, 1737.0),
    const Offset(1645.0, 1855.0),
    const Offset(1754.0, 1808.0),
    const Offset(1870.0, 1801.0),
    const Offset(1992.0, 1837.0),
    const Offset(2113.0, 1813.0),
    const Offset(2204.0, 1896.0),
    const Offset(2319.0, 1884.0),
    const Offset(2423.0, 1947.0),
    const Offset(2482.0, 2055.0),
    const Offset(2592.0, 2113.0),
    const Offset(2653.0, 2058.0),
    const Offset(2763.0, 2121.0),
    const Offset(2849.0, 2220.0),
    const Offset(2924.0, 2324.0),
    const Offset(2991.0, 2433.0),
    const Offset(3060.0, 2541.0),
    const Offset(3141.0, 2568.0),
    const Offset(3173.0, 2445.0),
    const Offset(3180.0, 2312.0),
    const Offset(3185.0, 2181.0),
    const Offset(3270.0, 2085.0),
    const Offset(3340.0, 1979.0),
    const Offset(3255.0, 1927.0),
    const Offset(3123.0, 1933.0),
    const Offset(2992.0, 1921.0),
    const Offset(2883.0, 1855.0),
    const Offset(2781.0, 1773.0),
    const Offset(2733.0, 1671.0),
    const Offset(2620.0, 1620.0),
    const Offset(2513.0, 1548.0),
    const Offset(2408.0, 1471.0),
    const Offset(2302.0, 1397.0),
    const Offset(2195.0, 1325.0),
    const Offset(2084.0, 1271.0),
    const Offset(1971.0, 1215.0),
    const Offset(1873.0, 1135.0),
    const Offset(1761.0, 1076.0),
    const Offset(1645.0, 1023.0),
    const Offset(1528.0, 976.0),
    const Offset(1411.0, 928.0),
    const Offset(1287.0, 899.0),
    const Offset(1160.0, 876.0),
    const Offset(1031.0, 856.0),
  ];

  List<Offset> edges = [];
  List<Offset> scaledEdges = [];

  @override
  void initState() {
    super.initState();
    _loadImageAndCreatePath();
  }

  Future<List<Offset>> loadOffsetsFromAssets(String assetPath) async {
    // Load the file content from assets
    final String data = await rootBundle.loadString(assetPath);

    // Split the content into lines
    final List<String> lines = data.split('\n');

    // Initialize a list to hold the Offset objects
    List<Offset> offsets = [];

    // Parse each line and create an Offset object
    for (String line in lines) {
      // Trim whitespace and skip empty lines
      final String trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      // Split by comma to get x and y coordinates
      final List<String> parts = trimmedLine.split(' ');

      if (parts.length == 2) {
        final double x = double.tryParse(parts[0].trim()) ?? 0.0;
        final double y = double.tryParse(parts[1].trim()) ?? 0.0;
        offsets.add(Offset(x, y));
      }
    }

    return offsets;
  }

  Future<void> _loadImageAndCreatePath() async {
    try {
      edges = await loadOffsetsFromAssets(
          Assets.offsets.edgePoints); // Load the image
      points = await loadOffsetsFromAssets(
          Assets.offsets.edgePoints); // Load the image
      final ByteData bytes = await rootBundle.load(Assets.images.fish.path);
      final Uint8List imageBytes = bytes.buffer.asUint8List();
      final image = img.decodeImage(imageBytes.buffer.asUint8List());

      if (image != null) {
        // Get scale factors based on the original and displayed image size
        final scaleFactors = await calScaleFact(
          Size(image.width.toDouble(), image.height.toDouble()),
          _imageKey,
        ); // Scale the points
        scalePoints(scaleFactors.$1, scaleFactors.$2);

        // Convert to Float32List for Delaunay
        Float32List uintPoints = convertToFloat32List();

        // Perform Delaunay triangulation
        delaunay = Delaunay(uintPoints);
        delaunay.update();

        // Extract the path from the grayscale mask
        createPathFromOffsets();
      }
    } catch (e) {
      log(e.toString());
    }
  }

  void scalePoints(double scaleX, double scaleY) {
    for (int i = 0; i < points.length; i++) {
      scaledPoints.add(Offset(points[i].dx / scaleX, points[i].dy / scaleY));
    }
    for (int i = 0; i < edges.length; i++) {
      scaledEdges.add(Offset(edges[i].dx / scaleX, edges[i].dy / scaleY));
    }
  }

  Float32List convertToFloat32List() {
    List<double> flatPoints = [];
    for (var point in scaledPoints) {
      flatPoints.add(point.dx);
      flatPoints.add(point.dy);
    }
    return Float32List.fromList(flatPoints);
  }

  void createPathFromOffsets() {
    final Path path = Path();

    // Start the path at the first offset
    path.moveTo(scaledEdges[0].dx, scaledEdges[0].dy);

    // Add lines to the remaining offsets
    for (int i = 1; i < scaledEdges.length; i++) {
      path.lineTo(scaledEdges[i].dx, scaledEdges[i].dy);
    }

    // Optionally, close the path if you want to create a closed shape
    path.close();

    setState(() {
      _maskPath = path;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Triangular Mesh"),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            onPressed: () {
              _loadImageAndCreatePath();
            },
            icon: const Icon(Icons.masks),
          )
        ],
      ),
      body: Stack(
        children: [
          Assets.images.fish.image(key: _imageKey),
          _maskPath != null
              ? CustomPaint(
                  painter: MaskPainter(
                    _maskPath!,
                    scaledPoints,
                    delaunay.triangles,
                  ),
                )
              : const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class MaskPainter extends CustomPainter {
  final Path maskPath;
  final List<Offset> points;
  final Uint32List triangles;

  MaskPainter(this.maskPath, this.points, this.triangles);

  @override
  void paint(Canvas canvas, Size size) {
    final innerTriangle = Paint()
      ..color = Colors.blue
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final edge = Paint()
      ..color = Colors.red
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    final pointPaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(maskPath, edge);
    // Apply the maskPath to clip the canvas
    canvas.save(); // Save the current state of the canvas
    canvas.clipPath(maskPath); // Clip to the maskPath
    // Draw triangles within the clipped area

    for (int i = 0; i < triangles.length; i += 3) {
      int p1 = triangles[i];
      int p2 = triangles[i + 1];
      int p3 = triangles[i + 2];
      // Draw lines between points to form triangles
      canvas.drawLine(
        points[p1],
        points[p2],
        innerTriangle,
      );
      canvas.drawLine(
        points[p2],
        points[p3],
        innerTriangle,
      );
      canvas.drawLine(
        points[p3],
        points[p1],
        innerTriangle,
      );
    }
    for (var p in points) {
      canvas.drawCircle(p, 3, pointPaint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
