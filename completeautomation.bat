echo "Please note that this will only work if you have cd'd to the directory of this file beforehand."
pause

rem Create the SBFRES compilation.
cd createsbfrescompilation
python3 CreateSBFRESCompilation.py
cd ..

rem Extract model and texture data.
cd bfresextraction
python3 ExtractModelAndTextureData.py
cd ..

rem Extract FBX files.
cd fbxextraction
python3 LoadAndExportExtractModels.py
