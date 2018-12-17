# Required modules
from sbfresgrouper import CreateSBFRESCompilation
from bfresextraction import ExtractModelAndTextureData
from fbxextraction import LoadAndExportExtractedModels
from packextractor import ExtractPackArchives
from animextraction import ExtractAnimations, ApplyAnimationsToFBXModels
import os

if __name__ == "__main__": 
    print("*************************")
    print("*** BotW SBFRES to FBX***")
    print("*************************")
    print("")
    print("1: Attempt to extract literally everything, you supply the SBFRES files and the tool extracts the entirety of them.")
    print("2: Run the PACK extractor, which will extract all PACK archives to the best choice directory within the resources.")
    print("3: Run the SBFRES compiler, which will organize all SBFRES files into a database, making them easier to modify")
    print("4: Run BFRES extraction, which will employ the SBFRES database (has to be organized before use) to extract all textures")
    print("5: Run the FBX extractor, which will use 3DS Max and RTB's loading script to get FBX models for all in-game assets")
    print("6: Run the animation extractor, which will use KillzXGaming's Smash Forge to export animations, link them to models from step 5, and then use Maya to apply them.")
    print("")
    print("Note: please avoid using special characters or spaces in your paths, they interfere with aspects of the extraction")
    print("") 

    initialWD = os.getcwd()

    selection = input("Please select an option: ")

    if selection == "1": 
        os.chdir("packextractor")
        ExtractPackArchives.extractAllPackArchives()
        os.chdir(initialWD)
        
        os.chdir("sbfresgrouper")
        CreateSBFRESCompilation.createCompilation()
        os.chdir(initialWD)
        
        os.chdir("bfresextraction")
        ExtractModelAndTextureData.extractModelAndTextureData()
        os.chdir(initialWD)

        os.chdir("fbxextraction")
        LoadAndExportExtractedModels.loadAndExportModels()
        os.chdir(initialWD)
		
        os.chdir("animextraction")
        ExtractAnimations.extractAnimations()
        os.chdir(initialWD)

    elif selection == "2":
        os.chdir("packextractor")
        ExtractPackArchives.extractAllPackArchives()
        os.chdir(initialWD)
    
    elif selection == "3":         
        os.chdir("sbfresgrouper")
        CreateSBFRESCompilation.createCompilation()
        os.chdir(initialWD)
    
    elif selection == "4": 
        os.chdir("bfresextraction")
        ExtractModelAndTextureData.extractModelAndTextureData()
        os.chdir(initialWD)
    
    elif selection == "5": 
        os.chdir("fbxextraction")
        LoadAndExportExtractedModels.loadAndExportModels()
        os.chdir(initialWD)

    elif selection == "6":
        os.chdir("animextraction")
        ExtractAnimations.extractAnimations()
        os.chdir(initialWD)
        os.chdir("animextraction")
        ApplyAnimationsToFBXModels.applyFBXModelAnimations()

