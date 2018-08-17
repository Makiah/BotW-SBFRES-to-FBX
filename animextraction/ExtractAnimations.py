import os
import shutil
from customUtilities import CustomFileUtils, CommandLineUtilsax

# Uses Smash Forge to export animations, and this python script takes care of moving them around so that the next one can apply the animations.  
def extractAnimations(): 
	# Initial wd
	initialWD = os.getcwd()

	# Run through the SBFRES compilation and copy the animation SBFRES files into the fbxextraction "Database" (link then by name)
	fbxDatabase = os.path.join(initialWD, "..", "fbxextraction", "Database")
	sbfresCompilation = os.path.join(initialWD, "..", "sbfresgrouper", "Compilation")

	for sbfresFile in sorted(os.listdir(sbfresCompilation)): 
		if sbfresFile.endswith("_Animation.sbfres"): 
			sbfresName = sbfresFile[0:len(sbfresFile) - len("_Animation.sbfres")]
			fbxDatabaseSubPath = os.path.join(fbxDatabase, sbfresName)
			if not os.path.exists(fbxDatabaseSubPath): 
				os.makedirs(fbxDatabaseSubPath)
				print("Had to make " + sbfresName + " database folder")
			# copy over animation sbfres
			shutil.copy(os.path.join(sbfresCompilation, sbfresFile), fbxDatabaseSubPath)
