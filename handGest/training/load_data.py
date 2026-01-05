import os
import json
import numpy as np
from sklearn.preprocessing import LabelEncoder

DATA_DIR      = "./data"
GESTURES      = ['tap','press','slide','smear','pick','knead']
FRAMES_PER_SAMPLE = 25
FEATURES_PER_FRAME = 21 * 3   # 21 hand landmarks × x,y,z

def load_data():
    X = []
    y = []
    for lbl in GESTURES:
        folder = os.path.join(DATA_DIR, lbl)
        for fname in os.listdir(folder):
            if not fname.endswith('.json'):
                continue
            with open(os.path.join(folder, fname), 'r') as f:
                obj = json.load(f)
            frames = obj['frames']
            # ensure exactly FRAMES_PER_SAMPLE
            if len(frames) != FRAMES_PER_SAMPLE:
                continue   # or pad/truncate if you want
            # convert frames into numpy array
            arr = np.array(frames, dtype=np.float32)  # shape (25, 63)
            X.append(arr)
            y.append(lbl)
    X = np.array(X)  # shape (num_samples, 25, 63)
    # Flatten if you choose
    num_samples = X.shape[0]
    X_flat = X.reshape(num_samples, FRAMES_PER_SAMPLE * FEATURES_PER_FRAME)
    le = LabelEncoder()
    y_enc = le.fit_transform(y)
    return X_flat, y_enc, le

if __name__ == "__main__":
    X, y, le = load_data()
    print("X shape:", X.shape)
    print("Labels:", le.classes_)
    # Save X, y, le if you want
