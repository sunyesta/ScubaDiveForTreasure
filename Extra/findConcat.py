import os


def concatenate_matching_files(directory_path, search_terms, output_file):
    """
    Concatenates files containing specific text and labels them with their file path.
    """

    # 1. Setup output file
    # 'w' overwrites existing file. Use 'a' to append.
    with open(output_file, "w", encoding="utf-8") as outfile:
        match_count = 0

        # 2. Walk through directory (includes subfolders)
        for root, _, files in os.walk(directory_path):
            for filename in files:
                # Construct the full path
                file_path = os.path.join(root, filename)

                try:
                    # 3. Read the file
                    # errors='replace' ensures it doesn't crash on emoji/binary characters
                    with open(
                        file_path, "r", encoding="utf-8", errors="replace"
                    ) as infile:
                        content = infile.read()

                        # 4. Check for matches
                        # Change all() to any() if you want files with AT LEAST ONE term
                        if all(term in content for term in search_terms):
                            print(f"Adding: {file_path}")

                            # --- HEADER SECTION ---
                            # This writes the path clearly at the top
                            outfile.write(f"\n{'='*50}\n")
                            outfile.write(f"SOURCE PATH: {file_path}\n")
                            outfile.write(f"{'='*50}\n\n")
                            # ----------------------

                            outfile.write(content)
                            outfile.write("\n")  # Ensure separation between files
                            match_count += 1

                except Exception as e:
                    # Useful for skipping system files or permissions errors
                    print(f"Could not read {file_path}: {e}")

    print(f"\nDone. {match_count} files concatenated into '{output_file}'.")


# --- Configuration ---
if __name__ == "__main__":

    # Target Directory (use "." for current folder)
    target_dir = "/Users/mary/Documents/Roblox Game Dev/Islanders/src"

    # Terms to search for (Case sensitive)
    # The file must contain ALL of these to be included
    terms = ["Villager"]

    # Output file name
    result_file = "out.txt"

    concatenate_matching_files(target_dir, terms, result_file)
