import 'package:flutter/material.dart';
import 'services/auth_service.dart';

class ActivationScreen extends StatefulWidget {
  final VoidCallback onActivated;
  const ActivationScreen({super.key, required this.onActivated});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final _controller = TextEditingController();
  String? _error;
  bool _loading = false;

  Future<void> _activate() async {
    final key = _controller.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'Veuillez entrer une clé d\'activation.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await AuthService.instance.activate(key);
    if (!mounted) return;
    switch (result) {
      case ActivationResult.success:
        widget.onActivated();
        break;
      case ActivationResult.keyNotFound:
        setState(() {
          _loading = false;
          _error = 'Clé invalide.';
        });
        break;

      case ActivationResult.networkError:
        setState(() {
          _loading = false;
          _error = 'Erreur réseau. Vérifiez votre connexion.';
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 64, color: Color(0xFF2563EB)),
                const SizedBox(height: 24),
                const Text(
                  'Activation requise',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Entrez la clé d\'activation fournie par l\'administrateur.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    labelText: 'Clé d\'activation',
                    prefixIcon: Icon(Icons.vpn_key_outlined),
                  ),
                  enabled: !_loading,
                  onSubmitted: (_) => _activate(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _activate,
                    child: _loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Activer'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
