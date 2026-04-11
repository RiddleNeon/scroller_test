import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wurp/logic/repositories/user_repository.dart';
import 'package:wurp/ui/animations/slide_morph_transitions.dart';
import 'package:wurp/ui/misc/ban_appeal_screen.dart';
import 'package:wurp/ui/router.dart';

import '../../base_logic.dart';
import '../../logic/users/user_model.dart';

// ─────────────────────────────────────────────
// Auth mode
// ─────────────────────────────────────────────

enum _AuthMode { login, signup, recover }

// ─────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  // ── State ──────────────────────────────────

  _AuthMode _mode = _AuthMode.login;
  int _modeDirection = 1;
  int _modeVersion = 0;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  bool _isBanned = false;
  String? _signedInUserId;
  UserProfile? _user;

  // ── Form ───────────────────────────────────

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // ── Animations ─────────────────────────────

  // Entry: fade + slide on first load
  late final AnimationController _entryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();

  late final Animation<double> _entryFade = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);

  late final Animation<Offset> _entrySlide = Tween<Offset>(
    begin: const Offset(0, 0.06),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic));

  // Shake on error
  late final AnimationController _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  late final Animation<double> _shakeAnim = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
    TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
    TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 2),
    TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
    TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 1),
  ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));

  // Ban banner: slide in from top
  late final AnimationController _banController = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));

  late final Animation<double> _banFade = CurvedAnimation(parent: _banController, curve: Curves.easeOut);

  late final Animation<Offset> _banSlide = Tween<Offset>(
    begin: const Offset(0, -0.3),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _banController, curve: Curves.easeOutCubic));

  @override
  void dispose() {
    _entryController.dispose();
    _shakeController.dispose();
    _banController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────

  void _setError(String? msg) {
    setState(() {
      _errorMessage = msg;
      _successMessage = null;
    });
    if (msg != null) _shakeController.forward(from: 0);
  }

  void _setSuccess(String msg) {
    setState(() {
      _successMessage = msg;
      _errorMessage = null;
    });
  }

  Future<void> _switchMode(_AuthMode mode) async {
    if (_mode == mode) return;
    setState(() {
      _modeDirection = _modeIndex(mode) > _modeIndex(_mode) ? 1 : -1;
      _mode = mode;
      _modeVersion++;
      _errorMessage = null;
      _successMessage = null;
    });
  }

  int _modeIndex(_AuthMode mode) => switch (mode) {
    _AuthMode.login => 0,
    _AuthMode.signup => 1,
    _AuthMode.recover => 2,
  };

  // ── Auth logic ─────────────────────────────

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    switch (_mode) {
      case _AuthMode.login:
        await _doLogin();
      case _AuthMode.signup:
        await _doSignup();
      case _AuthMode.recover:
        await _doRecover();
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _doLogin() async {
    try {
      final response = await auth.signInWithPassword(email: _emailController.text.trim(), password: _passwordController.text);
      _signedInUserId = response.user?.id;
    } catch (e) {
      _setError("Unable to sign in. ${e is AuthException ? e.message : ''}");
      return;
    }

    if (_signedInUserId == null) {
      _setError("Unable to sign in.");
      return;
    }

    try {
      _user = await userRepository.getUserSupabase(_signedInUserId!) ?? await userRepository.getOrCreateCurrentUser();

      if (_user == null) {
        await auth.signOut();
        setState(() => _isBanned = true);
        _banController.forward();
        _setError("You are banned from this app.");
        return;
      }

      _completeLogin();
    } on BanAuthException catch (e) {
      setState(() => _isBanned = true);
      _banController.forward();
      _setError(e.message);
    } on AuthException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError("An unknown error occurred.");
    }
  }

  Future<void> _doSignup() async {
    try {
      final response = await auth.signUp(email: _emailController.text.trim(), password: _passwordController.text);
      if (response.user == null) {
        _setError("Unable to create account.");
        return;
      }
      _user = await userRepository.createCurrentUser(username: currentAuthUsername());
      _completeLogin();
    } on AuthException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError("An unknown error occurred.");
    }
  }

  Future<void> _doRecover() async {
    try {
      await auth.resetPasswordForEmail(
        _emailController.text.trim(),
        redirectTo: kIsWeb
            ? 'https://riddleneon.github.io/scroller_test/#/reset-password' // Web doesn't support custom schemes, use localhost with a path instead
            : 'https://riddleneon.github.io/scroller_test/#/reset-password',
      );
      _setSuccess("Password reset email sent! Check your inbox.");
    } on AuthException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError("An error occurred.");
    }
  }

  void _completeLogin() {
    assert(_user != null);
    onUserLogin(_user!)
        .then((_) {
          if (mounted) routerConfig.push('/feed');
        })
        .catchError((e, st) {
          debugPrint('Post-login error: $e\n$st');
        });
  }

  Future<void> _openBanAppeal() async {
    if (_signedInUserId == null) return;
    await showDialog(
      context: context,
      builder: (_) => BanAppealScreen(
        userId: _signedInUserId!,
        onAppealSuccess: () {
          setState(() => _isBanned = false);
          _banController.reverse();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Appeal successful! You are now unbanned.")));
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: cs.brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: cs.surface,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: SlideMorphTransitions.build(
                _entryFade,
                SlideTransition(
                  position: _entrySlide,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: AnimatedBuilder(
                      animation: _shakeAnim,
                      builder: (context, child) => Transform.translate(offset: Offset(_shakeAnim.value, 0), child: child),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [_buildHeader(cs, theme), const SizedBox(height: 40), _buildCard(cs, theme)],
                      ),
                    ),
                  ),
                ),
                beginOffset: const Offset(0, 0.06),
                beginScale: 0.985,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs, ThemeData theme) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: cs.primaryContainer),
          child: Icon(Icons.lightbulb, color: cs.onPrimaryContainer, size: 28),
        ),
        const SizedBox(height: 16),
        Text(
          'wurp',
          style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.5, color: cs.onSurface),
        ),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) => _buildHorizontalClipTransition(child: child, animation: animation),
          child: Text(
            _modeSubtitle,
            key: _subtitleKey(),
            style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  String get _modeSubtitle => switch (_mode) {
    _AuthMode.login => 'Welcome back',
    _AuthMode.signup => 'Create your account',
    _AuthMode.recover => 'Reset your password',
  };

  Widget _buildCard(ColorScheme cs, ThemeData theme) {
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              reverseDuration: const Duration(milliseconds: 450),
              transitionBuilder: (child, animation) => _buildHorizontalClipTransition(child: child, animation: animation),
              layoutBuilder: (currentChild, previousChildren) => Stack(clipBehavior: Clip.hardEdge, children: [...previousChildren, ?currentChild]),
              child: _buildModeFormContent(cs, theme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeFormContent(ColorScheme cs, ThemeData theme) {
    return KeyedSubtree(
      key: _modeContentKey(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_mode != _AuthMode.recover) _buildModeTabs(cs, theme),
          if (_mode != _AuthMode.recover) const SizedBox(height: 24),
          _buildBanBanner(cs, theme),
          _buildEmailField(cs, theme),
          if (_mode != _AuthMode.recover) ...[const SizedBox(height: 12), _buildPasswordField(cs, theme)],
          if (_mode == _AuthMode.signup) ...[const SizedBox(height: 12), _buildConfirmPasswordField(cs, theme)],
          if (_mode == _AuthMode.login) ...[const SizedBox(height: 8), _buildForgotLink(cs)],
          const SizedBox(height: 24),
          AnimatedSize(duration: const Duration(milliseconds: 250), curve: Curves.easeOut, child: _buildFeedback(cs, theme)),
          _buildSubmitButton(cs, theme),
          if (_mode == _AuthMode.recover) ...[const SizedBox(height: 16), _buildBackToLogin(cs)],
        ],
      ),
    );
  }

  Widget _buildHorizontalClipTransition({required Widget child, required Animation<double> animation}) {
    final isCurrent = child.key == _modeContentKey() || child.key == _subtitleKey();
    final enteringOffset = Offset(_modeDirection.toDouble(), 0);
    final exitingOffset = Offset(-_modeDirection.toDouble(), 0);
    // AnimatedSwitcher runs the outgoing child's animation in reverse (1→0).
    // Tween evaluates as lerp(begin, end, t), so for the outgoing child we need
    // begin=exitingOffset and end=Offset.zero so that at t=1.0 (start of exit)
    // the position is Offset.zero (center) and at t=0.0 (end of exit) it's
    // exitingOffset (off-screen). The incoming child's animation runs forward
    // (0→1) so begin=enteringOffset, end=Offset.zero works correctly.
    final tween = Tween<Offset>(begin: isCurrent ? enteringOffset : exitingOffset, end: Offset.zero);
    return ClipRect(
      child: SlideTransition(
        position: tween.animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic)),
        child: child,
      ),
    );
  }

  ValueKey<String> _modeContentKey() => ValueKey('mode-${_mode.name}-$_modeVersion');

  ValueKey<String> _subtitleKey() => ValueKey('subtitle-${_mode.name}-$_modeVersion');

  Widget _buildModeTabs(ColorScheme cs, ThemeData theme) {
    return Container(
      height: 42,
      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: _mode == _AuthMode.signup ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: cs.surface,
                  border: Border.all(color: cs.outlineVariant),
                ),
              ),
            ),
          ),
          Row(children: [_modeTab('Sign in', _AuthMode.login, cs, theme), _modeTab('Sign up', _AuthMode.signup, cs, theme)]),
        ],
      ),
    );
  }

  Widget _modeTab(String label, _AuthMode mode, ColorScheme cs, ThemeData theme) {
    final active = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchMode(mode),
        child: Container(
          color: Colors.transparent, //needed to make the entire area tappable
          margin: const EdgeInsets.all(3),
          alignment: Alignment.center,
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: (theme.textTheme.labelLarge ?? const TextStyle()).copyWith(
              color: active ? cs.primary : cs.onSurfaceVariant,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }

  Widget _buildBanBanner(ColorScheme cs, ThemeData theme) {
    return ClipRect(
      child: SlideTransition(
        position: _banSlide,
        child: SlideMorphTransitions.build(
          _banFade,
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            child: _isBanned
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: cs.errorContainer,
                        border: Border.all(color: cs.error.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.block_rounded, color: cs.onErrorContainer, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'Account Suspended',
                                style: theme.textTheme.labelLarge?.copyWith(color: cs.onErrorContainer, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your account has been suspended. You can submit an appeal below.',
                            style: theme.textTheme.bodySmall?.copyWith(color: cs.onErrorContainer.withValues(alpha: 0.8)),
                          ),
                          const SizedBox(height: 10),
                          FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              backgroundColor: cs.error.withValues(alpha: 0.15),
                              foregroundColor: cs.onErrorContainer,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                            ),
                            onPressed: _openBanAppeal,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.gavel_rounded, size: 16),
                                SizedBox(width: 6),
                                Text('Appeal Ban', style: TextStyle(fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          beginOffset: const Offset(0, -0.08),
          beginScale: 0.97,
        ),
      ),
    );
  }

  Widget _buildEmailField(ColorScheme cs, ThemeData theme) {
    return _AuthField(
      controller: _emailController,
      label: 'Email',
      icon: Icons.mail_outline_rounded,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      cs: cs,
      theme: theme,
      validator: (v) {
        if (v == null || v.isEmpty) return 'Please enter your email';
        if (!v.contains('@')) return 'Enter a valid email';
        return null;
      },
    );
  }

  Widget _buildPasswordField(ColorScheme cs, ThemeData theme) {
    return _AuthField(
      controller: _passwordController,
      label: 'Password',
      icon: Icons.lock_outline_rounded,
      obscureText: _obscurePassword,
      cs: cs,
      theme: theme,
      autofillHints: _mode == _AuthMode.login ? const [AutofillHints.password] : const [AutofillHints.newPassword],
      suffixIcon: IconButton(
        icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
        color: cs.onSurfaceVariant,
        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Please enter a password';
        if (_mode == _AuthMode.signup && v.length < 8) {
          return 'Password must be at least 8 characters';
        }
        return null;
      },
    );
  }

  Widget _buildConfirmPasswordField(ColorScheme cs, ThemeData theme) {
    return _AuthField(
      controller: _confirmPasswordController,
      label: 'Confirm Password',
      icon: Icons.lock_outline_rounded,
      obscureText: _obscureConfirm,
      cs: cs,
      theme: theme,
      autofillHints: const [AutofillHints.newPassword],
      suffixIcon: IconButton(
        icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
        color: cs.onSurfaceVariant,
        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
      ),
      validator: (v) {
        if (v != _passwordController.text) {
          return 'Passwords do not match';
        }
        return null;
      },
    );
  }

  Widget _buildForgotLink(ColorScheme cs) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: () => _switchMode(_AuthMode.recover),
        child: Text(
          'Forgot password?',
          style: TextStyle(color: cs.primary, fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildFeedback(ColorScheme cs, ThemeData theme) {
    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _FeedbackBanner(message: _errorMessage!, isError: true, cs: cs, theme: theme),
      );
    }
    if (_successMessage != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _FeedbackBanner(message: _successMessage!, isError: false, cs: cs, theme: theme),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildSubmitButton(ColorScheme cs, ThemeData theme) {
    final label = switch (_mode) {
      _AuthMode.login => 'Sign in',
      _AuthMode.signup => 'Create Account',
      _AuthMode.recover => 'Send Reset Email',
    };

    return SizedBox(
      height: 50,
      child: FilledButton(
        style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        onPressed: _isLoading ? null : _submit,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, animation) => SlideMorphTransitions.switcher(child, animation, beginOffset: const Offset(0, 0.14), beginScale: 0.9),
          child: _isLoading
              ? SizedBox(
                  key: const ValueKey('loader'),
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.onPrimary),
                )
              : Text(
                  label,
                  key: ValueKey(label),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
        ),
      ),
    );
  }

  Widget _buildBackToLogin(ColorScheme cs) {
    return Center(
      child: TextButton(
        onPressed: () => _switchMode(_AuthMode.login),
        child: RichText(
          text: TextSpan(
            text: 'Remembered it?  ',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
            children: [
              TextSpan(
                text: 'Sign in',
                style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Reusable field
// ─────────────────────────────────────────────

class _AuthField extends StatefulWidget {
  const _AuthField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.cs,
    required this.theme,
    this.obscureText = false,
    this.keyboardType,
    this.autofillHints,
    this.suffixIcon,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final ColorScheme cs;
  final ThemeData theme;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  @override
  State<_AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<_AuthField> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;

    return TextFormField(
      controller: widget.controller,
      focusNode: _focus,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      autofillHints: widget.autofillHints,
      validator: widget.validator,
      style: widget.theme.textTheme.bodyLarge?.copyWith(color: cs.onSurface),
      cursorColor: cs.primary,
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: TextStyle(color: _focused ? cs.primary : cs.onSurfaceVariant),
        prefixIcon: Icon(widget.icon, color: _focused ? cs.primary : cs.onSurfaceVariant, size: 20),
        suffixIcon: widget.suffixIcon,
        filled: true,
        fillColor: _focused ? cs.primaryContainer.withValues(alpha: 0.25) : cs.surfaceContainerHighest,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.error, width: 1.5),
        ),
        errorStyle: TextStyle(color: cs.error, fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Feedback banner
// ─────────────────────────────────────────────

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({required this.message, required this.isError, required this.cs, required this.theme});

  final String message;
  final bool isError;
  final ColorScheme cs;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final bgColor = isError ? cs.errorContainer : cs.secondaryContainer;
    final fgColor = isError ? cs.onErrorContainer : cs.onSecondaryContainer;
    final icon = isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: bgColor),
      child: Row(
        children: [
          Icon(icon, color: fgColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(color: fgColor, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = false;
  String? _error;
  String? _success;

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  final supabase = Supabase.instance.client;

  late final AnimationController _entryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();

  late final Animation<double> _fade = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.06),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic));

  late final AnimationController _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  late final Animation<double> _shake = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
    TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
    TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 2),
    TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
    TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 1),
  ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));

  @override
  void dispose() {
    _entryController.dispose();
    _shakeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _setError(String msg) {
    setState(() {
      _error = msg;
      _success = null;
    });
    _shakeController.forward(from: 0);
  }

  void _setSuccess(String msg) {
    setState(() {
      _success = msg;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    try {
      await supabase.auth.updateUser(UserAttributes(password: _passwordController.text));

      _setSuccess("Password updated successfully!");

      await Future.delayed(const Duration(milliseconds: 800));

      if (mounted) context.go('/login');
    } on AuthException catch (e) {
      if (e.message == "Auth session missing!") {
        _setError(
          "Auth session is missing! Please use this link on the same device and browser where you requested the password reset. Redirecting to login. you can request the code again from there.",
        );
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) context.go('/login');
        });
        return;
      }

      _setError(e.message);
    } catch (_) {
      _setError("Something went wrong.");
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: cs.brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: cs.surface,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: SlideMorphTransitions.build(
                _fade,
                SlideTransition(
                  position: _slide,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: AnimatedBuilder(
                      animation: _shake,
                      builder: (context, child) => Transform.translate(offset: Offset(_shake.value, 0), child: child),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [_buildHeader(cs, theme), const SizedBox(height: 40), _buildCard(cs, theme)],
                      ),
                    ),
                  ),
                ),
                beginOffset: const Offset(0, 0.06),
                beginScale: 0.985,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs, ThemeData theme) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: cs.primaryContainer),
          child: Icon(Icons.lock_reset_rounded, color: cs.onPrimaryContainer, size: 28),
        ),
        const SizedBox(height: 16),
        Text('Reset Password', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.2)),
        const SizedBox(height: 6),
        Text('Enter a new password for your account', style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildCard(ColorScheme cs, ThemeData theme) {
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPasswordField(cs, theme),
              const SizedBox(height: 12),
              _buildConfirmField(cs, theme),
              const SizedBox(height: 24),
              if (_error != null) _FeedbackBanner(message: _error!, isError: true, cs: cs, theme: theme),
              if (_success != null) _FeedbackBanner(message: _success!, isError: false, cs: cs, theme: theme),
              const SizedBox(height: 16),
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text("Update Password", style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField(ColorScheme cs, ThemeData theme) {
    return _AuthField(
      controller: _passwordController,
      label: 'New Password',
      icon: Icons.lock_outline_rounded,
      obscureText: _obscurePassword,
      cs: cs,
      theme: theme,
      suffixIcon: IconButton(
        icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
      ),
      validator: (v) {
        if (v == null || v.length < 8) {
          return 'Min. 8 characters required';
        }
        return null;
      },
    );
  }

  Widget _buildConfirmField(ColorScheme cs, ThemeData theme) {
    return _AuthField(
      controller: _confirmController,
      label: 'Confirm Password',
      icon: Icons.lock_outline_rounded,
      obscureText: _obscureConfirm,
      cs: cs,
      theme: theme,
      suffixIcon: IconButton(
        icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
      ),
      validator: (v) {
        if (v != _passwordController.text) {
          return 'Passwords do not match';
        }
        return null;
      },
    );
  }
}
