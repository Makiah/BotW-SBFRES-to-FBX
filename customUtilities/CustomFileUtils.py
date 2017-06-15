import os, shutil

# Empty a folder without deleting the folder itself.
def emptyFolder(folderPath):
    for root, dirs, files in os.walk(folderPath):
        for f in files:
            os.unlink(os.path.join(root, f)) # the EXACT same thing as os.remove :P
        for d in dirs:
            shutil.rmtree(os.path.join(root, d))


# File utilities
def getFilenameFromPath(path: str):
    name = os.path.basename(path)
    return name[0:name.index(".")]