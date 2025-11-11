import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Pakiet do formatowania dat
import 'package:url_launcher/url_launcher.dart'; // Import url_launcher
import 'match_details_screen.dart'; // Import ekranu szczegółów meczu

class MatchesScreen extends StatefulWidget {
  @override
  _MatchesScreenState createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  List<Map<String, dynamic>> _matches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserMatches();
  }

  Future<void> _fetchUserMatches() async {
    if (user == null) return;

    try {
      String userEmail = user!.email!;

      // Pobranie meczów z dodatkowym filtrem "status == 'Nierozpoczęty'"
      QuerySnapshot matchesSnapshot = await FirebaseFirestore.instance
          .collection('matches')
          .where('team1', arrayContains: userEmail)
          .where('status', isEqualTo: 'Nierozpoczęty') // Filtrowanie po statusie
          .get();

      QuerySnapshot team2MatchesSnapshot = await FirebaseFirestore.instance
          .collection('matches')
          .where('team2', arrayContains: userEmail)
          .where('status', isEqualTo: 'Nierozpoczęty') // Filtrowanie po statusie
          .get();

      QuerySnapshot spectatorsMatchesSnapshot = await FirebaseFirestore.instance
          .collection('matches')
          .where('spectators', arrayContains: userEmail)
          .where('status', isEqualTo: 'Nierozpoczęty') // Filtrowanie po statusie
          .get();

      QuerySnapshot statisticiansMatchesSnapshot = await FirebaseFirestore.instance
          .collection('matches')
          .where('statisticians', arrayContains: userEmail)
          .where('status', isEqualTo: 'Nierozpoczęty') // Filtrowanie po statusie
          .get();

      // Łączenie wyników z różnych kolekcji
      List<QueryDocumentSnapshot> allMatchesDocs = [
        ...matchesSnapshot.docs,
        ...team2MatchesSnapshot.docs,
        ...spectatorsMatchesSnapshot.docs,
        ...statisticiansMatchesSnapshot.docs
      ];

      // Usuwanie duplikatów na podstawie identyfikatora dokumentu
      final uniqueMatches = allMatchesDocs.toSet().toList();

      setState(() {
        _matches = uniqueMatches.map((doc) => doc.data() as Map<String, dynamic>).toList();
        _isLoading = false;
      });
    } catch (e) {
      print("Błąd pobierania meczów: $e");
    }
  }


  String _getUserRole(Map<String, dynamic> match, String userEmail) {
    if (match['team1Captain'] == userEmail) {
      return 'Kapitan (Drużyna 1)';
    } else if (match['team2Captain'] == userEmail) {
      return 'Kapitan (Drużyna 2)';
    } else if (match['team1'].contains(userEmail)) {
      return 'Zawodnik (Drużyna 1)';
    } else if (match['team2'].contains(userEmail)) {
      return 'Zawodnik (Drużyna 2)';
    } else if (match['spectators'].contains(userEmail)) {
      return 'Widz';
    } else if (match['statisticians'].contains(userEmail)) {
      return 'Statystyk';
    }
    return 'Nieznana rola';
  }

  Future<void> _addToGoogleCalendar(Map<String, dynamic> match) async {
    try {
      String matchTitle = '${match['team1Name']} vs ${match['team2Name']}';
      String location = match['location'] ?? 'Nieznana lokalizacja';
      DateTime matchDate = match['matchDate'].toDate();
      DateTime matchEndDate = matchDate.add(Duration(hours: 2));

      String startTime = DateFormat('yyyyMMddTHHmmss').format(matchDate.toUtc());
      String endTime = DateFormat('yyyyMMddTHHmmss').format(matchEndDate.toUtc());

      Uri calendarUri = Uri.parse(
          'https://www.google.com/calendar/render?action=TEMPLATE&text=$matchTitle&dates=$startTime/$endTime&details=Mecz+piłki+nożnej&location=$location&sf=true&output=xml');

      if (!await launchUrl(calendarUri, mode: LaunchMode.externalApplication)) {
        throw 'Nie udało się otworzyć linku';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd dodawania wydarzenia: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Moje Mecze'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _matches.isEmpty
          ? Center(child: Text('Nie bierzesz udziału w żadnych meczach.'))
          : Padding(
        padding: const EdgeInsets.all(8.0), // Dodaj padding do ListView
        child: ListView.builder(
          itemCount: _matches.length,
          itemBuilder: (context, index) {
            var match = _matches[index];
            String userEmail = user!.email!;
            String userRole = _getUserRole(match, userEmail);

            return Card( // Użyj Card, aby dodać trochę marginesu i wizualnej separacji
              elevation: 2,
              margin: EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  GestureDetector( // Dodaj GestureDetector, aby umożliwić przejście do szczegółów meczu
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MatchDetailsScreen(
                            match: match,
                            loggedUser: userEmail, // Przekazywanie e-maila zalogowanego użytkownika
                          ),
                        ),
                      );
                    },
                    child: ListTile(
                      title: Text('Mecz: ${match['team1Name']} vs ${match['team2Name']}'),
                      subtitle: Text('Data: ${match['matchDate']?.toDate().toLocal().toString().split(' ')[0]}'),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Lokalizacja: ${match['location'] ?? 'Nieznana'}'),
                        Text('Twoja rola: $userRole'),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                    child: ElevatedButton(
                      onPressed: () => _addToGoogleCalendar(match),
                      child: Text('Dodaj do Kalendarza Google'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
