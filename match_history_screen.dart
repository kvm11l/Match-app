import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Do obsługi formatowania daty

import 'match_history_user.dart'; // Dodaj import nowego ekranu

class MatchHistoryScreen extends StatefulWidget {
  @override
  _MatchHistoryScreenState createState() => _MatchHistoryScreenState();
}

class _MatchHistoryScreenState extends State<MatchHistoryScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  DateTime? _startDate;
  DateTime? _endDate;

  bool showCaptain = true;
  bool showPlayer = true;
  bool showSpectator = true;
  bool showStatistician = true;

  bool filtersVisible = false; // Dodajemy kontrolę widoczności filtrów

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Historia meczów'),
      ),
      body: Column(
        children: [
          // Przełącznik do pokazywania/ukrywania filtrów
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Text('Pokaż filtry', style: TextStyle(fontSize: 16)),
                Switch(
                  value: filtersVisible,
                  onChanged: (value) {
                    setState(() {
                      filtersVisible = value;
                    });
                  },
                ),
              ],
            ),
          ),
          // Panel filtrów - rozwijany
          if (filtersVisible) ...[
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Filtracja ról
                    Row(
                      children: [
                        Text('Filtruj według ról:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Row(
                      children: [
                        Checkbox(
                          value: showCaptain,
                          onChanged: (value) {
                            setState(() {
                              showCaptain = value!;
                            });
                          },
                        ),
                        Text('Kapitan'),
                        Checkbox(
                          value: showPlayer,
                          onChanged: (value) {
                            setState(() {
                              showPlayer = value!;
                            });
                          },
                        ),
                        Text('Zawodnik'),
                      ],
                    ),
                    Row(
                      children: [
                        Checkbox(
                          value: showSpectator,
                          onChanged: (value) {
                            setState(() {
                              showSpectator = value!;
                            });
                          },
                        ),
                        Text('Widz'),
                        Checkbox(
                          value: showStatistician,
                          onChanged: (value) {
                            setState(() {
                              showStatistician = value!;
                            });
                          },
                        ),
                        Text('Statystyk'),
                      ],
                    ),

                    // Filtracja daty
                    Row(
                      children: [
                        Text('Filtruj według daty:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Row(
                      children: [
                        Text('Data początkowa:'),
                        IconButton(
                          icon: Icon(Icons.calendar_today),
                          onPressed: () async {
                            DateTime? pickedDate = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2101),
                            );
                            if (pickedDate != null && pickedDate != _startDate) {
                              setState(() {
                                _startDate = pickedDate;
                              });
                            }
                          },
                        ),
                        Expanded(
                          child: Text(
                            _startDate == null ? 'Wybierz datę' : DateFormat('yyyy-MM-dd').format(_startDate!),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text('Data końcowa:'),
                        IconButton(
                          icon: Icon(Icons.calendar_today),
                          onPressed: () async {
                            DateTime? pickedDate = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2101),
                            );
                            if (pickedDate != null && pickedDate != _endDate) {
                              setState(() {
                                _endDate = pickedDate;
                              });
                            }
                          },
                        ),
                        Expanded(
                          child: Text(
                            _endDate == null ? 'Wybierz datę' : DateFormat('yyyy-MM-dd').format(_endDate!),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          // Lista meczów
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('matches').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                var matches = snapshot.data!.docs;
                var userMatches = _getUserMatchesWithRoles(matches);

                // Filtrujemy mecze z odpowiednim statusem "Zakończony, potwierdzony" lub "Zakończony, niepotwierdzony"
                var filteredMatches = userMatches.where((match) {
                  String status = match['match']['status'];
                  bool roleMatches = (showCaptain && (match['role'] == 'Kapitan' || match['role'] == 'Kapitan Drużyny 1' || match['role'] == 'Kapitan Drużyny 2')) ||
                      (showPlayer && (match['role'] == 'Zawodnik' || match['role'] == 'Zawodnik Drużyny 1' || match['role'] == 'Zawodnik Drużyny 2')) ||
                      (showSpectator && match['role'] == 'Widz') ||
                      (showStatistician && match['role'] == 'Statystyk');

                  bool dateMatches = true;
                  if (_startDate != null) {
                    DateTime matchDate = (match['match']['matchDate'] as Timestamp).toDate();
                    dateMatches = matchDate.isAfter(_startDate!) && (_endDate == null || matchDate.isBefore(_endDate!));
                  }

                  return (status == 'Zakończony, potwierdzony' || status == 'Zakończony, niepotwierdzony') && roleMatches && dateMatches;
                }).toList();

                if (filteredMatches.isEmpty) {
                  return Center(child: Text('Nie brałeś udziału w żadnym meczu o wymaganym statusie.'));
                }

                return ListView.builder(
                  itemCount: filteredMatches.length,
                  itemBuilder: (context, index) {
                    var match = filteredMatches[index]['match'];
                    String userRole = filteredMatches[index]['role'];
                    String matchId = match['matchId'];
                    String team1Name = match['team1Name'];
                    String team2Name = match['team2Name'];
                    String status = match['status'];
                    Timestamp matchDate = match['matchDate'];
                    String team1Logo = match['team1Logo'];  // Zmieniono na team1Logo
                    String team2Logo = match['team2Logo'];  // Zmieniono na team2Logo
                    String matchLocation = match['location'];  // Zmieniono na match['location']

                    return ListTile(
                      title: Text('$team1Name vs $team2Name'),
                      subtitle: Text(
                        'Data: ${matchDate.toDate().toLocal().toString().split(' ')[0]}\nRola: $userRole\nStatus: $status',
                      ),
                      onTap: () {
                        // Nawigacja do ekranu MatchHistoryUserScreen z przekazaniem danych o meczu
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MatchHistoryUserScreen(
                              matchId: matchId,
                              team1Name: team1Name,
                              team2Name: team2Name,
                              team1Logo: team1Logo,  // Zmieniono na team1Logo
                              team2Logo: team2Logo,  // Zmieniono na team2Logo
                              matchDate: matchDate.toDate(),
                              matchLocation: matchLocation,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
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

      if (isCaptain1 || isCaptain2) {
        userMatches.add({'match': match, 'role': 'Kapitan'});
      } else if (isPlayer1 || isPlayer2) {
        userMatches.add({'match': match, 'role': 'Zawodnik'});
      }

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
