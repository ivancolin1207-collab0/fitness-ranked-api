import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleDiscoveredDevice {
  final BluetoothDevice device;
  final String displayName;
  final String remoteId;
  final int rssi;
  final bool advertisesHrService;

  const BleDiscoveredDevice({
    required this.device,
    required this.displayName,
    required this.remoteId,
    required this.rssi,
    required this.advertisesHrService,
  });
}

class BleHeartRateService extends ChangeNotifier {
  static final BleHeartRateService instance = BleHeartRateService._internal();

  factory BleHeartRateService() => instance;

  BleHeartRateService._internal();

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

  int? _latestBpm;
  int? get latestBpm => _latestBpm;

  String? _statusMessage;
  String? get statusMessage => _statusMessage;

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<bool>? _isScanningSub;
  StreamSubscription<List<int>>? _hrCharacteristicSub;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSub;

  /// Parsea el payload GATT 0x2A37 (Heart Rate Measurement) manejando
  /// las banderas UINT8 (bit 0 == 0) y UINT16 Little-Endian (bit 0 == 1)
  /// según la especificación oficial Bluetooth SIG.
  static int? parseHeartRateMeasurement(List<int> value) {
    if (value.length < 2) {
      return null;
    }
    final int flags = value[0] & 0xFF;
    final bool isUint16 = (flags & 0x01) != 0;

    int bpm;
    if (isUint16) {
      if (value.length < 3) {
        return null;
      }
      bpm = (value[1] & 0xFF) | ((value[2] & 0xFF) << 8);
    } else {
      bpm = value[1] & 0xFF;
    }

    if (bpm < 25 || bpm > 240) {
      return null;
    }
    return bpm;
  }

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
            'Activa el Bluetooth de tu dispositivo y habilita "Broadcast Heart Rate" en tu Whoop / banda.';
        notifyListeners();
        return;
      }

      // Incluir dispositivos del sistema ya conectados que expongan 0x180D
      final List<BluetoothDevice> systemDevices =
          await FlutterBluePlus.systemDevices(<Guid>[_hrServiceGuid]);
      for (final BluetoothDevice dev in systemDevices) {
        final String name = dev.platformName.trim().isNotEmpty
            ? dev.platformName.trim()
            : 'Sensor BLE (${dev.remoteId.str})';
        _discoveredMap[dev.remoteId.str] = BleDiscoveredDevice(
          device: dev,
          displayName: name,
          remoteId: dev.remoteId.str,
          rssi: -45,
          advertisesHrService: true,
        );
      }

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

          final String rawName = r.advertisementData.advName.trim().isNotEmpty
              ? r.advertisementData.advName.trim()
              : r.device.platformName.trim();

          if (!hasHrUuid && rawName.isEmpty) {
            continue;
          }

          final String displayName = rawName.isNotEmpty
              ? rawName
              : 'Monitor Cardíaco 0x180D (${r.device.remoteId.str})';

          _discoveredMap[r.device.remoteId.str] = BleDiscoveredDevice(
            device: r.device,
            displayName: displayName,
            remoteId: r.device.remoteId.str,
            rssi: r.rssi,
            advertisesHrService: hasHrUuid,
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

  Future<bool> connectToDevice(BleDiscoveredDevice target) async {
    _isConnecting = true;
    _statusMessage = 'Conectando a ${target.displayName}...';
    notifyListeners();

    try {
      await stopScan();
      await disconnect();

      await target.device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 12),
        autoConnect: false,
      );

      _connectionStateSub = target.device.connectionState.listen(
        (BluetoothConnectionState state) {
          if (state == BluetoothConnectionState.disconnected) {
            _connectedDevice = null;
            _connectedDeviceName = null;
            _statusMessage = 'Dispositivo BLE desconectado.';
            notifyListeners();
          }
        },
      );

      final List<BluetoothService> services =
          await target.device.discoverServices();
      BluetoothCharacteristic? hrCharacteristic;

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
        }
        if (hrCharacteristic != null) {
          break;
        }
      }

      if (hrCharacteristic == null) {
        await target.device.disconnect();
        _statusMessage =
            '${target.displayName} no expone el servicio GATT 0x180D / 0x2A37. Si usas Whoop, activa "Broadcast Heart Rate".';
        return false;
      }

      await hrCharacteristic.setNotifyValue(true);
      await _hrCharacteristicSub?.cancel();
      _hrCharacteristicSub =
          hrCharacteristic.onValueReceived.listen((List<int> payload) {
        final int? bpm = parseHeartRateMeasurement(payload);
        if (bpm != null) {
          _latestBpm = bpm;
          _bpmStreamController.add(bpm);
          notifyListeners();
        }
      });

      _connectedDevice = target.device;
      _connectedDeviceName = target.displayName;
      _statusMessage =
          'Conectado a ${target.displayName} (GATT 0x180D • Notificaciones 0x2A37 activas)';
      return true;
    } catch (e) {
      _statusMessage =
          'Error al vincular con ${target.displayName}. Verifica que esté en modo transmisión.';
      return false;
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    await _hrCharacteristicSub?.cancel();
    _hrCharacteristicSub = null;
    await _connectionStateSub?.cancel();
    _connectionStateSub = null;

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
    _scanSub?.cancel();
    _isScanningSub?.cancel();
    _hrCharacteristicSub?.cancel();
    _connectionStateSub?.cancel();
    _bpmStreamController.close();
    super.dispose();
  }
}
