import 'package:flutter/material.dart';
import 'package:icebot_kiosk/config/app_config.dart';
import 'package:icebot_kiosk/features/kiosk/presentation/widgets/kiosk_panels.dart';
import 'package:icebot_kiosk/features/setup/data/models/auth_models.dart';
import 'package:icebot_kiosk/features/setup/presentation/state/auth_scope.dart';

class ManagerLoginScreen extends StatefulWidget {
  const ManagerLoginScreen({super.key});

  @override
  State<ManagerLoginScreen> createState() => _ManagerLoginScreenState();
}

class _ManagerLoginScreenState extends State<ManagerLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final success = await AuthScope.of(context).login(
      emailOrUsername: _accountController.text,
      password: _passwordController.text,
    );
    if (success) {
      _passwordController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    if (auth.requiresKioskSelection) {
      return const KioskSelectionScreen();
    }
    final configurationError = AppConfig.runtimeConfigurationError;

    return Scaffold(
      body: SafeArea(
        child: KioskBackdrop(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 760;
                    final intro = const _SetupIntroduction();
                    final form = _LoginCard(
                      formKey: _formKey,
                      accountController: _accountController,
                      passwordController: _passwordController,
                      passwordFocus: _passwordFocus,
                      obscurePassword: _obscurePassword,
                      onTogglePassword: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      onSubmit: _submit,
                      isSubmitting: auth.isSubmitting,
                      errorMessage: configurationError ?? auth.error?.message,
                    );

                    return compact
                        ? Column(
                            children: [intro, const SizedBox(height: 24), form],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(child: intro),
                              const SizedBox(width: 52),
                              Expanded(child: form),
                            ],
                          );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SetupIntroduction extends StatelessWidget {
  const _SetupIntroduction();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(
            Icons.icecream_rounded,
            color: Colors.white,
            size: 42,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Thiết lập IceBot Kiosk',
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SizedBox(height: 14),
        Text(
          'Đăng nhập bằng tài khoản Manager để liên kết máy với đúng điểm bán. Thông tin kiosk sẽ được lưu an toàn trên thiết bị này.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.55),
        ),
        const SizedBox(height: 24),
        const _SetupBenefit(
          icon: Icons.storefront_outlined,
          text: 'Chọn kiosk phù hợp nếu điểm bán có nhiều máy',
        ),
        const SizedBox(height: 12),
        const _SetupBenefit(
          icon: Icons.lock_outline_rounded,
          text: 'Phiên đăng nhập được lưu bằng bộ nhớ bảo mật',
        ),
      ],
    );
  }
}

class _SetupBenefit extends StatelessWidget {
  const _SetupBenefit({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ],
    );
  }
}

class KioskSelectionScreen extends StatefulWidget {
  const KioskSelectionScreen({super.key});

  @override
  State<KioskSelectionScreen> createState() => _KioskSelectionScreenState();
}

class _KioskSelectionScreenState extends State<KioskSelectionScreen> {
  String? _selectedKioskId;

  Future<void> _confirmSelection() async {
    final kioskId = _selectedKioskId;
    if (kioskId == null) {
      return;
    }
    await AuthScope.of(context).selectKiosk(kioskId);
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final kiosks = auth.availableKiosks;
    if (!kiosks.any((kiosk) => kiosk.id == _selectedKioskId)) {
      _selectedKioskId = null;
    }

    return Scaffold(
      body: SafeArea(
        child: KioskBackdrop(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  elevation: 4,
                  shadowColor: Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(28),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.point_of_sale_rounded, size: 42),
                        const SizedBox(height: 18),
                        Text(
                          'Chọn kiosk để thiết lập',
                          style: Theme.of(context).textTheme.headlineMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Điểm bán này có ${kiosks.length} kiosk. Hãy chọn đúng máy vật lý đang được cài đặt.',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 26),
                        ...kiosks.indexed.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _KioskChoiceTile(
                              kiosk: entry.$2,
                              fallbackLabel: 'Kiosk ${entry.$1 + 1}',
                              isSelected: entry.$2.id == _selectedKioskId,
                              onTap: auth.isSubmitting
                                  ? null
                                  : () => setState(
                                      () => _selectedKioskId = entry.$2.id,
                                    ),
                            ),
                          ),
                        ),
                        if (auth.error != null) ...[
                          const SizedBox(height: 4),
                          _SetupErrorMessage(message: auth.error!.message),
                        ],
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 58,
                          child: FilledButton.icon(
                            onPressed:
                                _selectedKioskId == null || auth.isSubmitting
                                ? null
                                : _confirmSelection,
                            icon: auth.isSubmitting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Icon(
                                    Icons.check_circle_outline_rounded,
                                  ),
                            label: Text(
                              auth.isSubmitting
                                  ? 'Đang lưu thiết lập...'
                                  : 'Xác nhận kiosk',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: auth.isSubmitting
                              ? null
                              : auth.cancelKioskSelection,
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('Đăng nhập bằng tài khoản khác'),
                        ),
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

class _KioskChoiceTile extends StatelessWidget {
  const _KioskChoiceTile({
    required this.kiosk,
    required this.fallbackLabel,
    required this.isSelected,
    required this.onTap,
  });

  final ManagedKiosk kiosk;
  final String fallbackLabel;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final title = kiosk.name?.trim().isNotEmpty == true
        ? kiosk.name!
        : fallbackLabel;
    final code = kiosk.code?.trim().isNotEmpty == true
        ? kiosk.code!
        : 'Chưa có mã kiosk';

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$title, $code',
      child: Material(
        color: isSelected
            ? colors.primaryContainer
            : colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: isSelected ? colors.primary : colors.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? colors.primary : colors.onSurfaceVariant,
                  size: 28,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 3),
                      Text(code, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                if (isSelected)
                  Text(
                    'Đã chọn',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w800,
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

class _SetupErrorMessage extends StatelessWidget {
  const _SetupErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: colors.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.formKey,
    required this.accountController,
    required this.passwordController,
    required this.passwordFocus,
    required this.obscurePassword,
    required this.onTogglePassword,
    required this.onSubmit,
    required this.isSubmitting,
    this.errorMessage,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController accountController;
  final TextEditingController passwordController;
  final FocusNode passwordFocus;
  final bool obscurePassword;
  final VoidCallback onTogglePassword;
  final Future<void> Function() onSubmit;
  final bool isSubmitting;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Đăng nhập Manager',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Chỉ cần thực hiện một lần khi cài đặt máy.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 28),
              TextFormField(
                controller: accountController,
                enabled: !isSubmitting,
                autofocus: true,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => passwordFocus.requestFocus(),
                decoration: const InputDecoration(
                  labelText: 'Email hoặc tên đăng nhập',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Vui lòng nhập tài khoản Manager.'
                    : null,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: passwordController,
                focusNode: passwordFocus,
                enabled: !isSubmitting,
                obscureText: obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => onSubmit(),
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: obscurePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                    onPressed: onTogglePassword,
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Vui lòng nhập mật khẩu.'
                    : null,
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 18),
                _SetupErrorMessage(message: errorMessage!),
              ],
              const SizedBox(height: 26),
              SizedBox(
                height: 58,
                child: FilledButton.icon(
                  onPressed: isSubmitting ? null : onSubmit,
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Icon(Icons.login_rounded),
                  label: Text(
                    isSubmitting
                        ? 'Đang thiết lập...'
                        : 'Đăng nhập và thiết lập',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
