import os
from customUtilities import CommandLineUtils

def extractAllPackArchives():
    print("***Phase 1: PACK Extraction ***")

    # SARC Extract library.
    sarcExtractPYPath = os.path.join(os.getcwd(), "Libraries", "WiiUTools-master", "SARCTools", "SARCExtract.py")

    # Query the user on both where the existent compilation is, and where to put these files.
    botwContent = "Z:\Desktop\BOTW\Raw Assets" # My personal location.
    while not os.path.exists(botwContent):
        if not botwContent == "":
            print("Invalid location!")
        botwContent = input("Where are the BoTW resources?: ")

    # Now extract all archives to essentially the same exact folder.
    for root, dirs, files in os.walk(botwContent):
        for file in files:
            if file.endswith(".pack") or file.endswith(".PACK"):
                # Check to see whether this has already been archived to the directory in question.
                expectedDirectory = os.path.join(root, file[0: file.index(".")])
                if not os.path.exists(expectedDirectory):
                    # Extract every PACK archive (has to use Python 2.7), arguments already quoted by custom lbrary.
                    print("Extracting " + file + " to " + expectedDirectory)
                    CommandLineUtils.call("python", [CommandLineUtils.toQuotedPath(sarcExtractPYPath), CommandLineUtils.toQuotedPath(os.path.join(root, file))])
                else:
                    print("Skipping " + file + ", expected directory already exists at " + expectedDirectory)

    print("\n\n")

if __name__ == "__main__":
    extractAllPackArchives()