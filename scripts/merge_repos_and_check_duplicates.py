#!/usr/bin/python3

import os
import shutil
import sys
import collections

from re import search

if len(sys.argv) < 2:
    print(
        'usage: merge_repos_and_check_duplicates.py [geocint-runner] [geocint-openstreetmap] [your private repo]'
    )

runner = sys.argv[1]
openstreetmap = sys.argv[2]
private = sys.argv[3]
       
def get_files_list(directory, ignore_list):
    dir_list = os.walk(directory)
    dir_list = [x for x in dir_list if not search('/\.', x[0])]
    
    # initialize empty list to store files names
    file_list = []
    for i in dir_list:
        for n in i[2]:
            file_list.append((str(i[0])+'/'+str(n)).replace('//', '/')) 
            
    # recursively remove ignored files         
    for i in ignore_list:
        file_list = [x for x in file_list if not x.split('/')[1] == i]   
        
    return file_list

def get_config_variable(config_name, variable, delimiter):
    config = open(config_name, 'r')
    
    # initialize empty list to store ignored files
    ignored_files = []
    
    for i in config:
        if search(variable, i):
            # transform row with ignored files into list of variables
            ignored_files = (i.split('='))[1].strip('\n').strip('"').strip("'").split(delimiter)
    
    return ignored_files

def find_duplicates(files):
    removed_repo = ['/'.join(x.split('/')[1:]) for x in files]
    
    # return filename patterns that occur more than once 
    duplicated_patterns = [x for x, count in collections.Counter(removed_repo).items() if count > 1]
    
    duplicates = []
    for n in duplicated_patterns:
        for x in files:
            if '/'.join(x.split('/')[1:]) == n:
                duplicates.append(x)
    
    return duplicates
    
def copy_folder_structure(directory, general_folder):
    dir_list = os.walk(directory)
    dir_list = [x[0] for x in dir_list if not search('/\.', x[0])]
    
    folder_list = [general_folder+'/'+'/'.join(x.split('/')[1:]) for x in dir_list]
    
    for path in folder_list:
        os.makedirs(path, exist_ok=True)
    
def main():
    ignore_list = get_config_variable(str(os.getenv('GEOCINT_WORK_DIRECTORY'))+'/config.inc.sh','ALLOW_DUPLICATE_FILES',',')
    general_folder = 'geocint'
    
    # create list with non-ignored files from all repositories  
    files = []    
    files += get_files_list(runner, ignore_list)
    files += get_files_list(openstreetmap, ignore_list)
    files += get_files_list(private, ignore_list)
    
    duplicated_files = find_duplicates(files)    
    
    # check if duplicates exist
    if len(duplicated_files) > 0:
        sys.stdout.write(f'Skip start: duplicate files were found while copying files to a {general_folder} folder: '+ ',\n'.join(duplicated_files) + '\n')
    else:
        # copy folder structure
        copy_folder_structure(runner, general_folder)
        copy_folder_structure(openstreetmap, general_folder)
        copy_folder_structure(private, general_folder)
        # copy files
        for x in files:
            shutil.copyfile(x, general_folder+'/'+'/'.join(x.split('/')[1:]))
        sys.stdout.write(f'Copy from {runner}, {openstreetmap} and {private} to {general_folder} folder completed successfully\n')    
 
if __name__ == '__main__':
    main() 
