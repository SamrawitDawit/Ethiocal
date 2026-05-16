import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../services/auth_service.dart';
import '../services/launch_context.dart';
import '../services/profile_service.dart';
import '../widgets/app_background.dart';
import '../widgets/app_logo.dart';

class AuthCallbackPage extends StatefulWidget {
  const AuthCallbackPage({super.key});

  @override
  State<AuthCallbackPage> createState() => _AuthCallbackPageState();
}

class _AuthCallbackPageState extends State<AuthCallbackPage> {
  String _message = 'Finishing sign-in...';
  bool _hasError = false;
  bool _showLoginAction = false;

  @override
  void initState() {
    super.initState();
    _handleCallback();
  }

  bool _hasCallbackParameters(Uri uri) {
    return uri.queryParameters.isNotEmpty || uri.fragment.isNotEmpty;
  }

  Map<String, String> _fragmentParameters(Uri uri) {
    if (uri.fragment.isEmpty) {
      return const <String, String>{};
    }

    return Uri.splitQueryString(uri.fragment);
  }

  Future<void> _handleCallback() async {
    final currentUri = Uri.base;
    final capturedUri = resolveCapturedLaunchUri();
    final callbackUri = _hasCallbackParameters(currentUri)
        ? currentUri
        : (_hasCallbackParameters(capturedUri) ? capturedUri : currentUri);
    clearCapturedLaunchUri();

    final queryParameters = callbackUri.queryParameters;
    final fragmentParameters = _fragmentParameters(callbackUri);
    final hasCallbackParameters = _hasCallbackParameters(callbackUri);

    final errorDescription = queryParameters['error_description'] ??
        fragmentParameters['error_description'];
    if (errorDescription != null && errorDescription.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _message = errorDescription;
        _showLoginAction = true;
      });
      return;
    }

    final accessToken =
        fragmentParameters['access_token'] ?? queryParameters['access_token'];
    final refreshToken = fragmentParameters['refresh_token'] ??
        queryParameters['refresh_token'] ??
        '';
    final flowType =
        fragmentParameters['type'] ?? queryParameters['type'] ?? '';
    final tokenHash =
        queryParameters['token_hash'] ?? fragmentParameters['token_hash'];

    if ((accessToken == null || accessToken.isEmpty) &&
        tokenHash != null &&
        tokenHash.isNotEmpty &&
        flowType.isNotEmpty) {
      try {
        final authResponse = await AuthService.exchangeCallback(
          tokenHash: tokenHash,
          callbackType: flowType,
        );
        if (!mounted) return;
        if (flowType == 'recovery') {
          Navigator.pushNamedAndRemoveUntil(
            context,
            RouteNames.resetPassword,
            (route) => false,
          );
          return;
        }

        final hasProfile = authResponse.user.hasCompletedProfile;
        Navigator.pushNamedAndRemoveUntil(
          context,
          hasProfile ? RouteNames.mainNavigation : RouteNames.profileSetupStep1,
          (route) => false,
        );
        return;
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _hasError = true;
          _message = 'Authentication failed: $e';
          _showLoginAction = true;
        });
        return;
      }
    }

    if (accessToken == null || accessToken.isEmpty) {
      if (!mounted) return;
      setState(() {
        _hasError = hasCallbackParameters;
        _showLoginAction = true;
        _message = hasCallbackParameters
            ? 'This link is missing a valid session. Request a new email and try again.'
            : 'Email verification completed. Log in to continue setting up your profile.';
      });
      return;
    }

    try {
      await AuthService.saveTokens(accessToken, refreshToken);

      if (!mounted) return;
      if (flowType == 'recovery') {
        Navigator.pushNamedAndRemoveUntil(
          context,
          RouteNames.resetPassword,
          (route) => false,
        );
        return;
      }

      final hasProfile = await ProfileService.hasProfile();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        hasProfile ? RouteNames.mainNavigation : RouteNames.profileSetupStep1,
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _message = 'Authentication failed: $e';
        _showLoginAction = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLogo(imageHeight: 44, fontSize: 24),
                  const SizedBox(height: 24),
                  if (!_hasError && !_showLoginAction)
                    const CircularProgressIndicator(),
                  if (_hasError)
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                      size: 40,
                    ),
                  if (!_hasError && _showLoginAction)
                    const Icon(
                      Icons.check_circle_outline,
                      color: AppColors.primaryGreen,
                      size: 40,
                    ),
                  const SizedBox(height: 16),
                  Text(
                    _message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (_showLoginAction) ...[
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          RouteNames.login,
                          (route) => false,
                        );
                      },
                      child: const Text('Go to login'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
