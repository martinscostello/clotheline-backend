import 'package:flutter/material.dart';

class GlobalErrorBoundary extends StatefulWidget {
  final Widget child;

  const GlobalErrorBoundary({required this.child, super.key});

  @override
  State<GlobalErrorBoundary> createState() => _GlobalErrorBoundaryState();
}

class _GlobalErrorBoundaryState extends State<GlobalErrorBoundary> {
  bool hasError = false;
  FlutterErrorDetails? errorDetails;

  @override
  void initState() {
    super.initState();
    // Override FlutterError.onError to catch errors mostly in debug, 
    // but ErrorWidget.builder captures build errors in release/debug.
    // Here we mainly rely on the widget build phase catching.
  }

  // Catch build phase errors
  @override
  Widget build(BuildContext context) {
    ErrorWidget.builder = (FlutterErrorDetails details) {
      // In development, you might want the red screen, but in prod, show this.
      // We can check kDebugMode. But implementation implies we want a custom screen regardless.
      return _buildErrorScreen(details);
    };
    return widget.child;
  }

  Widget _buildErrorScreen(FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFF101020),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 60),
              const SizedBox(height: 20),
              const Text(
                "Oops! Something went wrong.",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                details.exception.toString().split('\n').first, // Short Summary
                style: const TextStyle(color: Colors.white54, fontSize: 13),
                textAlign: TextAlign.center,
                maxLines: 3, 
                overflow: TextOverflow.ellipsis
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black 
                ),
                onPressed: () {
                   // Navigate to Root or Reload?
                   // Hard to reload just this widget without a key reset.
                   // Ideally we reset the App. Use main.dart logic if accessible.
                   // Or just pop navigation if possible.
                   // Simple action: Trigger a rebuild if transient?
                   // For now, simple "Reload App" by invoking main() or hot restart unavailable in prod.
                   // We just ask user to restart app or try back.
                   // Navigating to '/' might help.
                   Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/', (route) => false);
                },
                icon: const Icon(Icons.refresh),
                label: const Text("RESTART APP"),
              )
            ],
          ),
        ),
      ),
    );
  }
}
