import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Platform-specific Hive initialization
  if (kIsWeb) {
    await Hive.initFlutter();
  } else {
    final appDir = await getApplicationDocumentsDirectory();
    Hive.init(appDir.path);
  }

  Hive.registerAdapter(ReportAdapter());
  await Hive.openBox<Report>('reports');
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Water Body Reporter',
      debugShowCheckedModeBanner: false, // Remove debug banner
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng? currentLocation;
  File? _image;
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await _getCurrentLocation();
      await _checkLocationPermission();
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      setState(() {
        currentLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      throw Exception('Failed to get location: $e');
    }
  }


  Future<void> _takePhoto() async {
  try {
    final image = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 800,
      imageQuality: 85,
    );

    if (image != null) {
      if (kIsWeb) {
        // Web-specific handling
        final bytes = await image.readAsBytes();
        setState(() {
          _image = File.fromRawPath(bytes);
        });
      } else {
        // Mobile handling
        setState(() {
          _image = File(image.path);
        });
      }
    }
  } catch (e) {
    _showErrorSnackbar('Failed to take photo: ${e.toString()}');
  }
}

  Future<void> _pickFromGallery() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() => _image = File(image.path));
      }
    } catch (e) {
      _showErrorSnackbar('Failed to pick image: $e');
    }
  }

  void _showReportDialog() {
    _descriptionController.clear();
    _titleController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Report Water Body"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_image != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _image!,
                    height: 150,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Camera"),
                    onPressed: _takePhoto,
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.photo_library),
                    label: const Text("Gallery"),
                    onPressed: _pickFromGallery,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: "Title",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: "Description",
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: _submitReport,
            child: const Text("Submit"),
          ),
        ],
      ),
    );
  }

  Future<void> _submitReport() async {
    if (currentLocation == null) {
      _showErrorSnackbar('Location not available');
      return;
    }

    if (_titleController.text.isEmpty) {
      _showErrorSnackbar('Please enter a title');
      return;
    }

    if (_descriptionController.text.isEmpty) {
      _showErrorSnackbar('Please enter a description');
      return;
    }

    try {
      final report = Report(
        title: _titleController.text,
        description: _descriptionController.text,
        imagePath: _image?.path,
        latitude: currentLocation!.latitude,
        longitude: currentLocation!.longitude,
        date: DateTime.now(),
      );

      await Hive.box<Report>('reports').add(report);
      
      Navigator.pop(context);
      setState(() => _image = null);
      
      _showSuccessSnackbar('Report submitted successfully!');
    } catch (e) {
      _showErrorSnackbar('Failed to submit report: $e');
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showReportDetails(Report report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(report.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (report.imagePath != null && File(report.imagePath!).existsSync())
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(report.imagePath!),
                    height: 150,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                report.description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Date: ${DateFormat('MMM dd, yyyy - hh:mm a').format(report.date)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Location: ${report.latitude.toStringAsFixed(4)}, ${report.longitude.toStringAsFixed(4)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _initializeApp,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Water Body Reporter"),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReportsListScreen(
                  onReportSelected: (report) {
                    setState(() {
                      currentLocation = LatLng(report.latitude, report.longitude);
                    });
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _getCurrentLocation,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showReportDialog,
        icon: const Icon(Icons.add),
        label: const Text("Report"),
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: currentLocation!,
          initialZoom: 14.0,
          onTap: (_, __) => FocusScope.of(context).unfocus(),
        ),
        children: [
          TileLayer(
            urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
            tileProvider: CancellableNetworkTileProvider(),
            userAgentPackageName: 'com.example.water_body_reporter',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: currentLocation!,
                width: 40.0,
                height: 40.0,
                child: const Icon(
                  Icons.my_location,
                  color: Colors.blue,
                  size: 40.0,
                ),
              ),
            ],
          ),
          ValueListenableBuilder<Box<Report>>(
                  valueListenable: Hive.box<Report>('reports').listenable(),
                  builder: (context, box, _) {
                    final reportMarkers = box.values.map((report) => Marker(
                      point: LatLng(report.latitude, report.longitude),
                      width: 40.0,
                      height: 40.0,
                      child: GestureDetector(
                        onTap: () => _showReportDetails(report),
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40.0,
                        ),
                      ),
                    )).toList();
                    
                    return MarkerLayer(markers: reportMarkers);
                  },
                ),
            ],
          ),
        
      
    );
  }
}

class ReportsListScreen extends StatelessWidget {
  final Function(Report) onReportSelected;

  const ReportsListScreen({super.key, required this.onReportSelected});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Reports'),
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<Report>('reports').listenable(),
        builder: (context, Box<Report> box, _) {
          if (box.isEmpty) {
            return const Center(child: Text('No reports yet'));
          }

          return ListView.builder(
            itemCount: box.length,
            itemBuilder: (context, index) {
              final report = box.getAt(index)!;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: report.imagePath != null && File(report.imagePath!).existsSync()
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.file(
                            File(report.imagePath!),
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(Icons.image, size: 50),
                  title: Text(report.title),
                  subtitle: Text(
                    DateFormat('MMM dd, yyyy').format(report.date),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onReportSelected(report),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

@HiveType(typeId: 0)
class Report extends HiveObject {
  @HiveField(0)
  final String title;
  
  @HiveField(1)
  final String description;
  
  @HiveField(2)
  final String? imagePath;
  
  @HiveField(3)
  final double latitude;
  
  @HiveField(4)
  final double longitude;
  
  @HiveField(5)
  final DateTime date;

  Report({
    required this.title,
    required this.description,
    this.imagePath,
    required this.latitude,
    required this.longitude,
    required this.date,
  });
}

class ReportAdapter extends TypeAdapter<Report> {
  @override
  final int typeId = 0;

  @override
  Report read(BinaryReader reader) {
    return Report(
      title: reader.read(),
      description: reader.read(),
      imagePath: reader.read(),
      latitude: reader.read(),
      longitude: reader.read(),
      date: reader.read(),
    );
  }

  @override
  void write(BinaryWriter writer, Report obj) {
    writer.write(obj.title);
    writer.write(obj.description);
    writer.write(obj.imagePath);
    writer.write(obj.latitude);
    writer.write(obj.longitude);
    writer.write(obj.date);
  }
}