# BOTW Model Extraction... Version 2 #

## The idea ##

This is an extension on what was already a fairly complex tool.  The idea here is that the ENTIRE repository of BOTW SBFRES files is exported into FBX files from 3DSMax in one fell swoop.  Now, this is no easy task.  Max includes zero scripting API for exporting files, and that would be hard enough, considering that the models must be manually rotated.  In addition, models occasionally SHARE textures, making it really hard to export them all to different files.  How will it be done?  

## The method(s) ##

Everything revolves around a single Python script, which automates the vast majority of this script's functionality, including texture extraction, model extraction (all into the same folder to prevent failure of cross-referencing), etc.  However, Python can't automate 3DSMax, which is why we use a really weird method which actually employs MouseRecorder to automate 3DSMax.  By simulating a certain key combination, we can get the mouse recorder to automte the whole 3DSMax rotation and exporting business, and then tell Python that it finished by adding a file to the desktop with a certain name (which Python is looking for).  Python then deletes this file and continues automating with the same techniques.  
Understandably therefore, it is super easy to mess this up.  A lot of intricate work is put into making this work with the MouseRecorder, including renaming things so that they end up at the top of the Explorer menu, so failure to set something up properly will result in weird issues.  Thankfully there are plenty of failsafes already built in.  