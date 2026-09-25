import 'package:flutter/material.dart';

import '../widgets/brand_header.dart';

/// Standalone Login page for Tech Panda Inventory.
class LoginPage extends StatefulWidget {
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final bool rememberCredentials;
  final ValueChanged<bool> onRememberCredentialsChanged;
  final VoidCallback onLogin;
  final String? error;

  const LoginPage({
    super.key,
    required this.usernameController,
    required this.passwordController,
    required this.rememberCredentials,
    required this.onRememberCredentialsChanged,
    required this.onLogin,
    this.error,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _showPassword = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: BrandLogo(size: 96)),
                const SizedBox(height: 18),
                Text(
                  'Tech Panda Inventory',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: widget.usernameController,
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: widget.passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                      icon: Icon(
                        _showPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      tooltip: _showPassword
                          ? 'Hide password'
                          : 'Show password',
                    ),
                  ),
                  obscureText: !_showPassword,
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: widget.rememberCredentials,
                  onChanged: (value) =>
                      widget.onRememberCredentialsChanged(value ?? false),
                  title: const Text('Remember credentials'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: widget.onLogin,
                  icon: const Icon(Icons.login),
                  label: const Text('Sign in'),
                ),
                if (widget.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      widget.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
