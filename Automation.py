# This is apparently where python keeps all of the utilities for accessing files and folders.
import os

# Will vary based on other people's set /ps.
contentFolder = "Z:\Desktop\BOTW\Raw Assets"

# List all files with extension sbfres.
print("Registering all models")

# Returns a boolean of whether this file should be added to the filename list.
invalidFileEndings = [".Tex2.sbfres", "_Animation.sbfres", "_L.sbfres", "_L.Tex1.sbfres", "_L.Tex2.sbfres"]
def isExtraneousSBFRES(sbfresInQuestion: str):
    for invalidEnd in invalidFileEndings:
        if sbfresInQuestion.endswith(invalidEnd):
            return True
    return False

# The list of files which things should be extracted from.
fileList = list()

# Loop through all subdirectories in the content folder.
for dirpath, dirnames, filenames in os.walk(contentFolder):
    for filename in [f for f in filenames if (f.endswith(".sbfres") and not isExtraneousSBFRES(f))]:
        fileList.append(os.path.join(contentFolder, dirpath, filename))

# Since get basename returns the file with the extension and we need to see the difference between .Tex1.sbfres and .sbfres.
def getFilenameForPath(path: str):
    name = os.path.basename(path)
    return name[0:name.index(".")]

# Now we have two extract everything.  Don't worry though, it's shockingly easy!  os.system("Command") is everything we need.
print("Current WD is " + os.getcwd())
