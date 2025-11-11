import 'dart:async';

import 'package:app_firebase/user_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'capitan_edit_stats.dart';

class CaptainScreen extends StatefulWidget {
  final Map<String, dynamic> match;
  final String team;
  final String teamCaptainEmail;

  CaptainScreen({
    required this.match,
    required this.team,
    required this.teamCaptainEmail,
  });

  @override
  _CaptainScreenState createState() => _CaptainScreenState();
}

class _CaptainScreenState extends State<CaptainScreen> with SingleTickerProviderStateMixin {
  List<String> fullTeam = [];
  List<String> startingPlayers = [];
  List<String> benchPlayers = [];
  int maxStartingPlayers = 5; // Początkowa liczba graczy w pierwszym składzie
  int proposedStartingPlayers = 5; // Przechowuje proponowaną liczbę graczy
  String? opposingTeamCaptainEmail; // Email kapitana drugiej drużyny
  String? matchStatus;
  late TabController _tabController;
  List<Map<String, dynamic>> availability = [];
  List<String> participants = [];
  List<String> spectators = []; // Lista widzów
  List<String> statisticians = [];
  final TextEditingController newPlayerController = TextEditingController();
  final TextEditingController newViewerController = TextEditingController();
  final TextEditingController newStatisticianController = TextEditingController();

  List<QueryDocumentSnapshot> _users = [];
  List<QueryDocumentSnapshot> _viewers = [];
  List<QueryDocumentSnapshot> _statisticians = [];
  bool _isLoading = false;
  bool _noResultsFound = false; // Flaga informująca, że nie znaleziono wyników
  bool _isLoadingForViewer = false;
  bool _noResultsFoundForViewer = false;
  bool _isLoadingForStatistician = false;
  bool _noResultsFoundForStatistician = false;
  Timer? _debounce;
  Timer? _debounceViewer;
  Timer? _debounceStatistician;
  DateTime? matchDate;
  String newCaptain = "";

  @override
  void initState() {
    super.initState();

    // Wczytaj pełny skład drużyny z bazy danych
    fullTeam = List<String>.from(widget.match[widget.team] ?? []);
    // Wczytaj graczy ustawionych w pierwszym składzie i na ławce (jeśli już istnieją)
    startingPlayers = List<String>.from(widget.match['${widget.team}StartingPlayers'] ?? []);
    benchPlayers = List<String>.from(widget.match['${widget.team}BenchPlayers'] ?? []);
    maxStartingPlayers = widget.match['maxStartingPlayers'] ?? 5;
    proposedStartingPlayers = widget.match['proposedMaxStartingPlayers'] ?? maxStartingPlayers;
    opposingTeamCaptainEmail = widget.match['opposingTeamCaptainEmail'];
    matchStatus = widget.match['status'] ?? 'Nierozpoczęty';
    _tabController = TabController(length: 2, vsync: this);
    // Załaduj dostępność graczy z bazy danych
    availability = List<Map<String, dynamic>>.from(widget.match['availability'] ?? []);
    participants = List<String>.from(widget.match['participants'] ?? []);
    spectators = List<String>.from(widget.match['spectators'] ?? []);
    statisticians =List<String>.from(widget.match['statisticians'] ?? []);


    // Listener dla kontrolera zawodników, dzieki temu po wyszukaniu i skasowaniu nie ma zadnych wyników i przez to że pole jest final!
    newPlayerController.addListener(() {
      String query = newPlayerController.text;

      // Jeśli pole jest puste, wyczyść wyniki i zakończ funkcję
      if (query.isEmpty) {
        setState(() {
          _users = [];  // Resetuj listę użytkowników
          _noResultsFound = false;
          _isLoading = false;
        });
      }

    });

    // Listener dla kontrolera widzów
    newViewerController.addListener(() {
      if (newViewerController.text.isEmpty) {
        setState(() {
          _viewers = [];
        });
      }
    });

    // Listener dla kontrolera statystyków
    newStatisticianController.addListener(() {
      String query = newStatisticianController.text;

      // Resetowanie wyników wyszukiwania, jeśli pole jest puste
      if (query.isEmpty) {
        setState(() {
          _statisticians = [];
          _noResultsFoundForStatistician = false;
          _isLoadingForStatistician = false;
        });
      } else {
        _fetchUsersForStatistician(query);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    newPlayerController.dispose();
    newViewerController.dispose();
    newStatisticianController.dispose();
    _debounce?.cancel();
    _debounceViewer?.cancel();
    _debounceStatistician?.cancel();
    super.dispose();
  }

  // Sprawdzanie propozycji po wczytaniu
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    checkForProposedChange();
    checkForProposedLocation(); // Sprawdza propozycję zmiany lokalizacji
    checkForProposedDateChange(); // Sprawdza propozycję zmiany daty meczu
    checkForProposedCancellation();
  }

  // Funkcja sprawdzająca propozycję zmiany
  void checkForProposedChange() {
    if (widget.match['proposedMaxStartingPlayers'] != null &&
        widget.match['proposedMaxStartingPlayers'] != maxStartingPlayers &&
        widget.teamCaptainEmail != opposingTeamCaptainEmail) {
      // Opóźnienie wywołania showDialog za pomocą Future.microtask
      Future.microtask(() =>
          showProposalDialog(widget.match['proposedMaxStartingPlayers']));
    }
  }

  void checkForProposedLocation() {
    if (widget.match['proposedLocation'] != null &&
        widget.teamCaptainEmail != opposingTeamCaptainEmail) {
      // Wyświetla dialog z propozycją zmiany lokalizacji
      Future.microtask(() =>
          showLocationProposalDialog(widget.match['proposedLocation']));
    }
  }

  void checkForProposedDateChange() {
    final proposedDate = widget.match['proposedMatchDate'];

    if (proposedDate != null && widget.teamCaptainEmail != opposingTeamCaptainEmail) {
      // Konwersja z Timestamp na DateTime, jeśli potrzebne
      DateTime proposedDateTime = (proposedDate is Timestamp) ? proposedDate.toDate() : proposedDate;

      // Wyświetlenie dialogu propozycji zmiany daty meczu
      Future.microtask(() => showDateProposalDialog(proposedDateTime));
    }
  }

  // Wyświetlanie dialogu z propozycją zmiany
  void showProposalDialog(int proposedNumber) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: Text("Propozycja zmiany liczby graczy"),
            content: Text(
                "Kapitan drużyny przeciwnej proponuje zmianę na: $proposedNumber"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(), // Zamknij dialog
                child: Text("Anuluj"),
              ),
              TextButton(
                onPressed: () {
                  acceptProposedChange(proposedNumber);
                  Navigator.of(context).pop();
                },
                child: Text("Akceptuj"),
              ),
              TextButton(
                onPressed: () {
                  rejectProposedChange();
                  Navigator.of(context).pop();
                },
                child: Text("Odrzuć"),
              ),
            ],
          ),
    );
  }

  // Funkcja akceptacji zmiany liczby graczy
  void acceptProposedChange(int newMax) async {
    await FirebaseFirestore.instance.collection('matches').doc(
        widget.match['matchId']).update({
      'maxStartingPlayers': newMax,
      'proposedMaxStartingPlayers': null,
    });
    setState(() {
      maxStartingPlayers = newMax;
      proposedStartingPlayers = newMax;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Propozycja zaakceptowana')),
    );
  }

  // Funkcja odrzucenia zmiany liczby graczy
  void rejectProposedChange() async {
    await FirebaseFirestore.instance.collection('matches').doc(
        widget.match['matchId']).update({
      'proposedMaxStartingPlayers': null,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Propozycja odrzucona')),
    );
  }

// Funkcja do zapisania propozycji zmiany liczby graczy
  void proposeChangeMaxStartingPlayers(int newMax) async {
    // Sprawdzenie, czy proponowana liczba graczy jest taka sama jak obecna
    if (newMax == maxStartingPlayers) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
            'Propozycja nie może być taka sama jak aktualna liczba graczy')),
      );
      return; // Przerwanie funkcji, jeśli liczba graczy jest taka sama
    }

    // Jeśli liczba graczy jest inna, wysyłamy propozycję
    await FirebaseFirestore.instance.collection('matches').doc(
        widget.match['matchId']).update({
      'proposedMaxStartingPlayers': newMax,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Propozycja zmiany liczby graczy wysłana')),
    );
  }

  // Funkcja do pokazania dialogu wyboru liczby graczy
  void showPlayerCountDialog() {
    if (matchStatus != 'Nierozpoczęty') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Liczbę graczy można zmienić tylko przed meczem')),
      );
      return; // Zatrzymanie dalszego wykonania funkcji
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Text("Zaproponuj liczbę graczy w pierwszym składzie"),
            content: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.remove),
                  onPressed: proposedStartingPlayers > 2
                      ? () => setState(() => proposedStartingPlayers--)
                      : null,
                ),
                Text(
                  proposedStartingPlayers.toString(),
                  style: TextStyle(fontSize: 24),
                ),
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: proposedStartingPlayers < 11
                      ? () => setState(() => proposedStartingPlayers++)
                      : null,
                ),
              ],
            ),
            actions: [
              TextButton(
                child: Text("Anuluj"),
                onPressed: () => Navigator.of(context).pop(),
              ),
              ElevatedButton(
                child: Text("Wyślij propozycję"),
                onPressed: () {
                  proposeChangeMaxStartingPlayers(proposedStartingPlayers);
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        });
      },
    );
  }


// Przypisanie gracza do pierwszego składu
  void toggleStartingPlayer(String player) {
    if (matchStatus != 'Nierozpoczęty') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
            'Zmiana składu jest możliwa tylko przed rozpoczęciem meczu')),
      );
      return;
    }

    setState(() {
      if (startingPlayers.contains(player)) {
        // Usuwanie gracza z pierwszego składu
        startingPlayers.remove(player);
      } else {
        // Dodanie gracza do pierwszego składu
        if (startingPlayers.length < maxStartingPlayers) {
          startingPlayers.add(player);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(
                'Maksymalna liczba graczy w pierwszym składzie to $maxStartingPlayers')),
          );
        }
      }

      // Upewnij się, że gracz nie istnieje jednocześnie w obu listach
      benchPlayers.remove(player);
    });
  }

// Przypisanie gracza do ławki rezerwowych
  void toggleBenchPlayer(String player) {
    if (matchStatus != 'Nierozpoczęty') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
            'Zmiana składu jest możliwa tylko przed rozpoczęciem meczu')),
      );
      return;
    }

    setState(() {
      if (benchPlayers.contains(player)) {
        // Usuwanie gracza z ławki rezerwowych
        benchPlayers.remove(player);
      } else {
        // Dodanie gracza do ławki rezerwowych
        benchPlayers.add(player);
      }

      // Upewnij się, że gracz nie istnieje jednocześnie w obu listach
      startingPlayers.remove(player);
    });
  }

  // Zapisanie ustawionego składu i ławki rezerwowych do Firestore
  void saveTeamChanges() async {
    if (matchStatus != 'Nierozpoczęty') {
      // Jeśli mecz nie ma statusu "Nierozpoczęty", powiadom użytkownika
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie można zapisać zmian, mecz już się rozpoczął lub zakończył')),
      );
      return; // Zatrzymanie dalszego działania funkcji
    }

    // Jeśli mecz ma status "Nierozpoczęty", zapisujemy zmiany
    await FirebaseFirestore.instance.collection('matches').doc(
        widget.match['matchId']).update({
      '${widget.team}StartingPlayers': startingPlayers,
      '${widget.team}BenchPlayers': benchPlayers,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Skład i ławka rezerwowych zapisane pomyślnie')),
    );
  }

  void proposeNewLocation(String newLocation) {
    // Sprawdzenie, czy nowa lokalizacja różni się od obecnej
    if (newLocation == widget.match['location']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nowa lokalizacja jest taka sama jak obecna')),
      );
      return; // Wyjdź z funkcji, jeśli lokalizacja jest taka sama
    }

    // Dodaj propozycję do Firebase, jeśli lokalizacja jest inna
    FirebaseFirestore.instance.collection('matches').doc(
        widget.match['matchId']).update({
      'proposedLocation': newLocation,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Propozycja nowego miejsca została wysłana')),
    );
  }

// Funkcja wyświetlająca dialog z propozycją nowej lokalizacji
  void showLocationProposalDialog(String proposedLocation) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: Text("Propozycja zmiany miejsca"),
            content: Text(
                "Kapitan drużyny przeciwnej proponuje nowe miejsce: $proposedLocation"),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(), // Zamknij dialog
                child: Text("Anuluj"),
              ),
              TextButton(
                onPressed: () {
                  acceptProposedLocation(proposedLocation);
                  Navigator.of(context).pop();
                },
                child: Text("Akceptuj"),
              ),
              TextButton(
                onPressed: () {
                  declineProposedLocation();
                  Navigator.of(context).pop();
                },
                child: Text("Odrzuć"),
              ),
            ],
          ),
    );
  }

  void acceptProposedLocation(String newLocation) async {
    // Zaktualizuj lokalizację w Firebase
    await FirebaseFirestore.instance.collection('matches').doc(
        widget.match['matchId']).update({
      'location': newLocation,
      'proposedLocation': FieldValue.delete(),
    });

    // Zaktualizuj stan lokalizacji lokalnie, aby odświeżenie było natychmiastowe
    setState(() {
      widget.match['location'] = newLocation;
      widget.match['proposedLocation'] = null;
    });

    // Wyświetl komunikat o sukcesie
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Nowe miejsce meczu zostało zaakceptowane')),
    );
  }

  void declineProposedLocation() async {
    await FirebaseFirestore.instance.collection('matches').doc(
        widget.match['matchId']).update({
      'proposedLocation': FieldValue.delete(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Propozycja zmiany miejsca meczu została odrzucona')),
    );
    setState(() {}); // odświeżenie ekranu
  }

  void showLocationChangeDialog() {
    if (matchStatus != 'Nierozpoczęty') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Miejsce spotkania można zmienić tylko przed meczem')),
      );
      return; // Zatrzymanie dalszego wykonania funkcji
    }

    String proposedLocation = '';
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Text("Zaproponuj nowe miejsce spotkania"),
            content: TextField(
              onChanged: (value) {
                setState(() {
                  proposedLocation = value;
                });
              },
              decoration: InputDecoration(hintText: 'Wprowadź nowe miejsce'),
            ),
            actions: [
              TextButton(
                child: Text("Anuluj"),
                onPressed: () => Navigator.of(context).pop(),
              ),
              ElevatedButton(
                child: Text("Wyślij propozycję"),
                onPressed: () {
                  if (proposedLocation.isNotEmpty) {
                    proposeNewLocation(proposedLocation);
                    Navigator.of(context).pop();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Proszę wprowadzić nowe miejsce')),
                    );
                  }
                },
              ),
            ],
          );
        });
      },
    );
  }


  void showDateProposalDialog(DateTime proposedDate) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Propozycja zmiany daty meczu"),
        content: Text("Kapitan drużyny przeciwnej proponuje zmianę na: ${proposedDate.toLocal()}"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(), // Zamknij dialog
            child: Text("Anuluj"),
          ),
          TextButton(
            onPressed: () {
              acceptProposedDateChange(proposedDate);
              Navigator.of(context).pop();
            },
            child: Text("Akceptuj"),
          ),
          TextButton(
            onPressed: () {
              rejectProposedDateChange();
              Navigator.of(context).pop();
            },
            child: Text("Odrzuć"),
          ),
        ],
      ),
    );
  }


// Funkcja akceptacji zmiany daty
  void acceptProposedDateChange(DateTime newDate) async {
    // Zaktualizowanie daty meczu w Firestore
    await FirebaseFirestore.instance.collection('matches').doc(widget.match['matchId']).update({
      'matchDate': Timestamp.fromDate(newDate),  // Konwersja DateTime na Timestamp
      'proposedMatchDate': null,  // Usuwamy propozycję zmiany daty
    });

    // Aktualizacja stanu lokalnego aplikacji, aby UI pokazało natychmiastową zmianę
    setState(() {
      widget.match['matchDate'] = newDate;  // Zaktualizowanie lokalnej daty meczu
    });

    // Wyświetlenie komunikatu o sukcesie
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Propozycja zmiany daty została zaakceptowana')),
    );
  }

// Funkcja odrzucenia zmiany daty
  void rejectProposedDateChange() async {
    await FirebaseFirestore.instance.collection('matches').doc(widget.match['matchId']).update({
      'proposedMatchDate': null,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Propozycja zmiany daty odrzucona')),
    );
  }

  void proposeNewMatchDate(DateTime newDate) async {
    if (newDate == widget.match['matchDate']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Propozycja nie może być taka sama jak aktualna data meczu')),
      );
      return; // Przerwanie funkcji, jeśli data jest taka sama
    }

    await FirebaseFirestore.instance.collection('matches').doc(widget.match['matchId']).update({
      'proposedMatchDate': newDate,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Propozycja zmiany daty meczu wysłana')),
    );
  }

  void showDateChangeDialog() {
    if (matchStatus != 'Nierozpoczęty') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Datę spotkania można zmienić tylko przed meczem')),
      );
      return; // Zatrzymanie dalszego wykonania funkcji
    }

    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text("Zaproponuj nową datę meczu"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Wyświetlenie aktualnie wybranej daty i godziny
                  Text(
                    "Wybrana data: ${selectedDate.toLocal().toIso8601String().split('T').first}",
                    style: TextStyle(fontSize: 16),
                  ),
                  Text(
                    "Wybrana godzina: ${selectedDate.hour}:${selectedDate.minute.toString().padLeft(2, '0')}",
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 20),

                  // Przycisk wyboru daty
                  ElevatedButton(
                    child: Text("Wybierz datę"),
                    onPressed: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(Duration(days: 365)),
                      );
                      if (pickedDate != null) {
                        setState(() {
                          selectedDate = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            selectedDate.hour,
                            selectedDate.minute,
                          );
                        });
                      }
                    },
                  ),
                  SizedBox(height: 20),

                  // Przycisk wyboru godziny
                  ElevatedButton(
                    child: Text("Wybierz godzinę"),
                    onPressed: () async {
                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(selectedDate),
                      );
                      if (pickedTime != null) {
                        setState(() {
                          selectedDate = DateTime(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: Text("Anuluj"),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  child: Text("Wyślij propozycję"),
                  onPressed: () {
                    proposeNewMatchDate(selectedDate);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }


// Funkcja do wyszukiwania zawodników
  void _fetchUsers(String query) async {
    if (query.isEmpty) {
      // Jeśli pole jest puste, wyczyść wyniki i zakończ funkcję
      setState(() {
        _users = [];
        _noResultsFound = false;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _noResultsFound = false;
    });

    try {
      // Zapytanie do Firestore w celu pobrania użytkowników na podstawie imienia
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('firstName', isGreaterThanOrEqualTo: query)
          .where('firstName', isLessThanOrEqualTo: query + '\uf8ff')
          .get();

      // Jeśli brak wyników, szukaj po nazwisku
      if (snapshot.docs.isEmpty) {
        snapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('lastName', isGreaterThanOrEqualTo: query)
            .where('lastName', isLessThanOrEqualTo: query + '\uf8ff')
            .get();
      }

      setState(() {
        _users = snapshot.docs;
        _noResultsFound = snapshot.docs.isEmpty;  // Jeśli brak wyników, ustaw flagę
        _isLoading = false;
      });
    } catch (e) {
      print("Błąd pobierania użytkowników: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

// Funkcja do dodawania zawodnika do składu
  void _addPlayerToTeam(String playerEmail) {
    // Sprawdzenie, czy zawodnik jest już na liście dostępności
    bool isInAvailability = availability.any((player) => player['email'] == playerEmail);
    if (isInAvailability) {
      // Wyświetl komunikat, że zawodnik jest już przypisany do meczu
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Zawodnik jest już przypisany do meczu!'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Sprawdzenie, czy zawodnik jest już na liście uczestników
    bool isInParticipants = participants.contains(playerEmail);
    if (!isInParticipants) {
      setState(() {
        // Dodanie zawodnika do listy uczestników
        participants.add(playerEmail);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dodano zawodnika do listy uczestników.'),
            duration: Duration(seconds: 2),
          ),
        );
      });
    }

    // Dodanie zawodnika do odpowiedniej drużyny
    setState(() {
      if (widget.team == 'team1') {
        fullTeam.add(playerEmail);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dodano zawodnika do drużyny 1!'),
            duration: Duration(seconds: 2),
          ),
        );
      } else if (widget.team == 'team2') {
        fullTeam.add(playerEmail);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dodano zawodnika do drużyny 2!'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Dodanie zawodnika do listy dostępności z domyślnym statusem
      availability.add({
        'email': playerEmail,
        'status': 'brak decyzji',
      });

      _users = [];
      newPlayerController.clear();
    });

    // Aktualizacja danych w Firestore
    FirebaseFirestore.instance.collection('matches').doc(widget.match['matchId']).update({
      'availability': availability,
      'participants': participants,
      widget.team: fullTeam,
    });

    print('Zawodnik $playerEmail został dodany do meczu.');
  }

  // Funkcja do wyświetlania dialogu potwierdzenia przed dodaniem zawodnika
  void _showAddPlayerDialog(String playerName, String playerEmail) {
    if (matchStatus != 'Nierozpoczęty') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie można dodać zawodnika, mecz już się rozpoczął')),
      );
      return; // Zatrzymanie dalszego wykonania funkcji
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Czy na pewno chcesz dodać $playerName?'),
          content: Text('Po dodaniu, zawodnik zostanie dodany do składu drużyny.'),
          actions: <Widget>[
            TextButton(
              child: Text('Nie'),
              onPressed: () {
                Navigator.of(context).pop(); // Zamknięcie dialogu
              },
            ),
            TextButton(
              child: Text('Tak'),
              onPressed: () {
                _addPlayerToTeam(playerEmail); // Dodanie zawodnika do składu
                Navigator.of(context).pop(); // Zamknięcie dialogu
                _showConfirmationMessage(playerName); // Wyświetlenie komunikatu
              },
            ),
          ],
        );
      },
    );
  }


  // Funkcja do wyświetlania komunikatu po dodaniu zawodnika
  void _showConfirmationMessage(String playerName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$playerName został dodany do składu!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

// Funkcja do wyszukiwania widzów
  void _fetchUsersForViewer(String query) async {
    if (query.isEmpty) {
      // Jeśli pole jest puste, wyczyść wyniki i zakończ funkcję
      setState(() {
        _viewers = [];
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
        _viewers = snapshot.docs;
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

// Funkcja do dodawania widza do meczu
  void _addViewerToMatch(String viewerEmail) {
    // Sprawdzenie, czy widz jest już na liście widzów
    bool isInSpectators = spectators.contains(viewerEmail);
    if (isInSpectators) {
      // Wyświetl komunikat, że widz jest już na liście widzów
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Widz jest już na liście widzów!'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Dodanie widza do listy widzów
    setState(() {
      spectators.add(viewerEmail);
      _showConfirmationMessage("$viewerEmail został dodany jako widz!");

      // Wyczyść wyniki i pole wyszukiwania
      _viewers = [];
      newViewerController.clear();
    });

    // Sprawdzenie, czy widz jest już na liście uczestników
    bool isInParticipants = participants.contains(viewerEmail);
    if (!isInParticipants) {
      setState(() {
        // Dodanie widza do listy uczestników
        participants.add(viewerEmail);
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('$viewerEmail został dodany do listy uczestników.'),
        //     duration: Duration(seconds: 2),
        //   ),
        // );
      });
    }

    // Zaktualizowanie danych w Firestore
    FirebaseFirestore.instance.collection('matches').doc(widget.match['matchId']).update({
      'spectators': spectators,
      'participants': participants,
    });

    print('$viewerEmail został dodany jako widz i, jeśli to konieczne, dodany do listy uczestników.');
  }

  // Dialog potwierdzający dodanie widza
  void _showAddViewerDialog(String userName, String userEmail) {
    if (matchStatus != 'Nierozpoczęty') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie można dodać widza, mecz już się rozpoczął')),
      );
      return; // Zatrzymanie dalszego wykonania funkcji
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Czy na pewno chcesz dodać $userName jako widza?'),
          content: Text(
            'Po dodaniu, użytkownik zostanie dodany jako widz do meczu.',
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Nie'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Tak'),
              onPressed: () {
                Navigator.of(context).pop();
                _addViewerToMatch(userEmail);
              },
            ),
          ],
        );
      },
    );
  }


  // Funkcja do wyszukiwania statystyków
  void _fetchUsersForStatistician(String query) async {
    if(query.isEmpty){
      setState(() {
        _statisticians = [];
        _isLoadingForStatistician = false;
        _noResultsFoundForStatistician = false;
      });
    }


    setState(() {
      _isLoadingForStatistician = true;
      _noResultsFoundForStatistician = false;
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
        setState(() {
          _noResultsFoundForStatistician = true;
          _isLoadingForStatistician = false;
        });
        return;
      }

      setState(() {
        _statisticians = snapshot.docs;
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

// Funkcja do dodawania statystyka do meczu
  void _addStatisticianToMatch(String statisticianEmail) {
    // Sprawdzenie, czy statystyk jest już na liście statystyków
    bool isInStatisticians = statisticians.contains(statisticianEmail);
    if (isInStatisticians) {
      // Wyświetl komunikat, że statystyk jest już na liście
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Statystyk jest już na liście statystyków!'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Dodanie statystyka do listy statystyków
    setState(() {
      statisticians.add(statisticianEmail);
      _showConfirmationMessage("$statisticianEmail został dodany jako statystyk!");

      // Wyczyść wyniki i pole wyszukiwania
      _viewers = [];
      newViewerController.clear();
    });

    // Sprawdzenie, czy statystyk jest już na liście uczestników
    bool isInParticipants = participants.contains(statisticianEmail);
    if (!isInParticipants) {
      setState(() {
        // Dodanie statystyka do listy uczestników
        participants.add(statisticianEmail);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$statisticianEmail został dodany do listy uczestników.'),
            duration: Duration(seconds: 2),
          ),
        );
      });
    }

    // Zaktualizowanie danych w Firestore
    FirebaseFirestore.instance.collection('matches').doc(widget.match['matchId']).update({
      'statisticians': statisticians,
      'participants': participants,
    });

    print('$statisticianEmail został dodany jako statystyk i, jeśli to konieczne, dodany do listy uczestników.');
  }

// Okno dialogowe potwierdzające dodanie statystyka
  void _showAddStatisticianDialog(String userName, String userEmail) {
    if (matchStatus != 'Nierozpoczęty') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie można dodać statystyka, mecz już się rozpoczął')),
      );
      return; // Zatrzymanie dalszego wykonania funkcji
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Czy na pewno chcesz dodać $userName jako statystyka?'),
          content: Text(
              'Po dodaniu, użytkownik zostanie dodany jako statystyk do meczu.'),
          actions: <Widget>[
            TextButton(
              child: Text('Nie'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Tak'),
              onPressed: () {
                Navigator.of(context).pop();
                _addStatisticianToMatch(userEmail);
              },
            ),
          ],
        );
      },
    );
  }

  // Funkcja do opuścięcia meczu i przekazania opaski
  void leaveMatchAndPassArmband() {
    // Implementacja logiki opuścienia meczu i przekazania opaski kapitana
    print("Opuściłeś mecz i przekazałeś opaskę kapitana.");
    Navigator.pop(context);
  }

  // Funkcja z debounce do przetwarzania wyszukiwania zawodników, by nie pokazywać listy
  void _onPlayerSearchChanged(String query) {
    // Anulowanie poprzedniego timeru, jeśli jest aktywny
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // Ustawienie nowego timeru
    _debounce = Timer(const Duration(milliseconds: 550), () {
      if (query.isEmpty) {
        // Jeśli query jest puste, resetuj wyniki
        setState(() {
          _users = [];
          _noResultsFound = false;
          _isLoading = false;
        });
      } else {
        // Wywołanie funkcji wyszukiwania
        _fetchUsers(query);
      }
    });
  }

  // Opóźniona funkcja do wyszukiwania widzów
  void _onViewerSearchChanged(String query) {
    if (_debounceViewer?.isActive ?? false) _debounceViewer!.cancel();
    _debounceViewer = Timer(const Duration(milliseconds: 550), () {
      if (query.isEmpty) {
        setState(() {
          _viewers = [];
          _noResultsFoundForViewer = false;
          _isLoadingForViewer = false;
        });
      } else {
        _fetchUsersForViewer(query);
      }
    });
  }

  // Opóźniona funkcja do wyszukiwania statystyków
  void _onStatisticianSearchChanged(String query) {
    if (_debounceStatistician?.isActive ?? false) _debounceStatistician!.cancel();
    _debounceStatistician = Timer(const Duration(milliseconds: 550), () {
      if (query.isEmpty) {
        setState(() {
          _statisticians = [];
          _noResultsFoundForStatistician = false;
          _isLoadingForStatistician = false;
        });
      } else {
        _fetchUsersForStatistician(query);
      }
    });
  }

  void showPlayersDialog() async {
    if (matchStatus != 'Nierozpoczęty') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Zawodników można usuwać tylko przed rozpoczęciem meczu.')),
      );
      return; // Zatrzymanie dalszego wykonania funkcji
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Zawodnicy drużyny"),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: fullTeam.length,
              itemBuilder: (context, index) {
                String playerEmail = fullTeam[index];

                // Sprawdzamy, czy dany zawodnik to kapitan, jeśli tak, to pomijamy
                if (playerEmail == widget.teamCaptainEmail) {
                  return Container(); // Pomijamy wyświetlanie kapitana
                }

                return FutureBuilder<String>(
                  future: fetchUserName(playerEmail), // Pobieranie imienia i nazwiska
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return ListTile(
                        title: Text('Ładowanie...'),
                      );
                    }

                    if (snapshot.hasError) {
                      return ListTile(
                        title: Text('Błąd ładowania nazwy'),
                      );
                    }

                    String playerName = snapshot.data ?? playerEmail; // Jeśli nie uda się pobrać nazwy, użyj emaila

                    return ListTile(
                      title: Text(playerName),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removePlayer(playerEmail),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Zamknij"),
            ),
          ],
        );
      },
    );
  }

  void _removePlayer(String playerEmail) async {
    // Pobranie aktualnych danych meczu
    DocumentSnapshot matchSnapshot = await FirebaseFirestore.instance.collection('matches').doc(widget.match['matchId']).get();
    Map<String, dynamic> matchData = matchSnapshot.data() as Map<String, dynamic>;

    List<String> team = List<String>.from(matchData[widget.team] ?? []);
    List<Map<String, dynamic>> availability = List<Map<String, dynamic>>.from(matchData['availability'] ?? []);
    List<String> participants = List<String>.from(matchData['participants'] ?? []);
    List<String> spectators = List<String>.from(matchData['spectators'] ?? []);
    List<String> statisticians = List<String>.from(matchData['statisticians'] ?? []);
    List<String> teamBenchPlayers = List<String>.from(matchData['${widget.team}BenchPlayers'] ?? []);
    List<String> teamStartingPlayers = List<String>.from(matchData['${widget.team}StartingPlayers'] ?? []);

    // Usunięcie zawodnika z drużyny głównej
    if (team.contains(playerEmail)) {
      await FirebaseFirestore.instance.collection('matches').doc(widget.match['matchId']).update({
        widget.team: FieldValue.arrayRemove([playerEmail]),
      });
    }

    // Usunięcie zawodnika z listy dostępności
    availability.removeWhere((entry) => entry['email'] == playerEmail);
    await FirebaseFirestore.instance.collection('matches').doc(widget.match['matchId']).update({
      'availability': availability,
    });

    // Usunięcie zawodnika z ławki rezerwowych i pierwszego składu, jeśli istnieje
    if (teamBenchPlayers.contains(playerEmail)) {
      await FirebaseFirestore.instance.collection('matches').doc(widget.match['matchId']).update({
        '${widget.team}BenchPlayers': FieldValue.arrayRemove([playerEmail]),
      });
    }

    if (teamStartingPlayers.contains(playerEmail)) {
      await FirebaseFirestore.instance.collection('matches').doc(widget.match['matchId']).update({
        '${widget.team}StartingPlayers': FieldValue.arrayRemove([playerEmail]),
      });
    }

    // Usunięcie zawodnika z listy 'participants' tylko, jeśli nie jest widzem ani statystykiem
    if (!spectators.contains(playerEmail) && !statisticians.contains(playerEmail)) {
      await FirebaseFirestore.instance.collection('matches').doc(widget.match['matchId']).update({
        'participants': FieldValue.arrayRemove([playerEmail]),
      });
    }

    // Aktualizacja stanu lokalnego
    setState(() {
      fullTeam.remove(playerEmail);
      availability.removeWhere((entry) => entry['email'] == playerEmail);
      startingPlayers.remove(playerEmail);
      benchPlayers.remove(playerEmail);
      participants.remove(playerEmail);
    });

    // Wyświetlenie komunikatu o sukcesie
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Zawodnik $playerEmail został usunięty z drużyny')),
    );
  }


// Funkcja wyświetlająca okno potwierdzenia
  void _showLeaveConfirmationDialog() {
    if (matchStatus != 'Nierozpoczęty') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mecz można opuścić tylko przed jego rozpoczęciem.')),
      );
      return; // Zatrzymanie dalszego wykonania funkcji
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Opuść mecz'),
        content: Text(
          'Opuszczając mecz musisz przekazać opaskę kapitana innemu zawodnikowi. Czy chcesz kontynuować?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(), // Zamknięcie dialogu
            child: Text('Nie'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showSelectNewCaptainDialog(); // Przejście do wyboru nowego kapitana
            },
            child: Text('Tak'),
          ),
        ],
      ),
    );
  }

// Funkcja do wyboru nowego kapitana
  void _showSelectNewCaptainDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Wybierz nowego kapitana'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: fullTeam.length,
              itemBuilder: (context, index) {
                final playerEmail = fullTeam[index];

                // Pomijamy aktualnego kapitana na liście wyboru
                if (playerEmail == widget.teamCaptainEmail) {
                  return Container();
                }

                return FutureBuilder<String>(
                  future: fetchUserName(playerEmail), // Pobieramy imię i nazwisko użytkownika
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return ListTile(
                        title: Text('Ładowanie...'),
                      );
                    }

                    if (snapshot.hasError) {
                      return ListTile(
                        title: Text('Błąd ładowania'),
                      );
                    }

                    final playerName = snapshot.data ?? playerEmail; // Jeśli błąd, użyjemy emaila

                    return ListTile(
                      title: Text(playerName),
                      onTap: () {
                        _assignNewCaptain(playerEmail);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

// Przypisanie nowego kapitana i usunięcie obecnego z list w bazie
  void _assignNewCaptain(String newCaptainEmail) async {
    final matchRef = FirebaseFirestore.instance.collection('matches').doc(widget.match['matchId']);

    // Wybór właściwego pola kapitana
    final captainField = widget.team == 'team1' ? 'team1Captain' : 'team2Captain';

    // Przypisanie nowego kapitana do właściwego pola
    await matchRef.update({
      captainField: newCaptainEmail,
    });

    // Pobierz zaktualizowane dane meczu
    final matchSnapshot = await matchRef.get();
    final matchData = matchSnapshot.data() as Map<String, dynamic>;

    // Pobranie list, z których trzeba usunąć obecnego kapitana
    List availability = List.from(matchData['availability'] ?? []);
    List team = List.from(matchData[widget.team] ?? []);
    List spectators = List.from(matchData['spectators'] ?? []);
    List statisticians = List.from(matchData['statisticians'] ?? []);
    List participants = List.from(matchData['participants'] ?? []);
    List teamBenchPlayers = List.from(matchData['${widget.team}BenchPlayers'] ?? []);
    List teamStartingPlayers = List.from(matchData['${widget.team}StartingPlayers'] ?? []);

    // Usunięcie obecnego kapitana z poszczególnych list
    availability.removeWhere((player) => player['email'] == widget.teamCaptainEmail);
    team.remove(widget.teamCaptainEmail);
    spectators.remove(widget.teamCaptainEmail);
    statisticians.remove(widget.teamCaptainEmail);

    // Usunięcie obecnego kapitana z `participants` jeśli nie ma go na liście `spectators` i `statisticians`
    if (!spectators.contains(widget.teamCaptainEmail) && !statisticians.contains(widget.teamCaptainEmail)) {
      participants.remove(widget.teamCaptainEmail);
    }

    // Usunięcie obecnego kapitana z list `teamBenchPlayers` i `teamStartingPlayers`
    teamBenchPlayers.remove(widget.teamCaptainEmail);
    teamStartingPlayers.remove(widget.teamCaptainEmail);

    // Zaktualizowanie danych w Firebase
    await matchRef.update({
      'availability': availability,
      widget.team: team,
      'spectators': spectators,
      'statisticians': statisticians,
      'participants': participants,
      '${widget.team}BenchPlayers': teamBenchPlayers,
      '${widget.team}StartingPlayers': teamStartingPlayers,
    });

    // Powiadomienie o sukcesie
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Kapitan został zmieniony na $newCaptainEmail, a Ty opuściłeś mecz.')),
    );

    // Wróć do poprzedniego ekranu
    Navigator.of(context).pop();
  }


  void _showCancelMatchConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Potwierdzenie anulowania"),
          content: Text("Czy na pewno chcesz anulować mecz?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Nie"),
            ),
            ElevatedButton(
              onPressed: () {
                _proposeCancelMatch();
                Navigator.of(context).pop();
              },
              child: Text("Tak"),
            ),
          ],
        );
      },
    );
  }

  void _proposeCancelMatch() async {
    await FirebaseFirestore.instance.collection('matches').doc(widget.match['matchId']).update({
      'proposedCancellation': true,
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Propozycja anulowania meczu wysłana')),
    );
  }

  void checkForProposedCancellation() {
    if (widget.match['proposedCancellation'] == true &&
        widget.teamCaptainEmail != opposingTeamCaptainEmail) {
      Future.microtask(() => showCancellationProposalDialog());
    }
  }

  void showCancellationProposalDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Propozycja anulowania meczu"),
        content: Text("Kapitan drużyny przeciwnej zaproponował anulowanie meczu. Czy akceptujesz?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("Anuluj"),
          ),
          TextButton(
            onPressed: () {
              acceptProposedCancellation();
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Cofnięcie do poprzedniego ekranu
            },
            child: Text("Akceptuj"),
          ),
          TextButton(
            onPressed: () {
              rejectProposedCancellation();
              Navigator.of(context).pop();
            },
            child: Text("Odrzuć"),
          ),
        ],
      ),
    );
  }


  void acceptProposedCancellation() async {
    await FirebaseFirestore.instance.collection('matches').doc(widget.match['matchId']).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Mecz został anulowany')),
    );
  }

  void rejectProposedCancellation() async {
    await FirebaseFirestore.instance.collection('matches').doc(widget.match['matchId']).update({
      'proposedCancellation': null,
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Propozycja anulowania meczu odrzucona')),
    );
  }








  void _showConfirmMatchResultDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Potwierdź wynik spotkania'),
        content: Text(
          'Czy chcesz potwierdzić wynik spotkania? Jeśli wszystko się zgadza, naciśnij "Tak". '
              'Jeśli coś jest nie tak, naciśnij "Nie", aby przejść do edycji statystyk.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToEditStatistics(); // Przejście do ekranu edycji statystyk
            },
            child: Text('Nie'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _confirmMatchResult(); // Potwierdzenie wyniku
            },
            child: Text('Tak'),
          ),
        ],
      ),
    );
  }

// Potwierdzenie wyniku
  void _confirmMatchResult() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Wynik spotkania został potwierdzony.')),
    );
  }

// Nawigacja do ekranu edycji statystyk
  void _navigateToEditStatistics() {
    final match = widget.match;

    // Walidacja danych
    final String matchId = match['matchId']?.toString() ?? '';
    final String team1Name = match['team1Name'] ?? 'Nieznana drużyna 1';
    final String team2Name = match['team2Name'] ?? 'Nieznana drużyna 2';
    final String team1Logo = match['team1Logo'] ??
        'https://via.placeholder.com/150?text=Brak+logo'; // Domyślne logo
    final String team2Logo = match['team2Logo'] ??
        'https://via.placeholder.com/150?text=Brak+logo'; // Domyślne logo

    if (matchId.isEmpty) {
      print('Błąd: matchId jest pusty');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditStatisticsScreen(
          matchId: matchId,
          team1Name: team1Name,
          team2Name: team2Name,
          team1LogoUrl: team1Logo,
          team2LogoUrl: team2Logo,
        ),
      ),
    );
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
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  // Metoda do budowy sekcji dostępności drużyny
  Widget _buildTeamAvailability(
      List<String> teamMembers,
      List<Map<String, dynamic>> availabilityList,
      String teamName,
      String captainEmail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tytuł sekcji z nazwą drużyny
        _buildSectionTitle('Dostępność: '),

        SizedBox(height: 12),

        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: teamMembers.length,
          itemBuilder: (context, index) {
            String playerEmail = teamMembers[index];
            String status = 'brak decyzji';

            // Znajdowanie statusu dostępności dla zawodnika
            for (var item in availabilityList) {
              if (item['email'] == playerEmail) {
                status = item['status'] ?? 'brak decyzji';
                break;
              }
            }

            return FutureBuilder<String>(
              future: fetchUserName(playerEmail), // Pobieranie imienia i nazwiska
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ListTile(
                      leading: CircularProgressIndicator(),
                      title: Text('Ładowanie...'),
                      subtitle: Text('Status: $status'),
                    ),
                  );
                }

                String playerName = snapshot.data ?? playerEmail;

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserDetailsScreen(userEmail: playerEmail),
                      ),
                    );
                  },
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ListTile(
                      leading: _getAvailabilityIcon(status),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              playerName, // Wyświetlanie imienia i nazwiska
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.blueGrey.shade800,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (playerEmail == captainEmail) ...[
                            SizedBox(width: 8),
                            Icon(Icons.star, color: Colors.orange, size: 18),
                            // Ikona kapitana
                          ],
                        ],
                      ),
                      subtitle: Text(
                        'Status: $status',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }


  // Metoda do pobierania odpowiedniej ikony dla dostępności
  Widget _getAvailabilityIcon(String status) {
    IconData icon;
    Color color;

    switch (status) {
      case 'dostępny':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'niedostępny':
        icon = Icons.cancel;
        color = Colors.red;
        break;
      default:
        icon = Icons.access_time;
        color = Colors.orange;
        break;
    }

    return Icon(icon, color: color);
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
    );
  }


// Uzywane przy samych adresach email teraz useless
//   Widget _buildPlayerTile(String playerName, IconData icon, Color iconColor, Function onPressed) {
//     return ListTile(
//       title: Text(
//         playerName,
//         style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
//       ),
//       trailing: IconButton(
//         icon: Icon(icon, color: iconColor),
//         onPressed: () => onPressed(playerName),
//       ),
//     );
//   }

  // Funkcja do pobierania imienia i nazwiska użytkownika na podstawie adresu e-mail

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
    // Pobranie danych meczu
    String team1Name = widget.match['team1Name'] ?? 'Drużyna 1';
    String team2Name = widget.match['team2Name'] ?? 'Drużyna 2';
    final DateTime matchDate = (widget.match['matchDate'] is Timestamp)
        ? (widget.match['matchDate'] as Timestamp).toDate()
        : widget.match['matchDate'] as DateTime;
    String matchLocation = widget.match['location'] ?? 'Nieznane miejsce';
    String team1Logo = widget.match['team1Logo'] ?? '';
    String team2Logo = widget.match['team2Logo'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('Zarządzanie składem'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: "Skład"),
            Tab(text: "Ustawienia"),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: saveTeamChanges, // Zapisz zmiany
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Zakładka Skład
          SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Wiersz z logo i nazwami drużyn
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildTeamColumn(team1Logo, team1Name),
                    Text(
                      'vs',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
                    ),
                    _buildTeamColumn(team2Logo, team2Name),
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
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Godzina meczu: ${matchDate.hour}:${matchDate.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Miejsce: $matchLocation',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Format: $maxStartingPlayers na $maxStartingPlayers',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 25),

                // Zarządzanie składem na mecz
                  _buildSectionTitle('Zarządzanie składem na mecz:'),

                SizedBox(height: 15),

// Wyświetlenie pierwszego składu
                _buildSectionTitle('Pierwszy skład:'),
                startingPlayers.isEmpty
                    ? Text('Nie wybrano jeszcze pierwszego składu', style: TextStyle(color: Colors.grey.shade700))
                    : Column(
                  children: startingPlayers.map((playerEmail) {
                    return FutureBuilder<String>(
                      future: fetchUserName(playerEmail), // Pobieranie imienia i nazwiska na podstawie emaila
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return ListTile(
                            title: Text('Ładowanie...'),
                            leading: CircularProgressIndicator(),
                          );
                        }

                        String playerName = snapshot.data ?? playerEmail;
                        return ListTile(
                          title: Text(playerName),
                          trailing: IconButton(
                            icon: Icon(Icons.remove_circle, color: Colors.red),
                            onPressed: () => toggleStartingPlayer(playerEmail), // Używaj emaila
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
                SizedBox(height: 20),

// Wyświetlenie ławki rezerwowych
                _buildSectionTitle('Ławka rezerwowych:'),
                benchPlayers.isEmpty
                    ? Text('Ławka rezerwowych jest pusta', style: TextStyle(color: Colors.grey.shade700))
                    : Column(
                  children: benchPlayers.map((playerEmail) {
                    return FutureBuilder<String>(
                      future: fetchUserName(playerEmail), // Pobieranie imienia i nazwiska na podstawie emaila
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return ListTile(
                            title: Text('Ładowanie...'),
                            leading: CircularProgressIndicator(),
                          );
                        }

                        String playerName = snapshot.data ?? playerEmail;
                        return ListTile(
                          title: Text(playerName),
                          trailing: IconButton(
                            icon: Icon(Icons.remove_circle, color: Colors.red),
                            onPressed: () => toggleBenchPlayer(playerEmail), // Używaj emaila
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),

                SizedBox(height: 20),

// Pełny skład drużyny
                _buildSectionTitle('Pełny skład drużyny:'),
                Column(
                  children: fullTeam.map((player) {
                    bool isInStarting = startingPlayers.contains(player);
                    bool isInBench = benchPlayers.contains(player);

                    return FutureBuilder<String>(
                      future: fetchUserName(player),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return ListTile(
                            title: Text('Ładowanie...'),
                            leading: CircularProgressIndicator(),
                          );
                        }

                        String playerName = snapshot.data ?? player;
                        return ListTile(
                          title: Text(playerName),
                          subtitle: Text(
                            isInStarting ? 'Pierwszy skład' : isInBench ? 'Ławka rezerwowych' : 'Brak przypisania',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(isInStarting ? Icons.remove_circle : Icons.add_circle,
                                    color: isInStarting ? Colors.red : Colors.green),
                                onPressed: () => toggleStartingPlayer(player),
                              ),
                              IconButton(
                                icon: Icon(isInBench ? Icons.remove_circle : Icons.add_circle,
                                    color: isInBench ? Colors.red : Colors.green),
                                onPressed: () => toggleBenchPlayer(player),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
                SizedBox(height: 20),

                // Przyciski dodatkowe
                _buildTeamAvailability(fullTeam, availability, widget.team, widget.teamCaptainEmail),
              ],
            ),
          ),


          // Zakładka Ustawienia
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ustawienia meczu',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Maksymalna liczba graczy w pierwszym składzie: $maxStartingPlayers',
                          style: TextStyle(fontSize: 16),
                        ),
                        SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: showPlayerCountDialog,
                          icon: Icon(Icons.edit, color: Colors.white),
                          label: Text('Zaproponuj zmianę liczby graczy'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                            backgroundColor: Colors.blueAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            foregroundColor: Colors.white

                          ),
                        ),
                        Divider(height: 30),
                        Text(
                          'Miejsce meczu: $matchLocation',
                          style: TextStyle(fontSize: 16),
                        ),
                        SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: showLocationChangeDialog,
                          icon: Icon(Icons.place, color: Colors.white),
                          label: Text('Zaproponuj zmianę miejsca'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                            backgroundColor: Colors.blueAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              foregroundColor: Colors.white
                          ),
                        ),
                        Divider(height: 30),
                        Text(
                          'Data meczu: ${matchDate.toLocal().toIso8601String().split('T').first}, ${matchDate.hour}:${matchDate.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(fontSize: 16),
                        ),
                        SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: showDateChangeDialog,
                          icon: Icon(Icons.calendar_today, color: Colors.white),
                          label: Text('Zaproponuj zmianę daty'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                            backgroundColor: Colors.blueAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              foregroundColor: Colors.white
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),

                // Lista zawodników do usuwania
                Center(
                  child: ElevatedButton.icon(
                    onPressed: showPlayersDialog,
                    icon: Icon(Icons.group_remove, color: Colors.white),
                    label: Text("Usuń zawodnika z drużyny"),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        foregroundColor: Colors.white
                    ),
                  ),
                ),
                SizedBox(height: 20),

                // Dodawanie zawodnika
                TextField(
                  controller: newPlayerController,
                  decoration: InputDecoration(
                    labelText: 'Dodaj zawodnika',
                    hintText: 'Wyszukaj zawodnika po imieniu lub nazwisku',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: _onPlayerSearchChanged,
                ),
                if (_isLoading)
                  Center(child: CircularProgressIndicator()),
                if (_noResultsFound)
                  Center(child: Text("Brak wyników wyszukiwania.", style: TextStyle(color: Colors.red))),
                if (!_isLoading && _users.isNotEmpty)
                  ListView.builder(
                    shrinkWrap: true,
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      String playerEmail = _users[index]['email'] ?? '';
                      String playerName = (_users[index]['firstName'] ?? '') + ' ' + (_users[index]['lastName'] ?? '');
                      return ListTile(
                        title: Text(playerName),
                        subtitle: Text(playerEmail),
                        leading: Icon(Icons.person, color: Colors.blueAccent),
                        onTap: () => _showAddPlayerDialog(playerName, playerEmail),
                      );
                    },
                  ),
                SizedBox(height: 20),

                // Dodawanie widza
                TextField(
                  controller: newViewerController,
                  decoration: InputDecoration(
                    labelText: 'Dodaj widza',
                    hintText: 'Wyszukaj widza po imieniu lub nazwisku',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: _onViewerSearchChanged,
                ),
                if (_isLoadingForViewer) Center(child: CircularProgressIndicator()),
                if (_noResultsFoundForViewer) Center(child: Text('Brak wyników wyszukiwania', style: TextStyle(color: Colors.red))),
                if (!_isLoadingForViewer && _viewers.isNotEmpty)
                  ListView.builder(
                    shrinkWrap: true,
                    itemCount: _viewers.length,
                    itemBuilder: (context, index) {
                      var user = _viewers[index];
                      String userName = '${user['firstName']} ${user['lastName']}';
                      String userEmail = user['email'];
                      return ListTile(
                        title: Text(userName),
                        subtitle: Text(userEmail),
                        leading: Icon(Icons.person, color: Colors.green),
                        onTap: () => _showAddViewerDialog(userName, userEmail),
                      );
                    },
                  ),
                SizedBox(height: 20),

                // Dodawanie statystyka
                TextField(
                  controller: newStatisticianController,
                  decoration: InputDecoration(
                    labelText: 'Dodaj statystyka',
                    hintText: 'Wyszukaj statystyka po imieniu lub nazwisku',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: _onStatisticianSearchChanged,
                ),
                if (_isLoadingForStatistician) Center(child: CircularProgressIndicator()),
                if (_noResultsFoundForStatistician)
                  Center(child: Text('Brak wyników wyszukiwania', style: TextStyle(color: Colors.red))),
                if (!_isLoadingForStatistician && _statisticians.isNotEmpty)
                  ListView.builder(
                    shrinkWrap: true,
                    itemCount: _statisticians.length,
                    itemBuilder: (context, index) {
                      var user = _statisticians[index];
                      String userName = '${user['firstName']} ${user['lastName']}';
                      String userEmail = user['email'];
                      return ListTile(
                        title: Text(userName),
                        subtitle: Text(userEmail),
                        leading: Icon(Icons.person, color: Colors.purple),
                        onTap: () => _showAddStatisticianDialog(userName, userEmail),
                      );
                    },
                  ),
                SizedBox(height: 30),
                // Sprawdzenie statusu meczu przed umożliwieniem przejścia

                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center, // Wyśrodkowanie w pionie
                    crossAxisAlignment: CrossAxisAlignment.center, // Wyśrodkowanie w poziomie
                    children: [
                      // Sprawdzenie statusu meczu przed umożliwieniem przejścia
                      ElevatedButton.icon(
                        onPressed: matchStatus == "Zakończony, niepotwierdzony"
                            ? _navigateToEditStatistics // Od razu przejście do edycji statystyk
                            : null, // W przypadku innego statusu, przycisk jest nieaktywny
                        icon: Icon(Icons.check_circle, color: Colors.white),
                        label: Text('Potwierdź wynik spotkania'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                          backgroundColor: matchStatus == "Zakończony, niepotwierdzony"
                              ? Colors.green // Kolor aktywnego przycisku
                              : Colors.grey, // Kolor przycisku, gdy nieaktywny
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.black), // Obramowanie przycisku
                        ),
                      ),
                      SizedBox(height: 20), // Dodatkowa przestrzeń przed komunikatem

                      // Komunikat w przypadku nieaktywnego przycisku
                      if (matchStatus != "Zakończony, niepotwierdzony")
                        Text(
                          'Mecz nie jest jeszcze zakończony.',
                          style: TextStyle(fontSize: 16, color: Colors.red),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 10), // Dodatkowa przestrzeń przed innymi przyciskami

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Przycisk opuszczenia meczu
                    ElevatedButton.icon(
                      onPressed: _showLeaveConfirmationDialog,
                      icon: Icon(Icons.exit_to_app, color: Colors.white),
                      label: Text('Opuść mecz'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        foregroundColor: Colors.white,
                      ),
                    ),
                    SizedBox(width: 10), // Odstęp między przyciskami
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('matches').doc(widget.match['matchId']).snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return SizedBox();
                        var matchData = snapshot.data!.data() as Map<String, dynamic>;
                        bool canCancel = matchData['status'] == 'Nierozpoczęty';

                        return ElevatedButton.icon(
                          onPressed: canCancel ? _showCancelMatchConfirmationDialog : null,
                          icon: Icon(Icons.cancel, color: Colors.white),
                          label: Text('Anuluj mecz'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            foregroundColor: Colors.white,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}