import socket

# UDP发送套接字
def udp_send(msg, ip="127.0.0.1", port=30000):
    # 1.创建一个udp套接字
    sendSocket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    # 2.准备接收方的地址
    # 192.168.65.149 表示目的地ip
    # 30000  表示目的地端口
    sendSocket.sendto(msg.encode("utf-8"), (ip, port))

    # 3.关闭套接字
    sendSocket.close()