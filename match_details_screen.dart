import 'package:app_firebase/user_details_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MatchDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> match;
  final String loggedUser; // Zmienna na zalogowanego użytkownika

  MatchDetailsScreen({
    required this.match,
    required this.loggedUser,
  });

  @override
  _MatchDetailsScreenState createState() => _MatchDetailsScreenState();
}

class _MatchDetailsScreenState extends State<MatchDetailsScreen> {
  // Zmienna do przechowywania danych użytkowników
  List<Map<String, dynamic>> _userDetails = [];

  @override
  void initState() {
    super.initState();
    // Pobranie danych użytkowników po załadowaniu widoku
    _fetchUserDetails();
  }

  // Funkcja pobierająca dane użytkowników z Firebase
  Future<void> _fetchUserDetails() async {
    final snapshot = await FirebaseFirestore.instance.collection('users').get();
    setState(() {
      _userDetails = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    });
  }

  // Funkcja, która zwraca imię i nazwisko na podstawie adresu e-mail
  String getFullName(String email) {
    if (_userDetails.isEmpty) {
      return 'Ładowanie...'; // Placeholder podczas ładowania
    }

    for (var user in _userDetails) {
      if (user['email'] == email) {
        return '${user['firstName']} ${user['lastName']}';
      }
    }
    return email; // Jeśli użytkownik nie jest w bazie, zwracamy email
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Szczegóły meczu'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTeamColumn(widget.match['team1Logo'], widget.match['team1Name']),
                  Text(
                    'vs',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  _buildTeamColumn(widget.match['team2Logo'], widget.match['team2Name']),
                ],
              ),
              SizedBox(height: 30),
              Center(
                child: Column(
                  children: [
                    Text(
                      'Data: ${widget.match['matchDate']?.toDate().toLocal().toString().split(' ')[0]}',
                      style: TextStyle(fontSize: 18),
                    ),
                    Text(
                      'Godzina: ${widget.match['matchDate']?.toDate().toLocal().toString().split(' ')[1].split('.')[0]}',
                      style: TextStyle(fontSize: 18),
                    ),
                    Text(
                      'Miejsce: ${widget.match['location'] ?? 'Nieznana'}',
                      style: TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10),
              // Zakładki
              DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    TabBar(
                      tabs: [
                        Tab(text: 'Team 1'),
                        Tab(text: 'Team 2'),
                      ],
                    ),
                    SizedBox(
                      height: 400, // Stała wysokość zakładek
                      child: TabBarView(
                        physics: NeverScrollableScrollPhysics(),
                        children: [
                          // Widok dla "Team 1"
                          SingleChildScrollView(
                            child: _buildTeamDetails(
                              widget.match['team1Name'],
                              widget.match['team1Logo'],
                              widget.match['team1'],
                              widget.match['team1Captain'],
                              widget.match['team1StartingPlayers'],
                              widget.match['team1BenchPlayers'],
                            ),
                          ),
                          // Widok dla "Team 2"
                          SingleChildScrollView(
                            child: _buildTeamDetails(
                              widget.match['team2Name'],
                              widget.match['team2Logo'],
                              widget.match['team2'],
                              widget.match['team2Captain'],
                              widget.match['team2StartingPlayers'],
                              widget.match['team2BenchPlayers'],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(thickness: 2),
              SizedBox(height: 30),
              Text(
                'Widzowie:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ..._buildSpectatorList(widget.match['spectators']),
              SizedBox(height: 20),
              Text(
                'Statystycy:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ..._buildStatisticiansList(widget.match['statisticians']),
              SizedBox(height: 30),
              Center(
                child: Text(
                  'ID meczu: ${widget.match['matchId']}',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Budowa szczegółów drużyny
  Widget _buildTeamDetails(String title, String logoUrl, List<dynamic> team, String captain, List<dynamic>? startingPlayers, List<dynamic>? benchPlayers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 10),
        // Nagłówek z logo i tytułem drużyny
        Row(
          children: [
            ClipOval(
              child: Image.network(
                logoUrl,
                width: 30,
                height: 30,
                fit: BoxFit.cover,
              ),
            ),
            SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        SizedBox(height: 20),
        // Pierwszy skład
        Text(
          'Pierwszy skład:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        if (startingPlayers == null || startingPlayers.isEmpty)
          Text(
            'Brak informacji o pierwszym składzie.',
            style: TextStyle(color: Colors.red),
          )
        else
          ..._buildTeamList(startingPlayers, captain),
        SizedBox(height: 10),
        // Ławka rezerwowych
        Text(
          'Ławka rezerwowych:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        if (benchPlayers == null || benchPlayers.isEmpty)
          Text(
            'Brak informacji o ławce rezerwowych.',
            style: TextStyle(color: Colors.red),
          )
        else
          ..._buildTeamList(benchPlayers, captain),
        SizedBox(height: 20),
        // Wszyscy zawodnicy
        Text(
          'Wszyscy zawodnicy w drużynie:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        ..._buildTeamList(team, captain),
      ],
    );
  }



  Widget _buildTeamColumn(String logoUrl, String teamName) {
    return Column(
      children: [
        ClipOval(
          child: Image.network(
            logoUrl,
            width: 50,
            height: 50,
            fit: BoxFit.cover,
          ),
        ),
        SizedBox(height: 4),
        Text(
          teamName,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  List<Widget> _buildTeamList(List<dynamic> team, String captain) {
    List<Widget> widgets = [];
    for (var player in team) {
      bool isLoggedUser = player == widget.loggedUser; // Czy to zalogowany użytkownik
      String fullName = _userDetails.isNotEmpty ? getFullName(player) : 'Ładowanie...';
      String email = player; // Adres email jako identyfikator użytkownika

      // Dodanie ikony dla zalogowanego użytkownika oraz dla kapitana
      widgets.add(
        GestureDetector(
          onTap: _userDetails.isNotEmpty
              ? () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserDetailsScreen(userEmail: email),
              ),
            );
          }
              : null, // Uniemożliwiamy przejście dopóki dane nie zostaną załadowane
          child: Container(
            color: isLoggedUser ? Colors.grey.withOpacity(0.1) : null,
            child: ListTile(
              leading: Icon(
                isLoggedUser
                    ? Icons.account_circle // Ikona dla zalogowanego użytkownika
                    : Icons.person,         // Ikona dla pozostałych
                color: isLoggedUser ? Colors.deepPurple : Colors.black,
              ),
              title: Text(
                fullName,
                style: isLoggedUser
                    ? TextStyle(fontWeight: FontWeight.bold, color: Colors.black)
                    : null,
              ),
              trailing: player == captain
                  ? Icon(Icons.copyright, color: Colors.black, size: 20) // Ikona kapitana
                  : null,
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  List<Widget> _buildSpectatorList(List<dynamic> spectators) {
    if (spectators == null || spectators.isEmpty) {
      return [Text('Brak widzów')];
    }

    return spectators.map<Widget>((spectator) {
      String fullName = _userDetails.isNotEmpty ? getFullName(spectator) : 'Ładowanie...';
      return ListTile(
        leading: Icon(Icons.visibility), // Ikona widza
        title: Text(fullName),
      );
    }).toList();
  }


  List<Widget> _buildStatisticiansList(List<dynamic> statisticians) {
    if (statisticians == null || statisticians.isEmpty) {
      return [Text('Brak statystyków')];
    }

    return statisticians.map<Widget>((statistician) {
      String fullName = _userDetails.isNotEmpty ? getFullName(statistician) : 'Ładowanie...';
      return ListTile(
        leading: Icon(Icons.bar_chart), // Ikona widza
        title: Text(fullName),
      );
    }).toList();
  }



}
