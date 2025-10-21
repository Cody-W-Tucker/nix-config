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

    def list_knowledge_collections(token):
        url = 'http://localhost:8080/api/v1/knowledge/list'
        headers = {'Authorization': f'Bearer {token}'}
        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            collections = response.json()
            print("Available Knowledge Collections:")
            for coll in collections:
                print(f"  ID: {coll.get('id')} - Name: {coll.get('name')}")
        else:
            print(f"Failed to list collections: {response.text}")

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
        if len(sys.argv) < 2:
            print("Usage: python script.py <token> (--list | <knowledge_id>)")
            print("  --list: List available knowledge collections")
            print("  <knowledge_id>: Upload files to the specified collection (ensure it exists)")
            sys.exit(1)
        token = sys.argv[1]
        if len(sys.argv) == 3 and sys.argv[2] == '--list':
            list_knowledge_collections(token)
        elif len(sys.argv) == 3:
            knowledge_id = sys.argv[2]
            main(token, knowledge_id)
        else:
            print("Usage: python script.py <token> (--list | <knowledge_id>)")
            sys.exit(1)
  '';
in
pkgs.writeShellScriptBin "ai-doc-upload" ''
  ${pkgs.python3.withPackages (ps: [ ps.requests ])}/bin/python3 ${pythonScript} "$@"
''
