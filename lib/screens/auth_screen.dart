import 'package:flutter/material.dart';
import 'package:recoveryplus/services/auth_service.dart';
import 'package:recoveryplus/screens/phone_input_screen.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added import
import 'package:recoveryplus/utils/dialog_utils.dart'; // Added import

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _surgeryTypeController = TextEditingController();
  final _surgeryDateController = TextEditingController();
  final _doctorNameController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  DateTime? _surgeryDate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colorScheme.secondary, colorScheme.secondary.withOpacity(0.7)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: colorScheme.surface, // Ensure card uses theme surface color
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isLogin ? 'Welcome Back' : 'Create Account',
                        style: textTheme.titleLarge?.copyWith(color: colorScheme.secondary), // Use theme text style
                      ),
                      SizedBox(height: 24),
                      if (!_isLogin) ...[
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                            prefixIcon: Icon(Icons.person, color: colorScheme.onSurface.withOpacity(0.7)), // Theme color
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            labelStyle: textTheme.labelLarge?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)), // Theme color
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your name';
                            }
                            return null;
                          },
                          style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface), // Theme color
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _surgeryTypeController,
                          decoration: InputDecoration(
                            labelText: 'Surgery Type',
                            prefixIcon: Icon(Icons.medical_services, color: colorScheme.onSurface.withOpacity(0.7)), // Theme color
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            labelStyle: textTheme.labelLarge?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)), // Theme color
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter surgery type';
                            }
                            return null;
                          },
                          style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface), // Theme color
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _surgeryDateController,
                          decoration: InputDecoration(
                            labelText: 'Surgery Date',
                            prefixIcon: Icon(Icons.calendar_today, color: colorScheme.onSurface.withOpacity(0.7)), // Theme color
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            labelStyle: textTheme.labelLarge?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)), // Theme color
                          ),
                          readOnly: true,
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: colorScheme.copyWith(
                                      primary: colorScheme.secondary, // Header background color
                                      onPrimary: colorScheme.onPrimary, // Header text color
                                      onSurface: colorScheme.onSurface, // Body text color
                                    ),
                                    textButtonTheme: TextButtonThemeData(
                                      style: TextButton.styleFrom(foregroundColor: colorScheme.secondary), // Button text color
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (date != null) {
                              if (mounted) {
                                setState(() {
                                  _surgeryDate = date;
                                  _surgeryDateController.text =
                                      '${date.day}/${date.month}/${date.year}';
                                });
                              }
                            }
                          },
                          validator: (value) {
                            if (!_isLogin && (value == null || value.isEmpty)) {
                              return 'Please select surgery date';
                            }
                            return null;
                          },
                          style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface), // Theme color
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _doctorNameController,
                          decoration: InputDecoration(
                            labelText: 'Doctor\'s Name',
                            prefixIcon: Icon(Icons.medical_services, color: colorScheme.onSurface.withOpacity(0.7)), // Theme color
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            labelStyle: textTheme.labelLarge?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)), // Theme color
                          ),
                          validator: (value) {
                            if (!_isLogin && (value == null || value.isEmpty)) {
                              return 'Please enter doctor\'s name';
                            }
                            return null;
                          },
                          style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface), // Theme color
                        ),
                        SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email, color: colorScheme.onSurface.withOpacity(0.7)), // Theme color
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          labelStyle: textTheme.labelLarge?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)), // Theme color
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                        style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface), // Theme color
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock, color: colorScheme.onSurface.withOpacity(0.7)), // Theme color
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          labelStyle: textTheme.labelLarge?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)), // Theme color
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                        style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface), // Theme color
                      ),
                      SizedBox(height: 24),
                      _isLoading
                          ? CircularProgressIndicator(color: colorScheme.secondary)
                          : ElevatedButton(
                              onPressed: _submitForm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.secondary,
                                foregroundColor: colorScheme.onPrimary,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 40,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                _isLogin ? 'Login' : 'Sign Up',
                                style: textTheme.labelLarge?.copyWith(color: colorScheme.onPrimary), // Theme color
                              ),
                            ),
                      SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isLogin = !_isLogin;
                          });
                        },
                        child: Text(
                          _isLogin
                              ? 'Create new account'
                              : 'I already have an account',
                          style: textTheme.labelLarge?.copyWith(color: colorScheme.secondary), // Theme color
                        ),
                      ),
                      SizedBox(height: 20),
                      Divider(color: colorScheme.onSurface.withOpacity(0.2)), // Theme color
                      SizedBox(height: 20),
                      Text(
                        'Or continue with',
                        style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)), // Theme color
                      ),
                      SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PhoneInputScreen(),
                            ),
                          );
                        },
                        icon: Icon(Icons.phone, color: colorScheme.secondary), // Theme color
                        label: Text('Continue with Phone', style: textTheme.labelLarge?.copyWith(color: colorScheme.secondary)), // Theme color
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: colorScheme.secondary), // Theme color
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        if (_isLogin) {
          debugPrint('[AuthScreen] Attempting to sign in with email: ${_emailController.text.trim()}');
          await authService.signInWithEmail(
            _emailController.text.trim(),
            _passwordController.text.trim(),
          );
          debugPrint('[AuthScreen] Sign in call completed.');
        } else {
          debugPrint('[AuthScreen] Attempting to sign up with email: ${_emailController.text.trim()}');
          await authService.signUpWithEmail(
            _emailController.text.trim(),
            _passwordController.text.trim(),
          );
          debugPrint('[AuthScreen] Sign up call completed.');

          // Save additional user data after signup
          if (_surgeryDate != null) {
            debugPrint('[AuthScreen] Saving additional user data.');
            await authService.saveUserDataAfterSignup(
              _nameController.text.trim(),
              _surgeryTypeController.text.trim(),
              _surgeryDate!,
              _doctorNameController.text.trim(),
            );
            debugPrint('[AuthScreen] Save user data call completed.');
          }
        }
      } catch (error) {
        debugPrint('[AuthScreen] ❌ Authentication failed: ${error.toString()}');
        String errorMessage = 'An unknown error occurred.';
        if (error is FirebaseAuthException) {
          errorMessage = error.message ?? errorMessage;
        } else {
          errorMessage = error.toString();
        }
        DialogUtils.showErrorDialog(
          context: context,
          title: 'Authentication Failed',
          message: errorMessage,
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _surgeryTypeController.dispose();
    _surgeryDateController.dispose();
    _doctorNameController.dispose();
    super.dispose();
  }
}