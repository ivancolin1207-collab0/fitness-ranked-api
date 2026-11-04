import 'package:flutter/material.dart';
import '../../../../data/models/auth_models.dart';
import '../../../core/app_theme.dart';
import '../view_models/auth_view_model.dart';

class ProfileSetupScreen extends StatefulWidget {
  final AuthViewModel viewModel;
  final VoidCallback? onCompleted;

  const ProfileSetupScreen({
    super.key,
    required this.viewModel,
    this.onCompleted,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _heightCtrl;

  DateTime _birthDate = DateTime(1998, 6, 15);
  String _biologicalSex = 'MALE';
  String _trainingGoal = 'HIPERTROFIA';
  String _preferredWearable = 'WHOOP';
  String _unitSystem = 'KG';

  @override
  void initState() {
    super.initState();
    final UserProfileModel? user = widget.viewModel.currentUser;
    _fullNameCtrl = TextEditingController(text: user?.fullName ?? '');
    _usernameCtrl = TextEditingController(text: user?.username ?? '');
    _heightCtrl = TextEditingController(
      text: (user?.heightCm ?? 175.0).toStringAsFixed(0),
    );
    if (user?.birthDate != null) {
      _birthDate = user!.birthDate!;
    }
    _biologicalSex = user?.biologicalSex ?? 'MALE';
    _trainingGoal = user?.trainingGoal ?? 'HIPERTROFIA';
    _preferredWearable = user?.preferredWearable ?? 'WHOOP';
    _unitSystem = user?.unitSystem ?? 'KG';
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _usernameCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  int get _calculatedAge {
    final DateTime today = DateTime.now();
    int age = today.year - _birthDate.year;
    if (today.month < _birthDate.month ||
        (today.month == _birthDate.month && today.day < _birthDate.day)) {
      age--;
    }
    return age.clamp(12, 110);
  }

  Future<void> _pickBirthDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthDate,
      firstDate: DateTime(1930, 1, 1),
      lastDate: DateTime(now.year - 12, now.month, now.day),
      helpText: 'SELECCIONA TU FECHA DE NACIMIENTO',
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
      });
    }
  }

  Future<void> _saveSetup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final double heightCm =
        double.tryParse(_heightCtrl.text.trim()) ?? 175.0;

    final ProfileSetupRequestModel payload = ProfileSetupRequestModel(
      username: _usernameCtrl.text.trim(),
      fullName: _fullNameCtrl.text.trim(),
      birthDate: _birthDate,
      biologicalSex: _biologicalSex,
      heightCm: heightCm.clamp(120.0, 240.0),
      trainingGoal: _trainingGoal,
      preferredWearable: _preferredWearable,
      unitSystem: _unitSystem,
    );

    final bool ok = await widget.viewModel.saveProfileOnboarding(payload);
    if (ok && mounted) {
      widget.onCompleted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final String formattedDate =
        '${_birthDate.day.toString().padLeft(2, '0')}/${_birthDate.month.toString().padLeft(2, '0')}/${_birthDate.year}';

    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (BuildContext context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('CONFIGURACIÓN BIOMÉTRICA Y METAS'),
          ),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const Text(
                              'PERFIL DE ATLETA RANKED',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: ApexTheme.voltAccent,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Estos parámetros calibran tu coeficiente DOTS, edad metabólica BMR y rutinas progresivas.',
                              style: TextStyle(
                                fontSize: 12,
                                color: ApexTheme.textMuted,
                              ),
                            ),
                            const SizedBox(height: 18),
                            if (widget.viewModel.errorMessage != null) ...<Widget>[
                              Container(
                                padding: const EdgeInsets.all(10),
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
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                            ],
                            TextFormField(
                              controller: _fullNameCtrl,
                              decoration: InputDecoration(
                                labelText: 'Nombre completo',
                                prefixIcon: const Icon(Icons.badge_outlined),
                                filled: true,
                                fillColor: ApexTheme.obsidianBg,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (String? v) {
                                if ((v ?? '').trim().length < 2) {
                                  return 'Ingresa tu nombre completo';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _usernameCtrl,
                              decoration: InputDecoration(
                                labelText: 'Username en Arena Ranked',
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
                                  return 'Mínimo 3 caracteres';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            InkWell(
                              onTap: _pickBirthDate,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: ApexTheme.obsidianBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: ApexTheme.cardBorder,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    Row(
                                      children: <Widget>[
                                        const Icon(
                                          Icons.cake_outlined,
                                          color: ApexTheme.cyanElectric,
                                        ),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            const Text(
                                              'FECHA DE NACIMIENTO',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: ApexTheme.textMuted,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              formattedDate,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: ApexTheme.voltAccent
                                            .withValues(alpha: 0.16),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '$_calculatedAge AÑOS',
                                        style: const TextStyle(
                                          color: ApexTheme.voltAccent,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _biologicalSex,
                                    decoration: InputDecoration(
                                      labelText: 'Sexo Biológico',
                                      filled: true,
                                      fillColor: ApexTheme.obsidianBg,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    items: const <DropdownMenuItem<String>>[
                                      DropdownMenuItem<String>(
                                        value: 'MALE',
                                        child: Text('Masculino'),
                                      ),
                                      DropdownMenuItem<String>(
                                        value: 'FEMALE',
                                        child: Text('Femenino'),
                                      ),
                                    ],
                                    onChanged: (String? v) {
                                      if (v != null) {
                                        setState(() => _biologicalSex = v);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _heightCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Altura (cm)',
                                      suffixText: 'cm',
                                      filled: true,
                                      fillColor: ApexTheme.obsidianBg,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    validator: (String? v) {
                                      final double? parsed =
                                          double.tryParse((v ?? '').trim());
                                      if (parsed == null ||
                                          parsed < 120 ||
                                          parsed > 240) {
                                        return '120 - 240 cm';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'META DE ENTRENAMIENTO',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: ApexTheme.textMuted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SegmentedButton<String>(
                              segments: const <ButtonSegment<String>>[
                                ButtonSegment<String>(
                                  value: 'FUERZA',
                                  label: Text('Fuerza'),
                                ),
                                ButtonSegment<String>(
                                  value: 'HIPERTROFIA',
                                  label: Text('Hipertrofia'),
                                ),
                                ButtonSegment<String>(
                                  value: 'RECOMPOSICION',
                                  label: Text('Recomp.'),
                                ),
                              ],
                              selected: <String>{_trainingGoal},
                              onSelectionChanged: (Set<String> s) {
                                setState(() => _trainingGoal = s.first);
                              },
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _preferredWearable,
                                    decoration: InputDecoration(
                                      labelText: 'Wearable Principal',
                                      filled: true,
                                      fillColor: ApexTheme.obsidianBg,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    items: const <DropdownMenuItem<String>>[
                                      DropdownMenuItem<String>(
                                        value: 'WHOOP',
                                        child: Text('WHOOP 4.0'),
                                      ),
                                      DropdownMenuItem<String>(
                                        value: 'HEALTH_CONNECT',
                                        child: Text('Health Connect'),
                                      ),
                                      DropdownMenuItem<String>(
                                        value: 'HUAWEI_GT',
                                        child: Text('Huawei GT'),
                                      ),
                                    ],
                                    onChanged: (String? v) {
                                      if (v != null) {
                                        setState(() => _preferredWearable = v);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _unitSystem,
                                    decoration: InputDecoration(
                                      labelText: 'Unidades',
                                      filled: true,
                                      fillColor: ApexTheme.obsidianBg,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    items: const <DropdownMenuItem<String>>[
                                      DropdownMenuItem<String>(
                                        value: 'KG',
                                        child: Text('Kilogramos (KG)'),
                                      ),
                                      DropdownMenuItem<String>(
                                        value: 'LB',
                                        child: Text('Libras (LB)'),
                                      ),
                                    ],
                                    onChanged: (String? v) {
                                      if (v != null) {
                                        setState(() => _unitSystem = v);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: ApexTheme.voltAccent,
                                foregroundColor: Colors.black,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                              onPressed: widget.viewModel.isSubmitting
                                  ? null
                                  : _saveSetup,
                              icon: widget.viewModel.isSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : const Icon(Icons.check_circle_outline),
                              label: const Text(
                                'GUARDAR PERFIL E INICIALIZAR RUTINAS',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
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
}
