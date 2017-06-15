# Import required libraries.
import os
import shutil
from customUtilities import CustomFileUtils, CommandLineUtils

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
CustomFileUtils.emptyFolder(modelLoadingWorkspace)

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

                # Rename "file".bfres to model.bfres so that it is loaded by the maxscript.
                if bfresOrTextureFile.endswith(".bfres"):
                    shutil.move(os.path.join(modelLoadingWorkspace, bfresOrTextureFile), os.path.join(modelLoadingWorkspace, "model.bfres"))
                    print("Renamed " + bfresOrTextureFile + " to model.bfres")


            # Open 3DSMax and open the launch script file.
            input("Hold up boi")
            #CommandLineUtils.call(CommandLineUtils.quoted("C:\\Program Files\\Autodesk\\3ds Max 2015\\3dsmax.exe"), ["-q", "-U", "MAXScript", os.path.join(fbxExtractionPath, "BFRES to FBX.ms")])

            input("Got back control")

        else:
            print(expectedFBX + " already exists!  Skipping.")

# Remove the model loading workspace so that the PhraseExpress script knows to stop.
print("Completed successfully!  :)")
CustomFileUtils.emptyFolder(modelLoadingWorkspace)