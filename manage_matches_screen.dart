import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'capitan_screen.dart';
import 'match_details_screen.dart';
import 'player_screen.dart';
import 'spectator_screen.dart';
import 'statistician_screen.dart';

class ManageMatchesScreen extends StatefulWidget {
  @override
  _ManageMatchesScreenState createState() => _ManageMatchesScreenState();
}

class _ManageMatchesScreenState extends State<ManageMatchesScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  // Zmienna do przechowywania wybranych filtrów
  bool showCaptain = true;
  bool showPlayer = true;
  bool showSpectator = true;
  bool showStatistician = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Zarządzaj meczami'),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('matches').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          var matches = snapshot.data!.docs;
          var userMatches = _getUserMatchesWithRoles(matches);

          // Filtrujemy mecze w zależności od wybranych opcji
          var filteredMatches = userMatches.where((match) {
            String role = match['role'];
            return (showCaptain && (role == 'Kapitan Drużyny 1' || role == 'Kapitan Drużyny 2')) ||
                (showPlayer && (role == 'Zawodnik Drużyny 1' || role == 'Zawodnik Drużyny 2')) ||
                (showSpectator && role == 'Widz') ||
                (showStatistician && role == 'Statystyk');
          }).toList();

          if (filteredMatches.isEmpty) {
            return Center(child: Text('Nie bierzesz udziału w żadnym meczu.'));
          }

          return ListView.builder(
            itemCount: filteredMatches.length,
            itemBuilder: (context, index) {
              var match = filteredMatches[index]['match'];
              String userRole = filteredMatches[index]['role'];
              String matchId = match['matchId'];

              return ListTile(
                title: Text('${match['team1Name']} vs ${match['team2Name']}'),
                subtitle: Text(
                  'Data: ${match['matchDate']?.toDate().toLocal().toString().split(' ')[0]}\nRola: $userRole',
                ),
                onTap: () {
                  if (userRole == 'Kapitan Drużyny 1' || userRole == 'Kapitan Drużyny 2') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CaptainScreen(
                          match: match.data() as Map<String, dynamic>,
                          team: userRole == 'Kapitan Drużyny 1' ? 'team1' : 'team2',
                          teamCaptainEmail: user!.email!,
                          // matchId: matchId,
                        ),
                      ),
                    );
                  } else if (userRole == 'Zawodnik Drużyny 1' || userRole == 'Zawodnik Drużyny 2') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PlayerScreen(
                          matchId: matchId,
                        ),
                      ),
                    );
                  } else if (userRole == 'Widz') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SpectatorScreen(
                          matchId: matchId,
                        ),
                      ),
                    );
                  } else if (userRole == 'Statystyk') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StatisticianScreen(
                          matchId: matchId,
                        ),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MatchDetailsScreen(
                          match: match.data() as Map<String, dynamic>,
                          loggedUser: user!.email!,
                        ),
                      ),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Filtruj mecze'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                title: Text('Kapitan'),
                value: showCaptain,
                onChanged: (bool? value) {
                  setState(() {
                    showCaptain = value ?? true;
                  });
                },
              ),
              CheckboxListTile(
                title: Text('Zawodnik'),
                value: showPlayer,
                onChanged: (bool? value) {
                  setState(() {
                    showPlayer = value ?? true;
                  });
                },
              ),
              CheckboxListTile(
                title: Text('Widz'),
                value: showSpectator,
                onChanged: (bool? value) {
                  setState(() {
                    showSpectator = value ?? true;
                  });
                },
              ),
              CheckboxListTile(
                title: Text('Statystyk'),
                value: showStatistician,
                onChanged: (bool? value) {
                  setState(() {
                    showStatistician = value ?? true;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Zamknij'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  List<Map<String, dynamic>> _getUserMatchesWithRoles(List<QueryDocumentSnapshot> matches) {
    List<Map<String, dynamic>> userMatches = [];
    String userEmail = user!.email!;

    for (var match in matches) {
      bool isCaptain1 = match['team1Captain'] == userEmail;
      bool isCaptain2 = match['team2Captain'] == userEmail;
      bool isPlayer1 = match['team1'].contains(userEmail);
      bool isPlayer2 = match['team2'].contains(userEmail);
      bool isSpectator = match['spectators'] != null && match['spectators'].contains(userEmail);
      bool isStatistician = match['statisticians'] != null && match['statisticians'].contains(userEmail);

      // Jeśli użytkownik jest kapitanem i jednocześnie zawodnikiem, dodajemy tylko rolę kapitana.
      if (isCaptain1) {
        userMatches.add({'match': match, 'role': 'Kapitan Drużyny 1'});
      } else if (isCaptain2) {
        userMatches.add({'match': match, 'role': 'Kapitan Drużyny 2'});
      }
      // Jeśli użytkownik nie jest kapitanem, ale jest zawodnikiem, dodajemy rolę zawodnika.
      else if (isPlayer1) {
        userMatches.add({'match': match, 'role': 'Zawodnik Drużyny 1'});
      } else if (isPlayer2) {
        userMatches.add({'match': match, 'role': 'Zawodnik Drużyny 2'});
      }

      // Dodajemy rolę widza i statystyka osobno, jeśli użytkownik pełni obie role.
      if (isSpectator) {
        userMatches.add({'match': match, 'role': 'Widz'});
      }
      if (isStatistician) {
        userMatches.add({'match': match, 'role': 'Statystyk'});
      }
    }

    return userMatches;
  }
}
