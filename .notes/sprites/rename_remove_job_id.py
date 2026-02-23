import os
import re
import argparse

def rename_files(directory, dry_run=True):
    """
    Renames files in the specified directory to remove trailing underscores and numbers.
    Example: 'bard_attack_00001.png' -> 'bard_attack.png'
    """
    # Regex pattern: 
    # _          : matches an underscore
    # \d+        : matches one or more digits
    # (?=\.[^.]+$|$) : lookahead to ensure this is at the end of the name (before extension)
    pattern = re.compile(r'_\d+(?=\.[^.]+$|$)')

    if not os.path.isdir(directory):
        print(f"Error: The directory '{directory}' does not exist.")
        return

    files = [f for f in os.listdir(directory) if os.path.isfile(os.path.join(directory, f))]
    
    if not files:
        print("No files found in the directory.")
        return

    print(f"{'--- DRY RUN MODE ---' if dry_run else '--- PERFORMING RENAME ---'}")
    
    rename_count = 0
    
    for filename in files:
        # Check if the pattern exists in the filename
        if pattern.search(filename):
            new_name = pattern.sub('', filename)
            
            # Handle potential collisions (if bard_attack.png already exists)
            if new_name == filename:
                continue
                
            old_path = os.path.join(directory, filename)
            new_path = os.path.join(directory, new_name)

            if os.path.exists(new_path):
                print(f"[SKIP] Cannot rename '{filename}' -> '{new_name}' (Target already exists)")
                continue

            print(f"[RENAME] '{filename}' -> '{new_name}'")
            
            if not dry_run:
                try:
                    os.rename(old_path, new_path)
                except Exception as e:
                    print(f"      Error renaming {filename}: {e}")
            
            rename_count += 1

    if rename_count == 0:
        print("No files matched the renaming pattern.")
    else:
        print(f"\nTotal files processed: {rename_count}")
        if dry_run:
            print("Run with '--execute' to apply changes.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Remove trailing numbers (e.g., _00001) from filenames.")
    parser.add_argument("path", nargs="?", default=".", help="Directory path (default: current directory)")
    parser.add_argument("--execute", action="store_true", help="Actually rename the files (default is dry-run)")
    
    args = parser.parse_args()
    
    rename_files("./assets/player/", dry_run=not args.execute)
    # rename_files("./assets/npcs/", dry_run=not args.execute)
    # rename_files("./assets/enemies/", dry_run=not args.execute)