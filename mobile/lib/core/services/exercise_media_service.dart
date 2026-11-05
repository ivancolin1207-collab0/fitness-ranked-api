import 'dart:math' as math;
import 'package:flutter/material.dart';

enum BiomechanicalArchetype {
  squat,
  benchPress,
  deadlift,
  overheadPress,
  latPulldown,
  barbellRow,
  bicepCurl,
  lateralRaise,
  tricepExtension,
  lunge,
  hipThrust,
}

class ExerciseMediaSpec {
  final String canonicalName;
  final String gifUrl;
  final BiomechanicalArchetype archetype;
  final String prescribedTempoCode;
  final String prescribedTempoDetail;
  final int eccentricSec;
  final int pauseBottomSec;
  final int concentricSec;
  final int pauseTopSec;
  final String activationCue;
  final String defaultTargetRange;
  final String primaryMuscles;
  final String jointFocusLabel;

  const ExerciseMediaSpec({
    required this.canonicalName,
    required this.gifUrl,
    required this.archetype,
    required this.prescribedTempoCode,
    required this.prescribedTempoDetail,
    required this.eccentricSec,
    required this.pauseBottomSec,
    required this.concentricSec,
    required this.pauseTopSec,
    required this.activationCue,
    required this.defaultTargetRange,
    required this.primaryMuscles,
    required this.jointFocusLabel,
  });
}

class ExerciseMediaService {
  const ExerciseMediaService();

  static const List<ExerciseMediaSpec> _catalog = <ExerciseMediaSpec>[
    ExerciseMediaSpec(
      canonicalName: 'Press de Banca con Barra',
      gifUrl:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Bench_Press_-_Medium_Grip/0.jpg',
      archetype: BiomechanicalArchetype.benchPress,
      prescribedTempoCode: '3-0-1-0',
      prescribedTempoDetail: '3 seg bajada, 0 pausa, 1 subida',
      eccentricSec: 3,
      pauseBottomSec: 0,
      concentricSec: 1,
      pauseTopSec: 0,
      activationCue:
          'Pecho erguido, retrae escápulas y mantén codos a 45° durante el descenso',
      defaultTargetRange: 'RPE 8.0 | 8-10 reps según tu recuperación de hoy',
      primaryMuscles: 'Pectoral Mayor • Deltoides Anterior • Tríceps',
      jointFocusLabel: 'Hombro 45° • Arco Torácico Estable',
    ),
    ExerciseMediaSpec(
      canonicalName: 'Sentadilla Libre con Barra (Back Squat)',
      gifUrl:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Full_Squat/0.jpg',
      archetype: BiomechanicalArchetype.squat,
      prescribedTempoCode: '3-1-1-0',
      prescribedTempoDetail: '3 seg bajada, 1 pausa abajo, 1 subida',
      eccentricSec: 3,
      pauseBottomSec: 1,
      concentricSec: 1,
      pauseTopSec: 0,
      activationCue:
          'Bracing abdominal 360°, rodillas alineadas con punteras y torso firme',
      defaultTargetRange: 'RPE 8.0 | 6-8 reps según tu recuperación de hoy',
      primaryMuscles: 'Cuádriceps • Glúteo Mayor • Core',
      jointFocusLabel: 'Flexión Cadera/Rodilla >95° • Columna Neutra',
    ),
    ExerciseMediaSpec(
      canonicalName: 'Peso Muerto Convencional / Rumano',
      gifUrl:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Deadlift/0.jpg',
      archetype: BiomechanicalArchetype.deadlift,
      prescribedTempoCode: '3-0-1-0',
      prescribedTempoDetail: '3 seg bisagra excéntrica, 0 pausa, 1 empuje',
      eccentricSec: 3,
      pauseBottomSec: 0,
      concentricSec: 1,
      pauseTopSec: 0,
      activationCue:
          'Barra pegada a las tibias, activa dorsales y empuja el piso con los talones',
      defaultTargetRange: 'RPE 8.0 | 6-8 reps según tu recuperación de hoy',
      primaryMuscles: 'Isquiosurales • Glúteo Mayor • Erectores Espinales',
      jointFocusLabel: 'Bisagra de Cadera • Dorsal Compacto',
    ),
    ExerciseMediaSpec(
      canonicalName: 'Press Militar Overhead (OHP)',
      gifUrl:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Standing_Military_Press/0.jpg',
      archetype: BiomechanicalArchetype.overheadPress,
      prescribedTempoCode: '2-0-1-1',
      prescribedTempoDetail: '2 seg bajada, 0 pausa, 1 subida explosiva',
      eccentricSec: 2,
      pauseBottomSec: 0,
      concentricSec: 1,
      pauseTopSec: 1,
      activationCue:
          'Glúteos y abdomen contraídos, antebrazos verticales y bloqueo sobre corona',
      defaultTargetRange: 'RPE 8.0 | 8-10 reps según tu recuperación de hoy',
      primaryMuscles: 'Deltoides Anterior/Lateral • Tríceps • Trapecio Sup.',
      jointFocusLabel: 'Escápula en Rotación Superior • Core Fijo',
    ),
    ExerciseMediaSpec(
      canonicalName: 'Dominadas / Jalón al Pecho Prono',
      gifUrl:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Wide-Grip_Lat_Pulldown/0.jpg',
      archetype: BiomechanicalArchetype.latPulldown,
      prescribedTempoCode: '3-0-1-1',
      prescribedTempoDetail: '3 seg retorno controlado, 1 tracción, 1 iso',
      eccentricSec: 3,
      pauseBottomSec: 0,
      concentricSec: 1,
      pauseTopSec: 1,
      activationCue:
          'Inicia con depresión escapular y conduce los codos hacia tus bolsillos',
      defaultTargetRange: 'RPE 8.0 | 8-12 reps según tu recuperación de hoy',
      primaryMuscles: 'Dorsal Ancho • Redondo Mayor • Bíceps Braquial',
      jointFocusLabel: 'Depresión Escapular • Tracción Vertical',
    ),
    ExerciseMediaSpec(
      canonicalName: 'Remo con Barra / Pendlay Row',
      gifUrl:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Bent_Over_Barbell_Row/0.jpg',
      archetype: BiomechanicalArchetype.barbellRow,
      prescribedTempoCode: '2-0-1-1',
      prescribedTempoDetail: '2 seg bajada, 0 pausa, 1 tracción, 1 pausa',
      eccentricSec: 2,
      pauseBottomSec: 0,
      concentricSec: 1,
      pauseTopSec: 1,
      activationCue:
          'Torso a 45° estable, tracciona hacia el abdomen bajo apretando romboides',
      defaultTargetRange: 'RPE 8.0 | 8-10 reps según tu recuperación de hoy',
      primaryMuscles: 'Dorsal Ancho • Romboides • Trapecio Medio',
      jointFocusLabel: 'Retracción Escapular • Bisagra Isométrica',
    ),
    ExerciseMediaSpec(
      canonicalName: 'Curl de Bíceps con Barra / Mancuerna',
      gifUrl:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Curl/0.jpg',
      archetype: BiomechanicalArchetype.bicepCurl,
      prescribedTempoCode: '3-0-1-1',
      prescribedTempoDetail: '3 seg bajada excéntrica, 1 subida, 1 contracción',
      eccentricSec: 3,
      pauseBottomSec: 0,
      concentricSec: 1,
      pauseTopSec: 1,
      activationCue:
          'Codos fijos a los costados, supina la muñeca al subir sin balancear el torso',
      defaultTargetRange: 'RPE 8.5 | 10-12 reps según tu recuperación de hoy',
      primaryMuscles: 'Bíceps Braquial • Braquial Anterior • Braquiorradial',
      jointFocusLabel: 'Húmero Fijo • Flexión de Codo Pura',
    ),
    ExerciseMediaSpec(
      canonicalName: 'Elevaciones Laterales en Plano Escapular',
      gifUrl:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Side_Lateral_Raise/0.jpg',
      archetype: BiomechanicalArchetype.lateralRaise,
      prescribedTempoCode: '3-0-1-1',
      prescribedTempoDetail: '3 seg bajada controlada, 1 subida, 1 iso arriba',
      eccentricSec: 3,
      pauseBottomSec: 0,
      concentricSec: 1,
      pauseTopSec: 1,
      activationCue:
          'Eleva a 30° en plano escapular guiando con los codos, sin encoger trapecios',
      defaultTargetRange: 'RPE 8.5 | 12-15 reps según tu recuperación de hoy',
      primaryMuscles: 'Deltoides Lateral • Supraespinoso',
      jointFocusLabel: 'Abducción 30° Plano Escapular',
    ),
    ExerciseMediaSpec(
      canonicalName: 'Extensión de Tríceps en Polea / Press Francés',
      gifUrl:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Triceps_Pushdown/0.jpg',
      archetype: BiomechanicalArchetype.tricepExtension,
      prescribedTempoCode: '3-0-1-1',
      prescribedTempoDetail: '3 seg fase excéntrica, 1 extensión completa',
      eccentricSec: 3,
      pauseBottomSec: 0,
      concentricSec: 1,
      pauseTopSec: 1,
      activationCue:
          'Bloquea los húmeros junto al torso y extiende el codo al 100% abajo',
      defaultTargetRange: 'RPE 8.5 | 10-12 reps según tu recuperación de hoy',
      primaryMuscles: 'Tríceps Braquial (Cabeza Lateral, Larga y Medial)',
      jointFocusLabel: 'Extensión Aislada de Codo',
    ),
    ExerciseMediaSpec(
      canonicalName: 'Zancadas Búlgaras / Prensa de Piernas',
      gifUrl:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dumbbell_Lunges/0.jpg',
      archetype: BiomechanicalArchetype.lunge,
      prescribedTempoCode: '3-1-1-0',
      prescribedTempoDetail: '3 seg descenso, 1 pausa abajo, 1 subida',
      eccentricSec: 3,
      pauseBottomSec: 1,
      concentricSec: 1,
      pauseTopSec: 0,
      activationCue:
          'Inclina ligeramente el torso al frente y empuja con toda la planta delantera',
      defaultTargetRange: 'RPE 8.0 | 8-10 reps según tu recuperación de hoy',
      primaryMuscles: 'Cuádriceps • Glúteo Mayor • Aductores',
      jointFocusLabel: 'Estabilidad Unilateral de Cadera y Rodilla',
    ),
    ExerciseMediaSpec(
      canonicalName: 'Hip Thrust con Barra',
      gifUrl:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Glute_Bridge/0.jpg',
      archetype: BiomechanicalArchetype.hipThrust,
      prescribedTempoCode: '2-0-1-2',
      prescribedTempoDetail: '2 seg bajada, 1 subida, 2 seg iso en extensión',
      eccentricSec: 2,
      pauseBottomSec: 0,
      concentricSec: 1,
      pauseTopSec: 2,
      activationCue:
          'Mentón recogido, tibias a 90° arriba y retroversión pélvica en el bloqueo',
      defaultTargetRange: 'RPE 8.5 | 8-12 reps según tu recuperación de hoy',
      primaryMuscles: 'Glúteo Mayor • Isquiosurales',
      jointFocusLabel: 'Extensión de Cadera 180° • Tibia Vertical',
    ),
  ];

  static ExerciseMediaSpec resolveForExercise(String rawName) {
    final String q = rawName.toLowerCase().trim();
    if (q.contains('banca') ||
        q.contains('bench') ||
        q.contains('pecho') ||
        q.contains('inclinado') ||
        q.contains('chest') ||
        q.contains('fondo') ||
        q.contains('dip') ||
        q.contains('apertura') ||
        q.contains('fly')) {
      return _catalog[0];
    }
    if (q.contains('sentadilla') ||
        q.contains('squat') ||
        q.contains('hack') ||
        q.contains('cuádriceps') ||
        q.contains('cuadriceps')) {
      return _catalog[1];
    }
    if (q.contains('peso muerto') ||
        q.contains('deadlift') ||
        q.contains('rumano') ||
        q.contains('rdl') ||
        q.contains('isquio') ||
        q.contains('femoral')) {
      return _catalog[2];
    }
    if (q.contains('militar') ||
        q.contains('overhead') ||
        q.contains('ohp') ||
        q.contains('hombro') ||
        q.contains('shoulder press') ||
        q.contains('arnold')) {
      return _catalog[3];
    }
    if (q.contains('dominada') ||
        q.contains('pull') ||
        q.contains('jalón') ||
        q.contains('jalon') ||
        q.contains('lat') ||
        q.contains('dorsal')) {
      return _catalog[4];
    }
    if (q.contains('remo') ||
        q.contains('row') ||
        q.contains('pendlay') ||
        q.contains('espalda') ||
        q.contains('seal')) {
      return _catalog[5];
    }
    if (q.contains('curl') ||
        q.contains('bíceps') ||
        q.contains('biceps') ||
        q.contains('martillo') ||
        q.contains('predicador')) {
      return _catalog[6];
    }
    if (q.contains('lateral') ||
        q.contains('vuelo') ||
        q.contains('pájaro') ||
        q.contains('pajaro') ||
        q.contains('deltoide')) {
      return _catalog[7];
    }
    if (q.contains('tríceps') ||
        q.contains('triceps') ||
        q.contains('francés') ||
        q.contains('frances') ||
        q.contains('polea') ||
        q.contains('extensión') ||
        q.contains('extension')) {
      return _catalog[8];
    }
    if (q.contains('hip thrust') ||
        q.contains('glúteo') ||
        q.contains('gluteo') ||
        q.contains('puente')) {
      return _catalog[10];
    }
    if (q.contains('zancada') ||
        q.contains('búlgara') ||
        q.contains('bulgara') ||
        q.contains('prensa') ||
        q.contains('lunge') ||
        q.contains('leg press')) {
      return _catalog[9];
    }
    return _catalog[0];
  }

  static String formatTargetRange({
    required ExerciseMediaSpec spec,
    double? recoveryScore,
    int? targetReps,
    double? prescribedRpe,
  }) {
    final double rpe = prescribedRpe ??
        (recoveryScore != null
            ? (recoveryScore < 34.0
                ? 6.5
                : (recoveryScore >= 67.0 ? 8.5 : 8.0))
            : 8.0);
    final String repsRange = targetReps != null
        ? '${math.max(4, targetReps - 1)}-${targetReps + 1} reps'
        : '8-10 reps';
    final String zoneSuffix = recoveryScore != null
        ? (recoveryScore < 34.0
            ? 'Descarga SNC (${recoveryScore.round()}% rec)'
            : (recoveryScore >= 67.0
                ? 'Sobrecarga activa (${recoveryScore.round()}% rec)'
                : 'según tu recuperación de hoy (${recoveryScore.round()}%)'))
        : 'según tu recuperación de hoy';
    return 'RPE ${rpe.toStringAsFixed(1)} | $repsRange $zoneSuffix';
  }
}

/// Módulo de Demostración Visual Biomecánica (180dp, #14171E, borde #232834)
/// + 3 Píldoras Técnicas (Tempo Prescrito, Cue de Activación, Rango Objetivo).
class BiomechanicalExerciseAvatarModule extends StatefulWidget {
  final String exerciseName;
  final double? recoveryScore;
  final int? targetReps;
  final double? prescribedRpe;

  const BiomechanicalExerciseAvatarModule({
    super.key,
    required this.exerciseName,
    this.recoveryScore,
    this.targetReps,
    this.prescribedRpe,
  });

  @override
  State<BiomechanicalExerciseAvatarModule> createState() =>
      _BiomechanicalExerciseAvatarModuleState();
}

class _BiomechanicalExerciseAvatarModuleState
    extends State<BiomechanicalExerciseAvatarModule>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Calcula la posición normalizada (0 = inicio/arriba, 1 = máxima flexión/abajo)
  /// respetando el tempo biomecánico (p. ej. 3 seg excéntrica, 0-1 seg pausa, 1 seg concéntrica).
  ({double depth, String phaseLabel, Color phaseColor}) _evaluatePhase(
    double t,
    ExerciseMediaSpec spec,
  ) {
    final double totalSec = (spec.eccentricSec +
            spec.pauseBottomSec +
            spec.concentricSec +
            spec.pauseTopSec)
        .clamp(2, 10)
        .toDouble();
    final double sec = t * totalSec;
    final double eccEnd = spec.eccentricSec.toDouble();
    final double bottomEnd = eccEnd + spec.pauseBottomSec.toDouble();
    final double concEnd = bottomEnd + spec.concentricSec.toDouble();

    if (sec <= eccEnd) {
      final double p = (sec / eccEnd).clamp(0.0, 1.0);
      final double eased = Curves.easeInOutCubic.transform(p);
      return (
        depth: eased,
        phaseLabel: 'FASE EXCÉNTRICA (${spec.eccentricSec}s CONTROL)',
        phaseColor: const Color(0xFF00E5FF),
      );
    } else if (sec <= bottomEnd) {
      return (
        depth: 1.0,
        phaseLabel: 'PAUSA ISOMÉTRICA (${spec.pauseBottomSec}s)',
        phaseColor: const Color(0xFFF59E0B),
      );
    } else if (sec <= concEnd) {
      final double p =
          ((sec - bottomEnd) / math.max(0.5, spec.concentricSec)).clamp(0.0, 1.0);
      final double eased = 1.0 - Curves.easeOutBack.transform(p).clamp(0.0, 1.0);
      return (
        depth: eased,
        phaseLabel: 'FASE CONCÉNTRICA (${spec.concentricSec}s EXPLOSIVA)',
        phaseColor: const Color(0xFFD2FF00),
      );
    } else {
      return (
        depth: 0.0,
        phaseLabel: 'ESTABILIZACIÓN / CONTRACCIÓN',
        phaseColor: const Color(0xFF10B981),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ExerciseMediaSpec spec =
        ExerciseMediaService.resolveForExercise(widget.exerciseName);
    final String targetRangeText = ExerciseMediaService.formatTargetRange(
      spec: spec,
      recoveryScore: widget.recoveryScore,
      targetReps: widget.targetReps,
      prescribedRpe: widget.prescribedRpe,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Contenedor Visual de 180dp de altura, esquinas 12px, fondo #14171E y borde #232834
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: const Color(0xFF14171E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF232834),
              width: 1.2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, _) {
              final phase = _evaluatePhase(_controller.value, spec);
              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  // Lienzo biomecánico animado en bucle continuo (60 FPS)
                  CustomPaint(
                    painter: _BiomechanicalAvatarPainter(
                      archetype: spec.archetype,
                      depth: phase.depth,
                      phaseColor: phase.phaseColor,
                    ),
                  ),
                  // HUD Superior: Nombre del ejercicio + Fase en vivo
                  Positioned(
                    top: 8,
                    left: 10,
                    right: 10,
                    child: Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B0E14).withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFF232834),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.motion_photos_on_rounded,
                                size: 12,
                                color: Color(0xFFD2FF00),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'AVATAR BIOMECÁNICO IA',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFD2FF00),
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: phase.phaseColor.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: phase.phaseColor.withValues(alpha: 0.7),
                              ),
                            ),
                            child: Text(
                              phase.phaseLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: phase.phaseColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // HUD Inferior: Músculos implicados y foco articular
                  Positioned(
                    bottom: 8,
                    left: 10,
                    right: 10,
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            spec.primaryMuscles,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B0E14).withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFF232834),
                            ),
                          ),
                          child: Text(
                            spec.jointFocusLabel,
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // 3 Píldoras Técnicas compactas debajo del avatar
        _TechnicalCuePill(
          icon: Icons.timer_outlined,
          accentColor: const Color(0xFFD2FF00),
          label: 'TEMPO PRESCRITO',
          value: '${spec.prescribedTempoCode} (${spec.prescribedTempoDetail})',
        ),
        const SizedBox(height: 5),
        _TechnicalCuePill(
          icon: Icons.psychology_alt_outlined,
          accentColor: const Color(0xFF00E5FF),
          label: 'CUE DE ACTIVACIÓN',
          value: '"${spec.activationCue}"',
        ),
        const SizedBox(height: 5),
        _TechnicalCuePill(
          icon: Icons.track_changes_rounded,
          accentColor: const Color(0xFF10B981),
          label: 'RANGO OBJETIVO',
          value: targetRangeText,
        ),
      ],
    );
  }
}

class _TechnicalCuePill extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final String label;
  final String value;

  const _TechnicalCuePill({
    required this.icon,
    required this.accentColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF14171E),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: const Color(0xFF232834),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 15, color: accentColor),
          const SizedBox(width: 7),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: accentColor,
              letterSpacing: 0.3,
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFFF1F5F9),
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BiomechanicalAvatarPainter extends CustomPainter {
  final BiomechanicalArchetype archetype;
  final double depth;
  final Color phaseColor;

  const _BiomechanicalAvatarPainter({
    required this.archetype,
    required this.depth,
    required this.phaseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Cuadrícula técnica de laboratorio biomecánico
    final Paint gridPaint = Paint()
      ..color = const Color(0xFF232834).withValues(alpha: 0.45)
      ..strokeWidth = 0.8;

    const double step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Suelo de plataforma
    final double floorY = size.height - 34.0;
    final Paint floorPaint = Paint()
      ..color = const Color(0xFF2E3646)
      ..strokeWidth = 2.0;
    canvas.drawLine(
      Offset(size.width * 0.12, floorY),
      Offset(size.width * 0.88, floorY),
      floorPaint,
    );

    final double cx = size.width * 0.5;

    final Paint bonePaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;

    final Paint muscleGlowPaint = Paint()
      ..color = phaseColor.withValues(alpha: 0.28)
      ..strokeWidth = 13.0
      ..strokeCap = StrokeCap.round;

    final Paint jointPaint = Paint()
      ..color = phaseColor
      ..style = PaintingStyle.fill;

    final Paint barbellPaint = Paint()
      ..color = const Color(0xFFD2FF00)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final Paint benchPaint = Paint()
      ..color = const Color(0xFF334155)
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    void drawSegment(Offset a, Offset b, {bool activeMuscle = false}) {
      if (activeMuscle) {
        canvas.drawLine(a, b, muscleGlowPaint);
      }
      canvas.drawLine(a, b, bonePaint);
      canvas.drawCircle(a, 4.0, jointPaint);
      canvas.drawCircle(b, 4.0, jointPaint);
    }

    void drawHead(Offset center) {
      canvas.drawCircle(
        center,
        9.5,
        Paint()
          ..color = const Color(0xFF1E293B)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        center,
        9.5,
        Paint()
          ..color = phaseColor
          ..strokeWidth = 2.2
          ..style = PaintingStyle.stroke,
      );
    }

    void drawBarbellPlate(Offset center, {double radius = 11.0}) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = const Color(0xFF0F172A)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = const Color(0xFFD2FF00)
          ..strokeWidth = 2.6
          ..style = PaintingStyle.stroke,
      );
    }

    switch (archetype) {
      case BiomechanicalArchetype.benchPress:
        // Banco horizontal
        final double benchY = floorY - 34;
        canvas.drawLine(
          Offset(cx - 58, benchY),
          Offset(cx + 36, benchY),
          benchPaint,
        );
        canvas.drawLine(
          Offset(cx - 46, benchY),
          Offset(cx - 46, floorY),
          benchPaint,
        );
        canvas.drawLine(
          Offset(cx + 26, benchY),
          Offset(cx + 26, floorY),
          benchPaint,
        );

        final Offset shoulder = Offset(cx - 28, benchY - 8);
        final Offset hip = Offset(cx + 16, benchY - 7);
        final Offset knee = Offset(cx + 42, benchY - 4);
        final Offset ankle = Offset(cx + 46, floorY);
        drawHead(Offset(cx - 46, benchY - 10));
        drawSegment(shoulder, hip, activeMuscle: true);
        drawSegment(hip, knee);
        drawSegment(knee, ankle);

        // Movimiento de press (depth 0 = bloqueo arriba, depth 1 = barra en pecho)
        final double barY = (benchY - 56) + (depth * 36);
        final Offset wrist = Offset(cx - 24, barY);
        final Offset elbow = Offset(
          cx - 12 + (depth * 8),
          benchY - 22 + (depth * 16),
        );
        drawSegment(shoulder, elbow, activeMuscle: true);
        drawSegment(elbow, wrist, activeMuscle: true);
        drawBarbellPlate(wrist, radius: 12);
        break;

      case BiomechanicalArchetype.squat:
      case BiomechanicalArchetype.lunge:
        final Offset ankle = Offset(cx + 4, floorY);
        final Offset knee = Offset(
          cx - 12 - (depth * 16),
          floorY - 36 + (depth * 10),
        );
        final Offset hip = Offset(
          cx + 10 + (depth * 18),
          floorY - 72 + (depth * 36),
        );
        final Offset shoulder = Offset(
          cx - 2 - (depth * 4),
          hip.dy - 40 + (depth * 6),
        );
        final Offset head = Offset(shoulder.dx - 2, shoulder.dy - 15);

        drawSegment(ankle, knee, activeMuscle: true);
        drawSegment(knee, hip, activeMuscle: true);
        drawSegment(hip, shoulder, activeMuscle: true);
        drawHead(head);
        drawBarbellPlate(Offset(shoulder.dx + 2, shoulder.dy + 2), radius: 12);
        break;

      case BiomechanicalArchetype.deadlift:
        final Offset ankle = Offset(cx, floorY);
        final Offset knee = Offset(
          cx - 6 - (depth * 10),
          floorY - 36 + (depth * 6),
        );
        final Offset hip = Offset(
          cx + 6 + (depth * 26),
          floorY - 72 + (depth * 24),
        );
        final Offset shoulder = Offset(
          cx - 2 - (depth * 14),
          hip.dy - 42 + (depth * 24),
        );
        final Offset hand = Offset(
          cx - 8,
          floorY - 58 + (depth * 36),
        );
        drawSegment(ankle, knee);
        drawSegment(knee, hip, activeMuscle: true);
        drawSegment(hip, shoulder, activeMuscle: true);
        drawSegment(shoulder, hand);
        drawHead(Offset(shoulder.dx - 6, shoulder.dy - 13));
        drawBarbellPlate(hand, radius: 13);
        break;

      case BiomechanicalArchetype.overheadPress:
        final Offset ankle = Offset(cx, floorY);
        final Offset knee = Offset(cx, floorY - 35);
        final Offset hip = Offset(cx, floorY - 70);
        final Offset shoulder = Offset(cx, floorY - 108);
        // depth 0 = bloqueo sobre cabeza, depth 1 = barra en clavícula
        final double handY = (shoulder.dy - 36) + (depth * 34);
        final Offset elbow = Offset(
          cx + 14,
          shoulder.dy - 10 + (depth * 22),
        );
        final Offset hand = Offset(cx + 4, handY);
        drawSegment(ankle, knee);
        drawSegment(knee, hip);
        drawSegment(hip, shoulder, activeMuscle: true);
        drawHead(Offset(cx - 4, shoulder.dy - 14));
        drawSegment(shoulder, elbow, activeMuscle: true);
        drawSegment(elbow, hand, activeMuscle: true);
        drawBarbellPlate(hand, radius: 10);
        break;

      case BiomechanicalArchetype.latPulldown:
        // Máquina / Barra superior
        const double topBarY = 38.0;
        canvas.drawLine(
          Offset(cx - 35, topBarY),
          Offset(cx + 35, topBarY),
          benchPaint,
        );
        final Offset hip = Offset(cx, floorY - 34);
        final Offset knee = Offset(cx + 22, floorY - 32);
        final Offset ankle = Offset(cx + 22, floorY);
        final Offset shoulder = Offset(cx - 2, floorY - 76);
        // depth 0 = contracción abajo, depth 1 = estiramiento arriba
        final Offset hand = Offset(
          cx + 4,
          (shoulder.dy + 4) - (depth * 34),
        );
        final Offset elbow = Offset(
          cx + 16,
          (shoulder.dy + 18) - (depth * 26),
        );
        drawSegment(ankle, knee);
        drawSegment(knee, hip);
        drawSegment(hip, shoulder, activeMuscle: true);
        drawHead(Offset(shoulder.dx - 4, shoulder.dy - 14));
        drawSegment(shoulder, elbow, activeMuscle: true);
        drawSegment(elbow, hand, activeMuscle: true);
        canvas.drawLine(Offset(cx + 4, topBarY), hand, barbellPaint);
        break;

      case BiomechanicalArchetype.barbellRow:
        final Offset ankle = Offset(cx, floorY);
        final Offset knee = Offset(cx - 10, floorY - 34);
        final Offset hip = Offset(cx + 20, floorY - 64);
        final Offset shoulder = Offset(cx - 14, floorY - 90);
        // depth 0 = barra en abdomen, depth 1 = brazos extendidos
        final Offset hand = Offset(
          cx - 10,
          (floorY - 66) + (depth * 26),
        );
        final Offset elbow = Offset(
          cx + 4 - (depth * 12),
          (floorY - 82) + (depth * 22),
        );
        drawSegment(ankle, knee);
        drawSegment(knee, hip);
        drawSegment(hip, shoulder, activeMuscle: true);
        drawHead(Offset(shoulder.dx - 10, shoulder.dy - 10));
        drawSegment(shoulder, elbow, activeMuscle: true);
        drawSegment(elbow, hand, activeMuscle: true);
        drawBarbellPlate(hand, radius: 11);
        break;

      case BiomechanicalArchetype.bicepCurl:
      case BiomechanicalArchetype.lateralRaise:
      case BiomechanicalArchetype.tricepExtension:
        final Offset ankle = Offset(cx, floorY);
        final Offset knee = Offset(cx, floorY - 35);
        final Offset hip = Offset(cx, floorY - 70);
        final Offset shoulder = Offset(cx, floorY - 108);
        final Offset elbow = Offset(cx + 4, floorY - 82);
        final double angle = archetype == BiomechanicalArchetype.tricepExtension
            ? (-0.9 + (depth * 1.6))
            : (0.9 - (depth * 1.6));
        final Offset hand = Offset(
          elbow.dx - math.cos(angle) * 26,
          elbow.dy - math.sin(angle) * 26,
        );
        drawSegment(ankle, knee);
        drawSegment(knee, hip);
        drawSegment(hip, shoulder);
        drawHead(Offset(cx, shoulder.dy - 15));
        drawSegment(shoulder, elbow, activeMuscle: true);
        drawSegment(elbow, hand, activeMuscle: true);
        drawBarbellPlate(hand, radius: 8.5);
        break;

      case BiomechanicalArchetype.hipThrust:
        // Apoyo escapular en banco
        final Offset benchSupport = Offset(cx - 32, floorY - 34);
        canvas.drawCircle(benchSupport, 10, benchPaint);
        final Offset shoulder = Offset(cx - 28, floorY - 40);
        final Offset hip = Offset(
          cx + 4,
          (floorY - 38) + (depth * 24),
        );
        final Offset knee = Offset(cx + 36, floorY - 36);
        final Offset ankle = Offset(cx + 36, floorY);
        drawHead(Offset(shoulder.dx - 14, shoulder.dy - 6));
        drawSegment(shoulder, hip, activeMuscle: true);
        drawSegment(hip, knee, activeMuscle: true);
        drawSegment(knee, ankle);
        drawBarbellPlate(hip, radius: 11);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _BiomechanicalAvatarPainter oldDelegate) {
    return oldDelegate.depth != depth ||
        oldDelegate.archetype != archetype ||
        oldDelegate.phaseColor != phaseColor;
  }
}
