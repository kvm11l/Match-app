import 'package:app_firebase/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_screen.dart';
import 'settings_screen.dart'; // Import nowego ekranu

class ProfileScreen extends StatefulWidget {
  final User user;

  ProfileScreen({required this.user});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _firstName = '';
  String _lastName = '';
  bool _isAvailable = false;
  bool _isWillingToPlay = false;
  String _profilePictureUrl = '';

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .get();

      if (userDoc.exists) {
        setState(() {
          _firstName = userDoc['firstName'] ?? 'Nieznane Imię';
          _lastName = userDoc['lastName'] ?? 'Nieznane Nazwisko';
          _isAvailable = userDoc['isAvailable'] ?? false;
          _isWillingToPlay = userDoc['isWillingToPlay'] ?? false;
          _profilePictureUrl = userDoc['avatarUrl'] ?? 'https://via.placeholder.com/150';
        });
      } else {
        print("Dokument użytkownika nie istnieje.");
      }
    } catch (e) {
      print("Błąd pobierania danych użytkownika: $e");
    }
  }

  Future<void> _toggleAvailability() async {
    setState(() {
      _isAvailable = !_isAvailable;
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .update({'isAvailable': _isAvailable});
    } catch (e) {
      print("Błąd aktualizacji statusu dostępności: $e");
    }
  }

  Future<void> _toggleWillingnessToPlay() async {
    setState(() {
      _isWillingToPlay = !_isWillingToPlay;
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .update({'isWillingToPlay': _isWillingToPlay});
    } catch (e) {
      print("Błąd aktualizacji statusu 'Chętny do gry': $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profil'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundImage: _profilePictureUrl.isNotEmpty
                  ? NetworkImage(_profilePictureUrl)
                  : AssetImage('assets/default_profile.png') as ImageProvider,
            ),
            SizedBox(height: 20),
            Text(
              '${_firstName} ${_lastName}',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              widget.user.email ?? "Nieznany email",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _isAvailable ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Dostępny: ${_isAvailable ? "Tak" : "Nie"}',
                  style: TextStyle(fontSize: 16),
                ),
                Spacer(),
                Switch(
                  value: _isAvailable,
                  onChanged: (val) => _toggleAvailability(),
                ),
              ],
            ),
            Row(
              children: [
                Icon(
                  Icons.sports_soccer,
                  color: _isWillingToPlay ? Colors.green : Colors.grey,
                ),
                SizedBox(width: 8),
                Text(
                  'Chętny do gry: ${_isWillingToPlay ? "Tak" : "Nie"}',
                  style: TextStyle(fontSize: 16),
                ),
                Spacer(),
                Switch(
                  value: _isWillingToPlay,
                  onChanged: (val) => _toggleWillingnessToPlay(),
                ),
              ],
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => SettingsScreen(user: widget.user),
                  ),
                );
              },
              icon: Icon(Icons.settings),
              label: Text('Ustawienia'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50), // Pełna szerokość i stała wysokość
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8), // Lekko zaokrąglone rogi
                ),
                textStyle: TextStyle(fontSize: 16),
              ),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                FirebaseAuth.instance.signOut(); // Wylogowanie użytkownika
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => LoginScreen()), // Przejście do ekranu logowania
                      (Route<dynamic> route) => false, // Usuń wszystkie poprzednie trasy
                );
              },
              child: Text('Wyloguj się'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50), // Pełna szerokość i stała wysokość
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8), // Lekko zaokrąglone rogi
                ),
                textStyle: TextStyle(fontSize: 16),
              ),
            ),

          ],
        ),
      ),
    );
  }
}
