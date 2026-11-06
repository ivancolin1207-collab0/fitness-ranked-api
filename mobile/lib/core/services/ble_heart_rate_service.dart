import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../data/services/secure_storage_service.dart';

class BleDiscoveredDevice {
  final BluetoothDevice device;
  final String displayName;
  final String remoteId;
  final int rssi;
  final bool advertisesHrService;
  final bool isWearableBrand;

  const BleDiscoveredDevice({
    required this.device,
    required this.displayName,
    required this.remoteId,
    required this.rssi,
    required this.advertisesHrService,
    this.isWearableBrand = false,
  });
}

class BleHeartRateService extends ChangeNotifier {
  static final BleHeartRateService instance = BleHeartRateService._internal();

  factory BleHeartRateService() => instance;

  BleHeartRateService._internal();

  final SecureStorageService _storage = const SecureStorageService();

  /// Standard Bluetooth SIG Heart Rate GATT Service (0x180D)
  static const String heartRateServiceUuid =
      '0000180d-0000-1000-8000-00805f9b34fb';

  /// Standard Bluetooth SIG Heart Rate Measurement Characteristic (0x2A37)
  static const String heartRateMeasurementUuid =
      '00002a37-0000-1000-8000-00805f9b34fb';

  static final Guid _hrServiceGuid = Guid(heartRateServiceUuid);
  static final Guid _hrCharGuid = Guid(heartRateMeasurementUuid);
  static final Guid _hrServiceShortGuid = Guid('180d');
  static final Guid _hrCharShortGuid = Guid('2a37');
  static final Guid _genericAccessGuid = Guid('1800');
  static final Guid _batteryServiceGuid = Guid('180f');
  static final Guid _huaweiWearableServiceGuid = Guid('fee0');

  static const List<String> _wearableKeywords = <String>[
    'whoop',
    'huawei',
    'honor',
    'band',
    'watch',
    'gt',
    'fit',
    'samsung',
    'galaxy',
    'gear',
    'polar',
    'garmin',
    'amazfit',
    'xiaomi',
    'mi band',
    'coros',
    'suunto',
    'wahoo',
    'heart',
    'hrm',
  ];

  final StreamController<int> _bpmStreamController =
      StreamController<int>.broadcast();
  Stream<int> get heartRateStream => _bpmStreamController.stream;

  final Map<String, BleDiscoveredDevice> _discoveredMap =
      <String, BleDiscoveredDevice>{};
  List<BleDiscoveredDevice> get discoveredDevices {
    final List<BleDiscoveredDevice> list = _discoveredMap.values.toList();
    list.sort((BleDiscoveredDevice a, BleDiscoveredDevice b) {
      if (a.advertisesHrService != b.advertisesHrService) {
        return a.advertisesHrService ? -1 : 1;
      }
      if (a.isWearableBrand != b.isWearableBrand) {
        return a.isWearableBrand ? -1 : 1;
      }
      return b.rssi.compareTo(a.rssi);
    });
    return list;
  }

  BluetoothDevice? _connectedDevice;
  BluetoothDevice? get connectedDevice => _connectedDevice;

  String? _connectedDeviceName;
  String? get connectedDeviceName => _connectedDeviceName;

  bool get isConnected => _connectedDevice != null;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  bool _isConnecting = false;
  bool get isConnecting => _isConnecting;

  bool _isAutoReconnecting = false;
  bool get isAutoReconnecting => _isAutoReconnecting;

  String? _savedDeviceId;
  String? get savedDeviceId => _savedDeviceId;

  String? _savedDeviceName;
  String? get savedDeviceName => _savedDeviceName;

  int? _latestBpm;
  int? get latestBpm => _latestBpm;

  String? _statusMessage;
  String? get statusMessage => _statusMessage;

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<bool>? _isScanningSub;
  StreamSubscription<List<int>>? _hrCharacteristicSub;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSub;
  Timer? _autoReconnectTimer;

  static bool _matchesWearableBrand(String name) {
    final String lower = name.toLowerCase();
    return _wearableKeywords.any((String kw) => lower.contains(kw));
  }

  /// Parser estándar GATT 0x2A37 (Heart Rate Measurement) compatible con
  /// Huawei Band/GT/Watch, Samsung Galaxy Watch, Polar, Garmin y Whoop 4.0.
  int parseHeartRate(List<int> value) {
    if (value.isEmpty) return 0;
    final int flags = value[0];
    final bool is16Bit = (flags & 0x01) != 0;
    if (is16Bit && value.length >= 3) {
      return value[1] | (value[2] << 8);
    } else if (!is16Bit && value.length >= 2) {
      return value[1];
    }
    return 0;
  }

  /// Parsea el payload GATT 0x2A37 manejando UINT8 y UINT16 Little-Endian.
  static int? parseHeartRateMeasurement(List<int> value) {
    final int bpm = BleHeartRateService.instance.parseHeartRate(value);
    if (bpm < 25 || bpm > 240) {
      return null;
    }
    return bpm;
  }

  /// Reconexión Automática Zero-Touch en Segundo Plano:
  /// Lee `last_paired_ble_id_${currentUser.id}` y, si el Bluetooth del teléfono está encendido,
  /// conecta silenciosamente con `BluetoothDevice.fromId(savedId)`, descubre servicios GATT
  /// y suscribe el stream de BPM en vivo (`0x2A37`) sin abrir ningún modal.
  Future<void> autoReconnectSavedDevice({String? userId}) async {
    final ({String id, String name})? saved =
        await _storage.readPairedBleDevice(userId: userId);
    if (saved == null || saved.id.isEmpty) {
      return;
    }

    _savedDeviceId = saved.id;
    _savedDeviceName = saved.name;
    _ensureBackgroundRetryTimer();

    if (isConnected || _isConnecting || _isAutoReconnecting) {
      return;
    }

    _isAutoReconnecting = true;
    notifyListeners();

    try {
      final BluetoothAdapterState adapterState =
          await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        return;
      }

      final BluetoothDevice device = BluetoothDevice.fromId(saved.id);

      // 1. Intento de conexión directa rápida si el wearable está al alcance inmediato
      bool connectedNow = false;
      try {
        await device.connect(
          license: License.nonprofit,
          timeout: const Duration(seconds: 6),
          autoConnect: false,
        );
        connectedNow = true;
      } catch (_) {
        // 2. Si está fuera de rango temporalmente, registrar reconexión pasiva del SO (autoConnect: true, mtu: null)
        try {
          await device.connect(
            license: License.nonprofit,
            timeout: const Duration(seconds: 8),
            autoConnect: true,
            mtu: null,
          );
          connectedNow = device.isConnected;
        } catch (_) {}
      }

      await _attachConnectionStateListener(device, saved.name);

      if (connectedNow || device.isConnected) {
        await _subscribeToHeartRateGatt(device, saved.name);
      }
    } catch (_) {
      // Silencioso en segundo plano para no bloquear ni interrumpir la UI
    } finally {
      _isAutoReconnecting = false;
      notifyListeners();
    }
  }

  void _ensureBackgroundRetryTimer() {
    _autoReconnectTimer ??= Timer.periodic(
      const Duration(seconds: 15),
      (_) {
        if (!isConnected &&
            !_isConnecting &&
            !_isAutoReconnecting &&
            _savedDeviceId != null &&
            _savedDeviceId!.isNotEmpty) {
          unawaited(autoReconnectSavedDevice());
        }
      },
    );
  }

  Future<void> _attachConnectionStateListener(
    BluetoothDevice device,
    String displayName,
  ) async {
    await _connectionStateSub?.cancel();
    _connectionStateSub = device.connectionState.listen(
      (BluetoothConnectionState state) {
        if (state == BluetoothConnectionState.connected) {
          if (_connectedDevice == null) {
            unawaited(_subscribeToHeartRateGatt(device, displayName));
          }
        } else if (state == BluetoothConnectionState.disconnected) {
          _connectedDevice = null;
          _connectedDeviceName = null;
          _statusMessage =
              'Dispositivo BLE fuera de rango. Reconectando automáticamente en segundo plano...';
          notifyListeners();
        }
      },
    );
  }

  Future<bool> _subscribeToHeartRateGatt(
    BluetoothDevice device,
    String displayName,
  ) async {
    final List<BluetoothService> services = await device.discoverServices();
    BluetoothCharacteristic? hrCharacteristic;

    // 1. Buscar servicio estándar Heart Rate 0x180D y característica 0x2A37
    for (final BluetoothService service in services) {
      final String sUuid = service.uuid.str.toLowerCase();
      if (service.uuid == _hrServiceGuid ||
          service.uuid == _hrServiceShortGuid ||
          sUuid.contains('180d')) {
        for (final BluetoothCharacteristic c in service.characteristics) {
          final String cUuid = c.uuid.str.toLowerCase();
          if (c.uuid == _hrCharGuid ||
              c.uuid == _hrCharShortGuid ||
              cUuid.contains('2a37')) {
            hrCharacteristic = c;
            break;
          }
        }
        // Fallback: cualquier característica notificable dentro de 0x180D
        if (hrCharacteristic == null) {
          for (final BluetoothCharacteristic c in service.characteristics) {
            if (c.properties.notify || c.properties.indicate) {
              hrCharacteristic = c;
              break;
            }
          }
        }
      }
      if (hrCharacteristic != null) {
        break;
      }
    }

    // 2. Fallback universal para wearables Huawei/Samsung/Amazfit que exponen 0x2A37 en otro contenedor GATT
    if (hrCharacteristic == null) {
      for (final BluetoothService service in services) {
        for (final BluetoothCharacteristic c in service.characteristics) {
          final String cUuid = c.uuid.str.toLowerCase();
          if (c.uuid == _hrCharGuid ||
              c.uuid == _hrCharShortGuid ||
              cUuid.contains('2a37')) {
            hrCharacteristic = c;
            break;
          }
        }
        if (hrCharacteristic != null) {
          break;
        }
      }
    }

    if (hrCharacteristic == null) {
      return false;
    }

    await hrCharacteristic.setNotifyValue(true);
    await _hrCharacteristicSub?.cancel();
    _hrCharacteristicSub =
        hrCharacteristic.lastValueStream.listen((List<int> payload) {
      final int bpm = parseHeartRate(payload);
      if (bpm >= 25 && bpm <= 240) {
        _latestBpm = bpm;
        _bpmStreamController.add(bpm);
        notifyListeners();
      }
    });

    _connectedDevice = device;
    _connectedDeviceName = displayName;
    _statusMessage =
        'Conectado a $displayName (GATT 0x180D • Stream 0x2A37 activo)';
    notifyListeners();
    return true;
  }

  /// Escáner Bluetooth BLE Universal sin filtros restrictivos de marca:
  /// Detecta Huawei Band/GT/Watch, Samsung Galaxy Watch (WearOS), Polar, Garmin y Whoop 4.0.
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    _statusMessage = null;
    _discoveredMap.clear();
    notifyListeners();

    try {
      final BluetoothAdapterState adapterState =
          await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        _statusMessage =
            'Activa el Bluetooth de tu teléfono y habilita "Transmitir Frecuencia Cardíaca" en tu reloj o banda.';
        notifyListeners();
        return;
      }

      // 1. Incluir dispositivos BLE ya conectados a nivel de sistema (Huawei Health, Galaxy Wearable, Whoop, etc.)
      final Set<BluetoothDevice> osDevices = <BluetoothDevice>{
        ...FlutterBluePlus.connectedDevices,
      };
      try {
        final List<BluetoothDevice> sysDevices =
            await FlutterBluePlus.systemDevices(<Guid>[
          _hrServiceGuid,
          _genericAccessGuid,
          _batteryServiceGuid,
          _huaweiWearableServiceGuid,
        ]);
        osDevices.addAll(sysDevices);
      } catch (_) {}

      for (final BluetoothDevice dev in osDevices) {
        final String name = dev.platformName.trim().isNotEmpty
            ? dev.platformName.trim()
            : 'Wearable BLE (${dev.remoteId.str})';
        _discoveredMap[dev.remoteId.str] = BleDiscoveredDevice(
          device: dev,
          displayName: name,
          remoteId: dev.remoteId.str,
          rssi: -42,
          advertisesHrService: true,
          isWearableBrand: _matchesWearableBrand(name),
        );
      }
      notifyListeners();

      // 2. Escaneo universal de anuncios BLE cercanos sin ocultar relojes Huawei/Samsung
      await _scanSub?.cancel();
      _scanSub = FlutterBluePlus.onScanResults.listen((List<ScanResult> results) {
        for (final ScanResult r in results) {
          final List<Guid> serviceUuids = r.advertisementData.serviceUuids;
          final bool hasHrUuid = serviceUuids.any(
            (Guid g) =>
                g == _hrServiceGuid ||
                g == _hrServiceShortGuid ||
                g.str.toLowerCase().contains('180d'),
          );
          final bool hasWearableServiceUuid = serviceUuids.any((Guid g) {
            final String u = g.str.toLowerCase();
            return u.contains('fee0') ||
                u.contains('fee7') ||
                u.contains('fd69') ||
                u.contains('180f');
          });

          final String rawName = r.advertisementData.advName.trim().isNotEmpty
              ? r.advertisementData.advName.trim()
              : r.device.platformName.trim();

          if (!hasHrUuid &&
              !hasWearableServiceUuid &&
              rawName.isEmpty &&
              !r.advertisementData.connectable) {
            continue;
          }
          if (rawName.isEmpty && !hasHrUuid && !hasWearableServiceUuid && r.rssi < -80) {
            continue;
          }

          final String displayName = rawName.isNotEmpty
              ? rawName
              : (hasHrUuid
                  ? 'Monitor Cardíaco 0x180D (${r.device.remoteId.str})'
                  : 'Dispositivo BLE (${r.device.remoteId.str})');

          final BleDiscoveredDevice? prev =
              _discoveredMap[r.device.remoteId.str];
          _discoveredMap[r.device.remoteId.str] = BleDiscoveredDevice(
            device: r.device,
            displayName: (rawName.isEmpty && prev != null)
                ? prev.displayName
                : displayName,
            remoteId: r.device.remoteId.str,
            rssi: r.rssi,
            advertisesHrService:
                hasHrUuid || (prev?.advertisesHrService ?? false),
            isWearableBrand: _matchesWearableBrand(displayName) ||
                hasWearableServiceUuid ||
                (prev?.isWearableBrand ?? false),
          );
        }
        notifyListeners();
      });

      await _isScanningSub?.cancel();
      _isScanningSub = FlutterBluePlus.isScanning.listen((bool scanning) {
        _isScanning = scanning;
        notifyListeners();
      });

      await FlutterBluePlus.startScan(timeout: timeout);
    } catch (e) {
      _isScanning = false;
      _statusMessage =
          'No se pudo iniciar el escaneo BLE: verifica permisos de Bluetooth cercanos.';
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    _isScanning = false;
    notifyListeners();
  }

  Future<bool> connectToDevice(
    BleDiscoveredDevice target, {
    String? userId,
  }) async {
    _isConnecting = true;
    _statusMessage = 'Conectando a ${target.displayName}...';
    notifyListeners();

    try {
      await stopScan();
      await disconnect(forgetDevice: false);

      await target.device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 12),
        autoConnect: false,
      );

      await _attachConnectionStateListener(target.device, target.displayName);

      final bool subscribed = await _subscribeToHeartRateGatt(
        target.device,
        target.displayName,
      );

      if (!subscribed) {
        await target.device.disconnect();
        _statusMessage =
            '${target.displayName} conectado, pero aún no transmite GATT 0x180D / 0x2A37. Activa "Transmitir Frecuencia Cardíaca / Broadcast HR" en tu reloj (Huawei, Samsung, Garmin o Whoop).';
        return false;
      }

      // Persistir ID y nombre del dispositivo vinculado para reconexión Zero-Touch en segundo plano
      _savedDeviceId = target.device.remoteId.str;
      _savedDeviceName = target.displayName;
      await _storage.savePairedBleDevice(
        deviceId: target.device.remoteId.str,
        deviceName: target.displayName,
        userId: userId,
      );
      _ensureBackgroundRetryTimer();
      return true;
    } catch (e) {
      _statusMessage =
          'Error al vincular con ${target.displayName}. Verifica que tenga activo "Transmitir Frecuencia Cardíaca".';
      return false;
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  Future<void> disconnect({bool forgetDevice = false, String? userId}) async {
    await _hrCharacteristicSub?.cancel();
    _hrCharacteristicSub = null;
    await _connectionStateSub?.cancel();
    _connectionStateSub = null;

    if (forgetDevice) {
      _savedDeviceId = null;
      _savedDeviceName = null;
      await _storage.clearPairedBleDevice(userId: userId);
    }

    if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect();
      } catch (_) {}
    }
    _connectedDevice = null;
    _connectedDeviceName = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _autoReconnectTimer?.cancel();
    _scanSub?.cancel();
    _isScanningSub?.cancel();
    _hrCharacteristicSub?.cancel();
    _connectionStateSub?.cancel();
    _bpmStreamController.close();
    super.dispose();
  }
}
