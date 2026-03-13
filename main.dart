import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'database_service.dart';
import 'dart:convert';
import 'dart:typed_data';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Class Check-in',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB22222), // Deep Red
          secondary: const Color(0xFFFFD700), // Gold
        ),
      ),
      home: const MainWrapper(),
    );
  }
}

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = <Widget>[
    HomeScreen(),
    CheckInScreen(),
    FinishClassScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.login),
            label: 'Check-in',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.logout),
            label: 'Finish Class',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Class Check-in'),
        backgroundColor: const Color(0xFFB22222),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Color(0xFFFFD700),
                  child: Icon(Icons.person, color: Color(0xFFB22222)),
                ),
                const SizedBox(width: 16),
                const Text(
                  'สวัสดี, นักศึกษา MFU',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Status Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, size: 40, color: Color(0xFFB22222)),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'สถานะปัจจุบัน: ยังไม่ได้เข้าเรียน',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Stats Row
            Row(
              children: [
                Expanded(
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text('Total Classes', style: TextStyle(fontSize: 14)),
                          Text('5', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text('Reflection Points', style: TextStyle(fontSize: 14)),
                          Text('25', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Quick Action
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Navigate to Check-in tab
                  DefaultTabController.of(context).animateTo(1);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB22222),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Start Check-in', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final _formKey = GlobalKey<FormState>();
  String _previousTopic = '';
  String _expectedTopic = '';
  int _moodScore = 1;
  double? _latitude;
  double? _longitude;
  String? _qrResult;
  String? _qrImageBase64;
  String _locationText = 'Location: Not fetched yet';
  String _qrText = 'QR Code: Not scanned yet';
  bool _isLoading = false;
  int _currentStep = 0;

  final DatabaseService _databaseService = DatabaseService();

  Future<void> _getGpsAndScanQR() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // First, get GPS
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationText = 'Location services are disabled.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationText = 'Location permissions are denied.';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationText = 'Location permissions are permanently denied.';
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationText = 'Location: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}';
        _currentStep = 1;
      });

      // Then, scan QR
      final result = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(builder: (context) => const QRScannerScreen()),
      );

      if (result != null) {
        setState(() {
          _qrResult = result['code'];
          _qrImageBase64 = result['image'];
          _qrText = 'QR Code: ${_qrResult ?? 'Captured'}';
          _currentStep = 2;
        });

        // Automatically save after scanning
        await _autoSaveCheckIn();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _autoSaveCheckIn() async {
    if (_latitude == null || _longitude == null || _qrResult == null) {
      return;
    }

    try {
      // Save to Firestore
      String documentId = await _databaseService.saveCheckIn(
        studentId: 'student123', // Hardcoded for demo
        previousTopic: _previousTopic,
        expectedTopic: _expectedTopic,
        moodScore: _moodScore,
        lat: _latitude!,
        lng: _longitude!,
        qrImageBase64: _qrImageBase64,
      );

      // Save locally
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('document_id', documentId);
      await prefs.setString('check_in_time', DateTime.now().toIso8601String());
      await prefs.setString('previous_topic', _previousTopic);
      await prefs.setString('expected_topic', _expectedTopic);
      await prefs.setInt('mood_score', _moodScore);
      await prefs.setDouble('check_in_lat', _latitude!);
      await prefs.setDouble('check_in_lng', _longitude!);
      await prefs.setString('qr_code', _qrResult ?? '');
      await prefs.setString('qr_image_base64', _qrImageBase64 ?? '');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check-in successful and data saved!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving data: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Check-in'),
        backgroundColor: const Color(0xFFB22222),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Progress Indicator
                  LinearProgressIndicator(
                    value: _currentStep / 2,
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFB22222)),
                  ),
                  const SizedBox(height: 10),
                  Text('Step ${_currentStep + 1} of 3'),
                  const SizedBox(height: 20),
                  // GPS & QR Section
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Icon(Icons.location_on, size: 40, color: Color(0xFFB22222)),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _getGpsAndScanQR,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFD700),
                              foregroundColor: const Color(0xFFB22222),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text('Scan QR & Get GPS'),
                          ),
                          const SizedBox(height: 10),
                          Text(_locationText, style: TextStyle(color: _latitude != null ? Colors.green : Colors.red)),
                          const SizedBox(height: 5),
                          Text(_qrText, style: TextStyle(color: _qrResult != null ? Colors.green : Colors.red)),
                          if (_qrImageBase64 != null) ...[
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                base64Decode(_qrImageBase64!),
                                height: 100,
                                width: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Form
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'หัวข้อที่เรียนไปในคาบที่แล้ว',
                      prefixIcon: const Icon(Icons.book),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onChanged: (value) => _previousTopic = value,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the previous topic';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'หัวข้อที่คาดหวังว่าจะได้เรียนในวันนี้',
                      prefixIcon: const Icon(Icons.lightbulb),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onChanged: (value) => _expectedTopic = value,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the expected topic';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text('ระดับอารมณ์ก่อนเรียน', style: TextStyle(fontSize: 16)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final emojis = ['😡', '🙁', '😐', '🙂', '😄'];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _moodScore = index + 1;
                          });
                        },
                        child: Text(
                          emojis[index],
                          style: TextStyle(
                            fontSize: _moodScore == index + 1 ? 40 : 30,
                            color: _moodScore == index + 1 ? const Color(0xFFFFD700) : Colors.grey,
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}

class FinishClassScreen extends StatefulWidget {
  const FinishClassScreen({super.key});

  @override
  State<FinishClassScreen> createState() => _FinishClassScreenState();
}

class _FinishClassScreenState extends State<FinishClassScreen> {
  final _formKey = GlobalKey<FormState>();
  String _learnedTopic = '';
  String _feedback = '';
  int _satisfactionScore = 1;
  bool _isLoading = false;

  final DatabaseService _databaseService = DatabaseService();

  Future<void> _getGpsAndScanQR() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // Get GPS
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied.')),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are permanently denied.')),
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      // Store in state or proceed

      // Now scan QR
      final result = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (context) => const QRScannerScreen()),
      );

      if (result != null) {
        // Proceed to checkout
        await _submitCheckOut(position.latitude, position.longitude);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitCheckOut(double lat, double lng) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // For demo, assume documentId is stored
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? documentId = prefs.getString('document_id'); // Need to store this after check-in
      if (documentId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No check-in found. Please check-in first.')),
        );
        return;
      }

      await _databaseService.saveCheckOut(
        documentId: documentId,
        learnedTopic: _learnedTopic,
        feedback: _feedback,
        checkoutLat: lat,
        checkoutLng: lng,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check-out completed successfully!')),
      );

      // Clear form
      _formKey.currentState!.reset();
      setState(() {
        _learnedTopic = '';
        _feedback = '';
        _satisfactionScore = 1;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving check-out data: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finish Class'),
        backgroundColor: const Color(0xFFB22222),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Class Finished! Let\'s reflect.',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'What did you learn today?',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onChanged: (value) => _learnedTopic = value,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter what you learned';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text('Class Satisfaction', style: TextStyle(fontSize: 16)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < _satisfactionScore ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                        ),
                        onPressed: () {
                          setState(() {
                            _satisfactionScore = index + 1;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Feedback',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onChanged: (value) => _feedback = value,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _getGpsAndScanQR,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB22222),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Scan QR & Checkout', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController controller = MobileScannerController();
  String? _detectedCode;
  Uint8List? _imageBytes;
  bool _isCapturing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: const Color(0xFFB22222),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  setState(() {
                    _detectedCode = barcode.rawValue;
                    _imageBytes = capture.image;
                  });
                  break;
                }
              }
            },
          ),
          if (_detectedCode != null)
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(8),
                color: Colors.black.withValues(alpha: 0.7),
                child: Text(
                  'Detected: $_detectedCode',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton(
                onPressed: _isCapturing ? null : _captureAndReturn,
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: const Color(0xFFB22222),
                child: _isCapturing
                    ? const CircularProgressIndicator(color: Color(0xFFB22222))
                    : const Icon(Icons.camera),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _captureAndReturn() async {
    setState(() {
      _isCapturing = true;
    });
    try {
      if (_imageBytes != null) {
        final base64Image = base64Encode(_imageBytes!);
        Navigator.of(context).pop({
          'code': _detectedCode,
          'image': base64Image,
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No image captured. Please scan a QR code first.')),
        );
        setState(() {
          _isCapturing = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error capturing image: $e')),
      );
      setState(() {
        _isCapturing = false;
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
