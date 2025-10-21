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
        try:
            with open(file_path, 'rb') as f:
                files = {'file': f}
                response = requests.post(url, headers=headers, files=files)
                if response.status_code == 200:
                    data = response.json()
                    if 'id' in data:
                        return data['id']
                    else:
                        print(f"Unexpected response format for {file_path}: {data}")
                        return None
                else:
                    print(f"Failed to upload {file_path}: HTTP {response.status_code} - {response.text}")
                    return None
        except Exception as e:
            print(f"Error uploading {file_path}: {str(e)}")
            return None

    def list_knowledge_collections(token):
        url = 'http://localhost:8080/api/v1/knowledge/list'
        headers = {'Authorization': f'Bearer {token}'}
        try:
            response = requests.get(url, headers=headers, timeout=10)
            if response.status_code == 200:
                collections = response.json()
                print("Available Knowledge Collections:")
                for coll in collections:
                    print(f"  ID: {coll.get('id')} - Name: {coll.get('name')}")
            else:
                print(f"Failed to list collections: HTTP {response.status_code} - {response.text}")
        except requests.exceptions.RequestException as e:
            print(f"Network error listing collections: {str(e)}")
        except Exception as e:
            print(f"Error listing collections: {str(e)}")

    def add_file_to_knowledge(token, knowledge_id, file_id):
        url = f'http://localhost:8080/api/v1/knowledge/{knowledge_id}/file/add'
        headers = {
            'Authorization': f'Bearer {token}',
            'Content-Type': 'application/json'
        }
        data = {'file_id': file_id}
        try:
            response = requests.post(url, headers=headers, json=data, timeout=30)
            if response.status_code == 200:
                return True
            else:
                print(f"Failed to add file to knowledge: HTTP {response.status_code} - {response.text}")
                return False
        except requests.exceptions.RequestException as e:
            print(f"Network error adding file to knowledge: {str(e)}")
            return False
        except Exception as e:
            print(f"Error adding file to knowledge: {str(e)}")
            return False

    def validate_knowledge_collection(token, knowledge_id):
        url = 'http://localhost:8080/api/v1/knowledge/list'
        headers = {'Authorization': f'Bearer {token}'}
        try:
            response = requests.get(url, headers=headers, timeout=10)
            if response.status_code == 200:
                collections = response.json()
                for coll in collections:
                    if coll.get('id') == knowledge_id:
                        return True
                return False
            else:
                print(f"Failed to validate knowledge collection: HTTP {response.status_code} - {response.text}")
                return False
        except requests.exceptions.RequestException as e:
            print(f"Network error validating collection: {str(e)}")
            return False
        except Exception as e:
            print(f"Error validating collection: {str(e)}")
            return False

    def main(token, knowledge_id):
        print(f"Uploading files to knowledge collection '{knowledge_id}' (ensure it exists in Open-WebUI UI).")

        # Validate collection exists
        if not validate_knowledge_collection(token, knowledge_id):
            print(f"Error: Knowledge collection '{knowledge_id}' does not exist or is not accessible.")
            return

        uploaded_count = 0
        for file_name in os.listdir('.'):
            if os.path.isfile(file_name):
                print(f"Uploading {file_name}...")
                file_id = upload_file(token, file_name)
                if file_id:
                    if add_file_to_knowledge(token, knowledge_id, file_id):
                        print(f"Added {file_name} to knowledge collection.")
                        uploaded_count += 1
                    else:
                        print(f"Failed to add {file_name} to knowledge collection.")
                else:
                    print(f"Failed to upload {file_name}.")

        print(f"Upload complete. Successfully processed {uploaded_count} files.")

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
