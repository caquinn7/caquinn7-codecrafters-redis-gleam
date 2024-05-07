import socket

HOST = 'localhost'
PORT = 6379

with socket.create_connection((HOST, PORT)) as sock:
    print("Connected successfully!")
    
    inputs = [
        "*1\r\n$4\r\nPING\r\n",
        "*2\r\n$4\r\nECHO\r\n$3\r\nhey\r\n",
        "*3\r\n$3\r\nSET\r\n$3\r\nfoo\r\n$3\r\nbar\r\n",
        "*2\r\n$3\r\nGET\r\n$3\r\nfoo\r\n",
    ]
    
    for input in inputs:
        print("Sending:")
        print(input)
        
        sock.sendall(input.encode())
        response = sock.recv(1024)

        print("Received:")
        print(response.decode())