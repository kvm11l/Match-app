import 'package:app_firebase/user_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PlayerScreen extends StatefulWidget {
  final String matchId;

  PlayerScreen({required this.matchId});

  @override
  _PlayerScreenState createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with SingleTickerProviderStateMixin {
  final User? user = FirebaseAuth.instance.currentUser;
  String _availabilityStatus = 'brak decyzji'; // Domyślny status
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _getUserAvailability(); // Pobieranie dostępności użytkownika
    _tabController = TabController(length: 2, vsync: this);
  }

  void _getUserAvailability() async {
    if (user == null) return;
    DocumentSnapshot matchSnapshot = await FirebaseFirestore.instance
        .collection('matches')
        .doc(widget.matchId)
        .get();

    if (matchSnapshot.exists) {
      var matchData = matchSnapshot.data() as Map<String, dynamic>;
      var availabilityList = matchData['availability'] ?? [];
      // Szukamy dostępności użytkownika w liście
      for (var item in availabilityList) {
        if (item['email'] == user!.email) {
          setState(() {
            _availabilityStatus = item['status'] ?? 'brak decyzji';
          });
          break; // Znaleziono dostępność, możemy przerwać pętlę
        }
      }
    }
  }

  void _updateAvailability(String newStatus) async {
    if (user == null) return;

    DocumentReference matchRef = FirebaseFirestore.instance.collection('matches').doc(widget.matchId);

    // Uaktualniamy status dostępności w Firestore
    await matchRef.update({
      'availability': FieldValue.arrayRemove([
        {'email': user!.email, 'status': _availabilityStatus}
      ])
    });

    await matchRef.update({
      'availability': FieldValue.arrayUnion([
        {'email': user!.email, 'status': newStatus}
      ])
    });

    setState(() {
      _availabilityStatus = newStatus;
    });
  }

  Icon _getAvailabilityIcon(String status) {
    switch (status) {
      case 'dostępny':
        return Icon(Icons.circle, color: Colors.green, size: 12);
      case 'niedostępny':
        return Icon(Icons.circle, color: Colors.red, size: 12);
      default:
        return Icon(Icons.circle, color: Colors.orange, size: 12);
    }
  }


  void _leaveMatch() async {
    if (user == null) return;

    DocumentReference matchRef = FirebaseFirestore.instance.collection('matches').doc(widget.matchId);
    DocumentSnapshot matchSnapshot = await matchRef.get();

    if (!matchSnapshot.exists) return;

    var matchData = matchSnapshot.data() as Map<String, dynamic>;
    String userEmail = user!.email!;

    // Sprawdzenie statusu meczu
    String matchStatus = matchData['status'];

    // Jeśli mecz ma status inny niż 'not_started', nie wykonuj funkcji i poinformuj użytkownika
    if (matchStatus != 'not_started') {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nie można opuścić meczu po jego rozpoczęciu!'))
      );
      return;
    }

    // Funkcja pomocnicza do usuwania z listy
    Future<void> _removeFromList(String fieldName, dynamic value) async {
      if (matchData[fieldName] != null && matchData[fieldName].contains(value)) {
        await matchRef.update({
          fieldName: FieldValue.arrayRemove([value]),
        });
      }
    }

    // Usunięcie użytkownika z availability
    List<dynamic> availabilityList = matchData['availability'] ?? [];
    Map<String, dynamic>? userAvailability = availabilityList.firstWhere(
          (item) => item['email'] == userEmail,
      orElse: () => null,
    );

    if (userAvailability != null) {
      await _removeFromList('availability', userAvailability);
    }

    // Sprawdzenie drużyny użytkownika
    if ((matchData['team1'] ?? []).contains(userEmail)) {
      // Usuwanie z team1 i odpowiednich list graczy
      await _removeFromList('team1', userEmail);
      await _removeFromList('team1StartingPlayers', userEmail);
      await _removeFromList('team1BenchPlayers', userEmail);
    } else if ((matchData['team2'] ?? []).contains(userEmail)) {
      // Usuwanie z team2 i odpowiednich list graczy
      await _removeFromList('team2', userEmail);
      await _removeFromList('team2StartingPlayers', userEmail);
      await _removeFromList('team2BenchPlayers', userEmail);
    }

    // Sprawdzenie, czy użytkownik jest widzem lub statystykiem
    bool isSpectator = (matchData['spectators'] ?? []).contains(userEmail);
    bool isStatistician = (matchData['statisticians'] ?? []).contains(userEmail);

    // Jeśli nie jest widzem ani statystykiem, usuń go z participants
    if (!isSpectator && !isStatistician) {
      await _removeFromList('participants', userEmail);
    }

    // Powrót do poprzedniego ekranu
    Navigator.of(context).pop();
  }






  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Zawodnik'),
        actions: [
          IconButton(
            icon: Icon(Icons.exit_to_app, color: Colors.red),
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text('Opuszczenie meczu'),
                    content: Text('Czy na pewno chcesz opuścić mecz?'),
                    actions: [
                      TextButton(
                        child: Text('Anuluj'),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      TextButton(
                        child: Text('Opuść', style: TextStyle(color: Colors.red)),
                        onPressed: () {
                          Navigator.of(context).pop(); // Zamknięcie dialogu
                          _leaveMatch();               // Wywołanie funkcji opuszczenia meczu
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('matches').doc(widget.matchId).get(),
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
          String matchStatus = matchData['status'];

          // Określenie drużyny, do której należy zawodnik
          List<dynamic> team1 = matchData['team1'] ?? [];
          List<dynamic> team2 = matchData['team2'] ?? [];

          String team1Captain = matchData['team1Captain'];
          String team2Captain = matchData['team2Captain'];



          // Pobieranie statusów dostępności zawodników
          List<dynamic> availabilityList = matchData['availability'] ?? [];

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
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
                        // Użycie Tooltip dla pełnej nazwy drużyny
                        Tooltip(
                          message: team1Name,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: 120), // Maksymalna szerokość tekstu
                            child: Text(
                              team1Name,
                              overflow: TextOverflow.ellipsis, // Zawijanie tekstu, jeśli jest za długi
                              softWrap: true,
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'VS',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
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
                        // Użycie Tooltip dla pełnej nazwy drużyny
                        Tooltip(
                          message: team2Name,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: 120), // Maksymalna szerokość tekstu
                            child: Text(
                              team2Name,
                              overflow: TextOverflow.ellipsis, // Zawijanie tekstu, jeśli jest za długi
                              softWrap: true,
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 24),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Data: ${matchDate.toLocal().toString().split(' ')[0]}',
                      style: TextStyle(fontSize: 16),
                    ),
                    Text(
                      'Godzina: ${matchDate.hour}:${matchDate.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: 16),
                    ),
                    Text(
                      'Miejsce: $matchLocation',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                Text(
                    'Status: $matchStatus',
                    style: TextStyle(fontSize: 16)),
                SizedBox(height: 20),

                // Zakładki
                Expanded(
                  child: Column(
                    children: [
                      TabBar(
                        controller: _tabController,
                        tabs: [
                          Tab(text: team1Name),
                          Tab(text: team2Name),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            // Zakładka dla drużyny 1
                            SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildTeamAvailability(team1, availabilityList, team1Name, team1Captain),
                                    SizedBox(height: 16),
                                    _buildTeamRoster(widget.matchId, team1Name, 'team1StartingPlayers', 'team1BenchPlayers'),
                                  ],
                                ),
                              ),
                            ),
                            // Zakładka dla drużyny 2
                            SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildTeamAvailability(team2, availabilityList, team2Name, team2Captain),
                                    SizedBox(height: 16),
                                    _buildTeamRoster(widget.matchId, team2Name, 'team2StartingPlayers', 'team2BenchPlayers'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Sekcja dostępności użytkownika na samym dole ekranu
                SizedBox(height: 16),
                if (user != null)
                  matchStatus == "Nierozpoczęty"
                      ? Column(
                    children: [
                      Text(
                        'Twoja dostępność:',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      DropdownButton<String>(
                        value: _availabilityStatus,
                        items: ['dostępny', 'brak decyzji', 'niedostępny']
                            .map((status) => DropdownMenuItem<String>(
                          value: status,
                          child: Text(status),
                        ))
                            .toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            _updateAvailability(newValue);
                          }
                        },
                      ),
                    ],
                  )
                      : Text(
                    'Nie można zmienić dostępności, ponieważ mecz jest rozpoczęty lub zakończony.',
                    style: TextStyle(fontSize: 16, color: Colors.red, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Funkcja do budowy sekcji składu drużyny
  Widget _buildTeamRoster(String matchId, String teamName, String startingPlayersKey, String benchPlayersKey) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('matches').doc(matchId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Center(child: Text('Brak danych o składzie dla $teamName.'));
        }

        var data = snapshot.data!.data() as Map<String, dynamic>;

        List<dynamic> startingPlayers = data[startingPlayersKey] ?? [];
        List<dynamic> benchPlayers = data[benchPlayersKey] ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Skład $teamName',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),

            startingPlayers.isNotEmpty
                ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pierwszy skład',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: startingPlayers.length,
                  itemBuilder: (context, index) {
                    String playerEmail = startingPlayers[index];
                    return FutureBuilder<String>(
                      future: fetchUserName(playerEmail),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return ListTile(
                            title: Text('Ładowanie...'),

                          );
                        }

                        String playerName = snapshot.data ?? playerEmail;
                        return ListTile(
                          title: Text(playerName),
                        );
                      },
                    );
                  },
                ),
                SizedBox(height: 16),
                Text(
                  'Ławka rezerwowych',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: benchPlayers.length,
                  itemBuilder: (context, index) {
                    String playerEmail = benchPlayers[index];
                    return FutureBuilder<String>(
                      future: fetchUserName(playerEmail),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return ListTile(
                            title: Text('Ładowanie...'),

                          );
                        }

                        String playerName = snapshot.data ?? playerEmail;
                        return ListTile(
                          title: Text(playerName),
                        );
                      },
                    );
                  },
                ),
              ],
            )
                : Text(
              'Pierwszy skład i ławka rezerwowych nie zostały wybrane dla $teamName.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
            ),
          ],
        );
      },
    );
  }

  // Metoda do budowy sekcji dostępności drużyny
  Widget _buildTeamAvailability(List<dynamic> teamMembers, List<dynamic> availabilityList, String teamName, String captainEmail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dostępność w $teamName:',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: teamMembers.length,
          itemBuilder: (context, index) {
            String playerEmail = teamMembers[index];
            String status = 'brak decyzji';

            // Szukanie statusu dostępności dla zawodnika
            for (var item in availabilityList) {
              if (item['email'] == playerEmail) {
                status = item['status'] ?? 'brak decyzji';
                break;
              }
            }

            return FutureBuilder<String>(
              future: fetchUserName(playerEmail),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return ListTile(
                    title: Text('Ładowanie...'), // Wyświetla napis Ładowanie podczas ładowania danych.
                  );
                }

                String playerName = snapshot.data ?? playerEmail; // Jeśli nie uda się pobrać imienia, wyświetli email.

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserDetailsScreen(userEmail: playerEmail),
                      ),
                    );
                  },
                  child: ListTile(
                    title: Row(
                      children: [
                        Text(playerName),
                        if (playerEmail == captainEmail) ...[
                          SizedBox(width: 8),
                          Icon(Icons.star, color: Colors.orange, size: 16), // Ikona kapitana
                        ],
                      ],
                    ),
                    leading: _getAvailabilityIcon(status),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

// Funkcja do pobierania imienia i nazwiska użytkownika na podstawie adresu email
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
}
