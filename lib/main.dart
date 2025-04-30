import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:ultralytics_yolo/yolo_model.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fruit Condition',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Fruit Condition'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final picker = ImagePicker();
  io.File? _image;
  late ObjectDetector _objectDetector;
  String _result = "";
  final FlutterTts flutterTts = FlutterTts();
  bool isLoading = false;

  Future<String> _copy(String assetPath) async {
    final path = '${(await getApplicationSupportDirectory()).path}/$assetPath';
    await io.Directory(dirname(path)).create(recursive: true);
    final file = io.File(path);
    if (!await file.exists()) {
      final byteData = await rootBundle.load(assetPath);
      await file.writeAsBytes(byteData.buffer
          .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    }
    return file.path;
  }

  Future<ObjectDetector> _initObjectDetectorWithLocalModel() async {
    final modelPath = await _copy('assets/best_int8.tflite');
    final metadataPath = await _copy('assets/metadata.yaml');

    final model = LocalYoloModel(
      id: 'fruit_condition',
      task: Task.detect,
      format: Format.tflite,
      modelPath: modelPath,
      metadataPath: metadataPath,
    );

    return ObjectDetector(model: model);
  }

  Future<void> speak(String text) async {
    await flutterTts.speak(text);
  }

  @override
  void initState() {
    super.initState();

    flutterTts.setLanguage("en-US");
    flutterTts.setSpeechRate(0.5);
    flutterTts.setPitch(1.0);

    _initObjectDetectorWithLocalModel().then((detector) {
      _objectDetector = detector;
      if (_objectDetector != null) {
        _objectDetector.loadModel().then((val) {
          print("Model loaded: $val");
        });
      }
    });
  }

  Future<void> classifyImage(io.File image) async {
    setState(() {
      isLoading = true;
    });
    final results = await _objectDetector.detect(imagePath: image.path);
    if (results != null) {
      final result = results?.first;
      final label = result?.label;
      final confidence = result?.confidence?.toStringAsFixed(2);
      print("Label: $label, Confidence: $confidence");
      var text = "";
      if (label == "fresh") {
        text = "This fruit is fresh and ready for storage.";
      } else {
        text = "This fruit is rotten and should be thrown away.";
      }
      speak(text);
      setState(() {
        _result = "$text"
            "\nConfidence: $confidence";
      });
    }
    setState(() {
      isLoading = false;
    });
  }

  Future<void> getImageFromGallery() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = io.File(pickedFile.path);
      });
      await classifyImage(_image!);
    }
  }

  Future<void> getImageFromCamera() async {
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _image = io.File(pickedFile.path);
      });
      await classifyImage(_image!);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Fruit Condition"),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: isLoading
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    _image == null
                        ? Text("No image selected")
                        : Image.file(_image!),
                    SizedBox(height: 20),
                    Text(
                      _result,
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: getImageFromGallery,
                          child: Text("Pick from Gallery"),
                        ),
                        ElevatedButton(
                          onPressed: getImageFromCamera,
                          child: Text("Capture from Camera"),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
