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


def process_single_file(file_path, outfile, output_filename, blacklist, separator):
    """
    Handles the logic for reading a single file and writing it to the output.
    Performs checks for binary content, blacklist, and self-overwriting.
    """
    # 1. Skip the output file itself to prevent infinite loops/corruption
    if os.path.abspath(file_path) == os.path.abspath(output_filename):
        return

    # 2. Check blacklist
    if should_skip(os.path.basename(file_path), file_path, blacklist):
        print(f"Skipping blacklisted file: {file_path}")
        return

    # 3. Skip binary files
    if is_binary(file_path):
        print(f"Skipping binary file: {file_path}")
        return

    # 4. Read and Write content
    try:
        with open(file_path, "r", encoding="utf-8", errors="replace") as infile:
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


def concatenate_paths(source_paths, output_filename, blacklist=None):
    """
    Iterates through a list of paths.
    If a path is a file, it processes it directly.
    If a path is a directory, it recursively walks it.
    """
    # Ensure source_paths is a list even if a single string is passed
    if isinstance(source_paths, str):
        source_paths = [source_paths]

    if blacklist is None:
        blacklist = []

    separator = "=" * 80

    try:
        # Open the output file in write mode ('w') once at the start
        # Use 'utf-8' to handle special characters correctly
        with open(output_filename, "w", encoding="utf-8") as outfile:

            for source_path in source_paths:
                if not os.path.exists(source_path):
                    print(
                        f"Warning: The path '{source_path}' does not exist. Skipping."
                    )
                    continue

                # --- CASE 1: It is a FILE ---
                if os.path.isfile(source_path):
                    print(f"\n--- Processing Single File: {source_path} ---")
                    process_single_file(
                        source_path, outfile, output_filename, blacklist, separator
                    )

                # --- CASE 2: It is a DIRECTORY ---
                elif os.path.isdir(source_path):
                    print(f"\n--- Processing Directory: {source_path} ---")

                    # Walk through the directory
                    for root, dirs, files in os.walk(source_path):
                        # Filter subdirectories in-place to prevent recursion into blacklisted dirs
                        for i in range(len(dirs) - 1, -1, -1):
                            dir_name = dirs[i]
                            dir_path = os.path.join(root, dir_name)
                            if should_skip(dir_name, dir_path, blacklist):
                                print(f"Skipping blacklisted directory: {dir_path}")
                                del dirs[i]

                        # Process files in the directory
                        for file in files:
                            file_path = os.path.join(root, file)
                            process_single_file(
                                file_path,
                                outfile,
                                output_filename,
                                blacklist,
                                separator,
                            )

        print(f"\nSuccess! All contents concatenated into: {output_filename}")

    except IOError as e:
        print(f"Error writing to output file: {e}")


if __name__ == "__main__":
    print("--- Multi-Path Concatenator ---")

    # 1. Define your list of files AND/OR directories here
    src_paths = [
        # Example of a directory
        # r"src/MyFolder",
        # Example of specific files
        # r"src/ReplicatedStorage/Components/Models/Treasure.lua",
        # r"src/ServerStorage/Components/Models/Treasure.lua",
        # r"src/ReplicatedStorage/Modules/ComponentUtils/TreasureUtils.lua",
        r"src/ReplicatedStorage/VSCodeStudioPlugins/SmoothieMoveTools",
    ]

    # 2. Define your output file
    out_file = r"./extra/out.txt"

    # 3. Define blacklist patterns (glob style)
    # Common examples: "*.log", ".git", "node_modules", "__pycache__"
    black_list = [".git", "__pycache__", "*.pyc"]

    # Ensure output directory exists before running
    output_dir = os.path.dirname(out_file)
    if output_dir and not os.path.exists(output_dir):
        os.makedirs(output_dir)

    concatenate_paths(src_paths, out_file, blacklist=black_list)
