{ pkgs }:

let
  pythonScript = pkgs.writeText "ai-doc-upload.py" ''
    import requests
    import os
    import sys
    import json



    def upload_file(token, file_path):
        url = 'http://localhost:8080/api/v1/files/upload'
        headers = {'Authorization': f'Bearer {token}'}
        with open(file_path, 'rb') as f:
            files = {'file': f}
            response = requests.post(url, headers=headers, files=files)
            if response.status_code == 200:
                return response.json()['id']
            else:
                print(f"Failed to upload {file_path}: {response.text}")
                return None

    def add_file_to_knowledge(token, knowledge_id, file_id):
        url = f'http://localhost:8080/api/v1/knowledge/{knowledge_id}/file/add'
        headers = {
            'Authorization': f'Bearer {token}',
            'Content-Type': 'application/json'
        }
        data = {'file_id': file_id}
        response = requests.post(url, headers=headers, json=data)
        if response.status_code != 200:
            print(f"Failed to add file to knowledge: {response.text}")

    def main(token, knowledge_id):
        print(f"Uploading files to knowledge collection '{knowledge_id}' (ensure it exists in Open-WebUI UI).")

        for file_name in os.listdir('.'):
            if os.path.isfile(file_name):
                print(f"Uploading {file_name}...")
                file_id = upload_file(token, file_name)
                if file_id:
                    add_file_to_knowledge(token, knowledge_id, file_id)
                    print(f"Added {file_name} to knowledge collection.")

    if __name__ == "__main__":
        if len(sys.argv) < 3:
            print("Usage: python script.py <token> <knowledge_id>")
            print("Note: Ensure the knowledge collection exists in Open-WebUI UI before running.")
            sys.exit(1)
        token = sys.argv[1]
        knowledge_id = sys.argv[2]
        main(token, knowledge_id)
  '';
in
pkgs.writeShellScriptBin "ai-doc-upload" ''
  ${pkgs.python3.withPackages (ps: [ ps.requests ])}/bin/python3 ${pythonScript} "$@"
''
