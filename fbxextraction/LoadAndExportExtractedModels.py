# Import required libraries.
import os
import shutil
from customUtilities import SimulateKeyboard, SimulateMouse, CustomFileUtils

# Testing.
SimulateMouse.click(3, 797)
SimulateKeyboard.typePhrase("hi there!")
SimulateMouse.click(0, 500)
exit(0)

# Create required references (since we are executed from a different location)
fbxExtractionPath = os.getcwd()
bfresDatabase = os.path.join(fbxExtractionPath, "..", "bfresextraction", "Database") # up one folder.
modelLoadingWorkspace = os.path.join(fbxExtractionPath, "Workspace")
fbxDatabase = os.path.join(fbxExtractionPath, "Database")


# Make sure that the model loading workspace exists.
if not os.path.exists(modelLoadingWorkspace):
    os.makedirs(modelLoadingWorkspace)
    print("Had to create model loading workspace!")
print("Reset true file")

# Delete previously existing BFRES and PNG files from the workspace.
for previousWorkspaceFile in os.listdir(modelLoadingWorkspace):
    if previousWorkspaceFile.endswith(".png") or previousWorkspaceFile.endswith(".bfres"):
        os.remove(os.path.join(modelLoadingWorkspace, previousWorkspaceFile))
        print("Removed " + previousWorkspaceFile + " from workspace!")

# Define the directories which have models to extract.
for root, dirs, files in os.walk(bfresDatabase):
    for modelSubdirectory in dirs:
        # If the FBX database has not yet contained this file.
        expectedFBX = os.path.join(fbxDatabase, modelSubdirectory + ".fbx")
        print("Checking for " + expectedFBX)
        if not os.path.exists(expectedFBX):
            # Output that it currently does not exist.
            print(expectedFBX + " doesn't exist!  Exporting now.")

            # Prepare this set of files.
            exportedBfresSubdirectory = os.path.join(bfresDatabase, modelSubdirectory)
            for bfresOrTextureFile in os.listdir(exportedBfresSubdirectory):
                # Copy every file to the model loading workspace.
                shutil.copy(os.path.join(exportedBfresSubdirectory, bfresOrTextureFile), modelLoadingWorkspace)
                print("Added " + bfresOrTextureFile + " to the workspace!")

                # Rename file.bfres to _file.bfres so that it ends up at the top of the list.
                if bfresOrTextureFile.endswith(".bfres"):
                    shutil.move(os.path.join(modelLoadingWorkspace, bfresOrTextureFile), os.path.join(modelLoadingWorkspace, "_" + bfresOrTextureFile))

            # Begin the mouse clicking simulation.
            

        else:
            print(expectedFBX + " already exists!  Skipping.")

# Remove the model loading workspace so that the PhraseExpress script knows to stop.
print("Completed successfully!  :)")
CustomFileUtils.emptyFolder(modelLoadingWorkspace)