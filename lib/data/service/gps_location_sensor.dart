import 'dart:async';
import 'package:geolocator/geolocator.dart';

class GPSLocationSensor {
  StreamSubscription<Position>? _subscription;
  final StreamController<Position> _controller = StreamController<Position>.broadcast();

  Stream<Position> get dataStream => _controller.stream;

  Future<void> startSensor() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _controller.addError('Location services are disabled.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _controller.addError('Location permissions are denied');
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      _controller.addError('Location permissions are permanently denied, we cannot request permissions.');
      return;
    } 

    _subscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3, // Emits an event every 3 meters of movement
      ),
    ).listen(
      (Position position) {
        _controller.add(position);
      },
      onError: (error) {
        _controller.addError(error);
      },
    );
  }

  Future<void> stopSensor() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
