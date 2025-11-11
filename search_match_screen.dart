import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'spectator_screen.dart';

class SearchMatchScreen extends StatefulWidget {
  @override
  _SearchMatchScreenState createState() => _SearchMatchScreenState();
}

class _SearchMatchScreenState extends State<SearchMatchScreen> {
  final TextEditingController _matchIdController = TextEditingController();
  final TextEditingController _teamNameController = TextEditingController();
  Map<String, dynamic>? _matchData;
  bool _isLoading = false;
  bool _matchNotFound = false;

  Future<void> _fetchMatch() async {
    setState(() {
      _isLoading = true;
      _matchNotFound = false;
      _matchData = null;
    });

    try {
      QuerySnapshot? snapshot;
      String matchId = _matchIdController.text.trim();
      String teamName = _teamNameController.text.trim();

      if (matchId.isNotEmpty) {
        snapshot = await FirebaseFirestore.instance
            .collection('matches')
            .where('matchId', isEqualTo: matchId)
            .get();
      } else if (teamName.isNotEmpty) {
        snapshot = await FirebaseFirestore.instance
            .collection('matches')
            .where('team1Name', isEqualTo: teamName)
            .get();

        if (snapshot.docs.isEmpty) {
          snapshot = await FirebaseFirestore.instance
              .collection('matches')
              .where('team2Name', isEqualTo: teamName)
              .get();
        }
      }

      if (snapshot != null && snapshot.docs.isNotEmpty) {
        setState(() {
          _matchData = snapshot?.docs.first.data() as Map<String, dynamic>;
        });
      } else {
        setState(() {
          _matchNotFound = true;
        });
      }
    } catch (e) {
      print("Błąd pobierania meczu: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatDate(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    return '${date.day}-${date.month}-${date.year}';
  }

  String _formatTime(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Wyszukaj Mecz'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _matchIdController,
              decoration: InputDecoration(
                labelText: 'Wpisz ID meczu',
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: _fetchMatch,
                ),
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _teamNameController,
              decoration: InputDecoration(
                labelText: 'Wpisz nazwę drużyny',
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: _fetchMatch,
                ),
              ),
            ),
            SizedBox(height: 20),
            _isLoading
                ? CircularProgressIndicator()
                : _matchData != null
                ? Expanded(
              child: ListView(
                children: [
                  ListTile(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SpectatorScreen(
                            matchId: _matchData!['matchId'],
                          ),
                        ),
                      );
                    },
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildTeamColumn(_matchData!['team1Logo'], _matchData!['team1Name']),
                            SizedBox(width: 40),
                            Text(
                              _matchData!.containsKey('team1Score') && _matchData!.containsKey('team2Score')
                                  ? '${_matchData!['team1Score']} - ${_matchData!['team2Score']}'
                                  : 'vs',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 40),
                            _buildTeamColumn(_matchData!['team2Logo'], _matchData!['team2Name']),
                          ],
                        ),
                        SizedBox(height: 10),
                        Text('Data: ${_formatDate(_matchData!['matchDate'])}', style: TextStyle(fontSize: 16)),
                        Text('Godzina: ${_formatTime(_matchData!['matchDate'])}', style: TextStyle(fontSize: 16)),
                        Text('Miejsce: ${_matchData!['location']}', style: TextStyle(fontSize: 16)),
                        Text('Status: ${_matchData!['status']}', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
                ],
              ),
            )
                : _matchNotFound
                ? Text('Mecz o podanym ID lub nazwie drużyny nie został znaleziony.')
                : SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamColumn(String logoUrl, String teamName) {
    return Column(
      children: [
        ClipOval(
          child: Image.network(
            logoUrl,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
          ),
        ),
        SizedBox(height: 4),
        Tooltip(
          message: teamName,
          child: Container(
            width: 85,
            child: Text(
              teamName,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}
