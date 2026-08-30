import 'package:flutter/material.dart';
import 'package:trace/app/matrix_session_controller.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.controller});

  final MatrixSessionController controller;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _homeserverController = TextEditingController(text: 'matrix.org');
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _restoreHints();
  }

  Future<void> _restoreHints() async {
    final values = await Future.wait([
      widget.controller.readLastHomeserver(),
      widget.controller.readLastUser(),
    ]);
    if (!mounted) return;
    if (values[0]?.isNotEmpty == true) {
      _homeserverController.text = values[0]!;
    }
    if (values[1]?.isNotEmpty == true) _userController.text = values[1]!;
  }

  @override
  void dispose() {
    _homeserverController.dispose();
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await widget.controller.login(
        homeserver: _homeserverController.text,
        user: _userController.text,
        password: _passwordController.text,
      );
    } catch (_) {
      // The controller exposes a sanitized error below the form.
    }
  }

  Future<void> _sso() async {
    try {
      await widget.controller.beginSso(_homeserverController.text);
    } catch (_) {
      // The controller exposes the sanitized error in the form.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          widget.controller.addingProfile
                              ? 'Add Matrix profile'
                              : 'Sign in to Matrix',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Use matrix.org or the address of your own homeserver.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          key: const Key('homeserver-field'),
                          controller: _homeserverController,
                          autocorrect: false,
                          keyboardType: TextInputType.url,
                          decoration: const InputDecoration(
                            labelText: 'Homeserver',
                            hintText: 'matrix.org',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          key: const Key('matrix-user-field'),
                          controller: _userController,
                          autocorrect: false,
                          autofillHints: const [AutofillHints.username],
                          decoration: const InputDecoration(
                            labelText: 'Matrix ID or username',
                            hintText: '@you:matrix.org',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => value?.trim().isEmpty == true
                              ? 'Enter your Matrix ID or username.'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          key: const Key('matrix-password-field'),
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          autofillHints: const [AutofillHints.password],
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            border: const OutlineInputBorder(),
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
                          validator: (value) => value?.isEmpty == true
                              ? 'Enter your password.'
                              : null,
                        ),
                        if (widget.controller.actionError
                            case final error?) ...[
                          const SizedBox(height: 14),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              error,
                              key: const Key('login-error'),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          key: const Key('matrix-login-button'),
                          onPressed: widget.controller.busy ? null : _submit,
                          child: widget.controller.busy
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Sign in'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          key: const Key('matrix-sso-button'),
                          onPressed: widget.controller.busy ? null : _sso,
                          icon: const Icon(Icons.open_in_browser),
                          label: const Text('Sign in with browser'),
                        ),
                        if (widget.controller.canCancelProfileLogin) ...[
                          const SizedBox(height: 10),
                          TextButton(
                            key: const Key('cancel-profile-login'),
                            onPressed: widget.controller.busy
                                ? null
                                : widget.controller.cancelProfileLogin,
                            child: const Text('Back to current profile'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
