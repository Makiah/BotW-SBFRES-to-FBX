USER_WORKSPACE_PATH = "E:\\BotW-SBFRES-to-FBX\\fbxextraction\\Workspace\\" 

-- Importer for Wii U / Switch BFRES files seen in many Nintendo games. 
-- Written by ItsEasyActually and Random Talking Bush (with some help from Ploaj for 10-bit normal values, and Sylk for optimizations and assistance in general).
-- Credit to the tockdom wiki community for the format documention
-- Special thanks to TGE for help early on with new scripting methods and getting ItsEasyActually started

-- Changelog:
-- June 20th, 2018
-- Fixed Switch models with four values (e.g. Obj_BGOBJ_CDplayer_M_Octa) failing to import.
-- Fixed vertex alphas not being applied to Wii U models.

-- April 30th, 2018
-- Fixed Switch models with three bone IDs not importing correctly (e.g. various models in Labo).

-- April 22nd, 2018
-- Temporarily disabled auto-application of emissive textures as it was *still* causing some models to error when importing.
-- Fixed Switch models with over 65535 vertices not importing correctly (e.g. LvMap1BG\Field.bfres from Kirby Star Allies).
-- Fixed models with specifically 5 weight values failing to import (e.g. LastBoss, also from Star Allies).

-- January 25th, 2018:
-- Added an option to print material properties to the Listener.
-- Changed texture importing to a two-pass system so it shouldn't error if it tries to apply certain textures before a diffuse is assigned.

-- August 4th, 2017:
-- Fixed Splatoon 2 models not importing correctly.

-- July 27th, 2017:
-- Added support for Nintendo Switch BFRES files!
-- Revised the material importing again with some changes from Sylk.
-- Fixed texture paths not remembering changes, added an option to check subfolders.

-- May 30th, 2017:
-- Sylk helped out with revising the UI, and another bunch of optimizations to the script were made
-- Added proper material importing, now bump/specular/emissive/etc. maps are applied to the right channels.
-- Added vertex types 0 (1-byte unsigned integer) and 2051 (1 half-float), fixing various TMS #FE and Paper Mario models.
-- Added scaling modifier to bones, which should fix certain models having misaligned parts (e.g. Balloon Yoshi from NSMBU).
-- Re-implemented the ability to import more than one BFMDL at once.
-- Fixed UV mapping for models with type 519 yet again, *NOW* it should be correct (NSMBU's Bowser's pupils were broken previously).
-- Fixed Wind Waker HD models from being accidentally broken *again*.
-- Changed the default UV importing option to "Merge".

-- May 14th, 2017:
-- Added some more adjustments to prevent script conflicts and removed redundancy from UV map importing, courtesy of Sylk.

-- May 12th, 2017:
-- Script has been optimized so that models will import significantly faster, thanks to Sylk!
-- Changed "mat = standardMaterial()" to "local PolyMat = standardMaterial()" to fix potential problems, as suggested by Sylk.
-- Shaved off about a thousand lines of redundant coding since the way vertex buffers are read has now been rewritten.
-- Added an option to print debug information to the Listener, so the separate "_Debug" script is no longer necessary.

-- April 7th, 2017:
-- Fixed UV mapping for models with type 516 (e.g. Dry Bowser's eyes in M&S2014).

-- April 2nd, 2017:
-- Fixed UV mapping for models with type 519 (e.g. Riju's model in BotW). Again.

-- March 11th, 2017:
-- Fixed importing for Wind Waker HD models, which wasn't set up properly in the script in the first place. Whoops!

-- March 6th, 2017:
-- Fixed rigging being utterly broken in 3DS Max 2012 and above (thanks to sunnydavis for part of the code used). Gee, *thanks*, Autodesk...
-- Also fixed rigging for models with more than 4 bone influences (Zelda's model in BotW, for example).
-- Added support for reading normals, thanks to Ploaj for helping with the 10-bit nonsense!
-- Added type 522 for colours (signed bytes, e.g. Fire Peach's dress model in SM3DW).b

-- October 15th, 2016:
-- Added a UI to choose which BFMDL to import in a BFRES, and various little options.
-- LOD (Level of Detail) models can now be imported.
-- Fixed Version 0 BFRES bone structures so they're no longer broken (NSMBU, NintendoLand)
-- Fixed Version 3 BFRES bone structures so they actually load now (Wii Sports Resort)
-- Fixed MatrFlag-related importing so now it won't take AGES to load maps!
-- Fixed texture importing for certain Paper Mario: Color Splash models.
-- Fixed vertex colours which use full floats instead of half floats (LoZWWHD), thanks DSX8!
-- Added UV mapping support for type 516 (bytes), might be incorrect.
-- Not a fix, but UV mapping type 2056 is currently incorrect and will need to be looked into later.
-- Likewise, normals will be looked into for the next update.

rollout BFRESImporter "Wii U / Switch BFRES model importer" width:450 height:300
(
	label lblDisclaimer "This script was written by ItsEasyActually and Random Talking Bush, with some assistance from both Ploaj and Sylk. If you use it, consider giving us all thanks for this. If something doesn't work right, please contact RTB on The VG Resource (Random Talking Bush), Twitter, Tumblr or Steam (RandomTBush) so that any problems can be fixed." \
	pos:[8,8] width:(BFRESImporter.width-16) height:56

	button btnLoad "Load BFRES..." pos:[210,70] width:110 height:20
	button btnImport "Import BFMDL" pos:[330,70] width:110 height:20 enabled:false
	multiListBox lstFMDL pos:[210,95] width:230 height:13 items:#()

	groupBox OptionsBox "Options" pos:[7,66] width:190 height:205
	radiobuttons tglTexFormat "Texture format:" labels:#("DDS","PNG") pos:[18,85] height:10 columns:2 default:2
	radiobuttons tglUVLayers "UV layering:" labels:#("Merge","Split","No") pos:[18,120] height:10 columns:3 default:1
	radiobuttons tglRigModel "Import rigging:" labels:#("Yes","No") pos:[18,155] height:10 columns:2 default:1
	radiobuttons tglLODs "Import LODs:" labels:#("Yes","No") pos:[18,190] height:10 columns:2 default:2
	radiobuttons tglTexPath "Texture path:" labels:#("Absolute","Relative", "Sub") pos:[18,225] height:10 columns:3 default:1

	checkbox tglMatInfo "Print material info?" pos:[8,BFRESImporter.height-20] width:115 checked: true
	checkbox tglDebug "Print debug info?" pos:[158,BFRESImporter.height-20] width:105
	label lblUpdate "(Updated 06/20/2018)" pos:[BFRESImporter.width-115,BFRESImporter.height-19] width:110

	local FMDLOffset_array = #()
	local f = #()
	local p = #()
	local sf = #()

	fn ReadOffset fstream = ((ftell fstream) + (bit.swapBytes (bit.swapBytes (readlong fstream #unsigned) 1 4) 2 3))
	fn readBEshort fstream = (bit.swapBytes (readshort fstream #unsigned) 1 2)
	fn readBElong fstream = (bit.swapBytes (bit.swapBytes (readlong fstream #unsigned) 1 4) 2 3)
	fn readBEfloat fstream = (bit.intAsFloat (bit.swapBytes (bit.swapBytes (readlong fstream #unsigned) 1 4) 2 3))

	fn ReadBEHalfFloat Fstream = (
		local BH  = readByte Fstream #unsigned
		local BL  = readByte Fstream #unsigned
		local N = BH*256 + BL
		local S = floor((mod N 65536) / 32768)
		local Ef = floor((mod N 32768) / 1024)
		local M = mod N 1024
		local ret=case of(
			((Ef==0)AND(M==0)): ( (-1.0)^S * 0.0 )
			((Ef==0)AND(M!=0)): ( (-1.0)^S * 2.0^-14 * (M / 2.0^10) )
			((Ef>0)AND(Ef<31)): ( (-1.0)^S * 2.0^(Ef-15) * (1 + M/2.0^10) )
			((Ef==31)AND(M==0)): ( (-1.0)^S * 1/0.0 )
			((Ef==31)AND(M!=0)): 0 --hack-- should be #inf
		)
	)

	fn ReadHalfFloat Fstream = (
		local BL  = readByte Fstream #unsigned
		local BH  = readByte Fstream #unsigned
		local N = BH*256 + BL
		local S = floor((mod N 65536) / 32768)
		local Ef = floor((mod N 32768) / 1024)
		local M = mod N 1024
		local ret=case of(
			((Ef==0)AND(M==0)): ( (-1.0)^S * 0.0 )
			((Ef==0)AND(M!=0)): ( (-1.0)^S * 2.0^-14 * (M / 2.0^10) )
			((Ef>0)AND(Ef<31)): ( (-1.0)^S * 2.0^(Ef-15) * (1 + M/2.0^10) )
			((Ef==31)AND(M==0)): ( (-1.0)^S * 1/0.0 )
			((Ef==31)AND(M!=0)): 0 --hack-- should be #inf
		)
	)

	fn sign10 x = (
		if (bit.shift x -9) == 1 do(
			x = bit.not x
			x = bit.and x 0x3FF
			x += 1
			x *= -1
		)
		x
	) --Thanks, Ploaj!

	fn ReadFixedString fstream fixedLen = (
		local str = ""
		for i = 1 to fixedLen do str += bit.intAsChar (ReadByte fstream #unsigned)
		str
	)

	fn printDebug pr = (if tglDebug.state do print(pr))
		
	fn vRange Lo Hi val = (
		val=case of(
			(val>Hi):Hi
			(val<Lo):Lo
			default:val
		)
	)

    fn buildMat matName: tSelOff: RtnTexAS: tCount: tFormat: tPath: = (
        local PolyMat
		-- Disabling this as it was causing path/extension changes to not get acknowledged on subsequent loads.
        -- for sm in sceneMaterials where sm.name == matName do PolyMat = sm

        if PolyMat == undefined do(
            PolyMat = standardMaterial name:(matName as string) showInViewport:true twoSided:false
            fseek f tSelOff#seek_set
            printDebug(PolyMat.name + " uses the following textures:")

            local isMatteMat=false
            fn addLayer layer mode ch=(
                ch.mapList[ch.mapList.count+1]=layer
                ch.blendMode[ch.mapList.count]=mode
                ch
            )

			RtnTexAS2 = RtnTexAS

            for t = 1 to tCount do(
                TexSelNameOffset = ReadOffset f
                FTEXPos = ReadOffset f
                RtnTexSel = ftell f

                fseek f TexSelNameOffset#seek_set
                TexSelName = readstring f

                fseek f RtnTexAS#seek_set
                TexAttSelUnk1 = readlong f #unsigned
                TexAttSelUnk2 = readlong f #unsigned
                TexAttSelUnk3 = readlong f #unsigned
                TexAttSelUnk4 = readlong f #unsigned
                TexAttSelNameOff = readOffset f
                TexAttSelNum = readlong f #unsigned
                RtnTexAS = ftell f
                fseek f TexAttSelNameOff#seek_set
                TexAttSelName = readstring f
                fseek f RtnTexSel#seek_set

                if tglDebug.state do(
					Finishing=case TexAttSelUnk2 of(
					    3328: "Glossy"
					    3580: "Matte"
					    default: TexAttSelUnk2
					)
					format"#%: %, %, Unk1= 0x%, Finishing=%, Unk3=0x%, Unk4=%\n" TexAttSelNum TexSelName TexAttSelName (bit.intAsHex TexAttSelUnk1) Finishing (bit.intAsHex TexAttSelUnk3) TexAttSelUnk4
                )

				local tm=stringstream""
				format"%%%" tPath TexSelName tFormat to:tm
				tm = bitmapTexture fileName:(tm as string)

				case TexAttSelName of (
					"_a0":(        -- Diffuse Map --
					    tm.alphaSource = 0
					    tm.monoOutput = 1
					    PolyMat.diffuseMap = PolyMat.opacityMap = tm
					    isMatteMat = (TexAttSelUnk2==3580)
					)
				)
            if isMatteMat do PolyMat.specularMap = PolyMat.diffuseMap
            )

			RtnTexAS = RtnTexAS2
			-- Need to do a two-pass to fix script erroring when it tries to add an emissive / albedo #1 before albedo #0 is applied.
			fseek f tSelOff#seek_set
            for t = 1 to tCount do(
                TexSelNameOffset = ReadOffset f
                FTEXPos = ReadOffset f
                RtnTexSel = ftell f

                fseek f TexSelNameOffset#seek_set
                TexSelName = readstring f

                fseek f RtnTexAS#seek_set
                TexAttSelUnk1 = readlong f #unsigned
                TexAttSelUnk2 = readlong f #unsigned
                TexAttSelUnk3 = readlong f #unsigned
                TexAttSelUnk4 = readlong f #unsigned
                TexAttSelNameOff = readOffset f
                TexAttSelNum = readlong f #unsigned
                RtnTexAS = ftell f
                fseek f TexAttSelNameOff#seek_set
                TexAttSelName = readstring f
                fseek f RtnTexSel#seek_set

				local tm=stringstream""
				format"%%%" tPath TexSelName tFormat to:tm
				tm = bitmapTexture fileName:(tm as string)

				case TexAttSelName of (
					-- _a = Albedo Map
					-- _ao = Ambient Occlusion Map
					-- _b = Bake Map
					-- _cc = "2CL" Map
					-- _e = Emissive Map
					-- _em = Emissive Mask Map
					-- _g = Secondary Bake Map?
					-- _l = Light Map
					-- _n = Normal Map / (Bump Map?)
					-- _p = Paper Map
					-- _r = Reflection Map
					-- _rn = Roughness Map
					-- _rt = Phong Warp Map?
					-- _s = Specular Map
					-- _sd = Shadow Map
					-- _t = "TRM" Map
					-- _tc = Team Color Map
					-- _x = Reflection Map
					-- sampler = temporary map copy? (eg. occurs with "npc_zelda_miko_body_damage_alb" map)
					
					-- TexAttSelUnk2 --
					-- d00 / 3328 = Standard/Glossy ?
					-- dfc / 3580 = Matte ? (specular color = diffuse)

					default:(printDebug(TexAttSelName + " not applied!"))
					"sampler0":()
					"_a0":()        -- Diffuse Map --
-- 					"_a0":(        -- Diffuse Map --
-- 					    tm.alphaSource = 0
-- 					    tm.monoOutput = 1
-- 					    PolyMat.diffuseMap = PolyMat.opacityMap = tm
-- 					    isMatteMat = (TexAttSelUnk2==3580)
-- 					)
					"_ao0":(        -- Ambient Occlusion Map --
					    tm = Color_Correction Map:tm rewireMode:1 rewireR:0 saturation:-100
					    ch = PolyMat.diffuseMap
					    if classOf ch == bitmapTexture do ch = compositeTextureMap mapList:#(ch)
					    PolyMat.diffuseMap = addLayer tm 5 ch
					)
					"_sd0":(        --Shadow Map --
					    ch = PolyMat.diffuseMap
					    if classOf ch == bitmapTexture do ch = compositeTextureMap mapList:#(ch)
					    PolyMat.diffuseMap = addLayer tm 5 ch
					)
					-- Disabling for now since it's causing diffuse-less textures to error..
-- 					"_e0":(        -- Emissive Map --
-- 					    ch = PolyMat.diffuseMap
-- 					    if classOf ch == bitmapTexture do ch = compositeTextureMap mapList:#(ch)
-- 					    PolyMat.diffuseMap = addLayer tm 5 ch
-- 					)
					"_em0":(        -- Emissive Mask Map --
					    PolyMat.selfillumMap = tm
					)
					"_n0":(
					    PolyMat.bumpMap = Normal_Bump normal_map:tm
					)
					"_s0":(        -- Specular Map --
					    PolyMat.specularLevelMap = tm
					)
					"_r0":(
					    tm.alphaSource = 0
					    PolyMat.glossinessMap = tm
					)
					"_rn0":(PolyMat.glossinessMap = tm)
					"_x0":(
					    tm.alphaSource = 0
					    PolyMat.reflectionMap = tm
					)
					"_b0":(printDebug(TexAttSelName + " (Bake Map) not applied!"))
					"_g0":(printDebug(TexAttSelName + " (Alt. Bake? Map) not applied!"))
					"_l0":(printDebug(TexAttSelName + " (Light Map) not applied!"))
					"_p0":(printDebug(TexAttSelName + " (Paper Map) not applied!"))
					"_rt0":(printDebug(TexAttSelName + " (Phong Warp? Map) not applied!"))
					"_t0":(printDebug(TexAttSelName + " (TRM? Map) not applied!"))
					"_tc0":(printDebug(TexAttSelName + " (Team Color Map) not applied!"))
                )

            )

        )
        PolyMat
    )

    fn buildMatSwitch matName: tSelOff: RtnTexAS: tCount: tFormat: tPath: = (
        local PolyMat
		-- Disabling this as it was causing path/extension changes to not get acknowledged on subsequent loads.
        -- for sm in sceneMaterials where sm.name == matName do PolyMat = sm

        if PolyMat == undefined do(
            PolyMat = standardMaterial name:(matName as string) showInViewport:true twoSided:false
            fseek f tSelOff#seek_set
            printDebug(PolyMat.name + " uses the following textures:")

            local isMatteMat=false
            fn addLayer layer mode ch=(
                ch.mapList[ch.mapList.count+1]=layer
                ch.blendMode[ch.mapList.count]=mode
                ch
            )

			RtnTexAS = RtnTexAS + 24
			RtnTexAS2 = RtnTexAS
            for t = 1 to tCount do(
                TexSelNameOffset = ReadLong f
				fseek f 4#seek_cur
                RtnTexSel = ftell f

                fseek f TexSelNameOffset#seek_set
				fseek f 2#seek_cur
                TexSelName = readstring f

                fseek f RtnTexAS#seek_set
                TexAttSelUnk1 = readshort f #unsigned
                TexAttSelUnk2 = readshort f #unsigned
                TexAttSelUnk3 = readshort f #unsigned
                TexAttSelUnk4 = readshort f #unsigned
                TexAttSelNameOff = ReadLong f
				fseek f 4#seek_cur
                TexAttSelNum = t
                RtnTexAS = ftell f
                fseek f TexAttSelNameOff#seek_set
				fseek f 2#seek_cur
                TexAttSelName = readstring f
                fseek f RtnTexSel#seek_set

                if tglDebug.state do(
					Finishing=case TexAttSelUnk2 of(
					    3328: "Glossy"
					    3580: "Matte"
					    default: TexAttSelUnk2
					)
					format"#%: %, %, Unk1= 0x%, Unk2=%, Unk3=0x%, Unk4=%\n" TexAttSelNum TexSelName TexAttSelName (bit.intAsHex TexAttSelUnk1) Finishing (bit.intAsHex TexAttSelUnk3) TexAttSelUnk4
                )

                local tm=stringstream""
                format"%%%" tPath TexSelName tFormat to:tm
                tm = bitmapTexture fileName:(tm as string)

                case TexAttSelName of (
					"_a0":(        -- Diffuse Map --
					    tm.alphaSource = 0
					    tm.monoOutput = 1
					    PolyMat.diffuseMap = PolyMat.opacityMap = tm
					    isMatteMat = (TexAttSelUnk2==3580)
					)
                )
            )
            if isMatteMat do PolyMat.specularMap = PolyMat.diffuseMap
			
			RtnTexAS = RtnTexAS2
			-- Need to do a two-pass to fix script erroring when it tries to add an emissive / albedo #1 before albedo #0 is applied.
			fseek f tSelOff#seek_set
			for t = 1 to tCount do(
                TexSelNameOffset = ReadLong f
				fseek f 4#seek_cur
                RtnTexSel = ftell f

                fseek f TexSelNameOffset#seek_set
				fseek f 2#seek_cur
                TexSelName = readstring f

                fseek f RtnTexAS#seek_set
                TexAttSelUnk1 = readshort f #unsigned
                TexAttSelUnk2 = readshort f #unsigned
                TexAttSelUnk3 = readshort f #unsigned
                TexAttSelUnk4 = readshort f #unsigned
                TexAttSelNameOff = ReadLong f
				fseek f 4#seek_cur
                TexAttSelNum = t
                RtnTexAS = ftell f
                fseek f TexAttSelNameOff#seek_set
				fseek f 2#seek_cur
                TexAttSelName = readstring f
                fseek f RtnTexSel#seek_set

                local tm=stringstream""
                format"%%%" tPath TexSelName tFormat to:tm
                tm = bitmapTexture fileName:(tm as string)

                case TexAttSelName of (
					-- _a = Albedo Map
					-- _ao = Ambient Occlusion Map
					-- _b = Bake Map
					-- _cc = "2CL" Map
					-- _e = Emissive Map
					-- _em = Emissive Mask Map
					-- _g = Secondary Bake Map?
					-- _i = Indirect Map?
					-- _l = Light Map
					-- _n = Normal Map / (Bump Map?)
					-- _o = Occlusion Map
					-- _p = Paper Map
					-- _r = Reflection or Roughness Map
					-- _rn = Roughness Map
					-- _rt = Phong Warp Map?
					-- _s = Specular Map
					-- sp = Specular Map
					-- _sd = Shadow Map
					-- _t = "TRM" Map
					-- _tc = Team Color Map
					-- _x = Reflection Map
					-- sampler = temporary map copy? (eg. occurs with "npc_zelda_miko_body_damage_alb" map)

					default:(printDebug(TexAttSelName + " not applied!"))
					"sampler0":()
					"_a0":()        -- Diffuse Map --
-- 					"_a0":(        -- Diffuse Map --
-- 					    tm.alphaSource = 0
-- 					    tm.monoOutput = 1
-- 					    PolyMat.diffuseMap = PolyMat.opacityMap = tm
-- 					    isMatteMat = (TexAttSelUnk2==3580)
-- 					)
					"_ao0":(        -- Ambient Occlusion Map --
					     tm = Color_Correction Map:tm rewireMode:1 rewireR:0 saturation:-100
					     ch = PolyMat.diffuseMap
					     if classOf ch == bitmapTexture do ch = compositeTextureMap mapList:#(ch)
					     PolyMat.diffuseMap = addLayer tm 5 ch
					)
					"_sd0":(        --Shadow Map --
					    ch = PolyMat.diffuseMap
					    if classOf ch == bitmapTexture do ch = compositeTextureMap mapList:#(ch)
					    PolyMat.diffuseMap = addLayer tm 5 ch
					)
					-- Disabling for now since it's causing diffuse-less textures to error..
-- 					"_e0":(        -- Emissive Map --
-- 					    ch = PolyMat.diffuseMap
-- 					    if classOf ch == bitmapTexture do ch = compositeTextureMap mapList:#(ch)
-- 					    PolyMat.diffuseMap = addLayer tm 5 ch
-- 					)
					"_em0":(        -- Emissive Mask Map --
					    PolyMat.selfillumMap = tm
					)
					"_n0":(
					    PolyMat.bumpMap = Normal_Bump normal_map:tm
					)
					"_s0":(        -- Specular Map --
					    PolyMat.specularLevelMap = tm
					)
					"_r0":(
					    tm.alphaSource = 0
					    PolyMat.glossinessMap = tm
					)
					"_rn0":(PolyMat.glossinessMap = tm)
					"_x0":(
					    tm.alphaSource = 0
					    PolyMat.reflectionMap = tm
					)
					"_b0":(printDebug(TexAttSelName + " (Bake Map) not applied!"))
					"_g0":(printDebug(TexAttSelName + " (Alt. Bake? Map) not applied!"))
					"_l0":(printDebug(TexAttSelName + " (Light Map) not applied!"))
					"_p0":(printDebug(TexAttSelName + " (Paper Map) not applied!"))
					"_rt0":(printDebug(TexAttSelName + " (Phong Warp? Map) not applied!"))
					"_t0":(printDebug(TexAttSelName + " (TRM? Map) not applied!"))
					"_tc0":(printDebug(TexAttSelName + " (Team Color Map) not applied!"))
                )
            )
        )
        PolyMat
    )

	on btnLoad pressed do(
		clearListener()
		--fname = GetOpenFileName caption:"Open BFRES" types:"BFRES File(*.bfres)|*.bfres"
		fname = (USER_WORKSPACE_PATH + "model.bfres")

		if fname != undefined do(
			fclose f
			FMDLName_array = #()
			FMDLOffset_array = #()

			p = getFilenamePath fname
			sf = (getFilenamePath fname) + (getFilenameFile fname) + "/"
			f = fopen fname "rb"   --open file in read only format

			fseek f 0x04 #seek_set
			SwitchCheck = readlong f #unsigned
			fseek f 0x00 #seek_set

			if SwitchCheck != 0x20202020 then(
			struct fmdlh(
				fmdl,				-- Magic
				fnameOff,		-- Filename Offset
				eofString,		-- End of File String Offset
				fsklOff,			-- FSKL Offset
				fvtxArrOff,		-- FVTX Array Offset
				fshpIndx,		-- FSHP Index Offset
				fmatIndx,		-- FMAT Index Offset
				paramOff,		-- Parameter Offset
				fvtxCount,		-- FVTX Count (int16)
				fshpCount,		-- FSHP Count (int16)
				fmatCount,		-- FMAT Count (int16
				paramCount	-- Parameter Count (int16)
			)

			fseek f 4#seek_set
			verNumA = ReadByte f
			verNumB = ReadByte f
			verNumC = ReadByte f
			verNumD = ReadByte f
			print ("FRES Version: " + verNumA as string + "." + verNumB as string + "." + verNumC as string + "." + verNumD as string)
			fseek f 0x20#seek_set
			FileOffset = ReadOffset f
			fseek f FileOffset#seek_set
			BlockSize = ReadBELong f
			FMDLTotal = ReadBELong f
			fseek f 0x10#seek_cur

			try(
				For mdl = 1 to FMDLTotal Do(
					fseek f 12#seek_cur
					FMDLOffset = ReadOffset f
					append FMDLOffset_array FMDLOffset
					NextFMDL = ftell f

					fseek f FMDLOffset#seek_set

					-- F_Model Header --
					fmdl_info=(fmdlh \
						fmdl: (ReadFixedString f 4) \
						fnameOff: (ReadOffset f) \
						eofString: (ReadOffset f) \
						fsklOff: (ReadOffset f) \
						fvtxArrOff: (ReadOffset f) \
						fshpIndx: (ReadOffset f) \
						fmatIndx: (ReadOffset f) \
						paramOff: (ReadOffset f) \
						fvtxCount: (ReadBEShort f) \
						fshpCount: (ReadBEShort f) \
						fmatCount: (ReadBEShort f) \
						paramCount: (ReadBEShort f) \
					)

					fseek f fmdl_info.fnameOff#seek_set
					FMDLName = ReadString f
					append FMDLName_array FMDLName
					fseek f NextFMDL#seek_set
				)
			
				if FMDLName_array!=0 then(
					lstFMDL.items = FMDLName_array
					lstFMDL.selection = 1
					btnImport.enabled = true
				)else(
					btnImport.enabled = false
				)
			)catch(
				lstFMDL.items = #()
				btnImport.enabled = false
				messageBox ("Invalid file content. No model was found in: \n\""+ fname +"\"") title:"BFRES loading failed"
				btnLoad.pressed()
			)
			) else (
			struct fmdlh(
				fmdl,				-- Magic
				headerLength1,    -- FMDL header length (1)
				headerLength2,    -- FMDL header length (2)
				fnameOff,		-- Filename Offset
				eofString,		-- End of File String Offset
				fsklOff,			-- FSKL Offset
				fvtxArrOff,		-- FVTX Array Offset
				fshpIndx,		-- FSHP Index Offset
				fshpSubIndx,   -- FSHP Secondary Index Offset
				fmatOff,		-- FMAT Offset
				fmatIndx,   -- FMAT Index Offset
				paramOff,		-- Parameter Offset
				fvtxCount,		-- FVTX Count (int16)
				fshpCount,		-- FSHP Count (int16)
				fmatCount,		-- FMAT Count (int16)
				paramCount,	-- Parameter Count (int16)
				fmdlUnk3,	    -- Unknown Offset
				padding           -- Always 0
			)

			fseek f 0x08 #seek_set
			verNumD = ReadByte f
			verNumC = ReadByte f
			verNumB = ReadByte f
			verNumA = ReadByte f
			print ("FRES Version: " + verNumA as string + "." + verNumB as string + "." + verNumC as string + "." + verNumD as string)
			fseek f 0x28 #seek_set
			FMDLOffset = ReadLong f
			fseek f 0xBC #seek_set
			FMDLTotal = ReadShort f #unsigned
			fseek f FMDLOffset #seek_set

			try(
				For mdl = 1 to FMDLTotal Do(
					FMDLOffset = (ftell f)
					append FMDLOffset_array FMDLOffset

					-- F_Model Header --
					fmdl_info=(fmdlh \
							fmdl: (ReadFixedString f 4) \
							headerLength1: (ReadLong f) \
							headerLength2: (ReadLong f) \
							padding: (ReadLong f) \
							fnameOff: (ReadLong f) \
							padding: (ReadLong f) \
							eofString: (ReadLong f) \
							padding: (ReadLong f) \
							fsklOff: (ReadLong f) \
							padding: (ReadLong f) \
							fvtxArrOff: (ReadLong f) \
							padding: (ReadLong f) \
							fshpIndx: (ReadLong f) \
							padding: (ReadLong f) \
							fshpSubIndx: (ReadLong f) \
							padding: (ReadLong f) \
							fmatOff: (ReadLong f) \
							padding: (ReadLong f) \
							fmatIndx: (ReadLong f) \
							padding: (ReadLong f) \
							paramOff: (ReadLong f) \
							padding: (ReadLong f) \
							padding: (ReadLong f) \
							padding: (ReadLong f) \
							padding: (ReadLong f) \
							padding: (ReadLong f) \
							fvtxCount: (ReadShort f) \
							fshpCount: (ReadShort f) \
							fmatCount: (ReadShort f) \
							paramCount: (ReadShort f) \
							fmdlUnk3: (ReadLong f) \
							padding: (ReadLong f) \
					)

					NextFMDL = ftell f
					fseek f fmdl_info.fnameOff#seek_set
					fseek f 0x02 #seek_cur
					FMDLName = ReadString f
					append FMDLName_array FMDLName
					fseek f NextFMDL#seek_set
				)
			
				if FMDLName_array!=0 then(
					lstFMDL.items = FMDLName_array
					lstFMDL.selection = 1
					btnImport.enabled = true
				)else(
					btnImport.enabled = false
				)
			)catch(
				lstFMDL.items = #()
				btnImport.enabled = false
				messageBox ("Invalid file content. No model was found in: \n\""+ fname +"\"") title:"BFRES loading failed"
				btnLoad.pressed()
			)
			)
		)
	)

	on btnImport pressed do(
		For currentExtractedModelIndex = 1 to lstFMDL.items.count do (
		--if lstFMDL.selection != 0 do(
		if currentExtractedModelIndex != 0 do (
			clearListener()
			disableSceneRedraw()
			st = timestamp() --get start time in milliseconds

			local TexFormat = tglTexFormat.state
			local TexPath = tglTexPath.state
			local UVLayers = tglUVLayers.state
			local RigModel = tglRigModel.state
			local LODs = tglLODs.state
			local TexF = #(".dds",".png")
			local TexP = #(p,"",sf)
			local MatInfo = tglMatInfo.state

			fseek f 0x04 #seek_set
			SwitchCheck = readlong f #unsigned
			fseek f 0x00 #seek_set

		if SwitchCheck != 0x20202020 then(
			struct fmdlh(
				fmdl,				-- Magic
				fnameOff,		-- Filename Offset
				eofString,		-- End of File String Offset
				fsklOff,			-- FSKL Offset
				fvtxArrOff,		-- FVTX Array Offset
				fshpIndx,		-- FSHP Index Offset
				fmatIndx,		-- FMAT Index Offset
				paramOff,		-- Parameter Offset
				fvtxCount,		-- FVTX Count (int16)
				fshpCount,		-- FSHP Count (int16)
				fmatCount,		-- FMAT Count (int16
				paramCount	-- Parameter Count (int16)
			)

			struct fvtxh(
				fvtx,				-- Magic
				attCount,		-- Attribute Count (int8)
				buffCount,		-- Buffer Count (int8)
				sectIndx,		-- Section Index (int16)
				vertCount,		-- Vertex Count
				u1,					-- Unknown (int8 or int16)
				u2,					-- Unknown (int16 or three bytes)
				attArrOff,		-- Attribute Array Offset
				attIndxOff,		-- Attribute Index Offset
				buffArrOff,		-- Buffer Array Offset
				padding			-- Padding (int32)
			)

			struct fmath(
				fmat,							-- Magic
				matOff,						-- Material Name Offset
				u1,								-- Unknown (int32)
				sectIndx,					-- Section Index (int16)
				rendParamCount,		-- Render Info Parameter Count (int16)
				texSelCount,				-- Texture Selector Count (int8)
				texAttSelCount,			-- Texture Attribute Selector Count (int8)
				matParamCount,		-- Material Parameter Count (int16)
				matParamSize,			-- Material Parameter Data Size
				u2,								-- Unknown (int32)
				rendParamIndx,			-- Render Info Parameter Index Group Offset
				unkMatOff,					-- Unknown Material Offset
				shadeOff,					-- Shader Control Offset
				texSelOff,					-- Texture Selector Offset
				texAttSelOff,				-- Texture Attribute Selector Offset
				texAttIndxOff,			-- Texture Attribute Selector Index Offset
				matParamArrOff,		-- Material Parameter Array Offset
				matParamIndxOff,		-- Material Parameter Index Offset
				matParamOff,				-- Material Parameter Data Offset
				shadParamIndxOff	-- Shadow Parameter Index Offset
			)

			struct fsklh(
				fskl,							-- Magic
				u1,							-- Unknown (int16)
				fsklType,				-- Type of Bone Data (uint16)
				boneArrCount,		-- Bone Array Count (int16)
				invIndxArrCount,	-- Inverse Index Array Count (int16)
				exIndxCount,			-- Extra Index Count (int16)
				u3,							-- Unknown (int16)
				boneIndxOff,			-- Bone Index Group Offset
				boneArrOff,			-- Bone Array Offset
				invIndxArrOff,		-- Inverse Index Array Offset
				invMatrArrOff,		-- Inverse Matric Array Offset
				padding					-- Padding (int32)
			)

			struct fshph(
				fshp,						-- Magic
				polyNameOff,			-- Polygon Name Offset
				u1,							-- Unknown (int32)
				fvtxIndx,					-- FVTX Index (int16)
				fmatIndx,				-- FMAT Index (int16)
				fsklIndx,					-- FSKL Index (int16)
				sectIndx,				-- Section Index (int16)
				fsklIndxArrCount,	-- FSKL Index Array Count (int16)
				matrFlag,				-- Matrix Use Flag (int8)
				lodMdlCount,			-- LoD Model Count (int8)
				visGrpCount,			-- Visibility Group Tree Node Count
				u3,							-- Unknown (float)
				fvtxOff,					-- FVTX Offset
				lodMdlOff,				-- LoD Model Offset
				fsklIndxArrOff,		-- FSKL Index Array Offset
				u4,							-- Unknown (int32)
				visGrpNodeOff,		-- Vibility Group Tree Nodes Offset
				visGrpRangeOff,	-- Visibility Group Tree Ranges Offset
				visGrpIndxOff,		-- Visibility Group Tree Indices Offset
				u5							-- Unknown (int32)
			)

			struct attdata(
				attName,	-- Attribute Type
				buffIndx,		-- Buffer Index (u8)
				buffOff,		-- Buffer Offset (u16)
				vertType		-- Format
			)

			struct buffData(
				buffSize,		-- Size of Buffer (u32)
				strideSize,	-- Size of Vertex Stride (u16)
				dataOffset	-- Offset to Buffer (u32)
			)

			struct bdata(
				bNameOff,		-- Bone Name Offset
				bIndx,				-- Bone Index (int16)
				parIndx1,		-- Parent Index 1 (int16)
				parIndx2,		-- Parent Index 2 (int16)
				parIndx3,		-- Parent Index 3 (int16)
				parIndx4,		-- Parent Index 4 (int16)
				u1,					-- Unknown (int16)
				bFlags,			-- Bone Flags (int16)
				u2,					-- Unknown (int16)
				scaleX,			-- Scale X
				scaleY,			-- Scale Y
				scaleZ,			-- Scale Z
				rotX,				-- Rotation X
				rotY,				-- Rotation Y
				rotZ,				-- Rotation Z
				rotW,				-- Rotation W
				posX,				-- Position X
				posY,				-- Position Y
				posZ,				-- Position Z
				padding,			-- Padding
				m11,				-- Matrix 
				m21,				-- Matrix 
				m31,				-- Matrix 
				m41,				-- Matrix 
				m12,				-- Matrix 
				m22,				-- Matrix 
				m32,				-- Matrix 
				m42,				-- Matrix 
				m13,				-- Matrix 
				m23,				-- Matrix 
				m33,				-- Matrix 
				m43				-- Matrix 
			)

			struct lodmdl(
				u1,					-- Unknown (int32)
				faceType,		-- Face Data Type (int32)
				dCount,			-- Visibility Group Draw Count
				visGrpCount,	-- Visibility Group Count (int16)
				u3,					-- Unknown (int16)
				visGrpOff,		-- Visibility Group Offset
				indxBuffOff,	-- Index Buffer Offset
				elmSkip			-- Element Skip (int32)
			)

			struct Bone_Info_Struct(
				bone1, bone2, bone3, bone4
			)

			struct Weight_Info_Struct(
				weight1, weight2, weight3, weight4
			)

			struct weight_data(
				boneids, weights
			)

			struct invMatrix(
				invIndx, invMatr
			)

			fseek f 4#seek_set
			verNumA = ReadByte f
			verNumB = ReadByte f
			verNumC = ReadByte f
			verNumD = ReadByte f
			FMDLList_array = lstFMDL.selection as array

			for x = 1 to FMDLList_array.count do(
				fseek f FMDLOffset_array[FMDLList_array[x]]#seek_set

				FMDLArr = #()
				FVTXArr = #()
				FSKLArr = #()
				FMATArr = #()
				FMATNameArr = #()
				FSHPArr = #()
				VTXAttr = #()

				BoneArray = #()
				BoneFixArray = #()
				invIndxArr = #()
				invMatrArr = #()
				Node_Array = #()

				-- F_Model Header --
				fmdl_info=(fmdlh \
					fmdl: (ReadFixedString f 4) \
					fnameOff: (ReadOffset f) \
					eofString: (ReadOffset f) \
					fsklOff: (ReadOffset f) \
					fvtxArrOff: (ReadOffset f) \
					fshpIndx: (ReadOffset f) \
					fmatIndx: (ReadOffset f) \
					paramOff: (ReadOffset f) \
					fvtxCount: (ReadBEShort f) \
					fshpCount: (ReadBEShort f) \
					fmatCount: (ReadBEShort f) \
					paramCount: (ReadBEShort f) \
				)
				append FMDLArr(fmdl_info)
				printDebug fmdl_info

				-- F_Vertex Header --
				fseek f fmdl_info.fvtxArrOff#seek_set
				For vtx = 1 to fmdl_info.fvtxCount Do(
					fvtx_info=(fvtxh \
						fvtx: (ReadFixedString f 4) \
						attCount: (ReadByte f) \
						buffCount: (ReadByte f) \
						sectIndx: (ReadBEshort f) \
						vertCount: (ReadBELong f) \
						u1: (ReadBEShort f) \
						u2: (ReadBEShort f) \
						attArrOff: (ReadOffset f) \
						attIndxOff: (ReadOffset f) \
						buffArrOff: (ReadOffset f) \
						padding: (ReadLong f) \
					)
					append FVTXArr(fvtx_info)
					printDebug fvtx_info
				)

				-- F_Material Header --
				fseek f fmdl_info.fmatIndx#seek_set
				fseek f 24#seek_cur

				For mat = 1 to fmdl_info.fmatCount Do(
					fseek f 8#seek_cur
					FMATNameOffset = ReadOffset f
					Rtn = ftell f
					fseek f FMATNameOffset#seek_set

					FMATName = readstring f
					append FMATNameArr FMATName
					fseek f Rtn#seek_set

					FMATOffset = ReadOffset f
					Rtn = ftell f

					fseek f FMATOffset#seek_set
					fmat_info=(fmath \
						fmat: (ReadFixedString f 4) \
						matOff: (ReadOffset f) \
						u1: (ReadBELong f) \
						sectIndx: (ReadBEShort f) \
						rendParamCount: (ReadBEshort f) \
						texSelCount: (ReadByte f) \
						texAttSelCount: (ReadByte f) \
						matParamCount: (ReadBEShort f) \
						matParamSize: (ReadBELong f) \
						u2: (ReadBELong f) \
						rendParamIndx: (ReadOffset f) \
						unkMatOff: (ReadOffset f) \
						shadeOff: (ReadOffset f) \
						texSelOff: (ReadOffset f) \
						texAttSelOff: (ReadOffset f) \
						texAttIndxOff: (ReadOffset f) \
						matParamArrOff: (ReadOffset f) \
						matParamIndxOff: (ReadOffset f) \
						matParamOff: (ReadOffset f) \
						shadParamIndxOff: (ReadOffset f) \
					)
					append FMATArr(fmat_info)
					printDebug fmat_info

					if MatInfo == true do(
						fseek f FMATArr[mat].matParamArrOff #seek_set
						print "--------------------"
						print ("Texture properties for " + FMATName + ":")
						print "--------------------"
						for m = 1 to FMATArr[mat].matParamCount do(
							matParamFlag = readbyte f
							matParamSize = readbyte f
							matParamStart = readBEshort f
							matParamUnk = readBElong f
							if verNumB >= 3 do(
								blank = readBElong f
								matParamIndex1 = readBEshort f
								matParamIndex2 = readBEshort f
								if verNumB == 3 do(matFMATOff = ReadOffset f)
							)
							matStringOff = ReadOffset f

							RtnMat = ftell f
							fseek f matStringOff #seek_set
							
							matParamString = ReadString f
							fseek f (FMATArr[mat].matParamOff + matParamStart) #seek_set
							
							-- Thanks, Tockdom!
							case matParamFlag of (
								default: (throw("Unknown param type!"))
								0x00: (matParamVar1 = readBElong f
										case matParamVar1 of (
											0: (matParamVar1 = "False")
											1: (matParamVar1 = "True")
										)
									print (matParamString as string + ": " + matParamVar1 as string)
									) -- 1 boolean
								0x01: (matParamVar1 = readBElong f; matParamVar2 = readBElong f
										case matParamVar1 of (
											0: (matParamVar1 = "False")
											1: (matParamVar1 = "True")
										)
										case matParamVar2 of (
											0: (matParamVar2 = "False")
											1: (matParamVar2 = "True")
										)
									print (matParamString as string + ": " + matParamVar1 as string + ", " + matParamVar2 as string)
									) -- 2 booleans
								0x02: (matParamVar1 = readBElong f; matParamVar2 = readBElong f; matParamVar3 = readBElong f
										case matParamVar1 of (
											0: (matParamVar1 = "False")
											1: (matParamVar1 = "True")
										)
										case matParamVar2 of (
											0: (matParamVar2 = "False")
											1: (matParamVar2 = "True")
										)
										case matParamVar3 of (
											0: (matParamVar3 = "False")
											1: (matParamVar3 = "True")
										)
									print (matParamString as string + ": " + matParamVar1 as string + ", " + matParamVar2 as string + ", " + matParamVar3 as string)
									) -- 3 booleans
								0x03: (matParamVar1 = readBElong f; matParamVar2 = readBElong f; matParamVar3 = readBElong f; matParamVar4 = readBElong f
										case matParamVar1 of (
											0: (matParamVar1 = "False")
											1: (matParamVar1 = "True")
										)
										case matParamVar2 of (
											0: (matParamVar2 = "False")
											1: (matParamVar2 = "True")
										)
										case matParamVar3 of (
											0: (matParamVar3 = "False")
											1: (matParamVar3 = "True")
										)
										case matParamVar4 of (
											0: (matParamVar4 = "False")
											1: (matParamVar4 = "True")
										)
									print (matParamString as string + ": " + matParamVar1 as string + ", " + matParamVar2 as string + ", " + matParamVar3 as string + ", " + matParamVar4 as string)
									) -- 4 booleans
								0x04: (matParamVar1 = readBElong f
									print (matParamString as string + ": " + matParamVar1 as string)
									) -- 1 signed integer
								0x05: (matParamVar1 = readBElong f; matParamVar2 = readBElong f
									print (matParamString as string + ": " + matParamVar1 as string + ", " + matParamVar2 as string)
									) -- 2 signed integers
								0x06: (matParamVar1 = readBElong f; matParamVar2 = readBElong f; matParamVar3 = readBElong f
									print (matParamString as string + ": " + matParamVar1 as string + ", " + matParamVar2 as string + ", " + matParamVar3 as string)
									) -- 3 signed integers
								0x07: (matParamVar1 = readBElong f; matParamVar2 = readBElong f; matParamVar3 = readBElong f; matParamVar4 = readBElong f
									print (matParamString as string + ": " + matParamVar1 as string + ", " + matParamVar2 as string + ", " + matParamVar3 as string + ", " + matParamVar4 as string)
									) -- 4 signed integers
								0x08: (matParamVar1 = readBElong f
									print (matParamString as string + ": " + matParamVar1 as string)
									) -- 1 unsigned integer
								0x09: (matParamVar1 = readBElong f; matParamVar2 = readBElong f
									print (matParamString as string + ": " + matParamVar1 as string + ", " + matParamVar2 as string)
									) -- 2 unsigned integers
								0x0A: (matParamVar1 = readBElong f; matParamVar2 = readBElong f; matParamVar3 = readBElong f
									print (matParamString as string + ": " + matParamVar1 as string + ", " + matParamVar2 as string + ", " + matParamVar3 as string)
									) -- 3 unsigned integers
								0x0B: (matParamVar1 = readBElong f; matParamVar2 = readBElong f; matParamVar3 = readBElong f; matParamVar4 = readBElong f
									print (matParamString as string + ": " + matParamVar1 as string + ", " + matParamVar2 as string + ", " + matParamVar3 as string + ", " + matParamVar4 as string)
									) -- 4 unsigned integers
								0x0C: (matParamVar1 = readBEfloat f
									print (matParamString as string + ": " + matParamVar1 as string)
									) -- 1x1 floats
								0x0D: (matParamVar1 = readBEfloat f; matParamVar2 = readBEfloat f
									print (matParamString as string + ": " + matParamVar1 as string + ", " + matParamVar2 as string)
									) -- 1x2 floats
								0x0E: (matParamVar1 = readBEfloat f; matParamVar2 = readBEfloat f; matParamVar3 = readBEfloat f
									print (matParamString as string + ": " + matParamVar1 as string + ", " + matParamVar2 as string + ", " + matParamVar3 as string)
									) -- 1x3 floats
								0x0F: (matParamVar1 = readBEfloat f; matParamVar2 = readBEfloat f; matParamVar3 = readBEfloat f; matParamVar4 = readBEfloat f
									print (matParamString as string + ": " + matParamVar1 as string + ", " + matParamVar2 as string + ", " + matParamVar3 as string + ", " + matParamVar4 as string)
									) -- 1x4 floats
								0x10: (matParamVarA1 = readBEfloat f; matParamVarA2 = readBEfloat f
									print (matParamString as string + ": " + matParamVarA1 as string + ", " + matParamVarA2 as string)
									) -- 2x1 floats
								0x11: (matParamVarA1 = readBEfloat f; matParamVarA2 = readBEfloat f
									matParamVarB1 = readBEfloat f; matParamVarB2 = readBEfloat f
									print (matParamString as string + ": " + matParamVarA1 as string + ", " + matParamVarA2 as string + " | " + matParamVarB1 as string + ", " + matParamVarB2 as string)
									) -- 2x2 floats
								0x12: (matParamVarA1 = readBEfloat f; matParamVarA2 = readBEfloat f
									matParamVarB1 = readBEfloat f; matParamVarB2 = readBEfloat f
									matParamVarC1 = readBEfloat f; matParamVarC2 = readBEfloat f
									print (matParamString as string + ": " + matParamVarA1 as string + ", " + matParamVarA2 as string + " | " + matParamVarB1 as string + ", " + matParamVarB2 as string + " | " + matParamVarC1 as string + ", " + matParamVarC2 as string)
									) -- 2x3 floats
								0x13: (matParamVarA1 = readBEfloat f; matParamVarA2 = readBEfloat f
									matParamVarB1 = readBEfloat f; matParamVarB2 = readBEfloat f
									matParamVarC1 = readBEfloat f; matParamVarC2 = readBEfloat f
									matParamVarD1 = readBEfloat f; matParamVarD2 = readBEfloat f
									print (matParamString as string + ": " + matParamVarA1 as string + ", " + matParamVarA2 as string + " | " + matParamVarB1 as string + ", " + matParamVarB2 as string + " | " + matParamVarC1 as string + ", " + matParamVarC2 as string + " | " + matParamVarD1 as string + ", " + matParamVarD2 as string)
									) -- 2x4 floats
								0x14: (matParamVarA1 = readBEfloat f; matParamVarA2 = readBEfloat f; matParamVarA3 = readBEfloat f
									print (matParamString as string + ": " + matParamVarA1 as string + ", " + matParamVarA2 as string + ", " + matParamVarA3 as string)
									) -- 3x1 floats
								0x15: (matParamVarA1 = readBEfloat f; matParamVarA2 = readBEfloat f; matParamVarA3 = readBEfloat f
									matParamVarB1 = readBEfloat f; matParamVarB2 = readBEfloat f; matParamVarB3 = readBEfloat f
									print (matParamString as string + ": " + matParamVarA1 as string + ", " + matParamVarA2 as string + ", " + matParamVarA3 as string + " | " + matParamVarB1 as string + ", " + matParamVarB2 as string + ", " + matParamVarB3 as string)
									) -- 3x2 floats
								0x16: (matParamVarA1 = readBEfloat f; matParamVarA2 = readBEfloat f; matParamVarA3 = readBEfloat f
									matParamVarB1 = readBEfloat f; matParamVarB2 = readBEfloat f; matParamVarB3 = readBEfloat f
									matParamVarC1 = readBEfloat f; matParamVarC2 = readBEfloat f; matParamVarC3 = readBEfloat f
									print (matParamString as string + ": " + matParamVarA1 as string + ", " + matParamVarA2 as string + ", " + matParamVarA3 as string + " | " + matParamVarB1 as string + ", " + matParamVarB2 as string + ", " + matParamVarB3 as string + " | " + matParamVarC1 as string + ", " + matParamVarC2 as string + ", " + matParamVarC3 as string)
									) -- 3x3 floats
								0x17: (matParamVarA1 = readBEfloat f; matParamVarA2 = readBEfloat f; matParamVarA3 = readBEfloat f
									matParamVarB1 = readBEfloat f; matParamVarB2 = readBEfloat f; matParamVarB3 = readBEfloat f
									matParamVarC1 = readBEfloat f; matParamVarC2 = readBEfloat f; matParamVarC3 = readBEfloat f
									matParamVarD1 = readBEfloat f; matParamVarD2 = readBEfloat f; matParamVarD3 = readBEfloat f
									print (matParamString as string + ": " + matParamVarA1 as string + ", " + matParamVarA2 as string + ", " + matParamVarA3 as string + " | " + matParamVarB1 as string + ", " + matParamVarB2 as string + ", " + matParamVarB3 as string + " | " + matParamVarC1 as string + ", " + matParamVarC2 as string + ", " + matParamVarC3 as string + " | " + matParamVarD1 as string + ", " + matParamVarD2 as string + ", " + matParamVarD3 as string)
									) -- 3x4 floats
								0x18: (matParamVarA1 = readBEfloat f; matParamVarA2 = readBEfloat f; matParamVarA3 = readBEfloat f; matParamVarA4 = readBEfloat f
									print (matParamString as string + ": " + matParamVarA1 as string + ", " + matParamVarA2 as string + ", " + matParamVarA3 as string + ", " + matParamVarA4 as string)
									) -- 4x1 floats
								0x19: (matParamVarA1 = readBEfloat f; matParamVarA2 = readBEfloat f; matParamVarA3 = readBEfloat f; matParamVarA4 = readBEfloat f
									matParamVarB1 = readBEfloat f; matParamVarB2 = readBEfloat f; matParamVarB3 = readBEfloat f; matParamVarB4 = readBEfloat f
									print (matParamString as string + ": " + matParamVarA1 as string + ", " + matParamVarA2 as string + ", " + matParamVarA3 as string + ", " + matParamVarA4 as string + " | " + matParamVarB1 as string + ", " + matParamVarB2 as string + ", " + matParamVarB3 as string + ", " + matParamVarB4 as string)
									) -- 4x2 floats
								0x1A: (matParamVarA1 = readBEfloat f; matParamVarA2 = readBEfloat f; matParamVarA3 = readBEfloat f; matParamVarA4 = readBEfloat f
									matParamVarB1 = readBEfloat f; matParamVarB2 = readBEfloat f; matParamVarB3 = readBEfloat f; matParamVarB4 = readBEfloat f
									matParamVarC1 = readBEfloat f; matParamVarC2 = readBEfloat f; matParamVarC3 = readBEfloat f; matParamVarC4 = readBEfloat f
									print (matParamString as string + ": " + matParamVarA1 as string + ", " + matParamVarA2 as string + ", " + matParamVarA3 as string + ", " + matParamVarA4 as string + " | " + matParamVarB1 as string + ", " + matParamVarB2 as string + ", " + matParamVarB3 as string + ", " + matParamVarB4 as string + " | " + matParamVarC1 as string + ", " + matParamVarC2 as string + ", " + matParamVarC3 as string + ", " + matParamVarC4 as string)
									) -- 4x3 floats
								0x1B: (matParamVarA1 = readBEfloat f; matParamVarA2 = readBEfloat f; matParamVarA3 = readBEfloat f; matParamVarA4 = readBEfloat f
									matParamVarB1 = readBEfloat f; matParamVarB2 = readBEfloat f; matParamVarB3 = readBEfloat f; matParamVarB4 = readBEfloat f
									matParamVarC1 = readBEfloat f; matParamVarC2 = readBEfloat f; matParamVarC3 = readBEfloat f; matParamVarC4 = readBEfloat f
									matParamVarD1 = readBEfloat f; matParamVarD2 = readBEfloat f; matParamVarD3 = readBEfloat f; matParamVarD4 = readBEfloat f
									print (matParamString as string + ": " + matParamVarA1 as string + ", " + matParamVarA2 as string + ", " + matParamVarA3 as string + ", " + matParamVarA4 as string + " | " + matParamVarB1 as string + ", " + matParamVarB2 as string + ", " + matParamVarB3 as string + ", " + matParamVarB4 as string + " | " + matParamVarC1 as string + ", " + matParamVarC2 as string + ", " + matParamVarC3 as string + ", " + matParamVarC4 as string + " | " + matParamVarD1 as string + ", " + matParamVarD2 as string + ", " + matParamVarD3 as string + ", " + matParamVarD4 as string)
									) -- 4x4 floats
								0x1C: (matParamSRTXScl = readBEfloat f; matParamSRTYScl = readBEfloat f; matParamSRTRot = readBEfloat f; matParamSRTXTrs = readBEfloat f; matParamSRTYTrs = readBEfloat f
									print (matParamString as string + ": 2D Scale X = " + matParamSRTXScl as string + ", Y = " + matParamSRTYScl as string + " | Rotate = " + matParamSRTRot as string + " | Translation X = " + matParamSRTXTrs as string + ", Y = " + matParamSRTYTrs as string)
									) -- 2D SRT
								0x1D: (matParamSRTXScl = readBEfloat f; matParamSRTYScl = readBEfloat f; matParamSRTZScl = readBEfloat f; matParamSRTXRot = readBEfloat f; matParamSRTYRot = readBEfloat f; matParamSRTZRot = readBEfloat f; matParamSRTXTrs = readBEfloat f; matParamSRTYTrs = readBEfloat f; matParamSRTZTrs = readBEfloat f
									print (matParamString as string + ": 3D Scale X = " + matParamSRTXScl as string + ", Y = " + matParamSRTYScl as string + ", Z = " + matParamSRTZScl as string + " | Rotate X = " + matParamSRTXRot as string + ", Y = " + matParamSRTYRot as string + ", Z = " + matParamSRTZRot as string + " | Translation X = " + matParamSRTXTrs as string + ", Y = " + matParamSRTYTrs as string + ", Z = " + matParamSRTZTrs as string)
									) -- 3D SRT
								0x1E: (matParamAxis = readBElong f; matParamSRTXScl = readBEfloat f; matParamSRTYScl = readBEfloat f; matParamSRTRot = readBEfloat f; matParamSRTXTrs = readBEfloat f; matParamSRTYTrs = readBEfloat f
									case matParamAxis of(
										0: (matParamAxis = "Maya")
										1: (matParamAxis = "3DS Max")
										2: (matParamAxis = "Softimage")
									)
									print (matParamString as string + ": Scale X = " + matParamSRTXScl as string + ", Y = " + matParamSRTYScl as string + " | Rotate = " + matParamSRTRot as string + " | Translation X = " + matParamSRTXTrs as string + ", Y = " + matParamSRTYTrs as string + " | Axis: " + matParamAxis as string)
									) -- Texture SRT
								0x1F: (matParamAxis = readBElong f; matParamSRTXScl = readBEfloat f; matParamSRTYScl = readBEfloat f; matParamSRTRot = readBEfloat f; matParamSRTXTrs = readBEfloat f; matParamSRTYTrs = readBEfloat f; matParamSRTMatPtr = readBElong f
									case matParamAxis of(
										0: (matParamAxis = "Maya")
										1: (matParamAxis = "3DS Max")
										2: (matParamAxis = "Softimage")
									)
									print (matParamString as string + ": Scale X = " + matParamSRTXScl as string + ", Y = " + matParamSRTYScl as string + " | Rotate = " + matParamSRTRot as string + " | Translation X = " + matParamSRTXTrs as string + ", Y = " + matParamSRTYTrs as string + " | Axis: " + matParamAxis as string + " | Matrix Pointer: " + matParamSRTMatPtr as string)
									) -- Texture SRT + Matrix
							)

							fseek f RtnMat#seek_set
						)
					)

					fseek f Rtn #seek_set
				)

				-- F_Skeleton Header --
				fseek f fmdl_info.fsklOff#seek_set
				fskl_info=(fsklh \
					fskl: (ReadFixedString f 4) \
					u1: (ReadBEShort f) \
					fsklType: (ReadBEShort f) \
					boneArrCount: (ReadBEShort f) \
					invIndxArrCount: (ReadBEShort f) \
					exIndxCount: (ReadBEShort f) \
					u3: (ReadBEShort f) \
					boneIndxOff: (ReadOffset f) \
					boneArrOff: (ReadOffset f) \
					invIndxArrOff: (ReadOffset f) \
					invMatrArrOff: (ReadOffset f) \
					padding: (ReadLong f) \
				)
				append FSKLArr(fskl_info)
				printDebug fskl_info

				-- Node Setup --
				fseek f fskl_info.invIndxArrOff #seek_set
				for nodes = 1 to (fskl_info.invIndxArrCount + fskl_info.exIndxCount) do(
					NodeID = readBEshort f + 1
					append Node_Array NodeID
				)

				-- F_Shape Header --
				fseek f fmdl_info.fshpIndx#seek_set
				fseek f 24#seek_cur
				For shp = 1 to fmdl_info.fshpCount Do(
					fseek f 12#seek_cur
					FSHPOffset = ReadOffset f
					Rtn = ftell f

					fseek f FSHPOffset#seek_set
					fshp_info=(fshph \
						fshp: (ReadFixedString f 4) \
						polyNameOff: (ReadOffset f) \
						u1: (ReadBELong f) \
						fvtxIndx: (ReadBEShort f +1) \
						fmatIndx: (ReadBEShort f +1) \
						fsklIndx: (ReadBEShort f +1) \
						sectIndx: (ReadBEShort f +1) \
						fsklIndxArrCount: (ReadBEShort f) \
						matrFlag: (ReadByte f) \
						lodMdlCount: (ReadByte f) \
						visGrpCount: (ReadBELong f) \
						u3: (ReadBEFloat f) \
						fvtxOff: (ReadOffset f) \
						lodMdlOff: (ReadOffset f) \
						fsklIndxArrOff: (ReadOffset f) \
						u4: (ReadBELong f) \
						visGrpNodeOff: (ReadOffset f) \
						visGrpRangeOff: (ReadOffset f) \
						visGrpIndxOff: (ReadOffset f) \
						u5: (ReadBElong f) \
					)

					fseek f Rtn#seek_set
					append FSHPArr(fshp_info)
					printDebug fshp_info
				)

				-- F_Model Inverse Matrices --
				--fseek f fskl_info.invMatrArrOff#seek_set
				NxtMatr = 0
				fseek f fskl_info.invIndxArrOff#seek_set
				For indx = 1 to fskl_info.invIndxArrCount Do(
					invIndx = ReadBEShort f +1
					NxtIndx = ftell f

					fseek f (fskl_info.invMatrArrOff + NxtMatr)#seek_set
					m11 = ReadBEFloat f; m21 = ReadBEFloat f; m31 = ReadBEFloat f; m41 = ReadBEFloat f
					m12 = ReadBEFloat f; m22 = ReadBEFloat f; m32 = ReadBEFloat f; m42 = ReadBEFloat f
					m13 = ReadBEFloat f; m23 = ReadBEFloat f; m33 = ReadBEFloat f; m43 = ReadBEFloat f
					invtfm = matrix3 [m11,m21,m31,m41] [m12,m22,m32,m42] [m13,m23,m33,m43] [0,0,0,1]

					NxtMatr += 48
					append invMatrArr (invMatrix invIndx:invIndx invMatr:invtfm)
					fseek f NxtIndx#seek_set
				)

				-- F_Model Bone Creation --
				fseek f fskl_info.boneArrOff#seek_set
				For bn = 1 to fskl_info.boneArrCount Do(
					boneData=( bdata \
						bNameOff: (ReadOffset f) \
						bIndx: (ReadBEShort f +1) \
						parIndx1: (ReadBEShort f +1) \
						parIndx2: (ReadBEShort f +1) \
						parIndx3: (ReadBEShort f +1) \
						parIndx4: (ReadBEShort f +1) \
						u1: (ReadBEShort f) \
						bFlags: (ReadBEShort f) \
						u2: (ReadBEShort f) \
						scaleX: (ReadBEFloat f) \
						scaleY: (ReadBEFloat f) \
						scaleZ: (ReadBEFloat f) \
						rotX: (ReadBEFloat f) \
						rotY: (ReadBEFloat f) \
						rotZ: (ReadBEFloat f) \
						rotW: (ReadBEFloat f) \
						posX: (ReadBEFloat f) \
						posY: (ReadBEFloat f) \
						posZ: (ReadBEFloat f) \
						padding: (ReadLong f) \
					)

					if boneData.u2 == 0x0001 then(tfm = inverse (scaleMatrix [boneData.scaleX,boneData.scaleY,boneData.scaleZ])
						tfm = tfm * (quat boneData.rotX boneData.rotY boneData.rotZ boneData.rotW) as matrix3
						tfm = inverse(tfm)
					)else(tfm = scaleMatrix [boneData.scaleX,boneData.scaleY,boneData.scaleZ]
					tfm = tfm * (eulerangles (boneData.rotX*(180/pi)) (boneData.rotY*(180/pi)) (boneData.rotZ*(180/pi))) as matrix3)
					tfm.row4 = [boneData.posX,boneData.posY,boneData.posZ]

					newBone = bonesys.createbone \
						tfm.row4	\
						(tfm.row4 + 0.01 * (normalize tfm.row1)) \
						(normalize tfm.row3)

					Rtn = ftell f
					fseek f boneData.bNameOff#seek_set
					boneName = ReadString f
					if FMDLList_array.count > 1 do(boneName += "_" + x as string)
					fseek f Rtn#seek_set
					newBone.name = boneName
					newBone.width = 0.03
					newBone.height = 0.03
					newBone.transform = tfm
					newBone.setBoneEnable false 0
					newBone.wirecolor = yellow
					newbone.showlinks = true
					newBone.pos.controller = TCB_position()
					newBone.rotation.controller = TCB_rotation()

					If boneData.parIndx1 != 65536 Do(
						newBone.parent = BoneArray[boneData.parIndx1]
						newBone.transform *= BoneArray[boneData.parIndx1].transform
					)

					append BoneArray newBone
					append BoneFixArray newBone.transform
					case of(
						(verNumB == 0 or verNumB == 1 or verNumB == 2 or verNumB == 3):(fseek f 48#seek_cur)
					)
				)

				-- Mesh Building --
				For m = 1 to FSHPArr.count Do(
					Vert_Array = #()
					Normal_Array = #()
					UV_Array = #()
					UV2_Array = #()
					UV3_Array = #()
					UV4_Array = #()
					UV5_Array = #()
					Color_Array = #()
					Alpha_Array = #()
					AttrArr = #()
					BuffArr = #()
					B1_array = #()
					B2_array = #()
					W1_array = #()
					W2_array = #()
					Weight_array = #()

					fseek f FSHPArr[m].polyNameOff#seek_set
					MeshName = ReadString f

					fseek f FVTXArr[FSHPArr[m].fvtxIndx].attArrOff#seek_set
					printDebug("Building polygon " + MeshName + "...")
					For att = 1 to FVTXArr[FSHPArr[m].fvtxIndx].attCount Do(
						AttTypeOff = ReadOffset f
						Rtn1 = ftell f
						fseek f AttTypeOff#seek_set
						AttType = ReadString f
						fseek f Rtn1#seek_set
						buffIndx = ReadByte f+1
						skip = ReadByte f
						buffOff = ReadBEShort f
						vertType = ReadBElong f
						append AttrArr (attdata attName: AttType buffIndx: buffIndx buffOff: buffOff vertType: vertType)
					)
					printDebug AttrArr

					fseek f FVTXArr[FSHPArr[m].fvtxIndx].buffArrOff#seek_set
					For buf = 1 to FVTXArr[FSHPArr[m].fvtxIndx].buffCount Do(
						unk1 = ReadLong f
						BufferSize = ReadBELong f
						unk2 = ReadLong f
						StrideSize = ReadBEShort f
						unk3 = ReadShort f
						unk4 = ReadLong f
						DataOffset = ReadOffset f
						append BuffArr (buffData buffSize: BufferSize strideSize: StrideSize dataOffset: DataOffset)
					)
					printDebug BuffArr

					fseek f BuffArr[1].dataOffset #seek_set
					For attr = 1 to AttrArr.count Do(
						locPoint = ((BuffArr[AttrArr[attr].buffIndx].dataOffset) + (AttrArr[attr].buffOff))
						fseek f locPoint #seek_set
						if attr == 1 do(printDebug("Vertex buffer starts at 0x" + bit.intAsHex(ftell f) as string))
						For v = 1 to FVTXArr[FSHPArr[m].fvtxIndx].vertCount Do(
							VertStart = (ftell f + (BuffArr[AttrArr[attr].buffIndx].strideSize))
							case AttrArr[attr].vertType of (
								-- 0x00 - Unsigned ints
								default: (throw("Unknown type!"))
								0x0000:(
									-- 1 byte integer, unsigned
									var1 = ReadByte f #unsigned
									var2 = 0
									var3 = 0
									var4 = 0
								)
								0x0004:(
									-- 2 byte integers, unsigned
									var1 = ReadByte f #unsigned
									var2 = ReadByte f #unsigned
									var3 = 0
									var4 = 0
								)
								0x0007:(
									-- 2 short integers, unsigned
									var1 = ReadBEShort f
									var2 = ReadBEShort f
									var3 = 0
									var4 = 0
								)
								0x000A:(
									-- 4 byte integers, unsigned
									var1 = ReadByte f #unsigned
									var2 = ReadByte f #unsigned
									var3 = ReadByte f #unsigned
									var4 = ReadByte f #unsigned
								)

								-- 0x01 - Unsigned ints (bone IDs only?)
								0x0100:(
									-- 1 byte integer, unsigned, bone IDs
									var1 = ReadByte f #unsigned + 1
									var2 = 1
									var3 = 1
									var4 = 1
								)
								0x0104:(
									-- 2 byte integers, unsigned, bone IDs
									var1 = ReadByte f #unsigned + 1
									var2 = ReadByte f #unsigned + 1
									var3 = 1
									var4 = 1
								)
								0x010A:(
									-- 4 byte integers, unsigned, bone IDs
									var1 = ReadByte f #unsigned + 1
									var2 = ReadByte f #unsigned + 1
									var3 = ReadByte f #unsigned + 1
									var4 = ReadByte f #unsigned + 1
								)
								0x010C:(
									-- 2 long integers, unsigned, bone IDs
									var1 = ReadBELong f + 1
									var2 = ReadBELong f + 1
									var3 = 1
									var4 = 1
								)
								0x0110:(
									-- 4 long integers, unsigned, bone IDs
									var1 = ReadBELong f + 1
									var2 = ReadBELong f + 1
									var3 = ReadBELong f + 1
									var4 = ReadBELong f + 1
								)
								0x0112:(
									-- 4 long integers, unsigned, bone IDs, same?
									var1 = ReadBELong f + 1
									var2 = ReadBELong f + 1
									var3 = ReadBELong f + 1
									var4 = ReadBELong f + 1
								)

								-- 0x02 - Signed ints
								0x0204:(
									-- 2 byte integers, signed
									var1 = ReadByte f
									var2 = ReadByte f
									var3 = 0
									var4 = 0
								)
								0x0207:(
									-- 2 short integers, signed
									var1 = ReadBEShort f
									var2 = ReadBEShort f
									var3 = 0
									var4 = 0
								)
								0x020A:(
									-- 4 byte integers, signed
									var1 = ReadByte f
									var2 = ReadByte f
									var3 = ReadByte f
									var4 = ReadByte f
								)
								0x020B:(
									-- 3 10-bit values, signed
									vars = ReadBElong f
									var1 = sign10(bit.and (vars) 0x3FF) as float / 511
									var2 = sign10(bit.and (bit.shift vars -10) 0x3FF) as float / 511
									var3 = sign10(bit.and (bit.shift vars -20) 0x3FF) as float / 511
									var4 = 0
								)

								-- 0x08 - Floats
								0x0803:(
									-- 1 half-float
									var1 = readBEHalfFloat f
									var2 = 0
									var3 = 0
									var4 = 0
								)
								0x0808:(
									-- 2 half-floats
									var1 = readBEHalfFloat f
									var2 = readBEHalfFloat f
									var3 = 0
									var4 = 0
								)
								0x080D:(
									-- 2 floats
									var1 = ReadBEFloat f
									var2 = ReadBEFloat f
									var3 = 0
									var4 = 0
								)
								0x080F:(
									-- 4 half-floats
									var1 = ReadBEHalfFloat f
									var2 = ReadBEHalfFloat f
									var3 = ReadBEHalfFloat f
									var4 = ReadBEHalfFloat f
								)
								0x0811:(
									-- 3 floats
									var1 = ReadBEFloat f
									var2 = ReadBEFloat f
									var3 = ReadBEFloat f
									var4 = 0
								)
								0x0813:(
									-- 4 floats
									var1 = ReadBEFloat f
									var2 = ReadBEFloat f
									var3 = ReadBEFloat f
									var4 = ReadBEFloat f
								)
							)

							case of (
								--Vertex Info--
								(AttrArr[attr].attName == "_p0"):(
									append vert_Array[var1,var2,var3]
								)
								--Color Info--
								(AttrArr[attr].attName == "_c0"):(
									case of (
										(AttrArr[attr].vertType == 0x020A):(
											var1 = vRange 0 254 (var1 * 2)
											var2 = vRange 0 254 (var2 * 2)
											var3 = vRange 0 254 (var3 * 2)
											var4 = vRange 0 1 (var4 as float / 127)
										)
										(AttrArr[attr].vertType == 0x080F):(
											var1 = vRange 0 255 (var1 * 255)
											var2 = vRange 0 255 (var2 * 255)
											var3 = vRange 0 255 (var3 * 255)
											var4 = vRange 0 1 (var4 as float)
										)
										(AttrArr[attr].vertType == 0x0813):(
											var1 = vRange 0 255 (var1 * 255)
											var2 = vRange 0 255 (var2 * 255)
											var3 = vRange 0 255 (var3 * 255)
											var4 = vRange 0 1 (var4 as float)
										)
									)
									append Color_Array[var1,var2,var3]
									append Alpha_Array var4
								)
								--Normals Info--
								(AttrArr[attr].attName == "_n0"):(
									case of (
										(AttrArr[attr].vertType == 0x020A):(
											fseek f (AttrArr[attr].buffOff)#seek_cur
											var1 = var1 as float / 127
											var2 = var2 as float / 127
											var3 = var3 as float / 127
											var4 = var4 as float / 127
										)
									)
									append Normal_Array[var1,var2,var3]
								)
								--Tangent Info--
								--Binormals Info--
								--UV Info--
								(AttrArr[attr].attName == "detail"):(
									var1 *= 2
									var2 *= 2
									append UV3_array [var1,var2,0]
								)
								(AttrArr[attr].attName == "_u0" or AttrArr[attr].attName == "color" or AttrArr[attr].attName == "_u1" or AttrArr[attr].attName == "_u2" or AttrArr[attr].attName == "_u3" or AttrArr[attr].attName == "_u4" or AttrArr[attr].attName == "All"):(
									case AttrArr[attr].vertType of (
										default:(var2 = (var2 * -1) + 1)
										0x0004:(
											var1 = (var1 as float / 255)
											var2 = ((var2 as float / 255) * -1) + 1
										)
										0x0007:(
											var1 = (var1 as float / 65535)
											var2 = ((var2 as float / 65535) * -1) + 1
										)
										0x0204:(
											var1 = (var1 as float / 127)
											var2 = ((var2 as float / 127) * -1) + 1
										)
										0x0207:(
											var1 = (var1 as float / 32767)
											var2 = ((var2 as float / 32767) * -1) + 1
											case of (
												(var1 < -1): var1 += 2
												(var1 > 1): var1 -= 2
											)
											case of (
												(var2 < 0): var2 += 2
												(var2 > 2): var2 -= 2
											)
										)
									)
									case of(
										(AttrArr[attr].attName == "_u0" or AttrArr[attr].attName == "color"): append UV_Array[var1,var2,0]
										(AttrArr[attr].attName == "_u1"): append UV2_Array[var1,var2,0]
										(AttrArr[attr].attName == "_u2"): append UV3_Array[var1,var2,0]
										(AttrArr[attr].attName == "_u3"): append UV4_Array[var1,var2,0]
										(AttrArr[attr].attName == "_u4" or AttrArr[attr].attName == "All"): append UV5_Array[var1,var2,0]
									)
								)

								--BlendIndex Info--
								(AttrArr[attr].attName == "_i0" or AttrArr[attr].attName == "_i1"):(
									bone1 = Node_array[var1]
									bone2 = Node_array[var2]
									bone3 = Node_array[var3]
									bone4 = Node_array[var4]
									case AttrArr[attr].attName of (
										"_i0": append B1_Array (Bone_Info_Struct bone1:bone1 bone2:bone2 bone3:bone3 bone4:bone4)
										"_i1": append B2_Array (Bone_Info_Struct bone1:bone1 bone2:bone2 bone3:bone3 bone4:bone4)
									)
								)
								-- BlendWeight Info --
								(AttrArr[attr].attName == "_w0" or AttrArr[attr].attName == "_w1"):(
									case AttrArr[attr].vertType of (
										default: (
											weight1 = var1
											weight2 = var2
											weight3 = var3
											weight4 = var4
										)
										0x0000:(
											weight1 = var1 as float / 255
											weight2 = 0
											weight3 = 0
											weight4 = 0
										)
										0x0004:(
											weight1 = var1 as float / 255
											weight2 = var2 as float / 255
											weight3 = 0
											weight4 = 0
										)
										0x000A:(
											weight1 = var1 as float / 255
											weight2 = var2 as float / 255
											weight3 = var3 as float / 255
											weight4 = var4 as float / 255
											if weight4 >= 1 do(weight4 = 0)
										)
										0x0811:(
											weight1 = var1
											weight2 = var2
											weight3 = var3
											weight4 = 0
										)
									)
									case AttrArr[attr].attName of (
										"_w0": append W1_Array (Weight_Info_Struct weight1:weight1 weight2:weight2 weight3:weight3 weight4:weight4)
										"_w1": append W2_Array (Weight_Info_Struct weight1:weight1 weight2:weight2 weight3:weight3 weight4:weight4)
									)
								)
							)

							fseek f VertStart #seek_set
						) -- Close Vert Read Loop
					) -- Close Attributes Loop

					If Color_Array.count == 0 Do(
						For ca = 1 to Vert_array.count Do (
							append Color_Array[255,255,255]
							append Alpha_Array 1
						)
					)

					If W1_Array.count == 0 Do(
						For v = 1 to B1_array.count Do(
							append W1_Array (Weight_Info_Struct weight1:1 weight2:0 weight3:0 weight4:0)
						)
					)
				
					If B2_Array.count == 0 Do(
						For v = 1 to B1_array.count Do(
							append B2_Array (Bone_Info_Struct bone1:1 bone2:1 bone3:1 bone4:1)
							append W2_Array (Weight_Info_Struct weight1:0 weight2:0 weight3:0 weight4:0)
						)
					)

					for b = 1 to W1_Array.count Do(
						w = (weight_data boneids:#() weights:#())
						maxweight = 0
						
						if W1_array[b].Weight1 != 0 do maxweight += W1_array[b].Weight1
						if W1_array[b].Weight2 != 0 do maxweight += W1_array[b].Weight2
						if W1_array[b].Weight3 != 0 do maxweight += W1_array[b].Weight3
						if W1_array[b].Weight4 != 0 do maxweight += W1_array[b].Weight4
						if W2_array[b].Weight1 != 0 do maxweight += W2_array[b].Weight1
						if W2_array[b].Weight2 != 0 do maxweight += W2_array[b].Weight2
						if W2_array[b].Weight3 != 0 do maxweight += W2_array[b].Weight3
						if W2_array[b].Weight4 != 0 do maxweight += W2_array[b].Weight4

						if maxweight != 0 then(
							if W1_array[b].Weight1 != 0 then(
								w1 = W1_array[b].Weight1 as float
								append w.boneids (B1_array[b].Bone1)
								append w.weights (w1)
							)
							if W1_array[b].Weight2 != 0 then(
								w2 = W1_array[b].Weight2 as float
								append w.boneids (B1_array[b].Bone2)
								append w.weights (w2)
							)
							if W1_array[b].Weight3 != 0 then(
								w3 = W1_array[b].Weight3 as float
								append w.boneids (B1_array[b].Bone3)
								append w.weights (w3)
							)
							if W1_array[b].Weight4 != 0 then(
								w4 = W1_array[b].Weight4 as float
								append w.boneids (B1_array[b].Bone4)
								append w.weights (w4)
							)
							if W2_array[b].Weight1 != 0 then(
								w5 = W2_array[b].Weight1 as float
								append w.boneids (B2_array[b].Bone1)
								append w.weights (w5)
							)
							if W2_array[b].Weight2 != 0 then(
								w6 = W2_array[b].Weight2 as float
								append w.boneids (B2_array[b].Bone2)
								append w.weights (w6)
							)
							if W2_array[b].Weight3 != 0 then(
								w7 = W2_array[b].Weight3 as float
								append w.boneids (B2_array[b].Bone3)
								append w.weights (w7)
							)
							if W2_array[b].Weight4 != 0 then(
								w8 = W2_array[b].Weight4 as float
								append w.boneids (B2_array[b].Bone4)
								append w.weights (w8)
							)
						)
						append Weight_array w
					)

					fseek f FSHPArr[m].lodMdlOff#seek_set
					if LODs == 2 do FSHPArr[m].lodMdlCount = 1
					for l = 1 to FSHPArr[m].lodMdlCount do(
						Face_Array = #()
						lodmdl_info=(lodmdl \
							u1: (ReadBELong f) \
							faceType: (ReadBELong f) \
							dCount: (ReadBELong f) \
							visGrpCount: (ReadBEShort f) \
							u3: (ReadBEShort f) \
							visGrpOff: (ReadOffset f) \
							indxBuffOff: (ReadOffset f) \
							elmSkip: (ReadBELong f) \
						)
						LODRet = (ftell f)

						fseek f lodmdl_info.indxBuffOff#seek_set
						unk1 = ReadBELong f
						FaceCount = (ReadBElong f)
						fseek f 12#seek_cur
						FaceBuffer = ReadOffset f
						
						fseek f FaceBuffer#seek_set
						PolyStart = lodmdl_info.elmSkip
						case of (
							(lodmdl_info.faceType == 4):(
								FaceCount = (FaceCount/6)
								For face = 1 to FaceCount Do(
									fa = ((ReadBEShort f) + 1 + PolyStart)
									fb = ((ReadBEShort f) + 1 + PolyStart)
									fc = ((ReadBEShort f) + 1 + PolyStart)
									append Face_Array[fa,fb,fc]
								)
							)
							(lodmdl_info.faceType == 9):(
								FaceCount = (FaceCount/12)
								For face = 1 to FaceCount Do(
									fa = ((ReadBELong f) + 1 + PolyStart)
									fb = ((ReadBELong f) + 1 + PolyStart)
									fc = ((ReadBELong f) + 1 + PolyStart)
									append Face_Array[fa,fb,fc]
								)
							)
						)

						local Cac=Color_Array.count
						local Vac=Vert_Array.count
						local Fac=Face_array.count
						local Nac=Normal_array.count
						local Bac=BoneArray.count
						local Wac=Weight_array.count

						msh = mesh vertices:Vert_array faces:Face_array
						msh.numTVerts = Vac
						setNumCPVVerts msh msh.numTVerts
						setCVertMode msh true
						setShadeCVerts msh true
						defaultVCFaces msh
						buildTVFaces msh
						for j = 1 to Cac do setvertcolor msh j Color_array[j]
						for j = 1 to Cac do(meshop.setVertAlpha msh -2 j Alpha_array[j])

						If Vac == UV_Array.count Do(
							for j = 1 to Vac do setTVert msh j UV_array[j]
							for j = 1 to Fac do setTVFace msh j Face_array[j]
						)
						for j = 1 to msh.numfaces do setFaceSmoothGroup msh j 1

						msh.name = MeshName + (if FSHPArr[m].lodMdlCount == 1 then "" else " (LOD: " + l as string + ")")
						msh.material = buildMat \
							matName:FMATNameArr[FSHPArr[m].fmatIndx] \
							tSelOff:FMATArr[FSHPArr[m].fmatIndx].texSelOff \
							rtnTexAS:FMATArr[FSHPArr[m].fmatIndx].texAttSelOff \
							tCount:FMATArr[FSHPArr[m].fmatIndx].texSelCount \
							tFormat:TexF[TexFormat] \
							tPath:TexP[TexPath]

						max modify mode
						select msh

						addmodifier msh (Edit_Normals()) ui:off
						msh.Edit_Normals.MakeExplicit selection:#{1..Normal_array.count}
						EN_convertVS = msh.Edit_Normals.ConvertVertexSelection
						EN_setNormal = msh.Edit_Normals.SetNormal
						normID = #{}
						for v = 1 to Nac do(
							free normID
							EN_convertVS #{v} &normID
							for id in normID do EN_setNormal id Normal_array[v]
						)

						if Bac > 0 do(
							if FSHPArr[m].matrFlag == 0 then(
								$.transform = BoneFixArray[FSHPArr[m].fsklIndx]
								if RigModel != 2 do(
									skinMod = skin()
									addModifier msh skinMod
									maxbone = getnodebyname BoneArray[FSHPArr[m].fsklIndx].name
									skinOps.addBone skinMod maxbone 0
								)
							)else(
								if RigModel != 2 do(
									skinMod = skin()
									boneIDMap = #()
									addModifier msh skinMod
									msh.Skin.weightAllVertices = false

									if FSHPArr[m].matrFlag == 1 do(for b in BoneArray do b.transform = matrix3 1)

									for i = 1 to Bac do(
										maxbone = getnodebyname BoneArray[i].name
										skinOps.addBone skinMod maxbone (if i != Bac then 0 else 1)
									)

									local numSkinBones = skinOps.GetNumberBones skinMod
									for i = 1 to numSkinBones do(
										local boneName = skinOps.GetBoneName skinMod i 0
										for j = 1 to Bac do(
											if boneName == BoneArray[j].Name do(
												boneIDMap[j] = i
												j = Bac + 1
											)
										)
									) -- Thanks to sunnydavis for the fix!

									modPanel.setCurrentObject skinMod

									for i = 1 to Vac do(
										skinOps.SetVertexWeights skinMod i 1 1
										skinOps.unnormalizeVertex skinMod i true 
										skinOps.SetVertexWeights skinMod i 1 0
										skinOps.unnormalizeVertex skinMod i false
									)
									skinOps.RemoveZeroWeights skinMod

									for i = 1 to Wac do(
										w = Weight_array[i]
										bi = #() --bone index array
										wv = #() --weight value array
										wbic = w.boneids.count

										for j = 1 to wbic do(
											boneid = w.boneids[j]
											weight = w.weights[j]
											append bi boneIDMap[boneid]
											append wv weight
										)   
										skinOps.ReplaceVertexWeights skinMod i bi wv
									)

									if FSHPArr[m].matrFlag == 1 do(for b = 1 to Bac do BoneArray[b].transform = BoneFixArray[b])

								)
							)
						)

						local UVarrays = #(UV2_array,UV3_array,UV4_array,UV5_array)
						case UVLayers of(
							1:(
								for uva=1 to UVarrays.count do(
									local uvac=UVarrays[uva].count
									if uvac > 0 do(
										meshop.setNumMaps msh (uva+2) keep:true
										for i = 1 to uvac do meshop.setMapVert msh (uva+1) i UVarrays[uva][i]
									)
								)
							)

							2:(
								for uva=1 to UVarrays.count do(
									local uvac=UVarrays[uva].count
									if uvac > 1 do(
										msh = mesh vertices:Vert_array faces:Face_array
										msh.numTVerts = Vac
										setNumCPVVerts msh msh.numTVerts
										setCVertMode msh true
										setShadeCVerts msh true
										defaultVCFaces msh
										buildTVFaces msh
										for j = 1 to Cac do setvertcolor msh j Color_array[j]
										for j = 1 to Cac do(meshop.setVertAlpha msh -2 j Alpha_array[j])
										If Vac == uvac Do(
											for j = 1 to Vac do setTVert msh j UVarrays[uva][j]
											for j = 1 to Fac do setTVFace msh j Face_array[j]
										)
										for j = 1 to msh.numfaces do setFaceSmoothGroup msh j 1

										msh.name = MeshName + " Layer "+ (uva+1) as string + (if FSHPArr[m].lodMdlCount == 1 then "" else " (LOD: " + l as string + ")")
										msh.material = buildMat \
											matName:FMATNameArr[FSHPArr[m].fmatIndx] \
											tSelOff:FMATArr[FSHPArr[m].fmatIndx].texSelOff \
											rtnTexAS:FMATArr[FSHPArr[m].fmatIndx].texAttSelOff \
											tCount:FMATArr[FSHPArr[m].fmatIndx].texSelCount \
											tFormat:TexF[TexFormat] \
											tPath:TexP[TexPath]

										select msh

										addmodifier msh (Edit_Normals()) ui:off
										msh.Edit_Normals.MakeExplicit selection:#{1..Normal_array.count}
										EN_convertVS = msh.Edit_Normals.ConvertVertexSelection
										EN_setNormal = msh.Edit_Normals.SetNormal
										normID = #{}
										for v = 1 to Nac do(
											free normID
											EN_convertVS #{v} &normID
											for id in normID do EN_setNormal id Normal_array[v]
										)

										if Bac > 0 do(
											if FSHPArr[m].matrFlag == 0 then(
												$.transform = BoneFixArray[FSHPArr[m].fsklIndx]
												if RigModel != 2 do(
													skinMod = skin()
													addModifier msh skinMod
													maxbone = getnodebyname BoneArray[FSHPArr[m].fsklIndx].name
													skinOps.addBone skinMod maxbone 0
												)
											)else(
												if RigModel != 2 do(
													skinMod = skin()
													boneIDMap = #()
													addModifier msh skinMod
													msh.Skin.weightAllVertices = false

													if FSHPArr[m].matrFlag == 1 do(for b in BoneArray do b.transform = matrix3 1)

													for i = 1 to Bac do(
														maxbone = getnodebyname BoneArray[i].name
														skinOps.addBone skinMod maxbone (if i != Bac then 0 else 1)
													)

													local numSkinBones = skinOps.GetNumberBones skinMod
													for i = 1 to numSkinBones do(
														local boneName = skinOps.GetBoneName skinMod i 0
														for j = 1 to Bac do(
															if boneName == BoneArray[j].Name do(
																boneIDMap[j] = i
																j = Bac + 1
															)
														)
													) -- Thanks to sunnydavis for the fix!

													modPanel.setCurrentObject skinMod

													for i = 1 to Vac do(
														skinOps.SetVertexWeights skinMod i 1 1
														skinOps.unnormalizeVertex skinMod i true 
														skinOps.SetVertexWeights skinMod i 1 0
														skinOps.unnormalizeVertex skinMod i false
													)
													skinOps.RemoveZeroWeights skinMod

													for i = 1 to Wac do(
														w = Weight_array[i]
														bi = #() --bone index array
														wv = #() --weight value array
														wbic = w.boneids.count

														for j = 1 to wbic do(
															boneid = w.boneids[j]
															weight = w.weights[j]
															append bi boneIDMap[boneid]
															append wv weight
														)   
														skinOps.ReplaceVertexWeights skinMod i bi wv
													)

													if FSHPArr[m].matrFlag == 1 do(for b = 1 to Bac do BoneArray[b].transform = BoneFixArray[b])

												)
											)
										)
									)
								)
							)
						)
						fseek f LODRet #seek_set
					)
				)
				clearSelection()
			)
		) else (
			struct fmdlh(
				fmdl,				-- Magic
				headerLength1,    -- FMDL header length (1)
				headerLength2,    -- FMDL header length (2)
				fnameOff,		-- Filename Offset
				eofString,		-- End of File String Offset
				fsklOff,			-- FSKL Offset
				fvtxArrOff,		-- FVTX Array Offset
				fshpIndx,		-- FSHP Index Offset
				fshpSubIndx,   -- FSHP Secondary Index Offset
				fmatOff,		-- FMAT Offset
				fmatIndx,   -- FMAT Index Offset
				paramOff,		-- Parameter Offset
				fvtxCount,		-- FVTX Count (int16)
				fshpCount,		-- FSHP Count (int16)
				fmatCount,		-- FMAT Count (int16)
				paramCount,	-- Parameter Count (int16)
				fmdlUnk3,	    -- Unknown Offset
				padding           -- Always 0
			)

			struct fvtxh(
				fvtx,				-- Magic
				attCount,		-- Attribute Count (int8)
				buffCount,		-- Buffer Count (int8)
				sectIndx,		-- Section Index (int16)
				vertCount,		-- Vertex Count
				attArrOff,		-- Attribute Array Offset
				attIndxOff,		-- Attribute Index Offset
				buffOff,		-- Buffer Array Offset
				UnkOffset1,
				UnkOffset3,
				UnkOffset4,
				vtxBuffSizeOff,
				vtxStrideSizeOff,
				UnkCount3,
				padding			-- Padding (int32)
			)

			struct fmath(
				fmat,							-- Magic
				matOff,						-- Material Name Offset
				u1,								-- Unknown (int32)
				sectIndx,					-- Section Index (int16)
				rendParamCount,		-- Render Info Parameter Count (int16)
				texSelCount,				-- Texture Selector Count (int8)
				texAttSelCount,			-- Texture Attribute Selector Count (int8)
				matParamCount,		-- Material Parameter Count (int16)
				matParamSize,			-- Material Parameter Data Size
				u2,								-- Unknown (int16)
				rendParamIndx,			-- Render Info Parameter Index Group Offset
				shadeOff,					-- Shader Control Offset
				texSelOff,					-- Texture Selector Offset
				texAttSelOff,				-- Texture Attribute Selector Offset
				texAttIndxOff,			-- Texture Attribute Selector Index Offset
				matParamArrOff,		-- Material Parameter Array Offset
				matParamIndxOff,		-- Material Parameter Index Offset
				matParamOff,				-- Material Parameter Data Offset
				shadParamIndxOff,	-- Shadow Parameter Index Offset
				UnkOffset1A,
				UnkOffset1B,
				Unk1Off,
				Unk2Off,
				Unk3Off,
				Unk4Off,
				Unk5Off,
				Unk6Off,
				Unk7Off,
				Unk8Off,
				padding
			)

			struct fsklh(
				fskl,							-- Magic
-- 				fsklType,				-- Type of Bone Data (uint16)
				boneArrCount,		-- Bone Array Count (int16)
				invIndxArrCount,	-- Inverse Index Array Count (int16)
				exIndxCount,			-- Extra Index Count (int16)
				boneIndxOff,			-- Bone Index Group Offset
				boneArrOff,			-- Bone Array Offset
				invIndxArrOff,		-- Inverse Index Array Offset
				invMatrArrOff,		-- Inverse Matric Array Offset
				padding,					-- Padding (int32)
				UnkOffset1A,
				UnkOffset1B,
				UnkOffset5,
				UnkCount2
			)

			struct fshph(
				fshp,						-- Magic
				polyNameOff,			-- Polygon Name Offset
				Unk3Off,
				Unk4Off,
				Unk5Off,
				UnkShort1,
				UnkShort2,
				sectIndx,				-- Section Index (int16)
				fvtxIndx,					-- FVTX Index (int16)
				fmatIndx,				-- FMAT Index (int16)
				fsklIndx,					-- FSKL Index (int16)
				fsklIndxArrCount,	-- FSKL Index Array Count (int16)
				matrFlag,				-- Matrix Use Flag (int8)
				lodMdlCount,			-- LoD Model Count (int8)
-- 				visGrpCount,			-- Visibility Group Tree Node Count
				fvtxOff,					-- FVTX Offset
				lodMdlOff,				-- LoD Model Offset
-- 				fsklIndxArrOff,		-- FSKL Index Array Offset
-- 				visGrpNodeOff,		-- Vibility Group Tree Nodes Offset
-- 				visGrpRangeOff,	-- Visibility Group Tree Ranges Offset
-- 				visGrpIndxOff,		-- Visibility Group Tree Indices Offset

				padding		-- Padding
			)

			struct attdata(
				attName,	-- Attribute Type
				buffIndx,		-- Buffer Index (u8)
				buffOff,		-- Buffer Offset (u16)
				vertType		-- Format
			)

			struct buffData(
				buffSize,		-- Size of Buffer (u32)
				strideSize,	-- Size of Vertex Stride (u16)
				dataOffset	-- Offset to Buffer (u32)
			)

			struct bdata(
				bNameOff,		-- Bone Name Offset
				bIndx,				-- Bone Index (int16)
				parIndx1,		-- Parent Index 1 (int16)
				parIndx2,		-- Parent Index 2 (int16)
				parIndx3,		-- Parent Index 3 (int16)
				parIndx4,		-- Parent Index 4 (int16)
				u1,					-- Unknown (int16)
				bFlags,			-- Bone Flags (int16)
				u2,					-- Unknown (int16)
				scaleX,			-- Scale X
				scaleY,			-- Scale Y
				scaleZ,			-- Scale Z
				rotX,				-- Rotation X
				rotY,				-- Rotation Y
				rotZ,				-- Rotation Z
				rotW,				-- Rotation W
				posX,				-- Position X
				posY,				-- Position Y
				posZ,				-- Position Z
				padding,			-- Padding
				m11,				-- Matrix 
				m21,				-- Matrix 
				m31,				-- Matrix 
				m41,				-- Matrix 
				m12,				-- Matrix 
				m22,				-- Matrix 
				m32,				-- Matrix 
				m42,				-- Matrix 
				m13,				-- Matrix 
				m23,				-- Matrix 
				m33,				-- Matrix 
				m43				-- Matrix 
			)

			struct lodmdl(
				u1,					-- Unknown (int32)
				faceType,		-- Face Data Type (int32)
				dCount,			-- Visibility Group Draw Count
				visGrpCount,	-- Visibility Group Count (int16)
				u3,					-- Unknown (int16)
				visGrpOff,		-- Visibility Group Offset
				indxBuffOff,	-- Index Buffer Offset
				elmSkip			-- Element Skip (int32)
			)

			struct Bone_Info_Struct(
				bone1, bone2, bone3, bone4
			)

			struct Weight_Info_Struct(
				weight1, weight2, weight3, weight4
			)

			struct weight_data(
				boneids, weights
			)

			struct invMatrix(
				invIndx, invMatr
			)

			fseek f 8#seek_set
			verNumD = ReadByte f
			verNumC = ReadByte f
			verNumB = ReadByte f
			verNumA = ReadByte f
			FMDLList_array = lstFMDL.selection as array

			for x = 1 to FMDLList_array.count do(
				fseek f FMDLOffset_array[FMDLList_array[x]]#seek_set

				FMDLArr = #()
				FVTXArr = #()
				FSKLArr = #()
				FMATArr = #()
				FMATNameArr = #()
				FSHPArr = #()
				FBVSArr = #()
				VTXAttr = #()

				BoneArray = #()
				BoneFixArray = #()
				invIndxArr = #()
				invMatrArr = #()
				Node_Array = #()

				-- F_Model Header --
				fmdl_info=(fmdlh \
						fmdl: (ReadFixedString f 4) \
						headerLength1: (ReadLong f) \
						headerLength2: (ReadLong f) \
						padding: (ReadLong f) \
						fnameOff: (ReadLong f) \
						padding: (ReadLong f) \
						eofString: (ReadLong f) \
						padding: (ReadLong f) \
						fsklOff: (ReadLong f) \
						padding: (ReadLong f) \
						fvtxArrOff: (ReadLong f) \
						padding: (ReadLong f) \
						fshpIndx: (ReadLong f) \
						padding: (ReadLong f) \
						fshpSubIndx: (ReadLong f) \
						padding: (ReadLong f) \
						fmatOff: (ReadLong f) \
						padding: (ReadLong f) \
						fmatIndx: (ReadLong f) \
						padding: (ReadLong f) \
						paramOff: (ReadLong f) \
						padding: (ReadLong f) \
						padding: (ReadLong f) \
						padding: (ReadLong f) \
						padding: (ReadLong f) \
						padding: (ReadLong f) \
						fvtxCount: (ReadShort f) \
						fshpCount: (ReadShort f) \
						fmatCount: (ReadShort f) \
						paramCount: (ReadShort f) \
						fmdlUnk3: (ReadLong f) \
						padding: (ReadLong f) \
				)
				append FMDLArr(fmdl_info)
				printDebug fmdl_info

				-- F_Vertex Header --
				fseek f fmdl_info.fvtxArrOff#seek_set
				For vtx = 1 to fmdl_info.fvtxCount Do(
					fvtx_info=(fvtxh \
						fvtx: (ReadFixedString f 4) \
						padding: (ReadLong f) \
						padding: (ReadLong f) \
						padding: (ReadLong f) \
						attArrOff: (ReadLong f) \
						padding: (ReadLong f) \
						attIndxOff: (ReadLong f) \
						padding: (ReadLong f) \
						UnkOffset1: (ReadLong f) \
						padding: (ReadLong f) \
						UnkOffset3: (ReadLong f) \
						padding: (ReadLong f) \
						UnkOffset4: (ReadLong f) \
						padding: (ReadLong f) \
						vtxBuffSizeOff: (ReadLong f) \
						padding: (ReadLong f) \
						vtxStrideSizeOff: (ReadLong f) \
						padding: (ReadLong f) \
-- 						buffArrOff: (ReadLong f) \
						padding: (ReadLong f) \
						padding: (ReadLong f) \
						buffOff: (ReadLong f) \
						attCount: (ReadByte f) \
						buffCount: (ReadByte f) \
						sectIndx: (ReadShort f +1) \
						vertCount: (ReadLong f) \
						UnkCount3: (ReadLong f) \
					)
					append FVTXArr(fvtx_info)
					printDebug fvtx_info
				)

				-- F_Material Header --
				fseek f fmdl_info.fmatIndx#seek_set
				fseek f 24#seek_cur
				For mat = 1 to fmdl_info.fmatCount Do(
					fseek f 8#seek_cur
					FMATNameOffset = ReadLong f
					Rtn = ftell f
					fseek f FMATNameOffset#seek_set

					fseek f 0x02 #seek_cur
					FMATName = readstring f
					append FMATNameArr FMATName
					fseek f Rtn#seek_set
					fseek f 4#seek_cur
				)

				fseek f fmdl_info.fmatOff#seek_set
				For mat = 1 to fmdl_info.fmatCount Do(
					fmat_info=(fmath \
						fmat: (ReadFixedString f 4) \
						UnkOffset1A: (ReadLong f) \
						UnkOffset1B: (ReadLong f) \
						padding: (ReadLong f) \
						matOff: (ReadLong f) \
						padding: (ReadLong f) \
						shadParamIndxOff: (ReadLong f) \
						padding: (ReadLong f) \
						rendParamIndx: (ReadLong f) \
						padding: (ReadLong f) \
						shadeOff: (ReadLong f) \
						padding: (ReadLong f) \
						Unk1Off: (ReadLong f) \
						padding: (ReadLong f) \
						texSelOff: (ReadLong f) \
						padding: (ReadLong f) \
						Unk2Off: (ReadLong f) \
						padding: (ReadLong f) \
						texAttSelOff: (ReadLong f) \
						padding: (ReadLong f) \
						texAttIndxOff: (ReadLong f) \
						padding: (ReadLong f) \
						matParamArrOff: (ReadLong f) \
						padding: (ReadLong f) \
						matParamIndxOff: (ReadLong f) \
						padding: (ReadLong f) \
						matParamOff: (ReadLong f) \
						padding: (ReadLong f) \
						Unk3Off: (ReadLong f) \
						padding: (ReadLong f) \
						Unk4Off: (ReadLong f) \
						padding: (ReadLong f) \
						Unk5Off: (ReadLong f) \
						padding: (ReadLong f) \
						Unk6Off: (ReadLong f) \
						padding: (ReadLong f) \
						Unk7Off: (ReadLong f) \
						padding: (ReadLong f) \
						Unk8Off: (ReadLong f) \
						padding: (ReadLong f) \
						u1: (ReadLong f) \
						sectIndx: (ReadShort f) \
						rendParamCount: (ReadShort f) \
						texSelCount: (ReadByte f) \
						texAttSelCount: (ReadByte f) \
						matParamCount: (ReadShort f) \
						u2: (ReadShort f) \
						matParamSize: (ReadShort f) \
						padding: (ReadLong f) \
						padding: (ReadLong f) \
					)
					append FMATArr(fmat_info)
					printDebug fmat_info

					if MatInfo == true do(
						Rtn = ftell f
						fseek f FMATArr[mat].matParamArrOff #seek_set

						print "--------------------"
						print ("Texture properties for " + FMATNameArr[mat] + ":")
						print "--------------------"
						for m = 1 to FMATArr[mat].matParamCount do(
							blank1 = readlong f
							blank2 = readlong f
							matStringOff = readlong f
							blank3 = readlong f
							matParamFlag = readbyte f #unsigned
							matParamSize = readbyte f #unsigned
							matParamStart = readshort f #unsigned
							matParamUnk = readlong f
							matParamIndex1 = readshort f #unsigned
							matParamIndex2 = readshort f #unsigned
							blank3 = readlong f

							RtnMat = ftell f
							fseek f matStringOff #seek_set
							
							matParamStrLen = readshort f
							matParamString = ReadFixedString f matParamStrLen
							fseek f (FMATArr[mat].matParamOff + matParamStart) #seek_set
							
							-- Thanks, Tockdom!
							case matParamFlag of (
								default: (throw("Unknown param type!"))
								0x00: (matParamVar1 = readlong f
										case matParamVar1 of (
											0: (matParamVar1 = "False")
											1: (matParamVar1 = "True")
										)
									print (matParamString as string + ": " + matParamVar1 as string)
									) -- 1 boolean
								0x01: (matParamVar1 = readlong f; matParamVar2 = readlong f
										case matParamVar1 of (
											0: (matParamVar1 = "False")
											1: (matParamVar1 = "True")
										)
										case matParamVar2 of (
											0: (matParamVar2 = "False")
											1: (matParamVar2 = "True")
										)
									print (matParamString as string + ": " + matParamVar1 as string + ", " + matParamVar2 as string)
									) -- 2 booleans
								0x02: (matParamVar1 = readlong f; matParamVar2 = readlong f; matParamVar3 = readlong f
										case matParamVar1 of (
											0: (matParamVar1 = "False")
											1: (matParamVar1 = "True")
										)
										case matParamVar2 of (
											0: (matParamVar2 = "False")
											1: (matParamVar2 = "True")
										)
										case matParamVar3 of (
											0: (matParamVar3 = "False")
											1: (matParamVar3 = "True")
										)
									print (matParamString as string + ": " + matParamVar1 as string + ", " + matParamVar2 as string + ", " + matParamVar3 as string)
									) -- 3 booleans
								0x03: (matParamVar1 = readlong f; matParamVar2 = readlong f; matParamVar3 = readlong f; matParamVar4 = readlong f
										case matParamVar1 of (
											0: (matParamVar1 = "False")
											1: (matParamVar1 = "True")
										)
										case matParamVar2 of (
											0: (matParamVar2 = "False")
											1: (matParamVar2 = "True")
										)
										case matParamVar3 of (
											0: (matParamVar3 = "False")
											1: (matParamVar3 = "True")
										)
										case matParamVar4 of (
											0: (matParamVar4 = "False")
											1: (matParamVar4 = "True")
										)
									print (matParamString as string + ": " + matParamVar1 as string + ", " + matParamVar2 as string + ", " + matParamVar3 as string + ", " + matParamVar4 as string)
									) -- 4 booleans
								0x04: (matParamVar1 = readlong f
									print (matParamString as string + ": " + matParamVar1 as string)
									) -- 1 signed integer
								0x05: (matParamVar1 = readlong f; matParamVar2 = readlong f
									print (matParamString as string + ": " + matParamVar1 as string + ", " + matParamVar2 as string)
									) -- 2 signed integers
								0x06: (matParamVar1 = readlong f; matParamVar2 = readlong f; matParamVar3 = readlong f
									print (matParamString as string + ": " + matParamVar1 as string + ", " + matParamVar2 as string + ", " + matParamVar3 as string)
									) -- 3 signed integers
								0x07: (matParamVar1 = readlong f; matParamVar2 = readlong f; matParamVar3 = readlong f; matParamVar4 = readlong f
									print (matParamString as string + ": " + matParamVar1 as string + ", " + matParamVar2 as string + ", " + matParamVar3 as string + ", " + matParamVar4 as string)
									) -- 4 signed integers
								0x08: (matParamVar1 = readlong f #unsigned
									print (matParamString as string + ": " + matParamVar1 as string)
									) -- 1 unsigned integer
								0x09: (matParamVar1 = readlong f #unsigned; matParamVar2 = readlong f #unsigned
									print (matParamString as string + ": " + matParamVar1 as string + ", " + matParamVar2 as string)
									) -- 2 unsigned integers
								0x0A: (matParamVar1 = readlong f #unsigned; matParamVar2 = readlong f #unsigned; matParamVar3 = readlong f #unsigned
									print (matParamString as string + ": " + matParamVar1 as string + ", " + matParamVar2 as string + ", " + matParamVar3 as string)
									) -- 3 unsigned integers
								0x0B: (matParamVar1 = readlong f #unsigned; matParamVar2 = readlong f #unsigned; matParamVar3 = readlong f #unsigned; matParamVar4 = readlong f #unsigned
									print (matParamString as string + ": " + matParamVar1 as string + ", " + matParamVar2 as string + ", " + matParamVar3 as string + ", " + matParamVar4 as string)
									) -- 4 unsigned integers
								0x0C: (matParamVar1 = readfloat f
									print (matParamString as string + ": " + matParamVar1 as string)
									) -- 1x1 floats
								0x0D: (matParamVar1 = readfloat f; matParamVar2 = readfloat f
									print (matParamString as string + ": " + matParamVar1 as string + ", " + matParamVar2 as string)
									) -- 1x2 floats
								0x0E: (matParamVar1 = readfloat f; matParamVar2 = readfloat f; matParamVar3 = readfloat f
									print (matParamString as string + ": " + matParamVar1 as string + ", " + matParamVar2 as string + ", " + matParamVar3 as string)
									) -- 1x3 floats
								0x0F: (matParamVar1 = readfloat f; matParamVar2 = readfloat f; matParamVar3 = readfloat f; matParamVar4 = readfloat f
									print (matParamString as string + ": " + matParamVar1 as string + ", " + matParamVar2 as string + ", " + matParamVar3 as string + ", " + matParamVar4 as string)
									) -- 1x4 floats
								0x10: (matParamVarA1 = readfloat f; matParamVarA2 = readfloat f
									print (matParamString as string + ": " + matParamVarA1 as string + ", " + matParamVarA2 as string)
									) -- 2x1 floats
								0x11: (matParamVarA1 = readfloat f; matParamVarA2 = readfloat f
									matParamVarB1 = readfloat f; matParamVarB2 = readfloat f
									print (matParamString as string + ": " + matParamVarA1 as string + ", " + matParamVarA2 as string + " | " + matParamVarB1 as string + ", " + matParamVarB2 as string)
									) -- 2x2 floats
								0x12: (matParamVarA1 = readfloat f; matParamVarA2 = readfloat f
									matParamVarB1 = readfloat f; matParamVarB2 = readfloat f
									matParamVarC1 = readfloat f; matParamVarC2 = readfloat f
									print (matParamString as string + ": " + matParamVarA1 as string + ", " + matParamVarA2 as string + " | " + matParamVarB1 as string + ", " + matParamVarB2 as string + " | " + matParamVarC1 as string + ", " + matParamVarC2 as string)
									) -- 2x3 floats
								0x13: (matParamVarA1 = readfloat f; matParamVarA2 = readfloat f
									matParamVarB1 = readfloat f; matParamVarB2 = readfloat f
									matParamVarC1 = readfloat f; matParamVarC2 = readfloat f
									matParamVarD1 = readfloat f; matParamVarD2 = readfloat f
									print (matParamString as string + ": " + matParamVarA1 as string + ", " + matParamVarA2 as string + " | " + matParamVarB1 as string + ", " + matParamVarB2 as string + " | " + matParamVarC1 as string + ", " + matParamVarC2 as string + " | " + matParamVarD1 as string + ", " + matParamVarD2 as string)
									) -- 2x4 floats
								0x14: (matParamVarA1 = readfloat f; matParamVarA2 = readfloat f; matParamVarA3 = readfloat f
									print (matParamString as string + ": " + matParamVarA1 as string + ", " + matParamVarA2 as string + ", " + matParamVarA3 as string)
									) -- 3x1 floats
								0x15: (matParamVarA1 = readfloat f; matParamVarA2 = readfloat f; matParamVarA3 = readfloat f
									matParamVarB1 = readfloat f; matParamVarB2 = readfloat f; matParamVarB3 = readfloat f
									print (matParamString as string + ": " + matParamVarA1 as string + ", " + matParamVarA2 as string + ", " + matParamVarA3 as string + " | " + matParamVarB1 as string + ", " + matParamVarB2 as string + ", " + matParamVarB3 as string)
									) -- 3x2 floats
								0x16: (matParamVarA1 = readfloat f; matParamVarA2 = readfloat f; matParamVarA3 = readfloat f
									matParamVarB1 = readfloat f; matParamVarB2 = readfloat f; matParamVarB3 = readfloat f
									matParamVarC1 = readfloat f; matParamVarC2 = readfloat f; matParamVarC3 = readfloat f
									print (matParamString as string + ": " + matParamVarA1 as string + ", " + matParamVarA2 as string + ", " + matParamVarA3 as string + " | " + matParamVarB1 as string + ", " + matParamVarB2 as string + ", " + matParamVarB3 as string + " | " + matParamVarC1 as string + ", " + matParamVarC2 as string + ", " + matParamVarC3 as string)
									) -- 3x3 floats
								0x17: (matParamVarA1 = readfloat f; matParamVarA2 = readfloat f; matParamVarA3 = readfloat f
									matParamVarB1 = readfloat f; matParamVarB2 = readfloat f; matParamVarB3 = readfloat f
									matParamVarC1 = readfloat f; matParamVarC2 = readfloat f; matParamVarC3 = readfloat f
									matParamVarD1 = readfloat f; matParamVarD2 = readfloat f; matParamVarD3 = readfloat f
									print (matParamString as string + ": " + matParamVarA1 as string + ", " + matParamVarA2 as string + ", " + matParamVarA3 as string + " | " + matParamVarB1 as string + ", " + matParamVarB2 as string + ", " + matParamVarB3 as string + " | " + matParamVarC1 as string + ", " + matParamVarC2 as string + ", " + matParamVarC3 as string + " | " + matParamVarD1 as string + ", " + matParamVarD2 as string + ", " + matParamVarD3 as string)
									) -- 3x4 floats
								0x18: (matParamVarA1 = readfloat f; matParamVarA2 = readfloat f; matParamVarA3 = readfloat f; matParamVarA4 = readfloat f
									print (matParamString as string + ": " + matParamVarA1 as string + ", " + matParamVarA2 as string + ", " + matParamVarA3 as string + ", " + matParamVarA4 as string)
									) -- 4x1 floats
								0x19: (matParamVarA1 = readfloat f; matParamVarA2 = readfloat f; matParamVarA3 = readfloat f; matParamVarA4 = readfloat f
									matParamVarB1 = readfloat f; matParamVarB2 = readfloat f; matParamVarB3 = readfloat f; matParamVarB4 = readfloat f
									print (matParamString as string + ": " + matParamVarA1 as string + ", " + matParamVarA2 as string + ", " + matParamVarA3 as string + ", " + matParamVarA4 as string + " | " + matParamVarB1 as string + ", " + matParamVarB2 as string + ", " + matParamVarB3 as string + ", " + matParamVarB4 as string)
									) -- 4x2 floats
								0x1A: (matParamVarA1 = readfloat f; matParamVarA2 = readfloat f; matParamVarA3 = readfloat f; matParamVarA4 = readfloat f
									matParamVarB1 = readfloat f; matParamVarB2 = readfloat f; matParamVarB3 = readfloat f; matParamVarB4 = readfloat f
									matParamVarC1 = readfloat f; matParamVarC2 = readfloat f; matParamVarC3 = readfloat f; matParamVarC4 = readfloat f
									print (matParamString as string + ": " + matParamVarA1 as string + ", " + matParamVarA2 as string + ", " + matParamVarA3 as string + ", " + matParamVarA4 as string + " | " + matParamVarB1 as string + ", " + matParamVarB2 as string + ", " + matParamVarB3 as string + ", " + matParamVarB4 as string + " | " + matParamVarC1 as string + ", " + matParamVarC2 as string + ", " + matParamVarC3 as string + ", " + matParamVarC4 as string)
									) -- 4x3 floats
								0x1B: (matParamVarA1 = readfloat f; matParamVarA2 = readfloat f; matParamVarA3 = readfloat f; matParamVarA4 = readfloat f
									matParamVarB1 = readfloat f; matParamVarB2 = readfloat f; matParamVarB3 = readfloat f; matParamVarB4 = readfloat f
									matParamVarC1 = readfloat f; matParamVarC2 = readfloat f; matParamVarC3 = readfloat f; matParamVarC4 = readfloat f
									matParamVarD1 = readfloat f; matParamVarD2 = readfloat f; matParamVarD3 = readfloat f; matParamVarD4 = readfloat f
									print (matParamString as string + ": " + matParamVarA1 as string + ", " + matParamVarA2 as string + ", " + matParamVarA3 as string + ", " + matParamVarA4 as string + " | " + matParamVarB1 as string + ", " + matParamVarB2 as string + ", " + matParamVarB3 as string + ", " + matParamVarB4 as string + " | " + matParamVarC1 as string + ", " + matParamVarC2 as string + ", " + matParamVarC3 as string + ", " + matParamVarC4 as string + " | " + matParamVarD1 as string + ", " + matParamVarD2 as string + ", " + matParamVarD3 as string + ", " + matParamVarD4 as string)
									) -- 4x4 floats
								0x1C: (matParamSRTXScl = readfloat f; matParamSRTYScl = readfloat f; matParamSRTRot = readfloat f; matParamSRTXTrs = readfloat f; matParamSRTYTrs = readfloat f
									print (matParamString as string + ": 2D Scale X = " + matParamSRTXScl as string + ", Y = " + matParamSRTYScl as string + " | Rotate = " + matParamSRTRot as string + " | Translation X = " + matParamSRTXTrs as string + ", Y = " + matParamSRTYTrs as string)
									) -- 2D SRT
								0x1D: (matParamSRTXScl = readfloat f; matParamSRTYScl = readfloat f; matParamSRTZScl = readfloat f; matParamSRTXRot = readfloat f; matParamSRTYRot = readfloat f; matParamSRTZRot = readfloat f; matParamSRTXTrs = readfloat f; matParamSRTYTrs = readfloat f; matParamSRTZTrs = readfloat f
									print (matParamString as string + ": 3D Scale X = " + matParamSRTXScl as string + ", Y = " + matParamSRTYScl as string + ", Z = " + matParamSRTZScl as string + " | Rotate X = " + matParamSRTXRot as string + ", Y = " + matParamSRTYRot as string + ", Z = " + matParamSRTZRot as string + " | Translation X = " + matParamSRTXTrs as string + ", Y = " + matParamSRTYTrs as string + ", Z = " + matParamSRTZTrs as string)
									) -- 3D SRT
								0x1E: (matParamAxis = readlong f; matParamSRTXScl = readfloat f; matParamSRTYScl = readfloat f; matParamSRTRot = readfloat f; matParamSRTXTrs = readfloat f; matParamSRTYTrs = readfloat f
									case matParamAxis of(
										0: (matParamAxis = "Maya")
										1: (matParamAxis = "3DS Max")
										2: (matParamAxis = "Softimage")
									)
									print (matParamString as string + ": Scale X = " + matParamSRTXScl as string + ", Y = " + matParamSRTYScl as string + " | Rotate = " + matParamSRTRot as string + " | Translation X = " + matParamSRTXTrs as string + ", Y = " + matParamSRTYTrs as string + " | Axis: " + matParamAxis as string)
									) -- Texture SRT
								0x1F: (matParamAxis = readlong f; matParamSRTXScl = readfloat f; matParamSRTYScl = readfloat f; matParamSRTRot = readfloat f; matParamSRTXTrs = readfloat f; matParamSRTYTrs = readfloat f; matParamSRTMatPtr = readlong f
									case matParamAxis of(
										0: (matParamAxis = "Maya")
										1: (matParamAxis = "3DS Max")
										2: (matParamAxis = "Softimage")
									)
									print (matParamString as string + ": Scale X = " + matParamSRTXScl as string + ", Y = " + matParamSRTYScl as string + " | Rotate = " + matParamSRTRot as string + " | Translation X = " + matParamSRTXTrs as string + ", Y = " + matParamSRTYTrs as string + " | Axis: " + matParamAxis as string + " | Matrix Pointer: " + matParamSRTMatPtr as string)
									) -- Texture SRT + Matrix
							)

							fseek f RtnMat#seek_set
						)

						fseek f Rtn #seek_set
					)

				)

				-- F_Skeleton Header --
				fseek f fmdl_info.fsklOff#seek_set
				if verNumB != 8 then(
					fskl_info=(fsklh \
						fskl: (ReadFixedString f 4) \
						UnkOffset1A: (ReadLong f) \
						UnkOffset1B: (ReadLong f) \
						padding: (ReadLong f) \
						boneIndxOff: (ReadLong f) \
						padding: (ReadLong f) \
						boneArrOff: (ReadLong f) \
						padding: (ReadLong f) \
						invIndxArrOff: (ReadLong f) \
						padding: (ReadLong f) \
						invMatrArrOff: (ReadLong f) \
						padding: (ReadLong f) \
						padding: (ReadLong f) \
						padding: (ReadLong f) \
						UnkOffset5: (ReadLong f) \
						boneArrCount: (ReadShort f) \
						invIndxArrCount: (ReadShort f) \
						exIndxCount: (ReadShort f) \
						UnkCount2: (ReadShort f) \
						padding: (ReadLong f) \
					)
				) else (
					fskl_info=(fsklh \
						fskl: (ReadFixedString f 4) \
						UnkOffset1A: (ReadLong f) \
						UnkOffset1B: (ReadLong f) \
						padding: (ReadLong f) \
						boneIndxOff: (ReadLong f) \
						padding: (ReadLong f) \
						boneArrOff: (ReadLong f) \
						padding: (ReadLong f) \
						invIndxArrOff: (ReadLong f) \
						padding: (ReadLong f) \
						invMatrArrOff: (ReadLong f) \
						padding: (ReadLong f) \
						padding: (ReadLong f) \
						padding: (ReadLong f) \
						padding: (ReadLong f) \
						padding: (ReadLong f) \
						padding: (ReadLong f) \
						padding: (ReadLong f) \
						UnkOffset5: (ReadLong f) \
						boneArrCount: (ReadShort f) \
						invIndxArrCount: (ReadShort f) \
						exIndxCount: (ReadShort f) \
						UnkCount2: (ReadShort f) \
						padding: (ReadLong f) \
					)
				)
				append FSKLArr(fskl_info)
				printDebug fskl_info

				-- Node Setup --
				fseek f fskl_info.invIndxArrOff #seek_set
				for nodes = 1 to (fskl_info.invIndxArrCount + fskl_info.exIndxCount) do(
					NodeID = ReadShort f + 1
					append Node_Array NodeID
				)

				-- F_Shape Header --
				fseek f fmdl_info.fshpIndx#seek_set
				For shp = 1 to fmdl_info.fshpCount Do(
					fshp_info=(fshph \
						fshp: (ReadFixedString f 4) \
						padding: (ReadLong f) \
						padding: (ReadLong f) \
						padding: (ReadLong f) \
						polyNameOff: (ReadLong f) \
						padding: (ReadLong f) \
						fvtxOff: (ReadLong f) \
						padding: (ReadLong f) \
						lodMdlOff: (ReadLong f) \
						padding: (ReadLong f) \
						Unk3Off: (ReadLong f) \
						padding: (ReadLong f) \
						padding: (ReadLong f) \
						padding: (ReadLong f) \
						padding: (ReadLong f) \
						padding: (ReadLong f) \
						Unk4Off: (ReadLong f) \
						padding: (ReadLong f) \
						Unk5Off: (ReadLong f) \
						padding: (ReadLong f) \
						padding: (ReadLong f) \
						padding: (ReadLong f) \
						UnkShort1: (ReadShort f) \
						UnkShort2: (ReadShort f) \
						fvtxIndx: (ReadShort f +1) \
						fmatIndx: (ReadShort f +1) \
						fsklIndx: (ReadShort f +1) \
						sectIndx: (ReadShort f +1) \
						fsklIndxArrCount: (ReadShort f) \
						matrFlag: (ReadByte f) \
						lodMdlCount: (ReadByte f) \
						padding: (ReadLong f) \
						padding: (ReadLong f) \
-- 						visGrpCount: (ReadLong f) \
-- 						visGrpIndex: (ReadShort f +1) \
-- 						fsklIndxArrOff: (ReadLong f) \
-- 						visGrpNodeOff: (ReadLong f) \
-- 						visGrpRangeOff: (ReadLong f) \
-- 						visGrpIndxOff: (ReadLong f) \
					)

					append FSHPArr(fshp_info)
					printDebug fshp_info
				)

				-- F_Model Bone Creation --
				fseek f fskl_info.boneArrOff#seek_set
				For bn = 1 to fskl_info.boneArrCount Do(
				if verNumB != 8 then(
					boneData=( bdata \
						bNameOff: (ReadLong f) \
						padding: (ReadLong f) \
						padding: (ReadLong f) \
						padding: (ReadLong f) \
						padding: (ReadLong f) \
						padding: (ReadLong f) \
						bIndx: (ReadShort f +1) \
						parIndx1: (ReadShort f +1) \
						parIndx2: (ReadShort f +1) \
						parIndx3: (ReadShort f +1) \
						parIndx4: (ReadShort f +1) \
						u1: (ReadShort f) \
						bFlags: (ReadShort f) \
						u2: (ReadShort f) \
						scaleX: (ReadFloat f) \
						scaleY: (ReadFloat f) \
						scaleZ: (ReadFloat f) \
						rotX: (ReadFloat f) \
						rotY: (ReadFloat f) \
						rotZ: (ReadFloat f) \
						rotW: (ReadFloat f) \
						posX: (ReadFloat f) \
						posY: (ReadFloat f) \
						posZ: (ReadFloat f) \
					)
				) else (
					boneData=( bdata \
						bNameOff: (ReadLong f) \
						padding: (ReadLong f) \
						padding: (ReadLong f) \
						padding: (ReadLong f) \
						padding: (ReadLong f) \
						padding: (ReadLong f) \
						padding: (ReadLong f) \
						padding: (ReadLong f) \
						padding: (ReadLong f) \
						padding: (ReadLong f) \
						bIndx: (ReadShort f +1) \
						parIndx1: (ReadShort f +1) \
						parIndx2: (ReadShort f +1) \
						parIndx3: (ReadShort f +1) \
						parIndx4: (ReadShort f +1) \
						u1: (ReadShort f) \
						bFlags: (ReadShort f) \
						u2: (ReadShort f) \
						scaleX: (ReadFloat f) \
						scaleY: (ReadFloat f) \
						scaleZ: (ReadFloat f) \
						rotX: (ReadFloat f) \
						rotY: (ReadFloat f) \
						rotZ: (ReadFloat f) \
						rotW: (ReadFloat f) \
						posX: (ReadFloat f) \
						posY: (ReadFloat f) \
						posZ: (ReadFloat f) \
					)
				)

					if boneData.u2 == 0x0001 then(tfm = inverse (scaleMatrix [boneData.scaleX,boneData.scaleY,boneData.scaleZ])
						tfm = tfm * (quat boneData.rotX boneData.rotY boneData.rotZ boneData.rotW) as matrix3
						tfm = inverse(tfm)
					)else(tfm = scaleMatrix [boneData.scaleX,boneData.scaleY,boneData.scaleZ]
					tfm = tfm * (eulerangles (boneData.rotX*(180/pi)) (boneData.rotY*(180/pi)) (boneData.rotZ*(180/pi))) as matrix3)
					tfm.row4 = [boneData.posX,boneData.posY,boneData.posZ]

					newBone = bonesys.createbone \
						tfm.row4	\
						(tfm.row4 + 0.01 * (normalize tfm.row1)) \
						(normalize tfm.row3)

					Rtn = ftell f
					fseek f boneData.bNameOff#seek_set
					fseek f 0x02 #seek_cur
					boneName = ReadString f
					if FMDLList_array.count > 1 do(boneName += "_" + x as string)
					fseek f Rtn#seek_set
					newBone.name = boneName
					newBone.width = 0.03
					newBone.height = 0.03
					newBone.transform = tfm
					newBone.setBoneEnable false 0
					newBone.wirecolor = yellow
					newbone.showlinks = true
					newBone.pos.controller = TCB_position()
					newBone.rotation.controller = TCB_rotation()

					If boneData.parIndx1 != 0 Do(
						newBone.parent = BoneArray[boneData.parIndx1]
						newBone.transform *= BoneArray[boneData.parIndx1].transform
					)

					append BoneArray newBone
					append BoneFixArray newBone.transform
				)

				-- Hacky_RLT reading since we only need one bit of information from it right now.
				fseek f 0x18 #seek_set
				RLTOff = ReadLong f
				fseek f RLTOff #seek_set
				fseek f 0x30 #seek_cur
				DataStart = ReadLong f
				
				-- Mesh Building --

				For m = 1 to FSHPArr.count Do(
				Vert_Array = #()
				Normal_Array = #()
				UV_Array = #()
				UV2_Array = #()
				UV3_Array = #()
				UV4_Array = #()
				UV5_Array = #()
				Color_Array = #()
				Alpha_Array = #()
				AttrArr = #()
				BuffArr = #()
				B1_array = #()
				B2_array = #()
				W1_array = #()
				W2_array = #()
				Weight_array = #()

				fseek f FSHPArr[m].polyNameOff#seek_set
				fseek f 0x02 #seek_cur
				MeshName = ReadString f

				fseek f FVTXArr[FSHPArr[m].fvtxIndx].attArrOff#seek_set
				printDebug("Building polygon " + MeshName + "...")
				For att = 1 to FVTXArr[FSHPArr[m].fvtxIndx].attCount Do(
					AttTypeOff = ReadLong f
					Padding = ReadLong f 
					Rtn1 = ftell f
					fseek f AttTypeOff#seek_set
					AttTypeLength = ReadShort f #unsigned
					AttType = ReadFixedString f AttTypeLength
					fseek f Rtn1#seek_set
					vertType = ReadBEShort f
					Padding = ReadShort f 
					buffOff = ReadShort f
					buffIndx = ReadShort f+1
					append AttrArr (attdata attName: AttType buffIndx: buffIndx buffOff: buffOff vertType: vertType)
				)
				printDebug AttrArr

				For buf = 1 to FVTXArr[FSHPArr[m].fvtxIndx].buffCount Do(
					fseek f (FVTXArr[FSHPArr[m].fvtxIndx].vtxBuffSizeOff + ((buf - 1) * 0x10)) #seek_set
					BuffSize = ReadLong f
					fseek f (FVTXArr[FSHPArr[m].fvtxIndx].vtxStrideSizeOff + ((buf - 1) * 0x10)) #seek_set
					StrideSize = ReadLong f
					if buf == 1 Do(DataOffset = (DataStart + FVTXArr[FSHPArr[m].fvtxIndx].buffOff))
					if buf > 1 Do(DataOffset = BuffArr[buf - 1].DataOffset + BuffArr[buf - 1].BuffSize)
					if mod (DataOffset) 8 != 0 Do(DataOffset = DataOffset + (8 - (mod (DataOffset) 8)))
					append BuffArr (buffData buffSize: BuffSize strideSize: StrideSize dataOffset: DataOffset)
				)
				printDebug BuffArr
				
				For attr = 1 to AttrArr.count Do(
					locPoint = ((BuffArr[AttrArr[attr].buffIndx].dataOffset) + (AttrArr[attr].buffOff))
					fseek f locPoint #seek_set
					if attr == 1 do(printDebug("Vertex buffer starts at 0x" + bit.intAsHex(ftell f) as string))
					For v = 1 to FVTXArr[FSHPArr[m].fvtxIndx].vertCount Do(
						VertStart = (ftell f + (BuffArr[AttrArr[attr].buffIndx].strideSize))
						case AttrArr[attr].vertType of (
							default: (
								enableSceneRedraw()
								throw("Unknown type!")
							)
							-- 0x01 - Unsigned integers
							0x0102:(
								-- 1 byte integer, unsigned
								var1 = ReadByte f #unsigned
								var2 = 0
								var3 = 0
								var4 = 0
							)
							0x0109:(
								-- 2 byte integers, unsigned
								var1 = ReadByte f #unsigned
								var2 = ReadByte f #unsigned
								var3 = 0
								var4 = 0
							)
							0x010A:(
								-- 3 byte integers, unsigned [ESTIMATED]
								var1 = ReadByte f #unsigned
								var2 = ReadByte f #unsigned
								var3 = ReadByte f #unsigned
								var4 = 0
							)
							0x010B:(
								-- 4 byte integers, unsigned
								var1 = ReadByte f #unsigned
								var2 = ReadByte f #unsigned
								var3 = ReadByte f #unsigned
								var4 = ReadByte f #unsigned
							)
							0x0112:(
								-- 2 short integers, unsigned
								var1 = ReadShort f #unsigned
								var2 = ReadShort f #unsigned
								var3 = 0
								var4 = 0
							)
							0x0115:(
								-- 4 short integers, unsigned [ESTIMATED]
								var1 = ReadShort f #unsigned
								var2 = ReadShort f #unsigned
								var3 = ReadShort f #unsigned
								var4 = ReadShort f #unsigned
							)
							0x0117:(
								-- 2 long integers, unsigned
								var1 = ReadLong f #unsigned
								var2 = ReadLong f #unsigned
								var3 = 0
								var4 = 0
							)
							0x0118:(
								-- 3 long integers, unsigned [ESTIMATED]
								var1 = ReadLong f #unsigned
								var2 = ReadLong f #unsigned
								var3 = ReadLong f #unsigned
								var4 = 0
							)
							0x0119:(
								-- 4 long integers, unsigned [ESTIMATED]
								var1 = ReadLong f #unsigned
								var2 = ReadLong f #unsigned
								var3 = ReadLong f #unsigned
								var4 = ReadLong f #unsigned
							)

							-- 0x02 - Signed integers
							0x0202:(
								-- 1 byte integer, signed
								var1 = ReadByte f
								var2 = 0
								var3 = 0
								var4 = 0
							)
							0x0209:(
								-- 2 byte integers, signed
								var1 = ReadByte f
								var2 = ReadByte f
								var3 = 0
								var4 = 0
							)
							0x020A:(
								-- 3 byte integers, signed [ESTIMATED]
								var1 = ReadByte f
								var2 = ReadByte f
								var3 = ReadByte f
								var4 = 0
							)
							0x020B:(
								-- 4 byte integers, signed
								var1 = ReadByte f
								var2 = ReadByte f
								var3 = ReadByte f
								var4 = ReadByte f
							)
							0x020E:(
								-- 3 10-bit values, signed
								vars = ReadLong f
								var1 = sign10(bit.and (vars) 0x3FF) as float / 511
								var2 = sign10(bit.and (bit.shift vars -10) 0x3FF) as float / 511
								var3 = sign10(bit.and (bit.shift vars -20) 0x3FF) as float / 511
								var4 = 0
							)
							0x0212:(
								-- 2 short integers, signed
								var1 = ReadShort f
								var2 = ReadShort f
								var3 = 0
								var4 = 0
							)
							0x0215:(
								-- 4 short integers, signed
								var1 = ReadShort f
								var2 = ReadShort f
								var3 = ReadShort f
								var4 = ReadShort f
							)
							0x0217:(
								-- 2 long integers, signed
								var1 = ReadLong f
								var2 = ReadLong f
								var3 = 0
								var4 = 0
							)
							0x0218:(
								-- 3 long integers, signed
								var1 = ReadLong f
								var2 = ReadLong f
								var3 = ReadLong f
								var4 = 0
							)
							0x0219:(
								-- 4 long integers, signed
								var1 = ReadLong f
								var2 = ReadLong f
								var3 = ReadLong f
								var4 = ReadLong f
							)

							-- 0x03 - Unsigned ints (bone IDs only)
							0x0302:(
								-- 1 byte integer, unsigned, bone IDs
								var1 = ReadByte f #unsigned + 1
								var2 = 1
								var3 = 1
								var4 = 1
							)
							0x0309:(
								-- 2 byte integers, unsigned, bone IDs
								var1 = ReadByte f #unsigned + 1
								var2 = ReadByte f #unsigned + 1
								var3 = 1
								var4 = 1
							)
							0x030A:(
                                -- 3 byte integers, unsigned, bone IDs
                                var1 = ReadByte f #unsigned + 1
                                var2 = ReadByte f #unsigned + 1
                                var3 = ReadByte f #unsigned + 1
                                var4 = 1
                            )
							0x030B:(
								-- 4 byte integers, unsigned, bone IDs
								var1 = ReadByte f #unsigned + 1
								var2 = ReadByte f #unsigned + 1
								var3 = ReadByte f #unsigned + 1
								var4 = ReadByte f #unsigned + 1
							)
							0x0312:(
								-- 2 short integers, unsigned, bone IDs
								var1 = ReadShort f #unsigned + 1
								var2 = ReadShort f #unsigned + 1
								var3 = 1
								var4 = 1
							)
							0x0315:(
								-- 4 short integers, unsigned, bone IDs
								var1 = ReadShort f #unsigned + 1
								var2 = ReadShort f #unsigned + 1
								var3 = ReadShort f #unsigned + 1
								var4 = ReadShort f #unsigned + 1
							)
							0x0317:(
								-- 2 long integers, unsigned, bone IDs
								var1 = ReadLong f #unsigned + 1
								var2 = ReadLong f #unsigned + 1
								var3 = 1
								var4 = 1
							)
							0x0318:(
								-- 3 long integers, unsigned, bone IDs
								var1 = ReadLong f + 1
								var2 = ReadLong f + 1
								var3 = ReadLong f + 1
								var4 = 1
							)
							0x0319:(
								-- 4 long integers, unsigned, bone IDs
								var1 = ReadLong f + 1
								var2 = ReadLong f + 1
								var3 = ReadLong f + 1
								var4 = ReadLong f + 1
							)

							-- 0x05 - Floats
							0x0512:(
								-- 2 half-floats
								var1 = readHalfFloat f
								var2 = readHalfFloat f
								var3 = 0
								var4 = 0
							)
							0x0515:(
								-- 4 half-floats
								var1 = ReadHalfFloat f
								var2 = ReadHalfFloat f
								var3 = ReadHalfFloat f
								var4 = ReadHalfFloat f
							)
							0x0517:(
								-- 2 floats
								var1 = ReadFloat f
								var2 = ReadFloat f
								var3 = 0
								var4 = 0
							)
							0x0518:(
								-- 3 floats
								var1 = ReadFloat f
								var2 = ReadFloat f
								var3 = ReadFloat f
								var4 = 0
							)
							0x0519:(
								-- 4 floats
								var1 = ReadFloat f
								var2 = ReadFloat f
								var3 = ReadFloat f
								var4 = ReadFloat f
							)
							)

						case of (
							--Vertex Info--
							(AttrArr[attr].attName == "_p0"):(
								append vert_Array[var1,var2,var3]
							)
							--Color Info--
							(AttrArr[attr].attName == "_c0"):(
								case of (
									(AttrArr[attr].vertType == 0x010B):(
										var1 = vRange 0 254 (var1 * 2)
										var2 = vRange 0 254 (var2 * 2)
										var3 = vRange 0 254 (var3 * 2)
										var4 = vRange 0 1 (var4 as float / 127)
									)
									(AttrArr[attr].vertType == 0x0515):(
										var1 = vRange 0 255 (var1 * 255)
										var2 = vRange 0 255 (var2 * 255)
										var3 = vRange 0 255 (var3 * 255)
										var4 = vRange 0 1 (var4 as float)
									)
								)
								append Color_Array[var1,var2,var3]
								append Alpha_Array var4
							)
							--Normals Info--
							(AttrArr[attr].attName == "_n0"):(
								case of (
									(AttrArr[attr].vertType == 0x010B):(
										fseek f (AttrArr[attr].buffOff)#seek_cur
										var1 = var1 as float / 127
										var2 = var2 as float / 127
										var3 = var3 as float / 127
										var4 = var4 as float / 127
									)
								)
								append Normal_Array[var1,var2,var3]
							)
							--Tangent Info--
							--Binormals Info--
							--UV Info--
							(AttrArr[attr].attName == "detail"):(
								var1 *= 2
								var2 *= 2
								append UV3_array [var1,var2,0]
							)
							(AttrArr[attr].attName == "_u0" or AttrArr[attr].attName == "color" or AttrArr[attr].attName == "_u1" or AttrArr[attr].attName == "_u2" or AttrArr[attr].attName == "_u3" or AttrArr[attr].attName == "_u4" or AttrArr[attr].attName == "All"):(
								case AttrArr[attr].vertType of (
									default:(var2 = (var2 * -1) + 1)
									0x0109:(
										var1 = (var1 as float / 255)
										var2 = ((var2 as float / 255) * -1) + 1
									)
									0x0112:(
										var1 = (var1 as float / 65535)
										var2 = ((var2 as float / 65535) * -1) + 1
									)
									0x0209:(
										var1 = (var1 as float / 127)
										var2 = ((var2 as float / 127) * -1) + 1
									)
									0x0212:(
										var1 = (var1 as float / 32767)
										var2 = ((var2 as float / 32767) * -1) + 1
										case of (
											(var1 < -1): var1 += 2
											(var1 > 1): var1 -= 2
										)
										case of (
											(var2 < 0): var2 += 2
											(var2 > 2): var2 -= 2
										)
									)
								)
								case of(
									(AttrArr[attr].attName == "_u0" or AttrArr[attr].attName == "color"): append UV_Array[var1,var2,0]
									(AttrArr[attr].attName == "_u1"): append UV2_Array[var1,var2,0]
									(AttrArr[attr].attName == "_u2"): append UV3_Array[var1,var2,0]
									(AttrArr[attr].attName == "_u3"): append UV4_Array[var1,var2,0]
									(AttrArr[attr].attName == "_u4" or AttrArr[attr].attName == "All"): append UV5_Array[var1,var2,0]
								)
							)

							--BlendIndex Info--
							(AttrArr[attr].attName == "_i0" or AttrArr[attr].attName == "_i1"):(
								bone1 = Node_array[var1]
								bone2 = Node_array[var2]
								bone3 = Node_array[var3]
								bone4 = Node_array[var4]
								case AttrArr[attr].attName of (
									"_i0": append B1_Array (Bone_Info_Struct bone1:bone1 bone2:bone2 bone3:bone3 bone4:bone4)
									"_i1": append B2_Array (Bone_Info_Struct bone1:bone1 bone2:bone2 bone3:bone3 bone4:bone4)
								)
							)
							-- BlendWeight Info --
							(AttrArr[attr].attName == "_w0" or AttrArr[attr].attName == "_w1"):(
								case AttrArr[attr].vertType of (
									default: (
										weight1 = var1
										weight2 = var2
										weight3 = var3
										weight4 = var4
									)
									0x0102:(
										weight1 = var1 as float / 255
										weight2 = 0
										weight3 = 0
										weight4 = 0
									)
									0x0109:(
										weight1 = var1 as float / 255
										weight2 = var2 as float / 255
										weight3 = 0
										weight4 = 0
									)
									0x010B:(
										weight1 = var1 as float / 255
										weight2 = var2 as float / 255
										weight3 = var3 as float / 255
										weight4 = var4 as float / 255
										if weight4 >= 1 do(weight4 = 0)
									)
									0x0518:(
										weight1 = var1
										weight2 = var2
										weight3 = var3
										weight4 = 0
									)
								)
								case AttrArr[attr].attName of (
									"_w0": append W1_Array (Weight_Info_Struct weight1:weight1 weight2:weight2 weight3:weight3 weight4:weight4)
									"_w1": append W2_Array (Weight_Info_Struct weight1:weight1 weight2:weight2 weight3:weight3 weight4:weight4)
								)
							)
						)

						fseek f VertStart #seek_set
					) -- Close Vert Read Loop
				) -- Close Attributes Loop

				If UV_Array.count == 0 Do(
					For uv = 1 to Vert_array.count Do append UV_Array[0,0,0]
				)

				If Color_Array.count == 0 Do(
					For ca = 1 to Vert_array.count Do (
						append Color_Array[255,255,255]
						append Alpha_Array 1
					)
				)

				If W1_Array.count == 0 Do(
					For v = 1 to B1_array.count Do(
						append W1_Array (Weight_Info_Struct weight1:1 weight2:0 weight3:0 weight4:0)
					)
				)

				If B2_Array.count == 0 Do(
					For v = 1 to B1_array.count Do(
						append B2_Array (Bone_Info_Struct bone1:1 bone2:1 bone3:1 bone4:1)
						append W2_Array (Weight_Info_Struct weight1:0 weight2:0 weight3:0 weight4:0)
					)
				)

				for b = 1 to W1_Array.count Do(
					w = (weight_data boneids:#() weights:#())
					maxweight = 0
					
					if W1_array[b].Weight1 != 0 do maxweight += W1_array[b].Weight1
					if W1_array[b].Weight2 != 0 do maxweight += W1_array[b].Weight2
					if W1_array[b].Weight3 != 0 do maxweight += W1_array[b].Weight3
					if W1_array[b].Weight4 != 0 do maxweight += W1_array[b].Weight4
					if W2_array[b].Weight1 != 0 do maxweight += W2_array[b].Weight1
					if W2_array[b].Weight2 != 0 do maxweight += W2_array[b].Weight2
					if W2_array[b].Weight3 != 0 do maxweight += W2_array[b].Weight3
					if W2_array[b].Weight4 != 0 do maxweight += W2_array[b].Weight4

					if maxweight != 0 then(
						if W1_array[b].Weight1 != 0 then(
							w1 = W1_array[b].Weight1 as float
							append w.boneids (B1_array[b].Bone1)
							append w.weights (w1)
						)
						if W1_array[b].Weight2 != 0 then(
							w2 = W1_array[b].Weight2 as float
							append w.boneids (B1_array[b].Bone2)
							append w.weights (w2)
						)
						if W1_array[b].Weight3 != 0 then(
							w3 = W1_array[b].Weight3 as float
							append w.boneids (B1_array[b].Bone3)
							append w.weights (w3)
						)
						if W1_array[b].Weight4 != 0 then(
							w4 = W1_array[b].Weight4 as float
							append w.boneids (B1_array[b].Bone4)
							append w.weights (w4)
						)
						if W2_array[b].Weight1 != 0 then(
							w5 = W2_array[b].Weight1 as float
							append w.boneids (B2_array[b].Bone1)
							append w.weights (w5)
						)
						if W2_array[b].Weight2 != 0 then(
							w6 = W2_array[b].Weight2 as float
							append w.boneids (B2_array[b].Bone2)
							append w.weights (w6)
						)
						if W2_array[b].Weight3 != 0 then(
							w7 = W2_array[b].Weight3 as float
							append w.boneids (B2_array[b].Bone3)
							append w.weights (w7)
						)
						if W2_array[b].Weight4 != 0 then(
							w8 = W2_array[b].Weight4 as float
							append w.boneids (B2_array[b].Bone4)
							append w.weights (w8)
						)
					)
					append Weight_array w
				)

				fseek f FSHPArr[m].lodMdlOff#seek_set
				if LODs == 2 do FSHPArr[m].lodMdlCount = 1
				for l = 1 to FSHPArr[m].lodMdlCount do(
					Face_Array = #()

					fseek f 32 #seek_cur
					FaceBuffer = (ReadLong f + DataStart)
					fseek f 4 #seek_cur
					faceType = (ReadLong f)
					FaceCount = (ReadLong f)
					PolyStart = (ReadLong f)
					fseek f 4 #seek_cur

					LODRet = (ftell f)

					fseek f FaceBuffer#seek_set

						case of (
							(faceType == 1):(
							FaceCount = (FaceCount/3)
							For face = 1 to FaceCount Do(
								fa = ((ReadShort f #unsigned) + 1 + PolyStart)
								fb = ((ReadShort f #unsigned) + 1 + PolyStart)
								fc = ((ReadShort f #unsigned) + 1 + PolyStart)
								append Face_Array[fa,fb,fc]
							)
							)
							(faceType == 2):(
							FaceCount = (FaceCount/3)
							For face = 1 to FaceCount Do(
								fa = ((ReadLong f) + 1 + PolyStart)
								fb = ((ReadLong f) + 1 + PolyStart)
								fc = ((ReadLong f) + 1 + PolyStart)
								append Face_Array[fa,fb,fc]
							)
							)
						)

					local Cac=Color_Array.count
					local Vac=Vert_Array.count
					local Fac=Face_array.count
					local Nac=Normal_array.count
					local Bac=BoneArray.count
					local Wac=Weight_array.count

					msh = mesh vertices:Vert_array faces:Face_array
					msh.numTVerts = Vac
					setNumCPVVerts msh msh.numTVerts
					setCVertMode msh true
					setShadeCVerts msh true
					defaultVCFaces msh
					buildTVFaces msh
					for j = 1 to Cac do setvertcolor msh j Color_array[j]
					for j = 1 to Cac do(meshop.setVertAlpha msh -2 j Alpha_array[j])

					If Vac == UV_Array.count Do(
						for j = 1 to Vac do setTVert msh j UV_array[j]
						for j = 1 to Fac do setTVFace msh j Face_array[j]
					)
					for j = 1 to msh.numfaces do setFaceSmoothGroup msh j 1

					msh.name = MeshName + (if FSHPArr[m].lodMdlCount == 1 then "" else " (LOD: " + l as string + ")")
					msh.material = buildMatSwitch \
						matName:FMATNameArr[FSHPArr[m].fmatIndx] \
						tSelOff:FMATArr[FSHPArr[m].fmatIndx].texSelOff \
						rtnTexAS:FMATArr[FSHPArr[m].fmatIndx].texAttIndxOff \
						tCount:FMATArr[FSHPArr[m].fmatIndx].texSelCount \
						tFormat:TexF[TexFormat] \
						tPath:TexP[TexPath]

					max modify mode
					select msh

					addmodifier msh (Edit_Normals()) ui:off
					msh.Edit_Normals.MakeExplicit selection:#{1..Normal_array.count}
					EN_convertVS = msh.Edit_Normals.ConvertVertexSelection
					EN_setNormal = msh.Edit_Normals.SetNormal
					normID = #{}
					for v = 1 to Nac do(
						free normID
						EN_convertVS #{v} &normID
						for id in normID do EN_setNormal id Normal_array[v]
					)

					if Bac > 0 do(
						if FSHPArr[m].matrFlag == 0 then(
							$.transform = BoneFixArray[FSHPArr[m].fsklIndx]
							if RigModel != 2 do(
								skinMod = skin()
								addModifier msh skinMod
								maxbone = getnodebyname BoneArray[FSHPArr[m].fsklIndx].name
								skinOps.addBone skinMod maxbone 0
							)
						)else(
							if RigModel != 2 do(
								skinMod = skin()
								boneIDMap = #()
								addModifier msh skinMod
								msh.Skin.weightAllVertices = false

								if FSHPArr[m].matrFlag == 1 do(for b in BoneArray do b.transform = matrix3 1)

								for i = 1 to Bac do(
									maxbone = getnodebyname BoneArray[i].name
									skinOps.addBone skinMod maxbone (if i != Bac then 0 else 1)
								)

								local numSkinBones = skinOps.GetNumberBones skinMod
								for i = 1 to numSkinBones do(
									local boneName = skinOps.GetBoneName skinMod i 0
									for j = 1 to Bac do(
										if boneName == BoneArray[j].Name do(h
											boneIDMap[j] = i
											j = Bac + 1
										)
									)
								) -- Thanks to sunnydavis for the fix!

								modPanel.setCurrentObject skinMod

								for i = 1 to Vac do(
									skinOps.SetVertexWeights skinMod i 1 1
									skinOps.unnormalizeVertex skinMod i true 
									skinOps.SetVertexWeights skinMod i 1 0
									skinOps.unnormalizeVertex skinMod i false
								)
								skinOps.RemoveZeroWeights skinMod

								for i = 1 to Wac do(
									w = Weight_array[i]
									bi = #() --bone index array
									wv = #() --weight value array
									wbic = w.boneids.count

									for j = 1 to wbic do(
										boneid = w.boneids[j]
										weight = w.weights[j]
										append bi boneIDMap[boneid]
										append wv weight
									)   
									skinOps.ReplaceVertexWeights skinMod i bi wv
								)

								if FSHPArr[m].matrFlag == 1 do(for b = 1 to Bac do BoneArray[b].transform = BoneFixArray[b])

							)
						)
					)

					local UVarrays = #(UV2_array,UV3_array,UV4_array,UV5_array)
					case UVLayers of(
						1:(
							for uva=1 to UVarrays.count do(
								local uvac=UVarrays[uva].count
								if uvac > 0 do(
									meshop.setNumMaps msh (uva+2) keep:true
									for i = 1 to uvac do meshop.setMapVert msh (uva+1) i UVarrays[uva][i]
								)
							)
						)

						2:(
							for uva=1 to UVarrays.count do(
								local uvac=UVarrays[uva].count
								if uvac > 1 do(
									msh = mesh vertices:Vert_array faces:Face_array
									msh.numTVerts = Vac
									setNumCPVVerts msh msh.numTVerts
									setCVertMode msh true
									setShadeCVerts msh true
									defaultVCFaces msh
									buildTVFaces msh
									for j = 1 to Cac do setvertcolor msh j Color_array[j]
									for j = 1 to Cac do(meshop.setVertAlpha msh -2 j Alpha_array[j])
									If Vac == uvac Do(
										for j = 1 to Vac do setTVert msh j UVarrays[uva][j]
										for j = 1 to Fac do setTVFace msh j Face_array[j]
									)
									for j = 1 to msh.numfaces do setFaceSmoothGroup msh j 1

									msh.name = MeshName + " Layer "+ (uva+1) as string + (if FSHPArr[m].lodMdlCount == 1 then "" else " (LOD: " + l as string + ")")
									msh.material = buildMatSwitch \
										matName:FMATNameArr[FSHPArr[m].fmatIndx] \
										tSelOff:FMATArr[FSHPArr[m].fmatIndx].texSelOff \
										rtnTexAS:FMATArr[FSHPArr[m].fmatIndx].texAttSelOff \
										tCount:FMATArr[FSHPArr[m].fmatIndx].texSelCount \
										tFormat:TexF[TexFormat] \
										tPath:TexP[TexPath]

									select msh

									addmodifier msh (Edit_Normals()) ui:off
									msh.Edit_Normals.MakeExplicit selection:#{1..Normal_array.count}
									EN_convertVS = msh.Edit_Normals.ConvertVertexSelection
									EN_setNormal = msh.Edit_Normals.SetNormal
									normID = #{}
									for v = 1 to Nac do(
										free normID
										EN_convertVS #{v} &normID
										for id in normID do EN_setNormal id Normal_array[v]
									)

									if Bac > 0 do(
										if FSHPArr[m].matrFlag == 0 then(
											$.transform = BoneFixArray[FSHPArr[m].fsklIndx]
											if RigModel != 2 do(
												skinMod = skin()
												addModifier msh skinMod
												maxbone = getnodebyname BoneArray[FSHPArr[m].fsklIndx].name
												skinOps.addBone skinMod maxbone 0
											)
										)else(
											if RigModel != 2 do(
												skinMod = skin()
												boneIDMap = #()
												addModifier msh skinMod
												msh.Skin.weightAllVertices = false

												if FSHPArr[m].matrFlag == 1 do(for b in BoneArray do b.transform = matrix3 1)

												for i = 1 to Bac do(
													maxbone = getnodebyname BoneArray[i].name
													skinOps.addBone skinMod maxbone (if i != Bac then 0 else 1)
												)

												local numSkinBones = skinOps.GetNumberBones skinMod
												for i = 1 to numSkinBones do(
													local boneName = skinOps.GetBoneName skinMod i 0
													for j = 1 to Bac do(
														if boneName == BoneArray[j].Name do(
															boneIDMap[j] = i
															j = Bac + 1
														)
													)
												) -- Thanks to sunnydavis for the fix!

												modPanel.setCurrentObject skinMod

												for i = 1 to Vac do(
													skinOps.SetVertexWeights skinMod i 1 1
													skinOps.unnormalizeVertex skinMod i true 
													skinOps.SetVertexWeights skinMod i 1 0
													skinOps.unnormalizeVertex skinMod i false
												)
												skinOps.RemoveZeroWeights skinMod

												for i = 1 to Wac do(
													w = Weight_array[i]
													bi = #() --bone index array
													wv = #() --weight value array
													wbic = w.boneids.count

													for j = 1 to wbic do(
														boneid = w.boneids[j]
														weight = w.weights[j]
														append bi boneIDMap[boneid]
														append wv weight
													)   
													skinOps.ReplaceVertexWeights skinMod i bi wv
												)

												if FSHPArr[m].matrFlag == 1 do(for b = 1 to Bac do BoneArray[b].transform = BoneFixArray[b])

											)
										)
									)
								)
							)
						)
					)
					fseek f LODRet #seek_set
				)
				)

				clearSelection()
			)
		)

			Print ("Done! ("+((((timestamp())-st)*0.001)as string)+" Seconds)")
			enableSceneRedraw()
		)
		
	
		-- Export the model as FBX
		toSelect = #()
		for potentialSelectable in objects do (
			if potentialSelectable.parent == undefined do(
				append toSelect potentialSelectable
			)	
		)
	
		select toSelect
		--rotate selection 90 [1,0,0]
	
		FBXExporterSetParam "LoadExportPresetFile" (USER_WORKSPACE_PATH + "..\\BotW Export Preset.fbxexportpreset")
		newFBXPath = (USER_WORKSPACE_PATH + lstFMDL.items[currentExtractedModelIndex] + ".fbx")
		exportfile newFBXPath #noPrompt selectedOnly:false
		resetmaxfile #noprompt
	)
	
	)
)
enableSceneRedraw()
CreateDialog BFRESImporter
clearListener()

-- Simulate clicking the buttons as a user would.
BFRESImporter.btnLoad.pressed()
BFRESImporter.btnImport.pressed()

quitMax #noprompt