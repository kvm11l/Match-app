import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io'; // Potrzebne do wyświetlania lokalnie wybranych obrazów
import 'package:intl/intl.dart';
import 'package:firebase_storage/firebase_storage.dart';

class CreateMatchScreen extends StatefulWidget {
  @override
  _CreateMatchScreenState createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends State<CreateMatchScreen> {
  List<DocumentSnapshot> _users = [];

  List<Map<String, dynamic>> _team1 = [];
  List<Map<String, dynamic>> _team2 = [];
  bool _isLoading = false;
  bool _isLoadingForViewer = false;
  bool _noResultsFoundForViewer = false;
  bool _hasSearched = false;
  bool _isLoadingForStatistician = false;
  bool _noResultsFoundForStatistician = false;
  bool _isInitialState = true;
  List<Map<String, dynamic>> _statisticianSearchResults = [];

  List<Map<String, dynamic>> _viewerSearchResults = [];

  List<Map<String, String>> _userDetails = [];
  List<Map<String, String>> _statisticianDetails = [];
  List<Map<String, String>> _spectatorDetails = [];




  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _team1NameController = TextEditingController(text: 'Drużyna 1');
  final TextEditingController _team2NameController = TextEditingController(text: 'Drużyna 2');
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _spectatorSearchController = TextEditingController();
  final TextEditingController _statisticianSearchController = TextEditingController();


  bool canPlayersJoin = true;
  DateTime? matchDate;
  TimeOfDay? matchTime;
  String? team1Captain;
  String? team2Captain;
  String? _team1LogoUrl;
  String? _team2LogoUrl;

  Timer? _debounce;
  Timer? _debounceForViewer;
  Timer? _debounceForStatistician;

  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _spectators = [];
  List<Map<String, dynamic>> _statisticians = [];
  List<Map<String, dynamic>> _availability = [];

  bool _showAvailablePlayers = false;
  bool _isLoadingAvailablePlayers = false;
  List<DocumentSnapshot> _availablePlayers = [];
  int _currentPage = 0;
  int _resultsPerPage = 5; // Możesz zmienić liczbę wyników na stronę
  List<String> _selectedPlayers = [];


// Funkcja do wyszukiwania użytkowników (bez zmian w logice)
  void _fetchUsers(String query) async {
    setState(() {
      _isLoading = true;
      _isInitialState = false; // Wyszukiwanie rozpoczęte
      _users = []; // Czyszczenie poprzednich wyników
    });

    try {
      QuerySnapshot snapshot;

      if (query.isNotEmpty) {
        snapshot = await FirebaseFirestore.instance
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
      } else {
        snapshot = await FirebaseFirestore.instance.collection('users').get();
      }

      setState(() {
        _users = snapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      print("Błąd pobierania użytkowników: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Funkcja debounce do obsługi zmiany tekstu w polu wyszukiwania
  void _onSearchChanged(String query) {
    // Anulowanie poprzedniego debounce
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // Ustawienie nowego debounce z opóźnieniem
    _debounce = Timer(const Duration(milliseconds: 550), () {
      if (query.isEmpty) {
        // Jeśli pole wyszukiwania jest puste, zresetuj wyniki
        setState(() {
          _users = [];
          _isInitialState = true; // Przywrócenie początkowego stanu
          _isLoading = false;
        });
      } else {
        // Wywołanie funkcji fetchUsers
        _fetchUsers(query);
      }
    });
  }

  void _addToTeam(Map<String, dynamic> user, int teamNumber) {
    setState(() {
      if (teamNumber == 1) {
        if (_team1.any((player) => player['email'] == user['email'])) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Użytkownik jest już w drużynie 1!')),
          );
        } else if (_team2.any((player) => player['email'] == user['email'])) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Użytkownik jest już w drużynie 2!')),
          );
        } else {
          _team1.add(user);
          _availability.add({
            'email': user['email'],
            'status': 'brak decyzji'
          });
          _userDetails.add({
            'firstName': user['firstName'],
            'lastName': user['lastName'],
            'email': user['email']
          });
        }
      } else {
        if (_team2.any((player) => player['email'] == user['email'])) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Użytkownik jest już w drużynie 2!')),
          );
        } else if (_team1.any((player) => player['email'] == user['email'])) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Użytkownik jest już w drużynie 1!')),
          );
        } else {
          _team2.add(user);
          _availability.add({
            'email': user['email'],
            'status': 'brak decyzji'
          });
          _userDetails.add({
            'firstName': user['firstName'],
            'lastName': user['lastName'],
            'email': user['email']
          });
        }
      }
      _searchController.clear();
      _isInitialState = true;
      _users = [];
    });
  }

  void _removeFromTeam(Map<String, dynamic> user, int teamNumber) {
    setState(() {
      if (teamNumber == 1) {
        _team1.remove(user);
      } else {
        _team2.remove(user);
      }
      _availability.removeWhere((entry) => entry['email'] == user['email']);
      _userDetails.removeWhere((entry) => entry['email'] == user['email']);
    });
  }

  // Funkcja wyszukiwania widzów (bez zmian w logice)
  void _fetchUsersForViewer(String query) async {
    if (query.isEmpty) {
      setState(() {
        _viewerSearchResults.clear();
        _noResultsFoundForViewer = false;
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
        _viewerSearchResults = snapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
        _isLoadingForViewer = false;
        _noResultsFoundForViewer = _viewerSearchResults.isEmpty;
      });
    } catch (e) {
      print("Error fetching users for viewer: $e");
      setState(() {
        _isLoadingForViewer = false;
        _noResultsFoundForViewer = true;
      });
    }
  }

  // Funkcja debounce dla widzów
  void _onViewerSearchChanged(String query) {
    if (_debounceForViewer?.isActive ?? false) _debounceForViewer!.cancel();

    _debounceForViewer = Timer(const Duration(milliseconds: 550), () {
      if (query.isEmpty) {
        setState(() {
          _viewerSearchResults.clear();
          _noResultsFoundForViewer = false;
          _isLoadingForViewer = false;
        });
      } else {
        _fetchUsersForViewer(query);
      }
    });
  }

  void _addViewerToMatch(String email) {
    var selectedUser = _viewerSearchResults.firstWhere((user) => user['email'] == email);
    setState(() {
      _spectators.add(selectedUser);
      _spectatorDetails.add({
        'firstName': selectedUser['firstName'],
        'lastName': selectedUser['lastName'],
        'email': selectedUser['email'],
      });
      _viewerSearchResults.clear();
      _spectatorSearchController.clear();
    });
  }

  void _removeSpectator(Map<String, dynamic> user) {
    setState(() {
      _spectators.remove(user);
      _availability.removeWhere((entry) => entry['email'] == user['email']);
      _spectatorDetails.removeWhere((entry) => entry['email'] == user['email']);
    });
  }

// Funkcja wyszukiwania statystyków (bez zmian w logice)
  void _fetchUsersForStatistician(String query) async {
    if (query.isEmpty) {
      setState(() {
        _statisticianSearchResults.clear();
        _noResultsFoundForStatistician = false;
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
        _statisticianSearchResults = snapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
        _isLoadingForStatistician = false;
        _noResultsFoundForStatistician = _statisticianSearchResults.isEmpty;
      });
    } catch (e) {
      print("Error fetching users for statistician: $e");
      setState(() {
        _isLoadingForStatistician = false;
        _noResultsFoundForStatistician = true;
      });
    }
  }

  // Funkcja debounce dla statystyków
  void _onStatisticianSearchChanged(String query) {
    if (_debounceForStatistician?.isActive ?? false) _debounceForStatistician!.cancel();

    _debounceForStatistician = Timer(const Duration(milliseconds: 550), () {
      if (query.isEmpty) {
        setState(() {
          _statisticianSearchResults.clear();
          _noResultsFoundForStatistician = false;
          _isLoadingForStatistician = false;
        });
      } else {
        _fetchUsersForStatistician(query);
      }
    });
  }

  void _addStatisticianToMatch(String email) {
    var selectedUser = _statisticianSearchResults.firstWhere((user) => user['email'] == email);
    setState(() {
      _statisticians.add(selectedUser);
      _statisticianDetails.add({
        'firstName': selectedUser['firstName'],
        'lastName': selectedUser['lastName'],
        'email': selectedUser['email'],
      });
      _statisticianSearchResults.clear();
      _statisticianSearchController.clear();
    });
  }

  void _removeStatistician(Map<String, dynamic> user) {
    setState(() {
      _statisticians.remove(user);
      _availability.removeWhere((entry) => entry['email'] == user['email']);
      _statisticianDetails.removeWhere((entry) => entry['email'] == user['email']);
    });
  }


// Metoda do wyboru daty i godziny
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
          matchTime = pickedTime; // Zapisz wybraną godzinę
        });
      }
    }
  }

  Future<void> _createMatch() async {
    // Sprawdzanie, czy wszystkie wymagane pola są uzupełnione
    if (_team1.isEmpty ||
        _team2.isEmpty ||
        _spectators.isEmpty ||
        _statisticians.isEmpty ||
        team1Captain == null ||
        team2Captain == null ||
        _team1NameController.text.isEmpty ||
        _team2NameController.text.isEmpty ||
        matchDate == null ||
        _locationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Wszystkie pola muszą być uzupełnione!')),
      );
      return;
    }


    // Ustawienie domyślnych logo, jeśli nie zostały dodane
    if (_team1LogoUrl == null) {
      _team1LogoUrl = 'https://firebasestorage.googleapis.com/v0/b/loginapp-796b3.appspot.com/o/logo%2FTeam_1_logo.webp?alt=media&token=6fc06ac6-d336-46a1-b453-5d3f4fdc4828'; // Zmień na link do domyślnego logo drużyny 1
    }
    if (_team2LogoUrl == null) {
      _team2LogoUrl = 'https://firebasestorage.googleapis.com/v0/b/loginapp-796b3.appspot.com/o/logo%2FTeam_2_logo.webp?alt=media&token=136ddb22-1d83-43ad-b442-760923538f67'; // Zmień na link do domyślnego logo drużyny 2
    }

    // Tworzenie zestawu participants (uczestników meczu) bez duplikatów
    Set<String> participantsSet = {};

    // Dodawanie zawodników z obu drużyn
    participantsSet.addAll(_team1.map((user) => user['email'].toString()).toList());
    participantsSet.addAll(_team2.map((user) => user['email'].toString()).toList());

    // Dodawanie widzów i statystyków
    participantsSet.addAll(_spectators.map((user) => user['email'].toString()).toList());
    participantsSet.addAll(_statisticians.map((user) => user['email'].toString()).toList());

    // Konwersja zestawu na listę, ponieważ Firestore nie obsługuje zestawów
    List<String> participants = participantsSet.toList();

    // Generowanie matchId na podstawie aktualnego czasu
    String matchId = DateTime.now().millisecondsSinceEpoch.toString();
    DateTime matchDateTime = DateTime(
      matchDate!.year,
      matchDate!.month,
      matchDate!.day,
      matchTime!.hour,
      matchTime!.minute,
    );

    // Przygotowanie danych meczu
    final matchData = {
      'team1': _team1.map((user) => user['email'].toString()).toList(),
      'team2': _team2.map((user) => user['email'].toString()).toList(),
      'team1Name': _team1NameController.text,
      'team2Name': _team2NameController.text,
      'location': _locationController.text,
      'matchId': matchId,
      'timestamp': FieldValue.serverTimestamp(),
      'matchDate': matchDateTime,
      'team1Captain': team1Captain,
      'team2Captain': team2Captain,
      'canPlayersJoin': canPlayersJoin,
      'spectators': _spectators.map((user) => user['email'].toString()).toList(),
      'statisticians': _statisticians.map((user) => user['email'].toString()).toList(),
      'team1Logo': _team1LogoUrl, // Użyj zaktualizowanego URL do logo drużyny 1
      'team2Logo': _team2LogoUrl, // Użyj zaktualizowanego URL do logo drużyny 2
      'participants': participants, // dodanie listy uczestników bez duplikatów
      'availability': _availability, // dodanie listy dostępności
      'stats': {}, // Dodanie pustej mapy stats
      'status': 'Nierozpoczęty', // Dodanie pola status z wartością domyślną "Nierozpoczęty"
      'maxStartingPlayers': 11,
      'userDetalis': _userDetails,
      'statisticianDetails': _statisticianDetails,
      'spectatorDetails': _spectatorDetails,
      'team1BenchPlayers': [],
      'team1StartingPlayers': [],
      'team2BenchPlayers': [],
      'team2StartingPlayers': [],

    };

    try {
      // Zapisywanie danych meczu do Firestore pod określonym matchId
      await FirebaseFirestore.instance.collection('matches').doc(matchId).set(matchData);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Mecz został stworzony!')));
    } catch (e) {
      print("Błąd zapisu meczu: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Wystąpił błąd przy tworzeniu meczu.')));
    }
  }


  Future<void> _uploadImageToFirebase(int teamNumber, File image) async {
    try {
      String fileName = 'Team_${teamNumber}_logo_${DateTime.now().millisecondsSinceEpoch}.webp';
      Reference storageReference = FirebaseStorage.instance.ref().child('logo/$fileName');

      UploadTask uploadTask = storageReference.putFile(image);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        if (teamNumber == 1) {
          _team1LogoUrl = downloadUrl; // Zaktualizuj logo drużyny 1
        } else {
          _team2LogoUrl = downloadUrl; // Zaktualizuj logo drużyny 2
        }
      });
    } catch (e) {
      print("Błąd podczas uploadu obrazu: $e");
    }
  }


  Future<void> _pickImage(int teamNumber) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      await _uploadImageToFirebase(teamNumber, File(image.path));
    }
  }

  Future<String> _getTeamLogoUrl(String fileName) async {
    try {
      // Pobierz referencję do pliku w Storage
      Reference storageReference = FirebaseStorage.instance.ref().child('logo/$fileName');

      // Pobierz publiczny URL do pliku
      String downloadUrl = await storageReference.getDownloadURL();

      return downloadUrl;  // Zwróć URL obrazu
    } catch (e) {
      print('Błąd podczas pobierania obrazu: $e');
      return '';  // W razie błędu zwróć pusty string
    }
  }

  @override
  void initState() {
    super.initState();

    // Pobierz URL-e do domyślnych logo drużyn
    _loadTeamLogos();

  }

  Future<void> _loadTeamLogos() async {
    String team1LogoUrl = await _getTeamLogoUrl('Team_1_logo.webp');
    String team2LogoUrl = await _getTeamLogoUrl('Team_2_logo.webp');

    setState(() {
      _team1LogoUrl = team1LogoUrl;  // Zapisz URL do logo drużyny 1
      _team2LogoUrl = team2LogoUrl;  // Zapisz URL do logo drużyny 2
    });
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
        _currentPage = 0;
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




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Stwórz spotkanie'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Pole do wyszukiwania użytkowników
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Wpisz imię lub nazwisko',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => _onSearchChanged(value.trim()), // Zamiast bezpośrednio _fetchUsers
              ),
              SizedBox(height: 20),
              _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _isInitialState
                  ? Center(child: Text('Wpisz imię lub nazwisko, aby rozpocząć wyszukiwanie.'))
                  : _users.isEmpty
                  ? Center(
                child: Text(
                  'Brak wyników wyszukiwania',
                  style: TextStyle(color: Colors.red),
                ),
              )
                  : ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _users.length,
                itemBuilder: (context, index) {
                  var user = _users[index].data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text('${user['firstName']} ${user['lastName']}'),
                    subtitle: Text('Email: ${user['email']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.looks_one_rounded, color: Colors.green),
                          onPressed: () => _addToTeam(user, 1),
                          tooltip: 'Dodaj do drużyny 1',
                        ),
                        IconButton(
                          icon: Icon(Icons.looks_two_rounded, color: Colors.orange),
                          onPressed: () => _addToTeam(user, 2),
                          tooltip: 'Dodaj do drużyny 2',
                        ),
                      ],
                    ),
                  );
                },
              ),

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
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: _getPaginatedPlayers().length,
                      itemBuilder: (context, index) {
                        var userDoc = _getPaginatedPlayers()[index];
                        var user = userDoc.data() as Map<String, dynamic>; // Konwersja do Map<String, dynamic>

                        return ListTile(
                          title: Text('${user['firstName']} ${user['lastName']}'),
                          subtitle: Text('Email: ${user['email']}'),
                          leading: Icon(Icons.person, color: Colors.blue),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.looks_one_rounded, color: Colors.green),
                                onPressed: () => _addToTeam(user, 1),
                                tooltip: 'Dodaj do drużyny 1',
                              ),
                              IconButton(
                                icon: Icon(Icons.looks_two_rounded, color: Colors.orange),
                                onPressed: () => _addToTeam(user, 2),
                                tooltip: 'Dodaj do drużyny 2',
                              ),
                            ],
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


              SizedBox(height: 20),

// Wyświetlanie drużyny 1 wraz z logo i nazwą
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Zaokrąglone logo drużyny 1
                      ClipOval(
                        child: Image.network(
                          _team1LogoUrl ?? 'https://example.com/default_team1_logo.png', // Domyślny URL
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.image_not_supported, size: 50);
                          },
                        ),
                      ),
                      SizedBox(width: 25,),
                      ElevatedButton(
                        onPressed: () => _pickImage(1),
                        child: Text('Dodaj logo drużyny 1'),
                      ),
                    ],
                  ),
                  SizedBox(height: 16), // Odstęp między wierszem a polem tekstowym
                  TextField(

                    controller: _team1NameController,
                    decoration: InputDecoration(labelText: 'Nazwa drużyny 1'),
                  ),
                ],
              ),
              SizedBox(height: 16),

// Lista zawodników w drużynie 1
              Text("Zawodnicy drużyny 1:", style: TextStyle(fontWeight: FontWeight.bold)),
              _team1.isNotEmpty
                  ? ListView.builder(
                shrinkWrap: true,
                itemCount: _team1.length,
                itemBuilder: (context, index) {
                  var player = _team1[index];
                  return ListTile(
                    title: Text('${player['firstName']} ${player['lastName']}'),
                    trailing: IconButton(
                      icon: Icon(Icons.remove_circle),
                      onPressed: () => _removeFromTeam(player, 1),
                    ),
                  );
                },
              )
                  : Text("Brak zawodników w drużynie 1."),
              SizedBox(height: 50),

// Drużyna 2 - logo, nazwa drużyny, przycisk dodawania logo
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Zaokrąglone logo drużyny 2
                      ClipOval(
                        child: Image.network(
                          _team2LogoUrl ?? 'https://example.com/default_team2_logo.png', // Domyślny URL
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.image_not_supported, size: 50);
                          },
                        ),
                      ),
                      SizedBox(width: 25,),
                      ElevatedButton(
                        onPressed: () => _pickImage(2),
                        child: Text('Dodaj logo drużyny 2'),
                      ),
                    ],
                  ),
                  SizedBox(height: 16), // Odstęp między wierszem a polem tekstowym
                  TextField(
                    controller: _team2NameController,
                    decoration: InputDecoration(labelText: 'Nazwa drużyny 2'),
                  ),
                ],
              ),
              SizedBox(height: 16),

// Lista zawodników w drużynie 2
              Text("Zawodnicy drużyny 2:", style: TextStyle(fontWeight: FontWeight.bold)),
              _team2.isNotEmpty
                  ? ListView.builder(
                shrinkWrap: true,
                itemCount: _team2.length,
                itemBuilder: (context, index) {
                  var player = _team2[index];
                  return ListTile(
                    title: Text('${player['firstName']} ${player['lastName']}'),
                    trailing: IconButton(
                      icon: Icon(Icons.remove_circle),
                      onPressed: () => _removeFromTeam(player, 2),
                    ),
                  );
                },
              )
                  : Text("Brak zawodników w drużynie 2."),




              SizedBox(height: 50),
              Text('Wybierz kapitanów obu druzyn:'),
              SizedBox(height: 20),
              // Wybór kapitanów
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text('Kapitan drużyny 1:'),
                      DropdownButton<String>(
                        value: team1Captain,
                        items: _team1
                            .map((player) => DropdownMenuItem<String>(
                          child: Text('${player['firstName']} ${player['lastName']}'),
                          value: player['email'],
                        ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            team1Captain = value;
                          });
                        },
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text('Kapitan drużyny 2:'),
                      DropdownButton<String>(
                        value: team2Captain,
                        items: _team2
                            .map((player) => DropdownMenuItem<String>(
                          child: Text('${player['firstName']} ${player['lastName']}'),
                          value: player['email'],
                        ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            team2Captain = value;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),

              SizedBox(height: 20),

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

              SizedBox(height: 20),

              // Pole tekstowe na miejsce spotkania
              TextField(
                controller: _locationController,
                decoration: InputDecoration(labelText: 'Miejsce spotkania'),
              ),
              SizedBox(height: 20),

              // Wybór daty meczu
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Napis nad przyciskiem
                  Text(
                    'Wybierz datę i godzinę meczu:',
                    style: TextStyle(fontSize: 16),
                  ),

                  SizedBox(height: 10), // Odstęp między tekstem a przyciskiem

                  // Przycisk do wyboru daty i godziny
                  ElevatedButton(
                    onPressed: () => _selectDate(context),
                    // Zmiana tekstu na przycisku w zależności od wybranej daty i godziny
                    child: Text(
                      matchDate == null || matchTime == null
                          ? 'Wybierz datę i godzinę'
                          : 'Wybrano: ${DateFormat('dd.MM.yyyy').format(matchDate!)} o ${matchTime!.format(context)}',
                    ),
                  ),
                ],
              ),

              SizedBox(height: 10),



              //Dodawanie widza
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pole do wyszukiwania widza
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
                  SizedBox(height: 10),

                  // Loader w trakcie wyszukiwania
                  if (_isLoadingForViewer) Center(child: CircularProgressIndicator()),

                  // Komunikat o braku wyników
                  if (_noResultsFoundForViewer)
                    Center(
                      child: Text(
                        'Brak wyników wyszukiwania',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),

                  // Lista wyników wyszukiwania
                  if (!_isLoadingForViewer && _viewerSearchResults.isNotEmpty)
                    ListView.builder(
                      shrinkWrap: true,
                      itemCount: _viewerSearchResults.length,
                      itemBuilder: (context, index) {
                        var user = _viewerSearchResults[index];
                        String userName = '${user['firstName']} ${user['lastName']}';
                        String userEmail = user['email'];
                        return ListTile(
                          title: Text(userName),
                          subtitle: Text(userEmail),
                          leading: Icon(Icons.person, color: Colors.green),
                          onTap: () => _addViewerToMatch(userEmail),
                        );
                      },
                    ),
                ],
              ),


              SizedBox(height: 20),

            // Lista dodanych widzów
              Center(
                child: Text(
                  'Dodani widzowie',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 10),
              _spectators.isEmpty
                  ? Center(
                child: Text(
                  'Brak widzów w meczu',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              )
                  : ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _spectators.length,
                itemBuilder: (context, index) {
                  var spectator = _spectators[index];
                  return ListTile(
                    title: Text('${spectator['firstName']} ${spectator['lastName']}'),
                    trailing: IconButton(
                      icon: Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () => _removeSpectator(spectator),
                      tooltip: 'Usuń widza',
                    ),
                  );
                },
              ),

              SizedBox(height: 20),


              //Dodawanie statystyków
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pole do wyszukiwania statystyka
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
                  SizedBox(height: 10),

// Loader w trakcie wyszukiwania
                  if (_isLoadingForStatistician) Center(child: CircularProgressIndicator()),

// Komunikat o braku wyników
                  if (_noResultsFoundForStatistician)
                    Center(
                      child: Text(
                        'Brak wyników wyszukiwania',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),

// Lista wyników wyszukiwania
                  if (!_isLoadingForStatistician && _statisticianSearchResults.isNotEmpty)
                    ListView.builder(
                      shrinkWrap: true,
                      itemCount: _statisticianSearchResults.length,
                      itemBuilder: (context, index) {
                        var user = _statisticianSearchResults[index];
                        String userName = '${user['firstName']} ${user['lastName']}';
                        String userEmail = user['email'];
                        return ListTile(
                          title: Text(userName),
                          subtitle: Text(userEmail),
                          leading: Icon(Icons.bar_chart, color: Colors.blue),
                          onTap: () => _addStatisticianToMatch(userEmail),
                        );
                      },
                    ),



                  // Lista dodanych statystyków
                  SizedBox(height: 20),
                  Center(
                    child: Text(
                      'Dodani statystycy',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 10),
                  _statisticians.isEmpty
                      ? Center(
                    child: Text(
                      'Brak dodanych statystyków',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  )
                      : ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: _statisticians.length,
                    itemBuilder: (context, index) {
                      var statistician = _statisticians[index];
                      return ListTile(
                        title: Text('${statistician['firstName']} ${statistician['lastName']}'),
                        trailing: IconButton(
                          icon: Icon(Icons.remove_circle, color: Colors.red),
                          onPressed: () => _removeStatistician(statistician),
                          tooltip: 'Usuń statystyka',
                        ),
                      );
                    },
                  ),
                ],
              ),

              SizedBox(height: 20),

              // Przycisk do tworzenia meczu
              ElevatedButton(
                onPressed: _createMatch,
                child: Text('Stwórz mecz'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

