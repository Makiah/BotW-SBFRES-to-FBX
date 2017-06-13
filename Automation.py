# This is apparently where python keeps all of the utilities for accessing files and folders.
import os
import subprocess
import shutil
import traceback

# Will vary based on other people's set /ps.
sbfresCompilation = "Z:\Desktop\BOTW\SBFRES Compilation"

# Get the initial working directory of this script.
initialWD = os.getcwd()


# Used to empty folders (but not the folder itself)
def emptyFolder(folderPath):
    for root, dirs, files in os.walk(folderPath):
        for f in files:
            os.unlink(os.path.join(root, f)) # the EXACT same thing as os.remove :P
        for d in dirs:
            shutil.rmtree(os.path.join(root, d))

# Register and empty workspace.
workspacePath = os.path.join(initialWD, "ExtractionWorkspace")
emptyFolder(os.path.join(initialWD, "ExtractionWorkspace"))

# Set up database reference.
databasePath = os.path.join(initialWD, "ExtractionDatabase")


# GTX to DDS conversion libraries.
os.makedirs(os.path.join(workspacePath,"OutDDS_Lossless"))
os.makedirs(os.path.join(workspacePath, "OutDDS"))
os.makedirs(os.path.join(workspacePath, "Convert"))
convertFolder = os.path.join(workspacePath, "Convert")
outDDSLosslessFolder = os.path.join(workspacePath, "OutDDS_Lossless")
transparencyFixFolder = os.path.join(workspacePath, "TransparencyFix")
os.makedirs(os.path.join(workspacePath, "TransparencyFix"))
texConv2Library = os.path.join(initialWD, "Libraries", "TexConv2")
shutil.copy(os.path.join(texConv2Library, "convertGTX.bat"), workspacePath)
shutil.copy(os.path.join(texConv2Library, "hax.py"), workspacePath)
shutil.copy(os.path.join(texConv2Library, "extract.bat"), workspacePath)
shutil.copy(os.path.join(texConv2Library, "gfd.dll"), workspacePath)
shutil.copy(os.path.join(texConv2Library, "texUtils.dll"), workspacePath)
shutil.copy(os.path.join(texConv2Library, "TexConv2.exe"), workspacePath)

# DDS to PNG Conversion libraries
os.makedirs(os.path.join(workspacePath, "ToPNGConvert"))
pngConvertFolder = os.path.join(workspacePath, "ToPNGConvert")
shutil.copy(os.path.join(initialWD, "Libraries", "Custom", "convertPNG.bat"), workspacePath)



# File utilities
def getFilenameFromPath(path: str):
    name = os.path.basename(path)
    return name[0:name.index(".")]


# Construct the model texture pair list.
print("Creating reference list of SBFRES paths to extract...")

# Returns a boolean of whether this file should be added to the filename list.
invalidFileEndings = [".Tex2.sbfres", "_Animation.sbfres", "_L.sbfres", "_L.Tex1.sbfres", "_L.Tex2.sbfres"]
def isExtraneousSBFRES(sbfresInQuestion: str):
    for invalidEnd in invalidFileEndings:
        if sbfresInQuestion.endswith(invalidEnd):
            return True
    return False

# This class encapsulates two properties: the model and texture pair for a given item.
class ModelTextureSBFRESPair:
    def __init__(self, itemName: str):
        self.itemName = itemName

        #Intelligently define model and texture path.
        self.modelPath = os.path.join(sbfresCompilation, itemName + ".sbfres")
        if not os.path.exists(self.modelPath):
            self.modelPath = ""

        self.texturePath = os.path.join(sbfresCompilation, itemName + ".Tex1.sbfres")
        if not os.path.exists(self.texturePath):
            self.texturePath = ""

        # Output that this was created.
        print("New model reference: " + self.itemName + " with model path " + self.modelPath + " and texture path " + self.texturePath)

# This list contains the entire database of SBFRES pairs.
mtPairList = list()

# For every distinct sbfres, make a new model set.
lastFilename = ""
for sbfresFile in sorted(os.listdir(sbfresCompilation)):
    # Make sure that this isn't .DS_Store or something.
    if sbfresFile.endswith(".sbfres") and not isExtraneousSBFRES(sbfresFile):
        # If this file has a distinct filename from the last filename.
        currentFilename = sbfresFile[0:sbfresFile.index(".")]
        if lastFilename != currentFilename:
            mtPairList.append(ModelTextureSBFRESPair(getFilenameFromPath(sbfresFile)))
            lastFilename = currentFilename




# Used for command line arguments.
def quoted(string: str):
    quote = "\""
    return quote + string + quote

# Utility method to call something via command prompt.
def call(item: str, args: list):
    argsString = ""
    for arg in args:
        argsString += " " + quoted(arg)

    # DO NOT REMOVE stdout.read() BELOW
    subprocess.Popen(item + argsString, shell=True, stdout=subprocess.PIPE).stdout.read()



# Extracting given files.
def extractSBFREStoRARC(sbfresPath: str):
    # Extract SBFRES with yaz0dec.
    call(quoted(os.path.join(initialWD, "Libraries", "szstools", "yaz0dec.exe")), [sbfresPath])

    # Delete original SBFRES.
    os.remove(sbfresPath)

    # Return the path of the resulting RARC.
    sbfresFolderPath = os.path.dirname(sbfresPath)
    for potentialRARC in os.listdir(sbfresFolderPath):
        if potentialRARC.endswith(".rarc"):
            return os.path.join(sbfresFolderPath, potentialRARC)

    print("yaz0dec.exe failed to extract a RARC for sbfres " + sbfresPath + " :(")
    return ""

# Adding the extracted SBFRES to the workspace.
def addSBFRESToWorkspaceAndExtract(sbfresPath: str):
    # Copy file into temporary workspace.
    sbfresFilePath = shutil.copy(sbfresPath, workspacePath)
    # SBFRES to BFRES to database.
    return extractSBFREStoRARC(sbfresFilePath)


# Check whether the database is empty and ask whether it should be emptied.
if len(os.listdir(databasePath)) > 0:
    if input("Files exist in the database currently, remove them? (y/n): ")[0] == "y":
        emptyFolder(databasePath)


# Extract every file from the pair list database: the grunt work
for currentModelTexturePair in mtPairList:
    # Output to the user what we are currently extracting and update the sbfresState pending model.
    print("Currently extracting " + currentModelTexturePair.itemName)

    # Create the boolean which will keep track of something going wrong during this process.
    somethingWentWrong = False

    # Verify that this item has not already been extracted.
    completedDatabaseSubdirectory = os.path.join(databasePath, currentModelTexturePair.itemName)
    if os.path.exists(completedDatabaseSubdirectory):
        print("Looks like " + currentModelTexturePair.itemName + " has already been exported successfully, skipping.")
        continue

    # Create the pending directory.
    pendingDatabaseSubdirectory = completedDatabaseSubdirectory + " (Pending)"
    print("Creating subdirectory " + pendingDatabaseSubdirectory + " for " + currentModelTexturePair.itemName)
    if os.path.exists(pendingDatabaseSubdirectory):
        print("Deleted previous pending subdirectory.")
        shutil.rmtree(pendingDatabaseSubdirectory)
    os.makedirs(pendingDatabaseSubdirectory)

    # Remove the something went wrong directory if it exists.
    somethingWentWrongSubdirectory = completedDatabaseSubdirectory + " (Error)"
    if os.path.exists(somethingWentWrongSubdirectory):
        shutil.rmtree(somethingWentWrongSubdirectory)
        print("Removed Error directory for " + currentModelTexturePair.itemName)

    # One massive try statement in case things go wrong.
    try:

        # Model extraction
        if currentModelTexturePair.modelPath != "":
            # Extract the SBFRES file.
            rarcFilePath = addSBFRESToWorkspaceAndExtract(currentModelTexturePair.modelPath)

            #Rename to BFRES
            bfresFilePath = shutil.move(rarcFilePath, os.path.join(os.path.dirname(rarcFilePath), getFilenameFromPath(rarcFilePath) + ".bfres"))
            #Add to database.
            shutil.move(bfresFilePath, pendingDatabaseSubdirectory)
            print("Added model of " + currentModelTexturePair.itemName + " to database successfully!")

        # Texture extraction
        if currentModelTexturePair.texturePath != "":
            # Extract the file.
            rarcFilePath = addSBFRESToWorkspaceAndExtract(currentModelTexturePair.texturePath)

            # Rename the file to texturefile.rarc.
            texturefile = shutil.move(rarcFilePath, "texturefile.rarc")

            # Extract GTX files with QuickBMS and script made by RTB.
            call(os.path.join(initialWD, "Libraries", "quickbms", "quickbms.exe"), [os.path.join(initialWD, "Libraries", "WiiU_BFREStoGTX", "BFRES_Textures_NoMips_BotWTex1Only.bms"), texturefile, workspacePath])
            extractDirectory = os.path.join(workspacePath, "texturefile")

            # Remove the texture file.
            os.remove(texturefile)

            # Verify that the QuickBMS script created a new folder with the textures.
            if not os.path.exists(extractDirectory):
                print("No textures were extracted from " + currentModelTexturePair.itemName + "!")
                continue

            # Move the GTX files to the Convert directory and delete the texture folder.
            for file in os.listdir(extractDirectory):
                shutil.move(os.path.join(extractDirectory, file), convertFolder)
            shutil.rmtree(extractDirectory) # created by the extract script.

            # Convert these GTX files to DDS files.
            os.chdir(workspacePath)
            call(os.path.join(workspacePath, "convertGTX.bat"), [])
            os.chdir(initialWD)

            # Apply the transparency fix to these DDS files.
            call(os.path.join(initialWD, "Libraries", "quickbms", "quickbms.exe"), [os.path.join(initialWD, "Libraries", "BFLIMDDS", "BFLIMDDSFix.bms"), os.path.join(outDDSLosslessFolder, "*.dds"), transparencyFixFolder])

            # Convert all created DDS files to PNG.
            for fixedFile in os.listdir(transparencyFixFolder):
                shutil.move(os.path.join(transparencyFixFolder, fixedFile), pngConvertFolder)

            # Call the PNG conversion BAT file (for some reason the arguments aren't working as expected :P)
            os.chdir(workspacePath)
            call("convertPNG.bat", [])
            os.chdir(initialWD)

            # Move all PNG files over to the database.
            for pngFile in os.listdir(pngConvertFolder):
                if pngFile.endswith(".png"):
                    shutil.move(os.path.join(pngConvertFolder, pngFile), pendingDatabaseSubdirectory)
                    print("Moved " + pngFile + " to subdirectory in database successfully!")

    except Exception as err:
        print("Something went wrong during extraction of " + currentModelTexturePair.itemName + "!")
        traceback.print_exc()
        somethingWentWrong = True

    # Rename the pending database to the completed database so that the script knows what to skip.
    if not somethingWentWrong:
        os.rename(pendingDatabaseSubdirectory, completedDatabaseSubdirectory)
    else:
        os.rename(pendingDatabaseSubdirectory, completedDatabaseSubdirectory + " (Error!)")

    # Clean out the folders for the next run.
    emptyFolder(os.path.join(workspacePath, "OutDDS"))
    emptyFolder(os.path.join(workspacePath, "Convert"))
    emptyFolder(transparencyFixFolder)
    emptyFolder(outDDSLosslessFolder)
    emptyFolder(pngConvertFolder)


print("Added all files to the database successfully :)")
