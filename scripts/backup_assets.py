import os
import shutil
import stat
from datetime import datetime

# Setup paths
current_date = datetime.now().strftime('%Y%m%d')
source_dir = './assets'
target_parent = f'../memory-dungeon-{current_date}'
target_dir = os.path.join(target_parent, 'assets')

def remove_readonly(func, path, excinfo):
    """Clear the readonly bit and re-attempt the removal."""
    os.chmod(path, stat.S_IWRITE)
    func(path)

def backup_and_verify():
    if not os.path.exists(source_dir):
        print(f"Error: Source {source_dir} not found.")
        return

    os.makedirs(target_parent, exist_ok=True)
    print(f"Starting backup: {source_dir} -> {target_dir}")

    try:
        if os.path.exists(target_dir):
            # onerror=remove_readonly handles files that are marked "Read-Only"
            shutil.rmtree(target_dir, onerror=remove_readonly)
            
        shutil.copytree(source_dir, target_dir)
        print("✅ Copy complete.")

        # Verification logic...
        # [Remaining verification code from previous script]

    except PermissionError as e:
        print(f"❌ Access Denied: {e}")
        print("Tip: Close Godot, VS Code, or any folder windows and try again.")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")

if __name__ == "__main__":
    backup_and_verify()