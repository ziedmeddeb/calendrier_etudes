import 'package:flutter/material.dart';

class LockedScreen extends StatelessWidget {
  const LockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.no_cell_outlined, size: 64, color: Colors.red),
                SizedBox(height: 24),
                Text(
                  'Application verrouillée',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                Text(
                  'Cette installation est liée à un autre appareil. '
                  'Contactez l\'administrateur pour obtenir un accès.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
