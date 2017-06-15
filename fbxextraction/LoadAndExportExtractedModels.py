# Import required libraries.
import os
import shutil
from customUtilities import CustomFileUtils, CommandLineUtils

# Create required references (since we are executed from a different location)
fbxExtractionPath = os.getcwd()
bfresDatabase = os.path.join(fbxExtractionPath, "..", "bfresextraction", "Database") # up one folder.
modelLoadingWorkspace = os.path.join(fbxExtractionPath, "Workspace")
fbxDatabase = os.path.join(fbxExtractionPath, "Database")
CustomFileUtils.offerToDeleteAllInSensitiveDirectory(fbxDatabase)


# Make sure that the model loading workspace exists.
if not os.path.exists(modelLoadingWorkspace):
    os.makedirs(modelLoadingWorkspace)
    print("Had to create model loading workspace!")

# Define the directories which have models to extract.
for root, dirs, files in os.walk(bfresDatabase):
    for modelSubdirectory in dirs:
        # If the FBX database has not yet contained this file.
        expectedSubdirectory = os.path.join(fbxDatabase, modelSubdirectory)
        print("Checking for " + expectedSubdirectory)
        if not os.path.exists(expectedSubdirectory):
            # Delete previously existing BFRES and PNG files from the workspace.
            CustomFileUtils.emptyFolder(modelLoadingWorkspace)

            # Output that it currently does not exist.
            print(expectedSubdirectory + " doesn't exist!  Exporting now.")

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


            # Open 3DSMax and let the max script do it's THING.
            CommandLineUtils.call(CommandLineUtils.quoted("C:\\Program Files\\Autodesk\\3ds Max 2015\\3dsmax.exe"), ["-q", "-U", "MAXScript", os.path.join(fbxExtractionPath, "BFRES to FBX.ms")])

            # Now move the FBX files it provided to the database of a folder with that name.
            os.makedirs(expectedSubdirectory)
            for possibleFBXExport in os.listdir(modelLoadingWorkspace):
                if possibleFBXExport.endswith(".fbx"):
                    shutil.move(os.path.join(modelLoadingWorkspace, possibleFBXExport), expectedSubdirectory)
                    print("Added " + possibleFBXExport + " to the database! :)")

        else:
            print(expectedSubdirectory + " already exists!  Skipping.")

# Remove the model loading workspace so that the PhraseExpress script knows to stop.
print("Completed successfully!  :)")
CustomFileUtils.emptyFolder(modelLoadingWorkspace)