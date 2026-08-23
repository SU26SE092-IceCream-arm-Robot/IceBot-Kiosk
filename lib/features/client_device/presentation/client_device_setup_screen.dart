import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:icebot_kiosk/config/routes/app_router.dart';
import 'package:icebot_kiosk/core/di/injection_container.dart';
import 'package:icebot_kiosk/core/error/api_exception.dart';
import 'package:icebot_kiosk/features/client_device/data/client_device_setup_service.dart';
import 'package:icebot_kiosk/features/client_device/data/client_device_session_manager.dart';

class ClientDeviceSetupScreen extends StatefulWidget {
  const ClientDeviceSetupScreen({super.key});

  @override
  State<ClientDeviceSetupScreen> createState() =>
      _ClientDeviceSetupScreenState();
}

class _ClientDeviceSetupScreenState extends State<ClientDeviceSetupScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _displayName = TextEditingController(text: 'Self-order tablet');
  ManagerSetupSession? _session;
  SetupKiosk? _selectedKiosk;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _displayName.dispose();
    super.dispose();
  }

  Future<bool> _tryExitSetup() async {
    final session = _session;
    if (_busy) return false;
    if (session == null) return true;

    setState(() {
      _busy = true;
      _error = null;
    });
    final revoked = await sl<ClientDeviceSetupService>().revoke(session);
    if (!mounted) return revoked;
    if (revoked) {
      setState(() {
        _session = null;
        _selectedKiosk = null;
        _busy = false;
      });
      return true;
    }

    setState(() {
      _busy = false;
      _error = 'Khong the thu hoi phien thiet lap. Thu lai truoc khi thoat.';
    });
    return false;
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await sl<ClientDeviceSetupService>().signIn(
        _email.text,
        _password.text,
      );
      if (!mounted) return;
      setState(() {
        _session = session;
        _selectedKiosk = session.kiosks.length == 1
            ? session.kiosks.single
            : null;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Object {
      if (mounted) {
        setState(() => _error = 'Khong the xac thuc tai khoan thiet lap.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _provision() async {
    final session = _session;
    final kiosk = _selectedKiosk;
    if (session == null || kiosk == null || _displayName.text.trim().isEmpty) {
      setState(() {
        _error = 'Chon kiosk va nhap ten nhan dien tablet.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final revokeSucceeded = await sl<ClientDeviceSetupService>().provision(
        session,
        kiosk,
        displayName: _displayName.text,
      );
      final runtimeIdentity = await sl<ClientDeviceSessionManager>()
          .ensureSession(force: true);
      if (runtimeIdentity == null) {
        throw const ApiException(
          type: ApiErrorType.unknown,
          message: 'Tablet da duoc lien ket nhung khong the tao phien runtime.',
        );
      }
      if (!mounted) return;
      _session = null;
      if (!revokeSucceeded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tablet da lien ket, nhung phien thiet lap chua thu hoi duoc.',
            ),
          ),
        );
      }
      context.go(AppRouter.initial);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _session = null;
          _selectedKiosk = null;
          _error = '${error.message} Dang nhap lai de thu lai.';
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _session = null;
          _selectedKiosk = null;
          _error =
              'Khong the hoan tat thiet lap tablet. Dang nhap lai de thu lai.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return PopScope(
      canPop: !_busy && session == null,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _session == null) return;
        if (await _tryExitSetup()) _completeExit();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Thiet lap tablet')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: session == null ? _loginForm() : _provisionForm(session),
            ),
          ),
        ),
      ),
    );
  }

  void _completeExit() {
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Widget _loginForm() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('Dang nhap quan tri de lien ket tablet voi kiosk.'),
      const SizedBox(height: 16),
      TextField(
        controller: _email,
        enabled: !_busy,
        decoration: const InputDecoration(
          labelText: 'Email hoac ten dang nhap',
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _password,
        enabled: !_busy,
        obscureText: true,
        decoration: const InputDecoration(labelText: 'Mat khau'),
      ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(_error!, style: const TextStyle(color: Colors.red)),
      ],
      const SizedBox(height: 20),
      FilledButton(
        onPressed: _busy ? null : _signIn,
        child: Text(_busy ? 'Dang xac thuc...' : 'Tiep tuc'),
      ),
    ],
  );

  Widget _provisionForm(ManagerSetupSession session) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('Chon kiosk trong pham vi duoc cap quyen.'),
      const SizedBox(height: 16),
      DropdownButtonFormField<SetupKiosk>(
        initialValue: _selectedKiosk,
        items: session.kiosks
            .map(
              (kiosk) => DropdownMenuItem(
                value: kiosk,
                child: Text('${kiosk.name} (${kiosk.code})'),
              ),
            )
            .toList(),
        onChanged: _busy
            ? null
            : (value) => setState(() => _selectedKiosk = value),
        decoration: const InputDecoration(labelText: 'Kiosk'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _displayName,
        enabled: !_busy,
        decoration: const InputDecoration(labelText: 'Ten tablet'),
      ),
      if (session.kiosks.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
            'Tai khoan nay khong co kiosk nao duoc cap quyen.',
            style: TextStyle(color: Colors.red),
          ),
        ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(_error!, style: const TextStyle(color: Colors.red)),
      ],
      const SizedBox(height: 20),
      FilledButton(
        onPressed: _busy || session.kiosks.isEmpty ? null : _provision,
        child: Text(_busy ? 'Dang lien ket...' : 'Lien ket tablet'),
      ),
    ],
  );
}
