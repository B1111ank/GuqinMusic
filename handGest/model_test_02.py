import cv2
import mediapipe as mp
import numpy as np
import tensorflow as tf
from collections import deque

# ================= 配置区域 =================
MODEL_PATH = "./trained_model/gesture_classifier.h5"
# 确保名称顺序与训练时一致
GESTURE_NAMES = ['knead', 'pick', 'press', 'slide', 'smear', 'tap']

FRAME_BUFFER_SIZE = 25
CONFIDENCE_THRESHOLD = 0.75
# ===========================================


def main():
    print(f"正在加载模型: {MODEL_PATH} ...")
    try:
        model = tf.keras.models.load_model(MODEL_PATH)
        print("✅ 模型加载成功")
    except Exception as e:
        print(f"❌ 错误：无法加载模型。\n{e}")
        return

    mp_hands = mp.solutions.hands
    mp_drawing = mp.solutions.drawing_utils
    hands = mp_hands.Hands(
        max_num_hands=1,
        model_complexity=1,
        min_detection_confidence=0.5,
        min_tracking_confidence=0.5
    )

    cap = cv2.VideoCapture(0)
    frames_buffer = deque(maxlen=FRAME_BUFFER_SIZE)

    display_text = "Initializing..."
    display_color = (200, 200, 200)
    display_conf = 0.0

    # 存储当前帧的手心坐标
    current_center_coords = None

    print("🎥 摄像头已开启，按 'q' 退出")

    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break

        frame = cv2.flip(frame, 1)
        h, w, c = frame.shape
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = hands.process(rgb_frame)

        hand_detected = False
        current_center_coords = None

        if results.multi_hand_landmarks:
            hand_detected = True
            for hand_landmarks in results.multi_hand_landmarks:
                mp_drawing.draw_landmarks(frame, hand_landmarks, mp_hands.HAND_CONNECTIONS)

                # --- 核心修改：获取手部中心 (9号点) ---
                # Landmark 9 是 MIDDLE_FINGER_MCP (中指指关节，位于手掌中央)
                center_lm = hand_landmarks.landmark[9]

                # 转换为像素坐标
                cx, cy = int(center_lm.x * w), int(center_lm.y * h)
                current_center_coords = (cx, cy)

                # 提取特征用于预测
                landmarks = []
                for lm in hand_landmarks.landmark:
                    landmarks.extend([lm.x, lm.y, lm.z])
                frames_buffer.append(landmarks)

        # 预测逻辑
        if hand_detected and len(frames_buffer) == FRAME_BUFFER_SIZE:
            input_tensor = np.array(frames_buffer, dtype=np.float32).flatten()
            input_tensor = np.expand_dims(input_tensor, axis=0)

            predictions = model.predict(input_tensor, verbose=0)
            predicted_idx = np.argmax(predictions[0])
            display_conf = np.max(predictions[0])

            if predicted_idx < len(GESTURE_NAMES):
                current_label = GESTURE_NAMES[predicted_idx]
            else:
                current_label = "Unknown"

            if display_conf > CONFIDENCE_THRESHOLD:
                display_text = f"{current_label.upper()}"
                display_color = (0, 255, 0)
            else:
                display_text = f"{current_label}?"
                display_color = (0, 165, 255)

        elif not hand_detected:
            if len(frames_buffer) > 0:
                frames_buffer.clear()
                display_text = "Waiting..."
                display_conf = 0

        # --- 输出：打印手势名称 + 中心坐标 ---
        if current_center_coords:
            print(f"手势: {display_text:<10} | 置信度: {display_conf:.2f} | 中心坐标: {cx/w*1.0:.3f}, {cy/h*1.0:.3f}")

        # --- UI 绘制 ---
        cv2.rectangle(frame, (0, 0), (w, 80), (0, 0, 0), -1)
        cv2.putText(frame, f"Action: {display_text}", (20, 50),
                    cv2.FONT_HERSHEY_SIMPLEX, 1.2, display_color, 2)

        # --- 可视化：在画面上画出手心位置 ---
        if current_center_coords:
            cx, cy = current_center_coords
            # 画一个红色的实心圆代表手心
            cv2.circle(frame, (cx, cy), 8, (0, 0, 255), -1)
            # 在圆旁边显示坐标文字
            cv2.putText(frame, f"Center({cx},{cy})", (cx+15, cy),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 255), 1)

        # 进度条
        buffer_ratio = len(frames_buffer) / FRAME_BUFFER_SIZE
        cv2.rectangle(frame, (0, h-10), (int(w * buffer_ratio), h), (0, 255, 255), -1)

        cv2.imshow('Hand Center Tracking', frame)

        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    cap.release()
    cv2.destroyAllWindows()
    hands.close()

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(e)