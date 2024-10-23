import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;
  String? _displayName;
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
    _loadUserName();
    _loadProfileImage();
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedName = prefs.getString('username');

    if (savedName!.isNotEmpty) {
      setState(() {
        _displayName = savedName;
        _nameController.text = _displayName!;
      });
    } else {
      setState(() {
        _displayName =
            _user?.displayName ?? _user?.email?.split('@')[0] ?? 'User';
        _nameController.text = _displayName!;
      });
    }
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    _imagePath = prefs.getString('profile_image');

    if (_imagePath != null && _imagePath!.isNotEmpty) {
      setState(() {
        _imageFile = File(_imagePath!);
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source);

      if (pickedFile != null) {
        if (!kIsWeb) {
          final file = File(pickedFile.path);
          if (file.existsSync()) {
            setState(() {
              _imageFile = file;
            });

            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('profile_image', pickedFile.path);
          } else {
            throw Exception('File does not exist.');
          }
        } else {
          // Handle web scenario
          setState(() {
            _imagePath = pickedFile.path;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _saveChanges() async {
    String newName = _nameController.text.trim();

    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a name.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _displayName = newName;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', _displayName!);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Changes saved successfully!'),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.pop(context, 'refresh'); // Pop after changes are saved
  }

  void _logout() async {
    await _auth.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SubsManager'),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, 'refresh');
          },
        ),
      ),
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(screenWidth * 0.04), // Dynamic padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (_) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.photo_library),
                            title: const Text('Choose from gallery'),
                            onTap: () {
                              _pickImage(ImageSource.gallery);
                              Navigator.pop(context);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.camera_alt),
                            title: const Text('Take a photo'),
                            onTap: () {
                              _pickImage(ImageSource.camera);
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
                child: CircleAvatar(
                  radius: screenHeight * 0.1, // Dynamic radius
                  backgroundImage: _imageFile != null
                      ? FileImage(_imageFile!)
                      : const AssetImage('default-profile.png')
                          as ImageProvider, // Use default image from assets
                ),
              ),
              SizedBox(height: screenHeight * 0.02), // Dynamic spacing
              Text(
                _displayName ?? 'User',
                style: TextStyle(
                  fontSize: screenHeight * 0.03, // Dynamic font size
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: screenHeight * 0.03), // Dynamic spacing
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
              ),
              SizedBox(height: screenHeight * 0.02), // Dynamic spacing
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding:
                        EdgeInsets.symmetric(vertical: screenHeight * 0.02),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                  ),
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              SizedBox(height: screenHeight * 0.01), // Dynamic spacing
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _logout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding:
                        EdgeInsets.symmetric(vertical: screenHeight * 0.02),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                  ),
                  child: const Text(
                    'Logout',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
