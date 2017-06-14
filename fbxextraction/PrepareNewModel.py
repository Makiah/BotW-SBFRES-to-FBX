# Import required libraries.
import os
import shutil

# Used to empty folders (but not the folder itself)
def emptyFolder(folderPath):
    for root, dirs, files in os.walk(folderPath):
        for f in files:
            os.unlink(os.path.join(root, f)) # the EXACT same thing as os.remove :P
        for d in dirs:
            shutil.rmtree(os.path.join(root, d))


# Create required references (since we are executed from a different location)
fbxExtractionPath = "C:\\Users\\makiah\\Desktop\\BOTWModelExtractionV2\\fbxextraction"
bfresDatabase = "C:\\Users\\makiah\\Desktop\\BOTWModelExtractionV2\\bfresextraction\\BFRESDatabase"
modelLoadingWorkspace = os.path.join(fbxExtractionPath, "___ModelLoadingWorkspace")
fbxDatabase = os.path.join(fbxExtractionPath, "FBXDatabase")

# Write to moretoload.txt.
def openAndWriteToMoreToLoad(thingToWrite: str):
    # will create if not already existent.
    moreToLoad = open(os.path.join(modelLoadingWorkspace, "moretoload.txt"), "w")
    moreToLoad.write(thingToWrite)
    moreToLoad.close()

# Make sure that the model loading workspace exists.
if not os.path.exists(modelLoadingWorkspace):
    os.makedirs(modelLoadingWorkspace)
    print("Had to create model loading workspace!")
openAndWriteToMoreToLoad("true")
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
            print("Doesn't exist!  Exporting now.  ")

            # Prepare this set of files.
            exportedBfresSubdirectory = os.path.join(bfresDatabase, modelSubdirectory)
            for bfresOrTextureFile in os.listdir(exportedBfresSubdirectory):
                # Copy every file to the model loading workspace.
                shutil.copy(os.path.join(exportedBfresSubdirectory, bfresOrTextureFile), modelLoadingWorkspace)
                print("Added " + bfresOrTextureFile + " to the workspace!")

                # Rename file.bfres to _file.bfres so that it ends up at the top of the list.
                if bfresOrTextureFile.endswith(".bfres"):
                    shutil.move(os.path.join(modelLoadingWorkspace, bfresOrTextureFile), os.path.join(modelLoadingWorkspace, "_" + bfresOrTextureFile))

            # Exit immediately (only doing one at a time.
            exit(0)

# Remove the model loading workspace so that the PhraseExpress script knows to stop.
print("No more to add!")
emptyFolder(modelLoadingWorkspace)
openAndWriteToMoreToLoad("false")