# BOTW Model Extraction... Version 2 #

## The idea ##

This is an extension on what was already a fairly complex tool.  The idea here is that the ENTIRE repository of BOTW SBFRES files is exported into FBX files from 3DSMax in one fell swoop.  Now, this is no easy task.  Max includes zero scripting API for exporting files, and that would be hard enough, considering that the models must be manually rotated.  In addition, models occasionally SHARE textures, making it really hard to export them all to different files.  How will it be done?  

## The code ##

First, the ExtractModels.py script takes care of creating a database of scripts for use within the following stages of the app.  This takes a WHILE, but eventually it will provide a massive repository of folders which have names pertaining to the models within them.  This is then the perfect setup for the BFRES importer script.  
Second, the pxp file provided is used with PhraseExpress.  First, you'll need to install MouseRecorder (mouserecorder.com), and then PhraseExpress.  Upon running the pxp file, it will run batch scripts which will then run the python scripts which work in cohesion with it.  