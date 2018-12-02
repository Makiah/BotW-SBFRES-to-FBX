# File utilities.
import os, shutil
from customUtilities import CustomFileUtils

def createCompilation():
    print("***Phase 2: SBFRES Grouping ***")

    # Query the user on both where the existent compilation is, and where to put these files.
    botwContent = "Z:\Desktop\BOTW\Raw Assets" # My personal location.
    while not os.path.exists(botwContent):
        if not botwContent == "":
            print("Invalid location!")
        botwContent = input("Where are the BoTW resources?: ")

    # Create the desired compilation folder.
    desiredCompilationFolder = os.path.join(os.getcwd(), "Compilation")
    if not os.path.exists(desiredCompilationFolder):
        os.makedirs(desiredCompilationFolder)
        print("Created compilation folder.")
    else:
        CustomFileUtils.offerToDeleteAllInSensitiveDirectory(desiredCompilationFolder)

    # Now move all SBFRES files over to this folder (untested)
    for root, dirs, files in os.walk(botwContent):
        for file in files:
            if file.endswith(".sbfres"):
                expectedFile = os.path.join(desiredCompilationFolder, file)
                if not os.path.exists(expectedFile):
                    shutil.copy(os.path.join(root, file), desiredCompilationFolder)
                    print("Copied " + os.path.join(root, file) + " to " + desiredCompilationFolder)
                else:
                    print("Skipping " + expectedFile)

    print("Created compilation successfully!")
	
    print("\n\n")

if __name__ == "__main__":
    createCompilation()