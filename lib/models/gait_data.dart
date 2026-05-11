class SensorData {
  final String deviceId;
  String role; // left_pressure, right_pressure, left_imu, right_imu
  
  double? pressure1;
  double? pressure2;
  double? pressure3;
  double? accX;
  double? accY;
  double? accZ;
  double? gyroX;
  double? gyroY;
  double? gyroZ;
  double? roll;
  double? pitch;
  double? yaw;
  DateTime lastUpdated;

  SensorData({
    required this.deviceId,
    required this.role,
    this.pressure1,
    this.pressure2,
    this.pressure3,
    this.accX,
    this.accY,
    this.accZ,
    this.gyroX,
    this.gyroY,
    this.gyroZ,
    this.roll,
    this.pitch,
    this.yaw,
  }) : lastUpdated = DateTime.now();

  bool get isPressure => role == 'left_pressure' || role == 'right_pressure';
  bool get isIMU => role == 'left_imu' || role == 'right_imu';
}

class RecordEntry {
  final DateTime timestamp;
  final String label;
  final double? p1R, p2R, p3R;
  final double? accXR, accYR, accZR;
  final double? gyroXR, gyroYR, gyroZR;
  final double? rollR, pitchR, yawR;
  final double? p1L, p2L, p3L;
  final double? accXL, accYL, accZL;
  final double? gyroXL, gyroYL, gyroZL;
  final double? rollL, pitchL, yawL;

  RecordEntry({
    required this.timestamp,
    required this.label,
    this.p1R, this.p2R, this.p3R,
    this.accXR, this.accYR, this.accZR,
    this.gyroXR, this.gyroYR, this.gyroZR,
    this.rollR, this.pitchR, this.yawR,
    this.p1L, this.p2L, this.p3L,
    this.accXL, this.accYL, this.accZL,
    this.gyroXL, this.gyroYL, this.gyroZL,
    this.rollL, this.pitchL, this.yawL,
  });

  List<String> toCsvRow() => [
    timestamp.toIso8601String(),
    p1R?.toStringAsFixed(1) ?? '',
    p2R?.toStringAsFixed(1) ?? '',
    p3R?.toStringAsFixed(1) ?? '',
    accXR?.toStringAsFixed(3) ?? '',
    accYR?.toStringAsFixed(3) ?? '',
    accZR?.toStringAsFixed(3) ?? '',
    gyroXR?.toStringAsFixed(1) ?? '',
    gyroYR?.toStringAsFixed(1) ?? '',
    gyroZR?.toStringAsFixed(1) ?? '',
    rollR?.toStringAsFixed(1) ?? '',
    pitchR?.toStringAsFixed(1) ?? '',
    yawR?.toStringAsFixed(1) ?? '',
    p1L?.toStringAsFixed(1) ?? '',
    p2L?.toStringAsFixed(1) ?? '',
    p3L?.toStringAsFixed(1) ?? '',
    accXL?.toStringAsFixed(3) ?? '',
    accYL?.toStringAsFixed(3) ?? '',
    accZL?.toStringAsFixed(3) ?? '',
    gyroXL?.toStringAsFixed(1) ?? '',
    gyroYL?.toStringAsFixed(1) ?? '',
    gyroZL?.toStringAsFixed(1) ?? '',
    rollL?.toStringAsFixed(1) ?? '',
    pitchL?.toStringAsFixed(1) ?? '',
    yawL?.toStringAsFixed(1) ?? '',
    label,
  ];

  static List<String> csvHeader = [
    'timestamp', 'P_first_meta_R', 'P_Fifth_meta_R', 'P_heel_R',
    'acc_x_R', 'acc_y_R', 'acc_z_R', 'ave_x_R', 'ave_y_R', 'ave_z_R',
    'ang_x_R', 'ang_y_R', 'ang_z_R', 'P_first_meta_L', 'P_Fifth_meta_L', 'P_heel_L',
    'acc_x_L', 'acc_y_L', 'acc_z_L', 'ave_x_L', 'ave_y_L', 'ave_z_L',
    'ang_x_L', 'ang_y_L', 'ang_z_L', 'Label',
  ];
}
