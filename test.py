import socket
import time
from colorama import init as init_colorama, Fore

init_colorama(autoreset=True)

HOST = 'localhost'
PORT = 6379

def test(sock, send, expected):
    print('sending:')
    print(send)
    response = send_and_receive(sock, send).decode()
    print('received:')

    color = Fore.GREEN if response == expected else Fore.RED
    print(color + response)

def send_and_receive(sock, input):
    sock.sendall(input.encode())
    return sock.recv(1024)

with socket.create_connection((HOST, PORT)) as sock:
    print('Connected successfully!')
    test(sock, '*1\r\n$4\r\nPING\r\n', "+PONG\r\n")
    test(sock, '*2\r\n$4\r\nECHO\r\n$3\r\nhey\r\n', "$3\r\nhey\r\n")
    test(sock, '*3\r\n$3\r\nSET\r\n$3\r\nfoo\r\n$3\r\nbar\r\n', '+OK\r\n')
    test(sock, '*2\r\n$3\r\nGET\r\n$3\r\nfoo\r\n', '$3\r\nbar\r\n')
    test(sock, '*2\r\n$3\r\nGET\r\n$3\r\nxxx\r\n', '$-1\r\n')
    test(sock, '*5\r\n$3\r\nSET\r\n$5\r\nhello\r\n$5\r\nworld\r\n$2\r\nPX\r\n$3\r\n100\r\n', '+OK\r\n')
    test(sock, '*2\r\n$3\r\nGET\r\n$3\r\nfoo\r\n', '$3\r\nbar\r\n')
    time.sleep(101 / 1000)
    test(sock, '*2\r\n$3\r\nGET\r\n$5\r\nhello\r\n', '$-1\r\n')
    