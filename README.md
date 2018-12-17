# Automated SBFRES Extractor for Zelda BotW 

## Disclaimer 

Avoid distributing the resulting models from implementing this tool, as they are copyrighted by Nintendo and you will be subject to such laws.  Personal use ONLY!

## Proof of Concept 
<p align="center">
  <img src="proofofconcept/bassmoving.gif"/>
</p>


## Initial Setup 
First, you'll need the models found by extracting your Wii U disc's content.  This can be done with a number of existent tools, so avoid torrenting the disc image (support this awesome game peeps!).  
Then, clone this repository in SourceTree or extract the downloaded ZIP archive.  Then run `cd /extracted/project/copy`, and finally, `python3 RunMe.py`. This should take care of everything, and after about a day or so (it'll probably take that long), you can open the FBX files in `fbxextraction/Database`.  For a more in-depth analysis of how it works, look at the next section.  


## Functionality 
*Note: this tool will only work on Windows because of limited platform support for certain tools.*

For each section, you'll need Python 3 so I suggest installing that first.

### PACK Extraction 
Searches through the entirety of the game directories and finds PACK files, then extracts them to a directory in the same path.  

Thanks to: NWPlayer123 for `SARCExtract.py`.

Additional requirements: Python 2.7.

### SBFRES grouping
Super simple, just takes all discovered SBFRES files (including extracted ones) and moves them to a `Compilation` subdirectory.  

Additional requirements: None.

### Texture Extraction
A bit more complex: uses yaz0dec to extract the model and tex1 sbfres files, and then uses an assortment of libraries to extract and convert the textures to PNG format.  

Thanks to: [Random Talking Bush from the VG Resource](https://www.vg-resource.com/thread-29836.html) for his QuickBMS scripts, NWPlayer123 for TexConv2, and the creators of ImageMagick. 

Additional requirements: None (everything included in `Libraries`).  

### Model Extraction
Uses RTB's BFRES extraction MAXScript via 3DS Max to render the model and load the previously extracted textures, then uses some MAXScript I wrote to automate the process via a startup script argument.  

Thanks to: Random Talking Bush for the [extraction script](https://www.vg-resource.com/thread-29836.html).  

Additional requirements: 3DS Max 2015/16.  

### Animation Extraction (WiP)
Extracts Maya animations (.anim files) in each animation sbfres via an automated fork of Smash Forge, alongside the corresponding .Animation.sbfres in one database.  Then, takes the completed models from fbxextraction and loads them in Maya, applies an animation to them, and exports the skeleton to a different set of database folders.  I couldn't figure out how to embed multiple tracks into a single FBX file that was readable by Unreal or Unity without doing frame splitting, and this was the next best thing.  

Thanks to: [KillzXGaming](https://github.com/KillzXGaming) for his terrific work on [Smash Forge](https://github.com/jam1garner/Smash-Forge) that enabled animation extraction.  

Additional requirements: Maya 2016.  
