import 'package:flutter/material.dart';
import '../../../../data/models/workout_models.dart';
import '../../../core/app_theme.dart';

class SetBinaryFeedbackResult {
  final bool completedBinaryUi;
  final double actualWeightKg;
  final int actualReps;
  final double actualRpe;

  const SetBinaryFeedbackResult({
    required this.completedBinaryUi,
    required this.actualWeightKg,
    required this.actualReps,
    required this.actualRpe,
  });
}

class SetBinaryFeedbackSheet extends StatefulWidget {
  final WorkoutSetModel activeSet;
  final String unitSystem;

  const SetBinaryFeedbackSheet({
    super.key,
    required this.activeSet,
    required this.unitSystem,
  });

  @override
  State<SetBinaryFeedbackSheet> createState() => _SetBinaryFeedbackSheetState();
}

class _SetBinaryFeedbackSheetState extends State<SetBinaryFeedbackSheet> {
  bool? _completedAsPrescribed;
  late double _actualWeightKg;
  late int _actualReps;
  late double _actualRpe;

  @override
  void initState() {
    super.initState();
    _actualWeightKg = widget.activeSet.prescribedWeightKg;
    _actualReps = widget.activeSet.prescribedReps;
    _actualRpe = widget.activeSet.prescribedRpe.clamp(6.5, 10.0);
  }

  String _formatWeight(double kg) {
    if (widget.unitSystem == 'LB') {
      return '${(kg * 2.20462).toStringAsFixed(1)} LB';
    }
    return '${kg.toStringAsFixed(1)} KG';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'SERIE #${widget.activeSet.setNumber} • ${widget.activeSet.exerciseName.toUpperCase()}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: ApexTheme.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '¿Completaste ${_formatWeight(widget.activeSet.prescribedWeightKg)} × ${widget.activeSet.prescribedReps} reps?',
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: ApexTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            // Botones Binarios [ SÍ ] / [ NO ]
            Row(
              children: <Widget>[
                Expanded(
                  child: _BinaryChoiceButton(
                    label: 'SÍ, COMPLETADO',
                    selected: _completedAsPrescribed == true,
                    activeColor: ApexTheme.readinessGreen,
                    icon: Icons.check_circle_outline_rounded,
                    onTap: () {
                      setState(() {
                        _completedAsPrescribed = true;
                        _actualWeightKg = widget.activeSet.prescribedWeightKg;
                        _actualReps = widget.activeSet.prescribedReps;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BinaryChoiceButton(
                    label: 'NO, AJUSTAR',
                    selected: _completedAsPrescribed == false,
                    activeColor: ApexTheme.deloadCrimson,
                    icon: Icons.tune_rounded,
                    onTap: () {
                      setState(() {
                        _completedAsPrescribed = false;
                      });
                    },
                  ),
                ),
              ],
            ),
            if (_completedAsPrescribed != null) ...<Widget>[
              const SizedBox(height: 20),
              if (_completedAsPrescribed == false) ...<Widget>[
                _buildStepperRow(
                  label: 'PESO REAL EJECUTADO',
                  valueText: _formatWeight(_actualWeightKg),
                  onDecrement: () {
                    setState(() {
                      _actualWeightKg = (_actualWeightKg - 2.5).clamp(0.0, 500.0);
                    });
                  },
                  onIncrement: () {
                    setState(() {
                      _actualWeightKg = (_actualWeightKg + 2.5).clamp(0.0, 500.0);
                    });
                  },
                ),
                const SizedBox(height: 12),
                _buildStepperRow(
                  label: 'REPETICIONES LOGRADAS',
                  valueText: '$_actualReps reps',
                  onDecrement: () {
                    setState(() {
                      _actualReps = (_actualReps - 1).clamp(0, 100);
                    });
                  },
                  onIncrement: () {
                    setState(() {
                      _actualReps = (_actualReps + 1).clamp(0, 100);
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const Text(
                    'ESFUERZO PERCIBIDO (RPE REAL)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: ApexTheme.textMuted,
                    ),
                  ),
                  Text(
                    'RPE ${_actualRpe.toStringAsFixed(1)} (${(10.0 - _actualRpe).toStringAsFixed(1)} RIR)',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: ApexTheme.voltAccent,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _actualRpe,
                min: 6.5,
                max: 10.0,
                divisions: 7,
                activeColor: ApexTheme.voltAccent,
                label: 'RPE ${_actualRpe.toStringAsFixed(1)}',
                onChanged: (double value) {
                  setState(() {
                    _actualRpe = value;
                  });
                },
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: ApexTheme.voltAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: () {
                  Navigator.of(context).pop(
                    SetBinaryFeedbackResult(
                      completedBinaryUi: _completedAsPrescribed!,
                      actualWeightKg: _actualWeightKg,
                      actualReps: _actualReps,
                      actualRpe: _actualRpe,
                    ),
                  );
                },
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text(
                  'CONFIRMAR Y RECALCULAR CON GEMINI',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepperRow({
    required String label,
    required String valueText,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ApexTheme.obsidianBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ApexTheme.cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: ApexTheme.textMuted,
            ),
          ),
          Row(
            children: <Widget>[
              IconButton.filledTonal(
                onPressed: onDecrement,
                icon: const Icon(Icons.remove_rounded),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  valueText,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: ApexTheme.textPrimary,
                  ),
                ),
              ),
              IconButton.filledTonal(
                onPressed: onIncrement,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BinaryChoiceButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color activeColor;
  final IconData icon;
  final VoidCallback onTap;

  const _BinaryChoiceButton({
    required this.label,
    required this.selected,
    required this.activeColor,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withValues(alpha: 0.22)
              : ApexTheme.obsidianBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? activeColor : ApexTheme.cardBorder,
            width: selected ? 2.0 : 1.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              icon,
              color: selected ? activeColor : ApexTheme.textMuted,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: selected ? activeColor : ApexTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
