import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; // Dodajemy do otwierania linków

class UserDetailsScreen extends StatelessWidget {
  final String userEmail;

  const UserDetailsScreen({Key? key, required this.userEmail}) : super(key: key);

  double calculateAverage(double totalRating, int totalReviews) {
    return totalReviews > 0 ? totalRating / totalReviews : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Szczegóły użytkownika'),
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: userEmail)
            .limit(1)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('Nie znaleziono użytkownika.'));
          }

          var userData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
          String firstName = userData['firstName'] ?? 'Brak imienia';
          String lastName = userData['lastName'] ?? 'Brak nazwiska';
          String email = userData['email'] ?? 'Brak adresu e-mail';
          String avatarUrl = userData['avatarUrl'] ?? 'https://via.placeholder.com/150';
          bool shareData = userData['shareData'] ?? false;
          bool shareInstagram = userData['shareInstagram'] ?? false;
          bool shareTwitter = userData['shareTwitter'] ?? false;
          String instagramProfile = userData['instagramProfile'] ?? '';
          String twitterProfile = userData['twitterProfile'] ?? '';

          int matches = userData['matches'] ?? 0;
          int goals = userData['goals'] ?? 0;
          int assists = userData['assists'] ?? 0;
          int dribbles = userData['dribbles'] ?? 0;
          int fouls = userData['fouls'] ?? 0;
          int redCards = userData['redCards'] ?? 0;
          int yellowCards = userData['yellowCards'] ?? 0;
          int shotsOnTarget = userData['shotsOnTarget'] ?? 0;
          int shotsOffTarget = userData['shotsOffTarget'] ?? 0;

          double totalRatingStatistician = userData['totalRating_statistician'] ?? 0;
          int totalReviewsStatistician = userData['totalReviews_statistician'] ?? 0;
          double averageStatisticianRating = calculateAverage(totalRatingStatistician, totalReviewsStatistician);

          double totalRatingSkills = userData['totalRating_skills'] ?? 0;
          double totalRatingFairPlay = userData['totalRating_fairPlay'] ?? 0;
          double totalRatingConflict = userData['totalRating_conflict'] ?? 0;
          int totalReviewsPlayer = userData['totalReviews_player'] ?? 0;

          double averageSkillsRating = calculateAverage(totalRatingSkills, totalReviewsPlayer);
          double averageFairPlayRating = calculateAverage(totalRatingFairPlay, totalReviewsPlayer);
          double averageConflictRating = calculateAverage(totalRatingConflict, totalReviewsPlayer);

          // Obliczenia dodatkowych wartości
          double shotAccuracy = (shotsOnTarget + shotsOffTarget) > 0
              ? (shotsOnTarget / (shotsOnTarget + shotsOffTarget)) * 100
              : 0.0;
          double goalsAssistsPerMatch = matches > 0
              ? (goals + assists) / matches
              : 0.0;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Awatar użytkownika
                  Center(
                    child: CircleAvatar(
                      radius: 60,
                      backgroundImage: NetworkImage(avatarUrl),
                    ),
                  ),
                  SizedBox(height: 20),

                  // Imię, nazwisko i adres e-mail
                  Center(
                    child: Column(
                      children: [
                        Text(
                          '$firstName $lastName',
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

                  // Nagłówek i sekcja ocen
                  Text(
                    'Oceny:',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  _buildRatingRow('Ocena umiejętności', averageSkillsRating, totalReviewsPlayer),
                  _buildRatingRow('Ocena fair play', averageFairPlayRating, totalReviewsPlayer),
                  _buildRatingRow('Ocena konfliktowości', averageConflictRating, totalReviewsPlayer),
                  _buildRatingRow('Ocena jako statystyk', averageStatisticianRating, totalReviewsStatistician),

                  SizedBox(height: 20),

                  // Sekcja statystyk
                  Text(
                    'Statystyki:',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
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

                  SizedBox(height: 20),

                  // Odnośniki do social mediów
                  if (shareData) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (shareInstagram && instagramProfile.isNotEmpty)
                          GestureDetector(
                            onTap: () async {
                              final String instagramUrl = 'instagram://user?username=$instagramProfile';
                              final String instagramWebUrl = 'https://www.instagram.com/$instagramProfile';

                              try {
                                await _launchURL(instagramUrl, mode: LaunchMode.externalApplication);
                              } catch (e) {
                                await _launchURL(instagramWebUrl, mode: LaunchMode.externalApplication);
                              }
                            },
                            child: Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: ClipOval(
                                    child: Image.network(
                                      'https://static.vecteezy.com/system/resources/previews/018/930/415/non_2x/instagram-logo-instagram-icon-transparent-free-png.png',
                                      width: 30,
                                      height: 30,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Text(
                                  instagramProfile, // Wyświetlenie nazwy profilu
                                  style: TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        if (shareTwitter && twitterProfile.isNotEmpty)
                          GestureDetector(
                            onTap: () async {
                              final String twitterUrl = 'twitter://user?screen_name=$twitterProfile';
                              final String twitterWebUrl = 'https://twitter.com/$twitterProfile';

                              try {
                                await _launchURL(twitterUrl, mode: LaunchMode.externalApplication);
                              } catch (e) {
                                await _launchURL(twitterWebUrl, mode: LaunchMode.externalApplication);
                              }
                            },
                            child: Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: ClipOval(
                                    child: Image.network(
                                      'https://img.freepik.com/premium-wektory/nowe-logo-twittera-x-2023-pobierz-wektor-logo-twittera-x_691560-10794.jpg?semt=ais_hybrid',
                                      width: 20,
                                      height: 20,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Text(
                                  twitterProfile.isNotEmpty ? twitterProfile : '', // Wyświetlenie nazwy profilu
                                  style: TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Funkcja do otwierania linków w przeglądarce
  Future<void> _launchURL(String url, {LaunchMode mode = LaunchMode.platformDefault}) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: mode);
    } else {
      throw 'Could not launch $url';
    }
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

  // Funkcja pomocnicza do wyświetlania oceny w gwiazdkach
  Widget _buildRatingRow(String label, double averageRating, int totalReviews) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 5),
          Row(
            children: [
              _buildStarRating(averageRating),
              SizedBox(width: 10),
              Text(
                '${averageRating.toStringAsFixed(1)}',
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
      ),
    );
  }

  // Funkcja pomocnicza do budowania gwiazdek na podstawie oceny z połówkami
  Widget _buildStarRating(double rating) {
    int fullStars = rating.floor();
    bool hasHalfStar = (rating - fullStars) >= 0.5;

    return Row(
      children: List.generate(5, (index) {
        if (index < fullStars) {
          return Icon(Icons.star, color: Colors.amber, size: 20);
        } else if (index == fullStars && hasHalfStar) {
          return Icon(Icons.star_half, color: Colors.amber, size: 20);
        } else {
          return Icon(Icons.star_border, color: Colors.amber, size: 20);
        }
      }),
    );
  }
}
