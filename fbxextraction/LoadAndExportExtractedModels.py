# Import required libraries.
import os
import shutil
from customUtilities import CommandLineUtils, CustomFileUtils

def loadAndExportModels():
    # Checks for an ending like -00, -01, -02, etc.
    def isMultipartFolder(folderPath: str):
        for i in range(0, 99):
            if i < 10:
                if folderPath.endswith("-0" + str(i)): 
                    return True
            else:
                if folderPath.endswith("-" + str(i)): 
                    return True
        return False

    print("***Phase 4: Model Exports***")

	# Create required references (since we are executed from a different location)
    fbxExtractionPath = os.getcwd()
    bfresDatabase = os.path.join(fbxExtractionPath, "..", "bfresextraction", "Database") # up one folder.

    # Make sure that the model loading workspace exists.
    modelLoadingWorkspace = os.path.join(fbxExtractionPath, "Workspace")
    if not os.path.exists(modelLoadingWorkspace):
        os.makedirs(modelLoadingWorkspace)
        print("Had to create model loading workspace!")

    # Make sure that the database exists.
    fbxDatabase = os.path.join(fbxExtractionPath, "Database")
    if not os.path.exists(fbxDatabase):
        os.makedirs(fbxDatabase)
    else:
        CustomFileUtils.offerToDeleteAllInSensitiveDirectory(fbxDatabase)

    # Get the path to the custom script.
    bfresToFBXMAXScript = os.path.join(fbxExtractionPath, "BFRES to FBX 2.ms")

    # Ask the user for the 3DSMax executable location.
    maxExecutableLocation = "C:\\Program Files\\Autodesk\\3ds Max 2016\\3dsmax.exe"
    if not os.path.exists(maxExecutableLocation):
        maxExecutableLocation = input("Input 3DSMax executable path: ")

    # Add the path of this workspace to the MAXScript (thanks StackOverflow!)
    with open(bfresToFBXMAXScript, 'r') as file:
        # read a list of lines into data
        data = file.readlines()
    data[0] = "USER_WORKSPACE_PATH = \"" + (modelLoadingWorkspace + "\\").replace('\\', '\\\\') + "\" \n"
    with open(bfresToFBXMAXScript, 'w') as file:
        file.writelines( data )

    # Define the directories which have models to extract.
    for modelSubdirectory in os.listdir(bfresDatabase):
        # If the FBX database has not yet contained this file.
        expectedSubdirectory = os.path.join(fbxDatabase, modelSubdirectory)
        print("Checking for " + expectedSubdirectory)
        if not os.path.exists(expectedSubdirectory):
            # Delete previously existing BFRES and PNG files from the workspace.
            CustomFileUtils.emptyFolder(modelLoadingWorkspace)

            # Output that it currently does not exist.
            print(expectedSubdirectory + " doesn't exist!  Exporting now.")

            # Prepare this set of files.
            foundBFRES = False
            foundTexture = False
            exportedBfresSubdirectory = os.path.join(bfresDatabase, modelSubdirectory)
            for bfresOrTextureFile in os.listdir(exportedBfresSubdirectory):
                # Copy every file to the model loading workspace.
                shutil.copy(os.path.join(exportedBfresSubdirectory, bfresOrTextureFile), modelLoadingWorkspace)
                print("Added " + bfresOrTextureFile + " to the workspace!")

                if (not foundTexture) and (bfresOrTextureFile.endswith(".png")): 
                    foundTexture = True

                # Rename "file".bfres to model.bfres so that it is loaded by the maxscript.
                if (not foundBFRES) and (bfresOrTextureFile.endswith(".bfres")):
                    shutil.move(os.path.join(modelLoadingWorkspace, bfresOrTextureFile), os.path.join(modelLoadingWorkspace, "model.bfres"))
                    print("Renamed " + bfresOrTextureFile + " to model.bfres")
                    foundBFRES = True

            print("Found texture is " + str(foundTexture) + " and found bfres is " + str(foundBFRES))

            # Don't call MAXScript if no BFRES found for this folder (but notify user)
            if not foundBFRES: 
                print("Can't find model BFRES for " + modelSubdirectory)
            else: 
                # BFRES but no texture, perhaps multipart? 
                if (not foundTexture) and isMultipartFolder(modelSubdirectory):  
                    print("No texture so checking multipart")
                    multipartRoot = modelSubdirectory[0:len(modelSubdirectory) - 3]
                    for modelSubdirectory in os.listdir(bfresDatabase): 
                        if modelSubdirectory == multipartRoot: 
                            print("Found root " + multipartRoot)
                            for file in os.listdir(os.path.join(bfresDatabase, multipartRoot)): 
                                if file.endswith(".png"): 
                                    shutil.copy(os.path.join(bfresDatabase, multipartRoot, file), modelLoadingWorkspace)
                                    print("Copied " + file)
                            break

                # Open 3DSMax and let the max script do it's THING.
                CommandLineUtils.call(CommandLineUtils.quoted(maxExecutableLocation), ["-q", "-U", "MAXScript", CommandLineUtils.quoted(bfresToFBXMAXScript)])

            # Now move the FBX files it provided to the database of a folder with that name.
            os.makedirs(expectedSubdirectory)
            if foundBFRES: 
                for possibleFBXExport in os.listdir(modelLoadingWorkspace):
                    if possibleFBXExport.endswith(".fbx"):
                        shutil.move(os.path.join(modelLoadingWorkspace, possibleFBXExport), expectedSubdirectory)
                        print("Added " + possibleFBXExport + " to the database! :)")

        else:
            print(expectedSubdirectory + " already exists!  Skipping.")

    # Remove the model loading workspace so that the PhraseExpress script knows to stop.
    print("Completed successfully!  :)")
    CustomFileUtils.emptyFolder(modelLoadingWorkspace)

    print("\n\n")

if __name__ == "__main__": 
    loadAndExportModels()