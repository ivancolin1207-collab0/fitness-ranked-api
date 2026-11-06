import 'dart:math' as math;
import 'package:flutter/material.dart';

enum BiomechanicalArchetype {
  squat,
  benchPress,
  deadlift,
  overheadPress,
  lateralRaise,
  rearDeltFacePull,
  shrug,
  latPulldown,
  barbellRow,
  bicepCurl,
  tricepExtension,
  lunge,
  hipThrust,
}

class ExerciseMediaSpec {
  final String keyId;
  final String canonicalName;
  final String gifUrl;
  final String frame1Url;
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
  final String secondaryMuscles;
  final String jointFocusLabel;
  final double minAngleDeg;
  final double maxAngleDeg;

  const ExerciseMediaSpec({
    required this.keyId,
    required this.canonicalName,
    required this.gifUrl,
    required this.frame1Url,
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
    required this.secondaryMuscles,
    required this.jointFocusLabel,
    required this.minAngleDeg,
    required this.maxAngleDeg,
  });
}

class ExerciseMediaService {
  const ExerciseMediaService();

  static const List<ExerciseMediaSpec> _catalog = <ExerciseMediaSpec>[
    // 0: Press de Banca
    ExerciseMediaSpec(
      keyId: 'bench_press',
      canonicalName: 'Press de Banca con Barra',
      gifUrl:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Bench_Press_-_Medium_Grip/0.jpg',
      frame1Url:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Bench_Press_-_Medium_Grip/1.jpg',
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
      primaryMuscles: 'Pectoral Mayor • Deltoides Anterior',
      secondaryMuscles: 'Tríceps Braquial • Serrato Anterior',
      jointFocusLabel: 'Hombro 45° • Arco Torácico Estable',
      minAngleDeg: 78,
      maxAngleDeg: 175,
    ),
    // 1: Sentadilla Libre
    ExerciseMediaSpec(
      keyId: 'squat',
      canonicalName: 'Sentadilla Libre con Barra (Back Squat)',
      gifUrl:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Full_Squat/0.jpg',
      frame1Url:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Full_Squat/1.jpg',
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
      primaryMuscles: 'Cuádriceps • Glúteo Mayor',
      secondaryMuscles: 'Core 360° • Erectores Espinales',
      jointFocusLabel: 'Flexión Cadera/Rodilla >95° • Columna Neutra',
      minAngleDeg: 82,
      maxAngleDeg: 176,
    ),
    // 2: Peso Muerto / RDL
    ExerciseMediaSpec(
      keyId: 'deadlift_barbell',
      canonicalName: 'Peso Muerto Rumano (RDL) / Convencional',
      gifUrl:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Romanian_Deadlift/0.jpg',
      frame1Url:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Romanian_Deadlift/1.jpg',
      archetype: BiomechanicalArchetype.deadlift,
      prescribedTempoCode: '3-1-1-0',
      prescribedTempoDetail: '3 seg bisagra excéntrica, 1 pausa en estiramiento, 1 subida',
      eccentricSec: 3,
      pauseBottomSec: 1,
      concentricSec: 1,
      pauseTopSec: 0,
      activationCue:
          'Barra pegada a las tibias, cadera atrás con columna neutra y empuja el piso',
      defaultTargetRange: 'RPE 8.0 | 8-10 reps según tu recuperación de hoy',
      primaryMuscles: 'Isquiosurales • Glúteo Mayor',
      secondaryMuscles: 'Erectores Espinales • Dorsal Ancho',
      jointFocusLabel: 'Bisagra de Cadera • Tibia Vertical',
      minAngleDeg: 75,
      maxAngleDeg: 178,
    ),
    // 3: Press Militar (military_press / overhead_press_barbell)
    ExerciseMediaSpec(
      keyId: 'military_press',
      canonicalName: 'Press Militar con Barra / Mancuernas',
      gifUrl:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Standing_Military_Press/0.jpg',
      frame1Url:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Standing_Military_Press/1.jpg',
      archetype: BiomechanicalArchetype.overheadPress,
      prescribedTempoCode: '2-0-1-1',
      prescribedTempoDetail: '2 seg bajada, 0 pausa, 1 subida explosiva, 1 bloqueo',
      eccentricSec: 2,
      pauseBottomSec: 0,
      concentricSec: 1,
      pauseTopSec: 1,
      activationCue:
          'Abdomen y glúteos firmes, antebrazos verticales y trayectoria recta sobre corona',
      defaultTargetRange: 'RPE 8.0 | 8-10 reps según tu recuperación de hoy',
      primaryMuscles: 'Deltoides Anterior/Medio • Tríceps',
      secondaryMuscles: 'Trapecio Superior • Core Estabilizador',
      jointFocusLabel: 'Trayectoria Vertical • Escápula Rot. Superior',
      minAngleDeg: 72,
      maxAngleDeg: 178,
    ),
    // 4: Jalón al Pecho / Dominadas (lat_pulldown)
    ExerciseMediaSpec(
      keyId: 'lat_pulldown',
      canonicalName: 'Jalón al Pecho / Dominadas Pronas',
      gifUrl:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Wide-Grip_Lat_Pulldown/0.jpg',
      frame1Url:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Wide-Grip_Lat_Pulldown/1.jpg',
      archetype: BiomechanicalArchetype.latPulldown,
      prescribedTempoCode: '3-0-1-1',
      prescribedTempoDetail: '3 seg retorno controlado, 1 tracción, 1 iso abajo',
      eccentricSec: 3,
      pauseBottomSec: 0,
      concentricSec: 1,
      pauseTopSec: 1,
      activationCue:
          'Inicia con depresión escapular y conduce los codos hacia tus bolsillos',
      defaultTargetRange: 'RPE 8.0 | 8-12 reps según tu recuperación de hoy',
      primaryMuscles: 'Dorsal Ancho • Redondo Mayor',
      secondaryMuscles: 'Bíceps Braquial • Romboides',
      jointFocusLabel: 'Retracción/Depresión Escapular • Tracción Vertical',
      minAngleDeg: 58,
      maxAngleDeg: 172,
    ),
    // 5: Remo con Barra / Polea (barbell_row)
    ExerciseMediaSpec(
      keyId: 'barbell_row',
      canonicalName: 'Remo con Barra / Polea Baja',
      gifUrl:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Bent_Over_Barbell_Row/0.jpg',
      frame1Url:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Bent_Over_Barbell_Row/1.jpg',
      archetype: BiomechanicalArchetype.barbellRow,
      prescribedTempoCode: '2-0-1-1',
      prescribedTempoDetail: '2 seg bajada, 0 pausa, 1 tracción, 1 contracción',
      eccentricSec: 2,
      pauseBottomSec: 0,
      concentricSec: 1,
      pauseTopSec: 1,
      activationCue:
          'Torso a 45° estable, tracciona hacia el abdomen bajo apretando romboides',
      defaultTargetRange: 'RPE 8.0 | 8-10 reps según tu recuperación de hoy',
      primaryMuscles: 'Dorsal Ancho • Romboides',
      secondaryMuscles: 'Trapecio Medio • Deltoides Posterior',
      jointFocusLabel: 'Torso 45° • Retracción Escapular Completa',
      minAngleDeg: 68,
      maxAngleDeg: 166,
    ),
    // 6: Curl de Bíceps (bicep_curl)
    ExerciseMediaSpec(
      keyId: 'bicep_curl',
      canonicalName: 'Curl de Bíceps con Barra EZ / Mancuernas',
      gifUrl:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Curl/0.jpg',
      frame1Url:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Curl/1.jpg',
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
      primaryMuscles: 'Bíceps Braquial • Braquial Anterior',
      secondaryMuscles: 'Braquiorradial • Flexores de Antebrazo',
      jointFocusLabel: 'Húmero Fijo • Flexión de Codo Pura',
      minAngleDeg: 45,
      maxAngleDeg: 165,
    ),
    // 7: Elevaciones Laterales (lateral_raise)
    ExerciseMediaSpec(
      keyId: 'lateral_raise',
      canonicalName: 'Elevaciones Laterales con Mancuernas',
      gifUrl:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Side_Lateral_Raise/0.jpg',
      frame1Url:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Side_Lateral_Raise/1.jpg',
      archetype: BiomechanicalArchetype.lateralRaise,
      prescribedTempoCode: '3-0-1-1',
      prescribedTempoDetail: '3 seg bajada controlada, 1 subida, 1 iso arriba',
      eccentricSec: 3,
      pauseBottomSec: 0,
      concentricSec: 1,
      pauseTopSec: 1,
      activationCue:
          'Eleva en plano escapular (30°) guiando con los codos sin encoger trapecios',
      defaultTargetRange: 'RPE 8.5 | 12-15 reps según tu recuperación de hoy',
      primaryMuscles: 'Deltoides Lateral • Supraespinoso',
      secondaryMuscles: 'Serrato Anterior • Trapecio Estabilizador',
      jointFocusLabel: '30° Plano Escapular • Abducción 90°',
      minAngleDeg: 15,
      maxAngleDeg: 92,
    ),
    // 8: Extensión de Tríceps (tricep_extension)
    ExerciseMediaSpec(
      keyId: 'tricep_extension',
      canonicalName: 'Extensión de Tríceps en Polea / Press Francés',
      gifUrl:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Triceps_Pushdown_-_Rope_Attachment/0.jpg',
      frame1Url:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Triceps_Pushdown_-_Rope_Attachment/1.jpg',
      archetype: BiomechanicalArchetype.tricepExtension,
      prescribedTempoCode: '2-0-1-1',
      prescribedTempoDetail: '2 seg fase excéntrica, 1 extensión, 1 bloqueo',
      eccentricSec: 2,
      pauseBottomSec: 0,
      concentricSec: 1,
      pauseTopSec: 1,
      activationCue:
          'Bloquea los húmeros junto al torso y abre la cuerda al final de la extensión',
      defaultTargetRange: 'RPE 8.5 | 10-12 reps según tu recuperación de hoy',
      primaryMuscles: 'Tríceps Braquial (Cabeza Lateral y Larga)',
      secondaryMuscles: 'Cabeza Medial del Tríceps • Ancóneo',
      jointFocusLabel: 'Codo Fijo • Extensión Aislada 180°',
      minAngleDeg: 65,
      maxAngleDeg: 176,
    ),
    // 9: Sentadilla Búlgara / Zancadas (lunge)
    ExerciseMediaSpec(
      keyId: 'bulgarian_split_squat',
      canonicalName: 'Sentadilla Búlgara / Zancadas con Mancuernas',
      gifUrl:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dumbbell_Lunges/0.jpg',
      frame1Url:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dumbbell_Lunges/1.jpg',
      archetype: BiomechanicalArchetype.lunge,
      prescribedTempoCode: '3-1-1-0',
      prescribedTempoDetail: '3 seg descenso, 1 pausa abajo, 1 subida firme',
      eccentricSec: 3,
      pauseBottomSec: 1,
      concentricSec: 1,
      pauseTopSec: 0,
      activationCue:
          'Inclina ligeramente el torso al frente y empuja con el talón delantero',
      defaultTargetRange: 'RPE 8.5 | 8-10 reps según tu recuperación de hoy',
      primaryMuscles: 'Cuádriceps Unilateral • Glúteo Mayor',
      secondaryMuscles: 'Glúteo Medio • Aductores',
      jointFocusLabel: 'Estabilidad Unilateral • Rodilla 90°',
      minAngleDeg: 85,
      maxAngleDeg: 172,
    ),
    // 10: Hip Thrust (hip_thrust)
    ExerciseMediaSpec(
      keyId: 'hip_thrust',
      canonicalName: 'Hip Thrust con Barra Olímpica',
      gifUrl:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Glute_Bridge/0.jpg',
      frame1Url:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Glute_Bridge/1.jpg',
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
      primaryMuscles: 'Glúteo Mayor • Glúteo Medio',
      secondaryMuscles: 'Isquiosurales • Core Pélvico',
      jointFocusLabel: 'Extensión Cadera 180° • Tibia Vertical 90°',
      minAngleDeg: 95,
      maxAngleDeg: 180,
    ),
    // 11: Face Pulls / Pájaros en Polea (rear_delt_fly / face_pull)
    ExerciseMediaSpec(
      keyId: 'face_pull',
      canonicalName: 'Face Pulls / Pájaros en Polea Alta',
      gifUrl:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Face_Pull/0.jpg',
      frame1Url:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Face_Pull/1.jpg',
      archetype: BiomechanicalArchetype.rearDeltFacePull,
      prescribedTempoCode: '2-0-1-2',
      prescribedTempoDetail: '2 seg retorno, 1 tracción externa, 2 seg iso atrás',
      eccentricSec: 2,
      pauseBottomSec: 0,
      concentricSec: 1,
      pauseTopSec: 2,
      activationCue:
          'Tracciona hacia la frente separando las manos en rotación externa de hombro',
      defaultTargetRange: 'RPE 8.5 | 12-15 reps según tu recuperación de hoy',
      primaryMuscles: 'Deltoides Posterior • Infraespinoso',
      secondaryMuscles: 'Romboides • Trapecio Medio/Inferior',
      jointFocusLabel: 'Rotación Externa 90° • Escápula Retraída',
      minAngleDeg: 40,
      maxAngleDeg: 95,
    ),
    // 12: Encogimientos de Trapecio (dumbbell_shrug)
    ExerciseMediaSpec(
      keyId: 'dumbbell_shrug',
      canonicalName: 'Encogimientos de Trapecio con Mancuernas',
      gifUrl:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dumbbell_Shrug/0.jpg',
      frame1Url:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dumbbell_Shrug/1.jpg',
      archetype: BiomechanicalArchetype.shrug,
      prescribedTempoCode: '2-0-1-2',
      prescribedTempoDetail: '2 seg estiramiento, 1 elevación, 2 seg pausa arriba',
      eccentricSec: 2,
      pauseBottomSec: 0,
      concentricSec: 1,
      pauseTopSec: 2,
      activationCue:
          'Eleva los hombros verticalmente hacia las orejas y sostén 2 segundos arriba',
      defaultTargetRange: 'RPE 8.5 | 10-12 reps según tu recuperación de hoy',
      primaryMuscles: 'Trapecio Superior • Elevador Escapular',
      secondaryMuscles: 'Romboides • Agarre Isométrico',
      jointFocusLabel: 'Elevación Escapular Vertical • Pausa 2s',
      minAngleDeg: 10,
      maxAngleDeg: 45,
    ),
  ];

  static ExerciseMediaSpec resolveForExercise(
    String rawName, {
    String? exerciseKey,
  }) {
    final String key = (exerciseKey ?? '').toLowerCase().trim();
    final String q = rawName.toLowerCase().trim();

    // 1. Face Pulls / Deltoides Posterior (prioridad alta antes que "polea" genérico)
    if (key.contains('rear_delt') ||
        key.contains('face_pull') ||
        q.contains('face pull') ||
        q.contains('pájaro') ||
        q.contains('pajaro') ||
        q.contains('posterior')) {
      return _catalog[11];
    }

    // 2. Encogimientos de Trapecio
    if (key.contains('shrug') ||
        q.contains('encogimiento') ||
        q.contains('shrug') ||
        (q.contains('trapecio') && !q.contains('remo'))) {
      return _catalog[12];
    }

    // 3. Elevaciones Laterales
    if (key.contains('lateral_raise') ||
        q.contains('elevaciones laterales') ||
        q.contains('elevación lateral') ||
        q.contains('vuelos laterales') ||
        q.contains('lateral')) {
      return _catalog[7];
    }

    // 4. Press Militar / Overhead Press
    if (key.contains('overhead_press') ||
        key.contains('military_press') ||
        key.contains('shoulder_press') ||
        q.contains('militar') ||
        q.contains('overhead') ||
        q.contains('ohp') ||
        q.contains('shoulder press') ||
        q.contains('arnold') ||
        (q.contains('press') && q.contains('hombro'))) {
      return _catalog[3];
    }

    // 5. Jalón al Pecho / Dominadas
    if (key.contains('lat_pulldown') ||
        key.contains('pulldown') ||
        key.contains('pull_up') ||
        q.contains('jalón') ||
        q.contains('jalon') ||
        q.contains('dominada') ||
        q.contains('lat pulldown')) {
      return _catalog[4];
    }

    // 6. Remo con Barra / Polea
    if (key.contains('row') ||
        q.contains('remo') ||
        q.contains('pendlay') ||
        q.contains('row')) {
      return _catalog[5];
    }

    // 7. Press de Banca / Inclinado / Fondos
    if (key.contains('bench') ||
        key.contains('chest') ||
        key.contains('incline_dumbbell_press') ||
        key.contains('pec') ||
        key.contains('dip') ||
        q.contains('banca') ||
        q.contains('bench') ||
        q.contains('inclinado') ||
        q.contains('pecho') ||
        q.contains('fondo') ||
        q.contains('apertura')) {
      return _catalog[0];
    }

    // 8. Hip Thrust / Puente de Glúteo
    if (key.contains('hip_thrust') ||
        key.contains('glute') ||
        q.contains('hip thrust') ||
        q.contains('puente') ||
        (q.contains('glúteo') && !q.contains('sentadilla'))) {
      return _catalog[10];
    }

    // 9. Sentadilla Búlgara / Zancadas
    if (key.contains('split_squat') ||
        key.contains('lunge') ||
        q.contains('búlgara') ||
        q.contains('bulgara') ||
        q.contains('zancada') ||
        q.contains('lunge')) {
      return _catalog[9];
    }

    // 10. Sentadilla Libre / Prensa / Extensión Cuádriceps / Gemelos
    if (key.contains('squat') ||
        key.contains('leg_press') ||
        key.contains('leg_extension') ||
        key.contains('calf') ||
        q.contains('sentadilla') ||
        q.contains('squat') ||
        q.contains('prensa') ||
        q.contains('cuádriceps') ||
        q.contains('cuadriceps') ||
        q.contains('talones') ||
        q.contains('gemelo') ||
        q.contains('sóleo') ||
        q.contains('soleo')) {
      return _catalog[1];
    }

    // 11. Peso Muerto / RDL / Curl Femoral / Hiperextensiones
    if (key.contains('deadlift') ||
        key.contains('rdl') ||
        key.contains('leg_curl') ||
        key.contains('hyperextension') ||
        q.contains('peso muerto') ||
        q.contains('rumano') ||
        q.contains('rdl') ||
        q.contains('femoral') ||
        q.contains('isquio') ||
        q.contains('hiperext')) {
      return _catalog[2];
    }

    // 12. Curl de Bíceps / Martillo
    if (key.contains('bicep') ||
        key.contains('hammer_curl') ||
        key.contains('dumbbell_curl') ||
        key.contains('curl_barbell') ||
        q.contains('curl') ||
        q.contains('bíceps') ||
        q.contains('biceps') ||
        q.contains('martillo')) {
      return _catalog[6];
    }

    // 13. Extensión de Tríceps / Press Francés
    if (key.contains('tricep') ||
        key.contains('french_press') ||
        key.contains('pushdown') ||
        q.contains('tríceps') ||
        q.contains('triceps') ||
        q.contains('francés') ||
        q.contains('frances') ||
        q.contains('cuerda')) {
      return _catalog[8];
    }

    return _catalog[3];
  }

  static String activationHeadlineFor(ExerciseMediaSpec spec) {
    switch (spec.archetype) {
      case BiomechanicalArchetype.benchPress:
        return 'Retracción Escapular Activa';
      case BiomechanicalArchetype.squat:
        return 'Bracing Abdominal 360° y Rodillas Alineadas';
      case BiomechanicalArchetype.deadlift:
        return 'Bisagra de Cadera y Dorsal Compacto';
      case BiomechanicalArchetype.overheadPress:
        return 'Estabilidad Lumbo-Pélvica y Empuje Vertical';
      case BiomechanicalArchetype.latPulldown:
        return 'Depresión Escapular Previa a la Tracción';
      case BiomechanicalArchetype.barbellRow:
        return 'Retracción de Romboides con Torso a 45°';
      case BiomechanicalArchetype.bicepCurl:
        return 'Flexión Pura de Codo con Húmero Fijo';
      case BiomechanicalArchetype.lateralRaise:
        return 'Abducción en Plano Escapular (30°)';
      case BiomechanicalArchetype.tricepExtension:
        return 'Bloqueo de Húmero y Extensión Completa';
      case BiomechanicalArchetype.lunge:
        return 'Control Unilateral de Cadera y Rodilla';
      case BiomechanicalArchetype.hipThrust:
        return 'Retroversión Pélvica y Tibia a 90°';
      case BiomechanicalArchetype.rearDeltFacePull:
        return 'Rotación Externa de Hombro a 90°';
      case BiomechanicalArchetype.shrug:
        return 'Elevación Escapular Vertical con Pausa';
    }
  }

  static String jointShortCueFor(ExerciseMediaSpec spec) {
    switch (spec.archetype) {
      case BiomechanicalArchetype.benchPress:
        return 'Codos a 45°';
      case BiomechanicalArchetype.squat:
        return 'Columna Neutra';
      case BiomechanicalArchetype.deadlift:
        return 'Tibia Vertical';
      case BiomechanicalArchetype.overheadPress:
        return 'Plano Escapular';
      case BiomechanicalArchetype.latPulldown:
        return 'Tracción Vertical';
      case BiomechanicalArchetype.barbellRow:
        return 'Torso a 45°';
      case BiomechanicalArchetype.bicepCurl:
        return 'Húmero Fijo';
      case BiomechanicalArchetype.lateralRaise:
        return '30° Escapular';
      case BiomechanicalArchetype.tricepExtension:
        return 'Codo Fijo';
      case BiomechanicalArchetype.lunge:
        return 'Rodilla Alineada';
      case BiomechanicalArchetype.hipThrust:
        return 'Tibia a 90°';
      case BiomechanicalArchetype.rearDeltFacePull:
        return 'Rot. Externa 90°';
      case BiomechanicalArchetype.shrug:
        return 'Escápula Elevada';
    }
  }

  static String formatTargetRange({
    required ExerciseMediaSpec spec,
    double? recoveryScore,
    int? targetReps,
    String? targetRepsRange,
    double? prescribedRpe,
  }) {
    final double rpe = prescribedRpe ??
        (recoveryScore != null
            ? (recoveryScore < 34.0
                ? 6.5
                : (recoveryScore >= 67.0 ? 8.5 : 8.0))
            : 8.0);
    final String repsRange =
        (targetRepsRange != null && targetRepsRange.trim().isNotEmpty)
            ? '${targetRepsRange.trim()} REPS'
            : (targetReps != null
                ? '${math.max(4, targetReps - 1)}-${targetReps + 1} REPS'
                : '8-10 REPS');
    return 'RPE ${rpe.toStringAsFixed(1)} • $repsRange';
  }
}

/// Visor Biomecánico 3D / HD Desacoplado por Capas Verticales Limpias:
/// 1. Cabecera del Visor (Barra Superior con Tag #F59E0B y Selector [3D / GIF] | [FOTO REAL])
/// 2. Stage Central Libre de 230dp (#0E121A, borde #222733, sin cajas flotantes sobre el modelo)
/// 3. Banda Técnica de Telemetría Muscular en 2 Columnas (Músculo Primario + Ángulo Articular)
/// 4. Tarjetas Modulares de Parámetros Técnicos (Tempo, Activación y Prescripción IA)
class BiomechanicalExerciseAvatarModule extends StatefulWidget {
  final String exerciseName;
  final String? exerciseKey;
  final double? recoveryScore;
  final double? lbmKg;
  final int? targetReps;
  final String? targetRepsRange;
  final double? prescribedRpe;
  final String? customTempo;
  final String? customCoachingCue;

  const BiomechanicalExerciseAvatarModule({
    super.key,
    required this.exerciseName,
    this.exerciseKey,
    this.recoveryScore,
    this.lbmKg,
    this.targetReps,
    this.targetRepsRange,
    this.prescribedRpe,
    this.customTempo,
    this.customCoachingCue,
  });

  @override
  State<BiomechanicalExerciseAvatarModule> createState() =>
      _BiomechanicalExerciseAvatarModuleState();
}

class _BiomechanicalExerciseAvatarModuleState
    extends State<BiomechanicalExerciseAvatarModule>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _showRealPhotoMode = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant BiomechanicalExerciseAvatarModule oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exerciseName != widget.exerciseName ||
        oldWidget.exerciseKey != widget.exerciseKey) {
      _controller
        ..reset()
        ..repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ({
    double depth,
    String phaseSubtitle,
    String movementWord,
    Color phaseColor,
    double jointAngleDeg,
  }) _evaluatePhase(double t, ExerciseMediaSpec spec) {
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

    double depth;
    String phaseSubtitle;
    String movementWord;
    Color phaseColor;

    if (sec <= eccEnd) {
      final double p = (sec / math.max(0.5, eccEnd)).clamp(0.0, 1.0);
      depth = Curves.easeInOutCubic.transform(p);
      phaseSubtitle = 'Fase excéntrica controlada (${spec.eccentricSec}s)';
      movementWord = 'Flexión';
      phaseColor = const Color(0xFF00E5FF);
    } else if (sec <= bottomEnd) {
      depth = 1.0;
      phaseSubtitle = 'Pausa isométrica inferior (${spec.pauseBottomSec}s)';
      movementWord = 'Isometría';
      phaseColor = const Color(0xFFF59E0B);
    } else if (sec <= concEnd) {
      final double p =
          ((sec - bottomEnd) / math.max(0.5, spec.concentricSec)).clamp(0.0, 1.0);
      depth = 1.0 - Curves.easeOutCubic.transform(p).clamp(0.0, 1.0);
      phaseSubtitle = 'Fase concéntrica activa (${spec.concentricSec}s)';
      movementWord = 'Extensión';
      phaseColor = const Color(0xFFD2FF00);
    } else {
      depth = 0.0;
      phaseSubtitle = 'Contracción máxima superior (${spec.pauseTopSec}s)';
      movementWord = 'Bloqueo';
      phaseColor = const Color(0xFF10B981);
    }

    final double angle =
        spec.maxAngleDeg - ((spec.maxAngleDeg - spec.minAngleDeg) * depth);

    return (
      depth: depth,
      phaseSubtitle: phaseSubtitle,
      movementWord: movementWord,
      phaseColor: phaseColor,
      jointAngleDeg: angle,
    );
  }

  Widget _buildTelemetryRow({
    required IconData icon,
    required Color accentColor,
    required String label,
    required String primaryValue,
    required String secondaryDescription,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: const Color(0xFF14171E),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: const Color(0xFF222733)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18.0, color: accentColor),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2.0),
                Text(
                  primaryValue,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (secondaryDescription.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2.0),
                  Text(
                    secondaryDescription,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ExerciseMediaSpec spec = ExerciseMediaService.resolveForExercise(
      widget.exerciseName,
      exerciseKey: widget.exerciseKey,
    );
    final String tempoCode =
        (widget.customTempo != null && widget.customTempo!.trim().isNotEmpty)
            ? widget.customTempo!.trim()
            : spec.prescribedTempoCode;
    final String cueText = (widget.customCoachingCue != null &&
            widget.customCoachingCue!.trim().isNotEmpty)
        ? widget.customCoachingCue!.trim()
        : spec.activationCue;
    final String activationHeadline =
        ExerciseMediaService.activationHeadlineFor(spec);
    final String jointShortCue = ExerciseMediaService.jointShortCueFor(spec);
    final String targetPrimary = ExerciseMediaService.formatTargetRange(
      spec: spec,
      recoveryScore: widget.recoveryScore,
      targetReps: widget.targetReps,
      targetRepsRange: widget.targetRepsRange,
      prescribedRpe: widget.prescribedRpe,
    );
    final double effectiveLbm = widget.lbmKg ?? 62.7;
    final int effectiveRec = (widget.recoveryScore ?? 47.0).round();
    final String targetSecondary =
        'Carga calculada para ${effectiveLbm.toStringAsFixed(1)} kg LBM con $effectiveRec% de recuperación';

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, _) {
        final phase = _evaluatePhase(_controller.value, spec);
        final String activeFrameUrl =
            phase.depth > 0.48 ? spec.frame1Url : spec.gifUrl;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // 1. Cabecera del Visor (Barra Superior limpia fuera del Canvas)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14171E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.65),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.document_scanner_outlined,
                        size: 13,
                        color: Color(0xFFF59E0B),
                      ),
                      SizedBox(width: 5),
                      Text(
                        'VISOR BIOMECÁNICO 3D',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFF59E0B),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    InkWell(
                      borderRadius: BorderRadius.circular(7),
                      onTap: () {
                        setState(() {
                          _showRealPhotoMode = false;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: !_showRealPhotoMode
                              ? const Color(0xFF1E232E)
                              : const Color(0xFF14171E),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: !_showRealPhotoMode
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF222733),
                          ),
                        ),
                        child: Text(
                          '3D / GIF',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: !_showRealPhotoMode
                                ? Colors.white
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(7),
                      onTap: () {
                        setState(() {
                          _showRealPhotoMode = true;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _showRealPhotoMode
                              ? const Color(0xFF1E232E)
                              : const Color(0xFF14171E),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: _showRealPhotoMode
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF222733),
                          ),
                        ),
                        child: Text(
                          'FOTO REAL',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _showRealPhotoMode
                                ? Colors.white
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 2. Stage Central del Modelo / Avatar (230dp, Zona 100% Libre de cajas flotantes)
            Container(
              height: 230,
              decoration: BoxDecoration(
                color: const Color(0xFF0E121A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF222733),
                  width: 1.2,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  if (!_showRealPhotoMode)
                    CustomPaint(
                      painter: _Biomechanical3DVisualizerPainter(
                        archetype: spec.archetype,
                        depth: phase.depth,
                        phaseColor: phase.phaseColor,
                        jointAngleDeg: phase.jointAngleDeg,
                        pulseValue: _controller.value,
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          activeFrameUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => CustomPaint(
                            painter: _Biomechanical3DVisualizerPainter(
                              archetype: spec.archetype,
                              depth: phase.depth,
                              phaseColor: phase.phaseColor,
                              jointAngleDeg: phase.jointAngleDeg,
                              pulseValue: _controller.value,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Únicamente una barra inferior discreta de 1 línea en la base del canvas
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B0E14).withValues(alpha: 0.86),
                        border: const Border(
                          top: BorderSide(color: Color(0xFF222733)),
                        ),
                      ),
                      child: Text(
                        '${spec.canonicalName} • ${spec.jointFocusLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 3. Banda Técnica de Telemetría Muscular (Debajo del Canvas, NO encima)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF14171E),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF222733)),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Columna Izquierda (Activación)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'MÚSCULO PRIMARIO',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            spec.primaryMuscles,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Sinergistas: ${spec.secondaryMuscles}',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      color: const Color(0xFF222733),
                    ),
                    // Columna Derecha (Dinámica)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'ÁNGULO ARTICULAR',
                            style: TextStyle(
                              color: Color(0xFFF59E0B),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${phase.jointAngleDeg.round()}° ${phase.movementWord} • $jointShortCue',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            phase.phaseSubtitle,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // 4. Tarjetas Modulares de Cues y Parámetros Técnicos
            _buildTelemetryRow(
              icon: Icons.timer_outlined,
              accentColor: const Color(0xFFD2FF00),
              label: 'TEMPO PRESCRITO',
              primaryValue: 'TEMPO: $tempoCode',
              secondaryDescription: spec.prescribedTempoDetail,
            ),
            _buildTelemetryRow(
              icon: Icons.psychology_alt_outlined,
              accentColor: const Color(0xFF00E5FF),
              label: 'ACTIVACIÓN BIOMECÁNICA',
              primaryValue: activationHeadline,
              secondaryDescription: cueText,
            ),
            _buildTelemetryRow(
              icon: Icons.track_changes_rounded,
              accentColor: const Color(0xFF10B981),
              label: 'PRESCRIPCIÓN IA',
              primaryValue: targetPrimary,
              secondaryDescription: targetSecondary,
            ),
          ],
        );
      },
    );
  }
}

/// Motor de Renderizado Anatómico Volumétrico 3D con sombreado cilíndrico/radial,
/// iluminación de fibras musculares activas, trayectoria de barra y goniómetro.
class _Biomechanical3DVisualizerPainter extends CustomPainter {
  final BiomechanicalArchetype archetype;
  final double depth;
  final Color phaseColor;
  final double jointAngleDeg;
  final double pulseValue;

  const _Biomechanical3DVisualizerPainter({
    required this.archetype,
    required this.depth,
    required this.phaseColor,
    required this.jointAngleDeg,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width * 0.50;
    final double floorY = size.height - 46.0;

    // 1. Escenario 3D: Spotlight radial + plataforma de perspectiva isométrica
    final Rect stageGlowRect = Rect.fromCenter(
      center: Offset(cx, floorY - 38),
      width: 210,
      height: 150,
    );
    canvas.drawOval(
      stageGlowRect,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            phaseColor.withValues(alpha: 0.16),
            const Color(0xFF00E5FF).withValues(alpha: 0.05),
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.55, 1.0],
        ).createShader(stageGlowRect),
    );

    // Plataforma 3D elíptica en el suelo
    final Rect platformRect = Rect.fromCenter(
      center: Offset(cx, floorY),
      width: 156,
      height: 22,
    );
    canvas.drawOval(
      platformRect,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            const Color(0xFF1E293B).withValues(alpha: 0.9),
            const Color(0xFF0F172A).withValues(alpha: 0.4),
          ],
        ).createShader(platformRect),
    );
    canvas.drawOval(
      platformRect,
      Paint()
        ..color = phaseColor.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // Líneas de perspectiva en la plataforma
    final Paint gridPaint = Paint()
      ..color = const Color(0xFF334155).withValues(alpha: 0.35)
      ..strokeWidth = 0.8;
    for (int i = -3; i <= 3; i++) {
      canvas.drawLine(
        Offset(cx + (i * 16), floorY - 9),
        Offset(cx + (i * 24), floorY + 9),
        gridPaint,
      );
    }

    final double pulse = 0.75 + 0.25 * math.sin(pulseValue * math.pi * 4);

    // Helper: Dibuja un segmento muscular volumétrico 3D (huso anatómico esculpido)
    void drawLimb3D(
      Offset start,
      Offset end, {
      double startRadius = 6.5,
      double bellyRadius = 10.5,
      double endRadius = 5.5,
      bool isPrimaryMuscle = false,
      bool isSecondaryMuscle = false,
    }) {
      final Offset delta = end - start;
      final double len = delta.distance;
      if (len < 1.0) return;
      final Offset dir = delta / len;
      final Offset normal = Offset(-dir.dy, dir.dx);
      final Offset mid = start + dir * (len * 0.46);

      // Halo bioluminiscente externo si el músculo está activo
      if (isPrimaryMuscle || isSecondaryMuscle) {
        final Color glowColor =
            isPrimaryMuscle ? phaseColor : const Color(0xFF00E5FF);
        final double glowAlpha =
            (isPrimaryMuscle ? 0.36 : 0.20) * pulse;
        canvas.drawLine(
          start,
          end,
          Paint()
            ..color = glowColor.withValues(alpha: glowAlpha)
            ..strokeWidth = bellyRadius * 2.5
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
        );
      }

      // Contorno anatómico fusiforme 3D (vientre muscular esculpido)
      final Path musclePath = Path()
        ..moveTo(
          start.dx + normal.dx * startRadius,
          start.dy + normal.dy * startRadius,
        )
        ..quadraticBezierTo(
          mid.dx + normal.dx * bellyRadius,
          mid.dy + normal.dy * bellyRadius,
          end.dx + normal.dx * endRadius,
          end.dy + normal.dy * endRadius,
        )
        ..lineTo(
          end.dx - normal.dx * endRadius,
          end.dy - normal.dy * endRadius,
        )
        ..quadraticBezierTo(
          mid.dx - normal.dx * bellyRadius,
          mid.dy - normal.dy * bellyRadius,
          start.dx - normal.dx * startRadius,
          start.dy - normal.dy * startRadius,
        )
        ..close();

      final List<Color> gradientColors = isPrimaryMuscle
          ? <Color>[
              Colors.white.withValues(alpha: 0.92),
              phaseColor,
              phaseColor.withValues(alpha: 0.55),
              const Color(0xFF0F172A),
            ]
          : isSecondaryMuscle
              ? <Color>[
                  const Color(0xFFE0F7FA),
                  const Color(0xFF00E5FF).withValues(alpha: 0.85),
                  const Color(0xFF1E293B),
                ]
              : <Color>[
                  const Color(0xFF94A3B8),
                  const Color(0xFF475569),
                  const Color(0xFF1E293B),
                ];

      final Rect bounds = musclePath.getBounds().inflate(6);
      canvas.drawPath(
        musclePath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment(normal.dx, normal.dy),
            end: Alignment(-normal.dx, -normal.dy),
            colors: gradientColors,
          ).createShader(bounds),
      );

      // Estriaciones de fibras musculares e iluminación especular 3D
      canvas.drawLine(
        start + normal * (bellyRadius * 0.28),
        end + normal * (endRadius * 0.28),
        Paint()
          ..color = Colors.white
              .withValues(alpha: isPrimaryMuscle ? 0.55 : 0.22)
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round,
      );

      // Articulaciones esféricas 3D
      for (final Offset j in <Offset>[start, end]) {
        canvas.drawCircle(
          j,
          4.2,
          Paint()
            ..color = isPrimaryMuscle
                ? phaseColor
                : const Color(0xFF64748B),
        );
        canvas.drawCircle(
          j - const Offset(1.0, 1.0),
          1.6,
          Paint()..color = Colors.white.withValues(alpha: 0.8),
        );
      }
    }

    // Helper: Dibuja torso anatómico 3D esculpido (Pectoral, Dorsal, Core)
    void drawSculptedTorso3D(
      Offset hip,
      Offset shoulder, {
      bool highlightChest = false,
      bool highlightLats = false,
      bool highlightCore = false,
      bool highlightTraps = false,
      bool frontalView = false,
    }) {
      final double shWidth = frontalView ? 22.0 : 13.0;
      final double waistWidth = frontalView ? 13.5 : 9.5;
      final Offset delta = shoulder - hip;
      final double len = delta.distance;
      if (len < 1.0) return;
      final Offset dir = delta / len;
      final Offset normal = Offset(-dir.dy, dir.dx);

      final Path torsoPath = Path()
        ..moveTo(
          hip.dx - normal.dx * waistWidth,
          hip.dy - normal.dy * waistWidth,
        )
        ..quadraticBezierTo(
          (hip.dx + shoulder.dx) * 0.5 - normal.dx * (shWidth * 1.05),
          (hip.dy + shoulder.dy) * 0.5 - normal.dy * (shWidth * 1.05),
          shoulder.dx - normal.dx * shWidth,
          shoulder.dy - normal.dy * shWidth,
        )
        ..lineTo(
          shoulder.dx + normal.dx * shWidth,
          shoulder.dy + normal.dy * shWidth,
        )
        ..quadraticBezierTo(
          (hip.dx + shoulder.dx) * 0.5 + normal.dx * (shWidth * 1.05),
          (hip.dy + shoulder.dy) * 0.5 + normal.dy * (shWidth * 1.05),
          hip.dx + normal.dx * waistWidth,
          hip.dy + normal.dy * waistWidth,
        )
        ..close();

      final Rect torsoBounds = torsoPath.getBounds().inflate(8);
      canvas.drawPath(
        torsoPath,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF64748B),
              Color(0xFF334155),
              Color(0xFF0F172A),
            ],
          ).createShader(torsoBounds),
      );
      canvas.drawPath(
        torsoPath,
        Paint()
          ..color = const Color(0xFF94A3B8).withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1,
      );

      // Iluminación específica de Pectoral Mayor
      if (highlightChest) {
        final Offset chestCenter = shoulder + (hip - shoulder) * 0.28;
        final Rect pecRect = Rect.fromCenter(
          center: chestCenter,
          width: frontalView ? 34 : 20,
          height: 16,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(pecRect, const Radius.circular(6)),
          Paint()
            ..shader = RadialGradient(
              colors: <Color>[
                Colors.white.withValues(alpha: 0.9),
                phaseColor.withValues(alpha: 0.85 * pulse),
                Colors.transparent,
              ],
            ).createShader(pecRect.inflate(6)),
        );
      }

      // Iluminación específica de Dorsal Ancho / Romboides
      if (highlightLats) {
        final Offset latCenter = shoulder + (hip - shoulder) * 0.42;
        final Rect latRect = Rect.fromCenter(
          center: latCenter,
          width: frontalView ? 42 : 24,
          height: 28,
        );
        canvas.drawOval(
          latRect,
          Paint()
            ..shader = RadialGradient(
              colors: <Color>[
                Colors.white.withValues(alpha: 0.85),
                phaseColor.withValues(alpha: 0.85 * pulse),
                const Color(0xFF00E5FF).withValues(alpha: 0.25),
                Colors.transparent,
              ],
            ).createShader(latRect.inflate(8)),
        );
      }

      // Iluminación específica de Trapecio Superior
      if (highlightTraps) {
        final Rect trapRect = Rect.fromCenter(
          center: shoulder - const Offset(0, 5),
          width: frontalView ? 34 : 20,
          height: 12,
        );
        canvas.drawOval(
          trapRect,
          Paint()
            ..shader = RadialGradient(
              colors: <Color>[
                Colors.white,
                phaseColor.withValues(alpha: 0.9 * pulse),
                Colors.transparent,
              ],
            ).createShader(trapRect.inflate(5)),
        );
      }

      // Iluminación de Core / Erectores
      if (highlightCore) {
        final Offset coreCenter = shoulder + (hip - shoulder) * 0.68;
        final Rect coreRect = Rect.fromCenter(
          center: coreCenter,
          width: frontalView ? 22 : 16,
          height: 22,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(coreRect, const Radius.circular(5)),
          Paint()
            ..color = const Color(0xFF00E5FF).withValues(alpha: 0.32 * pulse),
        );
      }
    }

    // Helper: Dibuja cápsula 3D de Deltoides (Hombro iluminado)
    void drawDeltoidCap3D(Offset center, {bool active = false, double radius = 9.0}) {
      if (active) {
        canvas.drawCircle(
          center,
          radius * 1.65,
          Paint()
            ..color = phaseColor.withValues(alpha: 0.35 * pulse)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
      final Rect rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.3),
            colors: active
                ? <Color>[
                    Colors.white,
                    phaseColor,
                    const Color(0xFF0F172A),
                  ]
                : <Color>[
                    const Color(0xFF94A3B8),
                    const Color(0xFF334155),
                    const Color(0xFF0F172A),
                  ],
          ).createShader(rect),
      );
    }

    // Helper: Dibuja cabeza anatómica 3D con visor cibernético
    void drawHead3D(Offset center) {
      final Rect headRect = Rect.fromCenter(
        center: center,
        width: 19,
        height: 22,
      );
      canvas.drawOval(
        headRect,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.25, -0.35),
            colors: <Color>[
              Color(0xFF94A3B8),
              Color(0xFF334155),
              Color(0xFF0F172A),
            ],
          ).createShader(headRect),
      );
      canvas.drawOval(
        headRect,
        Paint()
          ..color = phaseColor.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
      // Visor táctico luminoso
      canvas.drawLine(
        center + const Offset(-5, -2),
        center + const Offset(5, -2),
        Paint()
          ..color = const Color(0xFF00E5FF)
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round,
      );
    }

    // Helper: Disco olímpico 3D o mancuerna cromada
    void drawWeight3D(Offset center, {double radius = 12.0}) {
      final Rect plateRect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = const RadialGradient(
            colors: <Color>[
              Color(0xFF334155),
              Color(0xFF0F172A),
              Colors.black,
            ],
          ).createShader(plateRect),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = const Color(0xFFD2FF00)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
      canvas.drawCircle(
        center,
        radius * 0.32,
        Paint()..color = const Color(0xFFE2E8F0),
      );
    }

    // Helper: Arco goniométrico de ángulo articular en vivo
    void drawJointGoniometer(Offset vertex, double radius) {
      final Rect arcRect = Rect.fromCircle(center: vertex, radius: radius);
      canvas.drawArc(
        arcRect,
        -math.pi * 0.75,
        math.pi * 0.65,
        false,
        Paint()
          ..color = phaseColor.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
    }

    // Helper: Vector de trayectoria cinemática punteada
    void drawTrajectoryVector(Offset top, Offset bottom) {
      final Paint dashPaint = Paint()
        ..color = phaseColor.withValues(alpha: 0.45)
        ..strokeWidth = 1.5;
      const double dashLen = 4.0;
      const double gapLen = 4.0;
      final double total = (bottom - top).distance;
      if (total < 4) return;
      final Offset dir = (bottom - top) / total;
      double d = 0;
      while (d < total) {
        final Offset p1 = top + dir * d;
        final Offset p2 = top + dir * math.min(d + dashLen, total);
        canvas.drawLine(p1, p2, dashPaint);
        d += dashLen + gapLen;
      }
    }

    switch (archetype) {
      case BiomechanicalArchetype.overheadPress:
        // VISTA 3D FRONTAL-OBLICUA: Press Militar con Barra Olímpica
        final Offset hip = Offset(cx, floorY - 68);
        final Offset shoulder = Offset(cx, floorY - 110);
        final Offset shL = Offset(cx - 21, shoulder.dy);
        final Offset shR = Offset(cx + 21, shoulder.dy);
        final Offset kneeL = Offset(cx - 11, floorY - 34);
        final Offset kneeR = Offset(cx + 11, floorY - 34);
        final Offset ankleL = Offset(cx - 13, floorY);
        final Offset ankleR = Offset(cx + 13, floorY);

        // Piernas y Torso 3D estable
        drawLimb3D(ankleL, kneeL, startRadius: 4.5, bellyRadius: 7.0);
        drawLimb3D(ankleR, kneeR, startRadius: 4.5, bellyRadius: 7.0);
        drawLimb3D(kneeL, Offset(cx - 10, hip.dy), bellyRadius: 8.5);
        drawLimb3D(kneeR, Offset(cx + 10, hip.dy), bellyRadius: 8.5);
        drawSculptedTorso3D(
          hip,
          shoulder,
          frontalView: true,
          highlightCore: true,
          highlightTraps: true,
        );
        drawHead3D(Offset(cx, shoulder.dy - 18));

        // Cinemática de Press Militar (depth 0 = bloqueo sobre corona, depth 1 = clavícula)
        final double barY = (shoulder.dy - 46) + (depth * 44);
        final Offset elbowL = Offset(
          shL.dx - 11,
          shoulder.dy - 12 + (depth * 26),
        );
        final Offset elbowR = Offset(
          shR.dx + 11,
          shoulder.dy - 12 + (depth * 26),
        );
        final Offset handL = Offset(shL.dx - 7, barY);
        final Offset handR = Offset(shR.dx + 7, barY);

        drawTrajectoryVector(
          Offset(cx, shoulder.dy - 48),
          Offset(cx, shoulder.dy),
        );

        // Brazos y Deltoides iluminados
        drawLimb3D(
          shL,
          elbowL,
          bellyRadius: 9.0,
          isPrimaryMuscle: true,
        );
        drawLimb3D(
          shR,
          elbowR,
          bellyRadius: 9.0,
          isPrimaryMuscle: true,
        );
        drawLimb3D(
          elbowL,
          handL,
          bellyRadius: 7.5,
          isSecondaryMuscle: true,
        );
        drawLimb3D(
          elbowR,
          handR,
          bellyRadius: 7.5,
          isSecondaryMuscle: true,
        );
        drawDeltoidCap3D(shL, active: true, radius: 9.5);
        drawDeltoidCap3D(shR, active: true, radius: 9.5);
        drawJointGoniometer(elbowR, 14);

        // Barra Olímpica 3D cromada con discos en ambos extremos
        canvas.drawLine(
          Offset(handL.dx - 16, barY),
          Offset(handR.dx + 16, barY),
          Paint()
            ..color = const Color(0xFFE2E8F0)
            ..strokeWidth = 3.6
            ..strokeCap = StrokeCap.round,
        );
        drawWeight3D(Offset(handL.dx - 12, barY), radius: 10.5);
        drawWeight3D(Offset(handR.dx + 12, barY), radius: 10.5);
        break;

      case BiomechanicalArchetype.lateralRaise:
        // VISTA 3D FRONTAL: Elevaciones Laterales en Plano Escapular (30°)
        final Offset hip = Offset(cx, floorY - 68);
        final Offset shoulder = Offset(cx, floorY - 110);
        final Offset shL = Offset(cx - 20, shoulder.dy);
        final Offset shR = Offset(cx + 20, shoulder.dy);

        drawLimb3D(
          Offset(cx - 12, floorY),
          Offset(cx - 10, floorY - 34),
          bellyRadius: 6.5,
        );
        drawLimb3D(
          Offset(cx + 12, floorY),
          Offset(cx + 10, floorY - 34),
          bellyRadius: 6.5,
        );
        drawLimb3D(
          Offset(cx - 10, floorY - 34),
          Offset(cx - 9, hip.dy),
          bellyRadius: 8.0,
        );
        drawLimb3D(
          Offset(cx + 10, floorY - 34),
          Offset(cx + 9, hip.dy),
          bellyRadius: 8.0,
        );
        drawSculptedTorso3D(
          hip,
          shoulder,
          frontalView: true,
          highlightCore: true,
        );
        drawHead3D(Offset(cx, shoulder.dy - 18));

        // Abducción de hombro: depth 0 = 90° horizontal, depth 1 = 15° abajo
        final double raiseFactor = 1.0 - depth;
        final double armAngle = 0.25 + (raiseFactor * 1.28); // rad desde vertical
        final Offset elbowL = Offset(
          shL.dx - math.sin(armAngle) * 22,
          shL.dy + math.cos(armAngle) * 22,
        );
        final Offset elbowR = Offset(
          shR.dx + math.sin(armAngle) * 22,
          shR.dy + math.cos(armAngle) * 22,
        );
        final Offset handL = Offset(
          elbowL.dx - math.sin(armAngle + 0.12) * 20,
          elbowL.dy + math.cos(armAngle + 0.12) * 20,
        );
        final Offset handR = Offset(
          elbowR.dx + math.sin(armAngle + 0.12) * 20,
          elbowR.dy + math.cos(armAngle + 0.12) * 20,
        );

        // Arcos de plano escapular 30°
        drawJointGoniometer(shR, 18);
        drawLimb3D(shL, elbowL, bellyRadius: 8.5, isPrimaryMuscle: true);
        drawLimb3D(shR, elbowR, bellyRadius: 8.5, isPrimaryMuscle: true);
        drawLimb3D(elbowL, handL, bellyRadius: 6.5, isSecondaryMuscle: true);
        drawLimb3D(elbowR, handR, bellyRadius: 6.5, isSecondaryMuscle: true);
        drawDeltoidCap3D(shL, active: true, radius: 10.5);
        drawDeltoidCap3D(shR, active: true, radius: 10.5);
        drawWeight3D(handL, radius: 7.5);
        drawWeight3D(handR, radius: 7.5);
        break;

      case BiomechanicalArchetype.rearDeltFacePull:
        // VISTA 3D POSTERIOR-SUPERIOR: Face Pulls / Deltoides Posterior y Romboides
        final Offset hip = Offset(cx, floorY - 68);
        final Offset shoulder = Offset(cx, floorY - 110);
        final Offset shL = Offset(cx - 21, shoulder.dy);
        final Offset shR = Offset(cx + 21, shoulder.dy);

        drawLimb3D(
          Offset(cx - 12, floorY),
          Offset(cx - 9, hip.dy),
          bellyRadius: 7.5,
        );
        drawLimb3D(
          Offset(cx + 12, floorY),
          Offset(cx + 9, hip.dy),
          bellyRadius: 7.5,
        );
        drawSculptedTorso3D(
          hip,
          shoulder,
          frontalView: true,
          highlightLats: true,
          highlightTraps: true,
        );
        drawHead3D(Offset(cx, shoulder.dy - 18));

        final double pullFactor = 1.0 - depth;
        final Offset elbowL = Offset(
          shL.dx - 14 - (pullFactor * 12),
          shL.dy + 6 - (pullFactor * 8),
        );
        final Offset elbowR = Offset(
          shR.dx + 14 + (pullFactor * 12),
          shR.dy + 6 - (pullFactor * 8),
        );
        final Offset handL = Offset(
          cx - 8 - (pullFactor * 14),
          shoulder.dy - 14,
        );
        final Offset handR = Offset(
          cx + 8 + (pullFactor * 14),
          shoulder.dy - 14,
        );

        // Polea alta frontal y cuerda doble
        final Offset pulleyAnchor = Offset(cx, shoulder.dy - 36);
        canvas.drawCircle(
          pulleyAnchor,
          5,
          Paint()..color = const Color(0xFF00E5FF),
        );
        canvas.drawLine(
          pulleyAnchor,
          handL,
          Paint()
            ..color = const Color(0xFFD2FF00)
            ..strokeWidth = 2.0,
        );
        canvas.drawLine(
          pulleyAnchor,
          handR,
          Paint()
            ..color = const Color(0xFFD2FF00)
            ..strokeWidth = 2.0,
        );

        drawLimb3D(shL, elbowL, bellyRadius: 8.5, isPrimaryMuscle: true);
        drawLimb3D(shR, elbowR, bellyRadius: 8.5, isPrimaryMuscle: true);
        drawLimb3D(elbowL, handL, bellyRadius: 6.5, isSecondaryMuscle: true);
        drawLimb3D(elbowR, handR, bellyRadius: 6.5, isSecondaryMuscle: true);
        drawDeltoidCap3D(shL, active: true, radius: 10.0);
        drawDeltoidCap3D(shR, active: true, radius: 10.0);
        drawJointGoniometer(elbowR, 14);
        break;

      case BiomechanicalArchetype.shrug:
        // VISTA 3D FRONTAL: Encogimientos de Trapecio con Mancuernas
        final Offset hip = Offset(cx, floorY - 68);
        final double liftOffset = (1.0 - depth) * 11.0;
        final Offset shoulder = Offset(cx, floorY - 108 - liftOffset);
        final Offset shL = Offset(cx - 21, shoulder.dy);
        final Offset shR = Offset(cx + 21, shoulder.dy);

        drawLimb3D(
          Offset(cx - 12, floorY),
          Offset(cx - 9, hip.dy),
          bellyRadius: 7.5,
        );
        drawLimb3D(
          Offset(cx + 12, floorY),
          Offset(cx + 9, hip.dy),
          bellyRadius: 7.5,
        );
        drawSculptedTorso3D(
          hip,
          shoulder,
          frontalView: true,
          highlightTraps: true,
        );
        drawHead3D(Offset(cx, floorY - 128));

        final Offset handL = Offset(shL.dx - 4, shL.dy + 42);
        final Offset handR = Offset(shR.dx + 4, shR.dy + 42);
        drawLimb3D(shL, handL, bellyRadius: 7.5, isSecondaryMuscle: true);
        drawLimb3D(shR, handR, bellyRadius: 7.5, isSecondaryMuscle: true);
        drawDeltoidCap3D(shL, active: true, radius: 9.5);
        drawDeltoidCap3D(shR, active: true, radius: 9.5);
        drawWeight3D(handL, radius: 9.0);
        drawWeight3D(handR, radius: 9.0);
        break;

      case BiomechanicalArchetype.latPulldown:
        // VISTA 3D: Jalón al Pecho con Retracción Escapular e Iluminación Dorsal + Bíceps
        const double topPulleyY = 30.0;
        final Offset hip = Offset(cx, floorY - 34);
        final Offset shoulder = Offset(cx, floorY - 82);
        final Offset shL = Offset(cx - 20, shoulder.dy);
        final Offset shR = Offset(cx + 20, shoulder.dy);

        // Asiento y rodillos
        canvas.drawLine(
          Offset(cx - 28, hip.dy + 4),
          Offset(cx + 28, hip.dy + 4),
          Paint()
            ..color = const Color(0xFF334155)
            ..strokeWidth = 6
            ..strokeCap = StrokeCap.round,
        );
        drawLimb3D(
          Offset(cx - 14, floorY),
          Offset(cx - 12, hip.dy),
          bellyRadius: 7.5,
        );
        drawLimb3D(
          Offset(cx + 14, floorY),
          Offset(cx + 12, hip.dy),
          bellyRadius: 7.5,
        );
        drawSculptedTorso3D(
          hip,
          shoulder,
          frontalView: true,
          highlightLats: true,
        );
        drawHead3D(Offset(cx, shoulder.dy - 17));

        // depth 0 = barra al pecho alto, depth 1 = brazos extendidos arriba
        final double barY = (shoulder.dy - 4) - (depth * 42);
        final Offset handL = Offset(cx - 34, barY);
        final Offset handR = Offset(cx + 34, barY);
        final Offset elbowL = Offset(
          shL.dx - 16,
          shoulder.dy + 14 - (depth * 28),
        );
        final Offset elbowR = Offset(
          shR.dx + 16,
          shoulder.dy + 14 - (depth * 28),
        );

        // Cable central y barra lat curva
        canvas.drawLine(
          Offset(cx, topPulleyY),
          Offset(cx, barY),
          Paint()
            ..color = const Color(0xFF94A3B8)
            ..strokeWidth = 2.0,
        );
        canvas.drawLine(
          handL,
          handR,
          Paint()
            ..color = const Color(0xFFD2FF00)
            ..strokeWidth = 3.5
            ..strokeCap = StrokeCap.round,
        );

        drawLimb3D(shL, elbowL, bellyRadius: 8.5, isPrimaryMuscle: true);
        drawLimb3D(shR, elbowR, bellyRadius: 8.5, isPrimaryMuscle: true);
        drawLimb3D(elbowL, handL, bellyRadius: 7.5, isSecondaryMuscle: true);
        drawLimb3D(elbowR, handR, bellyRadius: 7.5, isSecondaryMuscle: true);
        drawDeltoidCap3D(shL, active: false, radius: 8.5);
        drawDeltoidCap3D(shR, active: false, radius: 8.5);
        drawJointGoniometer(elbowR, 14);
        break;

      case BiomechanicalArchetype.benchPress:
        // VISTA 3D ISOMÉTRICA: Press de Banca con Arco Torácico, Pectoral y Deltoides Anterior
        final double benchY = floorY - 34;
        final Paint benchPaint = Paint()
          ..color = const Color(0xFF334155)
          ..strokeWidth = 7.0
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(cx - 56, benchY),
          Offset(cx + 38, benchY),
          benchPaint,
        );
        canvas.drawLine(
          Offset(cx - 44, benchY),
          Offset(cx - 44, floorY),
          benchPaint,
        );
        canvas.drawLine(
          Offset(cx + 26, benchY),
          Offset(cx + 26, floorY),
          benchPaint,
        );

        final Offset shoulder = Offset(cx - 26, benchY - 11);
        final Offset hip = Offset(cx + 16, benchY - 9);
        final Offset knee = Offset(cx + 42, benchY - 5);
        final Offset ankle = Offset(cx + 46, floorY);

        drawLimb3D(hip, knee, bellyRadius: 9.0);
        drawLimb3D(knee, ankle, bellyRadius: 7.0);
        drawSculptedTorso3D(
          hip,
          shoulder,
          highlightChest: true,
          highlightCore: true,
        );
        drawHead3D(Offset(cx - 45, benchY - 12));

        final double barY = (benchY - 62) + (depth * 40);
        final Offset wrist = Offset(cx - 22, barY);
        final Offset elbow = Offset(
          cx - 10 + (depth * 8),
          benchY - 26 + (depth * 18),
        );

        drawTrajectoryVector(Offset(cx - 22, benchY - 64), Offset(cx - 22, benchY - 18));
        drawLimb3D(shoulder, elbow, bellyRadius: 9.5, isPrimaryMuscle: true);
        drawLimb3D(elbow, wrist, bellyRadius: 7.5, isSecondaryMuscle: true);
        drawDeltoidCap3D(shoulder, active: true, radius: 9.5);
        drawJointGoniometer(elbow, 14);
        drawWeight3D(wrist, radius: 13.0);
        break;

      case BiomechanicalArchetype.squat:
      case BiomechanicalArchetype.lunge:
        // VISTA 3D: Sentadilla Profunda con Iluminación en Cuádriceps y Glúteo Mayor
        final Offset ankle = Offset(cx + 4, floorY);
        final Offset knee = Offset(
          cx - 14 - (depth * 18),
          floorY - 38 + (depth * 10),
        );
        final Offset hip = Offset(
          cx + 12 + (depth * 20),
          floorY - 76 + (depth * 38),
        );
        final Offset shoulder = Offset(
          cx - 2 - (depth * 4),
          hip.dy - 44 + (depth * 6),
        );

        drawTrajectoryVector(
          Offset(cx - 4, floorY - 122),
          Offset(cx - 4, floorY - 78),
        );
        drawLimb3D(
          ankle,
          knee,
          startRadius: 5.5,
          bellyRadius: 8.5,
          isSecondaryMuscle: true,
        );
        drawLimb3D(
          knee,
          hip,
          startRadius: 7.5,
          bellyRadius: 12.5,
          endRadius: 9.5,
          isPrimaryMuscle: true,
        );
        drawSculptedTorso3D(
          hip,
          shoulder,
          highlightCore: true,
        );
        // Iluminación volumétrica de Glúteo Mayor en la cadera
        drawDeltoidCap3D(hip, active: true, radius: 10.5);
        drawHead3D(Offset(shoulder.dx - 2, shoulder.dy - 17));
        drawJointGoniometer(knee, 15);
        drawWeight3D(Offset(shoulder.dx + 3, shoulder.dy + 2), radius: 12.5);
        break;

      case BiomechanicalArchetype.deadlift:
        // VISTA 3D: Peso Muerto Rumano (RDL) con Iluminación en Isquiosurales y Glúteos
        final Offset ankle = Offset(cx, floorY);
        final Offset knee = Offset(
          cx - 6 - (depth * 8),
          floorY - 38 + (depth * 5),
        );
        final Offset hip = Offset(
          cx + 8 + (depth * 26),
          floorY - 76 + (depth * 22),
        );
        final Offset shoulder = Offset(
          cx - 4 - (depth * 16),
          hip.dy - 44 + (depth * 26),
        );
        final Offset hand = Offset(
          cx - 10,
          floorY - 62 + (depth * 36),
        );

        drawTrajectoryVector(Offset(cx - 10, floorY - 64), Offset(cx - 10, floorY - 22));
        drawLimb3D(ankle, knee, bellyRadius: 7.5);
        drawLimb3D(
          knee,
          hip,
          bellyRadius: 11.5,
          isPrimaryMuscle: true,
        );
        drawSculptedTorso3D(
          hip,
          shoulder,
          highlightLats: true,
          highlightCore: true,
        );
        drawDeltoidCap3D(hip, active: true, radius: 10.5);
        drawLimb3D(shoulder, hand, bellyRadius: 7.0, isSecondaryMuscle: true);
        drawHead3D(Offset(shoulder.dx - 8, shoulder.dy - 14));
        drawJointGoniometer(hip, 16);
        drawWeight3D(hand, radius: 13.5);
        break;

      case BiomechanicalArchetype.barbellRow:
        // VISTA 3D: Remo con Barra 45° con Iluminación en Dorsal Ancho y Romboides
        final Offset ankle = Offset(cx, floorY);
        final Offset knee = Offset(cx - 10, floorY - 36);
        final Offset hip = Offset(cx + 22, floorY - 68);
        final Offset shoulder = Offset(cx - 14, floorY - 94);
        final Offset hand = Offset(
          cx - 10,
          (floorY - 70) + (depth * 28),
        );
        final Offset elbow = Offset(
          cx + 6 - (depth * 14),
          (floorY - 86) + (depth * 24),
        );

        drawLimb3D(ankle, knee, bellyRadius: 7.5);
        drawLimb3D(knee, hip, bellyRadius: 10.0, isSecondaryMuscle: true);
        drawSculptedTorso3D(
          hip,
          shoulder,
          highlightLats: true,
          highlightCore: true,
        );
        drawHead3D(Offset(shoulder.dx - 11, shoulder.dy - 11));
        drawLimb3D(shoulder, elbow, bellyRadius: 8.5, isPrimaryMuscle: true);
        drawLimb3D(elbow, hand, bellyRadius: 7.0, isSecondaryMuscle: true);
        drawJointGoniometer(elbow, 14);
        drawWeight3D(hand, radius: 11.5);
        break;

      case BiomechanicalArchetype.bicepCurl:
      case BiomechanicalArchetype.tricepExtension:
        // VISTA 3D: Aislamiento de Brazo (Bíceps Braquial o Tríceps Braquial)
        final Offset ankle = Offset(cx, floorY);
        final Offset knee = Offset(cx, floorY - 36);
        final Offset hip = Offset(cx, floorY - 72);
        final Offset shoulder = Offset(cx, floorY - 112);
        final Offset elbow = Offset(cx + 5, floorY - 82);
        final double angle = archetype == BiomechanicalArchetype.tricepExtension
            ? (-0.85 + (depth * 1.65))
            : (0.88 - (depth * 1.65));
        final Offset hand = Offset(
          elbow.dx - math.cos(angle) * 28,
          elbow.dy - math.sin(angle) * 28,
        );

        drawLimb3D(ankle, knee, bellyRadius: 7.5);
        drawLimb3D(knee, hip, bellyRadius: 9.5);
        drawSculptedTorso3D(hip, shoulder, highlightCore: true);
        drawHead3D(Offset(cx - 2, shoulder.dy - 17));
        drawLimb3D(
          shoulder,
          elbow,
          bellyRadius: 10.5,
          isPrimaryMuscle: true,
        );
        drawLimb3D(
          elbow,
          hand,
          bellyRadius: 7.5,
          isSecondaryMuscle: true,
        );
        drawDeltoidCap3D(shoulder, active: false, radius: 8.5);
        drawJointGoniometer(elbow, 14);
        drawWeight3D(hand, radius: 9.0);
        break;

      case BiomechanicalArchetype.hipThrust:
        // VISTA 3D: Hip Thrust con Barra e Iluminación en Glúteo Mayor
        final Offset benchSupport = Offset(cx - 34, floorY - 36);
        canvas.drawCircle(
          benchSupport,
          12,
          Paint()..color = const Color(0xFF334155),
        );
        final Offset shoulder = Offset(cx - 28, floorY - 42);
        final Offset hip = Offset(
          cx + 4,
          (floorY - 40) + (depth * 24),
        );
        final Offset knee = Offset(cx + 38, floorY - 38);
        final Offset ankle = Offset(cx + 38, floorY);

        drawHead3D(Offset(shoulder.dx - 15, shoulder.dy - 7));
        drawSculptedTorso3D(hip, shoulder, highlightCore: true);
        drawLimb3D(
          hip,
          knee,
          bellyRadius: 11.5,
          isPrimaryMuscle: true,
        );
        drawLimb3D(knee, ankle, bellyRadius: 7.5, isSecondaryMuscle: true);
        drawDeltoidCap3D(hip, active: true, radius: 11.5);
        drawJointGoniometer(hip, 16);
        drawWeight3D(hip - const Offset(0, 4), radius: 12.0);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _Biomechanical3DVisualizerPainter oldDelegate) {
    return oldDelegate.depth != depth ||
        oldDelegate.archetype != archetype ||
        oldDelegate.phaseColor != phaseColor ||
        oldDelegate.jointAngleDeg != jointAngleDeg;
  }
}
