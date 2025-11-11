import 'dart:io';
import 'package:app_firebase/user_details_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:image_picker/image_picker.dart';

class MatchHistoryUserScreen extends StatefulWidget {
  final String matchId;
  final String team1Name;
  final String team2Name;
  final String team1Logo;
  final String team2Logo;
  final DateTime matchDate;
  final String matchLocation;

  MatchHistoryUserScreen({
    required this.matchId,
    required this.team1Name,
    required this.team2Name,
    required this.team1Logo,
    required this.team2Logo,
    required this.matchDate,
    required this.matchLocation,
  });

  @override
  _MatchHistoryUserScreenState createState() => _MatchHistoryUserScreenState();
}

class _MatchHistoryUserScreenState extends State<MatchHistoryUserScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> comments = [];
  final TextEditingController _commentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadComments();
    _tabController = TabController(length: 7, vsync: this); // 7 zakładek
  }

  void _loadComments() async {
    DocumentSnapshot snapshot = await FirebaseFirestore.instance
        .collection('matches')
        .doc(widget.matchId)
        .get();

    if (snapshot.exists) {
      setState(() {
        comments = List<Map<String, dynamic>>.from(snapshot['comments'] ?? []);
      });
    }
  }

  void _addComment() async {
    if (_commentController.text.isEmpty) return;

    // Pobierz aktualnie zalogowanego użytkownika
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      // Sprawdź, czy użytkownik jest anonimowy
      String userIdentifier = currentUser.isAnonymous ? 'Anonymous' : currentUser.email ?? 'Anonymous';

      // Utwórz obiekt komentarza z identyfikatorem użytkownika (e-mail lub "Anonymous")
      Map<String, dynamic> newComment = {
        'email': userIdentifier,  // Email lub "Anonymous" w przypadku anonimowego użytkownika
        'text': _commentController.text,
        'timestamp': DateTime.now(),  // Lokalny czas
      };

      // Dodawanie nowego komentarza do Firestore
      await FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.matchId)
          .update({
        'comments': FieldValue.arrayUnion([newComment])
      });

      // Czyszczenie pola tekstowego i ponowne ładowanie komentarzy
      _commentController.clear();
      _loadComments();
    } else {
      print('Użytkownik nie jest zalogowany');
    }
  }

  void _showPlayerStatsDialog(BuildContext context, String playerEmail, String playerName) {
    String playerId = playerEmail.replaceAll('.', '_'); // Zamiana kropek na podkreślenia

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('matches')
              .doc(widget.matchId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Center(child: Text('Brak danych o statystykach.'));
            }

            // Pobranie danych meczu
            var data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

            // Pobranie statystyk dla gracza, używając zamienionego adresu e-mail
            var playerStats = (data['stats'] ?? {})[playerId] as Map<String, dynamic>? ?? {};

            // Sprawdzenie, czy obecny użytkownik jest uczestnikiem meczu
            var participants = List<String>.from(data['participants'] ?? []);
            bool isParticipant = participants.contains(FirebaseAuth.instance.currentUser!.email);

            return DefaultTabController(
              length: isParticipant ? 2 : 1,
              child: Scaffold(
                appBar: AppBar(
                  title: Text('Statystyki: $playerName'),
                  bottom: TabBar(
                    tabs: [
                      Tab(text: 'Statystyki'),
                      if (isParticipant) Tab(text: 'Oceń zawodnika'),
                    ],
                  ),
                ),
                body: TabBarView(
                  children: [
                    // Zakładka 1: Statystyki zawodnika
                    _buildPlayerStats(playerStats),

                    // Zakładka 2: Oceń zawodnika (tylko dla uczestników)
                    if (isParticipant) _buildRatingTab(playerEmail),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _submitStatisticianRating(String email, double rating) async {
    try {
      // Szukamy dokumentu użytkownika po e-mailu
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception("Użytkownik nie istnieje.");
      }

      // Zakładamy, że pierwszy wynik to nasz użytkownik (limit 1)
      DocumentReference userRef = querySnapshot.docs.first.reference;

      // Transakcja na dokumencie użytkownika
      FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot userSnapshot = await transaction.get(userRef);

        // Pobieramy dane użytkownika
        var userData = userSnapshot.data() as Map<String, dynamic>;
        int currentTotalReviewsStatistician = userData['totalReviews_statistician'] ?? 0;
        double currentTotalRatingStatistician = userData['totalRating_statistician']?.toDouble() ?? 0.0;

        // Aktualizacja danych
        int newTotalReviewsStatistician = currentTotalReviewsStatistician + 1;
        double newTotalRatingStatistician = currentTotalRatingStatistician + rating;

        // Zaktualizowanie użytkownika w bazie
        transaction.update(userRef, {
          'totalReviews_statistician': newTotalReviewsStatistician,
          'totalRating_statistician': newTotalRatingStatistician,
        });
      });

      print("Ocena statystyka została zapisana pomyślnie.");
    } catch (e) {
      print("Błąd podczas zapisywania oceny statystyka: $e");
    }
  }

  void _showStatisticianRatingDialog(BuildContext context, String userId, String userName) {
    double rating = 3;  // Ustawiamy początkową wartość oceny na 3, aby była domyślna

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Oceń statystyka: $userName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Ocena statystyka (1-5):'),
              SizedBox(height: 16),
              RatingBar.builder(
                initialRating: 3,  // Domyślna ocena
                minRating: 1,
                direction: Axis.horizontal,
                allowHalfRating: false,
                itemCount: 5,
                itemBuilder: (context, _) => Icon(Icons.star, color: Colors.amber),
                onRatingUpdate: (newRating) {
                  rating = newRating;  // Aktualizowanie wartości oceny
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Anuluj'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Zapisz'),
              onPressed: () {
                _submitStatisticianRating(userId, rating);  // Zapis oceny po kliknięciu przycisku
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _submitRating(String email, double skillsRating, double fairPlayRating, double conflictRating) async {
    try {
      // Szukanie dokumentu użytkownika po adresie email
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception("Użytkownik nie istnieje.");
      }

      // Pobranie odniesienia do dokumentu użytkownika
      DocumentReference userRef = querySnapshot.docs.first.reference;

      // Przeprowadzenie transakcji aktualizacji danych
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot userSnapshot = await transaction.get(userRef);

        // Pobranie danych użytkownika
        var userData = userSnapshot.data() as Map<String, dynamic>;

        // Aktualne dane ocen
        int currentTotalReviews = userData['totalReviews_player'] ?? 0;
        double currentSkillsTotal = userData['totalRating_skills']?.toDouble() ?? 0.0;
        double currentFairPlayTotal = userData['totalRating_fairPlay']?.toDouble() ?? 0.0;
        double currentConflictTotal = userData['totalRating_conflict']?.toDouble() ?? 0.0;

        // Nowe wartości po dodaniu oceny
        int newTotalReviews = currentTotalReviews + 1;
        double newSkillsTotal = currentSkillsTotal + skillsRating;
        double newFairPlayTotal = currentFairPlayTotal + fairPlayRating;
        double newConflictTotal = currentConflictTotal + conflictRating;

        // Aktualizacja dokumentu użytkownika
        transaction.update(userRef, {
          'totalReviews_player': newTotalReviews,
          'totalRating_skills': newSkillsTotal,
          'totalRating_fairPlay': newFairPlayTotal,
          'totalRating_conflict': newConflictTotal,
        });
      });

      print("Ocena zawodnika została zapisana pomyślnie.");
    } catch (e) {
      print("Błąd podczas zapisywania oceny zawodnika: $e");
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.team1Name} vs ${widget.team2Name}'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true, // Scrollowanie zakładek
          tabs: [
            Tab(text: 'Skład drużyny 1'),
            Tab(text: 'Skład drużyny 2'),
            Tab(text: 'Statystyki'),
            Tab(text: 'Strzelcy'),
            Tab(text: 'Uczestnicy'),
            Tab(text: 'Komentarze'),
            Tab(text: 'Zdjęcia'),
          ],
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('matches')
            .doc(widget.matchId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('Ładowanie danych meczu...'));
          }

          // Pobieranie wyniku meczu
          var matchData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          int team1Score = matchData['team1Score'] ?? 0;
          int team2Score = matchData['team2Score'] ?? 0;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo drużyny 1
                        Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(50.0),
                              child: Image.network(
                                widget.team1Logo,
                                width: 65,
                                height: 65,
                                fit: BoxFit.cover,
                              ),
                            ),
                            SizedBox(height: 8),
                            Tooltip(
                              message: widget.team1Name,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: 120),
                                child: Text(
                                  widget.team1Name,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            '$team1Score : $team2Score', // Wyświetlenie wyniku meczu
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ),
                        // Logo drużyny 2
                        Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(50.0),
                              child: Image.network(
                                widget.team2Logo,
                                width: 65,
                                height: 65,
                                fit: BoxFit.cover,
                              ),
                            ),
                            SizedBox(height: 8),
                            Tooltip(
                              message: widget.team2Name,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: 120),
                                child: Text(
                                  widget.team2Name,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Data: ${widget.matchDate.toLocal().toString().split(' ')[0]}',
                          style: TextStyle(fontSize: 16),
                        ),
                        Text(
                          'Godzina: ${widget.matchDate.toLocal().toString().split(' ')[1].substring(0, 5)}',
                          style: TextStyle(fontSize: 16),
                        ),
                        Text(
                          'Miejsce: ${widget.matchLocation}',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTeam1Squad(),
                    _buildTeam2Squad(),
                    _buildStatistics(),
                    _buildGoalScorers(),
                    _buildParticipants(),
                    _buildCommentSection(),
                    _buildPhotos(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<String> fetchUserName(String email) async {
    try {
      var userDoc = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .get();
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

  Widget _buildTeam1Squad() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.matchId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Center(child: Text('Brak danych o składzie drużyny 1.'));
        }

        // Pobranie danych z dokumentu
        var data = snapshot.data!.data() as Map<String, dynamic>;

        List<dynamic> team1Players = data['team1'] ?? [];
        List<dynamic> team1StartingPlayers = data['team1StartingPlayers'] ?? [];
        List<dynamic> team1BenchPlayers = data['team1BenchPlayers'] ?? [];

        FutureBuilder<String> buildPlayerTile(String email) {
          return FutureBuilder<String>(
            future: fetchUserName(email),
            builder: (context, nameSnapshot) {
              String displayName = nameSnapshot.data ?? email; // Jeśli imię i nazwisko nie zostanie znalezione, wyświetl e-mail
              return ListTile(
                title: Text(displayName),
                leading: Icon(Icons.person),
                onTap: () {
                  // Wywołanie dialogu statystyk po kliknięciu na zawodnika
                  _showPlayerStatsDialog(context, email, displayName);
                },
              );
            },
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Skład drużyny 1 (${widget.team1Name})',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),

              // Sprawdzenie czy pierwszy skład został ustalony
              team1StartingPlayers.isNotEmpty
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
                    itemCount: team1StartingPlayers.length,
                    itemBuilder: (context, index) {
                      String playerEmail = team1StartingPlayers[index];
                      return buildPlayerTile(playerEmail);
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
                    itemCount: team1BenchPlayers.length,
                    itemBuilder: (context, index) {
                      String playerEmail = team1BenchPlayers[index];
                      return buildPlayerTile(playerEmail);
                    },
                  ),
                ],
              )
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pierwszy skład i ławka rezerwowych nie zostały wybrane.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Lista wszystkich zawodników',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: team1Players.length,
                    itemBuilder: (context, index) {
                      String playerEmail = team1Players[index];
                      return buildPlayerTile(playerEmail);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTeam2Squad() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.matchId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Center(child: Text('Brak danych o składzie drużyny 2.'));
        }

        // Pobranie danych z dokumentu
        var data = snapshot.data!.data() as Map<String, dynamic>;

        List<dynamic> team2Players = data['team2'] ?? [];
        List<dynamic> team2StartingPlayers = data['team2StartingPlayers'] ?? [];
        List<dynamic> team2BenchPlayers = data['team2BenchPlayers'] ?? [];

        FutureBuilder<String> buildPlayerTile(String email) {
          return FutureBuilder<String>(
            future: fetchUserName(email),
            builder: (context, nameSnapshot) {
              String displayName = nameSnapshot.data ?? email; // Jeśli imię i nazwisko nie zostanie znalezione, wyświetl e-mail
              return ListTile(
                title: Text(displayName),
                leading: Icon(Icons.person),
                onTap: () {
                  // Wywołanie dialogu statystyk po kliknięciu na zawodnika
                  _showPlayerStatsDialog(context, email, displayName);
                },
              );
            },
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Skład drużyny 2 (${widget.team2Name})',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),

              // Sprawdzenie czy pierwszy skład został ustalony
              team2StartingPlayers.isNotEmpty
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
                    itemCount: team2StartingPlayers.length,
                    itemBuilder: (context, index) {
                      String playerEmail = team2StartingPlayers[index];
                      return buildPlayerTile(playerEmail);
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
                    itemCount: team2BenchPlayers.length,
                    itemBuilder: (context, index) {
                      String playerEmail = team2BenchPlayers[index];
                      return buildPlayerTile(playerEmail);
                    },
                  ),
                ],
              )
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pierwszy skład i ławka rezerwowych nie zostały wybrane.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Lista wszystkich zawodników',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: team2Players.length,
                    itemBuilder: (context, index) {
                      String playerEmail = team2Players[index];
                      return buildPlayerTile(playerEmail);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }


  Widget _buildStatistics() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.matchId) // Użyj odpowiedniego ID meczu
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Center(child: Text('Brak danych o statystykach.'));
        }

        var data = snapshot.data!.data() as Map<String, dynamic>;
        var stats = data['stats'] ?? {}; // Pobierz dane statystyk

        return SingleChildScrollView(
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
        );
      },
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

  Widget _buildGoalScorers() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.matchId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Center(child: Text('Brak danych o strzelcach.'));
        }

        // Pobranie danych z dokumentu
        var data = snapshot.data!.data() as Map<String, dynamic>;

        List<dynamic> team1Players = data['team1'] ?? [];
        List<dynamic> team2Players = data['team2'] ?? [];
        List<dynamic> goalScorers = data['goalScorers'] ?? []; // Strzelcy

        FutureBuilder<String> buildPlayerTile(String email) {
          return FutureBuilder<String>(
            future: fetchUserName(email),
            builder: (context, nameSnapshot) {
              String displayName = nameSnapshot.data ?? email; // Jeśli imię i nazwisko nie są dostępne, wyświetl e-mail
              return ListTile(
                title: Text(displayName),
                leading: Icon(Icons.sports_soccer),
              );
            },
          );
        }

        return SingleChildScrollView(
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
                      'Strzelcy ${widget.team1Name}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: goalScorers.where((scorer) => team1Players.contains(scorer)).length,
                      itemBuilder: (context, index) {
                        var team1Scorers = goalScorers.where((scorer) => team1Players.contains(scorer)).toList();
                        String playerEmail = team1Scorers[index];
                        return buildPlayerTile(playerEmail);
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
                      'Strzelcy ${widget.team2Name}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: goalScorers.where((scorer) => team2Players.contains(scorer)).length,
                      itemBuilder: (context, index) {
                        var team2Scorers = goalScorers.where((scorer) => team2Players.contains(scorer)).toList();
                        String playerEmail = team2Scorers[index];
                        return buildPlayerTile(playerEmail);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  Widget _buildParticipants() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.matchId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Center(child: Text('Brak danych o uczestnikach.'));
        }

        // Pobranie danych z dokumentu
        var data = snapshot.data!.data() as Map<String, dynamic>;

        List<dynamic> team1Players = data['team1'] ?? [];
        List<dynamic> team2Players = data['team2'] ?? [];
        List<dynamic> spectators = data['spectators'] ?? [];
        List<dynamic> statisticians = data['statisticians'] ?? [];

        Widget buildLoadingTile() {
          return ListTile(
            title: Text('Ładowanie...'),
          );
        }

        FutureBuilder<String> buildParticipantTile(String email, {Widget? trailing}) {
          return FutureBuilder<String>(
            future: fetchUserName(email),
            builder: (context, nameSnapshot) {
              if (nameSnapshot.connectionState == ConnectionState.waiting) {
                return buildLoadingTile();
              }
              String displayName = nameSnapshot.data ?? 'Nieznany użytkownik'; // Jeśli brak danych
              return ListTile(
                title: Text(displayName),
                trailing: trailing,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserDetailsScreen(userEmail: email),
                    ),
                  );
                },
              );
            },
          );
        }

        return ListView(
          padding: EdgeInsets.all(16.0),
          children: [
            // Drużyna 1
            Text('Drużyna 1 - ${widget.team1Name}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ...team1Players.map((email) => buildParticipantTile(email)).toList(),
            Divider(),

            // Drużyna 2
            Text('Drużyna 2 - ${widget.team2Name}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ...team2Players.map((email) => buildParticipantTile(email)).toList(),
            Divider(),

            // Widzowie
            Text('Widzowie', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ...spectators.map((email) => buildParticipantTile(email)).toList(),
            Divider(),

            // Statystycy
            Text('Statystycy', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ...statisticians.map((email) => buildParticipantTile(
              email,
              trailing: IconButton(
                icon: Icon(Icons.star),
                onPressed: () {
                  _showStatisticianRatingDialog(context, email, "Statystyk");
                },
              ),
            )).toList(),
          ],
        );
      },
    );
  }




  Widget _buildCommentSection() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('matches')
                .doc(widget.matchId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }

              var matchData = snapshot.data!.data() as Map<String, dynamic>?;
              var comments = matchData?['comments'] ?? [];

              if (comments.isEmpty) {
                return Center(child: Text('Brak komentarzy'));
              }

              Widget buildLoadingCommentTile() {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Ładowanie...', style: TextStyle(fontWeight: FontWeight.bold)),
                    CircularProgressIndicator(),
                  ],
                );
              }

              FutureBuilder<String> buildCommentUserName(String email) {
                return FutureBuilder<String>(
                  future: fetchUserName(email),
                  builder: (context, nameSnapshot) {
                    if (nameSnapshot.connectionState == ConnectionState.waiting) {
                      return buildLoadingCommentTile();
                    }
                    return Text(
                      nameSnapshot.data ?? 'Nieznany użytkownik',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    );
                  },
                );
              }

              return ListView.builder(
                itemCount: comments.length,
                itemBuilder: (context, index) {
                  var comment = comments[index];
                  String userEmail = comment['email'] ?? 'Anonymous';
                  String commentText = comment['text'];
                  Timestamp timestamp = comment['timestamp'];

                  DateTime commentDate = timestamp.toDate();
                  String formattedDate = "${commentDate.toLocal()}".split(' ')[0];

                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Card(
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                buildCommentUserName(userEmail),
                                Text(
                                  formattedDate,
                                  style: TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            ExpandableComment(commentText: commentText),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: InputDecoration(hintText: 'Dodaj komentarz'),
                ),
              ),
              IconButton(
                icon: Icon(Icons.send),
                onPressed: _addComment,
              ),
            ],
          ),
        ),
      ],
    );
  }


  // Widget _buildPhotos() {
  //   double _uploadProgress = 0.0;
  //
  //   Future<void> _uploadImage(File imageFile) async {
  //     User? currentUser = FirebaseAuth.instance.currentUser;
  //
  //     if (currentUser != null) {
  //       String userIdentifier = currentUser.isAnonymous ? 'Anonymous' : currentUser.email ?? 'Anonymous';
  //
  //       try {
  //         String fileName = '${widget.matchId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
  //         String storagePath = 'match_images/${widget.matchId}/$fileName';
  //
  //         UploadTask uploadTask = FirebaseStorage.instance
  //             .ref(storagePath)
  //             .putFile(imageFile);
  //
  //         // Listen to upload progress
  //         uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
  //           setState(() {
  //             _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
  //           });
  //         });
  //
  //         TaskSnapshot snapshot = await uploadTask;
  //         String downloadUrl = await snapshot.ref.getDownloadURL();
  //
  //         // Update Firestore with the new image URL
  //         await FirebaseFirestore.instance
  //             .collection('matches')
  //             .doc(widget.matchId)
  //             .update({
  //           'photos': FieldValue.arrayUnion([{
  //             'email': userIdentifier,
  //             'imageUrl': downloadUrl,
  //             'timestamp': DateTime.now(),
  //           }])
  //         });
  //
  //         setState(() {
  //           _uploadProgress = 0.0; // Reset the progress after upload completes
  //         });
  //
  //         print("Obraz przesłany i zapisany do Firestore.");
  //       } catch (e) {
  //         setState(() {
  //           _uploadProgress = 0.0; // Reset progress in case of an error
  //         });
  //         print("Błąd podczas przesyłania obrazu: $e");
  //       }
  //     }
  //   }
  //
  //   Future<void> _pickImage() async {
  //     final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
  //
  //     if (image != null) {
  //       File imageFile = File(image.path);
  //       _uploadImage(imageFile); // Upload image to Firebase Storage
  //     }
  //   }
  //
  //   void _showFullImage(BuildContext context, String imageUrl) {
  //     showDialog(
  //       context: context,
  //       builder: (context) => GestureDetector(
  //         onTap: () => Navigator.pop(context), // Close the dialog on tap
  //         child: Dialog(
  //           backgroundColor: Colors.black,
  //           insetPadding: EdgeInsets.all(10),
  //           child: InteractiveViewer(
  //             child: Image.network(imageUrl, fit: BoxFit.contain),
  //           ),
  //         ),
  //       ),
  //     );
  //   }
  //
  //   return Column(
  //     children: [
  //       Expanded(
  //         child: StreamBuilder<DocumentSnapshot>(
  //           stream: FirebaseFirestore.instance
  //               .collection('matches')
  //               .doc(widget.matchId)
  //               .snapshots(),
  //           builder: (context, snapshot) {
  //             if (!snapshot.hasData || !snapshot.data!.exists) {
  //               return Center(child: Text('Brak zdjęć.'));
  //             }
  //
  //             var data = snapshot.data!.data() as Map<String, dynamic>;
  //             if (!data.containsKey('photos')) {
  //               return Center(child: Text('Brak zdjęć.'));
  //             }
  //
  //             List<dynamic> photos = data['photos'] ?? [];
  //             return ListView.builder(
  //               itemCount: photos.length,
  //               itemBuilder: (context, index) {
  //                 var photo = photos[index];
  //                 return Padding(
  //                   padding: const EdgeInsets.all(8.0),
  //                   child: Column(
  //                     crossAxisAlignment: CrossAxisAlignment.start,
  //                     children: [
  //                       Text(photo['email'] ?? 'Anonimowy'),
  //                       GestureDetector(
  //                         onTap: () => _showFullImage(context, photo['imageUrl']), // Show full image on tap
  //                         child: Image.network(photo['imageUrl'], height: 200, fit: BoxFit.cover),
  //                       ),
  //                       Text(photo['timestamp'].toDate().toString()),
  //                     ],
  //                   ),
  //                 );
  //               },
  //             );
  //           },
  //         ),
  //       ),
  //       ElevatedButton(
  //         onPressed: _pickImage,
  //         child: Text('Dodaj zdjęcie'),
  //       ),
  //       if (_uploadProgress > 0)
  //         Padding(
  //           padding: const EdgeInsets.all(16.0),
  //           child: Column(
  //             children: [
  //               LinearProgressIndicator(value: _uploadProgress),
  //               SizedBox(height: 8),
  //               Text(
  //                 'Przesyłanie: ${(_uploadProgress * 100).toStringAsFixed(0)}%',
  //                 style: TextStyle(fontSize: 16),
  //               ),
  //             ],
  //           ),
  //         ),
  //     ],
  //   );
  // }                     // stare dodawanie zdjec bez poprawy na imie i nazwisko

  Widget _buildPhotos() {
    double _uploadProgress = 0.0;

    Future<void> _uploadImage(File imageFile) async {
      User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        String userIdentifier = currentUser.isAnonymous ? 'Anonymous' : currentUser.email ?? 'Anonymous';

        try {
          String fileName = '${widget.matchId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          String storagePath = 'match_images/${widget.matchId}/$fileName';

          UploadTask uploadTask = FirebaseStorage.instance
              .ref(storagePath)
              .putFile(imageFile);

          // Listen to upload progress
          uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
            setState(() {
              _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
            });
          });

          TaskSnapshot snapshot = await uploadTask;
          String downloadUrl = await snapshot.ref.getDownloadURL();

          // Update Firestore with the new image URL
          await FirebaseFirestore.instance
              .collection('matches')
              .doc(widget.matchId)
              .update({
            'photos': FieldValue.arrayUnion([{
              'email': userIdentifier,
              'imageUrl': downloadUrl,
              'timestamp': DateTime.now(),
            }])
          });

          setState(() {
            _uploadProgress = 0.0; // Reset the progress after upload completes
          });

          print("Obraz przesłany i zapisany do Firestore.");
        } catch (e) {
          setState(() {
            _uploadProgress = 0.0; // Reset progress in case of an error
          });
          print("Błąd podczas przesyłania obrazu: $e");
        }
      }
    }

    Future<void> _pickImage() async {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        File imageFile = File(image.path);
        _uploadImage(imageFile); // Upload image to Firebase Storage
      }
    }

    void _showFullImage(BuildContext context, String imageUrl) {
      showDialog(
        context: context,
        builder: (context) => GestureDetector(
          onTap: () => Navigator.pop(context), // Close the dialog on tap
          child: Dialog(
            backgroundColor: Colors.black,
            insetPadding: EdgeInsets.all(10),
            child: InteractiveViewer(
              child: Image.network(imageUrl, fit: BoxFit.contain),
            ),
          ),
        ),
      );
    }

    FutureBuilder<String> buildPhotoUserName(String email) {
      return FutureBuilder<String>(
        future: fetchUserName(email),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Text('Ładowanie...', style: TextStyle(fontWeight: FontWeight.bold));
          }
          return Text(
            snapshot.data ?? 'Nieznany użytkownik',
            style: TextStyle(fontWeight: FontWeight.bold),
          );
        },
      );
    }

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('matches')
                .doc(widget.matchId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return Center(child: Text('Brak zdjęć.'));
              }

              var data = snapshot.data!.data() as Map<String, dynamic>;
              if (!data.containsKey('photos')) {
                return Center(child: Text('Brak zdjęć.'));
              }

              List<dynamic> photos = data['photos'] ?? [];
              return ListView.builder(
                itemCount: photos.length,
                itemBuilder: (context, index) {
                  var photo = photos[index];
                  String email = photo['email'] ?? 'Anonymous';
                  String imageUrl = photo['imageUrl'];
                  DateTime timestamp = (photo['timestamp'] as Timestamp).toDate();

                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildPhotoUserName(email), // Display user name
                        GestureDetector(
                          onTap: () => _showFullImage(context, imageUrl), // Show full image on tap
                          child: Image.network(imageUrl, height: 200, fit: BoxFit.cover),
                        ),
                        Text('${timestamp.toLocal()}'.split(' ')[0]),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        ElevatedButton(
          onPressed: _pickImage,
          child: Text('Dodaj zdjęcie'),
        ),
        if (_uploadProgress > 0)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                LinearProgressIndicator(value: _uploadProgress),
                SizedBox(height: 8),
                Text(
                  'Przesyłanie: ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
      ],
    );
  }



  Widget _buildPlayerStats(Map<String, dynamic> playerStats) {
    return SingleChildScrollView( // Dodajemy SingleChildScrollView
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatItem('Gole', playerStats['goals'] ?? 0),
            _buildStatItem('Asysty', playerStats['assists'] ?? 0),
            _buildStatItem('Strzały', playerStats['shots'] ?? 0),
            _buildStatItem('Słupek/poprzeczka', playerStats['crossbars'] ?? 0),
            _buildStatItem('Strzały celne', playerStats['shotsOnTarget'] ?? 0),
            _buildStatItem('Strzały niecelne', playerStats['shotsOffTarget'] ?? 0),
            _buildStatItem('Strzały spoza pola karnego', playerStats['shotsOutsideBox'] ?? 0),
            _buildStatItem('Strzały z pola karnego', playerStats['shotsOffTarget'] ?? 0),
            _buildStatItem('Dryblingi', playerStats['dribbles'] ?? 0),
            _buildStatItem('Dośrodkowania', playerStats['crosses'] ?? 0),
            _buildStatItem('Faule', playerStats['fouls'] ?? 0),
            _buildStatItem('Sfaulowany', playerStats['fouled'] ?? 0),
            _buildStatItem('Żółte kartki', playerStats['yellowCards'] ?? 0),
            _buildStatItem('Czerwone kartki', playerStats['redCards'] ?? 0),
          ],
        ),
      ),
    );
  }


  Widget _buildRatingTab(String playerEmail) {
    double skillsRating = 0;
    double fairPlayRating = 0;
    double conflictRating = 0;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Oceń zawodnika w 3 kategoriach:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),

          // Ocena umiejętności
          Text('Umiejętności'),
          RatingBar.builder(
            initialRating: 0,
            minRating: 1,
            direction: Axis.horizontal,
            allowHalfRating: true,
            itemCount: 5,
            itemBuilder: (context, _) => Icon(Icons.star, color: Colors.amber),
            onRatingUpdate: (rating) {
              skillsRating = rating;
            },
          ),
          SizedBox(height: 16),

          // Ocena gry fair
          Text('Gra fair'),
          RatingBar.builder(
            initialRating: 0,
            minRating: 1,
            direction: Axis.horizontal,
            allowHalfRating: true,
            itemCount: 5,
            itemBuilder: (context, _) => Icon(Icons.star, color: Colors.amber),
            onRatingUpdate: (rating) {
              fairPlayRating = rating;
            },
          ),
          SizedBox(height: 16),

          // Ocena konfliktowości
          Text('Konfliktowość'),
          RatingBar.builder(
            initialRating: 0,
            minRating: 1,
            direction: Axis.horizontal,
            allowHalfRating: true,
            itemCount: 5,
            itemBuilder: (context, _) => Icon(Icons.star, color: Colors.amber),
            onRatingUpdate: (rating) {
              conflictRating = rating;
            },
          ),
          SizedBox(height: 10),

          // Przycisk do zapisania oceny
          Center(
            child: ElevatedButton(
              onPressed: () {
                // Sprawdzenie, czy wszystkie oceny są większe od 0
                if (skillsRating > 0 && fairPlayRating > 0 && conflictRating > 0) {
                  _submitRating(playerEmail, skillsRating, fairPlayRating, conflictRating);
                } else {
                  // Wyświetlenie wiadomości, jeśli nie wszystkie oceny zostały uzupełnione
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Proszę ocenić zawodnika w każdej kategorii przed zapisaniem.'),
                    ),
                  );
                }
              },
              child: Text('Zapisz ocenę'),
            ),
          ),
        ],
      ),
    );
  }

// Funkcja pomocnicza do wyświetlania pojedynczego elementu statystyki
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

class ExpandableComment extends StatefulWidget {
  final String commentText;

  ExpandableComment({required this.commentText});

  @override
  _ExpandableCommentState createState() => _ExpandableCommentState();
}

class _ExpandableCommentState extends State<ExpandableComment> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.commentText.length > 100 && !_isExpanded
              ? widget.commentText.substring(0, 100) + '...'
              : widget.commentText,
        ),
        if (widget.commentText.length > 100) // Pokazuj przycisk tylko dla długich komentarzy
          TextButton(
            onPressed: () {
              if (_isExpanded) {
                setState(() {
                  _isExpanded = false;
                });
              } else {
                _showFullCommentDialog(context);
              }
            },
            child: Text(_isExpanded ? 'Zwiń' : 'Rozwiń'),
          ),
      ],
    );
  }

  void _showFullCommentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Pełny komentarz'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.commentText),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _isExpanded = true;
                });
              },
              child: Text('Zamknij'),
            ),
          ],
        );
      },
    );
  }
}


