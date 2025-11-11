import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'welcome_screen.dart';

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance; // Inicjalizacja Firestore
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  String _firstName = '';
  String _lastName = '';
  bool _isLogin = true;
  String? _errorMessage;

  final String defaultAvatarUrl = 'https://firebasestorage.googleapis.com/v0/b/loginapp-796b3.appspot.com/o/avatars%2Fdefault_avatar.png?alt=media&token=a773a5a7-71f3-4465-9512-21fc83a37a82';

// Funkcja logowania przez Google
  Future<void> _signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // Użytkownik anulował logowanie
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      User? user = userCredential.user;

      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user!.uid).get();

      if (!userDoc.exists) {
        // Użytkownik nie istnieje, zapisz dane w Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'firstName': googleUser.displayName?.split(' ').first ?? 'Unknown',
          'lastName': googleUser.displayName?.split(' ').last ?? 'User',
          'email': user.email,
          'isAvailable': true,
          'isWillingToPlay': true,
          'avatarUrl': googleUser.photoUrl ?? defaultAvatarUrl, // Ustawienie avatara lub domyślnego
        });
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => WelcomeScreen(user: user),
        ),
      );
    } catch (e) {
      _handleFirebaseAuthError(e as FirebaseAuthException);
    }
  }


  // Funkcja sprawdzająca, czy adres e-mail istnieje w Firestore
  Future<bool> _isEmailAlreadyRegistered(String email) async {
    QuerySnapshot userSnapshot = await _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .get();

    return userSnapshot.docs.isNotEmpty;
  }

  // Funkcja do obsługi logowania lub rejestracji
  void _submit() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      try {
        if (_isLogin) {
          // Logowanie użytkownika
          UserCredential userCredential = await _auth.signInWithEmailAndPassword(
            email: _email,
            password: _password,
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => WelcomeScreen(user: userCredential.user!),
            ),
          );
        } else {
          // Sprawdzenie, czy adres e-mail już istnieje w Firestore
          bool emailExists = await _isEmailAlreadyRegistered(_email);

          if (emailExists) {
            setState(() {
              _errorMessage = 'Ten adres e-mail jest już zarejestrowany.';
            });
            return; // Przerwij proces rejestracji
          }

          // Rejestracja nowego użytkownika
          UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
            email: _email,
            password: _password,
          );

          // Aktualizacja danych użytkownika o imię i nazwisko
          await userCredential.user!.updateDisplayName('$_firstName $_lastName');

          // Zapisz dane użytkownika do Firestore
          await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
            'firstName': _firstName,
            'lastName': _lastName,
            'email': _email,
            'isAvailable': true,
            'isWillingToPlay': false,
            'avatarUrl': defaultAvatarUrl, // Ustawienie domyślnego avatara
          });

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => WelcomeScreen(user: userCredential.user!),
            ),
          );
        }
      } catch (e) {
        _handleFirebaseAuthError(e as FirebaseAuthException);
      }
    }
  }

  // Funkcja obsługi błędów Firebase Auth
  void _handleFirebaseAuthError(FirebaseAuthException e) {
    String errorMessage;
    switch (e.code) {
      case 'invalid-email':
        errorMessage = 'Adres e-mail jest nieprawidłowy.';
        break;
      case 'user-disabled':
        errorMessage = 'To konto zostało zablokowane.';
        break;
      case 'user-not-found':
        errorMessage = 'Nie znaleziono użytkownika o podanym adresie e-mail.';
        break;
      case 'wrong-password':
        errorMessage = 'Nieprawidłowe hasło. Spróbuj ponownie.';
        break;
      case 'email-already-in-use':
        errorMessage = 'Ten adres e-mail jest już zarejestrowany.';
        break;
      case 'weak-password':
        errorMessage = 'Hasło jest zbyt słabe. Wybierz silniejsze hasło.';
        break;
      case 'operation-not-allowed':
        errorMessage = 'Operacja jest niedozwolona. Skontaktuj się z administratorem.';
        break;
      default:
        errorMessage = 'Wystąpił nieznany błąd: ${e.message}';
    }

    setState(() {
      _errorMessage = errorMessage;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_errorMessage ?? 'Wystąpił nieznany błąd')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Logowanie' : 'Rejestracja'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              if (!_isLogin) ...[
                TextFormField(
                  decoration: InputDecoration(labelText: 'Imię'),
                  validator: (value) {
                    if (value!.isEmpty) return 'Proszę podać imię';
                    return null;
                  },
                  onSaved: (value) => _firstName = value!,
                ),
                TextFormField(
                  decoration: InputDecoration(labelText: 'Nazwisko'),
                  validator: (value) {
                    if (value!.isEmpty) return 'Proszę podać nazwisko';
                    return null;
                  },
                  onSaved: (value) => _lastName = value!,
                ),
              ],
              TextFormField(
                decoration: InputDecoration(labelText: 'E-mail'),
                validator: (value) {
                  if (value!.isEmpty) return 'Proszę podać e-mail';
                  return null;
                },
                onSaved: (value) => _email = value!,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Hasło'),
                obscureText: true,
                validator: (value) {
                  if (value!.isEmpty) return 'Proszę podać hasło';
                  return null;
                },
                onSaved: (value) => _password = value!,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submit,
                child: Text(_isLogin ? 'Zaloguj się' : 'Utwórz konto'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isLogin = !_isLogin;
                    _errorMessage = null;
                  });
                },
                child: Text(_isLogin ? 'Nie masz konta? Utwórz' : 'Masz konto? Zaloguj się'),
              ),
              SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _signInWithGoogle,
                icon: Icon(Icons.login),
                label: Text('Zaloguj się przez Google'),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
