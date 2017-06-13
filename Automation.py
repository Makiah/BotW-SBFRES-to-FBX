# This is apparently where python keeps all of the utilities for accessing files and folders.
import os
import subprocess
import shutil

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

# Set up variables.
workspacePath = os.path.join(initialWD, "ExtractionWorkspace")
databasePath = os.path.join(initialWD, "ExtractionDatabase")
# Used to move all folders over and all executables.
# Prepare for new session.
emptyFolder(os.path.join(initialWD, "ExtractionWorkspace"))

# Set up the required components for DDS conversion (don't want to compromise the integrity of these Library files)
os.makedirs(os.path.join(workspacePath,"OutDDS_Lossless"))
os.makedirs(os.path.join(workspacePath, "OutDDS"))
os.makedirs(os.path.join(workspacePath, "Convert"))
os.makedirs(os.path.join(workspacePath, "TransparencyFix"))

# I could use call("copy", [...]) but this must be a better option.
texConv2Library = os.path.join(initialWD, "Libraries", "TexConv2")
shutil.copy(os.path.join(texConv2Library, "convertGTX.bat"), workspacePath)
shutil.copy(os.path.join(texConv2Library, "hax.py"), workspacePath)
shutil.copy(os.path.join(texConv2Library, "extract.bat"), workspacePath)
shutil.copy(os.path.join(texConv2Library, "gfd.dll"), workspacePath)
shutil.copy(os.path.join(texConv2Library, "texUtils.dll"), workspacePath)
shutil.copy(os.path.join(texConv2Library, "TexConv2.exe"), workspacePath)

# PNG Conversion libraries
os.makedirs(os.path.join(workspacePath, "ToPNGConvert"))
shutil.copy(os.path.join(initialWD, "Libraries", "Custom", "convertPNG.bat"), workspacePath)

# Create references to these folders.
convertFolder = os.path.join(workspacePath, "Convert")
outDDSLosslessFolder = os.path.join(workspacePath, "OutDDS_Lossless")
transparencyFixFolder = os.path.join(workspacePath, "TransparencyFix")


# File utilities
def getFilenameFromPath(path: str):
    name = os.path.basename(path)
    return name[0:name.index(".")]


# Construct the model texture pair list.
print("Creating list of SBFRES paths to extract...")

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
        print("Created model " + self.itemName + " with model path " + self.modelPath + " and texture path " + self.texturePath)

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


# Shortcut based on a previously created file to the model currently pending extraction.

# Used to get rid of the already extracted models.
sbfresStateFile = os.path.join(databasePath, ".sbfres_state")

# Check whether exporting has already started (using provided file)
def checkSbfresStateFile():
    if os.path.exists(sbfresStateFile):
        openedFile = open(sbfresStateFile, "r")
        pendingModel = openedFile.read()
        openedFile.close()
        if pendingModel != "":
            print("Opened file is " + pendingModel)
            #Can't remove objects from list while iterating so have to iterate over copy.
            for modelTexturePair in mtPairList[:]:
                if modelTexturePair.itemName != pendingModel:
                    mtPairList.remove(modelTexturePair)
                    print("Skipping " + modelTexturePair.itemName)
                else:
                    print("Saw same")
                    openedFile.close()
                    return
        else:
            print("No sbfres state detected, beginning new.  ")
        openedFile.close()

checkSbfresStateFile()



# Used to add files to the database.
def addToDatabase(toAddFilePath: str):
    toAddFilename = os.path.basename(toAddFilePath)
    try:
        shutil.move(toAddFilePath, databasePath)
        print("Added " + toAddFilename + " to the database successfully!")
    except FileExistsError:
        os.remove(toAddFilePath)
        print("Didnt' add " + toAddFilename + " because it already is part of the database.")
    except:
        os.remove(toAddFilePath)
        print("A weird error occurred upon attempting to add " + toAddFilename + " to the database!")

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

# Extract every file from the pair list database.

for currentModelTexturePair in mtPairList:
    # Output to the user what we are currently extracting and update the sbfresState pending model.
    print("Currently extracting " + currentModelTexturePair.itemName)

    # Calling open should create it if it doesn't exist.
    openedStateFile = open(sbfresStateFile, "w")
    openedStateFile.truncate(0) # Erase the file.
    openedStateFile.write(currentModelTexturePair.itemName) # Write the name of the current item.
    openedStateFile.close() # you HAVE to close the file or it won't work.

    # Model extraction
    if currentModelTexturePair.modelPath != "":
        rarcFilePath = addSBFRESToWorkspaceAndExtract(currentModelTexturePair.modelPath)
        #Rename to BFRES
        bfresFilePath = shutil.move(rarcFilePath, os.path.join(os.path.dirname(rarcFilePath), getFilenameFromPath(rarcFilePath) + ".bfres"))
        #Add to database.
        addToDatabase(bfresFilePath)

    # Texture extraction
    if currentModelTexturePair.texturePath != "":
        rarcFilePath = addSBFRESToWorkspaceAndExtract(currentModelTexturePair.texturePath)
        # Rename the file to texturefile.rarc.
        texturefile = shutil.move(rarcFilePath, "texturefile.rarc")

        # Extract GTX files with QuickBMS and script made by RTB.
        call(os.path.join("Libraries", "quickbms", "quickbms.exe"), [os.path.join("Libraries", "WiiU_BFREStoGTX", "BFRES_Textures_NoMips_BotWTex1Only.bms"), texturefile, workspacePath])
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

        # Clean out the Convert and OutDDS folders.
        emptyFolder(os.path.join(workspacePath, "OutDDS"))
        emptyFolder(os.path.join(workspacePath, "Convert"))

        # Apply the transparency fix to these DDS files.
        call(os.path.join("Libraries", "quickbms", "quickbms.exe"), [os.path.join("Libraries", "BFLIMDDS", "BFLIMDDSFix.bms"), os.path.join(outDDSLosslessFolder, "*.dds"), transparencyFixFolder])

        # Convert all created DDS files to PNG.
        pngConvertFolder = os.path.join(workspacePath, "ToPNGConvert")
        for fixedFile in os.listdir(transparencyFixFolder):
            shutil.move(os.path.join(transparencyFixFolder, fixedFile), pngConvertFolder)

        # Call the PNG conversion BAT file (for some reason the arguments aren't working as expected :P)
        os.chdir(workspacePath)
        call("convertPNG.bat", [])
        os.chdir(initialWD)

        # Move all PNG files over to the database.
        for pngFile in os.listdir(pngConvertFolder):
            if pngFile.endswith(".png"):
                addToDatabase(os.path.join(pngConvertFolder, pngFile))

        # Empty each folder.
        emptyFolder(transparencyFixFolder)
        emptyFolder(outDDSLosslessFolder)
        emptyFolder(pngConvertFolder)


print("Added all files to the database successfully :)")
