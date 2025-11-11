import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'welcome_screen.dart';

class SignupScreen extends StatefulWidget {
  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  String _firstName = '';
  String _lastName = '';
  String? _errorMessage;

  Future<bool> _isEmailAlreadyRegistered(String email) async {
    QuerySnapshot userSnapshot = await _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .get();
    return userSnapshot.docs.isNotEmpty;
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      try {
        bool emailExists = await _isEmailAlreadyRegistered(_email);
        if (emailExists) {
          setState(() {
            _errorMessage = 'Ten adres e-mail jest już zarejestrowany.';
          });
          return;
        }

        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: _email,
          password: _password,
        );

        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'firstName': _firstName,
          'lastName': _lastName,
          'email': _email,
          'isAvailable': true,
          'isWillingToPlay': false,
          'avatarUrl':
          'https://firebasestorage.googleapis.com/v0/b/loginapp-796b3.appspot.com/o/avatars%2Fdefault_avatar.png?alt=media&token=a773a5a7-71f3-4465-9512-21fc83a37a82',
        });

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WelcomeScreen(user: userCredential.user!),
          ),
        );
      } catch (e) {
        _handleFirebaseAuthError(e as FirebaseAuthException);
      }
    }
  }

  void _handleFirebaseAuthError(FirebaseAuthException e) {
    String errorMessage;
    switch (e.code) {
      case 'email-already-in-use':
        errorMessage = 'Ten adres e-mail jest już zarejestrowany.';
        break;
      case 'weak-password':
        errorMessage = 'Hasło jest zbyt słabe.';
        break;
      default:
        errorMessage = 'Wystąpił nieznany błąd: ${e.message}';
    }
    setState(() {
      _errorMessage = errorMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Zarejestruj się'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Utwórz nowe konto',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                'Podaj poniższe informacje, aby utworzyć nowe konto.',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              SizedBox(height: 20),
              _buildTextField(
                label: 'Imię',
                onSaved: (value) => _firstName = value!,
                validator: (value) => value!.isEmpty ? 'Proszę podać imię' : null,
              ),
              SizedBox(height: 15),
              _buildTextField(
                label: 'Nazwisko',
                onSaved: (value) => _lastName = value!,
                validator: (value) => value!.isEmpty ? 'Proszę podać nazwisko' : null,
              ),
              SizedBox(height: 15),
              _buildTextField(
                label: 'E-mail',
                onSaved: (value) => _email = value!,
                validator: (value) => value!.isEmpty ? 'Proszę podać e-mail' : null,
              ),
              SizedBox(height: 15),
              _buildTextField(
                label: 'Hasło',
                obscureText: true,
                onSaved: (value) => _password = value!,
                validator: (value) => value!.isEmpty ? 'Proszę podać hasło' : null,
              ),
              SizedBox(height: 25),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple.shade400, // Użycie deepPurple.shade400
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('Utwórz konto', style: TextStyle(fontSize: 18)),
              ),
              SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => LoginScreen()), // Przejście do login_screen
                    );
                  },
                  child: Text(
                    'Masz już konto? Zaloguj się',
                    style: TextStyle(color: Colors.deepPurple.shade400, fontSize: 16),

                  ),
                ),
              ),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Center(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red, fontSize: 14),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    bool obscureText = false,
    required FormFieldSetter<String> onSaved,
    required FormFieldValidator<String> validator,
  }) {
    return TextFormField(
      obscureText: obscureText,
      onSaved: onSaved,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.black54),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.shade400!),
          borderRadius: BorderRadius.circular(8),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red),
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.deepPurple.shade50,
      ),
    );
  }
}
