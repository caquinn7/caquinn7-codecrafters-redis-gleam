import socket
import time
from colorama import init as init_colorama, Fore

init_colorama(autoreset=True)

HOST = 'localhost'
PORT = 6379

def test(sock, send, expected):
    print('sending:')
    print(send)
    response = send_and_receive(sock, send)
    print('received:')

    color = Fore.GREEN if response == expected else Fore.RED
    print(color + response)

def send_and_receive(sock, input):
    sock.sendall(input.encode('utf8'))
    return sock.recv(1024).decode('utf8')

def open_conn():
    sock = socket.create_connection((HOST, PORT))
    print('Connected successfully!')
    return sock

with open_conn() as sock:
    test(sock, '*1\r\n$4\r\nPING\r\n', "+PONG\r\n")
    test(sock, '*2\r\n$4\r\nECHO\r\n$3\r\nhey\r\n', "$3\r\nhey\r\n")
    test(sock, '*3\r\n$3\r\nSET\r\n$3\r\nfoo\r\n$3\r\nbar\r\n', '+OK\r\n')
    test(sock, '*2\r\n$3\r\nGET\r\n$3\r\nfoo\r\n', '$3\r\nbar\r\n')
    test(sock, '*2\r\n$3\r\nGET\r\n$3\r\nxxx\r\n', '$-1\r\n')
    test(sock, '*5\r\n$3\r\nSET\r\n$5\r\nhello\r\n$5\r\nworld\r\n$2\r\nPX\r\n$3\r\n100\r\n', '+OK\r\n')
    test(sock, '*2\r\n$3\r\nGET\r\n$3\r\nfoo\r\n', '$3\r\nbar\r\n')
    time.sleep(101 / 1000)
    test(sock, '*2\r\n$3\r\nGET\r\n$5\r\nhello\r\n', '$-1\r\n')
    
    test(sock, '*2\r\n$4\r\nECHO\r\n', '-ERR Syntax error\r\n')
    test(sock, '*2\r\n$3\r\nGET\r\n$-1\r\n', '-ERR Invalid value for "key": Value cannot be null\r\n')
    test(sock, '*1\r\n$3\r\nGET\r\n', '-ERR Wrong number of arguments\r\n')
    test(sock, '*5\r\n$3\r\nSET\r\n$5\r\nhello\r\n$5\r\nworld\r\n$2\r\nPX\r\n$3\r\nabc\r\n',
         '-ERR Invalid value for "PX": Value must be a postive integer\r\n')
    test(sock, '*1\r\n$3\r\nXXX\r\n', '-ERR Invalid command: "XXX"\r\n')

with open_conn() as sock:
    test(sock, '*2\r\n$3\r\nGET\r\n$3\r\nfoo\r\n', '$3\r\nbar\r\n')
    # test(sock, '*3\r\n$6\r\nCONFIG\r\n$3\r\nGET\r\n$3\r\ndir\r\n', '*2\r\n$3\r\ndir\r\n$39\r\n/Users/caquinn/codecrafters-redis-gleam\r\n')
    # test(sock, '*4\r\n$6\r\nCONFIG\r\n$3\r\nGET\r\n$3\r\ndir\r\n$10\r\ndbfilename\r\n',
    #      '*4\r\n$3\r\ndir\r\n$39\r\n/Users/caquinn/codecrafters-redis-gleam\r\n$10\r\ndbfilename\r\n$8\r\ndump.rdb\r\n')
# ./spawn_redis_server.sh --dir /Users/caquinn/codecrafters-redis-gleam --dbfilename dump.rdb
    