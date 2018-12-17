import os
import shutil
from customUtilities import CustomFileUtils, CommandLineUtils

def applyFBXModelAnimations(): 
	initialWD = os.getcwd()

	# For some reason these won't export?  Maybe update Smash Forge later on
	glitchyAnimations = ["Wait_Random_H.anim", "Wait_Random_H_DownSlope.anim", "Wait_Random_H_UpSlope.anim"]

	mayaExecutablePath = "C:\\Program Files\\Autodesk\\Maya2018\\bin\\mayabatch.exe"
	melExtractPath = os.path.join(initialWD, "extract.mel")

	database2Path = os.path.join(initialWD, "Database2")
	if os.path.exists(database2Path): 
		CustomFileUtils.offerToDeleteAllInSensitiveDirectory(database2Path)

	# Generate extract.mel
	for animFolder in sorted(os.listdir(os.path.join(initialWD, "Database"))): 
		# Skip this if already outputted
		outputPath = os.path.join(database2Path, animFolder)
		if os.path.exists(outputPath): 
			print("Skipping " + animFolder + " because already existent")
			continue
		else: 
			os.mkdir(outputPath)

		# Figure out corresponding fbx
		correspondingFBXFolder = os.path.join(initialWD, "..", "fbxextraction", "Database", animFolder)
		if not os.path.exists(correspondingFBXFolder): 
			print("Can't find corresponding FBX folder for " + animFolder)
			continue
		fbxModelPath = ""
		fbxModelName = ""
		for possibleFBXFile in os.listdir(correspondingFBXFolder): 
			if possibleFBXFile.endswith(".fbx"): 
				fbxModelPath = os.path.join(correspondingFBXFolder, possibleFBXFile)
				fbxModelName = possibleFBXFile[0:len(possibleFBXFile) - 4]
				break
		print("Chose FBX file " + fbxModelPath)

		# Create extract.mel for this file.  
		extractMELPath = os.path.join(initialWD, "extract.mel")
		if os.path.exists(extractMELPath): 
			os.remove(extractMELPath)
		extractMELFile = open(extractMELPath, "w+")

		print("Writing MEL script")
		for animFile in sorted(os.listdir(os.path.join(initialWD, "Database", animFolder))): 
			if not animFile.endswith(".anim"): 
				continue
			if animFile in glitchyAnimations: # hacky fix
				continue
			animFileName = animFile[0:len(animFile) - 5]
			animFilePath = os.path.join(initialWD, "Database", animFolder, animFile)
			outputFile = os.path.join(outputPath, animFolder + "_" + animFileName + ".fbx")
			extractMELFile.write("""
// Import the main model FBX file
file -import -type "FBX"  -ignoreVersion -ra true -mergeNamespacesOnClash false -namespace "{0}" -options "fbx"  -pr  -importFrameRate true  -importTimeRange "override" "{1}";

// Select the skeleton hierarchy
select -r Root ;
select -hierarchy;

// Import the animation file.  
file -import -type "animImport"  -ignoreVersion -ra true -mergeNamespacesOnClash false -namespace "{2}" -options "targetTime=4;copies=1;option=replace;pictures=0;connect=0;"  -pr  -importTimeRange "combine" "{3}";

// Select the skeleton hierarchy again
select -r Root ;
select -hierarchy;

// Export the skeleton selection
file -force -options "v=0;" -typ "FBX export" -pr -es "{4}";
deleteUI -window FbxWarningWindow;

// Completely clear scene (perhaps a more elegant approach elsewhere?)
file -f -new;

// Start from the top while there are still animations
""".format(fbxModelName, fbxModelPath.replace("\\", "\\\\"), animFileName, animFilePath.replace("\\", "\\\\"), outputFile.replace("\\", "\\\\")))
		extractMELFile.close()

		# Run the maya command
		print("Running Maya command")
		CommandLineUtils.call(CommandLineUtils.quoted(mayaExecutablePath), ["-script", CommandLineUtils.quoted(melExtractPath)])