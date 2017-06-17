import os, shutil

def findAndCombineMultipartModels():

    # Checks for an ending like -00, -01, -02, etc.
    def isMultipartFolder(folderPath: str):
        for i in range(0, 99):
            if i < 10:
                return folderPath.endswith("-0" + str(i))
            else:
                return folderPath.endswith("-" + str(i))

    # Find all models which end with -00, -01, etc, and move them into their own pending directory.
    for root, dirs, files in os.walk("."):
        for dir in dirs:
            if isMultipartFolder(dir):
                folderRootPath = os.path.join(root, dir[0:len(dir) - 3])
                completedFolderPath = folderRootPath + " (Complete)"
                pendingFolderPath = folderRootPath + " (Pending)"
                print("Determined that " + dir + " is a multipart folder.")
                if not os.path.exists(combinedFolder):
                    os.makedirs(combinedFolder)
