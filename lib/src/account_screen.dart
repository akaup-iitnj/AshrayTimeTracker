import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_store.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _creatingAccount = false;
  bool _obscurePassword = true;
  bool _busy = false;
  String? _formError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (!email.contains('@')) {
      setState(() => _formError = 'Enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      setState(
        () => _formError = 'Use at least 6 characters for the password.',
      );
      return;
    }

    setState(() {
      _busy = true;
      _formError = null;
    });
    try {
      if (_creatingAccount) {
        final result = await widget.store.signUp(email, password);
        if (result.needsEmailConfirmation && mounted) {
          _passwordController.clear();
          setState(() => _creatingAccount = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Check your email to confirm the account, then return here to sign in.',
              ),
              duration: Duration(seconds: 7),
            ),
          );
        }
      } else {
        await widget.store.signIn(email, password);
        _passwordController.clear();
      }
    } on Object catch (error) {
      if (mounted) setState(() => _formError = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyError(Object error) {
    if (error is AuthException) return error.message;
    return error.toString().replaceFirst(RegExp(r'^\w+Exception:\s*'), '');
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Cloud account')),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: widget.store.isCloudSignedIn
                    ? _SignedInView(store: widget.store)
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                        children: [
                          Icon(
                            Icons.cloud_outlined,
                            size: 48,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            _creatingAccount
                                ? 'Create your account'
                                : 'Sync across devices',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your local entries stay available offline. Signing in adds a private cloud copy for your other devices.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 28),
                          TextField(
                            controller: _emailController,
                            enabled: !_busy,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _passwordController,
                            enabled: !_busy,
                            obscureText: _obscurePassword,
                            autofillHints: _creatingAccount
                                ? const [AutofillHints.newPassword]
                                : const [AutofillHints.password],
                            onSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Show password'
                                    : 'Hide password',
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                          ),
                          if (_formError != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _formError!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          FilledButton(
                            onPressed: _busy ? null : _submit,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                            ),
                            child: _busy
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _creatingAccount
                                        ? 'Create account'
                                        : 'Sign in',
                                  ),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () {
                                    setState(() {
                                      _creatingAccount = !_creatingAccount;
                                      _formError = null;
                                    });
                                  },
                            child: Text(
                              _creatingAccount
                                  ? 'I already have an account'
                                  : 'Create a new account',
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SignedInView extends StatelessWidget {
  const _SignedInView({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final error = store.syncError;
    final lastSync = store.lastSyncAt;
    final lastSyncText = lastSync == null
        ? 'Not synchronized yet'
        : 'Last synced ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(lastSync))}';
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      children: [
        CircleAvatar(
          radius: 34,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.cloud_done_outlined,
            size: 34,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          store.cloudUserEmail ?? 'Signed in',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        Text(
          store.isSyncing ? 'Synchronizing…' : lastSyncText,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: store.isSyncing ? null : store.synchronize,
          icon: const Icon(Icons.sync),
          label: const Text('Sync now'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: store.isSyncing ? null : store.signOut,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
          ),
          child: const Text('Sign out'),
        ),
        const SizedBox(height: 18),
        Text(
          'Signing out does not erase the entries stored on this device.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
