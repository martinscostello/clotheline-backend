# Liquid Glass UI 💎

A premium, high-fidelity refractive glass component for Flutter.
This package provides the `LiquidGlassContainer`, a widget that applies realistic refraction ("liquid warp"), a concave rim light, and depth shadows to any child widget.

## How to Use in a New Project

### 1. Add Dependency
Open your new project's `pubspec.yaml` and add the dependency pointing to where you saved this folder.

```yaml
dependencies:
  flutter:
    sdk: flutter
    
  # Add this:
  liquid_glass_ui:
    path: /Users/directorm/Anti_Gravity/LiquidGlassContainer/liquid_glass_ui
```

*Note: Update the `path` if you move the folder somewhere else.*

### 2. Get Packages
Run the flutter command to link the package:
```bash
flutter pub get
```

### 3. Import & Use
In your Dart file (e.g., `main.dart` or any screen):

```dart
import 'package:flutter/material.dart';
import 'package:liquid_glass_ui/liquid_glass_ui.dart'; // Import the package

class MyGlassCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: LiquidGlassContainer(
        // Optional Configuration
        radius: 24.0, 
        padding: EdgeInsets.all(20),
        
        // Your Content Here
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Glass Card", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text("This content is floating on liquid glass."),
          ],
        ),
      ),
    );
  }
}
```

## Features
*   **Full Refraction**: Warps the background behind the container (Center-anchored zoom).
*   **Concave Rim**: Adds a subtle inner white highlight to simulate thick glass edges.
*   **Depth Shadow**: Automatically adds a soft shadow behind the glass to lift it from the background.
*   **Responsive**: Works on all screen sizes.
