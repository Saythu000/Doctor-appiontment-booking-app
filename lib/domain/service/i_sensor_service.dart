abstract class ISensorService {
  Future<void> startSensor();
  Future<void> stopSensor();
  Stream<dynamic> get dataStream;
}
