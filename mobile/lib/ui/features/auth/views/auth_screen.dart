import 'package:flutter/material.dart';
import '../../../../data/models/auth_models.dart';
import '../../../core/app_theme.dart';
import '../view_models/auth_view_model.dart';

class AuthScreen extends StatefulWidget {
  final AuthViewModel viewModel;

  const AuthScreen({
    super.key,
    required this.viewModel,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  bool _isRegisterMode = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isRegisterMode) {
      await widget.viewModel.register(
        username: _usernameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
    } else {
      await widget.viewModel.login(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (BuildContext context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('APEXMETRIX RANKED'),
            actions: <Widget>[
              IconButton(
                tooltip: 'Configurar URL de API',
                icon: const Icon(
                  Icons.dns_outlined,
                  color: ApexTheme.cyanElectric,
                ),
                onPressed: () => _openServerConfigDialog(context),
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: ApexTheme.voltAccent
                                        .withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: ApexTheme.voltAccent,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.bolt_rounded,
                                    color: ApexTheme.voltAccent,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        _isRegisterMode
                                            ? 'CREAR CUENTA DE ATLETA'
                                            : 'INICIAR SESIÓN',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Endpoint actual: ${widget.viewModel.apiBaseUrl}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: ApexTheme.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _buildServerHealthBanner(context),
                            const SizedBox(height: 16),
                            if (widget.viewModel.errorMessage != null) ...<Widget>[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: ApexTheme.deloadCrimson
                                      .withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: ApexTheme.deloadCrimson,
                                  ),
                                ),
                                child: Text(
                                  widget.viewModel.errorMessage!,
                                  style: const TextStyle(
                                    color: ApexTheme.deloadCrimson,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (_isRegisterMode) ...<Widget>[
                              TextFormField(
                                controller: _usernameCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Username (ej. cesar_lifts)',
                                  prefixIcon: const Icon(
                                    Icons.alternate_email_rounded,
                                  ),
                                  filled: true,
                                  fillColor: ApexTheme.obsidianBg,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                validator: (String? v) {
                                  final String val = (v ?? '').trim();
                                  if (val.length < 3) {
                                    return 'Mínimo 3 caracteres alfanuméricos';
                                  }
                                  if (!RegExp(r'^[a-zA-Z0-9_]+$')
                                      .hasMatch(val)) {
                                    return 'Usa solo letras, números o guion bajo (_)';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                            ],
                            TextFormField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'Correo electrónico',
                                prefixIcon: const Icon(Icons.email_outlined),
                                filled: true,
                                fillColor: ApexTheme.obsidianBg,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (String? v) {
                                final String val = (v ?? '').trim();
                                if (!val.contains('@') || !val.contains('.')) {
                                  return 'Ingresa un correo electrónico válido';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passwordCtrl,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Contraseña (mín. 8 caracteres)',
                                prefixIcon:
                                    const Icon(Icons.lock_outline_rounded),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                filled: true,
                                fillColor: ApexTheme.obsidianBg,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (String? v) {
                                if ((v ?? '').length < 8) {
                                  return 'La contraseña debe tener al menos 8 caracteres';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 22),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: ApexTheme.voltAccent,
                                foregroundColor: Colors.black,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                              onPressed:
                                  widget.viewModel.isSubmitting ? null : _submit,
                              icon: widget.viewModel.isSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : Icon(
                                      _isRegisterMode
                                          ? Icons.person_add_alt_1_rounded
                                          : Icons.login_rounded,
                                    ),
                              label: Text(
                                _isRegisterMode
                                    ? 'REGISTRAR Y CONFIGURAR PERFIL'
                                    : 'ENTRAR A LA ARENA',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: widget.viewModel.isSubmitting
                                  ? null
                                  : () {
                                      setState(() {
                                        _isRegisterMode = !_isRegisterMode;
                                      });
                                    },
                              child: Text(
                                _isRegisterMode
                                    ? '¿Ya tienes cuenta? Inicia sesión aquí'
                                    : '¿Atleta nuevo? Regístrate aquí',
                                style: const TextStyle(
                                  color: ApexTheme.cyanElectric,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
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
      },
    );
  }

  Widget _buildServerHealthBanner(BuildContext context) {
    final ServerHealthCheckModel? health = widget.viewModel.healthStatus;
    final bool isOnline = health?.isOnline ?? false;
    final Color statusColor = isOnline
        ? ApexTheme.readinessGreen
        : (health == null ? ApexTheme.cyanElectric : ApexTheme.warningAmber);

    final String statusText = health != null
        ? health.message
        : 'Pulsa "Ping /health" para verificar disponibilidad del servidor.';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                isOnline
                    ? Icons.cloud_done_rounded
                    : Icons.health_and_safety_outlined,
                color: statusColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isOnline
                      ? 'HEALTHCHECK /health: ONLINE'
                      : 'DIAGNÓSTICO DE SERVIDOR (/health)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            statusText,
            style: const TextStyle(
              fontSize: 11.5,
              color: ApexTheme.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: <Widget>[
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: ApexTheme.voltAccent,
                  side: const BorderSide(color: ApexTheme.voltAccent),
                ),
                onPressed: widget.viewModel.isCheckingHealth
                    ? null
                    : () => widget.viewModel.pingServerHealth(),
                icon: widget.viewModel.isCheckingHealth
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: ApexTheme.voltAccent,
                        ),
                      )
                    : const Icon(Icons.network_ping_rounded, size: 15),
                label: const Text(
                  'Ping /health',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: ApexTheme.cyanElectric,
                  side: const BorderSide(color: ApexTheme.cyanElectric),
                ),
                onPressed: () => _openServerConfigDialog(context),
                icon: const Icon(Icons.dns_outlined, size: 15),
                label: const Text(
                  'Cambiar Servidor / IP',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openServerConfigDialog(BuildContext context) {
    final TextEditingController urlCtrl = TextEditingController(
      text: widget.viewModel.apiBaseUrl,
    );
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: ApexTheme.cardGraphite,
          title: const Text(
            'SERVIDOR BACKEND FASTAPI',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(
                  labelText: 'URL base del backend',
                  hintText: 'https://fitness-ranked-api.onrender.com',
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  ActionChip(
                    label: const Text(
                      'Render Cloud (Producción)',
                      style: TextStyle(fontSize: 11),
                    ),
                    onPressed: () =>
                        urlCtrl.text = 'https://fitness-ranked-api.onrender.com',
                  ),
                  ActionChip(
                    label: const Text(
                      'LAN Wi-Fi (192.168.0.19)',
                      style: TextStyle(fontSize: 11),
                    ),
                    onPressed: () =>
                        urlCtrl.text = 'http://192.168.0.19:8000',
                  ),
                  ActionChip(
                    label: const Text(
                      'Emulador (10.0.2.2)',
                      style: TextStyle(fontSize: 11),
                    ),
                    onPressed: () => urlCtrl.text = 'http://10.0.2.2:8000',
                  ),
                ],
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('CANCELAR'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: ApexTheme.voltAccent,
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                await widget.viewModel.setServerUrl(urlCtrl.text);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('GUARDAR'),
            ),
          ],
        );
      },
    );
  }
}
