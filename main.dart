import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';


List<CameraDescription> cameras = [];
CameraController? _controller;
File? _imageFile;
String _ngrokUrl = 'https://ccfb-182-176-222-244.ngrok-free.app';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Attendance System',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.normal),
          bodyMedium: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.normal),
          bodySmall: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.normal),
          displayLarge: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.bold),
          displayMedium: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.bold),
          displaySmall: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.bold),
          headlineMedium: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.bold),
          headlineSmall: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.bold),
          titleLarge: TextStyle(fontFamily: 'Roboto', fontWeight: FontWeight.bold),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const AttendancePage(),
    );
  }
}

class AttendancePage extends StatefulWidget {
  const AttendancePage({Key? key}) : super(key: key);

  @override
  _AttendancePageState createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final picker = ImagePicker();
  final TextEditingController _urlController = TextEditingController(text: _ngrokUrl);

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (cameras.isNotEmpty) {
      _controller = CameraController(cameras[0], ResolutionPreset.medium);
      await _controller!.initialize();
      if (!mounted) {
        return;
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    try {
      final image = await _controller!.takePicture();
      setState(() {
        _imageFile = File(image.path);
      });
    } catch (e) {
      print(e);
      _showSnackBar('Failed to take picture: $e');
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await picker.getImage(source: ImageSource.gallery);
    setState(() {
      _imageFile = pickedFile != null ? File(pickedFile.path) : null;
    });
  }

  Future<void> _sendImage() async {
    if (_imageFile == null || !_imageFile!.existsSync()) {
      _showSnackBar('No image file available or file does not exist');
      return;
    }

    if (_ngrokUrl.isEmpty) {
      _showSnackBar('Please set the ngrok URL first');
      return;
    }

    final url = Uri.parse(_ngrokUrl + '/upload');
    var request = http.MultipartRequest('POST', url)
      ..files.add(await http.MultipartFile.fromPath('image', _imageFile!.path));

    try {
      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        _showSnackBar('Image sent successfully: $responseData');
      } else {
        var errorData = await response.stream.bytesToString();
        print('Failed with status: ${response.statusCode}. Response body: $errorData');
        _showSnackBar('Failed to send image: $errorData');
      }
    } catch (e) {
      print('Error sending image: $e');
      _showSnackBar('Error sending image: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Attendance System'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Please enter the ngrok URL below. Ngrok is used for tunneling and exposing your local server to the internet.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: 'Enter ngrok URL',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _ngrokUrl = value.trim();
                  });
                },
              ),
              const SizedBox(height: 20),
              _imageFile == null
                  ? (_controller != null && _controller!.value.isInitialized
                      ? AspectRatio(
                          aspectRatio: _controller!.value.aspectRatio,
                          child: CameraPreview(_controller!),
                        )
                      : Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(child: Text('Camera preview')),
                        ))
                  : Container(
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        image: DecorationImage(
                          image: FileImage(_imageFile!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _takePicture,
                icon: const Icon(FontAwesomeIcons.camera),
                label: const Text('Take Picture'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(FontAwesomeIcons.image),
                label: const Text('Pick Image'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _sendImage,
                icon: const Icon(FontAwesomeIcons.paperPlane),
                label: const Text('Send Image'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
