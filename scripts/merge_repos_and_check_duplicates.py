#!/usr/bin/python3

import collections
import os
import shutil
import sys
from re import search


if len(sys.argv) < 4:
    print(
        "usage: merge_repos_and_check_duplicates.py "
        "[geocint-runner] [geocint-openstreetmap] [your private repo]"
    )
    sys.exit(1)

runner = sys.argv[1]
openstreetmap = sys.argv[2]
private = sys.argv[3]


def get_files_list(directory, ignore_list):
    dir_list = os.walk(directory)
    dir_list = [x for x in dir_list if not search(r"/\.", x[0])]

    file_list = []
    for folder, _, filenames in dir_list:
        for name in filenames:
            file_list.append((str(folder) + "/" + str(name)).replace("//", "/"))

    for item in ignore_list:
        file_list = [x for x in file_list if x.split("/")[1] != item]

    return file_list


def get_config_variable(config_name, variable, delimiter):
    ignored_files = []
    with open(config_name, "r", encoding="utf-8") as config:
        for line in config:
            if search(variable, line):
                ignored_files = (
                    line.split("=")[1]
                    .strip("\n")
                    .strip('"')
                    .strip("'")
                    .split(delimiter)
                )

    return ignored_files


def find_duplicates(files):
    removed_repo = ["/".join(x.split("/")[1:]) for x in files]

    duplicated_patterns = [
        x for x, count in collections.Counter(removed_repo).items() if count > 1
    ]

    duplicates = []
    for pattern in duplicated_patterns:
        for filename in files:
            if "/".join(filename.split("/")[1:]) == pattern:
                duplicates.append(filename)

    return duplicates


def copy_folder_structure(directory, general_folder):
    dir_list = os.walk(directory)
    dir_list = [x[0] for x in dir_list if not search(r"/\.", x[0])]

    folder_list = [
        general_folder + "/" + "/".join(x.split("/")[1:])
        for x in dir_list
    ]

    for path in folder_list:
        os.makedirs(path, exist_ok=True)


def main():
    ignore_list = get_config_variable(
        str(os.getenv("GEOCINT_WORK_DIRECTORY")) + "/config.inc.sh",
        "ALLOW_DUPLICATE_FILES",
        ",",
    )
    general_folder = "geocint"

    files = []
    files += get_files_list(runner, ignore_list)
    files += get_files_list(openstreetmap, ignore_list)
    files += get_files_list(private, ignore_list)

    duplicated_files = find_duplicates(files)

    if len(duplicated_files) > 0:
        sys.stdout.write(
            "Skip start: duplicate files were found while copying files to a "
            f"{general_folder} folder: " + ",\n".join(duplicated_files) + "\n"
        )
    else:
        copy_folder_structure(runner, general_folder)
        copy_folder_structure(openstreetmap, general_folder)
        copy_folder_structure(private, general_folder)
        for file_name in files:
            shutil.copyfile(
                file_name,
                general_folder + "/" + "/".join(file_name.split("/")[1:]),
            )
        sys.stdout.write(
            f"Copy from {runner}, {openstreetmap} and {private} to {general_folder} "
            "folder completed successfully\n"
        )


if __name__ == "__main__":
    main()
