import 'dart:js' as dart_js;

void playWebNotificationSound() {
  try {
    dart_js.context.callMethod('eval', [
      """
      (function() {
        try {
          var audioCtx = new (window.AudioContext || window.webkitAudioContext)();
          var oscillator = audioCtx.createOscillator();
          var gainNode = audioCtx.createGain();
          oscillator.connect(gainNode);
          gainNode.connect(audioCtx.destination);
          oscillator.type = 'sine';
          oscillator.frequency.setValueAtTime(880, audioCtx.currentTime);
          gainNode.gain.setValueAtTime(0, audioCtx.currentTime);
          gainNode.gain.linearRampToValueAtTime(0.3, audioCtx.currentTime + 0.1);
          gainNode.gain.linearRampToValueAtTime(0, audioCtx.currentTime + 0.5 );
          oscillator.start();
          oscillator.stop(audioCtx.currentTime + 0.5);
        } catch (inner) {
          console.error('AudioContext error:', inner);
        }
      })();
      """
    ]);
  } catch (e) {
    // Silently fail if audio context is blocked by browser policy
  }
}
