# File utilities.
import os, shutil
from customUtilities import CustomFileUtils

def createCompilation():
    # Query the user on both where the existent compilation is, and where to put these files.
    botwContent = "Z:\Desktop\BOTW\SBFRES Compilation" # My personal location.
    while not os.path.exists(botwContent):
        if not botwContent == "":
            print("Invalid location!")
        botwContent = input("Where are the BoTW resources?: ")

    # Create the desired compilation folder.
    desiredCompilationFolder = input("Where should we compile the SBFRES files?: ")
    if not os.path.exists(desiredCompilationFolder):
        os.makedirs(desiredCompilationFolder)
        print("Created folder.")
    else:
        CustomFileUtils.offerToDeleteAllInSensitiveDirectory(desiredCompilationFolder)

    # Now move all SBFRES files over to this folder (untested)
    for root, dirs, files in os.walk(botwContent):
        for file in files:
            if file.endswith(".sbfres"):
                 shutil.copy(os.path.join(root, file), desiredCompilationFolder)
                 print("Copied " + os.path.join(root, file) + " to " + desiredCompilationFolder)

    print("Created compilation successfully!")

    return desiredCompilationFolder

if __name__ == "__main__":
    createCompilation()