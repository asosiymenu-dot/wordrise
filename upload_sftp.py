import paramiko
import sys

def upload_file(host, port, username, password, local_path, remote_path):
    try:
        transport = paramiko.Transport((host, port))
        transport.connect(username=username, password=password)
        sftp = paramiko.SFTPClient.from_transport(transport)
        
        sftp.put(local_path, remote_path)
        print("✅ File uploaded successfully to " + remote_path)
        
        sftp.close()
        transport.close()
    except Exception as e:
        print("❌ Error uploading file: " + str(e))

if __name__ == "__main__":
    host = sys.argv[1]
    username = sys.argv[2]
    password = sys.argv[3]
    local_path = sys.argv[4]
    remote_path = sys.argv[5]
    
    upload_file(host, 22, username, password, local_path, remote_path)
