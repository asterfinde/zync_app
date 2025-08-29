// lib/features/auth/presentation/widgets/auth_form.dart

import 'dart:developer';
import 'package:flutter/material.dart';

class AuthForm extends StatefulWidget {
  final void Function(String email, String password) submitFn;
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
  // --- CAMBIO 1 de 3: Se añade una variable para controlar la visibilidad ---
  var _isPasswordObscured = true;

  void _trySubmit() {
    final isValid = _formKey.currentState?.validate();
    FocusScope.of(context).unfocus();

    if (isValid == true) {
      _formKey.currentState?.save();
      log("[AuthForm] Form is valid. Calling submitFn with email: $_userEmail");
      widget.submitFn(_userEmail.trim(), _userPassword.trim());
    } else {
      log("[AuthForm] Form submission attempted but form is invalid.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            _isLogin ? 'Iniciar Sesión' : 'Crear Cuenta',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 24),
          TextFormField(
            key: const ValueKey('email'),
            validator: (value) {
              if (value == null || !value.contains('@')) {
                return 'Por favor, introduce un email válido.';
              }
              return null;
            },
            onSaved: (value) {
              _userEmail = value ?? '';
            },
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          // --- CAMBIO 2 de 3: Se modifica el TextFormField de la contraseña ---
          TextFormField(
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
            // Se usa la variable de estado para ocultar el texto
            obscureText: _isPasswordObscured,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              border: const OutlineInputBorder(),
              // Se añade el ícono del ojo
              suffixIcon: IconButton(
                icon: Icon(
                  // Cambia el ícono dependiendo del estado
                  _isPasswordObscured ? Icons.visibility_off : Icons.visibility,
                ),
                // --- CAMBIO 3 de 3: Lógica para cambiar la visibilidad ---
                onPressed: () {
                  setState(() {
                    _isPasswordObscured = !_isPasswordObscured;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (widget.isLoading) const CircularProgressIndicator(),
          if (!widget.isLoading)
            ElevatedButton(
              onPressed: _trySubmit,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: Text(_isLogin ? 'Login' : 'Signup'),
            ),
          if (!widget.isLoading)
            TextButton(
              child: Text(
                _isLogin ? 'Crear una nueva cuenta' : 'Ya tengo una cuenta',
              ),
              onPressed: () {
                setState(() {
                  _isLogin = !_isLogin;
                });
              },
            ),
        ],
      ),
    );
  }
}


// // lib/features/auth/presentation/widgets/auth_form.dart

// import 'dart:developer';
// import 'package:flutter/material.dart';

// class AuthForm extends StatefulWidget {
//   final void Function(String email, String password) submitFn;
//   final bool isLoading;

//   const AuthForm({
//     super.key,
//     required this.submitFn,
//     required this.isLoading,
//   });

//   @override
//   State<AuthForm> createState() => _AuthFormState();
// }

// class _AuthFormState extends State<AuthForm> {
//   final _formKey = GlobalKey<FormState>();
//   var _isLogin = true;
//   var _userEmail = '';
//   var _userPassword = '';

//   void _trySubmit() {
//     final isValid = _formKey.currentState?.validate();
//     FocusScope.of(context).unfocus();

//     if (isValid == true) {
//       _formKey.currentState?.save();
//       log("[AuthForm] Form is valid. Calling submitFn with email: $_userEmail");
//       widget.submitFn(_userEmail.trim(), _userPassword.trim());
//     } else {
//       log("[AuthForm] Form submission attempted but form is invalid.");
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Form(
//       key: _formKey,
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: <Widget>[
//           Text(
//             _isLogin ? 'Iniciar Sesión' : 'Crear Cuenta',
//             style: Theme.of(context).textTheme.headlineMedium,
//           ),
//           const SizedBox(height: 24),
//           TextFormField(
//             key: const ValueKey('email'),
//             validator: (value) {
//               if (value == null || !value.contains('@')) {
//                 return 'Por favor, introduce un email válido.';
//               }
//               return null;
//             },
//             onSaved: (value) {
//               _userEmail = value ?? '';
//             },
//             keyboardType: TextInputType.emailAddress,
//             decoration: const InputDecoration(
//               labelText: 'Email',
//               border: OutlineInputBorder(),
//             ),
//           ),
//           const SizedBox(height: 12),
//           TextFormField(
//             key: const ValueKey('password'),
//             validator: (value) {
//               if (value == null || value.length < 6) {
//                 return 'La contraseña debe tener al menos 6 caracteres.';
//               }
//               return null;
//             },
//             onSaved: (value) {
//               _userPassword = value ?? '';
//             },
//             obscureText: true,
//             decoration: const InputDecoration(
//               labelText: 'Contraseña',
//               border: OutlineInputBorder(),
//             ),
//           ),
//           const SizedBox(height: 20),
//           if (widget.isLoading) const CircularProgressIndicator(),
//           if (!widget.isLoading)
//             ElevatedButton(
//               onPressed: _trySubmit,
//               style: ElevatedButton.styleFrom(
//                 minimumSize: const Size(double.infinity, 50),
//               ),
//               child: Text(_isLogin ? 'Login' : 'Signup'),
//             ),
//           if (!widget.isLoading)
//             TextButton(
//               child: Text(
//                 _isLogin
//                     ? 'Crear una nueva cuenta'
//                     : 'Ya tengo una cuenta',
//               ),
//               onPressed: () {
//                 setState(() {
//                   _isLogin = !_isLogin;
//                 });
//               },
//             ),
//         ],
//       ),
//     );
//   }
// }