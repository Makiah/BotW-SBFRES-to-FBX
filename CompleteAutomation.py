# Required files.
from sbfresgrouper import CreateSBFRESCompilation
from bfresextraction import ExtractModelAndTextureData
from fbxextraction import LoadAndExportExtractedModels
from packextractor import ExtractPackArchives
import os

# Do everything!
initialWD = os.getcwd()

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