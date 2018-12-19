import os
import shutil
from customUtilities import CustomFileUtils, CommandLineUtils

# Uses Smash Forge to export animations, and this python script takes care of moving them around so that the next one can apply the animations.  
def extractAnimations(): 
	print("***Phase 5: Animation Extraction***")

	# Initial wd
	initialWD = os.getcwd()

	# Required constants
	smashForgeExecutableLoc = os.path.join(initialWD, "Libraries", "SmashForge", "Smash Forge.exe")
	animFolderLoc = os.path.join(initialWD, "Libraries", "SmashForge", "animextractions")
	if os.path.exists(animFolderLoc): 
		shutil.rmtree(animFolderLoc)
	os.makedirs(animFolderLoc)

	# Run through the SBFRES compilation and copy the animation SBFRES files into the fbxextraction "Database" (link then by name)
	animDatabase = os.path.join(initialWD, "Database")
	sbfresCompilation = os.path.join(initialWD, "..", "sbfresgrouper", "Compilation")
	
	# Check whether we should do this from scratch.  
	if os.path.exists(animDatabase): 
		CustomFileUtils.offerToDeleteAllInSensitiveDirectory(animDatabase)
	else: 
		os.makedirs(animDatabase)

	# Go through the SBFRES animation files and check whether they've been extracted
	for sbfresFile in sorted(os.listdir(sbfresCompilation)): 
		if sbfresFile.endswith("_Animation.sbfres"): 
			sbfresName = sbfresFile[0:len(sbfresFile) - len("_Animation.sbfres")]
			animDatabaseSubPath = os.path.join(animDatabase, sbfresName)
			if not os.path.exists(animDatabaseSubPath): 
				os.makedirs(animDatabaseSubPath)
			else: 
				print("Skipping " + sbfresFile + " because already extracted")
				continue
			if not os.path.exists(os.path.join(animDatabaseSubPath, sbfresFile)): 
				# copy over animation sbfres
				shutil.copy(os.path.join(sbfresCompilation, sbfresFile), animDatabaseSubPath)
				print("Copied " + os.path.join(sbfresCompilation, sbfresFile) + " to " + animDatabaseSubPath)
			else: 
				print("Didn't copy " + sbfresFile + " because it already exists")

			# Run the modified Smash Forge executable on all of the animation files.  
			found = False
			for file in os.listdir(animDatabaseSubPath): 
				if file.endswith(".anim"): 
					found = True
					break
			if found: # Already extracted
				print(sbfresFile + " has already been extracted")
				continue
			animDatabaseAnimFile = os.path.join(animDatabaseSubPath, sbfresFile)
			CommandLineUtils.call(CommandLineUtils.quoted(smashForgeExecutableLoc), [CommandLineUtils.quoted(animDatabaseAnimFile)])
			for animExtractedFile in os.listdir(animFolderLoc): 
				shutil.move(os.path.join(animFolderLoc, animExtractedFile), animDatabaseSubPath)
				print("Moved " + animExtractedFile)

	print("\n\n")
