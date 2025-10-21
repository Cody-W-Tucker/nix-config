{ pkgs }:

let
  pythonScript = pkgs.writeText "ai-doc-upload.py" ''
    import requests
    import os
    import sys
    import json
    import time
    import concurrent.futures
    from pathlib import Path



    def get_processing_timeout(file_path):
        """Get appropriate timeout based on file type"""
        file_ext = os.path.splitext(file_path)[1].lower()

        # Timeouts in seconds based on file type
        timeouts = {
            '.txt': 30, '.md': 30, '.json': 30, '.csv': 30,  # Text files: fast
            '.pdf': 120, '.docx': 90, '.doc': 90,             # Documents: medium
            '.jpg': 90, '.png': 90, '.jpeg': 90, '.gif': 60,  # Images: OCR time
            '.mp3': 300, '.wav': 300, '.flac': 300,           # Audio: transcription
            '.mp4': 600, '.avi': 600, '.mov': 600,            # Video: long processing
        }

        return timeouts.get(file_ext, 120)  # Default 2 minutes

    def upload_file_async(token, file_path):
        """Upload file with async processing enabled"""
        url = 'http://localhost:8080/api/v1/files/'
        headers = {'Authorization': f'Bearer {token}'}
        # Enable async processing for better performance
        params = {'process': 'true', 'process_in_background': 'true'}
        try:
            with open(file_path, 'rb') as f:
                files = {'file': f}
                response = requests.post(url, headers=headers, files=files, params=params, timeout=60)
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

    def check_file_processing_status(token, file_id):
        url = f'http://localhost:8080/api/v1/files/{file_id}/process/status'
        headers = {'Authorization': f'Bearer {token}'}
        try:
            response = requests.get(url, headers=headers, timeout=10)
            if response.status_code == 200:
                data = response.json()
                return data.get('status', 'unknown')
            else:
                print(f"Failed to check file status: HTTP {response.status_code}")
                return 'error'
        except Exception as e:
            print(f"Error checking file status: {str(e)}")
            return 'error'

    def smart_wait_for_processing(token, file_id, file_path, timeout=None):
        """Wait for file processing with exponential backoff and appropriate timeout"""
        if timeout is None:
            timeout = get_processing_timeout(file_path)

        start_time = time.time()
        file_name = os.path.basename(file_path)

        # Exponential backoff delays: 1s, 2s, 4s, 8s, 15s, then 30s intervals
        initial_delays = [1, 2, 4, 8, 15]
        steady_delay = 30

        # Initial exponential backoff phase
        for i, delay in enumerate(initial_delays):
            if time.time() - start_time >= timeout:
                print(f"Timeout waiting for {file_name} processing ({timeout}s)")
                return False

            status = check_file_processing_status(token, file_id)
            if status == 'completed':
                return True
            elif status == 'failed':
                print(f"Processing failed for {file_name}")
                return False
            elif status in ['error', 'unknown']:
                print(f"Error checking status for {file_name}")
                return False

            time.sleep(delay)

        # Steady polling phase - check every 30 seconds until timeout
        while time.time() - start_time < timeout:
            status = check_file_processing_status(token, file_id)
            if status == 'completed':
                return True
            elif status == 'failed':
                print(f"Processing failed for {file_name}")
                return False
            elif status in ['error', 'unknown']:
                print(f"Error checking status for {file_name}")
                return False

            time.sleep(steady_delay)

        print(f"Timeout waiting for {file_name} processing ({timeout}s)")
        return False

    def add_file_to_knowledge(token, knowledge_id, file_id, file_path):
        """Add a single file to knowledge collection"""
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
                file_name = os.path.basename(file_path)
                print(f"Failed to add {file_name} to knowledge: HTTP {response.status_code} - {response.text}")
                return False
        except requests.exceptions.RequestException as e:
            file_name = os.path.basename(file_path)
            print(f"Network error adding {file_name} to knowledge: {str(e)}")
            return False
        except Exception as e:
            file_name = os.path.basename(file_path)
            print(f"Error adding {file_name} to knowledge: {str(e)}")
            return False

    def batch_add_to_knowledge(token, knowledge_id, processed_files):
        """Add multiple processed files to knowledge collection"""
        successful_adds = 0

        for file_path, file_id in processed_files:
            file_name = os.path.basename(file_path)
            if add_file_to_knowledge(token, knowledge_id, file_id, file_path):
                print(f"✓ Added {file_name} to knowledge collection")
                successful_adds += 1
            else:
                print(f"✗ Failed to add {file_name} to knowledge collection")

        return successful_adds

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

    def collect_files_to_process():
        """Collect all files to process recursively"""
        files_to_process = []

        for root, dirs, files in os.walk('.'):
            # Skip hidden directories
            dirs[:] = [d for d in dirs if not d.startswith('.')]

            for file_name in files:
                # Skip hidden files
                if file_name.startswith('.'):
                    continue

                file_path = os.path.join(root, file_name)
                files_to_process.append(file_path)

        return files_to_process

    def upload_files_parallel(token, file_paths, max_workers=3):
        """Upload multiple files concurrently"""
        uploaded_files = {}
        completed_count = 0
        total_count = len(file_paths)

        print(f"Uploading {total_count} files with {max_workers} concurrent workers...")

        with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
            # Submit all upload tasks
            future_to_path = {
                executor.submit(upload_file_async, token, file_path): file_path
                for file_path in file_paths
            }

            # Process completed uploads
            for future in concurrent.futures.as_completed(future_to_path):
                file_path = future_to_path[future]
                rel_path = os.path.relpath(file_path, '.')
                completed_count += 1

                try:
                    file_id = future.result()
                    if file_id:
                        uploaded_files[file_path] = file_id
                        print(f"✓ [{completed_count}/{total_count}] Uploaded {rel_path}")
                    else:
                        print(f"✗ [{completed_count}/{total_count}] Failed to upload {rel_path}")
                except Exception as e:
                    print(f"✗ [{completed_count}/{total_count}] Error uploading {rel_path}: {str(e)}")

        return uploaded_files

    def wait_for_processing_parallel(token, uploaded_files, max_workers=5):
        """Wait for all files to finish processing concurrently"""
        processed_files = []
        completed_count = 0
        total_count = len(uploaded_files)

        print(f"Waiting for {total_count} files to finish processing...")

        with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
            # Submit status checking tasks
            future_to_file = {
                executor.submit(smart_wait_for_processing, token, file_id, file_path): (file_path, file_id)
                for file_path, file_id in uploaded_files.items()
            }

            # Process completed status checks
            for future in concurrent.futures.as_completed(future_to_file):
                file_path, file_id = future_to_file[future]
                rel_path = os.path.relpath(file_path, '.')
                completed_count += 1

                try:
                    if future.result():
                        processed_files.append((file_path, file_id))
                        print(f"✓ [{completed_count}/{total_count}] Processed {rel_path}")
                    else:
                        print(f"✗ [{completed_count}/{total_count}] Processing failed for {rel_path}")
                except Exception as e:
                    print(f"✗ [{completed_count}/{total_count}] Error checking status for {rel_path}: {str(e)}")

        return processed_files

    def main(token, knowledge_id):
        print(f"Uploading files to knowledge collection '{knowledge_id}' (ensure it exists in Open-WebUI UI).")

        # Validate collection exists
        if not validate_knowledge_collection(token, knowledge_id):
            print(f"Error: Knowledge collection '{knowledge_id}' does not exist or is not accessible.")
            return

        # Collect all files to process
        files_to_process = collect_files_to_process()
        if not files_to_process:
            print("No files found to process.")
            return

        print(f"Found {len(files_to_process)} files to process")

        # Phase 1: Upload all files concurrently
        uploaded_files = upload_files_parallel(token, files_to_process)

        if not uploaded_files:
            print("No files were successfully uploaded.")
            return

        # Phase 2: Wait for processing to complete concurrently
        processed_files = wait_for_processing_parallel(token, uploaded_files)

        if not processed_files:
            print("No files were successfully processed.")
            return

        # Phase 3: Add all processed files to knowledge collection
        print(f"Adding {len(processed_files)} processed files to knowledge collection...")
        successful_adds = batch_add_to_knowledge(token, knowledge_id, processed_files)

        print(f"\n🎉 Upload complete!")
        print(f"   Total files found: {len(files_to_process)}")
        print(f"   Successfully uploaded: {len(uploaded_files)}")
        print(f"   Successfully processed: {len(processed_files)}")
        print(f"   Successfully added to knowledge: {successful_adds}")

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
