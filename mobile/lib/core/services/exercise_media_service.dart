import 'dart:math' as math;
import 'package:flutter/material.dart';

enum BiomechanicalArchetype {
  benchPress,
  inclineDumbbellPress,
  parallelBarDips,
  frenchPress,
  tricepPushdown,
  overheadTricepExtension,
  latPulldown,
  barbellRow,
  seatedCableRow,
  bicepCurl,
  inclineDumbbellCurl,
  squat,
  legPress,
  lunge,
  legExtension,
  legCurl,
  calfRaise,
  overheadPress,
  lateralRaise,
  rearDeltFacePull,
  shrug,
  deadlift,
  hipThrust,
}

class ExerciseMediaSpec {
  final String keyId;
  final String canonicalName;
  final String gifUrl;
  final String frame1Url;
  final String? femaleGifUrl;
  final String? femaleFrame1Url;
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
    this.femaleGifUrl,
    this.femaleFrame1Url,
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
    // 0: Press de Banca Plano con Barra
    ExerciseMediaSpec(
      keyId: 'bench_press_barbell',
      canonicalName: 'Press de Banca Plano con Barra',
      gifUrl:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Bench_Press_-_Medium_Grip/0.jpg',
      frame1Url:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Bench_Press_-_Medium_Grip/1.jpg',
      archetype: BiomechanicalArchetype.benchPress,
      prescribedTempoCode: '3-0-1-0',
      prescribedTempoDetail: '3 seg bajada controlada, 0 pausa, 1 subida explosiva',
      eccentricSec: 3,
      pauseBottomSec: 0,
      concentricSec: 1,
      pauseTopSec: 0,
      activationCue:
          'Pecho erguido, retrae escápulas y mantén codos a 45° durante el descenso al esternón',
      defaultTargetRange: 'RPE 8.0 | 6-8 reps según tu recuperación de hoy',
      primaryMuscles: 'Pectoral Mayor • Deltoides Anterior',
      secondaryMuscles: 'Tríceps Braquial • Serrato Anterior',
      jointFocusLabel: 'Hombro 45° • Arco Torácico Estable',
      minAngleDeg: 78,
      maxAngleDeg: 175,
    ),
    // 1: Press Inclinado con Mancuernas (30°-45°)
    ExerciseMediaSpec(
      keyId: 'incline_dumbbell_press',
      canonicalName: 'Press Inclinado con Mancuernas (30°)',
      gifUrl:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Incline_Dumbbell_Press/0.jpg',
      frame1Url:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Incline_Dumbbell_Press/1.jpg',
      archetype: BiomechanicalArchetype.inclineDumbbellPress,
      prescribedTempoCode: '3-1-1-0',
      prescribedTempoDetail: '3 seg bajada, 1 seg pausa en estiramiento, 1 subida convergente',
      eccentricSec: 3,
      pauseBottomSec: 1,
      concentricSec: 1,
      pauseTopSec: 0,
      activationCue:
          'Banco a 30°-45°, baja las mancuernas con codos a 45° enfatizando el haz clavicular superior',
      defaultTargetRange: 'RPE 8.0 | 8-10 reps según tu recuperación de hoy',
      primaryMuscles: 'Pectoral Mayor (Haz Clavicular/Superior)',
      secondaryMuscles: 'Deltoides Anterior • Tríceps Braquial',
      jointFocusLabel: 'Inclinación 30°-45° • Codos a 45°',
      minAngleDeg: 74,
      maxAngleDeg: 174,
    ),
    // 2: Fondos en Paralelas / Cruce en Polea
    ExerciseMediaSpec(
      keyId: 'parallel_bar_dips',
      canonicalName: 'Fondos en Paralelas Lastrados',
      gifUrl:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dips_-_Chest_Version/0.jpg',
      frame1Url:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dips_-_Chest_Version/1.jpg',
      archetype: BiomechanicalArchetype.parallelBarDips,
      prescribedTempoCode: '3-0-1-1',
      prescribedTempoDetail: '3 seg descenso controlado, 0 pausa, 1 empuje vertical, 1 bloqueo',
      eccentricSec: 3,
      pauseBottomSec: 0,
      concentricSec: 1,
      pauseTopSec: 1,
      activationCue:
          'Inclina el torso 30° al frente, desciende hasta 90° de flexión de codo y empuja deprimiendo escápulas',
      defaultTargetRange: 'RPE 8.0 | 8-10 reps según tu recuperación de hoy',
      primaryMuscles: 'Pectoral Inferior & Tríceps Braquial',
      secondaryMuscles: 'Deltoides Anterior • Pectoral Menor',
      jointFocusLabel: 'Flexión Codo 90° • Inclinación Torso 30°',
      minAngleDeg: 86,
      maxAngleDeg: 176,
    ),
    // 3: Press Francés con Barra EZ
    ExerciseMediaSpec(
      keyId: 'tricep_french_press',
      canonicalName: 'Press Francés con Barra EZ (Skullcrusher)',
      gifUrl:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/EZ-Bar_Skullcrusher/0.jpg',
      frame1Url:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/EZ-Bar_Skullcrusher/1.jpg',
      archetype: BiomechanicalArchetype.frenchPress,
      prescribedTempoCode: '3-0-1-0',
      prescribedTempoDetail: '3 seg flexión hacia la frente, 0 pausa, 1 extensión aislada',
      eccentricSec: 3,
      pauseBottomSec: 0,
      concentricSec: 1,
      pauseTopSec: 0,
      activationCue:
          'Mantén los húmeros fijos con ligera inclinación atrás y flexiona solo los codos',
      defaultTargetRange: 'RPE 8.0 | 8-10 reps según tu recuperación de hoy',
      primaryMuscles: 'Tríceps Braquial (Cabeza Larga y Medial)',
      secondaryMuscles: 'Cabeza Lateral del Tríceps • Ancóneo',
      jointFocusLabel: 'Flexión Codo 85° • Húmero Fijo',
      minAngleDeg: 72,
      maxAngleDeg: 174,
    ),
    // 4: Extensión de Tríceps en Polea con Cuerda
    ExerciseMediaSpec(
      keyId: 'tricep_rope_pushdown',
      canonicalName: 'Extensión de Tríceps en Polea con Cuerda',
      gifUrl:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Triceps_Pushdown_-_Rope_Attachment/0.jpg',
      frame1Url:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Triceps_Pushdown_-_Rope_Attachment/1.jpg',
      archetype: BiomechanicalArchetype.tricepPushdown,
      prescribedTempoCode: '2-0-1-1',
      prescribedTempoDetail: '2 seg retorno controlado, 1 extensión, 1 seg apertura final',
      eccentricSec: 2,
      pauseBottomSec: 0,
      concentricSec: 1,
      pauseTopSec: 1,
      activationCue:
          'Bloquea los codos pegados a las costillas y separa la cuerda en bloqueo completo',
      defaultTargetRange: 'RPE 8.5 | 10-12 reps según tu recuperación de hoy',
      primaryMuscles: 'Tríceps Braquial (Cabeza Lateral)',
      secondaryMuscles: 'Cabeza Medial del Tríceps • Ancóneo',
      jointFocusLabel: 'Extensión Codo 180° • Codos Fijos',
      minAngleDeg: 68,
      maxAngleDeg: 178,
    ),
    // 5: Extensión Overhead en Polea (Cabeza Larga)
    ExerciseMediaSpec(
      keyId: 'overhead_tricep_extension',
      canonicalName: 'Extensión de Tríceps Overhead en Polea',
      gifUrl:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Cable_Rope_Overhead_Triceps_Extension/0.jpg',
      frame1Url:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Cable_Rope_Overhead_Triceps_Extension/1.jpg',
      archetype: BiomechanicalArchetype.overheadTricepExtension,
      prescribedTempoCode: '3-1-1-0',
      prescribedTempoDetail: '3 seg estiramiento detrás de nuca, 1 pausa, 1 extensión',
      eccentricSec: 3,
      pauseBottomSec: 1,
      concentricSec: 1,
      pauseTopSec: 0,
      activationCue:
          'Hombros en flexión a 160° para máximo estiramiento de la cabeza larga del tríceps',
      defaultTargetRange: 'RPE 8.5 | 12-15 reps según tu recuperación de hoy',
      primaryMuscles: 'Tríceps Braquial (Cabeza Larga)',
      secondaryMuscles: 'Cabeza Medial • Core Anti-Extensión',
      jointFocusLabel: 'Flexión Hombro 160° • Extensión Codo',
      minAngleDeg: 64,
      maxAngleDeg: 175,
    ),
    // 6: Jalón al Pecho / Dominadas Pronas
    ExerciseMediaSpec(
      keyId: 'lat_pulldown',
      canonicalName: 'Jalón al Pecho Prono Ancho',
      gifUrl:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Wide-Grip_Lat_Pulldown/0.jpg',
      frame1Url:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Wide-Grip_Lat_Pulldown/1.jpg',
      archetype: BiomechanicalArchetype.latPulldown,
      prescribedTempoCode: '3-0-1-1',
      prescribedTempoDetail: '3 seg retorno controlado, 1 tracción al pecho, 1 iso abajo',
      eccentricSec: 3,
      pauseBottomSec: 0,
      concentricSec: 1,
      pauseTopSec: 1,
      activationCue:
          'Inicia con depresión escapular y conduce los codos hacia tus bolsillos',
      defaultTargetRange: 'RPE 8.0 | 8-10 reps según tu recuperación de hoy',
      primaryMuscles: 'Dorsal Ancho • Redondo Mayor',
      secondaryMuscles: 'Bíceps Braquial • Romboides',
      jointFocusLabel: 'Depresión Escapular • Tracción Vertical',
      minAngleDeg: 58,
      maxAngleDeg: 172,
    ),
    // 7: Remo con Barra Prono (Pendlay Row)
    ExerciseMediaSpec(
      keyId: 'barbell_row',
      canonicalName: 'Remo con Barra Prono (45°)',
      gifUrl:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Bent_Over_Barbell_Row/0.jpg',
      frame1Url:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Bent_Over_Barbell_Row/1.jpg',
      archetype: BiomechanicalArchetype.barbellRow,
      prescribedTempoCode: '2-0-1-1',
      prescribedTempoDetail: '2 seg bajada, 0 pausa, 1 tracción al abdomen, 1 contracción',
      eccentricSec: 2,
      pauseBottomSec: 0,
      concentricSec: 1,
      pauseTopSec: 1,
      activationCue:
          'Torso a 45° estable, tracciona hacia la cadera/abdomen apretando romboides',
      defaultTargetRange: 'RPE 8.0 | 6-8 reps según tu recuperación de hoy',
      primaryMuscles: 'Dorsal Ancho • Romboides',
      secondaryMuscles: 'Trapecio Medio • Erectores Espinales',
      jointFocusLabel: 'Torso 45° • Retracción Escapular',
      minAngleDeg: 68,
      maxAngleDeg: 166,
    ),
    // 8: Remo en Polea Baja Agarre Neutro
    ExerciseMediaSpec(
      keyId: 'seated_cable_row',
      canonicalName: 'Remo en Polea Baja Agarre Neutro',
      gifUrl:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Seated_Cable_Rows/0.jpg',
      frame1Url:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Seated_Cable_Rows/1.jpg',
      archetype: BiomechanicalArchetype.seatedCableRow,
      prescribedTempoCode: '3-0-1-1',
      prescribedTempoDetail: '3 seg retorno estirando escápulas, 1 tracción horizontal, 1 iso',
      eccentricSec: 3,
      pauseBottomSec: 0,
      concentricSec: 1,
      pauseTopSec: 1,
      activationCue:
          'Torso erguido a 90°, tracciona hacia el ombligo y exprime romboides 1 segundo',
      defaultTargetRange: 'RPE 8.0 | 10-12 reps según tu recuperación de hoy',
      primaryMuscles: 'Espalda Media (Romboides y Dorsal Ancho)',
      secondaryMuscles: 'Trapecio Medio/Inferior • Bíceps Braquial',
      jointFocusLabel: 'Tracción Horizontal • Torso 90°',
      minAngleDeg: 64,
      maxAngleDeg: 168,
    ),
    // 9: Curl de Bíceps con Barra / Martillo
    ExerciseMediaSpec(
      keyId: 'bicep_curl_barbell',
      canonicalName: 'Curl de Bíceps con Barra / Mancuernas',
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
      defaultTargetRange: 'RPE 8.5 | 8-12 reps según tu recuperación de hoy',
      primaryMuscles: 'Bíceps Braquial • Braquial Anterior',
      secondaryMuscles: 'Braquiorradial • Flexores de Antebrazo',
      jointFocusLabel: 'Húmero Fijo • Flexión Pura de Codo',
      minAngleDeg: 45,
      maxAngleDeg: 165,
    ),
    // 10: Curl Inclinado con Mancuernas (45°)
    ExerciseMediaSpec(
      keyId: 'incline_dumbbell_curl',
      canonicalName: 'Curl Inclinado con Mancuernas (45°)',
      gifUrl:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Incline_Dumbbell_Curl/0.jpg',
      frame1Url:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Incline_Dumbbell_Curl/1.jpg',
      archetype: BiomechanicalArchetype.inclineDumbbellCurl,
      prescribedTempoCode: '3-1-1-0',
      prescribedTempoDetail: '3 seg bajada en estiramiento, 1 pausa abajo, 1 flexión supinando',
      eccentricSec: 3,
      pauseBottomSec: 1,
      concentricSec: 1,
      pauseTopSec: 0,
      activationCue:
          'Apoya la espalda en banco a 45° dejando los húmeros atrás en extensión constante',
      defaultTargetRange: 'RPE 8.5 | 10-12 reps según tu recuperación de hoy',
      primaryMuscles: 'Bíceps Braquial (Cabeza Larga en Estiramiento)',
      secondaryMuscles: 'Braquial Anterior • Supinadores',
      jointFocusLabel: 'Hombro en Extensión 45° • Supinación',
      minAngleDeg: 48,
      maxAngleDeg: 170,
    ),
    // 11: Sentadilla Libre con Barra (Back Squat)
    ExerciseMediaSpec(
      keyId: 'squat_barbell',
      canonicalName: 'Sentadilla Libre con Barra (Back Squat)',
      gifUrl:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Full_Squat/0.jpg',
      frame1Url:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Barbell_Full_Squat/1.jpg',
      archetype: BiomechanicalArchetype.squat,
      prescribedTempoCode: '3-1-1-0',
      prescribedTempoDetail: '3 seg bajada profunda, 1 pausa abajo, 1 subida',
      eccentricSec: 3,
      pauseBottomSec: 1,
      concentricSec: 1,
      pauseTopSec: 0,
      activationCue:
          'Bracing abdominal 360°, rodillas alineadas con punteras y torso firme',
      defaultTargetRange: 'RPE 8.0 | 6-8 reps según tu recuperación de hoy',
      primaryMuscles: 'Cuádriceps (Vasto Lateral/Medial) & Glúteo',
      secondaryMuscles: 'Core 360° • Erectores Espinales',
      jointFocusLabel: 'Flexión Cadera/Rodilla >95° • Columna Neutra',
      minAngleDeg: 82,
      maxAngleDeg: 176,
    ),
    // 12: Prensa Inclinada 45° Profunda
    ExerciseMediaSpec(
      keyId: 'leg_press',
      canonicalName: 'Prensa Inclinada 45° Profunda',
      gifUrl:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Leg_Press/0.jpg',
      frame1Url:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Leg_Press/1.jpg',
      archetype: BiomechanicalArchetype.legPress,
      prescribedTempoCode: '3-0-1-0',
      prescribedTempoDetail: '3 seg descenso en riel 45°, 0 pausa, 1 empuje controlado',
      eccentricSec: 3,
      pauseBottomSec: 0,
      concentricSec: 1,
      pauseTopSec: 0,
      activationCue:
          'Mantén el sacro pegado al respaldo y desciende hasta >95° de flexión de rodilla',
      defaultTargetRange: 'RPE 8.0 | 8-10 reps según tu recuperación de hoy',
      primaryMuscles: 'Cuádriceps • Glúteo Mayor',
      secondaryMuscles: 'Aductor Mayor • Isquiosurales',
      jointFocusLabel: 'Riel Inclinado 45° • Sacro Apoyado',
      minAngleDeg: 80,
      maxAngleDeg: 172,
    ),
    // 13: Zancadas Búlgaras / Caminando con Mancuernas
    ExerciseMediaSpec(
      keyId: 'bulgarian_split_squat',
      canonicalName: 'Sentadilla Búlgara / Zancadas con Mancuernas',
      gifUrl:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dumbbell_Lunges/0.jpg',
      frame1Url:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dumbbell_Lunges/1.jpg',
      archetype: BiomechanicalArchetype.lunge,
      prescribedTempoCode: '3-1-1-0',
      prescribedTempoDetail: '3 seg descenso unilateral, 1 pausa abajo, 1 subida firme',
      eccentricSec: 3,
      pauseBottomSec: 1,
      concentricSec: 1,
      pauseTopSec: 0,
      activationCue:
          'Inclina el torso 15° al frente y empuja con toda la planta del pie delantero',
      defaultTargetRange: 'RPE 8.0 | 8-10 reps según tu recuperación de hoy',
      primaryMuscles: 'Cuádriceps Unilateral & Glúteo Mayor',
      secondaryMuscles: 'Glúteo Medio • Aductores',
      jointFocusLabel: 'Rodilla Delantera 90° • Torso 15°',
      minAngleDeg: 85,
      maxAngleDeg: 172,
    ),
    // 14: Extensión de Cuádriceps en Máquina
    ExerciseMediaSpec(
      keyId: 'leg_extension',
      canonicalName: 'Extensión de Cuádriceps en Máquina',
      gifUrl:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Leg_Extensions/0.jpg',
      frame1Url:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Leg_Extensions/1.jpg',
      archetype: BiomechanicalArchetype.legExtension,
      prescribedTempoCode: '3-0-1-1',
      prescribedTempoDetail: '3 seg bajada controlada, 1 extensión, 1 seg iso arriba',
      eccentricSec: 3,
      pauseBottomSec: 0,
      concentricSec: 1,
      pauseTopSec: 1,
      activationCue:
          'Alinea el eje de la máquina con tu rodilla y sostén 1s arriba exprimiendo el vasto medial',
      defaultTargetRange: 'RPE 8.5 | 12-15 reps según tu recuperación de hoy',
      primaryMuscles: 'Cuádriceps (Recto Femoral y Vasto Medial)',
      secondaryMuscles: 'Vasto Lateral • Vasto Intermedio',
      jointFocusLabel: 'Extensión de Rodilla 90°-180° • Pausa 1s',
      minAngleDeg: 85,
      maxAngleDeg: 178,
    ),
    // 15: Curl Femoral Sentado / Tumbado
    ExerciseMediaSpec(
      keyId: 'seated_leg_curl',
      canonicalName: 'Curl Femoral Sentado / Tumbado',
      gifUrl:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Seated_Leg_Curl/0.jpg',
      frame1Url:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Seated_Leg_Curl/1.jpg',
      archetype: BiomechanicalArchetype.legCurl,
      prescribedTempoCode: '3-0-1-1',
      prescribedTempoDetail: '3 seg retorno excéntrico, 1 flexión tibial, 1 iso atrás',
      eccentricSec: 3,
      pauseBottomSec: 0,
      concentricSec: 1,
      pauseTopSec: 1,
      activationCue:
          'Mantén dorsiflexión activa de tobillo y controla los 3 segundos de fase excéntrica',
      defaultTargetRange: 'RPE 8.5 | 10-12 reps según tu recuperación de hoy',
      primaryMuscles: 'Isquiosurales (Bíceps Femoral y Semitendinoso)',
      secondaryMuscles: 'Gastrocnemio • Poplíteo',
      jointFocusLabel: 'Flexión Isquiosural • Dorsiflexión Activa',
      minAngleDeg: 75,
      maxAngleDeg: 172,
    ),
    // 16: Elevación de Talones (Gemelos y Sóleo)
    ExerciseMediaSpec(
      keyId: 'standing_calf_raise',
      canonicalName: 'Elevación de Talones (Gemelos & Sóleo)',
      gifUrl:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Standing_Calf_Raises/0.jpg',
      frame1Url:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Standing_Calf_Raises/1.jpg',
      archetype: BiomechanicalArchetype.calfRaise,
      prescribedTempoCode: '2-2-1-1',
      prescribedTempoDetail: '2 seg bajada, 2 seg pausa en estiramiento, 1 subida, 1 iso arriba',
      eccentricSec: 2,
      pauseBottomSec: 2,
      concentricSec: 1,
      pauseTopSec: 1,
      activationCue:
          'Pausa 2 segundos abajo eliminando el rebote del tendón de Aquiles y sube al máximo sobre el metatarso',
      defaultTargetRange: 'RPE 8.5 | 10-15 reps según tu recuperación de hoy',
      primaryMuscles: 'Gastrocnemio & Sóleo (Tríceps Sural)',
      secondaryMuscles: 'Tibial Posterior • Peroneos',
      jointFocusLabel: 'Flexión Plantar Máxima • Pausa 2s',
      minAngleDeg: 70,
      maxAngleDeg: 135,
    ),
    // 17: Press Militar Overhead con Barra / Mancuernas
    ExerciseMediaSpec(
      keyId: 'overhead_press',
      canonicalName: 'Press Militar Overhead (OHP)',
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
      defaultTargetRange: 'RPE 8.0 | 6-10 reps según tu recuperación de hoy',
      primaryMuscles: 'Deltoides Anterior/Medio • Tríceps',
      secondaryMuscles: 'Trapecio Superior • Core Estabilizador',
      jointFocusLabel: 'Trayectoria Vertical • Plano Escapular',
      minAngleDeg: 72,
      maxAngleDeg: 178,
    ),
    // 18: Elevaciones Laterales en Plano Escapular
    ExerciseMediaSpec(
      keyId: 'lateral_raise',
      canonicalName: 'Elevaciones Laterales en Plano Escapular',
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
    // 19: Face Pulls / Pájaros en Polea Alta
    ExerciseMediaSpec(
      keyId: 'rear_delt_fly',
      canonicalName: 'Face Pull / Pájaros en Polea Alta',
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
      defaultTargetRange: 'RPE 8.0 | 12-15 reps según tu recuperación de hoy',
      primaryMuscles: 'Deltoides Posterior • Infraespinoso',
      secondaryMuscles: 'Romboides • Trapecio Medio/Inferior',
      jointFocusLabel: 'Rotación Externa 90° • Escápula Retraída',
      minAngleDeg: 40,
      maxAngleDeg: 95,
    ),
    // 20: Encogimientos de Trapecio (Barra / Mancuernas)
    ExerciseMediaSpec(
      keyId: 'barbell_shrug',
      canonicalName: 'Encogimientos de Trapecio con Barra / Mancuernas',
      gifUrl:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dumbbell_Shrug/0.jpg',
      frame1Url:
          'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Dumbbell_Shrug/1.jpg',
      archetype: BiomechanicalArchetype.shrug,
      prescribedTempoCode: '2-0-1-2',
      prescribedTempoDetail: '2 seg estiramiento, 1 elevación vertical, 2 seg pausa arriba',
      eccentricSec: 2,
      pauseBottomSec: 0,
      concentricSec: 1,
      pauseTopSec: 2,
      activationCue:
          'Eleva los hombros verticalmente hacia las orejas y sostén 2 segundos arriba',
      defaultTargetRange: 'RPE 8.0 | 10-12 reps según tu recuperación de hoy',
      primaryMuscles: 'Trapecio Superior • Elevador Escapular',
      secondaryMuscles: 'Romboides • Agarre Isométrico',
      jointFocusLabel: 'Elevación Escapular Vertical • Pausa 2s',
      minAngleDeg: 10,
      maxAngleDeg: 45,
    ),
    // 21: Peso Muerto Rumano (RDL) / Extensión de Cadera
    ExerciseMediaSpec(
      keyId: 'deadlift_barbell',
      canonicalName: 'Peso Muerto Rumano con Barra (RDL)',
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
          'Barra pegada a los muslos, cadera atrás con columna neutra y tibia vertical',
      defaultTargetRange: 'RPE 8.0 | 6-8 reps según tu recuperación de hoy',
      primaryMuscles: 'Isquiosurales • Glúteo Mayor',
      secondaryMuscles: 'Erectores Espinales • Dorsal Ancho',
      jointFocusLabel: 'Bisagra de Cadera • Tibia Vertical',
      minAngleDeg: 75,
      maxAngleDeg: 178,
    ),
    // 22: Hip Thrust Pesado con Barra
    ExerciseMediaSpec(
      keyId: 'hip_thrust',
      canonicalName: 'Hip Thrust Pesado con Barra Olímpica',
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
      defaultTargetRange: 'RPE 8.0 | 8-10 reps según tu recuperación de hoy',
      primaryMuscles: 'Glúteo Mayor • Glúteo Medio',
      secondaryMuscles: 'Isquiosurales • Core Pélvico',
      jointFocusLabel: 'Extensión Cadera 180° • Tibia Vertical 90°',
      minAngleDeg: 95,
      maxAngleDeg: 180,
    ),
  ];

  static ExerciseMediaSpec _byKeyId(String keyId) {
    for (final ExerciseMediaSpec spec in _catalog) {
      if (spec.keyId == keyId) {
        return spec;
      }
    }
    return _catalog.first;
  }

  /// Mapeo estricto y determinístico por `exerciseKey` y `rawName` (CERO repetición de Press Plano).
  static ExerciseMediaSpec resolveForExercise(
    String rawName, {
    String? exerciseKey,
  }) {
    final String key = (exerciseKey ?? '').toLowerCase().trim();
    final String q = rawName.toLowerCase().trim();

    // 1. DÍA 1 - EMPUJE: Diferenciación estricta entre Press Plano, Press Inclinado, Fondos y 3 variantes de Tríceps
    if (key.contains('incline_dumbbell_press') ||
        key.contains('incline_press') ||
        (q.contains('press') && q.contains('inclinado')) ||
        (q.contains('inclinado') && !q.contains('curl'))) {
      return _byKeyId('incline_dumbbell_press');
    }

    if (key.contains('dip') ||
        key.contains('parallel_bar') ||
        q.contains('fondo') ||
        q.contains('paralela') ||
        q.contains('cruce en polea') ||
        q.contains('dip')) {
      return _byKeyId('parallel_bar_dips');
    }

    if (key.contains('french_press') ||
        key.contains('skullcrusher') ||
        q.contains('francés') ||
        q.contains('frances') ||
        q.contains('skull')) {
      return _byKeyId('tricep_french_press');
    }

    if (key.contains('overhead_tricep') ||
        (q.contains('overhead') &&
            (q.contains('tríceps') ||
                q.contains('triceps') ||
                q.contains('extensión') ||
                q.contains('extension') ||
                q.contains('cabeza larga')))) {
      return _byKeyId('overhead_tricep_extension');
    }

    if (key.contains('tricep_rope_pushdown') ||
        key.contains('pushdown') ||
        key.contains('tricep_extension') ||
        (q.contains('tríceps') || q.contains('triceps')) ||
        q.contains('cuerda')) {
      return _byKeyId('tricep_rope_pushdown');
    }

    if (key.contains('bench_press') ||
        key == 'bench_press' ||
        q.contains('banca') ||
        q.contains('bench press') ||
        q.contains('press plano')) {
      return _byKeyId('bench_press_barbell');
    }

    // 2. DÍA 2 - TRACCIÓN: Diferenciación estricta entre Remo con Barra, Jalón al Pecho, Remo en Polea Baja, Curl Barra y Curl Inclinado
    if (key.contains('incline_dumbbell_curl') ||
        (q.contains('curl') && q.contains('inclinado'))) {
      return _byKeyId('incline_dumbbell_curl');
    }

    if (key.contains('bicep') ||
        key.contains('hammer_curl') ||
        key.contains('dumbbell_curl') ||
        key.contains('curl_barbell') ||
        (q.contains('curl') && !q.contains('femoral')) ||
        q.contains('bíceps') ||
        q.contains('biceps') ||
        q.contains('martillo')) {
      return _byKeyId('bicep_curl_barbell');
    }

    if (key.contains('lat_pulldown') ||
        key.contains('pulldown') ||
        key.contains('pull_up') ||
        q.contains('jalón') ||
        q.contains('jalon') ||
        q.contains('dominada') ||
        q.contains('lat pulldown')) {
      return _byKeyId('lat_pulldown');
    }

    if (key.contains('seated_cable_row') ||
        key.contains('cable_row') ||
        (q.contains('remo') && q.contains('polea')) ||
        (q.contains('remo') && q.contains('sentado')) ||
        (q.contains('remo') && q.contains('neutro'))) {
      return _byKeyId('seated_cable_row');
    }

    if (key.contains('barbell_row') ||
        key.contains('row') ||
        q.contains('remo') ||
        q.contains('pendlay') ||
        q.contains('row')) {
      return _byKeyId('barbell_row');
    }

    // 3. DÍA 4 - HOMBROS & TRAPECIO
    if (key.contains('rear_delt') ||
        key.contains('face_pull') ||
        q.contains('face pull') ||
        q.contains('pájaro') ||
        q.contains('pajaro') ||
        q.contains('posterior')) {
      return _byKeyId('rear_delt_fly');
    }

    if (key.contains('shrug') ||
        q.contains('encogimiento') ||
        q.contains('shrug') ||
        (q.contains('trapecio') && !q.contains('remo'))) {
      return _byKeyId('barbell_shrug');
    }

    if (key.contains('lateral_raise') ||
        q.contains('elevaciones laterales') ||
        q.contains('elevación lateral') ||
        q.contains('vuelos laterales') ||
        q.contains('lateral')) {
      return _byKeyId('lateral_raise');
    }

    if (key.contains('overhead_press') ||
        key.contains('military_press') ||
        key.contains('shoulder_press') ||
        q.contains('militar') ||
        q.contains('ohp') ||
        q.contains('shoulder press') ||
        q.contains('arnold') ||
        (q.contains('press') && q.contains('hombro'))) {
      return _byKeyId('overhead_press');
    }

    // 4. DÍA 3 & DÍA 5 - TREN INFERIOR: Diferenciación estricta entre Sentadilla, Prensa 45°, Búlgara, Extensión Cuádriceps, Curl Femoral, Gemelos, RDL y Hip Thrust
    if (key.contains('hip_thrust') ||
        key.contains('glute_bridge') ||
        q.contains('hip thrust') ||
        q.contains('puente')) {
      return _byKeyId('hip_thrust');
    }

    if (key.contains('leg_curl') ||
        q.contains('curl femoral') ||
        q.contains('femoral')) {
      return _byKeyId('seated_leg_curl');
    }

    if (key.contains('leg_extension') ||
        q.contains('extensión de cuádriceps') ||
        q.contains('extension de cuadriceps')) {
      return _byKeyId('leg_extension');
    }

    if (key.contains('calf') ||
        q.contains('talones') ||
        q.contains('gemelo') ||
        q.contains('sóleo') ||
        q.contains('soleo')) {
      return _byKeyId('standing_calf_raise');
    }

    if (key.contains('leg_press') ||
        q.contains('prensa')) {
      return _byKeyId('leg_press');
    }

    if (key.contains('split_squat') ||
        key.contains('lunge') ||
        q.contains('búlgara') ||
        q.contains('bulgara') ||
        q.contains('zancada') ||
        q.contains('lunge')) {
      return _byKeyId('bulgarian_split_squat');
    }

    if (key.contains('deadlift') ||
        key.contains('rdl') ||
        key.contains('hyperextension') ||
        q.contains('peso muerto') ||
        q.contains('rumano') ||
        q.contains('rdl') ||
        q.contains('extensión de cadera') ||
        q.contains('hiperext')) {
      return _byKeyId('deadlift_barbell');
    }

    if (key.contains('squat') ||
        q.contains('sentadilla') ||
        q.contains('squat')) {
      return _byKeyId('squat_barbell');
    }

    return _byKeyId('bench_press_barbell');
  }

  static String activationHeadlineFor(ExerciseMediaSpec spec) {
    switch (spec.archetype) {
      case BiomechanicalArchetype.benchPress:
        return 'Retracción Escapular Activa y Arco Estable';
      case BiomechanicalArchetype.inclineDumbbellPress:
        return 'Énfasis Clavicular en Banco a 30°-45°';
      case BiomechanicalArchetype.parallelBarDips:
        return 'Torso Inclinado 30° y Depresión Escapular';
      case BiomechanicalArchetype.frenchPress:
        return 'Aislamiento de Cabeza Larga con Húmero Fijo';
      case BiomechanicalArchetype.tricepPushdown:
        return 'Bloqueo de Húmero y Extensión Completa 180°';
      case BiomechanicalArchetype.overheadTricepExtension:
        return 'Máximo Estiramiento Overhead (160°)';
      case BiomechanicalArchetype.latPulldown:
        return 'Depresión Escapular Previa a la Tracción';
      case BiomechanicalArchetype.barbellRow:
        return 'Retracción de Romboides con Torso a 45°';
      case BiomechanicalArchetype.seatedCableRow:
        return 'Tracción Horizontal Pura con Torso a 90°';
      case BiomechanicalArchetype.bicepCurl:
        return 'Flexión Pura de Codo con Húmero Fijo';
      case BiomechanicalArchetype.inclineDumbbellCurl:
        return 'Estiramiento de Cabeza Larga a 45°';
      case BiomechanicalArchetype.squat:
        return 'Bracing Abdominal 360° y Rodillas Alineadas';
      case BiomechanicalArchetype.legPress:
        return 'Sacro Apoyado y Flexión Profunda en Riel 45°';
      case BiomechanicalArchetype.lunge:
        return 'Control Unilateral de Cadera y Rodilla';
      case BiomechanicalArchetype.legExtension:
        return 'Contracción Isométrica de Vasto Medial';
      case BiomechanicalArchetype.legCurl:
        return 'Flexión Isquiosural con Dorsiflexión Activa';
      case BiomechanicalArchetype.calfRaise:
        return 'Pausa en Estiramiento y Flexión Plantar Máxima';
      case BiomechanicalArchetype.overheadPress:
        return 'Estabilidad Lumbo-Pélvica y Empuje Vertical';
      case BiomechanicalArchetype.lateralRaise:
        return 'Abducción en Plano Escapular (30°)';
      case BiomechanicalArchetype.rearDeltFacePull:
        return 'Rotación Externa de Hombro a 90°';
      case BiomechanicalArchetype.shrug:
        return 'Elevación Escapular Vertical con Pausa';
      case BiomechanicalArchetype.deadlift:
        return 'Bisagra de Cadera y Dorsal Compacto';
      case BiomechanicalArchetype.hipThrust:
        return 'Retroversión Pélvica y Tibia a 90°';
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

/// Visor Biomecánico 3D / HD Desacoplado por Capas Verticales Limpias y Adaptativo por Género:
/// 1. Cabecera del Visor (Tag #F59E0B, Selector Género [♂ | ♀] y Selector [3D / GIF] | [FOTO REAL])
/// 2. Stage Central Libre de 230dp (#0E121A, borde #222733, sin cajas flotantes sobre el modelo)
/// 3. Banda Técnica de Telemetría Muscular en 2 Columnas (Músculo Primario + Ángulo Articular)
/// 4. Tarjetas Modulares de Parámetros Técnicos (Tempo, Activación y Prescripción IA)
class BiomechanicalExerciseAvatarModule extends StatefulWidget {
  final String exerciseName;
  final String? exerciseKey;
  final String athleteGender;
  final ValueChanged<String>? onGenderChanged;
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
    this.athleteGender = 'male',
    this.onGenderChanged,
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
  late String _localGender;

  @override
  void initState() {
    super.initState();
    _localGender = widget.athleteGender.toLowerCase().contains('fem')
        ? 'female'
        : 'male';
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant BiomechanicalExerciseAvatarModule oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.athleteGender != widget.athleteGender) {
      _localGender = widget.athleteGender.toLowerCase().contains('fem')
          ? 'female'
          : 'male';
    }
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

  void _toggleGender(String target) {
    setState(() {
      _localGender = target;
    });
    widget.onGenderChanged?.call(target);
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
    final bool isFemale = _localGender == 'female';
    final String displayExerciseName = widget.exerciseName.trim().isNotEmpty
        ? widget.exerciseName.trim()
        : spec.canonicalName;
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
        final String primaryPhoto =
            isFemale ? (spec.femaleGifUrl ?? spec.gifUrl) : spec.gifUrl;
        final String secondaryPhoto =
            isFemale ? (spec.femaleFrame1Url ?? spec.frame1Url) : spec.frame1Url;
        final String activeFrameUrl =
            phase.depth > 0.48 ? secondaryPhoto : primaryPhoto;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // 1. Cabecera del Visor (Barra Superior con Tag #F59E0B, Avatar ♂/♀ y Modo 3D/Foto)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
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
                        SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'VISOR BIOMECÁNICO 3D',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFF59E0B),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // Selector de Avatar por Género (♂ MASC / ♀ FEM)
                    InkWell(
                      borderRadius: BorderRadius.circular(7),
                      onTap: () => _toggleGender(isFemale ? 'male' : 'female'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E232E),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: isFemale
                                ? const Color(0xFFF472B6)
                                : const Color(0xFF00E5FF),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              isFemale ? Icons.female_rounded : Icons.male_rounded,
                              size: 12,
                              color: isFemale
                                  ? const Color(0xFFF472B6)
                                  : const Color(0xFF00E5FF),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              isFemale ? 'FEM' : 'MASC',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: isFemale
                                    ? const Color(0xFFF472B6)
                                    : const Color(0xFF00E5FF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    InkWell(
                      borderRadius: BorderRadius.circular(7),
                      onTap: () {
                        setState(() {
                          _showRealPhotoMode = false;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
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
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: !_showRealPhotoMode
                                ? Colors.white
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    InkWell(
                      borderRadius: BorderRadius.circular(7),
                      onTap: () {
                        setState(() {
                          _showRealPhotoMode = true;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
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
                            fontSize: 9.5,
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
                        isFemale: isFemale,
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
                              isFemale: isFemale,
                              depth: phase.depth,
                              phaseColor: phase.phaseColor,
                              jointAngleDeg: phase.jointAngleDeg,
                              pulseValue: _controller.value,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Etiqueta inferior reactiva de 1 línea en la base del canvas
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
                        color: const Color(0xFF0B0E14).withValues(alpha: 0.88),
                        border: const Border(
                          top: BorderSide(color: Color(0xFF222733)),
                        ),
                      ),
                      child: Text(
                        '$displayExerciseName • ${spec.jointFocusLabel}',
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
                    // Columna Izquierda (Músculo Primario y Sinergistas)
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
                    // Columna Derecha (Ángulo Articular específico del ejercicio + fase en vivo)
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
                            spec.jointFocusLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${phase.jointAngleDeg.round()}° ${phase.movementWord} • ${phase.phaseSubtitle}',
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

/// Motor de Renderizado Anatómico Volumétrico 3D con soporte de Avatares Masculino/Femenino,
/// iluminación de fibras musculares activas, bancos regulables (0°/35°/45°), barras paralelas y poleas.
class _Biomechanical3DVisualizerPainter extends CustomPainter {
  final BiomechanicalArchetype archetype;
  final bool isFemale;
  final double depth;
  final Color phaseColor;
  final double jointAngleDeg;
  final double pulseValue;

  const _Biomechanical3DVisualizerPainter({
    required this.archetype,
    required this.isFemale,
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
            (isFemale ? const Color(0xFFF472B6) : const Color(0xFF00E5FF))
                .withValues(alpha: 0.06),
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.55, 1.0],
        ).createShader(stageGlowRect),
    );

    final Rect platformRect = Rect.fromCenter(
      center: Offset(cx, floorY),
      width: 162,
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
    final double genderScale = isFemale ? 0.86 : 1.0;

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
      final double sR = startRadius * genderScale;
      final double bR = bellyRadius * genderScale;
      final double eR = endRadius * genderScale;

      final Offset delta = end - start;
      final double len = delta.distance;
      if (len < 1.0) return;
      final Offset dir = delta / len;
      final Offset normal = Offset(-dir.dy, dir.dx);
      final Offset mid = start + dir * (len * 0.46);

      if (isPrimaryMuscle || isSecondaryMuscle) {
        final Color glowColor =
            isPrimaryMuscle ? phaseColor : const Color(0xFF00E5FF);
        final double glowAlpha = (isPrimaryMuscle ? 0.36 : 0.20) * pulse;
        canvas.drawLine(
          start,
          end,
          Paint()
            ..color = glowColor.withValues(alpha: glowAlpha)
            ..strokeWidth = bR * 2.5
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
        );
      }

      final Path musclePath = Path()
        ..moveTo(
          start.dx + normal.dx * sR,
          start.dy + normal.dy * sR,
        )
        ..quadraticBezierTo(
          mid.dx + normal.dx * bR,
          mid.dy + normal.dy * bR,
          end.dx + normal.dx * eR,
          end.dy + normal.dy * eR,
        )
        ..lineTo(
          end.dx - normal.dx * eR,
          end.dy - normal.dy * eR,
        )
        ..quadraticBezierTo(
          mid.dx - normal.dx * bR,
          mid.dy - normal.dy * bR,
          start.dx - normal.dx * sR,
          start.dy - normal.dy * sR,
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

      canvas.drawLine(
        start + normal * (bR * 0.28),
        end + normal * (eR * 0.28),
        Paint()
          ..color =
              Colors.white.withValues(alpha: isPrimaryMuscle ? 0.55 : 0.22)
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round,
      );

      for (final Offset j in <Offset>[start, end]) {
        canvas.drawCircle(
          j,
          3.9 * genderScale,
          Paint()
            ..color = isPrimaryMuscle ? phaseColor : const Color(0xFF64748B),
        );
        canvas.drawCircle(
          j - const Offset(1.0, 1.0),
          1.4,
          Paint()..color = Colors.white.withValues(alpha: 0.8),
        );
      }
    }

    // Helper: Dibuja torso anatómico 3D esculpido con dimorfismo Masculino / Femenino
    void drawSculptedTorso3D(
      Offset hip,
      Offset shoulder, {
      bool highlightChest = false,
      bool highlightUpperChest = false,
      bool highlightLowerChest = false,
      bool highlightLats = false,
      bool highlightCore = false,
      bool highlightTraps = false,
      bool frontalView = false,
    }) {
      final double shWidth =
          frontalView ? (isFemale ? 17.5 : 22.0) : (isFemale ? 10.5 : 13.0);
      final double waistWidth =
          frontalView ? (isFemale ? 10.0 : 13.5) : (isFemale ? 7.2 : 9.5);
      final double hipWidth =
          frontalView ? (isFemale ? 15.5 : 13.5) : (isFemale ? 11.2 : 9.5);

      final Offset delta = shoulder - hip;
      final double len = delta.distance;
      if (len < 1.0) return;
      final Offset dir = delta / len;
      final Offset normal = Offset(-dir.dy, dir.dx);
      final Offset waistPt = hip + dir * (len * 0.42);

      final Path torsoPath = Path()
        ..moveTo(
          hip.dx - normal.dx * hipWidth,
          hip.dy - normal.dy * hipWidth,
        )
        ..quadraticBezierTo(
          waistPt.dx - normal.dx * waistWidth,
          waistPt.dy - normal.dy * waistWidth,
          shoulder.dx - normal.dx * shWidth,
          shoulder.dy - normal.dy * shWidth,
        )
        ..lineTo(
          shoulder.dx + normal.dx * shWidth,
          shoulder.dy + normal.dy * shWidth,
        )
        ..quadraticBezierTo(
          waistPt.dx + normal.dx * waistWidth,
          waistPt.dy + normal.dy * waistWidth,
          hip.dx + normal.dx * hipWidth,
          hip.dy + normal.dy * hipWidth,
        )
        ..close();

      final Rect torsoBounds = torsoPath.getBounds().inflate(8);
      canvas.drawPath(
        torsoPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isFemale
                ? const <Color>[
                    Color(0xFF7E8CE0),
                    Color(0xFF334155),
                    Color(0xFF0F172A),
                  ]
                : const <Color>[
                    Color(0xFF64748B),
                    Color(0xFF334155),
                    Color(0xFF0F172A),
                  ],
          ).createShader(torsoBounds),
      );
      canvas.drawPath(
        torsoPath,
        Paint()
          ..color = (isFemale ? const Color(0xFFF472B6) : const Color(0xFF94A3B8))
              .withValues(alpha: 0.38)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1,
      );

      // Si es avatar femenino, dibuja contorno de sports top técnico
      if (isFemale) {
        final Offset topCenter = shoulder + (hip - shoulder) * 0.26;
        canvas.drawLine(
          topCenter - normal * (shWidth * 0.78),
          topCenter + normal * (shWidth * 0.78),
          Paint()
            ..color = const Color(0xFFF472B6).withValues(alpha: 0.45)
            ..strokeWidth = 3.5
            ..strokeCap = StrokeCap.round,
        );
      }

      if (highlightChest || highlightUpperChest || highlightLowerChest) {
        final double chestRatio = highlightUpperChest
            ? 0.18
            : (highlightLowerChest ? 0.36 : 0.28);
        final Offset chestCenter = shoulder + (hip - shoulder) * chestRatio;
        final Rect pecRect = Rect.fromCenter(
          center: chestCenter,
          width: frontalView ? 32 : 19,
          height: 15,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(pecRect, const Radius.circular(6)),
          Paint()
            ..shader = RadialGradient(
              colors: <Color>[
                Colors.white.withValues(alpha: 0.92),
                phaseColor.withValues(alpha: 0.88 * pulse),
                Colors.transparent,
              ],
            ).createShader(pecRect.inflate(6)),
        );
      }

      if (highlightLats) {
        final Offset latCenter = shoulder + (hip - shoulder) * 0.42;
        final Rect latRect = Rect.fromCenter(
          center: latCenter,
          width: frontalView ? 40 : 23,
          height: 26,
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

      if (highlightTraps) {
        final Rect trapRect = Rect.fromCenter(
          center: shoulder - const Offset(0, 5),
          width: frontalView ? 32 : 18,
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

      if (highlightCore) {
        final Offset coreCenter = shoulder + (hip - shoulder) * 0.68;
        final Rect coreRect = Rect.fromCenter(
          center: coreCenter,
          width: frontalView ? 20 : 15,
          height: 20,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(coreRect, const Radius.circular(5)),
          Paint()
            ..color = const Color(0xFF00E5FF).withValues(alpha: 0.30 * pulse),
        );
      }
    }

    void drawDeltoidCap3D(
      Offset center, {
      bool active = false,
      double radius = 9.0,
    }) {
      final double r = radius * genderScale;
      if (active) {
        canvas.drawCircle(
          center,
          r * 1.65,
          Paint()
            ..color = phaseColor.withValues(alpha: 0.35 * pulse)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
      final Rect rect = Rect.fromCircle(center: center, radius: r);
      canvas.drawCircle(
        center,
        r,
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

    // Helper: Cabeza anatómica 3D con diferenciación Masculina / Femenina (coleta atlética 3D)
    void drawHead3D(Offset center, {bool facingRight = true}) {
      if (isFemale) {
        final double dirSign = facingRight ? -1.0 : 1.0;
        final Path ponytail = Path()
          ..moveTo(center.dx + (dirSign * 6), center.dy - 5)
          ..quadraticBezierTo(
            center.dx + (dirSign * 17),
            center.dy - 9 + (depth * 4),
            center.dx + (dirSign * 19),
            center.dy + 6 + (depth * 3),
          )
          ..quadraticBezierTo(
            center.dx + (dirSign * 11),
            center.dy + 4,
            center.dx + (dirSign * 6),
            center.dy - 1,
          )
          ..close();
        canvas.drawPath(
          ponytail,
          Paint()..color = const Color(0xFFF472B6).withValues(alpha: 0.85),
        );
      }

      final Rect headRect = Rect.fromCenter(
        center: center,
        width: isFemale ? 17.0 : 19.0,
        height: isFemale ? 20.0 : 22.0,
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
      canvas.drawLine(
        center + const Offset(-4.5, -2),
        center + const Offset(4.5, -2),
        Paint()
          ..color = isFemale ? const Color(0xFFF472B6) : const Color(0xFF00E5FF)
          ..strokeWidth = 2.3
          ..strokeCap = StrokeCap.round,
      );
    }

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
          ..strokeWidth = 2.1,
      );
      canvas.drawCircle(
        center,
        radius * 0.32,
        Paint()..color = const Color(0xFFE2E8F0),
      );
    }

    void drawDumbbell3D(Offset center, {double angleRad = 0.0}) {
      final Offset axis = Offset(math.cos(angleRad), math.sin(angleRad));
      final Offset p1 = center - axis * 7.5;
      final Offset p2 = center + axis * 7.5;
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = const Color(0xFFE2E8F0)
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round,
      );
      for (final Offset bell in <Offset>[p1, p2]) {
        canvas.drawCircle(
          bell,
          4.8,
          Paint()..color = const Color(0xFF1E293B),
        );
        canvas.drawCircle(
          bell,
          4.8,
          Paint()
            ..color = const Color(0xFFD2FF00)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }

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

    final Paint structurePaint = Paint()
      ..color = const Color(0xFF334155)
      ..strokeWidth = 6.5
      ..strokeCap = StrokeCap.round;

    switch (archetype) {
      case BiomechanicalArchetype.benchPress:
        // #1 PRESS DE BANCA PLANO CON BARRA (Banco horizontal 0°)
        final double benchY = floorY - 34;
        canvas.drawLine(
          Offset(cx - 56, benchY),
          Offset(cx + 38, benchY),
          structurePaint,
        );
        canvas.drawLine(
          Offset(cx - 44, benchY),
          Offset(cx - 44, floorY),
          structurePaint,
        );
        canvas.drawLine(
          Offset(cx + 26, benchY),
          Offset(cx + 26, floorY),
          structurePaint,
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

        drawTrajectoryVector(
          Offset(cx - 22, benchY - 64),
          Offset(cx - 22, benchY - 18),
        );
        drawLimb3D(shoulder, elbow, bellyRadius: 9.5, isPrimaryMuscle: true);
        drawLimb3D(elbow, wrist, bellyRadius: 7.5, isSecondaryMuscle: true);
        drawDeltoidCap3D(shoulder, active: true, radius: 9.5);
        drawJointGoniometer(elbow, 14);
        drawWeight3D(wrist, radius: 13.0);
        break;

      case BiomechanicalArchetype.inclineDumbbellPress:
        // #2 PRESS INCLINADO CON MANCUERNAS (Banco inclinado a 35° + Mancuernas convergentes)
        final Offset seatHinge = Offset(cx + 6, floorY - 30);
        final Offset backrestTop = Offset(cx - 38, floorY - 68);
        final Offset seatFront = Offset(cx + 26, floorY - 34);
        // Respaldo inclinado 35° y asiento
        canvas.drawLine(backrestTop, seatHinge, structurePaint);
        canvas.drawLine(seatHinge, seatFront, structurePaint);
        canvas.drawLine(
          Offset(cx - 24, floorY - 54),
          Offset(cx - 28, floorY),
          structurePaint,
        );
        canvas.drawLine(
          Offset(cx + 12, floorY - 31),
          Offset(cx + 16, floorY),
          structurePaint,
        );

        final Offset hip = Offset(cx + 4, floorY - 38);
        final Offset shoulder = Offset(cx - 24, floorY - 66);
        final Offset knee = Offset(cx + 34, floorY - 34);
        final Offset ankle = Offset(cx + 38, floorY);

        drawLimb3D(hip, knee, bellyRadius: 9.0);
        drawLimb3D(knee, ankle, bellyRadius: 7.0);
        drawSculptedTorso3D(
          hip,
          shoulder,
          highlightUpperChest: true,
          highlightCore: true,
        );
        drawHead3D(Offset(shoulder.dx - 13, shoulder.dy - 12));

        // Trayectoria vertical-convergente sobre clavícula con mancuernas
        final double dbY = (shoulder.dy - 46) + (depth * 38);
        final Offset wrist = Offset(shoulder.dx + 4, dbY);
        final Offset elbow = Offset(
          shoulder.dx + 14 + (depth * 4),
          shoulder.dy - 14 + (depth * 20),
        );

        drawTrajectoryVector(
          Offset(shoulder.dx + 4, shoulder.dy - 48),
          Offset(shoulder.dx + 4, shoulder.dy - 6),
        );
        drawLimb3D(shoulder, elbow, bellyRadius: 9.5, isPrimaryMuscle: true);
        drawLimb3D(elbow, wrist, bellyRadius: 7.5, isSecondaryMuscle: true);
        drawDeltoidCap3D(shoulder, active: true, radius: 10.0);
        drawJointGoniometer(elbow, 14);
        drawDumbbell3D(wrist, angleRad: 0.15);
        break;

      case BiomechanicalArchetype.parallelBarDips:
        // #3 FONDOS EN PARALELAS (Barras verticales + Atleta suspendido con torso a 30°)
        final Offset barTopL = Offset(cx - 32, floorY - 78);
        final Offset barTopR = Offset(cx + 28, floorY - 78);
        // Postes verticales y barras paralelas horizontales
        canvas.drawLine(
          Offset(cx - 26, floorY),
          Offset(cx - 26, floorY - 78),
          structurePaint,
        );
        canvas.drawLine(
          Offset(cx + 22, floorY),
          Offset(cx + 22, floorY - 78),
          structurePaint,
        );
        canvas.drawLine(
          barTopL,
          barTopR,
          Paint()
            ..color = const Color(0xFF94A3B8)
            ..strokeWidth = 5.5
            ..strokeCap = StrokeCap.round,
        );

        final double dipDrop = depth * 28.0;
        final Offset hand = Offset(cx - 4, floorY - 78);
        final Offset shoulder = Offset(
          cx - 12,
          (floorY - 114) + dipDrop,
        );
        final Offset elbow = Offset(
          cx + 10 + (depth * 8),
          (floorY - 96) + (dipDrop * 0.65),
        );
        final Offset hip = Offset(
          cx + 10,
          (floorY - 68) + dipDrop,
        );
        final Offset knee = Offset(
          cx + 6,
          (floorY - 38) + dipDrop * 0.7,
        );
        final Offset ankle = Offset(
          cx + 22,
          (floorY - 32) + dipDrop * 0.7,
        );

        drawTrajectoryVector(
          Offset(cx - 12, floorY - 116),
          Offset(cx - 12, floorY - 82),
        );
        drawLimb3D(hip, knee, bellyRadius: 8.5);
        drawLimb3D(knee, ankle, bellyRadius: 6.5);
        drawSculptedTorso3D(
          hip,
          shoulder,
          highlightLowerChest: true,
          highlightCore: true,
        );
        drawHead3D(Offset(shoulder.dx - 8, shoulder.dy - 15));
        drawLimb3D(shoulder, elbow, bellyRadius: 9.5, isPrimaryMuscle: true);
        drawLimb3D(elbow, hand, bellyRadius: 8.0, isSecondaryMuscle: true);
        drawDeltoidCap3D(shoulder, active: true, radius: 9.5);
        drawJointGoniometer(elbow, 14);
        break;

      case BiomechanicalArchetype.frenchPress:
        // #4 PRESS FRANCÉS CON BARRA EZ (Húmero fijo, flexión de codo hacia la frente)
        final double benchY = floorY - 34;
        canvas.drawLine(
          Offset(cx - 56, benchY),
          Offset(cx + 38, benchY),
          structurePaint,
        );
        canvas.drawLine(
          Offset(cx - 44, benchY),
          Offset(cx - 44, floorY),
          structurePaint,
        );
        canvas.drawLine(
          Offset(cx + 26, benchY),
          Offset(cx + 26, floorY),
          structurePaint,
        );

        final Offset shoulder = Offset(cx - 24, benchY - 11);
        final Offset hip = Offset(cx + 16, benchY - 9);
        final Offset knee = Offset(cx + 42, benchY - 5);
        final Offset ankle = Offset(cx + 46, floorY);

        drawLimb3D(hip, knee, bellyRadius: 8.5);
        drawLimb3D(knee, ankle, bellyRadius: 6.5);
        drawSculptedTorso3D(hip, shoulder, highlightCore: true);
        drawHead3D(Offset(cx - 44, benchY - 12));

        // Húmero fijo apuntando ligeramente atrás, antebrazo describe arco hacia la frente
        final Offset elbow = Offset(shoulder.dx - 5, shoulder.dy - 32);
        final double forearmAngle = -math.pi * 0.45 - (depth * math.pi * 0.52);
        final Offset wrist = Offset(
          elbow.dx + math.cos(forearmAngle) * 28,
          elbow.dy + math.sin(forearmAngle) * 28,
        );

        drawLimb3D(shoulder, elbow, bellyRadius: 9.5, isPrimaryMuscle: true);
        drawLimb3D(elbow, wrist, bellyRadius: 7.5, isSecondaryMuscle: true);
        drawDeltoidCap3D(shoulder, active: false, radius: 8.5);
        drawJointGoniometer(elbow, 14);
        drawWeight3D(wrist, radius: 9.5);
        break;

      case BiomechanicalArchetype.tricepPushdown:
        // #5 EXTENSIÓN DE TRÍCEPS EN POLEA CON CUERDA (De pie frente a torre de polea alta)
        final Offset pulleyTop = Offset(cx - 34, floorY - 134);
        canvas.drawLine(
          Offset(cx - 34, floorY),
          pulleyTop,
          structurePaint,
        );
        canvas.drawCircle(
          pulleyTop,
          5,
          Paint()..color = const Color(0xFF00E5FF),
        );

        final Offset ankle = Offset(cx + 10, floorY);
        final Offset knee = Offset(cx + 8, floorY - 36);
        final Offset hip = Offset(cx + 12, floorY - 72);
        final Offset shoulder = Offset(cx + 6, floorY - 112);
        final Offset elbow = Offset(cx + 4, floorY - 82);
        // depth 0 = extensión completa abajo, depth 1 = flexión 80° arriba
        final double pushAngle = 1.25 - (depth * 1.45);
        final Offset hand = Offset(
          elbow.dx - math.cos(pushAngle) * 28,
          elbow.dy + math.sin(pushAngle) * 28,
        );

        canvas.drawLine(
          pulleyTop,
          hand,
          Paint()
            ..color = const Color(0xFFD2FF00)
            ..strokeWidth = 2.0,
        );

        drawLimb3D(ankle, knee, bellyRadius: 7.5);
        drawLimb3D(knee, hip, bellyRadius: 9.5);
        drawSculptedTorso3D(hip, shoulder, highlightCore: true);
        drawHead3D(Offset(shoulder.dx - 4, shoulder.dy - 17), facingRight: false);
        drawLimb3D(shoulder, elbow, bellyRadius: 10.0, isPrimaryMuscle: true);
        drawLimb3D(elbow, hand, bellyRadius: 7.5, isSecondaryMuscle: true);
        drawDeltoidCap3D(shoulder, active: false, radius: 8.5);
        drawJointGoniometer(elbow, 14);
        break;

      case BiomechanicalArchetype.overheadTricepExtension:
        // #6 EXTENSIÓN DE TRÍCEPS OVERHEAD EN POLEA (Cabeza larga en máximo estiramiento)
        final Offset pulleyAnchor = Offset(cx - 36, floorY - 88);
        canvas.drawLine(
          Offset(cx - 36, floorY),
          Offset(cx - 36, floorY - 126),
          structurePaint,
        );

        final Offset ankle = Offset(cx + 4, floorY);
        final Offset knee = Offset(cx + 8, floorY - 36);
        final Offset hip = Offset(cx + 6, floorY - 72);
        final Offset shoulder = Offset(cx + 14, floorY - 108);
        final Offset elbow = Offset(shoulder.dx + 4, shoulder.dy - 26);
        final double extFactor = 1.0 - depth;
        final Offset hand = Offset(
          elbow.dx - 14 + (extFactor * 26),
          elbow.dy + 12 - (extFactor * 28),
        );

        canvas.drawLine(
          pulleyAnchor,
          hand,
          Paint()
            ..color = const Color(0xFFD2FF00)
            ..strokeWidth = 2.0,
        );

        drawLimb3D(ankle, knee, bellyRadius: 7.5);
        drawLimb3D(knee, hip, bellyRadius: 9.5);
        drawSculptedTorso3D(hip, shoulder, highlightCore: true);
        drawHead3D(Offset(shoulder.dx + 4, shoulder.dy - 16));
        drawLimb3D(shoulder, elbow, bellyRadius: 10.0, isPrimaryMuscle: true);
        drawLimb3D(elbow, hand, bellyRadius: 7.5, isSecondaryMuscle: true);
        drawDeltoidCap3D(shoulder, active: true, radius: 8.5);
        drawJointGoniometer(elbow, 14);
        break;

      case BiomechanicalArchetype.latPulldown:
        // JALÓN AL PECHO PRONO ANCHO
        const double topPulleyY = 30.0;
        final Offset hip = Offset(cx, floorY - 34);
        final Offset shoulder = Offset(cx, floorY - 82);
        final Offset shL = Offset(cx - 20, shoulder.dy);
        final Offset shR = Offset(cx + 20, shoulder.dy);

        canvas.drawLine(
          Offset(cx - 28, hip.dy + 4),
          Offset(cx + 28, hip.dy + 4),
          structurePaint,
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

      case BiomechanicalArchetype.barbellRow:
        // REMO CON BARRA PRONO (Torso a 45°)
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
        drawHead3D(Offset(shoulder.dx - 11, shoulder.dy - 11), facingRight: false);
        drawLimb3D(shoulder, elbow, bellyRadius: 8.5, isPrimaryMuscle: true);
        drawLimb3D(elbow, hand, bellyRadius: 7.0, isSecondaryMuscle: true);
        drawJointGoniometer(elbow, 14);
        drawWeight3D(hand, radius: 11.5);
        break;

      case BiomechanicalArchetype.seatedCableRow:
        // REMO EN POLEA BAJA SENTADO (Tracción Horizontal con Torso a 90°)
        final double benchY = floorY - 24;
        canvas.drawLine(
          Offset(cx - 36, benchY),
          Offset(cx + 32, benchY),
          structurePaint,
        );
        final Offset pulleyLow = Offset(cx - 52, floorY - 48);
        canvas.drawLine(
          Offset(cx - 52, floorY),
          Offset(cx - 52, floorY - 86),
          structurePaint,
        );

        final Offset hip = Offset(cx + 16, benchY - 8);
        final Offset shoulder = Offset(cx + 14, benchY - 56);
        final Offset knee = Offset(cx - 12, benchY - 12);
        final Offset ankle = Offset(cx - 42, benchY - 6);

        drawLimb3D(hip, knee, bellyRadius: 9.0);
        drawLimb3D(knee, ankle, bellyRadius: 7.0);
        drawSculptedTorso3D(
          hip,
          shoulder,
          highlightLats: true,
          highlightCore: true,
        );
        drawHead3D(Offset(shoulder.dx, shoulder.dy - 17), facingRight: false);

        final double pullX = (cx + 6) - (depth * 32);
        final Offset hand = Offset(pullX, benchY - 34);
        final Offset elbow = Offset(pullX + 16, benchY - 32);

        canvas.drawLine(
          pulleyLow,
          hand,
          Paint()
            ..color = const Color(0xFFD2FF00)
            ..strokeWidth = 2.2,
        );
        drawLimb3D(shoulder, elbow, bellyRadius: 8.5, isPrimaryMuscle: true);
        drawLimb3D(elbow, hand, bellyRadius: 7.0, isSecondaryMuscle: true);
        drawJointGoniometer(elbow, 13);
        break;

      case BiomechanicalArchetype.bicepCurl:
        // CURL DE BÍCEPS DE PIE CON BARRA / MANCUERNAS
        final Offset ankle = Offset(cx, floorY);
        final Offset knee = Offset(cx, floorY - 36);
        final Offset hip = Offset(cx, floorY - 72);
        final Offset shoulder = Offset(cx, floorY - 112);
        final Offset elbow = Offset(cx + 5, floorY - 82);
        final double angle = 0.88 - (depth * 1.65);
        final Offset hand = Offset(
          elbow.dx - math.cos(angle) * 28,
          elbow.dy - math.sin(angle) * 28,
        );

        drawLimb3D(ankle, knee, bellyRadius: 7.5);
        drawLimb3D(knee, hip, bellyRadius: 9.5);
        drawSculptedTorso3D(hip, shoulder, highlightCore: true);
        drawHead3D(Offset(cx - 2, shoulder.dy - 17), facingRight: false);
        drawLimb3D(shoulder, elbow, bellyRadius: 10.5, isPrimaryMuscle: true);
        drawLimb3D(elbow, hand, bellyRadius: 7.5, isSecondaryMuscle: true);
        drawDeltoidCap3D(shoulder, active: false, radius: 8.5);
        drawJointGoniometer(elbow, 14);
        drawWeight3D(hand, radius: 9.0);
        break;

      case BiomechanicalArchetype.inclineDumbbellCurl:
        // CURL INCLINADO CON MANCUERNAS EN BANCO A 45° (Hombro en extensión)
        final Offset seatHinge = Offset(cx + 8, floorY - 30);
        final Offset backrestTop = Offset(cx - 32, floorY - 74);
        canvas.drawLine(backrestTop, seatHinge, structurePaint);
        canvas.drawLine(seatHinge, Offset(cx + 28, floorY - 34), structurePaint);
        canvas.drawLine(
          Offset(cx - 18, floorY - 56),
          Offset(cx - 22, floorY),
          structurePaint,
        );

        final Offset hip = Offset(cx + 6, floorY - 38);
        final Offset shoulder = Offset(cx - 20, floorY - 68);
        final Offset knee = Offset(cx + 32, floorY - 34);
        final Offset ankle = Offset(cx + 36, floorY);

        drawLimb3D(hip, knee, bellyRadius: 8.5);
        drawLimb3D(knee, ankle, bellyRadius: 6.5);
        drawSculptedTorso3D(hip, shoulder, highlightCore: true);
        drawHead3D(Offset(shoulder.dx - 11, shoulder.dy - 13));

        // Húmero colgando vertical detrás del torso (extensión de hombro)
        final Offset elbow = Offset(shoulder.dx - 4, shoulder.dy + 28);
        final double curlAngle = -0.35 + (depth * 1.65);
        final Offset hand = Offset(
          elbow.dx + math.cos(curlAngle) * 25,
          elbow.dy + math.sin(curlAngle) * 25,
        );

        drawLimb3D(shoulder, elbow, bellyRadius: 10.0, isPrimaryMuscle: true);
        drawLimb3D(elbow, hand, bellyRadius: 7.5, isSecondaryMuscle: true);
        drawDeltoidCap3D(shoulder, active: false, radius: 8.5);
        drawJointGoniometer(elbow, 13);
        drawDumbbell3D(hand);
        break;

      case BiomechanicalArchetype.squat:
        // SENTADILLA LIBRE CON BARRA (BACK SQUAT)
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
        drawSculptedTorso3D(hip, shoulder, highlightCore: true);
        drawDeltoidCap3D(hip, active: true, radius: 10.5);
        drawHead3D(Offset(shoulder.dx - 2, shoulder.dy - 17), facingRight: false);
        drawJointGoniometer(knee, 15);
        drawWeight3D(Offset(shoulder.dx + 3, shoulder.dy + 2), radius: 12.5);
        break;

      case BiomechanicalArchetype.legPress:
        // PRENSA INCLINADA 45° PROFUNDA
        final Offset seatHip = Offset(cx + 26, floorY - 24);
        final Offset backrestTop = Offset(cx + 50, floorY - 58);
        canvas.drawLine(seatHip, backrestTop, structurePaint);
        // Riel inclinado a 45°
        canvas.drawLine(
          Offset(cx - 48, floorY - 110),
          Offset(cx + 12, floorY - 50),
          Paint()
            ..color = const Color(0xFF475569)
            ..strokeWidth = 4.0,
        );

        final Offset shoulder = Offset(cx + 42, floorY - 52);
        final double sledTravel = (1.0 - depth) * 28.0;
        final Offset footPlate = Offset(
          (cx - 12) - sledTravel * 0.75,
          (floorY - 66) - sledTravel * 0.75,
        );
        final Offset knee = Offset(
          cx + 10 - (sledTravel * 0.25),
          floorY - 58 - (sledTravel * 0.15),
        );

        // Plataforma de empuje y discos
        canvas.drawLine(
          footPlate + const Offset(-10, 14),
          footPlate + const Offset(10, -14),
          structurePaint,
        );
        drawWeight3D(footPlate + const Offset(-12, -8), radius: 11.5);

        drawSculptedTorso3D(seatHip, shoulder, highlightCore: true);
        drawHead3D(Offset(shoulder.dx + 6, shoulder.dy - 14), facingRight: false);
        drawLimb3D(seatHip, knee, bellyRadius: 12.0, isPrimaryMuscle: true);
        drawLimb3D(knee, footPlate, bellyRadius: 8.5, isSecondaryMuscle: true);
        drawDeltoidCap3D(seatHip, active: true, radius: 10.5);
        drawJointGoniometer(knee, 15);
        break;

      case BiomechanicalArchetype.lunge:
        // SENTADILLA BÚLGARA / ZANCADA UNILATERAL (Pie trasero elevado en banco)
        final Offset rearBench = Offset(cx + 42, floorY - 30);
        canvas.drawLine(
          Offset(cx + 32, floorY - 30),
          Offset(cx + 52, floorY - 30),
          structurePaint,
        );
        canvas.drawLine(
          Offset(cx + 42, floorY - 30),
          Offset(cx + 42, floorY),
          structurePaint,
        );

        final double drop = depth * 28.0;
        final Offset frontAnkle = Offset(cx - 22, floorY);
        final Offset frontKnee = Offset(
          cx - 26 - (depth * 6),
          floorY - 38 + (drop * 0.35),
        );
        final Offset hip = Offset(cx + 2, floorY - 74 + drop);
        final Offset rearKnee = Offset(cx + 18, floorY - 46 + drop * 0.85);
        final Offset shoulder = Offset(cx - 6, hip.dy - 44);

        // Pierna trasera de apoyo
        drawLimb3D(rearBench, rearKnee, bellyRadius: 6.5);
        drawLimb3D(rearKnee, hip, bellyRadius: 8.5, isSecondaryMuscle: true);

        // Pierna delantera principal
        drawLimb3D(frontAnkle, frontKnee, bellyRadius: 7.5, isSecondaryMuscle: true);
        drawLimb3D(frontKnee, hip, bellyRadius: 11.5, isPrimaryMuscle: true);
        drawSculptedTorso3D(hip, shoulder, highlightCore: true);
        drawDeltoidCap3D(hip, active: true, radius: 10.0);
        drawHead3D(Offset(shoulder.dx - 3, shoulder.dy - 16), facingRight: false);
        drawDumbbell3D(Offset(hip.dx - 4, hip.dy + 4));
        drawJointGoniometer(frontKnee, 14);
        break;

      case BiomechanicalArchetype.legExtension:
        // EXTENSIÓN DE CUÁDRICEPS EN MÁQUINA
        final Offset hip = Offset(cx + 12, floorY - 42);
        final Offset knee = Offset(cx - 18, floorY - 42);
        final Offset shoulder = Offset(cx + 18, floorY - 88);
        canvas.drawLine(
          Offset(cx - 20, floorY - 36),
          Offset(cx + 24, floorY - 36),
          structurePaint,
        );
        canvas.drawLine(
          Offset(cx + 18, floorY - 36),
          Offset(cx + 24, floorY - 86),
          structurePaint,
        );

        final double extAngle = (1.0 - depth) * 1.38;
        final Offset ankle = Offset(
          knee.dx - math.sin(extAngle) * 34,
          knee.dy + math.cos(extAngle) * 34,
        );

        drawSculptedTorso3D(hip, shoulder, highlightCore: true);
        drawHead3D(Offset(shoulder.dx, shoulder.dy - 16), facingRight: false);
        drawLimb3D(hip, knee, bellyRadius: 12.0, isPrimaryMuscle: true);
        drawLimb3D(knee, ankle, bellyRadius: 7.5, isSecondaryMuscle: true);
        drawJointGoniometer(knee, 15);
        drawWeight3D(ankle, radius: 7.5);
        break;

      case BiomechanicalArchetype.legCurl:
        // CURL FEMORAL SENTADO / TUMBADO (Isquiosurales)
        final Offset hip = Offset(cx + 14, floorY - 42);
        final Offset knee = Offset(cx - 18, floorY - 42);
        final Offset shoulder = Offset(cx + 20, floorY - 88);
        canvas.drawLine(
          Offset(cx - 20, floorY - 36),
          Offset(cx + 24, floorY - 36),
          structurePaint,
        );

        final double curlAngle = 0.25 + (1.0 - depth) * 1.25;
        final Offset ankle = Offset(
          knee.dx - math.cos(curlAngle) * 34,
          knee.dy + math.sin(curlAngle) * 34,
        );

        drawSculptedTorso3D(hip, shoulder, highlightCore: true);
        drawHead3D(Offset(shoulder.dx, shoulder.dy - 16), facingRight: false);
        drawLimb3D(hip, knee, bellyRadius: 11.5, isPrimaryMuscle: true);
        drawLimb3D(knee, ankle, bellyRadius: 8.0, isSecondaryMuscle: true);
        drawJointGoniometer(knee, 15);
        drawWeight3D(ankle, radius: 7.5);
        break;

      case BiomechanicalArchetype.calfRaise:
        // ELEVACIÓN DE TALONES (GEMELOS Y SÓLEO)
        final double raiseY = (1.0 - depth) * 16.0;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(cx, floorY - 4),
              width: 44,
              height: 10,
            ),
            const Radius.circular(4),
          ),
          Paint()..color = const Color(0xFF475569),
        );

        final Offset ankle = Offset(cx, floorY - 8 - raiseY);
        final Offset knee = Offset(cx - 2, floorY - 46 - raiseY);
        final Offset hip = Offset(cx, floorY - 82 - raiseY);
        final Offset shoulder = Offset(cx, floorY - 122 - raiseY);

        drawLimb3D(
          ankle,
          knee,
          startRadius: 5.5,
          bellyRadius: 10.5,
          isPrimaryMuscle: true,
        );
        drawLimb3D(knee, hip, bellyRadius: 9.5, isSecondaryMuscle: true);
        drawSculptedTorso3D(hip, shoulder, highlightCore: true);
        drawHead3D(Offset(cx, shoulder.dy - 16));
        drawJointGoniometer(ankle, 13);
        break;

      case BiomechanicalArchetype.overheadPress:
        // PRESS MILITAR OVERHEAD CON BARRA
        final Offset hip = Offset(cx, floorY - 68);
        final Offset shoulder = Offset(cx, floorY - 110);
        final Offset shL = Offset(cx - 21, shoulder.dy);
        final Offset shR = Offset(cx + 21, shoulder.dy);
        final Offset kneeL = Offset(cx - 11, floorY - 34);
        final Offset kneeR = Offset(cx + 11, floorY - 34);
        final Offset ankleL = Offset(cx - 13, floorY);
        final Offset ankleR = Offset(cx + 13, floorY);

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

        drawLimb3D(shL, elbowL, bellyRadius: 9.0, isPrimaryMuscle: true);
        drawLimb3D(shR, elbowR, bellyRadius: 9.0, isPrimaryMuscle: true);
        drawLimb3D(elbowL, handL, bellyRadius: 7.5, isSecondaryMuscle: true);
        drawLimb3D(elbowR, handR, bellyRadius: 7.5, isSecondaryMuscle: true);
        drawDeltoidCap3D(shL, active: true, radius: 9.5);
        drawDeltoidCap3D(shR, active: true, radius: 9.5);
        drawJointGoniometer(elbowR, 14);

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
        // ELEVACIONES LATERALES EN PLANO ESCAPULAR (30°)
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

        final double raiseFactor = 1.0 - depth;
        final double armAngle = 0.25 + (raiseFactor * 1.28);
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

        drawJointGoniometer(shR, 18);
        drawLimb3D(shL, elbowL, bellyRadius: 8.5, isPrimaryMuscle: true);
        drawLimb3D(shR, elbowR, bellyRadius: 8.5, isPrimaryMuscle: true);
        drawLimb3D(elbowL, handL, bellyRadius: 6.5, isSecondaryMuscle: true);
        drawLimb3D(elbowR, handR, bellyRadius: 6.5, isSecondaryMuscle: true);
        drawDeltoidCap3D(shL, active: true, radius: 10.5);
        drawDeltoidCap3D(shR, active: true, radius: 10.5);
        drawDumbbell3D(handL);
        drawDumbbell3D(handR);
        break;

      case BiomechanicalArchetype.rearDeltFacePull:
        // FACE PULL / PÁJAROS EN POLEA ALTA
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
        // ENCOGIMIENTOS DE TRAPECIO CON BARRA / MANCUERNAS
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

      case BiomechanicalArchetype.deadlift:
        // PESO MUERTO RUMANO CON BARRA (RDL)
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

        drawTrajectoryVector(
          Offset(cx - 10, floorY - 64),
          Offset(cx - 10, floorY - 22),
        );
        drawLimb3D(ankle, knee, bellyRadius: 7.5);
        drawLimb3D(knee, hip, bellyRadius: 11.5, isPrimaryMuscle: true);
        drawSculptedTorso3D(
          hip,
          shoulder,
          highlightLats: true,
          highlightCore: true,
        );
        drawDeltoidCap3D(hip, active: true, radius: 10.5);
        drawLimb3D(shoulder, hand, bellyRadius: 7.0, isSecondaryMuscle: true);
        drawHead3D(Offset(shoulder.dx - 8, shoulder.dy - 14), facingRight: false);
        drawJointGoniometer(hip, 16);
        drawWeight3D(hand, radius: 13.5);
        break;

      case BiomechanicalArchetype.hipThrust:
        // HIP THRUST PESADO CON BARRA OLÍMPICA
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
        drawLimb3D(hip, knee, bellyRadius: 11.5, isPrimaryMuscle: true);
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
        oldDelegate.isFemale != isFemale ||
        oldDelegate.phaseColor != phaseColor ||
        oldDelegate.jointAngleDeg != jointAngleDeg;
  }
}
