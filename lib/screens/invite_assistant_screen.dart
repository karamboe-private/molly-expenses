import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/expense_provider.dart';

class InviteAssistantScreen extends StatefulWidget {
  const InviteAssistantScreen({super.key});

  @override
  State<InviteAssistantScreen> createState() => _InviteAssistantScreenState();
}

class _InviteAssistantScreenState extends State<InviteAssistantScreen> {
  String? _inviteCode;
  DateTime? _expiresAt;
  bool _isGenerating = false;

  Future<void> _generateCode() async {
    final auth = context.read<AuthProvider>();
    if (auth.accountId == null || auth.user == null) return;

    setState(() => _isGenerating = true);

    final invite = await context.read<ExpenseProvider>().createInviteCode(
          accountId: auth.accountId!,
          createdBy: auth.user!.uid,
        );

    setState(() {
      _isGenerating = false;
      _inviteCode = invite?.code;
      _expiresAt = invite?.expiresAt;
    });

    if (invite == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to generate invite code')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMd().add_jm();

    return Scaffold(
      appBar: AppBar(title: const Text('Invite Assistant')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Generate an invite code for an assistant. They will enter this code when registering.',
            ),
            const SizedBox(height: 24),
            if (_inviteCode != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        _inviteCode!,
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              letterSpacing: 4,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (_expiresAt != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Expires ${dateFormat.format(_expiresAt!)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white54,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _inviteCode!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code copied to clipboard')),
                  );
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy Code'),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isGenerating ? null : _generateCode,
              child: _isGenerating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_inviteCode == null ? 'Generate Code' : 'Generate New Code'),
            ),
          ],
        ),
      ),
    );
  }
}
