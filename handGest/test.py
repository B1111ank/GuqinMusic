import numpy as np
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon
from matplotlib.animation import FuncAnimation, PillowWriter

# -----------------------------
# 工具函数
# -----------------------------
def rotate(points, angle):
    R = np.array([[np.cos(angle), -np.sin(angle)],
                  [np.sin(angle),  np.cos(angle)]])
    return points @ R.T

def translate(points, t):
    return points + np.array(t)

def centroid(poly):
    return poly.mean(axis=0)

# -----------------------------
# 生成等边三角形
# -----------------------------
L = 1.0
h = np.sqrt(3)/2 * L
A = np.array([0,0])
B = np.array([L,0])
C = np.array([L/2,h])
triangle = np.vstack([A,B,C])

# -----------------------------
# Dudeney 式切割示意
# -----------------------------
p = 0.33
P = A + p*(C-A)
Q = B + p*(C-B)

def line_intersection_with_y0(P, Q):
    dy = Q[1]-P[1]
    t = -P[1]/dy
    return P + t*(Q-P)

R = line_intersection_with_y0(P,Q)

poly1 = np.array([A,P,R])
poly2 = np.array([P,C,Q,R])
poly3 = np.array([R,Q,B])
poly4 = np.array([A,R,B])

pieces = [poly1, poly2, poly3, poly4]

# -----------------------------
# 目标正方形边长 s
# -----------------------------
area = L*h/2
s = np.sqrt(area)

# -----------------------------
# 目标拼接位置（示意性）
# -----------------------------
targets = [
    (0.0,         0.0,          0.0),         # (tx,ty,angle)
    (0.0,         s*0.45,       0.0),
    (s*0.60,      s*0.55,      -np.pi/6),
    (s*0.45,      0.0,          np.pi/12)
]

# -----------------------------
# 动画配置
# -----------------------------
fig, ax = plt.subplots(figsize=(6,6))
ax.set_xlim(-0.2, 1.2)
ax.set_ylim(-0.2, 1.2)
ax.set_aspect("equal")
ax.axis("off")

patches = [Polygon(p, True, fc="cornflowerblue", alpha=0.7) for p in pieces]
for patch in patches:
    ax.add_patch(patch)

# 画正方形框（目标）
sq = np.array([[0,0],[s,0],[s,s],[0,s],[0,0]])
ax.plot(sq[:,0], sq[:,1], "k--", lw=1)

# -----------------------------
# 动画更新函数
# -----------------------------
frames = 120
def animate(frame):
    t = frame / frames

    for i,(poly,patch) in enumerate(zip(pieces, patches)):
        tx, ty, ang = targets[i]
        c = centroid(poly)

        # 步骤 1：先移开一点（分离）
        sep_offset = np.array([ (i-1.5)*0.3, 0.3 ])
        moved = poly + sep_offset * min(t*2,1)

        # 步骤 2：逐渐旋转 + 平移到目标位置
        rot = rotate(moved - c, ang * t)
        rot = rot + c
        final = translate(rot, np.array([tx,ty]) * t)

        patch.set_xy(final)

    return patches

# -----------------------------
# 生成动图
# -----------------------------
ani = FuncAnimation(fig, animate, frames=frames, interval=25, blit=False)
ani.save("triangle_to_square.gif", writer=PillowWriter(fps=30))

print("🎉 已生成动图：triangle_to_square.gif")
