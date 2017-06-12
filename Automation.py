# This is apparently where python keeps all of the utilities for accessing files and folders.
import os

# Obtain a valid content folder path.
while True:
    # Ask for the content folder.
    contentFolder = input("Where is the content folder?: ")

    # See whether this content folder is valid.
    if not os.path.exists(contentFolder):
        print("Uh oh!  This path does not exist >:(")
    else:
        break

# List all files with extension sbfres.
print("Obtaining all models")

# This class contains two definitions: a file path for the model.sbfres file, and another for the model.Tex1.sbfres file.
class BOTWModel(object):
    # The class constructor
    def __init__(self, modelFilePath: str, textureFilePath: str, filename: str):
        self.modelFilePath = modelFilePath
        self.textureFilePath = textureFilePath
        self.filename = filename
        print(self.filename + ": Model path is " + self.modelFilePath + " and Tex1 path is " + self.textureFilePath)

# Returns a boolean of whether this file should be added to the filename list.
invalidFileEndings = [".Tex2.sbfres", "_Animation.sbfres", "_L.sbfres", "_L.Tex1.sbfres", "_L.Tex2.sbfres"]
def isExtraneousSBFRES(filename: str):
    for invalidEnd in invalidFileEndings:
        if filename.endswith(invalidEnd):
            return True
    return False

# Add all unique SBFRES model paths and file paths to the same list.
fileList = list()
for dirpath, dirnames, filenames in os.walk(contentFolder):
    for filename in [f for f in filenames if (f.endswith(".sbfres") and not isExtraneousSBFRES(f))]:
        fileList.append(os.path.join(contentFolder, dirpath, filename))

# Since get basename returns the file with the extension and we need to see the difference between .Tex1.sbfres and .sbfres.
def getFilenameForPath(path: str):
    name = os.path.basename(path)
    return name[0:name.index(".")]

# Link all model and SBFRES files.
modelList = list()

# Using list(filePath) instead of filePath makes it so we can remove objects from the list during iteration.
for firstFilePath in fileList:
    # Get the filename of this index.
    firstFilename = getFilenameForPath(firstFilePath)
    fileList.remove(firstFilePath)

    secondFilePath = ""

    # Iterate through the list a second time to find the texture file.
    for potentialSecondFilePath in fileList:
        # Get the filename of this new item.
        secondFilename = getFilenameForPath(potentialSecondFilePath)

        # Make sure that we are getting the texture and not the same file.
        if firstFilename == secondFilename and not firstFilePath == potentialSecondFilePath:
            # Make this the second file path.
            secondFilePath = potentialSecondFilePath

            # Remove both files from the model path list (resource inefficient otherwise).
            fileList.remove(potentialSecondFilePath)
            break

    # Create the model.
    if firstFilePath.endswith(".Tex1.sbfres"):
        modelList.append(BOTWModel(secondFilePath, firstFilePath, firstFilename))
    else:
        modelList.append(BOTWModel(firstFilePath, secondFilePath, firstFilename))

print("Completed model registration :)")
