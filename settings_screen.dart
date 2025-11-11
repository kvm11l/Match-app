import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class SettingsScreen extends StatefulWidget {
  final User user;

  SettingsScreen({required this.user});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _shareData = false;
  bool _shareInstagram = false;
  bool _shareTwitter = false;
  String _instagramProfile = '';
  String _twitterProfile = '';
  String _avatarUrl = '';  // URL do obrazu awatara
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchUserSettings();
  }

  Future<void> _fetchUserSettings() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .get();

      if (userDoc.exists) {
        setState(() {
          _shareData = userDoc['shareData'] ?? false;
          _shareInstagram = userDoc['shareInstagram'] ?? false;
          _shareTwitter = userDoc['shareTwitter'] ?? false;
          _instagramProfile = _shareInstagram ? (userDoc['instagramProfile'] ?? '') : '';
          _twitterProfile = _shareTwitter ? (userDoc['twitterProfile'] ?? '') : '';
          _avatarUrl = userDoc['avatarUrl'] ?? 'https://firebasestorage.googleapis.com/v0/b/loginapp-796b3.appspot.com/o/avatars%2Fdefault_avatar.png?alt=media&token=a773a5a7-71f3-4465-9512-21fc83a37a82';
        });
      }
    } catch (e) {
      print("Błąd pobierania ustawień użytkownika: $e");
    }
  }

  Future<void> _saveSettings() async {
    if (_shareData) {
      if (!_shareInstagram && !_shareTwitter) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Wybierz przynajmniej jedno pole (Instagram lub Twitter)')),
        );
        return;
      }
      if ((_shareInstagram && _instagramProfile.isEmpty) || (_shareTwitter && _twitterProfile.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Uzupełnij profil na Instagramie lub Twitterze')),
        );
        return;
      }
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .update({
        'shareData': _shareData,
        'shareInstagram': _shareInstagram,
        'instagramProfile': _shareInstagram ? _instagramProfile : '',
        'shareTwitter': _shareTwitter,
        'twitterProfile': _shareTwitter ? _twitterProfile : '',
        'avatarUrl': _avatarUrl,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ustawienia zapisane!')),
      );
    } catch (e) {
      print("Błąd zapisywania ustawień: $e");
    }
  }

  Future<void> _selectAndUploadAvatar() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      try {
        // Prześlij obraz do Firebase Storage
        final ref = FirebaseStorage.instance
            .ref()
            .child('avatars')
            .child('${widget.user.uid}.jpg');
        await ref.putFile(File(pickedFile.path));

        // Pobierz adres URL i zaktualizuj Firestore
        final avatarUrl = await ref.getDownloadURL();
        setState(() {
          _avatarUrl = avatarUrl;
        });

        // Zapisz URL awatara w Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.user.uid)
            .update({'avatarUrl': _avatarUrl});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Awatar zaktualizowany!')),
        );
      } catch (e) {
        print("Błąd podczas aktualizacji awatara: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ustawienia'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _selectAndUploadAvatar,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: _avatarUrl.isNotEmpty
                          ? NetworkImage(_avatarUrl)
                          : AssetImage('assets/images/default_avatar.png') as ImageProvider,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Kliknij, aby wybrać i zmienić awatar',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Text(
                  'Czy chcesz przekazać swoje dane?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Spacer(),
                Switch(
                  value: _shareData,
                  onChanged: (val) {
                    setState(() {
                      _shareData = val;
                      if (!val) {
                        _shareInstagram = false;
                        _shareTwitter = false;
                        _instagramProfile = '';
                        _twitterProfile = '';
                      }
                    });
                  },
                ),
              ],
            ),
            if (_shareData) ...[
              Row(
                children: [
                  Text(
                    'Udostępnij Instagram',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Spacer(),
                  Switch(
                    value: _shareInstagram,
                    onChanged: (val) {
                      setState(() {
                        _shareInstagram = val;
                        if (!val) _instagramProfile = '';
                      });
                    },
                  ),
                ],
              ),
              if (_shareInstagram)
                TextField(
                  onChanged: (val) => _instagramProfile = val,
                  controller: TextEditingController(text: _instagramProfile),
                  decoration: InputDecoration(
                    labelText: 'Nazwa profilu na Instagramie',
                    border: OutlineInputBorder(),
                  ),
                ),
              SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    'Udostępnij Twitter',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Spacer(),
                  Switch(
                    value: _shareTwitter,
                    onChanged: (val) {
                      setState(() {
                        _shareTwitter = val;
                        if (!val) _twitterProfile = '';
                      });
                    },
                  ),
                ],
              ),
              if (_shareTwitter)
                TextField(
                  onChanged: (val) => _twitterProfile = val,
                  controller: TextEditingController(text: _twitterProfile),
                  decoration: InputDecoration(
                    labelText: 'Nazwa profilu na Twitterze',
                    border: OutlineInputBorder(),
                  ),
                ),
            ],
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveSettings,
              child: Text('Zapisz ustawienia'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                textStyle: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
