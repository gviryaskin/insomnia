import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:win32/win32.dart';

void main() {
  runApp(const MouseMoverApp());
}

class MouseMoverApp extends StatelessWidget {
  const MouseMoverApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mouse Mover',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const MouseMoverHomePage(),
    );
  }
}

class MouseMoverHomePage extends StatefulWidget {
  const MouseMoverHomePage({super.key});

  @override
  State<MouseMoverHomePage> createState() => _MouseMoverHomePageState();
}

class _MouseMoverHomePageState extends State<MouseMoverHomePage> {
  bool _isActive = false;
  Timer? _timer;
  String _statusText = 'Выключено';
  String? _errorText;

  static const Duration _moveInterval = Duration(seconds: 30);

  int _countdownSeconds = 30;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isActive = !_isActive;
      _statusText = _isActive ? 'Включено' : 'Выключено';
      _errorText = null;
    });

    if (_isActive) {
      _startMovingMouse();
    } else {
      _stopMovingMouse();
    }
  }

  void _startMovingMouse() {
    _timer?.cancel();
    _moveMouseOnce();
    _timer = Timer.periodic(_moveInterval, (_) => _moveMouseOnce());
    _startCountdown();
  }

  void _stopMovingMouse() {
    _timer?.cancel();
    _timer = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    setState(() {
      _countdownSeconds = 30;
    });
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownSeconds = _moveInterval.inSeconds;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tickCountdown());
  }

  void _tickCountdown() {
    setState(() {
      if (_countdownSeconds > 0) {
        _countdownSeconds--;
      } else {
        _countdownSeconds = _moveInterval.inSeconds;
      }
    });
  }

  Future<void> _moveMouseOnce() async {
    if (!Platform.isWindows) {
      if (mounted) {
        setState(() {
          _errorText = 'Функция доступна только на Windows';
        });
      }
      return;
    }

    try {
      final point = calloc.allocate<POINT>(sizeOf<POINT>());
      final result = GetCursorPos(point);
      if (result == 0) {
        throw Exception('GetCursorPos вернул 0 (ошибка WinAPI)');
      }

      final currentX = point.ref.x;
      final currentY = point.ref.y;

      SetCursorPos(currentX + 1, currentY + 1);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      SetCursorPos(currentX, currentY);

      calloc.free(point);

      if (mounted && _isActive) {
        _startCountdown();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = 'Ошибка WinAPI: $e';
        });
      }
      _stopMovingMouse();
      setState(() {
        _isActive = false;
        _statusText = 'Выключено (ошибка)';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mouse Mover — не даём уходить в спящий режим'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isActive ? Icons.computer : Icons.computer_outlined,
                size: 96,
                color: _isActive ? Colors.green : Colors.grey,
              ),
              const SizedBox(height: 32),
              Text(
                'Шевеление мышкой:',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                _statusText,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: _isActive ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 32),
              if (_isActive)
                Text(
                  'До следующего движения: $_countdownSeconds сек.',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text(
                  'Предотвратить переход в спящий режим',
                  style: TextStyle(fontSize: 16),
                ),
                subtitle: const Text(
                  'Когда включено, курсор будет немного двигаться каждые 30 сек.',
                  style: TextStyle(fontSize: 13),
                ),
                value: _isActive,
                activeThumbColor: Colors.green,
                onChanged: (_) => _toggle(),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 24),
              if (!Platform.isWindows)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Функция управления мышкой доступна только на Windows.',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_errorText != null)
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorText!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
