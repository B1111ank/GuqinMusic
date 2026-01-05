// capture.js

// Number of decimal places to keep
const DECIMALS = 5;

// Utility: round a number to `decimals` places
function roundTo(val, decimals) {
  const factor = Math.pow(10, decimals);
  return Math.round(val * factor) / factor;
}

// UI elements
const gestureSelect = document.getElementById('gestureSelect');
const startBtn      = document.getElementById('startBtn');
const stopBtn       = document.getElementById('stopBtn');
const statusSpan    = document.getElementById('status');
const FRAME_LIMIT = 25;

let recording     = false;
let currentLabel  = null;
let framesBuffer  = [];

// Setup video and canvas
const videoElement  = document.getElementById('video');
const canvasElement = document.getElementById('output');
const canvasCtx     = canvasElement.getContext('2d');

// Initialize MediaPipe Hands
const hands = new Hands({
  locateFile: file => `https://cdn.jsdelivr.net/npm/@mediapipe/hands/${file}`
});
hands.setOptions({
  maxNumHands            : 1,
  modelComplexity        : 1,
  minDetectionConfidence : 0.5,
  minTrackingConfidence  : 0.5
});
hands.onResults(onResults);

// Camera setup
const camera = new Camera(videoElement, {
  onFrame: async () => {
    await hands.send({ image: videoElement });
  },
  width : 640,
  height: 480
});
camera.start();

// UI event handlers
startBtn.onclick = () => {
  currentLabel = gestureSelect.value;
  recording    = true;
  framesBuffer = [];
  statusSpan.textContent = `Recording: ${currentLabel}`;
  startBtn.disabled = true;
  stopBtn.disabled  = false;
};

stopBtn.onclick = () => {
  recording = false;
  statusSpan.textContent = `Saved ${framesBuffer.length} frames of label: ${currentLabel}`;
  startBtn.disabled = false;
  stopBtn.disabled  = true;
  downloadSample(currentLabel, framesBuffer);
};

// Main callback when hands results arrive
function onResults(results) {
  // draw camera + landmarks
  canvasCtx.save();
  canvasCtx.clearRect(0, 0, canvasElement.width, canvasElement.height);
  canvasCtx.drawImage(results.image, 0, 0, canvasElement.width, canvasElement.height);

  if (results.multiHandLandmarks && results.multiHandLandmarks.length > 0) {
    const landmarks = results.multiHandLandmarks[0];
    drawConnectors(canvasCtx, landmarks, HAND_CONNECTIONS, { color: '#00FF00', lineWidth: 2 });
    drawLandmarks(canvasCtx, landmarks, { color: '#FF0000', lineWidth: 1 });

    if (recording) {
      // Flatten the landmarks into a single rounded-vector [x0,y0,z0, x1,y1,z1, …]
      const vector = landmarks.flatMap(lm => [
        roundTo(lm.x, DECIMALS),
        roundTo(lm.y, DECIMALS),
        roundTo(lm.z, DECIMALS)
      ]);
      framesBuffer.push(vector);

      // Stop automatically after 25 frames
      if (framesBuffer.length >= FRAME_LIMIT) {
        recording = false;
        statusSpan.textContent = `Captured ${FRAME_LIMIT} frames for: ${currentLabel}`;
        startBtn.disabled = false;
        stopBtn.disabled  = true;
        downloadSample(currentLabel, framesBuffer);
      }
    }

  }

  canvasCtx.restore();
}

// Function to download recorded sample as JSON
function downloadSample(label, frames) {
  const data = {
    label : label,
    frames: frames
  };
  const blob = new Blob([ JSON.stringify(data) ], { type: 'application/json' });
  const url  = URL.createObjectURL(blob);
  const a    = document.createElement('a');
  a.href     = url;
  a.download = `gesture_${label}_${Date.now()}.json`;
  a.click();
  URL.revokeObjectURL(url);
}
