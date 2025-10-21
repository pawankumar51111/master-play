import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:masterplay/pages/info_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';
import '../models/app_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = true;


  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final session = supabase.auth.currentSession;
    if (session != null) {

      await AppState().initialize();

      if (AppState().updateType.isNotEmpty){
        _navigateToPage(InfoPage(currentVersion: AppState().currentVersion, minVersion: AppState().minVersion, maxVersion: AppState().maxVersion, updateType: AppState().updateType));
        return;
      }

      _navigateToPage(const MyHomePage(title: 'My Home Page'));

    } else {
      // User not logged in, stop the loading state
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Handle Sign In / Sign Out
  Future<void> _onSignInOrOut() async {
    if (supabase.auth.currentUser == null) {
      // User is not signed in, sign them in
      await _signInWithGoogle();
    } else {
      _showSignOutDialog();
    }
  }

  // Method for signing in with Google
  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      //  Replace with your actual client IDs
      const webClientId = '419450533501-nofkhbkmlbjls80spfihcf28vot1hlsi.apps.googleusercontent.com';
      const iosClientId = '419450533501-iari4b2goejvqsa2tnvh1qejb9gjf4f9.apps.googleusercontent.com';

      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: iosClientId,
        serverClientId: webClientId,
      );

      // Check if a user is already signed in and disconnect if needed
      if (await googleSignIn.isSignedIn()) {
        // await googleSignIn.signOut();
        await googleSignIn.disconnect();
      }

      // Trigger Google Sign-In
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() {
          _isLoading = false;
        });
        return; // User canceled sign-in
      }

      // Retrieve authentication tokens
      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) {
        throw 'Authentication failed: Missing access or ID token.';
      }

      // Sign in with Supabase
      final response = await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      // Validate session
      if (response.session == null || response.user == null) {
        throw Exception('Authentication failed: No session created.');
      }

      // Check if the user is authenticated
      if (response.session != null && response.user != null) {

        await AppState().initialize();

        if (AppState().updateType.isNotEmpty){
          _navigateToPage(InfoPage(currentVersion: AppState().currentVersion, minVersion: AppState().minVersion, maxVersion: AppState().maxVersion, updateType: AppState().updateType));
          return;
        }

        _navigateToPage(const MyHomePage(title: 'My Home Page'));

      } else {
        throw 'Authentication failed: No session created.';
      }
    } catch (error) {
      String errorMessage = 'Close the app completely, restart it, and try again.';

      if (error.toString().contains('Network')) {
        errorMessage = 'It seems there’s a network issue. Please check your connection and try again.';
      } else if (error.toString().contains('Authentication failed')) {
        errorMessage = 'Authentication failed. Close the app, restart it, and try again.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  Future<void> _showSignOutDialog() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );

    if (shouldSignOut == true) {
      _signOut();
    }
  }

  Future<void> _signOut() async {
    try {

      setState(() {
        _isLoading = true;
      });

      await supabase.auth.signOut();
      await Supabase.instance.client.dispose();

      final GoogleSignIn googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        // await googleSignIn.signOut();
        await googleSignIn.disconnect();
      }

      await AppState().resetState();

      setState(() {
        _isLoading = false;
      }); // Update UI
      // Close the app after successful sign out
      // SystemNavigator.pop();
      SystemChannels.platform.invokeMethod('SystemNavigator.pop');
      exit(0); // Forcefully terminate the app


    } on AuthException catch (error) {
      context.showSnackBar(error.message, isError: true);
    } catch (error) {
      context.showSnackBar('Unexpected error occurred', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2575FC), Color(0xFF6A11CB)], // blue-to-purple gradient
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                // Logo with subtle animation
                AnimatedScale(
                  scale: 1.0,
                  duration: const Duration(milliseconds: 700),
                  child: Image.asset(
                    'assets/launcher_icon.png',
                    height: 250,
                    width: 250,
                  ),
                ),

                const SizedBox(height: 12),

                // Title with improved styling
                const Text(
                  'Welcome to MasterPlay',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 8),

                // Subtitle with subtle transparency
                const Text(
                  'Play Smarter, Controlled, Fair & Fun',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500, // Added to make it stand out more
                    color: Colors.white70,
                    height: 1.5, // Adding some line height for better readability
                  ),
                ),

                const SizedBox(height: 40),

                // Card for Sign-In Button
                Card(
                  color: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24),
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : SizedBox(
                      width: 240, // Limit the button width
                      child: ElevatedButton(
                        onPressed: _onSignInOrOut,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Image.asset('assets/google_logo.png', height: 36),
                            const SizedBox(width: 12),
                            Text(
                              supabase.auth.currentUser == null ? 'Sign in with Google' : 'Sign Out',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Email Display
                if (supabase.auth.currentUser != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Text(
                      '${supabase.auth.currentUser!.email}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  void _navigateToPage(Widget page) {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => page));
  }

}
