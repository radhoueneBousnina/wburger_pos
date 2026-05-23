// ignore_for_file: invalid_use_of_protected_member

part of '../screens/login_screen.dart';

extension _LoginForm on _LoginScreenState {
  Widget _buildLoginScreen(BuildContext context) {
    final layout = context.posLayout;

    return Scaffold(
      backgroundColor: AppColors.blue,
      body: LayoutBuilder(
        builder: (context, constraints) => layout.showWideLoginLayout
            ? Row(
                children: [
                  const Expanded(child: _BrandingPanel()),
                  Container(
                    width: constraints.maxWidth >= 1400 ? 520 : 470,
                    color: AppColors.white,
                    child: _buildLoginForm(),
                  ),
                ],
              )
            : Container(
                color: AppColors.white,
                child: Column(
                  children: [
                    const Expanded(flex: 3, child: _BrandingPanel()),
                    Expanded(
                      flex: 4,
                      child: Container(
                        width: double.infinity,
                        color: AppColors.white,
                        child: _buildLoginForm(),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildLoginForm() {
    final layout = context.posLayout;

    return LayoutBuilder(
      builder: (context, constraints) {
        final shortViewport = constraints.maxHeight < 520;
        final content = Padding(
          padding: EdgeInsets.symmetric(
            horizontal: layout.isCompact ? 28 : 52,
            vertical: layout.isCompact ? 24 : 40,
          ),
          child: Column(
            mainAxisSize: shortViewport ? MainAxisSize.min : MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.yellow,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome back 👋',
                style:
                    AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                'Sign In',
                style: AppTextStyles.display.copyWith(
                  color: AppColors.blue,
                  fontSize: layout.isCompact ? 34 : 40,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Enter your credentials to access the POS terminal.',
                style:
                    AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
              if (shortViewport) const SizedBox(height: 24) else const Spacer(),
              Text('Username', style: AppTextStyles.label),
              const SizedBox(height: 8),
              TextField(
                controller: _usernameCtrl,
                autofocus: true,
                textInputAction: TextInputAction.next,
                style: AppTextStyles.title,
                decoration: InputDecoration(
                  hintText: 'Enter your username',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Icon(
                      Icons.person_rounded,
                      color: AppColors.blue,
                      size: 22,
                    ),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: AppColors.border, width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: AppColors.border, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: AppColors.blue, width: 2),
                  ),
                ),
                onSubmitted: (_) => FocusScope.of(context).nextFocus(),
              ),
              const SizedBox(height: 20),
              Text('Password', style: AppTextStyles.label),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                style: AppTextStyles.title,
                decoration: InputDecoration(
                  hintText: '••••••••',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Icon(
                      Icons.lock_rounded,
                      color: AppColors.blue,
                      size: 22,
                    ),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: AppColors.textSecondary,
                      size: 24,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: AppColors.border, width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: AppColors.border, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: AppColors.blue, width: 2),
                  ),
                ),
                onSubmitted: (_) => _handleLogin(),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.error,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: AppTextStyles.bodySm
                              .copyWith(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: layout.touchTarget + 4,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.yellow,
                    foregroundColor: AppColors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                    textStyle: AppTextStyles.buttonLg.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.blue,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Sign In'),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ),
                ),
              ),
              if (shortViewport) const SizedBox(height: 20) else const Spacer(),
              Center(
                child: Text(
                  '© ${DateTime.now().year} W Burger – POS Terminal v1.0',
                  style: AppTextStyles.labelSm
                      .copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        );

        if (!shortViewport) return content;
        return SingleChildScrollView(child: content);
      },
    );
  }
}
