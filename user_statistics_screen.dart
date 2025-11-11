import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserStatisticsScreen extends StatelessWidget {
  final User user;

  UserStatisticsScreen({required this.user});

  double calculateAverage(double totalRating, int totalReviews) {
    return totalReviews > 0 ? totalRating / totalReviews : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Statystyki użytkownika'),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('Nie znaleziono statystyk użytkownika.'));
          }

          var userData = snapshot.data!.data() as Map<String, dynamic>;
          String displayName = user.displayName ?? 'Nieznane Imię';
          String email = user.email ?? 'Nieznany email';
          String avatarUrl = userData['avatarUrl'] ?? 'https://via.placeholder.com/150';

          // Statystyki gry
          int matches = userData['matches'] ?? 0;
          int goals = userData['goals'] ?? 0;
          int assists = userData['assists'] ?? 0;
          int dribbles = userData['dribbles'] ?? 0;
          int fouls = userData['fouls'] ?? 0;
          int redCards = userData['redCards'] ?? 0;
          int yellowCards = userData['yellowCards'] ?? 0;
          int shotsOnTarget = userData['shotsOnTarget'] ?? 0;
          int shotsOffTarget = userData['shotsOffTarget'] ?? 0;

          double goalsAssistsPerMatch = matches > 0 ? (goals + assists) / matches : 0.0;
          double shotAccuracy = (shotsOnTarget + shotsOffTarget) > 0
              ? (shotsOnTarget / (shotsOnTarget + shotsOffTarget)) * 100
              : 0.0;

          // Statystyki ocen
          double totalRatingSkills = userData['totalRating_skills'] ?? 0;
          double totalRatingFairPlay = userData['totalRating_fairPlay'] ?? 0;
          double totalRatingConflict = userData['totalRating_conflict'] ?? 0;
          int totalReviewsPlayer = userData['totalReviews_player'] ?? 0;

          double averageSkillsRating = calculateAverage(totalRatingSkills, totalReviewsPlayer);
          double averageFairPlayRating = calculateAverage(totalRatingFairPlay, totalReviewsPlayer);
          double averageConflictRating = calculateAverage(totalRatingConflict, totalReviewsPlayer);

          double totalRatingStatistician = userData['totalRating_statistician'] ?? 0;
          int totalReviewsStatistician = userData['totalReviews_statistician'] ?? 0;
          double averageStatisticianRating = calculateAverage(totalRatingStatistician, totalReviewsStatistician);

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Zdjęcie użytkownika
                    Center(
                      child: CircleAvatar(
                        radius: 60,
                        backgroundImage: NetworkImage(avatarUrl),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Imię i nazwisko
                    Center(
                      child: Column(
                        children: [
                          Text(
                            displayName,
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            email,
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    // Nagłówek ocen
                    Text(
                      'Oceny:',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    // Oceny w postaci gwiazdek
                    _buildRatingRow('Ocena umiejętności', averageSkillsRating, totalReviewsPlayer),
                    SizedBox(height: 10),
                    _buildRatingRow('Ocena fair play', averageFairPlayRating, totalReviewsPlayer),
                    SizedBox(height: 10),
                    _buildRatingRow('Ocena konfliktowości', averageConflictRating, totalReviewsPlayer),
                    SizedBox(height: 10),
                    _buildRatingRow('Ocena jako statystyk', averageStatisticianRating, totalReviewsStatistician),

                    SizedBox(height: 30),

                    // Nagłówek statystyk
                    Text(
                      'Statystyki:',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),

                    // Statystyki
                    _buildStatisticRow('Rozegrane mecze', matches),
                    _buildStatisticRow('Gole', goals),
                    _buildStatisticRow('Asysty', assists),
                    _buildStatisticRow('Gol/Asysta na mecz', goalsAssistsPerMatch.toStringAsFixed(2)),
                    _buildStatisticRow('Dryblingi', dribbles),
                    _buildStatisticRow('Faule', fouls),
                    _buildStatisticRow('Czerwone kartki', redCards),
                    _buildStatisticRow('Żółte kartki', yellowCards),
                    _buildStatisticRow('Strzały celne', shotsOnTarget),
                    _buildStatisticRow('Strzały niecelne', shotsOffTarget),
                    _buildStatisticRow('Celność strzałów (%)', shotAccuracy.toStringAsFixed(2)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Funkcja tworząca wiersz z oceną w gwiazdkach
  Widget _buildRatingRow(String criteria, double rating, int totalReviews) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          criteria,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 5),
        Row(
          children: [
            RatingBarIndicator(
              rating: rating,
              itemBuilder: (context, index) => Icon(
                Icons.star,
                color: Colors.amber,
              ),
              itemCount: 5,
              itemSize: 30.0,
              direction: Axis.horizontal,
            ),
            SizedBox(width: 10),
            Text(
              '${rating.toStringAsFixed(1)}',
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
            Text(
              ' (${totalReviews > 0 ? totalReviews : "Brak ocen"})',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            SizedBox(width: 10),

          ],
        ),
      ],
    );
  }

  // Funkcja pomocnicza do wyświetlania wiersza statystyki
  Widget _buildStatisticRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            '$value',
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}
