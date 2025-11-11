import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_details_screen.dart'; // Upewnij się, że masz odpowiedni import

class UserSearchScreen extends StatefulWidget {
  @override
  _UserSearchScreenState createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<DocumentSnapshot> _users = [];
  bool _isLoading = false;

  void _searchUsers() async {
    String query = _searchController.text.trim();
    if (query.isEmpty) return; // Jeśli pole jest puste, nie wyszukuj

    setState(() {
      _isLoading = true;
    });

    try {
      List<String> nameParts = query.split(' ');
      QuerySnapshot snapshot;

      if (nameParts.length == 2) {
        snapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('firstName', isEqualTo: nameParts[0])
            .where('lastName', isEqualTo: nameParts[1])
            .get();
      } else {
        snapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('firstName', isEqualTo: query)
            .get();

        if (snapshot.docs.isEmpty) {
          snapshot = await FirebaseFirestore.instance
              .collection('users')
              .where('lastName', isEqualTo: query)
              .get();
        }
      }

      setState(() {
        _users = snapshot.docs;
      });
    } catch (e) {
      print("Błąd wyszukiwania: $e");
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Wyszukaj użytkowników'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Wpisz imię, nazwisko lub oba',
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: _searchUsers,
                ),
              ),
            ),
            SizedBox(height: 20),
            _isLoading
                ? CircularProgressIndicator()
                : Expanded(
              child: ListView.builder(
                itemCount: _users.length,
                itemBuilder: (context, index) {
                  var user = _users[index].data() as Map<String, dynamic>;

                  return ListTile(
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.account_circle_outlined, size: 24),
                            SizedBox(width: 8),
                            Text(
                              '${user['firstName']} ${user['lastName']}',
                              style: TextStyle(
                                fontSize: 20, // większa czcionka
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.mail, size: 20),
                            SizedBox(width: 8),
                            Text(
                              user['email'],
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: user['isAvailable'] ? Colors.green : Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              '  Dostępność: ${user['isAvailable'] ? "Tak" : "Nie"}',
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.sports_soccer,
                              size: 20,
                              color: user['isWillingToPlay'] ? Colors.green : Colors.grey,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Chętny do gry: ${user['isWillingToPlay'] ? "Tak" : "Nie"}',
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                        SizedBox(height: 5),
                        Divider(height: 10, color: Colors.grey, thickness: 2, indent: 50, endIndent: 50)
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UserDetailsScreen(
                            userEmail: user['email'],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
