import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'controllers/groupe_controller.dart';
import 'controllers/theme_controller.dart';
import 'services/sync_service.dart';

class DataScreen extends StatefulWidget {
  const DataScreen({super.key});

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  bool _isPushing = false;
  bool _isReceiving = false;
  String _status = 'Pret a synchroniser.';
  DateTime? _lastSyncedAt;

  Future<void> _pushData() async {
    setState(() {
      _isPushing = true;
      _status = 'Envoi des donnees en cours...';
    });

    final SyncResult result = await SyncService.instance.pushData();

    if (!mounted) return;

    setState(() {
      _isPushing = false;
      _status = result.message;
      _lastSyncedAt = result.syncedAt;
    });

    _showResult(result);
  }

  Future<void> _receiveData() async {
    setState(() {
      _isReceiving = true;
      _status = 'Reception des donnees en cours...';
    });

    final SyncResult result = await SyncService.instance.receiveData();

    if (!mounted) return;

    if (result.success) {
      await context.read<GroupeController>().rechargerGroupes(context);
    }

    setState(() {
      _isReceiving = false;
      _status = result.message;
      _lastSyncedAt = result.syncedAt;
    });

    _showResult(result);
  }

  Future<void> _confirmAndPush() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmation'),
          content: const Text('Voulez-vous vraiment envoyer (push) vos donnees ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirmer'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _pushData();
    }
  }

  Future<void> _confirmAndReceive() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmation'),
          content: const Text('Voulez-vous vraiment recuperer (receive) les donnees ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirmer'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _receiveData();
    }
  }

  void _showResult(SyncResult result) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Provider.of<ThemeController>(context);
    final String lastSyncText = _lastSyncedAt == null
        ? 'Jamais'
        : DateFormat('dd/MM/yyyy HH:mm').format(_lastSyncedAt!);

    return Scaffold(
      appBar: AppBar(title: const Text('Configuration')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Theme toggle section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        themeController.isDark ? Icons.dark_mode : Icons.light_mode,
                        color: Theme.of(context).colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mode sombre',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            themeController.isDark ? 'Activé' : 'Désactivé',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: themeController.isDark,
                      onChanged: (_) => themeController.toggleTheme(),
                      activeColor: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Sync section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Synchronisation multi-appareils',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_status),
                    const SizedBox(height: 8),

                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_isPushing || _isReceiving) ? null : _confirmAndPush,
                icon: _isPushing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.upload_outlined),
                label: Text(_isPushing ? 'Envoi...' : 'Push (envoyer mes donnees)'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: (_isPushing || _isReceiving) ? null : _confirmAndReceive,
                icon: _isReceiving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined),
                label: Text(_isReceiving ? 'Reception...' : 'Receive (recuperer les donnees)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
