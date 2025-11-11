import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_screen.dart';
import 'available_match_screen.dart';
import 'manage_matches_screen.dart';
import 'user_search_screen.dart'; // Ekran wyszukiwania użytkowników
import 'create_match_screen.dart'; // Ekran tworzenia spotkania
import 'search_match_screen.dart';
import 'matches_screen.dart';
import 'user_statistics_screen.dart';
import 'profile_screen.dart'; // Import ekranu profilu
import 'random_match_screen.dart'; // Import ekranu dla losowego meczu
import 'match_history_screen.dart'; // Import ekranu dla historii meczy

class WelcomeScreen extends StatefulWidget {
  final User user;

  WelcomeScreen({required this.user});

  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserStatus();
  }

  Future<void> _fetchUserStatus() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .get();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print("Błąd pobierania danych użytkownika: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Witaj, ${widget.user.displayName ?? "Użytkowniku"}!'),
        actions: [
          IconButton(
            icon: Icon(Icons.person), // Ikona profilu
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => ProfileScreen(user: widget.user)), // Przejście do profilu
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, // Wyrównanie do lewej
            children: [
              // Przycisk wyszukiwania użytkowników
              _buildElevatedButton(
                context,
                Icons.search,
                'Szukaj użytkowników',
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => UserSearchScreen()),
                  );
                },
              ),
              SizedBox(height: 15),
              // Przycisk wyszukiwania meczów
              _buildElevatedButton(
                context,
                Icons.find_in_page,
                'Wyszukaj Mecz',
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SearchMatchScreen()),
                  );
                },
              ),
              SizedBox(height: 15),
              // Przycisk tworzenia spotkania
              _buildElevatedButton(
                context,
                Icons.add,
                'Stwórz spotkanie',
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CreateMatchScreen()),
                  );
                },
              ),
              SizedBox(height: 15),
              // Przycisk losowego meczu
              _buildElevatedButton(
                context,
                Icons.shuffle, // Ikona losowego meczu
                'Stwórz mecz losowy',
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => RandomMatchScreen()),
                  );
                },
              ),
              SizedBox(height: 15),
              // Przycisk dostępnych meczów
              _buildElevatedButton(
                context,
                Icons.list,
                'Dostępne Mecze',
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AvailableMatchesScreen()),
                  );
                },
              ),
              SizedBox(height: 15),
              // Przycisk do wyświetlania meczów
              _buildElevatedButton(
                context,
                Icons.schedule,
                'Moje Mecze / Harmonogram',
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => MatchesScreen()),
                  );
                },
              ),
              SizedBox(height: 15),
              // Przycisk statystyk użytkownika
              _buildElevatedButton(
                context,
                Icons.bar_chart,
                'Moje Statystyki',
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserStatisticsScreen(user: widget.user),
                    ),
                  );
                },
              ),
              SizedBox(height: 15),
              // Przycisk historii meczów
              _buildElevatedButton(
                context,
                Icons.history, // Ikona historii meczów
                'Historia meczy',
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => MatchHistoryScreen()),
                  );
                },
              ),
              SizedBox(height: 15),
              // Przycisk zarządzania meczami
              _buildElevatedButton(
                context,
                Icons.settings,
                'Zarządzaj meczami',
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ManageMatchesScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  ElevatedButton _buildElevatedButton(BuildContext context, IconData icon, String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: Size(double.infinity, 60), // Zwiększenie wysokości przycisku
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // Wyrównanie do boków
        children: [
          Row(
            children: [
              Icon(icon), // Ikona
              SizedBox(width: 8), // Przerwa między ikoną a tekstem
              Text(label),
            ],
          ),
          Icon(Icons.arrow_forward), // Strzałka po prawej stronie
        ],
      ),
    );
  }
}
