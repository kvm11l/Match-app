import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditStatisticsScreen extends StatefulWidget {
  final String matchId;
  final String team1Name;
  final String team2Name;
  final String team1LogoUrl;
  final String team2LogoUrl;


  EditStatisticsScreen({
    required this.matchId,
    required this.team1Name,
    required this.team2Name,
    required this.team1LogoUrl,
    required this.team2LogoUrl,
  });

  @override
  _EditStatisticsScreenState createState() => _EditStatisticsScreenState();
}

class _EditStatisticsScreenState extends State<EditStatisticsScreen> with SingleTickerProviderStateMixin {
  late Future<Map<String, dynamic>> _matchData;
  late TabController _tabController;
  Map<String, Map<String, int>> localPlayerStats = {}; // Przechowywanie lokalnych zmian
  Map<String, Map<String, int>> _originalPlayerStats = {}; // Oryginalne dane
  bool firstCaptainAccepted = false;
  bool secondCaptainAccepted = false;
  bool sharedStatsLoaded = false;
  String matchStatus = "";
  bool isFirstCaptain = true; // True dla pierwszego kapitana, False dla drugiego
  List<String> acceptedByList = []; // Lista e-maili kapitanów, którzy zaakceptowali wynik
  Map<String, int> localTeam1Stats = {};
  Map<String, int> localTeam2Stats = {};
  List<String> localTeam1Lineup = [];
  List<String> localTeam2Lineup = [];
  int? team1Score;
  int? team2Score;
  List<String> goalScorers = [];
  int localTeam1Score = 0;
  int localTeam2Score = 0;
  List<String> localGoalScorers = [];
  Map<String, dynamic>? sharedStats;
  Map<String, dynamic>? sharedTeamStats;
  Map<String, dynamic>? sharedLocalScore;
  List<dynamic>? sharedLocalGoalScorers;
  bool isStatsUpdated = false; // Flaga, czy statystyki zostały zmienione i nie zapisane
  bool canLoadSharedStats = false; // Flaga kontrolująca możliwość wczytania danych
  Map<String, int>? originalTeam1Stats;
  Map<String, int>? originalTeam2Stats;
  List<String>? originalGoalScorers;
  int? originalTeam1Score;
  int? originalTeam2Score;
  bool hasLoadedChanges = false; // Flaga sprawdzająca, czy zmiany zostały wczytane

  Map<String, int> initialTeam1Stats = {};
  Map<String, int> initialTeam2Stats = {};
  int? initialTeam1Score;
  int? initialTeam2Score;
  List<String> initialGoalScorers = [];




  bool _hasSharedStats() {
    return sharedStats != null ||
        sharedTeamStats != null ||
        sharedLocalScore != null ||
        (sharedLocalGoalScorers != null && sharedLocalGoalScorers!.isNotEmpty);
  }






  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // 3 zakładki
    _matchData = _fetchMatchData(widget.matchId);
    _matchData.then((data) {
      final stats = data['stats'] as Map<String, dynamic>;
      final acceptedBy = List<String>.from(data['acceptedBy'] ?? []);
      setState(() {
        _originalPlayerStats = stats.map((key, value) {
          if (value is Map<String, dynamic>) {
            return MapEntry(key, value.map((k, v) => MapEntry(k, v as int)));
          } else {
            debugPrint('Unexpected data format for key $key: $value');
            return MapEntry(key, {});
          }
        });
        acceptedByList = acceptedBy;
      });
    }).catchError((error) {
      debugPrint('Error loading match data: $error');
    });
    _getMatchStatus();
    _fetchTeamStatsAndLineups();
    _loadMatchResultAndGoalScorers();
  }


  Future<void> _loadMatchResultAndGoalScorers() async {
    try {
      final matchDoc = await FirebaseFirestore.instance.collection('matches').doc(widget.matchId).get();
      if (!matchDoc.exists) throw Exception("Dane meczu nie zostały znalezione.");

      final matchData = matchDoc.data();

      final team1Score = matchData?['team1Score'] as int?;
      final team2Score = matchData?['team2Score'] as int?;
      final goalScorers = List<String>.from(matchData?['goalScorers'] ?? []);

      setState(() {
        if (team1Score != null && team2Score != null) {
          localTeam1Score = team1Score;
          localTeam2Score = team2Score;

          // 🔹 Zapisujemy początkowe wartości wyniku!
          initialTeam1Score = team1Score;
          initialTeam2Score = team2Score;
        }

        localGoalScorers = goalScorers;
        initialGoalScorers = List<String>.from(goalScorers); // 🔹 Zapisujemy początkowych strzelców!
      });

      print('✅ Początkowe wartości meczu zapisane.');
    } catch (e) {
      print('❌ Błąd wczytywania danych: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd wczytywania danych: $e')),
      );
    }
  }

  void _revertChanges() {
    if (matchStatus == "Zakończony, potwierdzony") return;

    setState(() {
      localPlayerStats.clear();
      sharedStatsLoaded = false;

      // 🔹 Przywrócenie statystyk drużyn z kopii początkowej
      localTeam1Stats = Map<String, int>.from(initialTeam1Stats);
      localTeam2Stats = Map<String, int>.from(initialTeam2Stats);

      // 🔹 Przywrócenie strzelców bramek z kopii początkowej
      localGoalScorers = List<String>.from(initialGoalScorers);

      // 🔹 Przywrócenie wyniku meczu z kopii początkowej
      if (initialTeam1Score != null && initialTeam2Score != null) {
        localTeam1Score = initialTeam1Score!;
        localTeam2Score = initialTeam2Score!;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Statystyki przywrócone do stanu pierwotnego')),
    );

    print('✅ Statystyki drużyn przywrócone: team1 - $localTeam1Stats, team2 - $localTeam2Stats');
    print('✅ Strzelcy bramek przywróceni: $localGoalScorers');
    print('✅ Wynik meczu przywrócony: $localTeam1Score - $localTeam2Score');
  }


  Future<Map<String, dynamic>> _fetchMatchData(String matchId) async {
    // Pobierz dane meczu z Firebase
    final matchDoc = await FirebaseFirestore.instance.collection('matches').doc(matchId).get();

    if (!matchDoc.exists) {
      throw Exception("Match data not found");
    }

    return matchDoc.data() as Map<String, dynamic>;
  }


  Future<void> _fetchTeamStatsAndLineups() async {
    try {
      final matchDoc = await FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.matchId)
          .get();

      if (!matchDoc.exists) {
        throw Exception('Dokument meczu nie istnieje.');
      }

      final matchData = matchDoc.data();
      if (matchData == null) {
        throw Exception('Brak danych w dokumencie meczu.');
      }

      final stats = matchData['stats'] as Map<String, dynamic>? ?? {};

      final Map<String, int> team1Stats = {
        'corners': stats['team1Corners'] ?? 0,
        'crossbars': stats['team1Crossbars'] ?? 0,
        'crosses': stats['team1Crosses'] ?? 0,
        'dribbles': stats['team1Dribbles'] ?? 0,
        'fouls': stats['team1Fouls'] ?? 0,
        'freeKicks': stats['team1FreeKicks'] ?? 0,
        'outPenaltyBox': stats['team1OutPenaltyBox'] ?? 0,
        'penalties': stats['team1Penalties'] ?? 0,
        'penaltyBox': stats['team1PenaltyBox'] ?? 0,
        'redCards': stats['team1RedCards'] ?? 0,
        'shotsOffTarget': stats['team1ShotsOffTarget'] ?? 0,
        'shotsOnTarget': stats['team1ShotsOnTarget'] ?? 0,
        'yellowCards': stats['team1YellowCards'] ?? 0,
        'intervention': stats['team1intervention'] ?? 0,
      };

      final Map<String, int> team2Stats = {
        'corners': stats['team2Corners'] ?? 0,
        'crossbars': stats['team2Crossbars'] ?? 0,
        'crosses': stats['team2Crosses'] ?? 0,
        'dribbles': stats['team2Dribbles'] ?? 0,
        'fouls': stats['team2Fouls'] ?? 0,
        'freeKicks': stats['team2FreeKicks'] ?? 0,
        'outPenaltyBox': stats['team2OutPenaltyBox'] ?? 0,
        'penalties': stats['team2Penalties'] ?? 0,
        'penaltyBox': stats['team2PenaltyBox'] ?? 0,
        'redCards': stats['team2RedCards'] ?? 0,
        'shotsOffTarget': stats['team2ShotsOffTarget'] ?? 0,
        'shotsOnTarget': stats['team2ShotsOnTarget'] ?? 0,
        'yellowCards': stats['team2YellowCards'] ?? 0,
        'intervention': stats['team2intervention'] ?? 0,
      };

      // Pobierz składy drużyn
      final List<String> team1Lineup = List<String>.from(matchData['team1'] ?? []);
      final List<String> team2Lineup = List<String>.from(matchData['team2'] ?? []);

      // Przypisz dane do lokalnych tablic
      setState(() {
        localTeam1Lineup = team1Lineup;
        localTeam2Lineup = team2Lineup;
      });

      setState(() {
        localTeam1Stats = Map<String, int>.from(team1Stats);
        localTeam2Stats = Map<String, int>.from(team2Stats);

        // 🔹 Zapisujemy kopie początkowe!
        initialTeam1Stats = Map<String, int>.from(team1Stats);
        initialTeam2Stats = Map<String, int>.from(team2Stats);
      });

      print('✅ Początkowe statystyki drużyn zapisane.');
    } catch (e) {
      print('❌ Błąd pobierania danych: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd pobierania danych: $e')),
      );
    }
  }

  Future<void> _saveLocalStatsToDatabase() async {
    if (matchStatus == "Zakończony, potwierdzony") return;

    try {
      final matchDoc = FirebaseFirestore.instance.collection('matches').doc(widget.matchId);
      final loggedInCaptainEmail = FirebaseAuth.instance.currentUser?.email;

      if (loggedInCaptainEmail == null) {
        throw Exception('Nie można zweryfikować zalogowanego użytkownika.');
      }

      // Pobierz obecne dane meczu
      final matchData = await matchDoc.get();
      if (!matchData.exists) {
        throw Exception('Dane meczu nie zostały znalezione.');
      }

      final matchInfo = matchData.data();
      final acceptedBy = List<String>.from(matchInfo?['acceptedBy'] ?? []);

      // Usuwamy drugiego kapitana z listy zaakceptowanych
      final updatedAcceptedBy = [loggedInCaptainEmail];

      // Zaktualizuj status meczu na "Zakończony, niepotwierdzony"
      const newStatus = 'Zakończony, niepotwierdzony';

      // Zapisz zmiany w bazie
      await matchDoc.update({
        'sharedStats': localPlayerStats, // Aktualizujemy zmiany w statystykach zawodników
        'sharedTeamStats': {
          'team1': localTeam1Stats,
          'team2': localTeam2Stats,
        }, // Aktualizujemy zmiany w statystykach drużynowych
        'sharedLocalScore': { // Zapis lokalnego wyniku
          'team1': localTeam1Score,
          'team2': localTeam2Score,
        },
        'sharedLocalGoalScorers': localGoalScorers, // Zapis lokalnej tablicy strzelców
        'status': newStatus, // Status pozostaje jako niepotwierdzony
        'acceptedBy': updatedAcceptedBy, // Tylko obecny kapitan na liście zaakceptowanych
      });

      setState(() {
        matchStatus = newStatus;
        sharedStatsLoaded = false; // Drugi kapitan musi wczytać zmiany
        isStatsUpdated = false; // Statystyki zapisane, flaga zresetowana
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          'Zmiany zostały zapisane. Oczekiwanie na odpowiedź drugiego kapitana.',
        )),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd zapisywania statystyk: $e')),
      );
    }
  }

  Future<void> _loadSharedStats() async {
    if (matchStatus == "Zakończony, potwierdzony") return;

    try {
      final matchDoc = await FirebaseFirestore.instance.collection('matches').doc(widget.matchId).get();
      if (!matchDoc.exists) throw Exception("Match not found");

      setState(() {
        sharedStats = matchDoc.data()?['sharedStats'] as Map<String, dynamic>?;
        sharedTeamStats = matchDoc.data()?['sharedTeamStats'] as Map<String, dynamic>?;
        sharedLocalScore = matchDoc.data()?['sharedLocalScore'] as Map<String, dynamic>?;
        sharedLocalGoalScorers = matchDoc.data()?['sharedLocalGoalScorers'] as List<dynamic>?;
        hasLoadedChanges = true; // ✅ Ustawienie flagi po wczytaniu zmian
      });

      // (Opcjonalne) Inicjalizacja lokalnych zmiennych na podstawie załadowanych danych
      if (sharedStats != null) {
        localPlayerStats = sharedStats!.map(
              (key, value) => MapEntry(key, (value as Map).map((k, v) => MapEntry(k, v as int))),
        );
      }
      if (sharedTeamStats != null) {
        localTeam1Stats = (sharedTeamStats!['team1'] as Map<String, dynamic>)
            .map((key, value) => MapEntry(key, value as int));
        localTeam2Stats = (sharedTeamStats!['team2'] as Map<String, dynamic>)
            .map((key, value) => MapEntry(key, value as int));
      }
      if (sharedLocalScore != null) {
        localTeam1Score = sharedLocalScore!['team1'] as int;
        localTeam2Score = sharedLocalScore!['team2'] as int;
      }
      if (sharedLocalGoalScorers != null) {
        localGoalScorers = sharedLocalGoalScorers!.map((e) => e as String).toList();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Statystyki i wyniki wczytane')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd wczytywania danych meczu: $e')),
      );
    }
  }

  Future<void> _acceptStats() async {
    if (matchStatus == "Zakończony, potwierdzony") {
      return; // Jeśli mecz jest już zakończony i potwierdzony, nic nie rób
    }

    try {
      final matchDoc = FirebaseFirestore.instance.collection('matches').doc(widget.matchId);
      final matchData = await matchDoc.get();

      if (!matchData.exists) {
        throw Exception('Dane meczu nie zostały znalezione.');
      }

      final matchInfo = matchData.data();
      final acceptedBy = List<String>.from(matchInfo?['acceptedBy'] ?? []);
      final loggedInCaptainEmail = FirebaseAuth.instance.currentUser?.email;

      if (loggedInCaptainEmail == null) {
        throw Exception('Nie można zweryfikować zalogowanego użytkownika.');
      }

      // Sprawdzenie, czy istnieją zmienione statystyki, a użytkownik ich nie wczytał
      bool hasPendingChanges = (matchInfo?['sharedLocalGoalScorers'] != null && (matchInfo?['sharedLocalGoalScorers'] as List).isNotEmpty) ||
          (matchInfo?['sharedLocalScore'] != null && (matchInfo?['sharedLocalScore'] as Map).isNotEmpty) ||
          (matchInfo?['sharedStats'] != null && (matchInfo?['sharedStats'] as Map).isNotEmpty) ||
          (matchInfo?['sharedTeamStats'] != null && (matchInfo?['sharedTeamStats'] as Map).isNotEmpty);

      if (hasPendingChanges && !hasLoadedChanges) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Najpierw wczytaj zmiany przed zaakceptowaniem wyniku meczu.')),
        );
        return;
      }

      if (acceptedBy.contains(loggedInCaptainEmail)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Już zaakceptowałeś wynik meczu')),
        );
        return;
      }

      acceptedBy.add(loggedInCaptainEmail);
      bool isFinalConfirmation = acceptedBy.length == 2;
      String newStatus = isFinalConfirmation ? 'Zakończony, potwierdzony' : 'Zakończony, niepotwierdzony';

      Map<String, dynamic> updates = {
        'acceptedBy': acceptedBy,
        'status': newStatus,
      };

      if (isFinalConfirmation) {
        updates['goalScorers'] = List<String>.from(matchInfo?['sharedLocalGoalScorers'] ?? []);
        Map<String, dynamic> sharedLocalScore = Map<String, dynamic>.from(matchInfo?['sharedLocalScore'] ?? {});

        updates['team1Score'] = sharedLocalScore['team1'] ?? 0;
        updates['team2Score'] = sharedLocalScore['team2'] ?? 0;

        setState(() {
          team1Score = sharedLocalScore['team1'] ?? 0;
          team2Score = sharedLocalScore['team2'] ?? 0;
        });

        await matchDoc.update(updates);

        Map<String, dynamic> playerStats = Map<String, dynamic>.from(matchInfo?['stats'] ?? {});
        Map<String, dynamic> sharedStats = Map<String, dynamic>.from(matchInfo?['sharedStats'] ?? {});
        Map<String, dynamic> sharedTeamStats = Map<String, dynamic>.from(matchInfo?['sharedTeamStats'] ?? {});

        for (var email in sharedStats.keys) {
          String transformedEmail = email.replaceAll('.', '_');
          Map<String, int> existingStats = Map<String, int>.from(playerStats[transformedEmail] ?? {});
          Map<String, int> newStats = Map<String, int>.from(sharedStats[email] ?? {});
          Map<String, int> statDifferences = {};

          newStats.forEach((statKey, newValue) {
            int oldValue = existingStats[statKey] ?? 0;
            int difference = newValue - oldValue;
            existingStats[statKey] = newValue;
            statDifferences[statKey] = difference;
          });

          playerStats[transformedEmail] = existingStats;

          var userQuery = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();

          if (userQuery.docs.isNotEmpty) {
            var userDoc = userQuery.docs.first.reference;
            Map<String, dynamic> userStats = (userQuery.docs.first.data() as Map<String, dynamic>) ?? {};

            statDifferences.forEach((statKey, diff) {
              if (userStats.containsKey(statKey)) {
                userStats[statKey] = (userStats[statKey] as int) + diff;
              } else {
                userStats[statKey] = diff;
              }
            });

            await userDoc.update(userStats);
          }
        }

        sharedTeamStats.forEach((team, stats) {
          Map<String, int> teamStats = Map<String, int>.from(stats);
          teamStats.forEach((key, value) {
            String formattedKey = '${team}${key[0].toUpperCase()}${key.substring(1)}';
            playerStats[formattedKey] = value;
          });
        });

        await matchDoc.update({'stats': playerStats});
      } else {
        await matchDoc.update(updates);
      }

      setState(() {
        matchStatus = newStatus;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          newStatus == 'Zakończony, potwierdzony'
              ? 'Statystyki meczu zostały potwierdzone przez obu kapitanów.'
              : 'Wynik zaakceptowany. Oczekiwanie na drugiego kapitana.',
        )),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd akceptacji statystyk: $e')),
      );
    }
  }

// Funkcja do pobierania imienia i nazwiska użytkownika na podstawie e-maila
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

  // Funkcja do budowania wiersza statystyk
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

  Future<Map<String, dynamic>> _fetchPlayerStats(String playerEmail) async {
    try {
      // Zamiana kropki na podkreślenie w e-mailu
      final sanitizedEmail = playerEmail.replaceAll('.', '_');

      // Pobierz dane meczu z kolekcji `matches`
      final matchDoc = await FirebaseFirestore.instance.collection('matches').doc(widget.matchId).get();

      if (!matchDoc.exists) {
        throw Exception("Match not found for ID: ${widget.matchId}");
      }

      // Pobierz mapę `stats` z danych meczu
      final matchData = matchDoc.data() as Map<String, dynamic>;
      final stats = matchData['stats'] as Map<String, dynamic>?;

      if (stats == null || !stats.containsKey(sanitizedEmail)) {
        print('Statystyki dla zawodnika $sanitizedEmail nie istnieją.');
        return _defaultPlayerStats();
      }

      // Pobierz statystyki zawodnika
      final playerStats = stats[sanitizedEmail] as Map<String, dynamic>;
      print('Statystyki zawodnika $sanitizedEmail: $playerStats');

      return playerStats;
    } catch (e) {
      print('Błąd podczas pobierania statystyk zawodnika: $e');
      return _defaultPlayerStats();
    }
  }

  Map<String, dynamic> _defaultPlayerStats() {
    return {
      'assists': 0,
      'crossbars': 0,
      'crosses': 0,
      'dribbles': 0,
      'fouled': 0,
      'fouls': 0,
      'goals': 0,
      'redCards': 0,
      'shots': 0,
      'shotsInsideBox': 0,
      'shotsOffTarget': 0,
      'shotsOnTarget': 0,
      'shotsOutsideBox': 0,
      'yellowCards': 0,
    };
  }

  void _showPlayerStatsDialog(BuildContext context, String playerEmail) async {
    try {
      // Pobierz statystyki zawodnika, używając lokalnych zmian jako pierwszeństwa
      Map<String, int> editableStats = localPlayerStats[playerEmail] ??
          (await _fetchPlayerStats(playerEmail)).map((key, value) => MapEntry(key, value as int));

      // Skopiuj oryginalne statystyki, aby móc wykryć różnice
      Map<String, int> originalStats = Map<String, int>.from(editableStats);

      // Mapa tłumaczeń statystyk
      Map<String, String> statLabels = {
        "assists": "Asysty",
        "crossbars": "Słupek/ poprzeczka",
        "crosses": "Dośrodkowania",
        "dribbles": "Dryblingi",
        "fouled": "Faulowany",
        "fouls": "Faule",
        "goals": "Gole",
        "redCards": "Czerwone kartki",
        "shots": "Strzały",
        "shotsInsideBox": "Z pola karnego",
        "shotsOffTarget": "Strzały niecelne",
        "shotsOnTarget": "Strzały celne",
        "shotsOutsideBox": "Spoza pola karnego",
        "yellowCards": "Żółte kartki",
      };

      showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Text('Edytuj statystyki zawodnika'),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: editableStats.entries.map((entry) {
                      String statName = statLabels[entry.key] ?? entry.key; // Pobranie tłumaczenia lub oryginalnej nazwy

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(statName, style: TextStyle(fontSize: 16)), // Wyświetlanie przetłumaczonej nazwy
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.remove, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    if (editableStats[entry.key]! > 0) {
                                      editableStats[entry.key] = editableStats[entry.key]! - 1;
                                    }
                                  });
                                },
                              ),
                              Text(
                                editableStats[entry.key].toString(),
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                icon: Icon(Icons.add, color: Colors.green),
                                onPressed: () {
                                  setState(() {
                                    editableStats[entry.key] = editableStats[entry.key]! + 1;
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Anuluj'),
                  ),
                  TextButton(
                    onPressed: () {
                      // Aktualizuj statystyki drużynowe przed zamknięciem dialogu
                      _updateTeamStats(playerEmail, originalStats, editableStats);

                      setState(() {
                        localPlayerStats[playerEmail] = editableStats; // Zapis lokalnych zmian
                      });
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
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Błąd'),
          content: Text('Nie udało się załadować statystyk zawodnika.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Zamknij'),
            ),
          ],
        ),
      );
    }
  }

// Funkcja aktualizująca statystyki drużynowe na podstawie zmian zawodnika
  void _updateTeamStats(String playerEmail, Map<String, int> originalStats, Map<String, int> updatedStats) {
    bool isTeam1 = localTeam1Lineup.contains(playerEmail); // Sprawdź, do którego zespołu należy zawodnik
    int teamScore = isTeam1 ? localTeam1Score : localTeam2Score;

    updatedStats.forEach((key, updatedValue) {
      int originalValue = originalStats[key] ?? 0;
      int difference = updatedValue - originalValue;

      if (key == 'goals') {
        // Aktualizuj listę strzelców i wynik
        if (difference > 0) {
          // Dodawanie goli
          for (int i = 0; i < difference; i++) {
            localGoalScorers.add(playerEmail); // Dodaj zawodnika jako strzelca
            if (isTeam1) {
              localTeam1Score++;
            } else {
              localTeam2Score++;
            }
          }
        } else if (difference < 0) {
          for (int i = 0; i < -difference; i++) {
            if (localGoalScorers.contains(playerEmail)) {
              localGoalScorers.remove(playerEmail);
              if (isTeam1 && localTeam1Score > 0) {
                localTeam1Score--;
              } else if (!isTeam1 && localTeam2Score > 0) {
                localTeam2Score--;
              }
            }
          }
        }
      }

      // Zaktualizuj inne statystyki drużynowe, jeśli istnieją
      Map<String, int> teamStats = isTeam1 ? localTeam1Stats : localTeam2Stats;
      if (teamStats.containsKey(key)) {
        teamStats[key] = (teamStats[key] ?? 0) + difference;
      }
    });

    setState(() {
      isStatsUpdated = true; // Oznacz, że statystyki zostały zmienione
    });

    print('Zaktualizowano statystyki drużyny: ${isTeam1 ? "Team 1" : "Team 2"}');
  }

  Widget _buildPlayerSection(String title, List<dynamic> players) {
    if (players.isEmpty) {
      return Container(); // Nie wyświetlamy pustych sekcji
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            title,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        ListView.builder(
          shrinkWrap: true, // Umożliwia przewijanie tylko tej sekcji
          itemCount: players.length,
          itemBuilder: (context, index) {
            String email = players[index];

            return FutureBuilder<String>(
              future: fetchUserName(email), // Pobranie imienia i nazwiska
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return ListTile(
                    leading: Icon(Icons.person),
                    title: Text("Ładowanie..."), // Wyświetla "Ładowanie..." podczas pobierania danych
                  );
                }

                String displayName = snapshot.data ?? email; // Jeśli błąd, pokazuje email

                return ListTile(
                  leading: Icon(Icons.person),
                  title: Text(displayName),
                  onTap: () => _showPlayerStatsDialog(context, email),
                );
              },
            );
          },
        ),
        SizedBox(height: 10), // Dodanie przestrzeni po sekcji
      ],
    );
  }

  String _getAcceptedByMessage(List<String> acceptedBy) {
    final loggedInCaptainEmail = FirebaseAuth.instance.currentUser?.email;
    final isLoggedInAccepted = acceptedBy.contains(loggedInCaptainEmail);

    return 'Akceptacja: ${acceptedBy.length}/2 '
        '${isLoggedInAccepted ? '(Ty zaakceptowałeś)' : ''}';
  }

  Future<void> _getMatchStatus() async {
    try {
      final matchDoc = await FirebaseFirestore.instance.collection('matches').doc(widget.matchId).get();
      if (!matchDoc.exists) throw Exception("Match not found");

      setState(() {
        matchStatus = matchDoc.data()?['status'] as String? ?? "Zakończony, niepotwierdzony";
        firstCaptainAccepted = matchDoc.data()?['firstCaptainAccepted'] ?? false;
        secondCaptainAccepted = matchDoc.data()?['secondCaptainAccepted'] ?? false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd pobierania statusu meczu: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMatchConfirmed = matchStatus == "Zakończony, potwierdzony";
    final acceptButtonText = 'Akceptuj wynik (${firstCaptainAccepted ? 1 : 0}/${secondCaptainAccepted ? 2 : 1})';
    final canSaveOrAccept = sharedStatsLoaded || localPlayerStats.isEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text('Edycja statystyk - ${widget.team1Name} vs ${widget.team2Name}'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Skład ${widget.team1Name}'),
            Tab(text: 'Skład ${widget.team2Name}'),
            Tab(text: 'Statystyki'),
          ],
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _matchData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Błąd podczas ładowania danych: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data == null) {
            return Center(child: Text('Brak danych dla meczu.'));
          }

          final matchData = snapshot.data!;
          final stats = matchData['stats'] ?? {};
          final team1Starting = List<String>.from(matchData['team1StartingPlayers'] ?? []);
          final team1Bench = List<String>.from(matchData['team1BenchPlayers'] ?? []);
          final team1 = List<String>.from(matchData['team1'] ?? []);
          final team2Starting = List<String>.from(matchData['team2StartingPlayers'] ?? []);
          final team2Bench = List<String>.from(matchData['team2BenchPlayers'] ?? []);
          final team2 = List<String>.from(matchData['team2'] ?? []);

          return Column(
            children: [
              // Logo drużyn, nazwa drużyny i wynik meczu
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, // Skrajne rozmieszczenie
                  children: [
                    // Kolumna dla drużyny 1
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(25),
                          child: Image.network(widget.team1LogoUrl, height: 65, width: 65, fit: BoxFit.cover),
                        ),
                        SizedBox(height: 5),
                        Tooltip(
                          message: widget.team1Name,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: 120),
                            child: Text(
                              widget.team1Name,
                              overflow: TextOverflow.ellipsis,
                              softWrap: true,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Wynik meczu wyśrodkowany
                    Expanded(
                      child: Center(
                        child: Text(
                          '$localTeam1Score - $localTeam2Score',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                    // Kolumna dla drużyny 2
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(50),
                          child: Image.network(widget.team2LogoUrl, height: 65, width: 65, fit: BoxFit.cover),
                        ),
                        SizedBox(height: 5),
                        Tooltip(
                          message: widget.team2Name,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: 120),
                            child: Text(
                              widget.team2Name,
                              overflow: TextOverflow.ellipsis,
                              softWrap: true,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),

              // Zakładki
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Skład drużyny 1
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          if (team1Starting.isNotEmpty)
                            _buildPlayerSection('Pierwszy skład ${widget.team1Name}', team1Starting),
                          if (team1Bench.isNotEmpty)
                            _buildPlayerSection('Ławka rezerwowych ${widget.team1Name}', team1Bench),
                          if (team1Starting.isEmpty && team1Bench.isEmpty)
                            _buildPlayerSection('Zawodnicy ${widget.team1Name}', team1),
                        ],
                      ),
                    ),

                    // Skład drużyny 2
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          if (team2Starting.isNotEmpty)
                            _buildPlayerSection('Pierwszy skład ${widget.team2Name}', team2Starting),
                          if (team2Bench.isNotEmpty)
                            _buildPlayerSection('Ławka rezerwowych ${widget.team2Name}', team2Bench),
                          if (team2Starting.isEmpty && team2Bench.isEmpty)
                            _buildPlayerSection('Zawodnicy ${widget.team2Name}', team2),
                        ],
                      ),
                    ),

                    // Statystyki porównania drużyn
                    SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    _buildStatRow('Strzały celne', localTeam1Stats['shotsOnTarget'] ?? 0, localTeam2Stats['shotsOnTarget'] ?? 0),
                                    _buildStatRow('Strzały niecelne', localTeam1Stats['shotsOffTarget'] ?? 0, localTeam2Stats['shotsOffTarget'] ?? 0),
                                    _buildStatRow('Faule', localTeam1Stats['fouls'] ?? 0, localTeam2Stats['fouls'] ?? 0),
                                    _buildStatRow('Żółte kartki', localTeam1Stats['yellowCards'] ?? 0, localTeam2Stats['yellowCards'] ?? 0),
                                    _buildStatRow('Czerwone kartki', localTeam1Stats['redCards'] ?? 0, localTeam2Stats['redCards'] ?? 0),
                                    _buildStatRow('Rzuty wolne', localTeam1Stats['freeKicks'] ?? 0, localTeam2Stats['freeKicks'] ?? 0),
                                    _buildStatRow('Rzuty rożne', localTeam1Stats['corners'] ?? 0, localTeam2Stats['corners'] ?? 0),
                                    _buildStatRow('Interwencje', localTeam1Stats['intervention'] ?? 0, localTeam2Stats['intervention'] ?? 0),
                                    _buildStatRow('Dribblingi', localTeam1Stats['dribbles'] ?? 0, localTeam2Stats['dribbles'] ?? 0),
                                    _buildStatRow('Karny', localTeam1Stats['penalties'] ?? 0, localTeam2Stats['penalties'] ?? 0),
                                    _buildStatRow('Strzał spoza pola karnym', localTeam1Stats['outPenaltyBox'] ?? 0, localTeam2Stats['outPenaltyBox'] ?? 0),
                                    _buildStatRow('Strzał z pola karnego', localTeam1Stats['penaltyBox'] ?? 0, localTeam2Stats['penaltyBox'] ?? 0),
                                    _buildStatRow('Słupki/Poprzeczka', localTeam1Stats['crossbars'] ?? 0, localTeam2Stats['crossbars'] ?? 0),
                                    _buildStatRow('Dośrodkowania', localTeam1Stats['crosses'] ?? 0, localTeam2Stats['crosses'] ?? 0),
                                  ],
                                ),
                              ),
                            ),

                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  // Pierwszy rząd przycisków
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Flexible(
                        child: ElevatedButton(
                          onPressed: isMatchConfirmed ? null : _revertChanges,
                          child: Text(
                            'Wczytaj dane statystyka',
                            textAlign: TextAlign.center, // Wyrównanie tekstu w przycisku
                          ),
                        ),
                      ),
                      SizedBox(width: 10), // Dystans między przyciskami
                      Flexible(
                        child: ElevatedButton(
                          onPressed: isMatchConfirmed ? null : _saveLocalStatsToDatabase,
                          child: Text(
                            'Zapisz i zaproponuj zmiany',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20), // Odstęp między wierszami
                  // Drugi rząd przycisków
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Flexible(
                        child: ElevatedButton(
                          onPressed: isMatchConfirmed ? null : _loadSharedStats,
                          child: Text(
                            'Wczytaj proponowane zmiany',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Flexible(
                        child: ElevatedButton(
                          onPressed:  matchStatus == "Zakończony, potwierdzony" || isStatsUpdated  ? null : _acceptStats, // Przycisk aktywuje się po wczytaniu zmian
                          child: Text(
                            _getAcceptedByMessage(acceptedByList),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

}
