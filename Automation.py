# This is apparently where python keeps all of the utilities for accessing files and folders.
import os
import subprocess

# Will vary based on other people's set /ps.
contentFolder = "Z:\Desktop\BOTW\Raw Assets"

# Get the initial working directory of this script.
initialWD = os.getcwd()

# Set up variables.
workspacePath = initialWD + "\ExtractionWorkspace\\"

# List all files with extension sbfres.
print("Creating list of SBFRES paths to extract...")

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

print("Created successfully!  " + str(len(fileList)) + " files will be extracted.")

# Since get basename returns the file with the extension and we need to see the difference between .Tex1.sbfres and .sbfres.
def getFilenameFromPath(path: str):
    name = os.path.basename(path)
    return name[0:name.index(".")]

# Used for command line arguments.
def quoted(string: str):
    quote = "\""
    return quote + string + quote

# Utility method to call via command prompt.
def call(item: str, args: list):
    argsString = ""
    for arg in args:
        argsString += " " + quoted(arg)
    print("Calling " + item + argsString)
    # DO NOT REMOVE stdout.read() BELOW
    subprocess.Popen(item + argsString, shell=True, stdout=subprocess.PIPE).stdout.read()

# For every file.
for filePath in fileList:
    # Copy file into temporary workspace.
    call("copy", [filePath, workspacePath])

    # Get filename.
    sbfresFilename = getFilenameFromPath(filePath)

    # Extract SBFRES with yaz0dec.
    sbfresFilePath = workspacePath + sbfresFilename + ".sbfres"
    call(quoted(initialWD + "\Libraries\szstools\yaz0dec.exe"), [sbfresFilePath])

    # Delete original SBFRES.
    call("del", [sbfresFilePath])

    # Get the new RARC file (only file in this directory).
    rarcFile = os.listdir(workspacePath)[0]

    # Figure out whether we're dealing with here: a texture or a model file.
    if filePath.endswith(".Tex1.sbfres"): # Texture file.
        call("rename", [workspacePath + rarcFile, "texturefile.rarc"])

        # Extract GTX files with QuickBMS and script made by RTB.
        call(initialWD + "\Libraries\quickbms\quickbms.exe", [initialWD + "\Libraries\WiiU_BFREStoGTX\BFRES_Textures_NoMips_BotWTex1Only.bms", workspacePath + rarcFile])

        # Make sure that textures were extracted.  If not, then move on to the next file.
        if not os.path.exists(workspacePath + "texturefile"): continue

        #Convert these GTX files to DDS.

    else:
        # Rename rarc file.
        call("rename", [workspacePath + rarcFile, getFilenameFromPath(rarcFile) + ".bfres"])

        # Output that this was extracted successfully and copy it into the database.
        call("copy", [workspacePath + getFilenameFromPath(rarcFile) + ".bfres", initialWD + "\\3DSMaxBFRESDatabase"])
