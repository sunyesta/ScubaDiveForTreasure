import os
import fnmatch


def is_binary(file_path):
    """
    Simple heuristic to check if a file is binary.
    """
    try:
        with open(file_path, "rb") as f:
            chunk = f.read(1024)
            if b"\0" in chunk:
                return True
    except Exception:
        return True
    return False


def should_skip(name, path, blacklist):
    """
    Helper to check if a name or path matches any pattern in the blacklist.
    """
    if not blacklist:
        return False

    for pattern in blacklist:
        # Check against the filename/dirname AND the full path
        if fnmatch.fnmatch(name, pattern) or fnmatch.fnmatch(path, pattern):
            return True
    return False


def concatenate_directories(source_dirs, output_filename, blacklist=None):
    """
    Recursively reads all files from a list of directories and appends them to output_filename.
    Skips files or directories matching patterns in the blacklist.
    """
    # Ensure source_dirs is a list even if a single string is passed
    if isinstance(source_dirs, str):
        source_dirs = [source_dirs]

    if blacklist is None:
        blacklist = []

    separator = "=" * 80

    try:
        # Open the output file in write mode ('w') once at the start
        with open(output_filename, "w", encoding="utf-8") as outfile:

            for source_dir in source_dirs:
                if not os.path.exists(source_dir):
                    print(
                        f"Warning: The directory '{source_dir}' does not exist. Skipping."
                    )
                    continue

                print(f"\n--- Processing Directory: {source_dir} ---")

                # Walk through the current directory
                for root, dirs, files in os.walk(source_dir):

                    # 1. Filter subdirectories in-place to prevent recursion into blacklisted dirs
                    # We iterate backwards to safely remove items from the list we are iterating
                    for i in range(len(dirs) - 1, -1, -1):
                        dir_name = dirs[i]
                        dir_path = os.path.join(root, dir_name)

                        if should_skip(dir_name, dir_path, blacklist):
                            print(f"Skipping blacklisted directory: {dir_path}")
                            del dirs[i]

                    # 2. Process files
                    for file in files:
                        file_path = os.path.join(root, file)

                        # Skip the output file itself
                        if os.path.abspath(file_path) == os.path.abspath(
                            output_filename
                        ):
                            continue

                        # Check blacklist for files
                        if should_skip(file, file_path, blacklist):
                            print(f"Skipping blacklisted file: {file_path}")
                            continue

                        # Skip binary files
                        if is_binary(file_path):
                            print(f"Skipping binary file: {file_path}")
                            continue

                        try:
                            with open(
                                file_path, "r", encoding="utf-8", errors="replace"
                            ) as infile:
                                content = infile.read()

                                # Write Header
                                outfile.write(f"\n{separator}\n")
                                outfile.write(f"FILE PATH: {file_path}\n")
                                outfile.write(f"{separator}\n\n")

                                # Write Content
                                outfile.write(content)
                                outfile.write("\n")

                                print(f"Processed: {file_path}")

                        except Exception as e:
                            print(f"Could not read {file_path}: {e}")

        print(
            f"\nSuccess! All files from {len(source_dirs)} directories concatenated into: {output_filename}"
        )

    except IOError as e:
        print(f"Error writing to output file: {e}")


if __name__ == "__main__":
    print("--- Multi-Directory Concatenator ---")

    # 1. Define your list of directories here
    src_directories = [r"NonWallyPackages/Cinemachine"]

    # 2. Define your output file
    out_file = r"./extra/out.txt"

    # 3. Define blacklist patterns (glob style)
    # Common examples: "*.log", ".git", "node_modules", "__pycache__"
    black_list = []

    concatenate_directories(src_directories, out_file, blacklist=black_list)
