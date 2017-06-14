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

# Write to moretoload.txt.
def openAndWriteToMoreToLoad(thingToWrite: str):
    # will create if not already existent.
    moreToLoad = open(os.path.join(os.getcwd(), "__ModelLoadingWorkspace", "moretoload.txt"), "w")
    moreToLoad.write(thingToWrite)
    moreToLoad.close()


# Create required references.
bfresDatabase = os.path.join(os.getcwd(), "ExtractionDatabase")
modelLoadingWorkspace = os.path.join("C:", "Users", "makiah", "Desktop", "___ModelLoadingWorkspace")
fbxDatabase = os.path.join(os.getcwd(), "FBXDatabase")
openAndWriteToMoreToLoad("true")

# Make sure that the model loading workspace exists.
if not os.path.exists(modelLoadingWorkspace):
    os.makedirs(modelLoadingWorkspace)

# Delete previously existing BFRES and PNG files from the workspace.
for previousWorkspaceFile in os.listdir(modelLoadingWorkspace):
    if previousWorkspaceFile.endswith(".png") or previousWorkspaceFile.endswith(".bfres"):
        os.remove(os.path.join(modelLoadingWorkspace, previousWorkspaceFile))

# Define the directories which have models to extract.
for modelSubdirectory in [x[0] for x in os.walk(bfresDatabase)]:
    # If the FBX database has not yet contained this file.
    if not os.path.exists(os.path.join(fbxDatabase, modelSubdirectory)):
        # Prepare this set of files.
        for bfresOrTextureFile in os.listdir(os.path.join(bfresDatabase, modelSubdirectory)):
            # Copy every file to the model loading workspace.
            shutil.copy(bfresOrTextureFile, modelLoadingWorkspace)

            # Rename file.bfres to _file.bfres so that it ends up at the top of the list.
            if bfresOrTextureFile.endswith(".bfres"):
                shutil.move(os.path.join(modelLoadingWorkspace, bfresOrTextureFile), os.path.join(modelLoadingWorkspace, "_" + bfresOrTextureFile))

        # Exit immediately (only doing one at a time.
        exit(0)

# Remove the model loading workspace so that the PhraseExpress script knows to stop.
emptyFolder(modelLoadingWorkspace)
openAndWriteToMoreToLoad("false")