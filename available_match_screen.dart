import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'match_details_screen.dart';

class AvailableMatchesScreen extends StatefulWidget {
  @override
  _AvailableMatchesScreenState createState() => _AvailableMatchesScreenState();
}

class _AvailableMatchesScreenState extends State<AvailableMatchesScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  List<Map<String, dynamic>> _availableMatches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAvailableMatches();
  }

  Future<void> _fetchAvailableMatches() async {
    try {
      QuerySnapshot matchesSnapshot = await FirebaseFirestore.instance
          .collection('matches')
          .where('canPlayersJoin', isEqualTo: true)
          .where('status', isEqualTo: 'Nierozpoczęty') // Dodano filtrację statusu
          .get();

      List<Map<String, dynamic>> tempAvailableMatches = [];
      String userEmail = user!.email!;

      for (var doc in matchesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // Dodaj ID dokumentu do danych meczu

        // Sprawdź, czy użytkownik jest już uczestnikiem meczu
        List<dynamic> team1 = data['team1'] ?? [];
        List<dynamic> team2 = data['team2'] ?? [];
        List<dynamic> spectators = data['spectators'] ?? [];
        List<dynamic> statisticians = data['statisticians'] ?? [];

        // Sprawdź, czy e-mail użytkownika znajduje się w którejkolwiek z grup
        if (!(team1.contains(userEmail) ||
            team2.contains(userEmail) ||
            spectators.contains(userEmail) ||
            statisticians.contains(userEmail))) {
          tempAvailableMatches.add(data);
        }
      }

      setState(() {
        _availableMatches = tempAvailableMatches;
        _isLoading = false;
      });
    } catch (e) {
      print("Błąd pobierania meczów: $e");
    }
  }

  Future<void> _showTeamSelectionDialog(BuildContext context, Map<String, dynamic> match) async {
    // Pokaż dialog z wyborem drużyny, widza lub statystyka
    String? selectedOption = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Dołącz do meczu"),
          content: Text("Wybierz, do kogo chcesz dołączyć:"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop("team1"); // Zwróć wybór "team1"
              },
              child: Text("Drużyna 1"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop("team2"); // Zwróć wybór "team2"
              },
              child: Text("Drużyna 2"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop("spectator"); // Zwróć wybór "spectator"
              },
              child: Text("Widz"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop("statistician"); // Zwróć wybór "statistician"
              },
              child: Text("Statystyk"),
            ),
          ],
        );
      },
    );

    // Sprawdź, czy użytkownik wybrał opcję, czy zamknął dialog
    if (selectedOption != null) {
      await _joinMatch(context, match, selectedOption); // Dołącz do wybranej opcji
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie wybrano opcji')),
      );
    }
  }

  Future<void> _joinMatch(BuildContext context, Map<String, dynamic> match, String selectedOption) async {
    try {
      String userEmail = user!.email!;
      String matchId = match['id'];  // Pobierz ID dokumentu

      // Pobierz aktualne dane meczu
      DocumentSnapshot matchDoc = await FirebaseFirestore.instance
          .collection('matches')
          .doc(matchId)
          .get();

      if (!matchDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mecz nie istnieje')),
        );
        return;
      }

      // Aktualizuj odpowiednią listę w zależności od wyboru
      if (selectedOption == 'team1' || selectedOption == 'team2') {
        List<dynamic> team1 = match['team1'] ?? [];
        List<dynamic> team2 = match['team2'] ?? [];

        if (selectedOption == 'team1') {
          if (team1.length < 11) {
            team1.add(userEmail);
            await FirebaseFirestore.instance
                .collection('matches')
                .doc(matchId)
                .update({'team1': team1});
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Dołączyłeś do Drużyny 1')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Brak miejsc w Drużynie 1')),
            );
          }
        } else if (selectedOption == 'team2') {
          if (team2.length < 11) {
            team2.add(userEmail);
            await FirebaseFirestore.instance
                .collection('matches')
                .doc(matchId)
                .update({'team2': team2});
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Dołączyłeś do Drużyny 2')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Brak miejsc w Drużynie 2')),
            );
          }
        }
      } else if (selectedOption == 'spectator') {
        List<dynamic> spectators = match['spectators'] ?? [];
        spectators.add(userEmail);
        await FirebaseFirestore.instance
            .collection('matches')
            .doc(matchId)
            .update({'spectators': spectators});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dołączyłeś jako widz')),
        );
      } else if (selectedOption == 'statistician') {
        List<dynamic> statisticians = match['statisticians'] ?? [];
        statisticians.add(userEmail);
        await FirebaseFirestore.instance
            .collection('matches')
            .doc(matchId)
            .update({'statisticians': statisticians});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dołączyłeś jako statystyk')),
        );
      }
    } catch (e) {
      print("Błąd dołączania do meczu: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się dołączyć do meczu')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dostępne Mecze'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _availableMatches.isEmpty
          ? Center(child: Text('Brak dostępnych meczów.'))
          : ListView.builder(
        itemCount: _availableMatches.length,
        itemBuilder: (context, index) {
          var match = _availableMatches[index];

          return Card(
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: ListTile(
              title: Text('${match['team1Name']} vs ${match['team2Name']}'),
              subtitle: Text('Data: ${match['matchDate']?.toDate().toLocal().toString().split(' ')[0]}'),
              trailing: ElevatedButton(
                onPressed: () {
                  _showTeamSelectionDialog(context, match);
                },
                child: Text('Dołącz do meczu'),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MatchDetailsScreen(
                      match: match,
                      loggedUser: user!.email!, // Przekazywanie e-maila zalogowanego użytkownika
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
