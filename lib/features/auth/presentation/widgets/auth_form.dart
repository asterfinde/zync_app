import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AuthForm extends StatefulWidget {
  final void Function(String email, String password, String nickname) submitFn;
  final bool isLoading;

  const AuthForm({
    super.key,
    required this.submitFn,
    required this.isLoading,
  });

  @override
  State<AuthForm> createState() => _AuthFormState();
}


class _AuthFormState extends State<AuthForm> {
  final _formKey = GlobalKey<FormState>();
  var _isLogin = true;
  var _userEmail = '';
  var _userPassword = '';
  var _nickname = '';
  var _isPasswordObscured = true;

  bool _formIsValid = false;

  void _validateForm() {
    final isValid = _formKey.currentState?.validate();
    setState(() {
      _formIsValid = isValid == true;
    });
  }

  void _trySubmit() {
    FocusScope.of(context).unfocus();
    _validateForm();
    if (_formIsValid) {
      _formKey.currentState?.save();
      log("[AuthForm] Form is valid. Calling submitFn with email: $_userEmail, nickname: $_nickname");
      widget.submitFn(_userEmail.trim(), _userPassword.trim(), _nickname.trim());
    } else {
      log("[AuthForm] Form submission attempted but form is invalid.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final accentColor = Colors.tealAccent.shade400;
    final primaryTextColor = isDarkMode ? Colors.white : Colors.black87;
    final secondaryTextColor = isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700;
    final inputFillColor = isDarkMode ? Colors.black26 : Colors.grey.shade200;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            _isLogin ? 'Bienvenido' : 'Crea tu Cuenta',
            textAlign: TextAlign.center,
            style: GoogleFonts.lato(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: primaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isLogin ? 'Inicia sesión para continuar' : 'Completa los campos para registrarte',
            textAlign: TextAlign.center,
            style: GoogleFonts.lato(
              fontSize: 16,
              color: secondaryTextColor,
            ),
          ),
          const SizedBox(height: 40),
          if (!_isLogin)
            Column(
              children: [
                TextFormField(
                  onChanged: (_) => _validateForm(),
                  key: const ValueKey('nickname'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor, introduce un nickname.';
                    }
                    if (value.trim().length < 3) {
                      return 'El nickname debe tener al menos 3 caracteres.';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _nickname = value ?? '';
                  },
                  style: TextStyle(color: primaryTextColor),
                  decoration: InputDecoration(
                    labelText: 'Nickname',
                    labelStyle: TextStyle(color: secondaryTextColor),
                    hintText: 'Tu apodo público',
                    hintStyle: TextStyle(color: secondaryTextColor.withOpacity(0.5)),
                    prefixIcon: Icon(Icons.person_outline, color: secondaryTextColor),
                    filled: true,
                    fillColor: inputFillColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: accentColor, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          TextFormField(
            onChanged: (_) => _validateForm(),
            key: const ValueKey('email'),
            validator: (value) {
              if (value == null || !value.contains('@') || !value.contains('.')) {
                return 'Por favor, introduce un email válido.';
              }
              return null;
            },
            onSaved: (value) {
              _userEmail = value ?? '';
            },
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: primaryTextColor),
            decoration: InputDecoration(
              labelText: 'Email',
              labelStyle: TextStyle(color: secondaryTextColor),
              hintText: 'tu.email@ejemplo.com',
              hintStyle: TextStyle(color: secondaryTextColor.withOpacity(0.5)),
              prefixIcon: Icon(Icons.alternate_email, color: secondaryTextColor),
              filled: true,
              fillColor: inputFillColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: accentColor, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            onChanged: (_) => _validateForm(),
            key: const ValueKey('password'),
            validator: (value) {
              if (value == null || value.length < 6) {
                return 'La contraseña debe tener al menos 6 caracteres.';
              }
              return null;
            },
            onSaved: (value) {
              _userPassword = value ?? '';
            },
            obscureText: _isPasswordObscured,
            style: TextStyle(color: primaryTextColor),
            decoration: InputDecoration(
              labelText: 'Contraseña',
              labelStyle: TextStyle(color: secondaryTextColor),
              prefixIcon: Icon(Icons.lock_outline, color: secondaryTextColor),
              filled: true,
              fillColor: inputFillColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: accentColor, width: 2),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: secondaryTextColor,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordObscured = !_isPasswordObscured;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (widget.isLoading)
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          if (!widget.isLoading)
            Opacity(
              opacity: _formIsValid ? 1.0 : 0.5,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accentColor.withOpacity(0.8), accentColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: ElevatedButton(
                  key: const ValueKey('auth_button'),
                  onPressed: _formIsValid ? _trySubmit : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 55),
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _isLogin ? 'Iniciar Sesi3n' : 'Crear Cuenta',
                    style: GoogleFonts.lato(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _formIsValid ? Colors.black : Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
          if (!widget.isLoading)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isLogin ? '¿No tienes una cuenta?' : '¿Ya tienes una cuenta?',
                    style: TextStyle(color: secondaryTextColor),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isLogin = !_isLogin;
                      });
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      overlayColor: accentColor.withOpacity(0.1),
                    ),
                    child: Text(
                      _isLogin ? 'Regístrate' : 'Inicia Sesión',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
