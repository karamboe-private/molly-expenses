import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/routes.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (!_initialized && auth.userProfile != null) {
            _nameController.text = auth.userProfile!.displayName;
            _initialized = true;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            (auth.userProfile?.displayName ?? '?')
                                .substring(0, 1)
                                .toUpperCase(),
                          ),
                        ),
                        title: Text(auth.userProfile?.displayName ?? ''),
                        subtitle: Text(auth.userProfile?.email ?? ''),
                      ),
                      const Divider(),
                      _InfoTile(
                        icon: Icons.admin_panel_settings,
                        label: 'Role',
                        value: auth.isOwner ? 'Parent / Owner' : 'Assistant',
                      ),
                      if (auth.account != null)
                        _InfoTile(
                          icon: Icons.child_care,
                          label: 'Beneficiary',
                          value: auth.account!.beneficiaryName,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: auth.isLoading
                    ? null
                    : () async {
                        final success = await auth.updateProfile(
                          displayName: _nameController.text.trim(),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? 'Profile updated'
                                    : auth.errorMessage ?? 'Update failed',
                              ),
                            ),
                          );
                        }
                      },
                child: const Text('Save Name'),
              ),
              if (auth.isOwner) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.person_add),
                  title: const Text('Invite Assistant'),
                  subtitle: const Text('Generate an invite code'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).pushNamed(AppRoutes.inviteAssistant);
                  },
                ),
              ],
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () async {
                  await auth.signOut();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(label, style: const TextStyle(fontSize: 13, color: Colors.white54)),
      trailing: Text(value),
    );
  }
}
