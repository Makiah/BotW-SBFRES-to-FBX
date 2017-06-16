# This is apparently where python keeps all of the utilities for accessing files and folders.
import os
import subprocess
import shutil
import traceback
# Import from a different folder.
from customUtilities import CustomFileUtils, CommandLineUtils

def extractModelAndTextureData():
    # Get the initial working directory of this script.
    initialWD = os.getcwd()

    # Will vary based on other people's set ups.
    sbfresCompilation = os.path.join(initialWD, "..", "sbfresgrouper", "Compilation")

    # Set up database reference.
    databasePath = os.path.join(initialWD, "Database")
    if not os.path.exists(databasePath):
        # Create the folder if it didn't already exist.
        os.makedirs(databasePath)
    else:
        # Ask if we should start from scratch.
        CustomFileUtils.offerToDeleteAllInSensitiveDirectory(databasePath)


    # Register and set up workspace.
    workspacePath = os.path.join(initialWD, "Workspace")
    if not os.path.exists(workspacePath):
        os.makedirs(workspacePath)
    else:
        CustomFileUtils.emptyFolder(workspacePath)

    # Set up workspace.
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
    quickBMSExecutablePath = os.path.join("Libraries", "quickbms", "quickbms.exe")

    # DDS to PNG Conversion libraries
    os.makedirs(os.path.join(workspacePath, "ToPNGConvert"))
    pngConvertFolder = os.path.join(workspacePath, "ToPNGConvert")
    shutil.copy(os.path.join(initialWD, "Libraries", "Custom", "convertPNG.bat"), workspacePath)


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
                mtPairList.append(ModelTextureSBFRESPair(CustomFileUtils.getFilenameFromPath(sbfresFile)))
                lastFilename = currentFilename



    # Extracting given files.
    def extractSBFREStoRARC(sbfresPath: str):
        # Extract SBFRES with yaz0dec.
        CommandLineUtils.call(CommandLineUtils.quoted(os.path.join(initialWD, "Libraries", "szstools", "yaz0dec.exe")), [sbfresPath])

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
                print("Extracting model")
                # Extract the SBFRES file.
                rarcFilePath = addSBFRESToWorkspaceAndExtract(currentModelTexturePair.modelPath)

                #Rename to BFRES
                bfresFilePath = shutil.move(rarcFilePath, os.path.join(os.path.dirname(rarcFilePath), CustomFileUtils.getFilenameFromPath(rarcFilePath) + ".bfres"))

                #Add to database.
                shutil.move(bfresFilePath, pendingDatabaseSubdirectory)
                print("Added model of " + currentModelTexturePair.itemName + " to database successfully!")

            # Texture extraction
            if currentModelTexturePair.texturePath != "":
                print("Extracting texture")
                # Extract the file.
                rarcFilePath = addSBFRESToWorkspaceAndExtract(currentModelTexturePair.texturePath)

                # Rename the file to texturefile.rarc.
                texturefile = shutil.move(rarcFilePath, os.path.join(os.path.dirname(rarcFilePath), "texturefile.rarc"))

                # Extract GTX files with QuickBMS and script made by RTB.
                CommandLineUtils.call(quickBMSExecutablePath, ["-K", os.path.join(initialWD, "Libraries", "WiiU_BFREStoGTX", "BFRES_Textures_NoMips_BotWTex1Only.bms"), texturefile, workspacePath])

                # Remove the texture file.
                os.remove(texturefile)

                # Verify that the QuickBMS script created a new folder with the textures.
                extractDirectory = os.path.join(workspacePath, "texturefile")
                if not os.path.exists(extractDirectory):
                    print("No textures were extracted from " + currentModelTexturePair.itemName + "!")
                    continue

                # Move the GTX files to the Convert directory and delete the texture folder.
                for file in os.listdir(extractDirectory):
                    shutil.move(os.path.join(extractDirectory, file), convertFolder)
                shutil.rmtree(extractDirectory) # created by the extract script.

                # Convert these GTX files to DDS files.
                os.chdir(workspacePath)
                CommandLineUtils.call(os.path.join(workspacePath, "convertGTX.bat"), [])
                os.chdir(initialWD)

                # Apply the transparency fix to these DDS files.
                CommandLineUtils.call(quickBMSExecutablePath, ["-K", os.path.join(initialWD, "Libraries", "BFLIMDDS", "BFLIMDDSFix.bms"), os.path.join(outDDSLosslessFolder, "*.dds"), transparencyFixFolder])

                # Convert all created DDS files to PNG.
                for fixedFile in os.listdir(transparencyFixFolder):
                    shutil.move(os.path.join(transparencyFixFolder, fixedFile), pngConvertFolder)

                # Call the PNG conversion BAT file (for some reason the arguments aren't working as expected :P)
                os.chdir(workspacePath)
                CommandLineUtils.call("convertPNG.bat", [])
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
        CustomFileUtils.emptyFolder(os.path.join(workspacePath, "OutDDS"))
        CustomFileUtils.emptyFolder(os.path.join(workspacePath, "Convert"))
        CustomFileUtils.emptyFolder(transparencyFixFolder)
        CustomFileUtils.emptyFolder(outDDSLosslessFolder)
        CustomFileUtils.emptyFolder(pngConvertFolder)


    print("Added all files to the database successfully :)")

if __name__ == "__main__":
    extractModelAndTextureData()