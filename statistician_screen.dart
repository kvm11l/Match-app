import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StatisticianScreen extends StatelessWidget {
  final String matchId;

  StatisticianScreen({required this.matchId});

  void _startMatch(String matchId) async {
    // Ustawienie statusu meczu i czasu rozpoczęcia
    await FirebaseFirestore.instance.collection('matches').doc(matchId).update({
      'status': 'Trwa',
      'startTime': Timestamp.now(), // Czas rozpoczęcia meczu
    });
  }


  void _endMatch(String matchId) async {
    try {
      // Pobranie dokumentu meczu
      DocumentSnapshot matchSnapshot = await FirebaseFirestore.instance.collection('matches').doc(matchId).get();
      Map<String, dynamic>? matchData = matchSnapshot.data() as Map<String, dynamic>?;

      if (matchData == null) {
        print("Brak danych meczu o podanym ID: $matchId");
        return;
      }

      // Pobranie startTime
      Timestamp? startTime = matchData['startTime'];
      if (startTime == null) {
        print("Brak informacji o czasie rozpoczęcia meczu (startTime).");
        return;
      }

      // Obliczenie całkowitego czasu trwania meczu
      DateTime startDateTime = startTime.toDate();
      DateTime endDateTime = DateTime.now();
      Duration totalDuration = endDateTime.difference(startDateTime);

      // Zapisanie statusu meczu i czasu trwania
      await FirebaseFirestore.instance.collection('matches').doc(matchId).update({
        'status': 'Zakończony, niepotwierdzony',
        'endTime': Timestamp.now(), // Czas zakończenia
        'totalDuration': totalDuration.inSeconds, // Czas trwania w sekundach
      });

      // Pobranie statystyk zawodników
      Map<String, dynamic> playerStats = matchData['stats'] ?? {};

      for (String sanitizedEmail in playerStats.keys) {
        // Sprawdzenie, czy klucz wygląda na email (zastąpiono '.' przez '_')
        if (!sanitizedEmail.contains('_')) {
          print("Pominięto drużynowe statystyki dla klucza: $sanitizedEmail");
          continue;
        }

        var stats = playerStats[sanitizedEmail];

        // Sprawdzenie, czy `stats` dla zawodnika jest typu `Map<String, dynamic>`
        if (stats is Map<String, dynamic>) {
          int goals = stats['goals'] ?? 0;
          int assists = stats['assists'] ?? 0;
          int yellowCards = stats['yellowCards'] ?? 0;
          int redCards = stats['redCards'] ?? 0;
          int shotsOnTarget = stats['shotsOnTarget'] ?? 0;
          int shotsOffTarget = stats['shotsOffTarget'] ?? 0;
          int dribbles = stats['dribbles'] ?? 0;
          int fouls = stats['fouls'] ?? 0;

          // Przywrócenie oryginalnego adresu e-mail
          String playerEmail = sanitizedEmail.replaceAll('_', '.');

          // Aktualizacja statystyk użytkownika
          _updateUserStats(playerEmail, goals, assists, yellowCards, redCards, shotsOnTarget, shotsOffTarget, dribbles, fouls);
        } else {
          print("Niespodziewany format danych w `stats` dla zawodnika $sanitizedEmail.");
        }
      }

      print("Mecz zakończony, czas trwania zapisany i statystyki użytkowników zostały zaktualizowane.");
    } catch (e) {
      print("Błąd podczas zakończania meczu i aktualizacji statystyk: $e");
    }
  }


  void _updateUserStats(String email, int goals, int assists, int yellowCards, int redCards, int shotsOnTarget, int shotsOffTarget, int dribbles, int fouls) async {
    try {
      // Szukanie dokumentu użytkownika na podstawie adresu email
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        print("Użytkownik $email nie istnieje.");
        return;
      }

      // Pobranie odniesienia do dokumentu użytkownika
      DocumentReference userRef = querySnapshot.docs.first.reference;

      // Przeprowadzenie transakcji aktualizacji statystyk użytkownika
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot userSnapshot = await transaction.get(userRef);
        var userData = userSnapshot.data() as Map<String, dynamic>;

        // Pobieranie istniejących danych użytkownika
        int currentMatches = userData['matches'] ?? 0;
        int currentGoals = userData['goals'] ?? 0;
        int currentAssists = userData['assists'] ?? 0;
        int currentYellowCards = userData['yellowCards'] ?? 0;
        int currentRedCards = userData['redCards'] ?? 0;
        int currentShotsOnTarget = userData['shotsOnTarget'] ?? 0;
        int currentShotsOffTarget = userData['shotsOffTarget'] ?? 0;
        int currentDribbles = userData['dribbles'] ?? 0;
        int currentFouls = userData['fouls'] ?? 0;

        // Zaktualizowanie wartości
        int newMatches = currentMatches + 1;
        int newGoals = currentGoals + goals;
        int newAssists = currentAssists + assists;
        int newYellowCards = currentYellowCards + yellowCards;
        int newRedCards = currentRedCards + redCards;
        int newShotsOnTarget = currentShotsOnTarget + shotsOnTarget;
        int newShotsOffTarget = currentShotsOffTarget + shotsOffTarget;
        int newDribbles = currentDribbles + dribbles;
        int newFouls = currentFouls + fouls;

        // Aktualizacja dokumentu użytkownika
        transaction.update(userRef, {
          'matches': newMatches,
          'goals': newGoals,
          'assists': newAssists,
          'yellowCards': newYellowCards,
          'redCards': newRedCards,
          'shotsOnTarget': newShotsOnTarget,
          'shotsOffTarget': newShotsOffTarget,
          'dribbles': newDribbles,
          'fouls': newFouls,
        });
      });

      print("Statystyki użytkownika $email zostały zaktualizowane.");
    } catch (e) {
      print("Błąd podczas aktualizacji statystyk użytkownika: $e");
    }
  }

  Future<String> fetchUserName(String email) async {
    try {
      var userDoc = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: email).get();
      if (userDoc.docs.isNotEmpty) {
        var userData = userDoc.docs.first.data();
        return '${userData['firstName']} ${userData['lastName']}';
      } else {
        return email; // Jeśli użytkownik nie istnieje, zwróć email.
      }
    } catch (e) {
      print('Error fetching user name: $e');
      return email; // W razie błędu zwróć email.
    }
  }


  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4, // Liczba zakładek
      child: Scaffold(
        appBar: AppBar(
          title: Text('Statystyk'),
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('matches').doc(matchId).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Center(child: Text('Nie znaleziono meczu.'));
            }

            var matchData = snapshot.data!.data() as Map<String, dynamic>;

            // Wyciąganie danych z matchData
            String team1LogoUrl = matchData['team1Logo'];
            String team2LogoUrl = matchData['team2Logo'];
            String team1Name = matchData['team1Name'];
            String team2Name = matchData['team2Name'];
            DateTime matchDate = matchData['matchDate'].toDate();
            String matchLocation = matchData['location'];

            // Składy drużyn
            List<dynamic> team1Players = matchData['team1'] ?? [];
            List<dynamic> team2Players = matchData['team2'] ?? [];
            List<dynamic> goalScorers = matchData['goalScorers'] ?? [];
            List<dynamic> team1StartingPlayers = matchData['team1StartingPlayers'] ?? [];
            List<dynamic> team1BenchPlayers = matchData['team1BenchPlayers'] ?? [];
            List<dynamic> team2StartingPlayers = matchData['team2StartingPlayers'] ?? [];
            List<dynamic> team2BenchPlayers = matchData['team2BenchPlayers'] ?? [];


            String matchScore = '${matchData['team1Score'] ?? 0} - ${matchData['team2Score'] ?? 0}';

            // Statystyki zawodników
            Map<String, dynamic> stats = matchData['stats'] ?? {};

            // Wyświetlanie statusu meczu
            String matchStatus = matchData['status'] ?? 'Nierozpoczęty';

            return Column(
              children: [
                // Wyświetlanie informacji o meczu
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          // Logo i nazwa drużyny 1
                          Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(50.0),
                                child: Image.network(
                                  team1LogoUrl,
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              SizedBox(height: 8),
                              Tooltip(
                                message: team1Name,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: 120),
                                  child: Text(
                                    team1Name,
                                    overflow: TextOverflow.ellipsis,
                                    softWrap: false,
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Wynik meczu
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              matchScore,
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                          ),
                          // Logo i nazwa drużyny 2
                          Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(50.0),
                                child: Image.network(
                                  team2LogoUrl,
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              SizedBox(height: 8),
                              Tooltip(
                                message: team2Name,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: 120),
                                  child: Text(
                                    team2Name,
                                    overflow: TextOverflow.ellipsis,
                                    softWrap: false,
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 15),
                      // Wyświetlanie daty, godziny i miejsca meczu
                      Column(
                        children: [
                          Text(
                            'Data: ${matchDate.toLocal().toString().split(' ')[0]}',
                            style: TextStyle(fontSize: 15),
                          ),
                          Text(
                            'Godzina: ${matchDate.hour}:${matchDate.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(fontSize: 15),
                          ),
                          Text(
                            'Miejsce: $matchLocation',
                            style: TextStyle(fontSize: 15),
                          ),
                          // Wyświetlanie statusu meczu
                          Text(
                            'Status meczu: $matchStatus',
                            style: TextStyle(fontSize: 15),
                          ),

                          if (matchStatus == 'Trwa')
                            MatchTimer(matchId: matchId), // Wyświetlanie czasu na żywo
                          if (matchStatus != 'Trwa')
                            FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance.collection('matches').doc(matchId).get(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return CircularProgressIndicator();
                                }

                                if (!snapshot.hasData || !snapshot.data!.exists) {
                                  return Text('Brak danych meczu');
                                }

                                Map<String, dynamic> matchData = snapshot.data!.data() as Map<String, dynamic>;
                                int? totalDuration = matchData['totalDuration'];

                                if (totalDuration == null) {
                                  return Text('Czas trwania meczu: brak danych', style: TextStyle(fontSize: 15));
                                }

                                // Formatowanie czasu trwania
                                Duration duration = Duration(seconds: totalDuration);
                                String formattedDuration = '${duration.inMinutes} minut ${duration.inSeconds.remainder(60)} sekund';

                                return Text('Czas trwania meczu: $formattedDuration', style: TextStyle(fontSize: 16));
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Zakładki ze składami drużyn i statystykami
                Expanded(
                  child: Column(
                    children: [
                      TabBar(
                        tabs: [
                          Tab(text: 'Skład Drużyny 1'),
                          Tab(text: 'Skład Drużyny 2'),
                          Tab(text: 'Statystyki'),
                          Tab(text: 'Szczegóły'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // Skład Drużyny 1
                            SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Przyciski do edytowania statystyk
                                  ElevatedButton(
                                    onPressed: matchStatus == 'Trwa'
                                        ? () {
                                      _showEditTeamStatsDialog(context, 'Drużyna 1', matchId);
                                    }
                                        : null,
                                    child: Text('Edytuj statystyki zespołu 1'),
                                  ),
                                  SizedBox(height: 10),
                                  if (team1StartingPlayers.isEmpty && team1BenchPlayers.isEmpty)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Kapitan nie wybrał jeszcze składu dla Drużyny 1.',
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
                                        ),
                                        SizedBox(height: 8),
                                        Text('Uczestnicy Drużyny 1:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                        ListView.builder(
                                          shrinkWrap: true,
                                          physics: NeverScrollableScrollPhysics(),
                                          itemCount: team1Players.length,
                                          itemBuilder: (context, index) {
                                            String playerEmail = team1Players[index];
                                            String sanitizedEmail = playerEmail.replaceAll('.', '_');
                                            String playerStats = stats[sanitizedEmail] != null
                                                ? 'Gole: ${stats[sanitizedEmail]['goals']}, Asysty: ${stats[sanitizedEmail]['assists']}'
                                                : 'Brak danych';

                                            return FutureBuilder<String>(
                                              future: fetchUserName(playerEmail),
                                              builder: (context, snapshot) {
                                                if (snapshot.connectionState == ConnectionState.waiting) {
                                                  return ListTile(
                                                    title: Text('Ładowanie...'),
                                                    leading: CircularProgressIndicator(),
                                                  );
                                                }
                                                String playerName = snapshot.data ?? playerEmail;
                                                return ListTile(
                                                  title: Text('$playerName - $playerStats'),
                                                  leading: Icon(Icons.person),
                                                  onTap: matchStatus == 'Trwa'
                                                      ? () {
                                                    _showStatsDialog(context, matchId, playerEmail, stats[sanitizedEmail] ?? {});
                                                  }
                                                      : null,
                                                );
                                              },
                                            );
                                          },
                                        ),
                                      ],
                                    )
                                  else ...[
                                    Text(
                                      'Pierwszy skład Drużyny 1:',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics: NeverScrollableScrollPhysics(),
                                      itemCount: team1StartingPlayers.length,
                                      itemBuilder: (context, index) {
                                        String playerEmail = team1StartingPlayers[index];
                                        String sanitizedEmail = playerEmail.replaceAll('.', '_');
                                        String playerStats = stats[sanitizedEmail] != null
                                            ? 'Gole: ${stats[sanitizedEmail]['goals']}, Asysty: ${stats[sanitizedEmail]['assists']}'
                                            : 'Brak danych';
                                        return FutureBuilder<String>(
                                          future: fetchUserName(playerEmail),
                                          builder: (context, snapshot) {
                                            if (snapshot.connectionState == ConnectionState.waiting) {
                                              return ListTile(
                                                title: Text('Ładowanie...'),
                                                leading: CircularProgressIndicator(),
                                              );
                                            }
                                            String playerName = snapshot.data ?? playerEmail;
                                            return ListTile(
                                              title: Text('$playerName - $playerStats'),
                                              leading: Icon(Icons.person),
                                              onTap: matchStatus == 'Trwa'
                                                  ? () {
                                                _showStatsDialog(context, matchId, playerEmail, stats[sanitizedEmail] ?? {});
                                              }
                                                  : null,
                                            );
                                          },
                                        );
                                      },
                                    ),
                                    SizedBox(height: 15),
                                    Text(
                                      'Ławka rezerwowych Drużyny 1:',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics: NeverScrollableScrollPhysics(),
                                      itemCount: team1BenchPlayers.length,
                                      itemBuilder: (context, index) {
                                        String playerEmail = team1BenchPlayers[index];
                                        String sanitizedEmail = playerEmail.replaceAll('.', '_');
                                        String playerStats = stats[sanitizedEmail] != null
                                            ? 'Gole: ${stats[sanitizedEmail]['goals']}, Asysty: ${stats[sanitizedEmail]['assists']}'
                                            : 'Brak danych';
                                        return FutureBuilder<String>(
                                          future: fetchUserName(playerEmail),
                                          builder: (context, snapshot) {
                                            if (snapshot.connectionState == ConnectionState.waiting) {
                                              return ListTile(
                                                title: Text('Ładowanie...'),
                                                leading: CircularProgressIndicator(),
                                              );
                                            }
                                            String playerName = snapshot.data ?? playerEmail;
                                            return ListTile(
                                              title: Text('$playerName - $playerStats'),
                                              leading: Icon(Icons.person),
                                              onTap: matchStatus == 'Trwa'
                                                  ? () {
                                                _showStatsDialog(context, matchId, playerEmail, stats[sanitizedEmail] ?? {});
                                              }
                                                  : null,
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            // Skład Drużyny 2
                            SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Przyciski do edytowania statystyk
                                  ElevatedButton(
                                    onPressed: matchStatus == 'Trwa'
                                        ? () {
                                      _showEditTeamStatsDialog(context, 'Drużyna 2', matchId);
                                    }
                                        : null,
                                    child: Text('Edytuj statystyki zespołu 2'),
                                  ),
                                  SizedBox(height: 10),

                                  if (team2StartingPlayers.isEmpty && team2BenchPlayers.isEmpty)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Kapitan nie wybrał jeszcze składu dla Drużyny 2.',
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
                                        ),
                                        SizedBox(height: 10),
                                        Text('Uczestnicy Drużyny 2:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                        ListView.builder(
                                          shrinkWrap: true,
                                          physics: NeverScrollableScrollPhysics(),
                                          itemCount: team2Players.length,
                                          itemBuilder: (context, index) {
                                            String playerEmail = team2Players[index];
                                            String sanitizedEmail = playerEmail.replaceAll('.', '_');
                                            String playerStats = stats[sanitizedEmail] != null
                                                ? 'Gole: ${stats[sanitizedEmail]['goals']}, Asysty: ${stats[sanitizedEmail]['assists']}'
                                                : 'Brak danych';

                                            return FutureBuilder<String>(
                                              future: fetchUserName(playerEmail),
                                              builder: (context, snapshot) {
                                                if (snapshot.connectionState == ConnectionState.waiting) {
                                                  return ListTile(
                                                    title: Text('Ładowanie...'),
                                                    leading: CircularProgressIndicator(),
                                                  );
                                                }
                                                String playerName = snapshot.data ?? playerEmail;
                                                return ListTile(
                                                  title: Text('$playerName - $playerStats'),
                                                  leading: Icon(Icons.person),
                                                  onTap: matchStatus == 'Trwa'
                                                      ? () {
                                                    _showStatsDialog(context, matchId, playerEmail, stats[sanitizedEmail] ?? {});
                                                  }
                                                      : null,
                                                );
                                              },
                                            );
                                          },
                                        ),
                                      ],
                                    )
                                  else ...[
                                    Text(
                                      'Pierwszy skład Drużyny 2:',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics: NeverScrollableScrollPhysics(),
                                      itemCount: team2StartingPlayers.length,
                                      itemBuilder: (context, index) {
                                        String playerEmail = team2StartingPlayers[index];
                                        String sanitizedEmail = playerEmail.replaceAll('.', '_');
                                        String playerStats = stats[sanitizedEmail] != null
                                            ? 'Gole: ${stats[sanitizedEmail]['goals']}, Asysty: ${stats[sanitizedEmail]['assists']}'
                                            : 'Brak danych';

                                        return FutureBuilder<String>(
                                          future: fetchUserName(playerEmail),
                                          builder: (context, snapshot) {
                                            if (snapshot.connectionState == ConnectionState.waiting) {
                                              return ListTile(
                                                title: Text('Ładowanie...'),
                                                leading: CircularProgressIndicator(),
                                              );
                                            }
                                            String playerName = snapshot.data ?? playerEmail;
                                            return ListTile(
                                              title: Text('$playerName - $playerStats'),
                                              leading: Icon(Icons.person),
                                              onTap: matchStatus == 'Trwa'
                                                  ? () {
                                                _showStatsDialog(context, matchId, playerEmail, stats[sanitizedEmail] ?? {});
                                              }
                                                  : null,
                                            );
                                          },
                                        );
                                      },
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'Ławka rezerwowych Drużyny 2:',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics: NeverScrollableScrollPhysics(),
                                      itemCount: team2BenchPlayers.length,
                                      itemBuilder: (context, index) {
                                        String playerEmail = team2BenchPlayers[index];
                                        String sanitizedEmail = playerEmail.replaceAll('.', '_');
                                        String playerStats = stats[sanitizedEmail] != null
                                            ? 'Gole: ${stats[sanitizedEmail]['goals']}, Asysty: ${stats[sanitizedEmail]['assists']}'
                                            : 'Brak danych';

                                        return FutureBuilder<String>(
                                          future: fetchUserName(playerEmail),
                                          builder: (context, snapshot) {
                                            if (snapshot.connectionState == ConnectionState.waiting) {
                                              return ListTile(
                                                title: Text('Ładowanie...'),
                                                leading: CircularProgressIndicator(),
                                              );
                                            }
                                            String playerName = snapshot.data ?? playerEmail;
                                            return ListTile(
                                              title: Text('$playerName - $playerStats'),
                                              leading: Icon(Icons.person),
                                              onTap: matchStatus == 'Trwa'
                                                  ? () {
                                                _showStatsDialog(context, matchId, playerEmail, stats[sanitizedEmail] ?? {});
                                              }
                                                  : null,
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Statystyki ogólne
                            SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    _buildStatRow('Strzały celne', stats['team1ShotsOnTarget'] ?? 0, stats['team2ShotsOnTarget'] ?? 0),
                                    _buildStatRow('Strzały niecelne', stats['team1ShotsOffTarget'] ?? 0, stats['team2ShotsOffTarget'] ?? 0),
                                    _buildStatRow('Strzały z pola karnego', stats['team1PenaltyBox'] ?? 0, stats['team2PenaltyBox'] ?? 0),
                                    _buildStatRow('Strzały spoza pola karnego', stats['team1OutPenaltyBox'] ?? 0, stats['team2OutPenaltyBox'] ?? 0),
                                    _buildStatRow('Interwencje bramkarza', stats['team1intervention'] ?? 0, stats['team2intervention'] ?? 0),
                                    _buildStatRow('Słupek/Poprzeczka', stats['team1Crossbars'] ?? 0, stats['team2Crossbars'] ?? 0),
                                    _buildStatRow('Dośrodkowania', stats['team1Crosses'] ?? 0, stats['team2Crosses'] ?? 0),
                                    _buildStatRow('Dryblingi', stats['team1Dribbles'] ?? 0, stats['team2Dribbles'] ?? 0),
                                    _buildStatRow('Rzuty rożne', stats['team1Corners'] ?? 0, stats['team2Corners'] ?? 0),
                                    _buildStatRow('Rzuty wolne', stats['team1FreeKicks'] ?? 0, stats['team2FreeKicks'] ?? 0),
                                    _buildStatRow('Rzuty karne', stats['team1Penalties'] ?? 0, stats['team2Penalties'] ?? 0),
                                    _buildStatRow('Faule', stats['team1Fouls'] ?? 0, stats['team2Fouls'] ?? 0),
                                    _buildStatRow('Żółte kartki', stats['team1YellowCards'] ?? 0, stats['team2YellowCards'] ?? 0),
                                    _buildStatRow('Czerwone kartki', stats['team1RedCards'] ?? 0, stats['team2RedCards'] ?? 0),
                                  ],
                                ),
                              ),
                            ),
                            // Szczegóły - wyświetlanie strzelców bramek
                            SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Strzelcy drużyny 1
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Strzelcy $team1Name',
                                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                          ),
                                          ListView.builder(
                                            shrinkWrap: true,
                                            physics: NeverScrollableScrollPhysics(),
                                            itemCount: goalScorers.where((scorer) => team1Players.contains(scorer)).length,
                                            itemBuilder: (context, index) {
                                              var team1Scorers = goalScorers.where((scorer) => team1Players.contains(scorer)).toList();
                                              String scorerEmail = team1Scorers[index];

                                              return FutureBuilder<String>(
                                                future: fetchUserName(scorerEmail),
                                                builder: (context, snapshot) {
                                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                                    return ListTile(
                                                      title: Text('Ładowanie...'),
                                                      leading: CircularProgressIndicator(),
                                                    );
                                                  }
                                                  String scorerName = snapshot.data ?? scorerEmail;
                                                  return ListTile(
                                                    title: Text(scorerName),
                                                    leading: Icon(Icons.sports_soccer),
                                                  );
                                                },
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 16), // Przerwa między kolumnami
                                    // Strzelcy drużyny 2
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Strzelcy $team2Name',
                                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                          ),
                                          ListView.builder(
                                            shrinkWrap: true,
                                            physics: NeverScrollableScrollPhysics(),
                                            itemCount: goalScorers.where((scorer) => team2Players.contains(scorer)).length,
                                            itemBuilder: (context, index) {
                                              var team2Scorers = goalScorers.where((scorer) => team2Players.contains(scorer)).toList();
                                              String scorerEmail = team2Scorers[index];

                                              return FutureBuilder<String>(
                                                future: fetchUserName(scorerEmail),
                                                builder: (context, snapshot) {
                                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                                    return ListTile(
                                                      title: Text('Ładowanie...'),
                                                      leading: CircularProgressIndicator(),
                                                    );
                                                  }
                                                  String scorerName = snapshot.data ?? scorerEmail;
                                                  return ListTile(
                                                    title: Text(scorerName),
                                                    leading: Icon(Icons.sports_soccer),
                                                  );
                                                },
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Przyciski do rozpoczęcia i zakończenia meczu
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            if (matchStatus == 'Zakończony, potwierdzony' || matchStatus == 'Zakończony, niepotwierdzony' || matchStatus == 'Anulowany')
                              Text(
                                'Mecz został zakończony. Nie można zmienić statusu meczu.',
                                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            if (matchStatus != 'Zakończony, potwierdzony' && matchStatus != 'Zakończony, niepotwierdzony')
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  ElevatedButton(
                                    onPressed: (matchStatus == 'Trwa')
                                        ? null // Zablokowane, gdy matchStatus jest "Trwa"
                                        : () {
                                      _startMatch(matchId);
                                      TextStyle(backgroundColor: Colors.grey);
                                    },
                                    child: Text('Rozpocznij mecz'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      _endMatch(matchId);
                                    },
                                    child: Text('Zakończ mecz'),
                                  ),
                                ],
                              ),

                          ],
                        ),
                      ),

                    ],
                  ),
                ),

              ],
            );
          },
        ),
      ),
    );
  }


  Widget _buildStatRow(String label, int team1Value, int team2Value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$team1Value',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 18),
          ),
          Text(
            '$team2Value',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showEditTeamStatsDialog(BuildContext context, String teamLabel, String matchId) {
    showDialog(
      context: context,
      builder: (context) {
        // Pobieranie istniejących statystyk zespołu z bazy danych na podstawie 'teamLabel'
        DocumentReference matchRef = FirebaseFirestore.instance.collection('matches').doc(matchId);

        return FutureBuilder<DocumentSnapshot>(
          future: matchRef.get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return AlertDialog(
                title: Text('Błąd'),
                content: Text('Dane meczu nie zostały znalezione.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('OK'),
                  ),
                ],
              );
            }

            // Pobierz dane statystyk z dokumentu meczu
            Map<String, dynamic> matchData = snapshot.data!.data() as Map<String, dynamic>;
            Map<String, dynamic> stats = matchData['stats'] ?? {};

            // Wybierz statystyki dla odpowiedniego zespołu
            Map<String, int> teamStats = {
              'Interwencje bramkarza': teamLabel == 'Drużyna 1' ? stats['team1intervention'] ?? 0 : stats['team2intervention'] ?? 0,
              'Rzuty rożne': teamLabel == 'Drużyna 1' ? stats['team1Corners'] ?? 0 : stats['team2Corners'] ?? 0,
              'Rzuty wolne': teamLabel == 'Drużyna 1' ? stats['team1FreeKicks'] ?? 0 : stats['team2FreeKicks'] ?? 0,
              'Rzuty karne': teamLabel == 'Drużyna 1' ? stats['team1Penalties'] ?? 0 : stats['team2Penalties'] ?? 0,
            };

            return StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  title: Text('Edytuj statystyki: $teamLabel'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: teamStats.keys.map((stat) {
                      return _buildCounterRow(
                        stat,
                        teamStats[stat] ?? 0,
                            (val) {
                          setState(() {
                            teamStats[stat] = val;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('Anuluj'),
                    ),
                    TextButton(
                      onPressed: () {
                        _saveTeamStats(context, matchId, teamLabel, teamStats);
                        Navigator.of(context).pop();
                      },
                      child: Text('Zapisz'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _saveTeamStats(BuildContext context, String matchId, String teamLabel, Map<String, int> teamStats) async {
    try {
      DocumentReference matchRef = FirebaseFirestore.instance.collection('matches').doc(matchId);

      // Pobierz bieżące dane meczu
      DocumentSnapshot matchSnapshot = await matchRef.get();
      Map<String, dynamic> matchData = matchSnapshot.data() as Map<String, dynamic>;

      // Aktualizuj statystyki w zależności od zespołu
      Map<String, dynamic> updatedStats = matchData['stats'] ?? {};

      // Aktualizuj tylko wybrane statystyki, zamiast nadpisywać całość
      if (teamLabel == 'Drużyna 1') {
        updatedStats['team1intervention'] = teamStats['Interwencje bramkarza'];
        updatedStats['team1Corners'] = teamStats['Rzuty rożne'];
        updatedStats['team1FreeKicks'] = teamStats['Rzuty wolne'];
        updatedStats['team1Penalties'] = teamStats['Rzuty karne'];
      } else if (teamLabel == 'Drużyna 2') {
        updatedStats['team2intervention'] = teamStats['Interwencje bramkarza'];
        updatedStats['team2Corners'] = teamStats['Rzuty rożne'];
        updatedStats['team2FreeKicks'] = teamStats['Rzuty wolne'];
        updatedStats['team2Penalties'] = teamStats['Rzuty karne'];
      }

      // Zapisz zaktualizowane statystyki
      await matchRef.update({
        'stats': updatedStats,
      });

      print('Statystyki zespołu $teamLabel zostały zapisane.');
    } catch (e) {
      print('Wystąpił błąd podczas zapisywania statystyk zespołu: $e');
    }
  }

  void _showStatsDialog(BuildContext context, String matchId, String playerEmail, Map<String, dynamic> currentStats) {
    showDialog(
      context: context,
      builder: (context) => _StatsDialog(matchId: matchId, playerEmail: playerEmail, currentStats: currentStats),
    );
  }
}

Widget _buildCounterRow(String label, int value, Function(int) onChanged) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label),
      IconButton(
        icon: Icon(Icons.remove),
        onPressed: () {
          if (value > 0) {
            onChanged(value - 1);
          }
        },
      ),
      Text('$value', style: TextStyle(fontSize: 16)),
      IconButton(
        icon: Icon(Icons.add),
        onPressed: () {
          onChanged(value + 1);
        },
      ),
    ],
  );
}

class _StatsDialog extends StatefulWidget {
  final String matchId;
  final String playerEmail;
  final Map<String, dynamic> currentStats;

  _StatsDialog({required this.matchId, required this.playerEmail, required this.currentStats});

  @override
  __StatsDialogState createState() => __StatsDialogState();
}

class __StatsDialogState extends State<_StatsDialog> {
  late int goals;
  late int assists;
  late int shots;
  late int fouls;
  late int shotsOnTarget;
  late int shotsOffTarget;
  late int crosses;
  late int fouled;
  late int dribbles;
  late int yellowCards;
  late int redCards;
  late int shotsInsideBox;
  late int shotsOutsideBox;
  late int crossbars;

  @override
  void initState() {
    super.initState();
    goals = widget.currentStats['goals'] ?? 0;
    assists = widget.currentStats['assists'] ?? 0;
    shots = widget.currentStats['shots'] ?? 0;
    fouls = widget.currentStats['fouls'] ?? 0;
    shotsOnTarget = widget.currentStats['shotsOnTarget'] ?? 0;
    shotsOffTarget = widget.currentStats['shotsOffTarget'] ?? 0;
    crosses = widget.currentStats['crosses'] ?? 0;
    fouled = widget.currentStats['fouled'] ?? 0;
    dribbles = widget.currentStats['dribbles'] ?? 0;
    yellowCards = widget.currentStats['yellowCards'] ?? 0;
    redCards = widget.currentStats['redCards'] ?? 0;
    shotsInsideBox = widget.currentStats['shotsInsideBox'] ?? 0;
    shotsOutsideBox = widget.currentStats['shotsOutsideBox'] ?? 0;
    crossbars = widget.currentStats['crossbars'] ?? 0;

    print('Loaded stats for ${widget.playerEmail}:');
    print('Goals: $goals, Assists: $assists, Shots: $shots, Fouls: $fouls, Yellow Cards: $yellowCards, Red Cards: $redCards');
  }


  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edycja Statystyk'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCounterRow('Gole', goals, (val) => setState(() => goals = val)),
            _buildCounterRow('Asysty', assists, (val) => setState(() => assists = val)),
            _buildCounterRow('Strzały', shots, (val) => setState(() => shots = val)),
            _buildCounterRow('Strzały z pola karnego', shotsInsideBox, (val) => setState(() => shotsInsideBox = val)),
            _buildCounterRow('Strzały spoza pola karnego', shotsOutsideBox, (val) => setState(() => shotsOutsideBox = val)),
            _buildCounterRow('Słupek/Poprzeczka', crossbars, (val) => setState(() => crossbars = val)),
            _buildCounterRow('Faule', fouls, (val) => setState(() => fouls = val)),
            _buildCounterRow('Strzały celne', shotsOnTarget, (val) => setState(() => shotsOnTarget = val)),
            _buildCounterRow('Strzały niecelne', shotsOffTarget, (val) => setState(() => shotsOffTarget = val)),
            _buildCounterRow('Dośrodkowania', crosses, (val) => setState(() => crosses = val)),
            _buildCounterRow('Sfaulowany', fouled, (val) => setState(() => fouled = val)),
            _buildCounterRow('Dryblingi', dribbles, (val) => setState(() => dribbles = val)),
            _buildCounterRow('Żółte kartki', yellowCards, (val) => setState(() => yellowCards = val)),
            _buildCounterRow('Czerwone kartki', redCards, (val) => setState(() => redCards = val)),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: Text('Anuluj'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: Text('Zapisz'),
          onPressed: () {
            _saveStats(
              widget.matchId,
              widget.playerEmail,
              goals,
              assists,
              shots,
              fouls,
              shotsOnTarget,
              shotsOffTarget,
              crosses,
              fouled,
              dribbles,
              yellowCards,
              redCards,
              shotsInsideBox,
              shotsOutsideBox,
              crossbars,
            );
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }


  void _saveStats(
      String matchId,
      String playerEmail,
      int newGoals,
      int assists,
      int shots,
      int fouls,
      int shotsOnTarget,
      int shotsOffTarget,
      int crosses,
      int fouled,
      int dribbles,
      int yellowCards,
      int redCards,
      int shotsInsideBox,
      int shotsOutsideBox,
      int crossbars,
      ) async {
    try {
      String sanitizedEmail = playerEmail.replaceAll('.', '_');
      DocumentReference matchRef = FirebaseFirestore.instance.collection('matches').doc(matchId);

      // Pobierz bieżące dane meczu
      DocumentSnapshot matchSnapshot = await matchRef.get();
      Map<String, dynamic> matchData = matchSnapshot.data() as Map<String, dynamic>;
      Map<String, dynamic> currentStats = matchData['stats'][sanitizedEmail] ?? {};

      int previousGoals = currentStats['goals'] ?? 0;
      int previousShotsOnTarget = currentStats['shotsOnTarget'] ?? 0;
      int previousShotsOffTarget = currentStats['shotsOffTarget'] ?? 0;
      int previousFouls = currentStats['fouls'] ?? 0;
      int previousYellowCards = currentStats['yellowCards'] ?? 0;
      int previousRedCards = currentStats['redCards'] ?? 0;
      int previousCrosses = currentStats['crosses'] ?? 0;
      int previousDribbles = currentStats['dribbles'] ?? 0;
      int previousShotsInsideBox = currentStats['shotsInsideBox'] ?? 0;
      int previousShotsOutsideBox = currentStats['shotsOutsideBox'] ?? 0;
      int previousCrossbars = currentStats['crossbars'] ?? 0;

      // Oblicz różnicę bramek, strzałów, fauli i kartek
      int goalDifference = newGoals - previousGoals;
      int shotsOnTargetDifference = shotsOnTarget - previousShotsOnTarget;
      int shotsOffTargetDifference = shotsOffTarget - previousShotsOffTarget;
      int foulsDifference = fouls - previousFouls;
      int yellowCardsDifference = yellowCards - previousYellowCards;
      int redCardsDifference = redCards - previousRedCards;
      int crossesDifference = crosses - previousCrosses;
      int dribblesDifference = dribbles - previousDribbles;
      int shotsInsideBoxDifference = shotsInsideBox - previousShotsInsideBox;
      int shotsOutsideBoxDifference = shotsOutsideBox - previousShotsOutsideBox;
      int crossbarsDifference = crossbars - previousCrossbars;


      // Ustal, do której drużyny należy zawodnik
      bool isPlayerInTeam1 = (matchData['team1'] as List<dynamic>).contains(playerEmail);
      bool isPlayerInTeam2 = (matchData['team2'] as List<dynamic>).contains(playerEmail);

      // Zaktualizuj wynik na podstawie różnicy bramek
      int team1Score = matchData['team1Score'] ?? 0;
      int team2Score = matchData['team2Score'] ?? 0;

      if (goalDifference != 0) {
        if (isPlayerInTeam1) {
          team1Score += goalDifference;
        } else if (isPlayerInTeam2) {
          team2Score += goalDifference;
        }
      }

      // Pobierz lub utwórz pustą listę strzelców, jeśli nie istnieje
      List<String> goalScorers = List<String>.from(matchData['goalScorers'] ?? []);
      if (goalDifference > 0) {
        // Dodaj nowego strzelca za każdą zdobyta bramkę
        goalScorers.addAll(List<String>.generate(goalDifference, (index) => playerEmail));
      } else if (goalDifference < 0) {
        // Usuń strzelca za każdą cofniętą bramkę
        for (int i = 0; i < -goalDifference; i++) {
          goalScorers.remove(playerEmail);
        }
      }

      // Zaktualizuj liczbę strzałów celnych w zależności od drużyny
      if (shotsOnTargetDifference != 0) {
        if (isPlayerInTeam1) {
          matchData['stats']['team1ShotsOnTarget'] = (matchData['stats']['team1ShotsOnTarget'] ?? 0) + shotsOnTargetDifference;
        } else if (isPlayerInTeam2) {
          matchData['stats']['team2ShotsOnTarget'] = (matchData['stats']['team2ShotsOnTarget'] ?? 0) + shotsOnTargetDifference;
        }
      }

      // Zaktualizuj liczbę strzałów niecelnych w zależności od drużyny
      if (shotsOffTargetDifference != 0) {
        if (isPlayerInTeam1) {
          matchData['stats']['team1ShotsOffTarget'] = (matchData['stats']['team1ShotsOffTarget'] ?? 0) + shotsOffTargetDifference;
        } else if (isPlayerInTeam2) {
          matchData['stats']['team2ShotsOffTarget'] = (matchData['stats']['team2ShotsOffTarget'] ?? 0) + shotsOffTargetDifference;
        }
      }

      // Zaktualizuj liczbę fauli w zależności od drużyny
      if (foulsDifference != 0) {
        if (isPlayerInTeam1) {
          matchData['stats']['team1Fouls'] = (matchData['stats']['team1Fouls'] ?? 0) + foulsDifference;
        } else if (isPlayerInTeam2) {
          matchData['stats']['team2Fouls'] = (matchData['stats']['team2Fouls'] ?? 0) + foulsDifference;
        }
      }

      // Zaktualizuj liczbę żółtych kartek w zależności od drużyny
      if (yellowCardsDifference != 0) {
        if (isPlayerInTeam1) {
          matchData['stats']['team1YellowCards'] = (matchData['stats']['team1YellowCards'] ?? 0) + yellowCardsDifference;
        } else if (isPlayerInTeam2) {
          matchData['stats']['team2YellowCards'] = (matchData['stats']['team2YellowCards'] ?? 0) + yellowCardsDifference;
        }
      }

      // Zaktualizuj liczbę dośrodkowań w zależności od drużyny
      if (crossesDifference != 0) {
        if (isPlayerInTeam1) {
          matchData['stats']['team1Crosses'] = (matchData['stats']['team1Crosses'] ?? 0) + crossesDifference;
        } else if (isPlayerInTeam2) {
          matchData['stats']['team2Crosses'] = (matchData['stats']['team2Crosses'] ?? 0) + crossesDifference;
        }
      }

      // Zaktualizuj liczbę dryblingów w zależności od drużyny
      if (dribblesDifference != 0) {
        if (isPlayerInTeam1) {
          matchData['stats']['team1Dribbles'] = (matchData['stats']['team1Dribbles'] ?? 0) + dribblesDifference;
        } else if (isPlayerInTeam2) {
          matchData['stats']['team2Dribbles'] = (matchData['stats']['team2Dribbles'] ?? 0) + dribblesDifference;
        }
      }

      // Zaktualizuj liczbę czerwonych kartek w zależności od drużyny
      if (redCardsDifference != 0) {
        if (isPlayerInTeam1) {
          matchData['stats']['team1RedCards'] = (matchData['stats']['team1RedCards'] ?? 0) + redCardsDifference;
        } else if (isPlayerInTeam2) {
          matchData['stats']['team2RedCards'] = (matchData['stats']['team2RedCards'] ?? 0) + redCardsDifference;
        }
      }

      // Zaktualizuj liczbę strzałów z pola karnego w zależności od drużyny
      if (shotsInsideBoxDifference != 0) {
        if (isPlayerInTeam1) {
          matchData['stats']['team1PenaltyBox'] = (matchData['stats']['team1PenaltyBox'] ?? 0) + shotsInsideBoxDifference;
        } else if (isPlayerInTeam2) {
          matchData['stats']['team2PenaltyBox'] = (matchData['stats']['team2PenaltyBox'] ?? 0) + shotsInsideBoxDifference;
        }
      }

      // Zaktualizuj liczbę strzałów spoza pola karnego w zależności od drużyny
      if (shotsOutsideBoxDifference != 0) {
        if (isPlayerInTeam1) {
          matchData['stats']['team1OutPenaltyBox'] = (matchData['stats']['team1OutPenaltyBox'] ?? 0) + shotsOutsideBoxDifference;
        } else if (isPlayerInTeam2) {
          matchData['stats']['team2OutPenaltyBox'] = (matchData['stats']['team2OutPenaltyBox'] ?? 0) + shotsOutsideBoxDifference;
        }
      }

      // Zaktualizuj liczbę słupków/poprzeczek w zależności od drużyny
      if (crossbarsDifference != 0) {
        if (isPlayerInTeam1) {
          matchData['stats']['team1Crossbars'] = (matchData['stats']['team1Crossbars'] ?? 0) + crossbarsDifference;
        } else if (isPlayerInTeam2) {
          matchData['stats']['team2Crossbars'] = (matchData['stats']['team2Crossbars'] ?? 0) + crossbarsDifference;
        }
      }

      // Upewnij się, że wartości nie są ujemne (np. liczba strzałów i kartek nie może być mniejsza niż zero)
      matchData['stats']['team1ShotsOnTarget'] = (matchData['stats']['team1ShotsOnTarget'] ?? 0).clamp(0, double.infinity).toInt();
      matchData['stats']['team2ShotsOnTarget'] = (matchData['stats']['team2ShotsOnTarget'] ?? 0).clamp(0, double.infinity).toInt();
      matchData['stats']['team1ShotsOffTarget'] = (matchData['stats']['team1ShotsOffTarget'] ?? 0).clamp(0, double.infinity).toInt();
      matchData['stats']['team2ShotsOffTarget'] = (matchData['stats']['team2ShotsOffTarget'] ?? 0).clamp(0, double.infinity).toInt();
      matchData['stats']['team1Fouls'] = (matchData['stats']['team1Fouls'] ?? 0).clamp(0, double.infinity).toInt();
      matchData['stats']['team2Fouls'] = (matchData['stats']['team2Fouls'] ?? 0).clamp(0, double.infinity).toInt();
      matchData['stats']['team1YellowCards'] = (matchData['stats']['team1YellowCards'] ?? 0).clamp(0, double.infinity).toInt();
      matchData['stats']['team2YellowCards'] = (matchData['stats']['team2YellowCards'] ?? 0).clamp(0, double.infinity).toInt();
      matchData['stats']['team1RedCards'] = (matchData['stats']['team1RedCards'] ?? 0).clamp(0, double.infinity).toInt();
      matchData['stats']['team2RedCards'] = (matchData['stats']['team2RedCards'] ?? 0).clamp(0, double.infinity).toInt();
      matchData['stats']['team1Crosses'] = (matchData['stats']['team1Crosses'] ?? 0).clamp(0, double.infinity).toInt();
      matchData['stats']['team2Crosses'] = (matchData['stats']['team2Crosses'] ?? 0).clamp(0, double.infinity).toInt();
      matchData['stats']['team1Dribbles'] = (matchData['stats']['team1Dribbles'] ?? 0).clamp(0, double.infinity).toInt();
      matchData['stats']['team2Dribbles'] = (matchData['stats']['team2Dribbles'] ?? 0).clamp(0, double.infinity).toInt();

      // Zaktualizuj dane zawodnika w Firestore
      await matchRef.update({
        'stats.$sanitizedEmail': {
          'goals': newGoals,
          'assists': assists,
          'shots': shots,
          'fouls': fouls,
          'shotsOnTarget': shotsOnTarget,
          'shotsOffTarget': shotsOffTarget,
          'crosses': crosses,
          'fouled': fouled,
          'dribbles': dribbles,
          'yellowCards': yellowCards,
          'redCards': redCards,
          'shotsInsideBox': shotsInsideBox,
          'shotsOutsideBox': shotsOutsideBox,
          'crossbars': crossbars,
        },
        'team1Score': team1Score,
        'team2Score': team2Score,
        'goalScorers': goalScorers,
        'stats.team1ShotsOnTarget': matchData['stats']['team1ShotsOnTarget'],
        'stats.team2ShotsOnTarget': matchData['stats']['team2ShotsOnTarget'],
        'stats.team1ShotsOffTarget': matchData['stats']['team1ShotsOffTarget'],
        'stats.team2ShotsOffTarget': matchData['stats']['team2ShotsOffTarget'],
        'stats.team1Fouls': matchData['stats']['team1Fouls'],
        'stats.team2Fouls': matchData['stats']['team2Fouls'],
        'stats.team1YellowCards': matchData['stats']['team1YellowCards'],
        'stats.team2YellowCards': matchData['stats']['team2YellowCards'],
        'stats.team1RedCards': matchData['stats']['team1RedCards'],
        'stats.team2RedCards': matchData['stats']['team2RedCards'],
        'stats.team1Crosses': matchData['stats']['team1Crosses'],
        'stats.team2Crosses': matchData['stats']['team2Crosses'],
        'stats.team1Dribbles': matchData['stats']['team1Dribbles'],
        'stats.team2Dribbles': matchData['stats']['team2Dribbles'],
        'stats.team1PenaltyBox': matchData['stats']['team1PenaltyBox'],
        'stats.team2PenaltyBox': matchData['stats']['team2PenaltyBox'],
        'stats.team1OutPenaltyBox': matchData['stats']['team1OutPenaltyBox'],
        'stats.team2OutPenaltyBox': matchData['stats']['team2OutPenaltyBox'],
        'stats.team1Crossbars': matchData['stats']['team1Crossbars'],
        'stats.team2Crossbars': matchData['stats']['team2Crossbars'],
      });



      print('Statystyki zapisane pomyślnie. Wynik meczu: $team1Score - $team2Score');
    } catch (e) {
      print('Wystąpił błąd podczas zapisywania statystyk: $e');
    }
  }
}

class MatchTimer extends StatefulWidget {
  final String matchId;

  const MatchTimer({Key? key, required this.matchId}) : super(key: key);

  @override
  _MatchTimerState createState() => _MatchTimerState();
}

class _MatchTimerState extends State<MatchTimer> {
  Timer? _timer;
  Duration _elapsedTime = Duration.zero;
  Timestamp? _startTime;

  @override
  void initState() {
    super.initState();
    _fetchStartTime();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _fetchStartTime() async {
    // Pobranie czasu rozpoczęcia meczu z bazy danych
    DocumentSnapshot matchDoc = await FirebaseFirestore.instance.collection(
        'matches').doc(widget.matchId).get();
    if (matchDoc.exists) {
      Map<String, dynamic> matchData = matchDoc.data() as Map<String, dynamic>;
      Timestamp? startTime = matchData['startTime'];
      if (startTime != null) {
        setState(() {
          _startTime = startTime;
        });
        _startTimer(startTime.toDate());
      }
    }
  }

  void _startTimer(DateTime startTime) {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      setState(() {
        _elapsedTime = now.difference(startTime);
      });
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return _startTime == null
        ? Text('Czekam na rozpoczęcie meczu...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
        : Text(
      'Czas trwania: ${_formatDuration(_elapsedTime)}',
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }
}



