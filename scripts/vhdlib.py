#!/usr/bin/python3
#-----------------------------------------------------------------------------
# This file is part of 'SLAC Firmware Standard Library'.
# It is subject to the license terms in the LICENSE.txt file found in the
# top-level directory of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of 'SLAC Firmware Standard Library', including this file,
# may be copied, modified, propagated, or distributed except according to
# the terms contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import os
import argparse
import re

def find_vhd_files(*paths):
    vhd_files = []
    for path in paths:
        for root, dirs, files in os.walk(path):
            for file in files:
                if file.endswith(".vhd") or file.endswith(".vhdl"):
                    vhd_files.append(os.path.join(root, file))
    return vhd_files


def parse_library(vhd_files, libname):
    d = {}
    d['package'] = {}
    d['entity'] = {}
    d['name'] = libname

    regex = re.compile('^(package|entity)\s+((?:[a-z][a-z0-9_]*))\s+is', re.IGNORECASE| re.MULTILINE)

    for file in vhd_files:
        try:
            file_string = open(file).read()
            result = regex.findall(file_string)
            if len(result) > 0:
                typ = result[0][0]
                name = result[0][1]
                #print(f'Found {typ} {name} in file {file}')
                d[typ.lower()][name.lower()] = file
            else:
                pass
                #print(f'Nothing found in file {file}')
        except (Exception) as e:
            print(f'Error reading {file} - {e}')

    return d


def refactor_file(vhd_file, library):
    done_library = False
    do_library = False
    changed = False
    libname = library['name']
    packages = library['package']
    entities = library['entity']

    # Regex to find both package `use` statements and entity instantiations
    regex = re.compile('(use|entity)\s+work\.((?:[a-z][a-z0-9]*))', re.IGNORECASE|re.MULTILINE)
    newlines = []

    try:
        with open(vhd_file) as f:
            for line in f:
                newline = line
                match = regex.findall(line)
                if len(match) > 0:
                    typ = match[0][0].lower()
                    name = match[0][1].lower()
                    if typ == 'use':
                        if name in packages:
                            if not done_library:
                                newlines.append(f'\nlibrary {libname};\n')
                                done_library = True
                            newline = line.replace('work', libname)
                            changed = True

                    elif typ == 'entity':
                        if name in entities:
                            changed = True
                            newline = line.replace('work', libname)
                            if not done_library:
                                do_library = True;

                newlines.append(newline)

        # Sometimes we need to go back and add a library declaration
        # find the last `use` statement and add it after that
        insert_index = 0
        if do_library is True:
            for linenum, line in enumerate(newlines):
                if line.lower().strip().startswith('use '):
                    insert_index = linenum

            newlines.insert(insert_index+1, f'\nlibrary {libname}; \n')
            print(f'Added library declaration to {vhd_file}')

        if changed:
            with open(vhd_file, 'w') as out:
                print(f'Refactoring: {vhd_file}')
                for line in newlines:
                    out.write(line)

    except (Exception) as e:
        print(f'Filed to open file {vhd_file}: {e}')


parser = argparse.ArgumentParser()

parser.add_argument(
    "--libname",
    type     = str,
    required = True,
)


parser.add_argument(
    "--libpath",
    required = True,
    nargs = '+'
)


parser.add_argument(
    "--refactor",
    nargs = '+',
)


if __name__ == '__main__':
    args = parser.parse_args()

    libfiles = find_vhd_files(*args.libpath)

    lib = parse_library(libfiles, args.libname)

    num_packages = len(lib['package'])
    num_entities= len(lib['entity'])

    print(f'Found {num_packages} packages and {num_entities} entities for library {args.libname}')
    input()

    refactor_files = find_vhd_files(*args.refactor)

    print(f'Applying library refactor to {len(refactor_files)} files')

    for filename in refactor_files:
        refactor_file(filename, lib)

    print('Done')
