import 'package:app_firebase/statistician_screen.dart';
import 'package:app_firebase/user_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SpectatorScreen extends StatelessWidget {
  final String matchId;

  SpectatorScreen({required this.matchId});




  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5, // Liczba zakładek
      child: Scaffold(
        appBar: AppBar(
          title: Text('Statystyki meczu'),
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
            Map<String, dynamic> userStats = matchData['stats'] ?? {};


            // Składy drużyn
            List<dynamic> team1StartingPlayers = matchData['team1StartingPlayers'] ?? [];
            List<dynamic> team1BenchPlayers = matchData['team1BenchPlayers'] ?? [];
            List<dynamic> team2StartingPlayers = matchData['team2StartingPlayers'] ?? [];
            List<dynamic> team2BenchPlayers = matchData['team2BenchPlayers'] ?? [];
            List<dynamic> goalScorers = matchData['goalScorers'] ?? [];

            // Uczestnicy drużyn
            List<dynamic> team1 = matchData['team1'] ?? [];
            List<dynamic> team2 = matchData['team2'] ?? [];

            String matchScore = '${matchData['team1Score'] ?? 0} - ${matchData['team2Score'] ?? 0}';

            // Statystyki zawodników
            Map<String, dynamic> stats = matchData['stats'] ?? {};
            String matchStatus = matchData['status'] ?? 'Nierozpoczęty';
            int totalDuration = matchData['totalDuration'] ?? 0;

            String formatDuration(int seconds) {
              int hours = seconds ~/ 3600;
              int minutes = (seconds % 3600) ~/ 60;
              int secs = seconds % 60;
              return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 10),
                // Wiersz z logo i nazwami drużyn
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildTeamColumn(team1LogoUrl, team1Name),
                    Text(
                      matchScore,
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
                    ),
                    _buildTeamColumn(team2LogoUrl, team2Name),
                  ],
                ),
                SizedBox(height: 15),

                // Wyświetlanie informacji o dacie, godzinie i miejscu meczu
                Container(
                  alignment: Alignment.center,
                  padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Data meczu: ${matchDate.toLocal().toIso8601String().split('T').first}',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Godzina meczu: ${matchDate.hour}:${matchDate.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Miejsce: $matchLocation',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Status meczu: $matchStatus',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
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
                            return Text('Czas trwania: brak danych', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500));
                          }

                          return Center(
                            child: Text(
                              'Czas trwania: ${formatDuration(totalDuration)}',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                          );
                        },
                      ),

                    ],
                  ),
                ),
                // Zakładki pod danymi o meczu
                TabBar(
                  isScrollable: true, // Pozwala na przewijanie zakładek
                  tabs: [
                    Tab(text: 'Skład drużyny 1'),
                    Tab(text: 'Skład drużyny 2'),
                    Tab(text: 'Statystyki'),
                    Tab(text: 'Strzelcy'),
                    Tab(text: 'Uczestnicy'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Skład drużyny 1
                      ListView(
                        children: [
                          _buildTeamTab(
                            context,
                            team1StartingPlayers,
                            team1BenchPlayers,
                            userStats,
                            team1.cast<String>(), // Lista uczestników drużyny 2
                          ),
                        ],
                      ),
                      // Skład drużyny 2
                      ListView(
                        children: [
                          _buildTeamTab(
                            context,
                            team2StartingPlayers,
                            team2BenchPlayers,
                            userStats,
                            team2.cast<String>(), // Lista uczestników drużyny 2
                          ),
                        ],
                      ),
                      // Statystyki
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

                      // Strzelcy


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
                                      'Strzelcy drużyny 1',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    if (goalScorers.where((scorer) => team1.contains(scorer)).isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text('Brak strzelców w tej drużynie.'),
                                      )
                                    else
                                      ListView.builder(
                                        shrinkWrap: true,
                                        physics: NeverScrollableScrollPhysics(),
                                        itemCount: goalScorers.where((scorer) => team1.contains(scorer)).length,
                                        itemBuilder: (context, index) {
                                          var team1Scorers = goalScorers.where((scorer) => team1.contains(scorer)).toList();
                                          return FutureBuilder<String>(
                                            future: _getFullName(team1Scorers[index]), // Pobierz pełne imię i nazwisko
                                            builder: (context, snapshot) {
                                              if (snapshot.connectionState == ConnectionState.waiting) {
                                                return Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                                  child: Text('Ładowanie...', style: TextStyle(fontSize: 16, color: Colors.black)),
                                                );
                                              }

                                              if (!snapshot.hasData) {
                                                return Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                                  child: Text('Błąd pobierania danych', style: TextStyle(fontSize: 16, color: Colors.red)),
                                                );
                                              }

                                              return ListTile(
                                                title: Text(snapshot.data!), // Wyświetl imię i nazwisko strzelca
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
                                      'Strzelcy drużyny 2',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    if (goalScorers.where((scorer) => team2.contains(scorer)).isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text('Brak strzelców w tej drużynie.'),
                                      )
                                    else
                                      ListView.builder(
                                        shrinkWrap: true,
                                        physics: NeverScrollableScrollPhysics(),
                                        itemCount: goalScorers.where((scorer) => team2.contains(scorer)).length,
                                        itemBuilder: (context, index) {
                                          var team2Scorers = goalScorers.where((scorer) => team2.contains(scorer)).toList();
                                          return FutureBuilder<String>(
                                            future: _getFullName(team2Scorers[index]), // Pobierz pełne imię i nazwisko
                                            builder: (context, snapshot) {
                                              if (snapshot.connectionState == ConnectionState.waiting) {
                                                return Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                                  child: Text('Ładowanie...', style: TextStyle(fontSize: 16, color: Colors.black)),
                                                );
                                              }

                                              if (!snapshot.hasData) {
                                                return Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                                  child: Text('Błąd pobierania danych', style: TextStyle(fontSize: 16, color: Colors.red)),
                                                );
                                              }

                                              return ListTile(
                                                title: Text(snapshot.data!), // Wyświetl imię i nazwisko strzelca
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

                      // Uczestnicy
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Uczestnicy Drużyny 1
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Drużyna 1 - Uczestnicy',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  if (team1.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text('Brak uczestników.'),
                                    )
                                  else
                                    ...team1.map((participant) => FutureBuilder<String>(
                                      future: _getFullName(participant), // Pobierz pełne imię i nazwisko
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState == ConnectionState.waiting) {
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                                            child: Text('Ładowanie...', style: TextStyle(fontSize: 16, color: Colors.black)),
                                          );
                                        }

                                        if (!snapshot.hasData) {
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                                            child: Text('Błąd pobierania danych', style: TextStyle(fontSize: 16, color: Colors.red)),
                                          );
                                        }

                                        return ListTile(
                                          title: Text(snapshot.data!), // Wyświetl imię i nazwisko
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => UserDetailsScreen(userEmail: participant),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    )),
                                ],
                              ),
                            ),
                          ),

                          // Uczestnicy Drużyny 2
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Drużyna 2 - Uczestnicy',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  if (team2.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text('Brak uczestników.'),
                                    )
                                  else
                                    ...team2.map((participant) => FutureBuilder<String>(
                                      future: _getFullName(participant), // Pobierz pełne imię i nazwisko
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState == ConnectionState.waiting) {
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                                            child: Text('Ładowanie...', style: TextStyle(fontSize: 16, color: Colors.black)),
                                          );
                                        }

                                        if (!snapshot.hasData) {
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                                            child: Text('Błąd pobierania danych', style: TextStyle(fontSize: 16, color: Colors.red)),
                                          );
                                        }

                                        return ListTile(
                                          title: Text(snapshot.data!), // Wyświetl imię i nazwisko
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => UserDetailsScreen(userEmail: participant),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    )),
                                ],
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildTeamTab(
      BuildContext context,
      List<dynamic> startingPlayers,
      List<dynamic> benchPlayers,
      Map<String, dynamic> userStats,
      List<String> teamParticipants,
      ) {
    final bool noPlayersSelected = startingPlayers.isEmpty && benchPlayers.isEmpty;

    // Komponent dla wyświetlania zawodników
    Widget _buildPlayerTile(String playerId, Map<String, dynamic> stats) {
      return FutureBuilder<String>(
        future: _getFullName(playerId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListTile(
              leading: CircularProgressIndicator(),
              title: Text('Ładowanie...', style: TextStyle(fontSize: 16, color: Colors.blue)),
            );
          }

          if (!snapshot.hasData) {
            return ListTile(
              leading: Icon(Icons.error, color: Colors.red),
              title: Text('Błąd pobierania danych', style: TextStyle(fontSize: 16, color: Colors.red)),
            );
          }

          return ListTile(
            leading: Icon(Icons.person, color: Colors.blue),
            title: Text(
              snapshot.data!,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            onTap: () => _showPlayerStatsDialog(context, playerId, stats),
          );
        },
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (noPlayersSelected) ...[
              Text(
                'Kapitan nie wybrał jeszcze składu.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
              ),
              SizedBox(height: 8),
              Text('Uczestnicy drużyny:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ...teamParticipants.map((participant) => _buildPlayerTile(participant, userStats)),
            ] else ...[
              Text('Pierwszy skład:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              if (startingPlayers.isEmpty)
                Text('Brak zawodników w pierwszym składzie.', style: TextStyle(fontSize: 16))
              else
                ...startingPlayers.map((player) => _buildPlayerTile(player, userStats)),
              SizedBox(height: 16),
              Text('Ławka rezerwowych:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              if (benchPlayers.isEmpty)
                Text('Brak zawodników na ławce.', style: TextStyle(fontSize: 16))
              else
                ...benchPlayers.map((player) => _buildPlayerTile(player, userStats)),
            ],
          ],
        ),
      ),
    );
  }


  // Funkcja pobierająca imię i nazwisko na podstawie adresu e-mail
  Future<String> _getFullName(String email) async {
    try {
      // Pobierz użytkownika na podstawie emaila
      var userSnapshot = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: email).get();
      if (userSnapshot.docs.isNotEmpty) {
        var userData = userSnapshot.docs.first.data();
        String firstName = userData['firstName'] ?? '';
        String lastName = userData['lastName'] ?? '';
        return '$firstName $lastName';
      }
    } catch (e) {
      print("Błąd pobierania danych użytkownika: $e");
    }
    return email; // Zwracamy email, jeśli nie uda się pobrać danych
  }

  // Budowanie kolumny z logo i nazwą drużyny
  Widget _buildTeamColumn(String logoUrl, String teamName) {
    return Column(
      children: [
        ClipOval(
          child: Image.network(
            logoUrl,
            width: 70,
            height: 70,
            fit: BoxFit.cover,
          ),
        ),
        SizedBox(height: 4),
        Tooltip(
          message: teamName,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 120), // Ograniczenie szerokości
            child: Text(
              teamName,
              overflow: TextOverflow.ellipsis, // Elipsa dla długiej nazwy
              softWrap: false,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }


  void _showPlayerStatsDialog(
      BuildContext context,
      String playerEmail,
      Map<String, dynamic> userStats,
      ) async {
    final playerStats = userStats[playerEmail.replaceAll('.', '_')] ?? {};

    // Pobieramy imię i nazwisko gracza
    String fullName = await _getFullName(playerEmail);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Statystyki - $fullName'), // Zmieniamy na pełne imię i nazwisko
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatItem('Gole', playerStats['goals'] ?? 0),
              _buildStatItem('Asysty', playerStats['assists'] ?? 0),
              _buildStatItem('Strzały', playerStats['shots'] ?? 0),
              _buildStatItem('Słupek/poprzeczka', playerStats['crossbars'] ?? 0),
              _buildStatItem('Strzały celne', playerStats['shotsOnTarget'] ?? 0),
              _buildStatItem('Strzały niecelne', playerStats['shotsOffTarget'] ?? 0),
              _buildStatItem('Strzały spoza pola karnego', playerStats['shotsOutsideBox'] ?? 0),
              _buildStatItem('Strzały z pola karnego', playerStats['shotsInsideBox'] ?? 0),
              _buildStatItem('Dryblingi', playerStats['dribbles'] ?? 0),
              _buildStatItem('Dośrodkowania', playerStats['crosses'] ?? 0),
              _buildStatItem('Faule', playerStats['fouls'] ?? 0),
              _buildStatItem('Sfaulowany', playerStats['fouled'] ?? 0),
              _buildStatItem('Żółte kartki', playerStats['yellowCards'] ?? 0),
              _buildStatItem('Czerwone kartki', playerStats['redCards'] ?? 0),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Zamknij'),
            ),
          ],
        );
      },
    );
  }


  Widget _buildStatItem(String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text('$value', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

