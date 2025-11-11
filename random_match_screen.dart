import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class RandomMatchScreen extends StatefulWidget {
  @override
  _RandomMatchScreenState createState() => _RandomMatchScreenState();
}

class _RandomMatchScreenState extends State<RandomMatchScreen> {
  final TextEditingController _playerSearchController = TextEditingController();
  final TextEditingController _spectatorSearchController = TextEditingController();
  final TextEditingController _statisticianSearchController = TextEditingController();
  final TextEditingController _matchLocationController = TextEditingController();

  // Kontrolery do zmiany nazwy drużyn
  final TextEditingController _team1NameController = TextEditingController(
      text: 'Team A');
  final TextEditingController _team2NameController = TextEditingController(
      text: 'Team B');

  TextEditingController newViewerController = TextEditingController();
  TextEditingController newStatisticianController = TextEditingController();
  List<DocumentSnapshot> _viewers = [];
  List<DocumentSnapshot> _statisticians = [];
  List<String> spectators = [];
  List<String> statisticians = [];
  Map<String, Map<String, dynamic>> _statisticianDetails = {};
  Map<String, Map<String, dynamic>> _viewerDetails = {};
  final Map<String, Map<String, dynamic>> _playerDetails = {};



  List<String> participants = [];
  List<DocumentSnapshot> _availablePlayers = [];
  bool _isLoadingAvailablePlayers = false;
  int _currentPage = 0;
  int _resultsPerPage = 5;

  bool _showAvailablePlayers = false;


  List<String> _allPlayers = [];
  List<String> _selectedPlayers = [];
  List<String> _team1 = [];
  List<String> _team2 = [];

  String? _team1Captain;
  String? _team2Captain;

  DateTime? matchDate;
  TimeOfDay? matchTime;
  bool canPlayersJoin = true;

  List<String> _spectators = [];

  // Wyniki wyszukiwania
  List<Map<String, String>> _playerSearchResults = [];
  List<Map<String, dynamic>> _availability = [];
  List<QueryDocumentSnapshot<Object?>> _viewerSearchResults = [];
  List<QueryDocumentSnapshot<Object?>> _statisticianSearchResults = [];

  // Stany ładowania i brak wyników
  bool _isLoadingForViewer = false;
  bool _noResultsFoundForViewer = false;
  bool _isLoadingForStatistician = false;
  bool _noResultsFoundForStatistician = false;

  final ImagePicker _picker = ImagePicker();
  String? _team1LogoUrl;
  String? _team2LogoUrl;

  Timer? _debounceForPlayer;
  Timer? _debounceForViewer;
  Timer? _debounceForStatistician;

  @override
  void initState() {
    super.initState();
    _fetchAllPlayers();
    _loadTeamLogos();
  }

  // Funkcja pobierająca wszystkich graczy
  Future<void> _fetchAllPlayers() async {
    try {
      QuerySnapshot playersSnapshot = await FirebaseFirestore.instance
          .collection('users').get();
      setState(() {
        _allPlayers =
            playersSnapshot.docs.map((doc) => doc['email'] as String).toList();
      });
    } catch (e) {
      print("Błąd pobierania graczy: $e");
    }
  }


// Funkcja wyszukiwania graczy (bez zmian w logice)
  void _searchPlayers(String query) async {
    setState(() {
      _playerSearchResults = []; // Wyczyść poprzednie wyniki
    });

    if (query.isEmpty) {
      setState(() {
        _playerSearchResults = [];
      });
      return;
    }

    try {
      QuerySnapshot snapshot;

      // Wyszukiwanie po imieniu
      snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('firstName', isGreaterThanOrEqualTo: query)
          .where('firstName', isLessThanOrEqualTo: query + '\uf8ff')
          .get();

      // Jeśli brak wyników, wyszukaj po nazwisku
      if (snapshot.docs.isEmpty) {
        snapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('lastName', isGreaterThanOrEqualTo: query)
            .where('lastName', isLessThanOrEqualTo: query + '\uf8ff')
            .get();
      }

      setState(() {
        _playerSearchResults = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'email': data['email']?.toString() ?? '',
            'firstName': data['firstName']?.toString() ?? '',
            'lastName': data['lastName']?.toString() ?? '',
            'fullName': '${data['firstName']?.toString() ?? ''} ${data['lastName']?.toString() ?? ''}'
          };
        }).toList().cast<Map<String, String>>(); // Rzutowanie na właściwy typ
      });
    } catch (e) {
      print("Błąd wyszukiwania graczy: $e");
    }
  }

  // Funkcja debounce dla wyszukiwania graczy
  void _onPlayerSearchChanged(String query) {
    if (_debounceForPlayer?.isActive ?? false) _debounceForPlayer!.cancel();

    _debounceForPlayer = Timer(const Duration(milliseconds: 550), () {
      if (query.isEmpty) {
        setState(() {
          _playerSearchResults = [];
        });
      } else {
        _searchPlayers(query);
      }
    });
  }

// Funkcja dodająca gracza do wybranych
  void _addPlayer(String playerEmail) {
    // Szukaj użytkownika w wynikach wyszukiwania (_playerSearchResults)
    final Map<String, dynamic>? userFromSearch = _playerSearchResults.firstWhere(
          (result) => result['email'] == playerEmail,
      orElse: () => {},
    );

    // Szukaj użytkownika w dostępnych graczach (_availablePlayers)
    final Map<String, dynamic>? userFromAvailable = _availablePlayers
        .map((doc) => doc.data() as Map<String, dynamic>)
        .firstWhere(
          (result) => result['email'] == playerEmail,
      orElse: () => {},
    );

    // Wybierz użytkownika: priorytet ma wynik wyszukiwania
    final Map<String, dynamic>? user =
    userFromSearch != null && userFromSearch.isNotEmpty
        ? userFromSearch
        : userFromAvailable;

    if (user != null && user.isNotEmpty) {
      setState(() {
        if (_selectedPlayers.contains(playerEmail)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Użytkownik jest już dodany!')),
          );
        } else {
          _selectedPlayers.add(playerEmail);

          // Dodaj szczegóły zawodnika do _playerDetails
          _playerDetails[playerEmail] = {
            'firstName': user['firstName'],
            'lastName': user['lastName'],
          };

          // Dodaj zawodnika do _availability
          _availability.add({
            'email': playerEmail,
            'status': 'brak decyzji',
          });

          print("Dodano do _availability: $_availability");
        }

        // Wyczyść wyniki wyszukiwania
        _playerSearchController.clear();
        _playerSearchResults = [];
      });
    } else {
      print("Nie znaleziono użytkownika o podanym e-mailu.");
    }
  }

// Funkcja usuwająca gracza z wybranych i drużyn
  void _removePlayer(String playerEmail) {
    setState(() {
      // Usuń gracza z listy wybranych zawodników
      _selectedPlayers.remove(playerEmail);

      // Usuń szczegóły gracza z _playerDetails
      _playerDetails.remove(playerEmail);

      // Usuń gracza z drużyny 1, jeśli tam jest
      _team1.remove(playerEmail);

      // Usuń gracza z drużyny 2, jeśli tam jest
      _team2.remove(playerEmail);

      // Usuń gracza z listy _availability
      _availability.removeWhere((player) => player['email'] == playerEmail);
    });

    _showConfirmationMessage('$playerEmail został usunięty z listy zawodników i drużyn!');
  }

  // Funkcja losowo przydzielająca drużyny
  void _randomlyAssignTeams() {
    if (_selectedPlayers.length < 2) return;

    List<String> players = List.from(_selectedPlayers);
    players.shuffle(Random());

    setState(() {
      _team1 = players.sublist(0, players.length ~/ 2);
      _team2 = players.sublist(players.length ~/ 2);
      _team1Captain = null; // Resetowanie kapitanów
      _team2Captain = null;
    });
  }

  Future<void> _createMatch() async {
    if (matchDate == null || matchTime == null || _team1.isEmpty ||
        _team2.isEmpty || _matchLocationController.text.isEmpty) {
      print("Proszę uzupełnić wszystkie pola przed zapisaniem meczu.");
      return;
    }

    String matchId = DateTime
        .now()
        .millisecondsSinceEpoch
        .toString();
    DateTime matchDateTime = DateTime(
      matchDate!.year,
      matchDate!.month,
      matchDate!.day,
      matchTime!.hour,
      matchTime!.minute,
    );

    Map<String, dynamic> matchData = {
      'canPlayersJoin': canPlayersJoin,
      'maxStartingPlayers': 11,
      'location': _matchLocationController.text,
      'matchDate': matchDateTime,
      'matchId': matchId,
      'participants': _selectedPlayers,
      'spectators': spectators,
      'statisticians': statisticians,
      'team1': _team1,
      'team1BenchPlayers': [],
      'team1Captain': _team1Captain ?? '',
      'team1Logo': _team1LogoUrl,
      'team1Name': _team1NameController.text,
      'team1StartingPlayers': [],
      'team2': _team2,
      'team2BenchPlayers': [],
      'team2Captain': _team2Captain ?? '',
      'team2Logo': _team2LogoUrl,
      'team2Name': _team2NameController.text,
      'team2StartingPlayers': [],
      'timestamp': FieldValue.serverTimestamp(),
      'stats': {},
      'status': 'Nierozpoczęty',
      'availability': _availability,
      // Dodanie pola status z wartością domyślną "Nierozpoczęty"
    };

    try {
      await FirebaseFirestore.instance.collection('matches').doc(matchId).set(
          matchData);
      print("Mecz został pomyślnie utworzony.");
      Navigator.of(context).pop();
    } catch (e) {
      print("Błąd podczas tworzenia meczu: $e");
    }
  }

  // Funkcja przesyłania obrazu do Firebase Storage
  Future<void> _uploadImageToFirebase(int teamNumber, File image) async {
    try {
      String fileName = 'Team_${teamNumber}_logo_${DateTime
          .now()
          .millisecondsSinceEpoch}.webp';
      Reference storageReference = FirebaseStorage.instance.ref().child(
          'logo/$fileName');

      UploadTask uploadTask = storageReference.putFile(image);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        if (teamNumber == 1) {
          _team1LogoUrl = downloadUrl;
        } else {
          _team2LogoUrl = downloadUrl;
        }
      });
    } catch (e) {
      print("Błąd podczas uploadu obrazu: $e");
    }
  }

  // Funkcja wybierania obrazu z galerii
  Future<void> _pickImage(int teamNumber) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      await _uploadImageToFirebase(teamNumber, File(image.path));
    }
  }

  Future<String> _getTeamLogoUrl(String fileName) async {
    try {
      Reference storageReference = FirebaseStorage.instance.ref().child(
          'logo/$fileName');
      String downloadUrl = await storageReference.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Błąd podczas pobierania obrazu: $e');
      return '';
    }
  }

  Future<void> _loadTeamLogos() async {
    String team1LogoUrl = await _getTeamLogoUrl('Team_1_logo.webp');
    String team2LogoUrl = await _getTeamLogoUrl('Team_2_logo.webp');

    setState(() {
      _team1LogoUrl = team1LogoUrl;
      _team2LogoUrl = team2LogoUrl;
    });
  }

  void _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (pickedTime != null) {
        setState(() {
          matchDate = pickedDate;
          matchTime = pickedTime;
        });
      }
    }
  }

  // Funkcja wyszukiwania widzów (bez zmian w logice)
  void _fetchUsersForViewer(String query) async {
    if (query.isEmpty) {
      setState(() {
        _viewerSearchResults = [];
        _noResultsFoundForViewer = false;
        _isLoadingForViewer = false;
      });
      return;
    }

    setState(() {
      _isLoadingForViewer = true;
      _noResultsFoundForViewer = false;
    });

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('firstName', isGreaterThanOrEqualTo: query)
          .where('firstName', isLessThanOrEqualTo: query + '\uf8ff')
          .get();

      if (snapshot.docs.isEmpty) {
        snapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('lastName', isGreaterThanOrEqualTo: query)
            .where('lastName', isLessThanOrEqualTo: query + '\uf8ff')
            .get();
      }

      setState(() {
        _viewerSearchResults = snapshot.docs;
        _noResultsFoundForViewer = snapshot.docs.isEmpty;
        _isLoadingForViewer = false;
      });
    } catch (e) {
      print("Błąd pobierania użytkowników: $e");
      setState(() {
        _isLoadingForViewer = false;
      });
    }
  }

  // Funkcja debounce dla wyszukiwania widzów
  void _onViewerSearchChanged(String query) {
    if (_debounceForViewer?.isActive ?? false) _debounceForViewer!.cancel();

    _debounceForViewer = Timer(const Duration(milliseconds: 550), () {
      if (query.isEmpty) {
        setState(() {
          _viewerSearchResults = [];
          _noResultsFoundForViewer = false;
          _isLoadingForViewer = false;
        });
      } else {
        _fetchUsersForViewer(query);
      }
    });
  }

  // Funkcja dodająca widza do meczu
  void _addViewerToMatch(Map<String, dynamic> viewer) {
    String viewerEmail = viewer['email'];

    if (spectators.contains(viewerEmail)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Widz jest już na liście widzów!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      spectators.add(viewerEmail); // Dodaj tylko e-mail
      _viewerDetails[viewerEmail] = viewer; // Zapisz szczegóły użytkownika lokalnie
      _showConfirmationMessage(
          "${viewer['firstName']} ${viewer['lastName']} został dodany jako widz!");
      _viewerSearchResults = [];
      participants.add(viewerEmail); // Dodaj widza do listy uczestników
      _spectatorSearchController.clear();
    });
  }

  // Funkcja usuwająca widza z meczu (lokalnie)
  void _removeViewerFromMatch(String viewerEmail) {
    setState(() {
      spectators.remove(viewerEmail); // Usuń z listy emaili
      _viewerDetails.remove(viewerEmail); // Usuń szczegóły użytkownika
      participants.remove(viewerEmail); // Usuń widza z listy uczestników

    });
    _showConfirmationMessage("$viewerEmail został usunięty z listy widzów!");
  }

// Funkcja wyszukiwania statystyków (bez zmian w logice)
  void _fetchUsersForStatistician(String query) async {
    if (query.isEmpty) {
      setState(() {
        _statisticianSearchResults = [];
        _noResultsFoundForStatistician = false;
        _isLoadingForStatistician = false;
      });
      return;
    }

    setState(() {
      _isLoadingForStatistician = true;
      _noResultsFoundForStatistician = false;
    });

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('firstName', isGreaterThanOrEqualTo: query)
          .where('firstName', isLessThanOrEqualTo: query + '\uf8ff')
          .get();

      if (snapshot.docs.isEmpty) {
        snapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('lastName', isGreaterThanOrEqualTo: query)
            .where('lastName', isLessThanOrEqualTo: query + '\uf8ff')
            .get();
      }

      setState(() {
        _statisticianSearchResults = snapshot.docs;
        _noResultsFoundForStatistician = snapshot.docs.isEmpty;
        _isLoadingForStatistician = false;
      });
    } catch (e) {
      print("Błąd pobierania użytkowników: $e");
      setState(() {
        _isLoadingForStatistician = false;
      });
    }
  }

  // Funkcja debounce dla wyszukiwania statystyków
  void _onStatisticianSearchChanged(String query) {
    if (_debounceForStatistician?.isActive ?? false) _debounceForStatistician!.cancel();

    _debounceForStatistician = Timer(const Duration(milliseconds: 550), () {
      if (query.isEmpty) {
        setState(() {
          _statisticianSearchResults = [];
          _noResultsFoundForStatistician = false;
          _isLoadingForStatistician = false;
        });
      } else {
        _fetchUsersForStatistician(query);
      }
    });
  }

  // Funkcja dodająca statystyka do meczu
  void _addStatisticianToMatch(Map<String, dynamic> statistician) {
    String statisticianEmail = statistician['email'];

    if (statisticians.contains(statisticianEmail)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Statystyk jest już na liście statystyków!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      statisticians.add(statisticianEmail); // Dodaj tylko e-mail do listy statysticians
      participants.add(statisticianEmail); // Dodaj statystyka do listy uczestników
      _statisticianDetails[statisticianEmail] = statistician; // Przechowuj pełne dane lokalnie
      _showConfirmationMessage(
          "${statistician['firstName']} ${statistician['lastName']} został dodany jako statystyk!");
      _statisticianSearchResults = [];
      _statisticianSearchController.clear();
    });
  }

// Funkcja usuwająca statystyka z meczu (lokalnie)
  void _removeStatisticianFromMatch(String statisticianEmail) {
    setState(() {
      statisticians.remove(statisticianEmail); // Usuń z listy emaili
      _statisticianDetails.remove(statisticianEmail); // Usuń szczegóły użytkownika
      participants.remove(statisticianEmail); // Usuń statystyka z listy uczestników
    });
    _showConfirmationMessage("$statisticianEmail został usunięty z listy statystyków!");
  }

  // Funkcja wyświetlająca komunikat o powodzeniu
  void _showConfirmationMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }


  void _fetchAvailablePlayers() async {
    setState(() {
      _isLoadingAvailablePlayers = true;
      _availablePlayers = [];
    });

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('isAvailable', isEqualTo: true)
          .where('isWillingToPlay', isEqualTo: true)
          .get();

      setState(() {
        _availablePlayers = snapshot.docs;
        _isLoadingAvailablePlayers = false;
        _currentPage = 0; // Resetuj paginację
      });
    } catch (e) {
      print("Błąd pobierania użytkowników chętnych do gry: $e");
      setState(() {
        _isLoadingAvailablePlayers = false;
      });
    }
  }

  List<DocumentSnapshot> _getPaginatedPlayers() {
    final availablePlayersFiltered = _availablePlayers
        .where((user) => !_selectedPlayers.contains(user['email'] as String))
        .toList();

    final startIndex = _currentPage * _resultsPerPage;
    final endIndex = startIndex + _resultsPerPage;
    return availablePlayersFiltered.sublist(
      startIndex,
      endIndex > availablePlayersFiltered.length
          ? availablePlayersFiltered.length
          : endIndex,
    );
  }

  void _nextPage() {
    if ((_currentPage + 1) * _resultsPerPage < _availablePlayers.length) {
      setState(() {
        _currentPage++;
      });
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
    }
  }

  void _removeDuplicatesFromSelectedPlayers() {
    setState(() {
      // Dodajemy listę participants do _selectedPlayers
      _selectedPlayers.addAll(participants);

      // Usuwamy duplikaty z listy _selectedPlayers
      _selectedPlayers = _selectedPlayers.toSet().toList();
    });

    print("Usunięto duplikaty z listy _selectedPlayers.");
  }










  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Stwórz mecz losowy'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Pole wyszukiwania graczy
              TextField(
                controller: _playerSearchController,
                decoration: InputDecoration(
                  labelText: 'Wpisz imię lub nazwisko',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => _onPlayerSearchChanged(value.trim()), // Zamiast bezpośrednio _searchPlayers
              ),
              if (_playerSearchResults.isNotEmpty)
                Column(
                  children: _playerSearchResults.map((result) => ListTile(
                    title: Text(result['fullName']!), // Wyświetl imię i nazwisko użytkownika
                    trailing: IconButton(
                      icon: Icon(Icons.add, color: Colors.green),
                      onPressed: () => _addPlayer(result['email']!), // Dodaj użytkownika po jego emailu
                    ),
                  )).toList(),
                ),

              if (_selectedPlayers.isNotEmpty) ...[
                SizedBox(height: 20),
                Text('Dodani zawodnicy:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: _selectedPlayers.length,
                  itemBuilder: (context, index) {
                    final playerEmail = _selectedPlayers[index];
                    final player = _playerDetails[playerEmail];
                    final playerName = player != null
                        ? '${player['firstName']} ${player['lastName']}'
                        : 'Nieznany użytkownik';

                    return ListTile(
                      title: Text(playerName),
                      subtitle: Text(playerEmail),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removePlayer(playerEmail),
                      ),
                    );
                  },
                ),
              ]
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    'Brak dodanych zawodników',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _randomlyAssignTeams();
                    _team1Captain = null; // Resetujemy kapitanów
                    _team2Captain = null;
                  });
                },
                child: Text('Przydziel losowo do drużyn'),
              ),

              SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Wyświetl chętnych do gry'),
                  Switch(
                    value: _showAvailablePlayers,
                    onChanged: (value) {
                      setState(() {
                        _showAvailablePlayers = value;
                        if (_showAvailablePlayers) {
                          _fetchAvailablePlayers();
                        }
                      });
                    },
                  ),
                ],
              ),

              if (_showAvailablePlayers) ...[
                if (_isLoadingAvailablePlayers)
                  Center(child: CircularProgressIndicator())
                else if (_availablePlayers.isEmpty)
                  Center(
                    child: Text(
                      'Brak użytkowników chętnych do gry.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                else ...[
                    ListView.builder(
                      shrinkWrap: true,
                      itemCount: _getPaginatedPlayers().length,
                      itemBuilder: (context, index) {
                        final user = _getPaginatedPlayers()[index];
                        final userName = '${user['firstName']} ${user['lastName']}';
                        final userEmail = user['email'];

                        return ListTile(
                          title: Text(userName),
                          subtitle: Text(userEmail),
                          leading: Icon(Icons.person, color: Colors.blue),
                          trailing: IconButton(
                            icon: Icon(Icons.add, color: Colors.green),
                            onPressed: () => _addPlayer(userEmail),
                          ),
                        );
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton(
                          onPressed: _previousPage,
                          child: Text('Poprzednia'),
                        ),
                        Text(
                          'Strona ${_currentPage + 1} z ${(_availablePlayers.length / _resultsPerPage).ceil()}',
                        ),
                        ElevatedButton(
                          onPressed: _nextPage,
                          child: Text('Następna'),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                  ],
              ],


              SizedBox(height: 10),

              // Wyświetlanie drużyny 1 z logo
              Row(
                children: [
                  ClipOval(
                    child: Image.network(
                      _team1LogoUrl ?? 'https://example.com/default_team1_logo.png',
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(Icons.image_not_supported, size: 50);
                      },
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _team1NameController,
                      decoration: InputDecoration(labelText: 'Nazwa drużyny 1'),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _pickImage(1),
                    child: Text('Dodaj logo drużyny 1'),
                  ),
                ],
              ),
              SizedBox(height: 10),

// Lista zawodników drużyny 1 z przeciąganiem i upuszczaniem
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0), // Większy obszar przeciągania
                child: Column(
                  children: _team1.map((playerEmail) => Draggable<String>(
                    data: playerEmail,
                    feedback: Material(
                      child: SizedBox(
                        width: 200,
                        child: ListTile(
                          title: Text(
                            '${_playerDetails[playerEmail]?['firstName'] ?? ''} ${_playerDetails[playerEmail]?['lastName'] ?? ''}',
                            style: TextStyle(color: Colors.white),
                          ),
                          tileColor: Colors.blueAccent,
                        ),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.5,
                      child: ListTile(
                        title: Text(
                          '${_playerDetails[playerEmail]?['firstName'] ?? ''} ${_playerDetails[playerEmail]?['lastName'] ?? ''}',
                        ),
                      ),
                    ),
                    child: DragTarget<String>(
                      onAccept: (receivedPlayerEmail) {
                        if (_team2.contains(receivedPlayerEmail)) {
                          setState(() {
                            _team2.remove(receivedPlayerEmail);
                            _team1.add(receivedPlayerEmail);
                            _team1.remove(playerEmail);
                            _team2.add(playerEmail);

                            // Wyczyść kapitanów, jeśli zostali przeciągnięci
                            if (_team1Captain == playerEmail) _team1Captain = null;
                            if (_team2Captain == receivedPlayerEmail) _team2Captain = null;
                          });
                        }
                      },
                      builder: (context, acceptedData, rejectedData) => ListTile(
                        title: Text(
                          '${_playerDetails[playerEmail]?['firstName'] ?? ''} ${_playerDetails[playerEmail]?['lastName'] ?? ''}',
                        ),
                        trailing: Radio<String>(
                          value: playerEmail,
                          groupValue: _team1Captain,
                          onChanged: (value) {
                            setState(() {
                              _team1Captain = value;
                            });
                          },
                        ),
                        subtitle: _team1Captain == playerEmail ? Text('Kapitan') : null,
                      ),
                    ),
                  )).toList(),
                ),
              ),


              SizedBox(height: 20),

              // Wyświetlanie drużyny 2 z logo
              Row(
                children: [
                  ClipOval(
                    child: Image.network(
                      _team2LogoUrl ?? 'https://example.com/default_team2_logo.png',
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(Icons.image_not_supported, size: 50);
                      },
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _team2NameController,
                      decoration: InputDecoration(labelText: 'Nazwa drużyny 2'),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _pickImage(2),
                    child: Text('Dodaj logo drużyny 2'),
                  ),
                ],
              ),
              SizedBox(height: 10),

// Lista zawodników drużyny 2 z przeciąganiem i upuszczaniem
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0), // Większy obszar przeciągania
                child: Column(
                  children: _team2.map((playerEmail) => Draggable<String>(
                    data: playerEmail,
                    feedback: Material(
                      child: SizedBox(
                        width: 200,
                        child: ListTile(
                          title: Text(
                            '${_playerDetails[playerEmail]?['firstName'] ?? ''} ${_playerDetails[playerEmail]?['lastName'] ?? ''}',
                            style: TextStyle(color: Colors.white),
                          ),
                          tileColor: Colors.redAccent,
                        ),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.5,
                      child: ListTile(
                        title: Text(
                          '${_playerDetails[playerEmail]?['firstName'] ?? ''} ${_playerDetails[playerEmail]?['lastName'] ?? ''}',
                        ),
                      ),
                    ),
                    child: DragTarget<String>(
                      onAccept: (receivedPlayerEmail) {
                        if (_team1.contains(receivedPlayerEmail)) {
                          setState(() {
                            _team1.remove(receivedPlayerEmail);
                            _team2.add(receivedPlayerEmail);
                            _team2.remove(playerEmail);
                            _team1.add(playerEmail);

                            // Wyczyść kapitanów, jeśli zostali przeciągnięci
                            if (_team2Captain == playerEmail) _team2Captain = null;
                            if (_team1Captain == receivedPlayerEmail) _team1Captain = null;
                          });
                        }
                      },
                      builder: (context, acceptedData, rejectedData) => ListTile(
                        title: Text(
                          '${_playerDetails[playerEmail]?['firstName'] ?? ''} ${_playerDetails[playerEmail]?['lastName'] ?? ''}',
                        ),
                        trailing: Radio<String>(
                          value: playerEmail,
                          groupValue: _team2Captain,
                          onChanged: (value) {
                            setState(() {
                              _team2Captain = value;
                            });
                          },
                        ),
                        subtitle: _team2Captain == playerEmail ? Text('Kapitan') : null,
                      ),
                    ),
                  )).toList(),
                ),
              ),

              // Przełącznik czy zawodnicy mogą dołączać
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Czy zawodnicy mogą dołączać?'),
                  Switch(
                    value: canPlayersJoin,
                    onChanged: (value) {
                      setState(() {
                        canPlayersJoin = value;
                      });
                    },
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    'Kapitan drużyny 1: ${_team1Captain != null && _playerDetails[_team1Captain] != null ? '${_playerDetails[_team1Captain]!['firstName']} ${_playerDetails[_team1Captain]!['lastName']}' : 'Brak'}',
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    'Kapitan drużyny 2: ${_team2Captain != null && _playerDetails[_team2Captain] != null ? '${_playerDetails[_team2Captain]!['firstName']} ${_playerDetails[_team2Captain]!['lastName']}' : 'Brak'}',
                  ),
                ],
              ),



              SizedBox(height: 20),

              SizedBox(height: 10),
              // Dodawanie widza
              TextField(
                controller: _spectatorSearchController,
                decoration: InputDecoration(
                  labelText: 'Dodaj widza',
                  hintText: 'Wyszukaj widza po imieniu lub nazwisku',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => _onViewerSearchChanged(value.trim()), // Zamiast bezpośrednio _fetchUsersForViewer
              ),
              if (_isLoadingForViewer)
                Center(child: CircularProgressIndicator()),
              if (_noResultsFoundForViewer)
                Center(child: Text('Brak wyników wyszukiwania', style: TextStyle(color: Colors.red))),
              if (!_isLoadingForViewer && _viewerSearchResults.isNotEmpty)
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: _viewerSearchResults.length,
                  itemBuilder: (context, index) {
                    var user = _viewerSearchResults[index].data() as Map<String, dynamic>;
                    String userName = '${user['firstName']} ${user['lastName']}';
                    String userEmail = user['email'];
                    return ListTile(
                      title: Text(userName),
                      subtitle: Text(userEmail),
                      leading: Icon(Icons.person, color: Colors.green),
                      onTap: () => _addViewerToMatch({
                        'email': userEmail,
                        'firstName': user['firstName'],
                        'lastName': user['lastName'],
                      }),
                    );
                  },
                ),

              SizedBox(height: 20),

// Wyświetlanie dodanych widzów z możliwością usunięcia
              Text('Dodani widzowie:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              if (spectators.isNotEmpty)
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: spectators.length,
                  itemBuilder: (context, index) {
                    String viewerEmail = spectators[index];
                    var viewer = _viewerDetails[viewerEmail];

                    return ListTile(
                      title: Text('${viewer?['firstName'] ?? ''} ${viewer?['lastName'] ?? ''}'),
                      subtitle: Text(viewerEmail),
                      leading: Icon(Icons.person, color: Colors.blue),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeViewerFromMatch(viewerEmail),
                      ),
                    );
                  },
                )
              else
                Center(
                  child: Text('Brak dodanych widzów', style: TextStyle(color: Colors.grey)),
                ),



              SizedBox(height: 20),

              // Dodawanie statystyka
              TextField(
                controller: _statisticianSearchController,
                decoration: InputDecoration(
                  labelText: 'Dodaj statystyka',
                  hintText: 'Wyszukaj statystyka po imieniu lub nazwisku',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => _onStatisticianSearchChanged(value.trim()), // Zamiast bezpośrednio _fetchUsersForStatistician
              ),
              if (_isLoadingForStatistician) Center(child: CircularProgressIndicator()),
              if (_noResultsFoundForStatistician)
                Center(child: Text('Brak wyników wyszukiwania', style: TextStyle(color: Colors.red))),
              if (!_isLoadingForStatistician && _statisticianSearchResults.isNotEmpty)
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: _statisticianSearchResults.length,
                  itemBuilder: (context, index) {
                    var user = _statisticianSearchResults[index].data() as Map<String, dynamic>;
                    String userName = '${user['firstName']} ${user['lastName']}';
                    String userEmail = user['email'];
                    return ListTile(
                      title: Text(userName),
                      subtitle: Text(userEmail),
                      leading: Icon(Icons.person, color: Colors.purple),
                      onTap: () => _addStatisticianToMatch({
                        'email': userEmail,
                        'firstName': user['firstName'],
                        'lastName': user['lastName'],
                      }),
                    );
                  },
                ),


              SizedBox(height: 20),

// Wyświetlanie dodanych statystyków z możliwością usunięcia
              Text('Dodani statystycy:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              if (statisticians.isNotEmpty)
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: statisticians.length,
                  itemBuilder: (context, index) {
                    String statisticianEmail = statisticians[index];
                    var statistician = _statisticianDetails[statisticianEmail];

                    return ListTile(
                      title: Text('${statistician?['firstName'] ?? ''} ${statistician?['lastName'] ?? ''}'),
                      subtitle: Text(statisticianEmail),
                      leading: Icon(Icons.person, color: Colors.orange),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeStatisticianFromMatch(statisticianEmail),
                      ),
                    );
                  },
                )
              else
                Center(
                  child: Text('Brak dodanych statystyków', style: TextStyle(color: Colors.grey)),
                ),



              SizedBox(height: 20),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center, // Wyśrodkowanie przycisków w pionie
                    children: [
                      ElevatedButton(
                        onPressed: () => _selectDate(context),
                        child: Text(
                          matchDate != null && matchTime != null
                              ? 'Wybrano: ${DateFormat('dd.MM.yyyy').format(matchDate!)} o ${matchTime!.format(context)}'
                              : 'Wybierz datę i godzinę',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 10),
              // Pole do wpisania miejsca meczu
              TextField(
                controller: _matchLocationController,
                decoration: InputDecoration(
                  labelText: 'Wpisz miejsce meczu',
                ),
              ),
              SizedBox(height: 10),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center, // Wyśrodkowanie przycisków w pionie
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          _removeDuplicatesFromSelectedPlayers(); // Usuń duplikaty
                          _createMatch(); // Następnie stwórz mecz
                        },
                        child: Text('Stwórz mecz'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}


