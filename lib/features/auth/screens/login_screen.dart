import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/pos_layout.dart';
import '../../../data/providers/app_providers.dart';

part '../widgets/login_branding_panel.dart';
part '../widgets/login_form.dart';
part '../widgets/login_screen_actions.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _usernameFieldKey = GlobalKey();
  final _passwordFieldKey = GlobalKey();
  final _errorMessageKey = GlobalKey();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  String? _usernameError;
  String? _passwordError;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _buildLoginScreen(context);
}
