-- Importer for Wii U BFRES Files seen in many Nintendo games. 
-- Written by ItsEasyActually and Random Talking Bush (with some help from Ploaj).
-- Credit to the tockdom wiki community for the format documention
-- Special thanks to TGE for help early on with new scripting methods and getting ItsEasyActually started
-- Updated April 2nd, 2017:
-- Fixed UV mapping for models with type 519 (Riju's model in BotW, for example).
-- Fixed importing for Wind Waker HD models, which wasn't set up properly in the script in the first place. Whoops!
-- Fixed rigging being utterly broken in 3DS Max 2012 and above (thanks to sunnydavis for part of the code used). Gee, *thanks*, Autodesk...
-- Also fixed rigging for models with more than 4 bone influences (Zelda's model in BotW, for example).
-- Added support for reading normals, thanks to Ploaj for helping with the 10-bit nonsense!
-- Added type 522 for colours (signed bytes, e.g. Fire Peach's dress model in SM3DW).


-- Modified by Makiah to automatically export all models to some location while working in cohesion with a Python script.
messagebox "Beginning modified BFRES Importer :)"


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
	if (Ef==0)AND(M==0) then return ( (-1.0)^S * 0.0 )
	if (Ef==0)AND(M!=0) then return ( (-1.0)^S * 2.0^-14 * (M / 2.0^10) )
	if (Ef>0)AND(Ef<31) then return ( (-1.0)^S * 2.0^(Ef-15) * (1 + M/2.0^10) )
	if (Ef==31)AND(M==0) then return ( (-1.0)^S * 1/0.0 )
	if (Ef==31)AND(M!=0) then return 0	--hack-- should be #inf   
)

fn sign10 x = (
	if (bit.shift x -9) == 1 do(
		x = bit.not x
		x = bit.and x 0x3FF
		x += 1
		x *= -1
	)
return x
) --Thanks, Ploaj!

fn ReadFixedString fstream fixedLen = (
    local str = ""
    for i = 1 to fixedLen do
    (
        str += bit.intAsChar (ReadByte fstream #unsigned)
    )
    str
)

fn ReadOffset fstream = ((ftell fstream) + (bit.swapBytes (bit.swapBytes (readlong fstream #unsigned) 1 4) 2 3))
fn ReadBuffer fstream = (
	long0 = ReadByte fstream
	long1 = ReadByte fstream
	long2 = ReadByte fstream
	long = (0 + long0 + long1 + long2)
	long = bit.swapBytes long 1 4
	long = bit.swapBytes long 2 3
	return long
)

FMDLOffset_array = #()
f = #()
p = #()


rollout BFRESImporter "Wii U BFRES model importer" width:390 height:195
(
	label lblDisclaimer "This script was written by ItsEasyActually and Random Talking Bush. If you use it, consider giving us both thanks for this. If something doesn't work right, please contact RTB on The VG Resource (Random Talking Bush), Twitter, Tumblr or Steam (RandomTBush) so that any problems can be fixed.  Automatic exporter by Makiah." pos:[8,8] width:375 height:55

	button btnLoad "Load BFRES" pos:[8,65] width:90 height:20
	button btnImport "Import BFMDL" pos:[108,65] width:90 height:20
	dropdownlist lstFMDL pos:[208,65] width:175 height:20 items:#() selection:0

	label lblOptions "Options:" pos:[8,90] width:375 height:15
	label lblTexFormat "Texture format:" pos:[8,105] width:375 height:15
	radiobuttons tglTexFormat labels:#("DDS","PNG") pos:[90,105]
	
	label lblLODs "Import LODs:" pos:[8,120] width:375 height:15
	radiobuttons tglLODs labels:#("No","Yes") pos:[90,120]

	label lblUVLayers "UV layering:" pos:[8,135] width:375 height:15
	radiobuttons tglUVLayers labels:#("Split","Merge","No") pos:[90,135]

	label lblRigModel "Import rigging:" pos:[8,150] width:375 height:15
	radiobuttons tglRigModel labels:#("Yes","No") pos:[90,150]

	label lblUpdate "(Updated 03/11/2017) " pos:[8,175] width:375 height:15

on btnLoad pressed do(
clearlistener()
fname = GetOpenFileName caption:"Open BFRES" types:"BFRES File(*.bfres)|*.bfres"
st = timestamp() --get start time in milliseconds

if fname != undefined do(
FMDLName_array = #()
FMDLOffset_array = #()

p = getFilenamePath fname
f = fopen fname "rb"   --open file in read only format

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

fseek f 5#seek_set
verNum = ReadByte f
print ("FMDL Version: " + verNum as string)
fseek f 26#seek_cur
FileOffset = ReadOffset f
fseek f FileOffset#seek_set
BlockSize = ReadBELong f
FMDLTotal = ReadBELong f
fseek f 0x10#seek_cur

For mdl = 1 to FMDLTotal Do (
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

-- Makiah: Assuming that this is the dropdown list populator.  Have to write this to a file somewhere.  
lstFMDL.items = FMDLName_array
lstFMDL.selection = 1

)
)	

on btnImport pressed do(
if lstFMDL.selection != 0 do(
clearlistener()
st = timestamp() --get start time in milliseconds

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
		u1,				-- Unknown (int8 or int16)
		u2,				-- Unknown (int16 or three bytes)
		attArrOff,		-- Attribute Array Offset
		attIndxOff,		-- Attribute Index Offset
		buffArrOff,		-- Buffer Array Offset
		padding			-- Padding (int32)
	)

	struct fmath(
		fmat,						-- Magic
		matOff,					-- Material Name Offset
		u1,						-- Unknown (int32)
		sectIndx,				-- Section Index (int16)
		rendParamCount,		-- Render Info Parameter Count (int16)
		texSelCount,			-- Texture Selector Count (int8)
		texAttSelCount,		-- Texture Attribute Selector Count (int8)
		matParamCount,		-- Material Parameter Count (int16)
		matParamSize,			-- Material Parameter Data Size
		u2,						-- Unknown (int32)
		rendParamIndx,		-- Render Info Parameter Index Group Offset
		unkMatOff,				-- Unknown Material Offset
		shadeOff,				-- Shader Control Offset
		texSelOff,				-- Texture Selector Offset
		texAttSelOff,			-- Texture Attribute Selector Offset
		texAttIndxOff,			-- Texture Attribute Selector Index Offset
		matParamArrOff,		-- Material Parameter Array Offset
		matParamIndxOff,	-- Material Parameter Index Offset
		matParamOff,			-- Material Parameter Data Offset
		shadParamIndxOff	-- Shadow Parameter Index Offset
	)

	struct fsklh(
		fskl,					-- Magic
		u1,					-- Unknown (int16)
		fsklType,			-- Type of Bone Data (uint16)
		boneArrCount,		-- Bone Array Count (int16)
		invIndxArrCount,	-- Inverse Index Array Count (int16)
		exIndxCount,		-- Extra Index Count (int16)
		u3,					-- Unknown (int16)
		boneIndxOff,		-- Bone Index Group Offset
		boneArrOff,			-- Bone Array Offset
		invIndxArrOff,		-- Inverse Index Array Offset
		invMatrArrOff,		-- Inverse Matric Array Offset
		padding				-- Padding (int32)
	)

	struct fshph(
		fshp,					-- Magic
		polyNameOff,		-- Polygon Name Offset
		u1,					-- Unknown (int32)
		fvtxIndx,			-- FVTX Index (int16)
		fmatIndx,			-- FMAT Index (int16)
		fsklIndx,				-- FSKL Index (int16)
		sectIndx,			-- Section Index (int16)
		fsklIndxArrCount,	-- FSKL Index Array Count (int16)
		matrFlag,			-- Matrix Use Flag (int8)
		lodMdlCount,		-- LoD Model Count (int8)
		visGrpCount,		-- Visibility Group Tree Node Count
		u3,					-- Unknown (float)
		fvtxOff,				-- FVTX Offset
		lodMdlOff,			-- LoD Model Offset
		fsklIndxArrOff,		-- FSKL Index Array Offset
		u4,					-- Unknown (int32)
		visGrpNodeOff,	-- Vibility Group Tree Nodes Offset
		visGrpRangeOff,	-- Visibility Group Tree Ranges Offset
		visGrpIndxOff,		-- Visibility Group Tree Indices Offset
		u5						-- Unknown (int32)
	)	

	struct attdata(
		attName,	-- Attribute Type
		buffIndx,	-- Buffer Index (u8)
		buffOff,		-- Buffer Offset (u16)
		vertType	-- Format
	)

	struct buffData(
		buffSize,	-- Size of Buffer (u32)
		strideSize,	-- Size of Vertex Stride (u16)
		dataOffset	-- Offset to Buffer (u32)
	)

	struct bdata(
		bNameOff,		-- Bone Name Offset
		bIndx,			-- Bone Index (int16)
		parIndx1,		-- Parent Index 1 (int16)
		parIndx2,		-- Parent Index 2 (int16)
		parIndx3,		-- Parent Index 3 (int16)
		parIndx4,		-- Parent Index 4 (int16)
		u1,				-- Unknown (int16)
		bFlags,			-- Bone Flags (int16)
		u2,				-- Unknown (int16)
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
		u1,				-- Unknown (int32)
		faceType,		-- Face Data Type (int32)
		dCount,			-- Visibility Group Draw Count
		visGrpCount,	-- Visibility Group Count (int16)
		u3,				-- Unknown (int16)
		visGrpOff,		-- Visibility Group Offset
		indxBuffOff,		-- Index Buffer Offset
		elmSkip			-- Element Skip (int32)
	)

	struct Bone_Info_Struct
	(
		bone1, 
		bone2, 
		bone3, 
		bone4, 
		bone5, 
		bone6, 
		bone7, 
		bone8
	)

	struct Weight_Info_Struct
	(
		weight1, 
		weight2, 
		weight3, 
		weight4, 
		weight5, 
		weight6, 
		weight7, 
		weight8
	)

	struct weight_data
	(
		boneids, 
		weights
	)

	struct invMatrix
	(
		invIndx,
		invMatr
	)

	local TexFormat = tglTexFormat.state
	local LODs = tglLODs.state
	local UVLayers = tglUVLayers.state
	local RigModel = tglRigModel.state

	fseek f 5#seek_set
	verNum = ReadByte f

	fseek f FMDLOffset_array[lstFMDL.selection]#seek_set

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

	-- F_Vertex Header --
	fseek f fmdl_info.fvtxArrOff#seek_set
	For vtx = 1 to fmdl_info.fvtxCount Do (
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
	)

	-- F_Material Header --
	fseek f fmdl_info.fmatIndx#seek_set
	fseek f 24#seek_cur
	For mat = 1 to fmdl_info.fmatCount Do (
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
		
		fseek f Rtn#seek_set
		append FMATArr(fmat_info)
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

	-- Node Setup --
	fseek f fskl_info.invIndxArrOff #seek_set
	for nodes = 1 to (fskl_info.invIndxArrCount + fskl_info.exIndxCount) do(
		NodeID = readBEshort f + 1
		append Node_Array NodeID
	)

	-- F_Shape Header --
	fseek f fmdl_info.fshpIndx#seek_set
	fseek f 24#seek_cur
	For shp = 1 to fmdl_info.fshpCount Do (
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
	)

	-- F_Model Inverse Matrices --
	--fseek f fskl_info.invMatrArrOff#seek_set
	NxtMatr = 0
	fseek f fskl_info.invIndxArrOff#seek_set
	For indx = 1 to fskl_info.invIndxArrCount Do (
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
	case of (
		(verNum == 0):(
			For bn = 1 to fskl_info.boneArrCount Do (
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
				
				if boneData.u2 == 0x0001 then(
				tfm = (quat boneData.rotX boneData.rotY boneData.rotZ boneData.rotW) as matrix3
				tfm = inverse(tfm)
				) else (tfm = (eulerangles (boneData.rotX*(180/pi)) (boneData.rotY*(180/pi)) (boneData.rotZ*(180/pi))) as matrix3)
				tfm.row4 = [boneData.posX,boneData.posY,boneData.posZ]
				
				newBone = bonesys.createbone \
					tfm.row4	\
					(tfm.row4 + 0.01 * (normalize tfm.row1)) \
					(normalize tfm.row3)
					
				Rtn = ftell f
				fseek f boneData.bNameOff#seek_set
				boneName = ReadString f
				fseek f Rtn#seek_set
				newBone.name = boneName
				newBone.width  = 0.03
				newBone.height = 0.03
				newBone.transform = tfm
				newBone.setBoneEnable false 0
				newBone.wirecolor = yellow
				newbone.showlinks = true
				newBone.pos.controller      = TCB_position ()
				newBone.rotation.controller = TCB_rotation ()
				
				If boneData.parIndx1 != 65536 Do (
					newBone.parent = BoneArray[boneData.parIndx1]
					newBone.transform *= BoneArray[boneData.parIndx1].transform
				)
				
				append BoneArray newBone
				append BoneFixArray newBone.transform
				fseek f 48#seek_cur
			)
		)
		(verNum == 2):(
			For bn = 1 to fskl_info.boneArrCount Do (
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
				
				if boneData.u2 == 0x0001 then(
				tfm = (quat boneData.rotX boneData.rotY boneData.rotZ boneData.rotW) as matrix3
				tfm = inverse(tfm)
				) else (tfm = (eulerangles (boneData.rotX*(180/pi)) (boneData.rotY*(180/pi)) (boneData.rotZ*(180/pi))) as matrix3)
				tfm.row4 = [boneData.posX,boneData.posY,boneData.posZ]
				
				newBone = bonesys.createbone \
					tfm.row4	\
					(tfm.row4 + 0.01 * (normalize tfm.row1)) \
					(normalize tfm.row3)
					
				Rtn = ftell f
				fseek f boneData.bNameOff#seek_set
				boneName = ReadString f
				fseek f Rtn#seek_set
				newBone.name = boneName
				newBone.width  = 0.03
				newBone.height = 0.03
				newBone.transform = tfm
				newBone.setBoneEnable false 0
				newBone.wirecolor = yellow
				newbone.showlinks = true
				newBone.pos.controller      = TCB_position ()
				newBone.rotation.controller = TCB_rotation ()
				
				If boneData.parIndx1 != 65536 Do (
					newBone.parent = BoneArray[boneData.parIndx1]
					newBone.transform *= BoneArray[boneData.parIndx1].transform
				)
				
				append BoneArray newBone
				append BoneFixArray newBone.transform
				fseek f 48#seek_cur
			)
		)
		(verNum == 3):(
			For bn = 1 to fskl_info.boneArrCount Do (
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
				
				if boneData.u2 == 0x0001 then(
				tfm = (quat boneData.rotX boneData.rotY boneData.rotZ boneData.rotW) as matrix3
				tfm = inverse(tfm)
				) else (tfm = (eulerangles (boneData.rotX*(180/pi)) (boneData.rotY*(180/pi)) (boneData.rotZ*(180/pi))) as matrix3)
				tfm.row4 = [boneData.posX,boneData.posY,boneData.posZ]
				
				newBone = bonesys.createbone \
					tfm.row4	\
					(tfm.row4 + 0.01 * (normalize tfm.row1)) \
					(normalize tfm.row3)
					
				Rtn = ftell f
				fseek f boneData.bNameOff#seek_set
				boneName = ReadString f
				fseek f Rtn#seek_set
				newBone.name = boneName
				newBone.width  = 0.03
				newBone.height = 0.03
				newBone.transform = tfm
				newBone.setBoneEnable false 0
				newBone.wirecolor = yellow
				newbone.showlinks = true
				newBone.pos.controller      = TCB_position ()
				newBone.rotation.controller = TCB_rotation ()
				
				If boneData.parIndx1 != 65536 Do (
					newBone.parent = BoneArray[boneData.parIndx1]
					newBone.transform *= BoneArray[boneData.parIndx1].transform
				)
				
				append BoneArray newBone
				append BoneFixArray newBone.transform
				fseek f 48#seek_cur
			)
		)
		(verNum == 4):(
			For bn = 1 to fskl_info.boneArrCount Do (
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
				
				if boneData.u2 == 0x0001 then(
				tfm = (quat boneData.rotX boneData.rotY boneData.rotZ boneData.rotW) as matrix3
				tfm = inverse(tfm)
				) else (tfm = (eulerangles (boneData.rotX*(180/pi)) (boneData.rotY*(180/pi)) (boneData.rotZ*(180/pi))) as matrix3)
				tfm.row4 = [boneData.posX,boneData.posY,boneData.posZ]
				
				newBone = bonesys.createbone \
					tfm.row4	\
					(tfm.row4 + 0.01 * (normalize tfm.row1)) \
					(normalize tfm.row3)
					
				Rtn = ftell f
				fseek f boneData.bNameOff#seek_set
				boneName = ReadString f
				fseek f Rtn#seek_set
				newBone.name = boneName
				newBone.width  = 0.03
				newBone.height = 0.03
				newBone.transform = tfm
				newBone.setBoneEnable false 0
				newBone.wirecolor = yellow
				newbone.showlinks = true
				newBone.pos.controller      = TCB_position ()
				newBone.rotation.controller = TCB_rotation ()
				
				If boneData.parIndx1 != 65536 Do (
					newBone.parent = BoneArray[boneData.parIndx1]
					newBone.transform *= BoneArray[boneData.parIndx1].transform
				)
				
				append BoneArray newBone
				append BoneFixArray newBone.transform
			)
		)
		(verNum == 5):(
			For bn = 1 to fskl_info.boneArrCount Do (
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
			
				if boneData.u2 == 0x0001 then(
				tfm = (quat boneData.rotX boneData.rotY boneData.rotZ boneData.rotW) as matrix3
				tfm = inverse(tfm)
				) else (tfm = (eulerangles (boneData.rotX*(180/pi)) (boneData.rotY*(180/pi)) (boneData.rotZ*(180/pi))) as matrix3)
				tfm.row4 = [boneData.posX,boneData.posY,boneData.posZ]
				
				newBone = bonesys.createbone \
					tfm.row4	\
					(tfm.row4 + 0.01 * (normalize tfm.row1)) \
					(normalize tfm.row3)
					
				Rtn = ftell f
				fseek f boneData.bNameOff#seek_set
				boneName = ReadString f
				fseek f Rtn#seek_set
				newBone.name = boneName
				newBone.width  = 0.03
				newBone.height = 0.03
				newBone.transform = tfm
				newBone.setBoneEnable false 0
				newBone.wirecolor = yellow
				newbone.showlinks = true
				newBone.pos.controller      = TCB_position ()
				newBone.rotation.controller = TCB_rotation ()
				
				If boneData.parIndx1 != 65536 Do (
					newBone.parent = BoneArray[boneData.parIndx1]
					newBone.transform *= BoneArray[boneData.parIndx1].transform
				)
				
				append BoneArray newBone
				append BoneFixArray newBone.transform
			)
		)
	)

	-- Mesh Building --
	For m = 1 to FSHPArr.count Do (
		Vert_Array = #()
		Normal_Array = #()
		UV_Array = #()
		UV2_Array = #()
		UV3_Array = #()
		UV4_Array = #()
		UV5_Array = #()
		Color_Array = #()
		AttrArr = #()
		BuffArr = #()
		W1_array = #()
		B1_array = #()
		Weight_array = #()
		
		fseek f FSHPArr[m].polyNameOff#seek_set
		MeshName = ReadString f

		fseek f FVTXArr[FSHPArr[m].fvtxIndx].attArrOff#seek_set
		For att = 1 to FVTXArr[FSHPArr[m].fvtxIndx].attCount Do (
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
		
		fseek f FVTXArr[FSHPArr[m].fvtxIndx].buffArrOff#seek_set
		For buf = 1 to FVTXArr[FSHPArr[m].fvtxIndx].buffCount Do (
			unk1 = ReadLong f
			BufferSize = ReadBELong f
			unk2 = ReadLong f
			StrideSize = ReadBEShort f
			unk3 = ReadShort f
			unk4 = ReadLong f
			DataOffset = ReadOffset f
			append BuffArr (buffData buffSize: BufferSize strideSize: StrideSize dataOffset: DataOffset)
		)

		If BuffArr.count > 1 then (
		For attr = 1 to AttrArr.count Do (
			locPoint = ((BuffArr[AttrArr[attr].buffIndx].dataOffset) + (AttrArr[attr].buffOff))
			fseek f locPoint#seek_set
			For v = 1 to FVTXArr[FSHPArr[m].fvtxIndx].vertCount Do (
				VertStart = ftell f
				case of (
					--Vertex Info--
					(AttrArr[attr].attName == "_p0"):(
						case of (
							(AttrArr[attr].vertType == 2063):(
							vx = ReadBEHalfFloat f
							vy = ReadBEHalfFloat f
							vz = ReadBEHalfFloat f
							vw = ReadBEHalfFloat f
							append vert_Array[vx,vy,vz]
							)
							(AttrArr[attr].vertType == 2065):(
							vx = ReadBEFloat f
							vy = ReadBEFloat f
							vz = ReadBEFloat f
							vw = ReadBEFloat f
							append vert_Array[vx,vy,vz]
							)
						)
						fseek f vertStart#seek_set
					)
					--Color Info--
					(AttrArr[attr].attName == "_c0"):(
						case of (
							default: (append Color_Array [255,255,255])
							(AttrArr[attr].vertType == 2063):(
							colorR = (ReadBEHalfFloat f * 255)
							colorG = (ReadBEHalfFloat f * 255)
							colorB = (ReadBEHalfFloat f * 255)
							colorA = (ReadBEHalfFloat f * 255)
							if colorR < 0 do(colorR = 0)
							if colorR > 255 do(colorR = 255)
							if colorG < 0 do(colorG = 0)
							if colorG > 255 do(colorG = 255)
							if colorB < 0 do(colorB = 0)
							if colorB > 255 do(colorB = 255)
							if colorA < 0 do(colorA = 0)
							if colorA > 255 do(colorA = 255)
							-- if these colours aren't clamped they'll go neon
							append Color_Array[colorR,colorG,colorB]
							)
							(AttrArr[attr].vertType == 2067):(
                            colorR = (ReadBEFloat f * 255)
                            colorG = (ReadBEFloat f * 255)
                            colorB = (ReadBEFloat f * 255)
                            colorA = (ReadBEFloat f * 255)
                            if colorR < 0 do(colorR = 0)
                            if colorR > 255 do(colorR = 255)
                            if colorG < 0 do(colorG = 0)
                            if colorG > 255 do(colorG = 255)
                            if colorB < 0 do(colorB = 0)
                            if colorB > 255 do(colorB = 255)
                            if colorA < 0 do(colorA = 0)
                            if colorA > 255 do(colorA = 255)
                            -- if these colours aren't clamped they'll go neon
                            append Color_Array[colorR,colorG,colorB]
                            )
							(AttrArr[attr].vertType == 10):(
							colorR = ReadByte f #unsigned
							colorG = ReadByte f #unsigned
							colorB = ReadByte f #unsigned
							colorA = ReadByte f #unsigned
							append Color_Array[colorR,colorG,colorB]
							)
							(AttrArr[attr].vertType == 522):(
							colorR = ReadByte f * 2
							colorG = ReadByte f * 2
							colorB = ReadByte f * 2
							colorA = ReadByte f * 2
							if colorR < 0 do(colorR = 0)
                            if colorR > 254 do(colorR = 255)
                            if colorG < 0 do(colorG = 0)
                            if colorG > 254 do(colorG = 255)
                            if colorB < 0 do(colorB = 0)
                            if colorB > 254 do(colorB = 255)
                            if colorA < 0 do(colorA = 0)
                            if colorA > 254 do(colorA = 255)
							append Color_Array[colorR,colorG,colorB]
							)
						)
						fseek f vertStart#seek_set
					)
					--Normals Info--
					(AttrArr[attr].attName == "_n0"):(
						case of (
							(AttrArr[attr].vertType == 522):(
							nx = ReadByte f as float / 127
							ny = ReadByte f as float / 127
							nz = ReadByte f as float / 127
							nw = ReadByte f as float / 127
							append Normal_Array[nx,ny,nz]
							)
							(AttrArr[attr].vertType == 523):(
							normVal = ReadBElong f
							nx = sign10(bit.and (normVal) 0x3FF) as float / 511
							ny = sign10(bit.and (bit.shift normVal -10) 0x3FF) as float / 511
							nz = sign10(bit.and (bit.shift normVal -20) 0x3FF) as float / 511
							append Normal_Array[nx,ny,nz]
							)
							(AttrArr[attr].vertType == 2065):(
							nx = ReadBEFloat f
							ny = ReadBEFloat f
							nz = ReadBEFloat f
							nw = ReadBEFloat f
							append Normal_Array[nx,ny,nz]
							)
						)
						fseek f vertStart#seek_set
					)
					--Tangent Info--
					--Binormals Info--
					--UV Info--
					(AttrArr[attr].attName == "_u0" or AttrArr[attr].attName == "color"):(
						case of (
							default: (append UV_Array[0,0,0]) 
							(AttrArr[attr].vertType == 4):(
							tu = (ReadByte f #unsigned) as float / 255
							tv = (ReadByte f #unsigned) as float / 255
							append UV_Array[tu,tv,0]
							)
							(AttrArr[attr].vertType == 7):(
							tu = ((ReadBEShort f as float)/65535)
							tv = (((ReadBEShort f as float)/65535)*-1) + 1
							if AttrArr[attr].attName == "detail" do (
                                tu = tu * 2
                                tv = tv * 2
                            )
							append UV_Array[tu,tv,0]
							)
							(AttrArr[attr].vertType == 516):(
							tu = (ReadByte f #unsigned) as float / 255
							tv = (ReadByte f #unsigned) as float / 255
							append UV_Array[tu,tv,0]
							)
							(AttrArr[attr].vertType == 519):(
							tu = ((ReadBEShort f as float)/32767)
							tv = (((ReadBEShort f as float)/32767)*-1) + 1
							If tu < -1 Do (
								tu = tu + 2
							)
							If tv < 0 Do (
								tv = tv + 2
							)
							If tu > 1 Do (
								tu = tu - 2
							)
							If tv > 2 Do (
								tv = tv - 2
							)
							append UV_Array[tu,tv,0]
							)
							(AttrArr[attr].vertType == 2056):(
							tu = readBEHalfFloat f
							tv = readBEHalfFloat f*-1
							append UV_Array[tu,tv,0]
							)
							(AttrArr[attr].vertType == 2061):(
							tu = ReadBEFloat f
							tv = (ReadBEFloat f*-1) + 1
							append UV_Array[tu,tv,0]
							)
						)
						fseek f vertStart#seek_set
					)
					(AttrArr[attr].attName == "_u1"):(
						case of (
							default: (append UV2_Array[0,0,0]) 
							(AttrArr[attr].vertType == 4):(
							tu2 = (ReadByte f #unsigned) as float / 255
							tv2 = (ReadByte f #unsigned) as float / 255
							append UV2_Array[tu2,tv2,0]
							)
							(AttrArr[attr].vertType == 7):(
							tu2 = ((ReadBEShort f as float)/65535)
							tv2 = ((ReadBEShort f as float)/65535)*-1
							append UV2_Array[tu2,tv2,0]
							)
							(AttrArr[attr].vertType == 516):(
							tu2 = (ReadByte f #unsigned) as float / 255
							tv2 = (ReadByte f #unsigned) as float / 255
							append UV2_Array[tu2,tv2,0]
							)
							(AttrArr[attr].vertType == 519):(
							tu2 = ((ReadBEShort f as float)/32767)
							tv2 = ((ReadBEShort f as float)/32767)*-1
							If tu2 < -1 Do (
								tu2 = tu2 + 2
							)
							If tv2 < 0 Do (
								tv2 = tv2 + 2
							)
							If tu2 > 1 Do (
								tu2 = tu2 - 2
							)
							If tv2 > 2 Do (
								tv2 = tv2 - 2
							)
							append UV2_Array[tu2,tv2,0]
							)
							(AttrArr[attr].vertType == 2056):(
							tu2 = readBEHalfFloat f
							tv2 = readBEHalfFloat f*-1
							append UV2_Array[tu2,tv2,0]
							)
							(AttrArr[attr].vertType == 2061):(
							tu2 = ReadBEFloat f
							tv2 = ReadBEFloat f*-1
							append UV2_Array[tu2,tv2,0]
							)
						)
						fseek f vertStart#seek_set
					)
					(AttrArr[attr].attName == "_u2"):(
						case of (
							default: (append UV3_Array[0,0,0]) 
							(AttrArr[attr].vertType == 4):(
							tu2 = (ReadByte f #unsigned) as float / 255
							tv2 = (ReadByte f #unsigned) as float / 255
							append UV3_Array[tu2,tv2,0]
							)
							(AttrArr[attr].vertType == 7):(
							tu2 = ((ReadBEShort f as float)/65535)
							tv2 = ((ReadBEShort f as float)/65535)*-1
							append UV3_Array[tu2,tv2,0]
							)
							(AttrArr[attr].vertType == 519):(
							tu2 = ((ReadBEShort f as float)/32767)
							tv2 = ((ReadBEShort f as float)/32767)*-1
							If tu2 < -1 Do (
								tu2 = tu2 + 2
							)
							If tv2 < 0 Do (
								tv2 = tv2 + 2
							)
							If tu2 > 1 Do (
								tu2 = tu2 - 2
							)
							If tv2 > 2 Do (
								tv2 = tv2 - 2
							)
							append UV3_Array[tu2,tv2,0]
							)
							(AttrArr[attr].vertType == 2056):(
							tu2 = readBEHalfFloat f
							tv2 = readBEHalfFloat f*-1
							append UV3_Array[tu2,tv2,0]
							)
							(AttrArr[attr].vertType == 2061):(
							tu2 = ReadBEFloat f
							tv2 = ReadBEFloat f*-1
							append UV3_Array[tu2,tv2,0]
							)
						)
						fseek f vertStart#seek_set
					)
					(AttrArr[attr].attName == "_u3"):(
						case of (
							default: (append UV4_Array[0,0,0]) 
							(AttrArr[attr].vertType == 4):(
							tu2 = (ReadByte f #unsigned) as float / 255
							tv2 = (ReadByte f #unsigned) as float / 255
							append UV4_Array[tu2,tv2,0]
							)
							(AttrArr[attr].vertType == 7):(
							tu2 = ((ReadBEShort f as float)/65535)
							tv2 = ((ReadBEShort f as float)/65535)*-1
							append UV4_Array[tu2,tv2,0]
							)
							(AttrArr[attr].vertType == 519):(
							tu2 = ((ReadBEShort f as float)/32767)
							tv2 = ((ReadBEShort f as float)/32767)*-1
							If tu2 < -1 Do (
								tu2 = tu2 + 2
							)
							If tv2 < 0 Do (
								tv2 = tv2 + 2
							)
							If tu2 > 1 Do (
								tu2 = tu2 - 2
							)
							If tv2 > 2 Do (
								tv2 = tv2 - 2
							)
							append UV4_Array[tu2,tv2,0]
							)
							(AttrArr[attr].vertType == 2056):(
							tu2 = readBEHalfFloat f
							tv2 = readBEHalfFloat f*-1
							append UV5_Array[tu2,tv2,0]
							)
							(AttrArr[attr].vertType == 2061):(
							tu2 = ReadBEFloat f
							tv2 = ReadBEFloat f*-1
							append UV4_Array[tu2,tv2,0]
							)
						)
						fseek f vertStart#seek_set
					)
					(AttrArr[attr].attName == "_u4" or AttrArr[attr].attName == "All"):(
						case of (
							default: (append UV5_Array[0,0,0]) 
							(AttrArr[attr].vertType == 4):(
							tu2 = (ReadByte f #unsigned) as float / 255
							tv2 = (ReadByte f #unsigned) as float / 255
							append UV5_Array[tu2,tv2,0]
							)
							(AttrArr[attr].vertType == 7):(
							tu2 = ((ReadBEShort f as float)/65535)
							tv2 = ((ReadBEShort f as float)/65535)*-1
							append UV5_Array[tu2,tv2,0]
							)
							(AttrArr[attr].vertType == 519):(
							tu2 = ((ReadBEShort f as float)/32767)
							tv2 = ((ReadBEShort f as float)/32767)*-1
							If tu2 < -1 Do (
								tu2 = tu2 + 2
							)
							If tv2 < 0 Do (
								tv2 = tv2 + 2
							)
							If tu2 > 1 Do (
								tu2 = tu2 - 2
							)
							If tv2 > 2 Do (
								tv2 = tv2 - 2
							)
							append UV5_Array[tu2,tv2,0]
							)
							(AttrArr[attr].vertType == 2056):(
							tu2 = readBEHalfFloat f
							tv2 = readBEHalfFloat f*-1
							append UV5_Array[tu2,tv2,0]
							)
							(AttrArr[attr].vertType == 2061):(
							tu2 = ReadBEFloat f
							tv2 = ReadBEFloat f*-1
							append UV5_Array[tu2,tv2,0]
							)
						)
						fseek f vertStart#seek_set
					)
					--BlendIndex Info--
					(AttrArr[attr].attName == "_i0"):(
						case of (
							(AttrArr[attr].vertType == 256):(
							bone1 = ReadByte f#unsigned+1
							bone1 = Node_array[bone1]
							bone2 = 1
							bone3 = 1
							bone4 = 1
							bone5 = 1
							bone6 = 1
							bone7 = 1
							bone8 = 1
							weight1 = 1
							weight2 = 0
							weight3 = 0
							weight4 = 0
							weight5 = 0
							weight6 = 0
							weight7 = 0
							weight8 = 0
							append B1_Array (Bone_Info_Struct bone1:bone1 bone2:bone2 bone3:bone3 bone4:bone4 bone5:bone5 bone6:bone6 bone7:bone7 bone8:bone8)
							append W1_Array (Weight_Info_Struct weight1:weight1 weight2:weight2 weight3:weight3 weight4:weight4 weight5:weight5 weight6:weight6 weight7:weight7 weight8:weight8)
							)
							(AttrArr[attr].vertType == 260):(
							bone1 = ReadByte f#unsigned+1
							bone1 = Node_array[Bone1]
							bone2 = ReadByte f#unsigned+1
							bone2 = Node_array[Bone2]
							bone3 = 1
							bone4 = 1
							bone5 = 1
							bone6 = 1
							bone7 = 1
							bone8 = 1
							append B1_Array (Bone_Info_Struct bone1:bone1 bone2:bone2 bone3:bone3 bone4:bone4 bone5:bone5 bone6:bone6 bone7:bone7 bone8:bone8)
							)
							(AttrArr[attr].vertType == 266):(
							bone1 = ReadByte f#unsigned+1
							bone1 = Node_array[Bone1]
							bone2 = ReadByte f#unsigned+1
							bone2 = Node_array[Bone2]
							bone3 = ReadByte f#unsigned+1
							bone3 = Node_array[Bone3]
							bone4 = ReadByte f#unsigned+1
							bone4 = Node_array[Bone4]
							bone5 = 1
							bone6 = 1
							bone7 = 1
							bone8 = 1
							append B1_Array (Bone_Info_Struct bone1:bone1 bone2:bone2 bone3:bone3 bone4:bone4 bone5:bone5 bone6:bone6 bone7:bone7 bone8:bone8)
							)
							(AttrArr[attr].vertType == 268):(
							bone1 = ReadLong f#unsigned+1
							bone1 = Node_array[Bone1]
							bone2 = ReadLong f#unsigned+1
							bone2 = Node_array[Bone2]
							bone3 = 1
							bone4 = 1
							bone5 = 1
							bone6 = 1
							bone7 = 1
							bone8 = 1
							append B1_Array (Bone_Info_Struct bone1:bone1 bone2:bone2 bone3:bone3 bone4:bone4 bone5:bone5 bone6:bone6 bone7:bone7 bone8:bone8)
							)
							(AttrArr[attr].vertType == 272):(
							bone1 = ReadLong f#unsigned+1
							bone1 = Node_array[Bone1]
							bone2 = ReadLong f#unsigned+1
							bone2 = Node_array[Bone2]
							bone3 = ReadLong f#unsigned+1
							bone3 = Node_array[Bone3]
							bone4 = ReadLong f#unsigned+1
							bone4 = Node_array[Bone4]
							bone5 = 1
							bone6 = 1
							bone7 = 1
							bone8 = 1
							append B1_Array (Bone_Info_Struct bone1:bone1 bone2:bone2 bone3:bone3 bone4:bone4 bone5:bone5 bone6:bone6 bone7:bone7 bone8:bone8)
							)
							(AttrArr[attr].vertType == 274):(
							bone1 = ReadLong f#unsigned+1
							bone1 = Node_array[Bone1]
							bone2 = ReadLong f#unsigned+1
							bone2 = Node_array[Bone2]
							bone3 = ReadLong f#unsigned+1
							bone3 = Node_array[Bone3]
							bone4 = ReadLong f#unsigned+1
							bone4 = Node_array[Bone4]
							bone5 = 1
							bone6 = 1
							bone7 = 1
							bone8 = 1
							append B1_Array (Bone_Info_Struct bone1:bone1 bone2:bone2 bone3:bone3 bone4:bone4 bone5:bone5 bone6:bone6 bone7:bone7 bone8:bone8)
							)
						)
						fseek f vertStart#seek_set
					)
					(AttrArr[attr].attName == "_i1"):(
						case of (
							(AttrArr[attr].vertType == 256):(
							bone5 = ReadByte f#unsigned+1
							bone5 = Node_array[bone5]
							bone6 = 1
							bone7 = 1
							bone8 = 1
							weight5 = 1
							weight6 = 0
							weight7 = 0
							weight8 = 0
							bone1 = B1_array[v].Bone1
							bone2 = B1_array[v].Bone2
							bone3 = B1_array[v].Bone3
							bone4 = B1_array[v].Bone4
							weight1 = W1_array[v].Weight1
							weight2 = W1_array[v].Weight2
							weight3 = W1_array[v].Weight3
							weight4 = W1_array[v].Weight4
							B1_Array[v] = (Bone_Info_Struct bone1:bone1 bone2:bone2 bone3:bone3 bone4:bone4 bone5:bone5 bone6:bone6 bone7:bone7 bone8:bone8)
							W1_Array[v] = (Weight_Info_Struct weight1:weight1 weight2:weight2 weight3:weight3 weight4:weight4 weight5:weight5 weight6:weight6 weight7:weight7 weight8:weight8)
							)
							(AttrArr[attr].vertType == 260):(
							bone5 = ReadByte f#unsigned+1
							bone5 = Node_array[Bone5]
							bone6 = ReadByte f#unsigned+1
							bone6 = Node_array[Bone6]
							bone7 = 1
							bone8 = 1
							bone1 = B1_array[v].Bone1
							bone2 = B1_array[v].Bone2
							bone3 = B1_array[v].Bone3
							bone4 = B1_array[v].Bone4
							B1_Array[v] = (Bone_Info_Struct bone1:bone1 bone2:bone2 bone3:bone3 bone4:bone4 bone5:bone5 bone6:bone6 bone7:bone7 bone8:bone8)
							)
							(AttrArr[attr].vertType == 266):(
							bone5 = ReadByte f#unsigned+1
							bone5 = Node_array[Bone5]
							bone6 = ReadByte f#unsigned+1
							bone6 = Node_array[Bone6]
							bone7 = ReadByte f#unsigned+1
							bone7 = Node_array[Bone7]
							bone8 = ReadByte f#unsigned+1
							bone8 = Node_array[Bone8]
							bone1 = B1_array[v].Bone1
							bone2 = B1_array[v].Bone2
							bone3 = B1_array[v].Bone3
							bone4 = B1_array[v].Bone4
							B1_Array[v] = (Bone_Info_Struct bone1:bone1 bone2:bone2 bone3:bone3 bone4:bone4 bone5:bone5 bone6:bone6 bone7:bone7 bone8:bone8)
							)
							(AttrArr[attr].vertType == 268):(
							bone5 = ReadLong f#unsigned+1
							bone5 = Node_array[Bone5]
							bone6 = ReadLong f#unsigned+1
							bone6 = Node_array[Bone6]
							bone7 = 1
							bone8 = 1
							bone1 = B1_array[v].Bone1
							bone2 = B1_array[v].Bone2
							bone3 = B1_array[v].Bone3
							bone4 = B1_array[v].Bone4
							B1_Array[v] = (Bone_Info_Struct bone1:bone1 bone2:bone2 bone3:bone3 bone4:bone4 bone5:bone5 bone6:bone6 bone7:bone7 bone8:bone8)
							)
							(AttrArr[attr].vertType == 272):(
							bone5 = ReadLong f#unsigned+1
							bone5 = Node_array[Bone5]
							bone6 = ReadLong f#unsigned+1
							bone6 = Node_array[Bone6]
							bone7 = ReadLong f#unsigned+1
							bone7 = Node_array[Bone7]
							bone8 = ReadLong f#unsigned+1
							bone8 = Node_array[Bone8]
							bone1 = B1_array[v].Bone1
							bone2 = B1_array[v].Bone2
							bone3 = B1_array[v].Bone3
							bone4 = B1_array[v].Bone4
							B1_Array[v] = (Bone_Info_Struct bone1:bone1 bone2:bone2 bone3:bone3 bone4:bone4 bone5:bone5 bone6:bone6 bone7:bone7 bone8:bone8)
							)
							(AttrArr[attr].vertType == 274):(
							bone5 = ReadLong f#unsigned+1
							bone5 = Node_array[Bone5]
							bone6 = ReadLong f#unsigned+1
							bone6 = Node_array[Bone6]
							bone7 = ReadLong f#unsigned+1
							bone7 = Node_array[Bone7]
							bone8 = ReadLong f#unsigned+1
							bone8 = Node_array[Bone8]
							bone1 = B1_array[v].Bone1
							bone2 = B1_array[v].Bone2
							bone3 = B1_array[v].Bone3
							bone4 = B1_array[v].Bone4
							B1_Array[v] = (Bone_Info_Struct bone1:bone1 bone2:bone2 bone3:bone3 bone4:bone4 bone5:bone5 bone6:bone6 bone7:bone7 bone8:bone8)
							)
						)
						fseek f vertStart#seek_set
					)
					-- BlendWeight Info --
					(AttrArr[attr].attName == "_w0"):( 
						case of (
							default: (append W1_Array (Weight_Info_Struct weight1:1 weight2:0 weight3:0 weight4:0 weight5:0 weight6:0 weight7:0 weight8:0)) 
							(AttrArr[attr].vertType == 4):(
							weight1 = (ReadByte f #unsigned) as float / 255
							weight2 = (ReadByte f #unsigned) as float / 255
							weight3 = 0
							weight4 = 0
							weight5 = 0
							weight6 = 0
							weight7 = 0
							weight8 = 0
							append W1_Array (Weight_Info_Struct weight1:weight1 weight2:weight2 weight3:weight3 weight4:weight4 weight5:weight5 weight6:weight6 weight7:weight7 weight8:weight8)
							)
							(AttrArr[attr].vertType == 10):(
							weight1 = (ReadByte f #unsigned) as float / 255
							weight2 = (ReadByte f #unsigned) as float / 255
							weight3 = (ReadByte f #unsigned) as float / 255
							weight4 = (ReadByte f #unsigned) as float / 255
							weight5 = 0
							weight6 = 0
							weight7 = 0
							weight8 = 0
							if weight4 >= 1 do(weight4 = 0)
							append W1_Array (Weight_Info_Struct weight1:weight1 weight2:weight2 weight3:weight3 weight4:weight4 weight5:weight5 weight6:weight6 weight7:weight7 weight8:weight8)
							)
							(AttrArr[attr].vertType == 2061):(
							weight1 = ReadBEFloat f
							weight2 = ReadBEFloat f
							weight3 = 0
							weight4 = 0
							weight5 = 0
							weight6 = 0
							weight7 = 0
							weight8 = 0
							append W1_Array (Weight_Info_Struct weight1:weight1 weight2:weight2 weight3:weight3 weight4:weight4 weight5:weight5 weight6:weight6 weight7:weight7 weight8:weight8)
							)
							(AttrArr[attr].vertType == 2065):(
							weight1 = ReadBEFloat f
							weight2 = ReadBEFloat f
							weight3 = ReadBEFloat f
							weight4 = ReadBEFloat f
							weight5 = 0
							weight6 = 0
							weight7 = 0
							weight8 = 0
							append W1_Array (Weight_Info_Struct weight1:weight1 weight2:weight2 weight3:weight3 weight4:weight4 weight5:weight5 weight6:weight6 weight7:weight7 weight8:weight8)
							)
							(AttrArr[attr].vertType == 2067):(
							weight1 = ReadBEFloat f
							weight2 = ReadBEFloat f
							weight3 = ReadBEFloat f
							weight4 = ReadBEFloat f
							weight5 = 0
							weight6 = 0
							weight7 = 0
							weight8 = 0
							append W1_Array (Weight_Info_Struct weight1:weight1 weight2:weight2 weight3:weight3 weight4:weight4 weight5:weight5 weight6:weight6 weight7:weight7 weight8:weight8)
							)
						)
						fseek f vertStart#seek_set
					)
					(AttrArr[attr].attName == "_w1"):( 
						case of (
							default: (append W1_Array (Weight_Info_Struct weight1:1 weight2:0 weight3:0 weight4:0 weight5:0 weight6:0 weight7:0 weight8:0)) 
							(AttrArr[attr].vertType == 4):(
							weight5 = (ReadByte f #unsigned) as float / 255
							weight6 = (ReadByte f #unsigned) as float / 255
							weight7 = 0
							weight8 = 0
							weight1 = W1_array[v].Weight1
							weight2 = W1_array[v].Weight2
							weight3 = W1_array[v].Weight3
							weight4 = W1_array[v].Weight4
							W1_Array[v] = (Weight_Info_Struct weight1:weight1 weight2:weight2 weight3:weight3 weight4:weight4 weight5:weight5 weight6:weight6 weight7:weight7 weight8:weight8)
							)
							(AttrArr[attr].vertType == 10):(
							weight5 = (ReadByte f #unsigned) as float / 255
							weight6 = (ReadByte f #unsigned) as float / 255
							weight7 = (ReadByte f #unsigned) as float / 255
							weight8 = (ReadByte f #unsigned) as float / 255
							weight1 = W1_array[v].Weight1
							weight2 = W1_array[v].Weight2
							weight3 = W1_array[v].Weight3
							weight4 = W1_array[v].Weight4
							if weight5 >= 1 do(weight5 = 0)
							W1_Array[v] = (Weight_Info_Struct weight1:weight1 weight2:weight2 weight3:weight3 weight4:weight4 weight5:weight5 weight6:weight6 weight7:weight7 weight8:weight8)
							)
							(AttrArr[attr].vertType == 2061):(
							weight5 = ReadBEFloat f
							weight6 = ReadBEFloat f
							weight7 = 0
							weight8 = 0
							weight1 = W1_array[v].Weight1
							weight2 = W1_array[v].Weight2
							weight3 = W1_array[v].Weight3
							weight4 = W1_array[v].Weight4
							W1_Array[v] = (Weight_Info_Struct weight1:weight1 weight2:weight2 weight3:weight3 weight4:weight4 weight5:weight5 weight6:weight6 weight7:weight7 weight8:weight8)
							)
							(AttrArr[attr].vertType == 2065):(
							weight5 = ReadBEFloat f
							weight6 = ReadBEFloat f
							weight7 = ReadBEFloat f
							weight8 = ReadBEFloat f
							weight1 = W1_array[v].Weight1
							weight2 = W1_array[v].Weight2
							weight3 = W1_array[v].Weight3
							weight4 = W1_array[v].Weight4
							W1_Array[v] = (Weight_Info_Struct weight1:weight1 weight2:weight2 weight3:weight3 weight4:weight4 weight5:weight5 weight6:weight6 weight7:weight7 weight8:weight8)
							)
							(AttrArr[attr].vertType == 2067):(
							weight5 = ReadBEFloat f
							weight6 = ReadBEFloat f
							weight7 = ReadBEFloat f
							weight8 = ReadBEFloat f
							weight1 = W1_array[v].Weight1
							weight2 = W1_array[v].Weight2
							weight3 = W1_array[v].Weight3
							weight4 = W1_array[v].Weight4
							W1_Array[v] = (Weight_Info_Struct weight1:weight1 weight2:weight2 weight3:weight3 weight4:weight4 weight5:weight5 weight6:weight6 weight7:weight7 weight8:weight8)
							)
						)
						fseek f vertStart#seek_set
					)
				)-- Close Case of For Attributes
				fseek f (BuffArr[AttrArr[attr].buffIndx].strideSize)#seek_cur
			) -- Close Vert Read Loop
		) -- Close Attributes Loop
		) else (
		fseek f BuffArr[1].dataOffset#seek_set
		For v = 1 to FVTXArr[FSHPArr[m].fvtxIndx].vertCount Do (
			vertStart= ftell f
			For attr = 1 to AttrArr.count Do (
				case of (
					--Vertex Info--
					(AttrArr[attr].attName == "_p0"):(
						case of (
							(AttrArr[attr].vertType == 2063):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							vx = ReadBEHalfFloat f
							vy = ReadBEHalfFloat f
							vz = ReadBEHalfFloat f
							append vert_Array[vx,vy,vz]
							)
							(AttrArr[attr].vertType == 2065):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							vx = ReadBEFloat f
							vy = ReadBEFloat f
							vz = ReadBEFloat f
							append vert_Array[vx,vy,vz]
							)
						)
						fseek f vertStart#seek_set
					)
					--Color Info--
					(AttrArr[attr].attName == "_c0"):(
						case of (
							default: (append Color_Array [255,255,255])
							(AttrArr[attr].vertType == 2063):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							colorR = (ReadBEHalfFloat f * 255)
							colorG = (ReadBEHalfFloat f * 255)
							colorB = (ReadBEHalfFloat f * 255)
							colorA = (ReadBEHalfFloat f * 255)
							if colorR < 0 do(colorR = 0)
							if colorR > 255 do(colorR = 255)
							if colorG < 0 do(colorG = 0)
							if colorG > 255 do(colorG = 255)
							if colorB < 0 do(colorB = 0)
							if colorB > 255 do(colorB = 255)
							if colorA < 0 do(colorA = 0)
							if colorA > 255 do(colorA = 255)
							-- if these colours aren't clamped they'll go neon
							append Color_Array[colorR,colorG,colorB]
							)
							(AttrArr[attr].vertType == 2067):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
                            colorR = (ReadBEFloat f * 255)
                            colorG = (ReadBEFloat f * 255)
                            colorB = (ReadBEFloat f * 255)
                            colorA = (ReadBEFloat f * 255)
                            if colorR < 0 do(colorR = 0)
                            if colorR > 255 do(colorR = 255)
                            if colorG < 0 do(colorG = 0)
                            if colorG > 255 do(colorG = 255)
                            if colorB < 0 do(colorB = 0)
                            if colorB > 255 do(colorB = 255)
                            if colorA < 0 do(colorA = 0)
                            if colorA > 255 do(colorA = 255)
                            -- if these colours aren't clamped they'll go neon
                            append Color_Array[colorR,colorG,colorB]
                            )
							(AttrArr[attr].vertType == 10):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							colorR = ReadByte f #unsigned
							colorG = ReadByte f #unsigned
							colorB = ReadByte f #unsigned
							colorA = ReadByte f #unsigned
							append Color_Array[colorR,colorG,colorB]
							)
							(AttrArr[attr].vertType == 522):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							colorR = ReadByte f * 2
							colorG = ReadByte f * 2
							colorB = ReadByte f * 2
							colorA = ReadByte f * 2
                            if colorR < 0 do(colorR = 0)
                            if colorR > 254 do(colorR = 255)
                            if colorG < 0 do(colorG = 0)
                            if colorG > 254 do(colorG = 255)
                            if colorB < 0 do(colorB = 0)
                            if colorB > 254 do(colorB = 255)
                            if colorA < 0 do(colorA = 0)
                            if colorA > 254 do(colorA = 255)
							append Color_Array[colorR,colorG,colorB]
							)
						)
						fseek f vertStart#seek_set
					)
					--Normals Info--
					(AttrArr[attr].attName == "_n0"):(
						case of (
							(AttrArr[attr].vertType == 523):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							normVal = ReadBElong f
							nx = sign10(bit.and (normVal) 0x3FF) as float / 511
							ny = sign10(bit.and (bit.shift normVal -10) 0x3FF) as float / 511
							nz = sign10(bit.and (bit.shift normVal -20) 0x3FF) as float / 511
							append Normal_Array[nx,ny,nz]
							)
							(AttrArr[attr].vertType == 522):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							nx = ReadByte f as float / 127
							ny = ReadByte f as float / 127
							nz = ReadByte f as float / 127
							nw = ReadByte f as float / 127
							append Normal_Array[nx,ny,nz]
							)
							(AttrArr[attr].vertType == 2065):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							nx = ReadBEFloat f
							ny = ReadBEFloat f
							nz = ReadBEFloat f
							nw = ReadBEFloat f
							append Normal_Array[nx,ny,nz]
							)
						)
						fseek f vertStart#seek_set
					)
					--Tangent Info--
					--Binormals Info--
					--UV Info--
					(AttrArr[attr].attName == "_u0" or AttrArr[attr].attName == "color"):(
						case of (
							default: (append UV_Array[0,0,0]) 
							(AttrArr[attr].vertType == 4):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							tu = (ReadByte f #unsigned) as float / 255
							tv = (ReadByte f #unsigned) as float / 255
							append UV_Array[tu,tv,0]
							)
							(AttrArr[attr].vertType == 7):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							tu = ((ReadBEShort f as float)/65535)
							tv = (((ReadBEShort f as float)/65535)*-1) + 1
							append UV_Array[tu,tv,0]
							)
							(AttrArr[attr].vertType == 516):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							tu = (ReadByte f #unsigned) as float / 255
							tv = (ReadByte f #unsigned) as float / 255
							append UV_Array[tu,tv,0]
							)
							(AttrArr[attr].vertType == 519):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							tu = ((ReadBEShort f as float)/32767)
							tv = (((ReadBEShort f as float)/32767)*-1) + 1
							If tu < -1 Do (
								tu = tu + 2
							)
							If tv < 0 Do (
								tv = tv + 2
							)
							If tu > 1 Do (
								tu = tu - 2
							)
							If tv > 2 Do (
								tv = tv - 2
							)
							append UV_Array[tu,tv,0]
							)
							(AttrArr[attr].vertType == 2056):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							tu = readBEHalfFloat f
							tv = readBEHalfFloat f*-1
							append UV_Array[tu,tv,0]
							)
							(AttrArr[attr].vertType == 2061):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							tu = ReadBEFloat f
							tv = (ReadBEFloat f*-1) + 1
							append UV_Array[tu,tv,0]
							)
						)
						fseek f vertStart#seek_set
					)
					(AttrArr[attr].attName == "_u1"):(
						case of (
							default: (append UV2_Array[0,0,0]) 
							(AttrArr[attr].vertType == 4):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							tu2 = (ReadByte f #unsigned) as float / 255
							tv2 = (ReadByte f #unsigned) as float / 255
							append UV2_Array[tu2,tv2,0]
							)
							(AttrArr[attr].vertType == 7):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							tu2 = ((ReadBEShort f as float)/65535)
							tv2 = ((ReadBEShort f as float)/65535)*-1
							append UV2_Array[tu2,tv2,0]
							)
							(AttrArr[attr].vertType == 516):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							tu2 = (ReadByte f #unsigned) as float / 255
							tv2 = (ReadByte f #unsigned) as float / 255
							append UV2_Array[tu2,tv2,0]
							)
							(AttrArr[attr].vertType == 519):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							tu2 = ((ReadBEShort f as float)/32767)
							tv2 = ((ReadBEShort f as float)/32767)*-1
							If tu2 < -1 Do (
								tu2 = tu2 + 2
							)
							If tv2 < 0 Do (
								tv2 = tv2 + 2
							)
							If tu2 > 1 Do (
								tu2 = tu2 - 2
							)
							If tv2 > 2 Do (
								tv2 = tv2 - 2
							)
							append UV2_Array[tu2,tv2,0]
							)
							(AttrArr[attr].vertType == 2056):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							tu2 = readBEHalfFloat f
							tv2 = readBEHalfFloat f*-1
							append UV2_Array[tu2,tv2,0]
							)
							(AttrArr[attr].vertType == 2061):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							tu2 = ReadBEFloat f
							tv2 = ReadBEFloat f*-1
							append UV2_Array[tu2,tv2,0]
							)
						)
						fseek f vertStart#seek_set
					)
					(AttrArr[attr].attName == "_u2"):(
						case of (
							default: (append UV3_Array[0,0,0]) 
							(AttrArr[attr].vertType == 4):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							tu2 = (ReadByte f #unsigned) as float / 255
							tv2 = (ReadByte f #unsigned) as float / 255
							append UV3_Array[tu2,tv2,0]
							)
							(AttrArr[attr].vertType == 7):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							tu2 = ((ReadBEShort f as float)/65535)
							tv2 = ((ReadBEShort f as float)/65535)*-1
							append UV3_Array[tu2,tv2,0]
							)
							(AttrArr[attr].vertType == 519):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							tu2 = ((ReadBEShort f as float)/32767)
							tv2 = ((ReadBEShort f as float)/32767)*-1
							If tu2 < -1 Do (
								tu2 = tu2 + 2
							)
							If tv2 < 0 Do (
								tv2 = tv2 + 2
							)
							If tu2 > 1 Do (
								tu2 = tu2 - 2
							)
							If tv2 > 2 Do (
								tv2 = tv2 - 2
							)
							append UV3_Array[tu2,tv2,0]
							)
							(AttrArr[attr].vertType == 2056):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							tu2 = readBEHalfFloat f
							tv2 = readBEHalfFloat f*-1
							append UV3_Array[tu2,tv2,0]
							)
							(AttrArr[attr].vertType == 2061):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							tu2 = ReadBEFloat f
							tv2 = ReadBEFloat f*-1
							append UV3_Array[tu2,tv2,0]
							)
						)
						fseek f vertStart#seek_set
					)
					(AttrArr[attr].attName == "_u3"):(
						case of (
							default: (append UV4_Array[0,0,0]) 
							(AttrArr[attr].vertType == 4):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							tu2 = (ReadByte f #unsigned) as float / 255
							tv2 = (ReadByte f #unsigned) as float / 255
							append UV4_Array[tu2,tv2,0]
							)
							(AttrArr[attr].vertType == 7):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							tu2 = ((ReadBEShort f as float)/65535)
							tv2 = ((ReadBEShort f as float)/65535)*-1
							append UV4_Array[tu2,tv2,0]
							)
							(AttrArr[attr].vertType == 519):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							tu2 = ((ReadBEShort f as float)/32767)
							tv2 = ((ReadBEShort f as float)/32767)*-1
							If tu2 < -1 Do (
								tu2 = tu2 + 2
							)
							If tv2 < 0 Do (
								tv2 = tv2 + 2
							)
							If tu2 > 1 Do (
								tu2 = tu2 - 2
							)
							If tv2 > 2 Do (
								tv2 = tv2 - 2
							)
							append UV4_Array[tu2,tv2,0]
							)
							(AttrArr[attr].vertType == 2056):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							tu2 = readBEHalfFloat f
							tv2 = readBEHalfFloat f*-1
							append UV4_Array[tu2,tv2,0]
							)
							(AttrArr[attr].vertType == 2061):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							tu2 = ReadBEFloat f
							tv2 = ReadBEFloat f*-1
							append UV4_Array[tu2,tv2,0]
							)
						)
						fseek f vertStart#seek_set
					)
					(AttrArr[attr].attName == "_u4" or AttrArr[attr].attName == "All"):(
						case of (
							default: (append UV5_Array[0,0,0]) 
							(AttrArr[attr].vertType == 4):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							tu2 = (ReadByte f #unsigned) as float / 255
							tv2 = (ReadByte f #unsigned) as float / 255
							append UV5_Array[tu2,tv2,0]
							)
							(AttrArr[attr].vertType == 7):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							tu2 = ((ReadBEShort f as float)/65535)
							tv2 = ((ReadBEShort f as float)/65535)*-1
							append UV5_Array[tu2,tv2,0]
							)
							(AttrArr[attr].vertType == 519):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							tu2 = ((ReadBEShort f as float)/32767)
							tv2 = ((ReadBEShort f as float)/32767)*-1
							If tu2 < -1 Do (
								tu2 = tu2 + 2
							)
							If tv2 < 0 Do (
								tv2 = tv2 + 2
							)
							If tu2 > 1 Do (
								tu2 = tu2 - 2
							)
							If tv2 > 2 Do (
								tv2 = tv2 - 2
							)
							append UV5_Array[tu2,tv2,0]
							)
							(AttrArr[attr].vertType == 2056):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							tu2 = readBEHalfFloat f
							tv2 = readBEHalfFloat f*-1
							append UV5_Array[tu2,tv2,0]
							)
							(AttrArr[attr].vertType == 2061):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							tu2 = ReadBEFloat f
							tv2 = ReadBEFloat f*-1
							append UV5_Array[tu2,tv2,0]
							)
						)
						fseek f vertStart#seek_set
					)
					--BlendIndex Info--
					(AttrArr[attr].attName == "_i0"):(
						case of (
							(AttrArr[attr].vertType == 256):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							bone1 = ReadByte f#unsigned+1
							bone1 = Node_array[bone1]
							bone2 = 1
							bone3 = 1
							bone4 = 1
							bone5 = 1
							bone6 = 1
							bone7 = 1
							bone8 = 1
							weight1 = 1
							weight2 = 0
							weight3 = 0
							weight4 = 0
							weight5 = 0
							weight6 = 0
							weight7 = 0
							weight8 = 0
							append B1_Array (Bone_Info_Struct bone1:bone1 bone2:bone2 bone3:bone3 bone4:bone4 bone5:bone5 bone6:bone6 bone7:bone7 bone8:bone8)
							append W1_Array (Weight_Info_Struct weight1:weight1 weight2:weight2 weight3:weight3 weight4:weight4 weight5:weight5 weight6:weight6 weight7:weight7 weight8:weight8)
							)
							(AttrArr[attr].vertType == 260):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							bone1 = ReadByte f#unsigned+1
							bone1 = Node_array[Bone1]
							bone2 = ReadByte f#unsigned+1
							bone2 = Node_array[Bone2]
							bone3 = 1
							bone4 = 1
							bone5 = 1
							bone6 = 1
							bone7 = 1
							bone8 = 1
							append B1_Array (Bone_Info_Struct bone1:bone1 bone2:bone2 bone3:bone3 bone4:bone4 bone5:bone5 bone6:bone6 bone7:bone7 bone8:bone8)
							)
							(AttrArr[attr].vertType == 266):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							bone1 = ReadByte f#unsigned+1
							bone1 = Node_array[Bone1]
							bone2 = ReadByte f#unsigned+1
							bone2 = Node_array[Bone2]
							bone3 = ReadByte f#unsigned+1
							bone3 = Node_array[Bone3]
							bone4 = ReadByte f#unsigned+1
							bone4 = Node_array[Bone4]
							bone5 = 1
							bone6 = 1
							bone7 = 1
							bone8 = 1
							append B1_Array (Bone_Info_Struct bone1:bone1 bone2:bone2 bone3:bone3 bone4:bone4 bone5:bone5 bone6:bone6 bone7:bone7 bone8:bone8)
							)
							(AttrArr[attr].vertType == 268):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							bone1 = ReadBELong f +1
							bone1 = Node_array[Bone1]
							bone2 = ReadBELong f +1
							bone2 = Node_array[Bone2]
							bone3 = 1
							bone4 = 1
							bone5 = 1
							bone6 = 1
							bone7 = 1
							bone8 = 1
							append B1_Array (Bone_Info_Struct bone1:bone1 bone2:bone2 bone3:bone3 bone4:bone4 bone5:bone5 bone6:bone6 bone7:bone7 bone8:bone8)
							)
							(AttrArr[attr].vertType == 272):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							bone1 = ReadBELong f +1
							bone1 = Node_array[Bone1]
							bone2 = ReadBELong f +1
							bone2 = Node_array[Bone2]
							bone3 = ReadBELong f +1
							bone3 = Node_array[Bone3]
							bone4 = ReadBELong f +1
							bone4 = Node_array[Bone4]
							bone5 = 1
							bone6 = 1
							bone7 = 1
							bone8 = 1
							append B1_Array (Bone_Info_Struct bone1:bone1 bone2:bone2 bone3:bone3 bone4:bone4 bone5:bone5 bone6:bone6 bone7:bone7 bone8:bone8)
							)
							(AttrArr[attr].vertType == 274):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							bone1 = ReadBELong f +1
							bone1 = Node_array[Bone1]
							bone2 = ReadBELong f +1
							bone2 = Node_array[Bone2]
							bone3 = ReadBELong f +1
							bone3 = Node_array[Bone3]
							bone4 = ReadBELong f +1
							bone4 = Node_array[Bone4]
							bone5 = 1
							bone6 = 1
							bone7 = 1
							bone8 = 1
							append B1_Array (Bone_Info_Struct bone1:bone1 bone2:bone2 bone3:bone3 bone4:bone4 bone5:bone5 bone6:bone6 bone7:bone7 bone8:bone8)
							)
						)
						fseek f vertStart#seek_set
					)
					(AttrArr[attr].attName == "_i1"):(
						case of (
							(AttrArr[attr].vertType == 256):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							bone5 = ReadByte f#unsigned+1
							bone5 = Node_array[bone5]
							bone6 = 1
							bone7 = 1
							bone8 = 1
							weight5 = 1
							weight6 = 0
							weight7 = 0
							weight8 = 0
							bone1 = B1_array[v].Bone1
							bone2 = B1_array[v].Bone2
							bone3 = B1_array[v].Bone3
							bone4 = B1_array[v].Bone4
							weight1 = W1_array[v].Weight1
							weight2 = W1_array[v].Weight2
							weight3 = W1_array[v].Weight3
							weight4 = W1_array[v].Weight4
							B1_Array[v] = (Bone_Info_Struct bone1:bone1 bone2:bone2 bone3:bone3 bone4:bone4 bone5:bone5 bone6:bone6 bone7:bone7 bone8:bone8)
							W1_Array[v] = (Weight_Info_Struct weight1:weight1 weight2:weight2 weight3:weight3 weight4:weight4 weight5:weight5 weight6:weight6 weight7:weight7 weight8:weight8)
							)
							(AttrArr[attr].vertType == 260):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							bone5 = ReadByte f#unsigned+1
							bone5 = Node_array[Bone5]
							bone6 = ReadByte f#unsigned+1
							bone6 = Node_array[Bone6]
							bone7 = 1
							bone8 = 1
							bone1 = B1_array[v].Bone1
							bone2 = B1_array[v].Bone2
							bone3 = B1_array[v].Bone3
							bone4 = B1_array[v].Bone4
							B1_Array[v] = (Bone_Info_Struct bone1:bone1 bone2:bone2 bone3:bone3 bone4:bone4 bone5:bone5 bone6:bone6 bone7:bone7 bone8:bone8)
							)
							(AttrArr[attr].vertType == 266):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							bone5 = ReadByte f#unsigned+1
							bone5 = Node_array[Bone5]
							bone6 = ReadByte f#unsigned+1
							bone6 = Node_array[Bone6]
							bone7 = ReadByte f#unsigned+1
							bone7 = Node_array[Bone7]
							bone8 = ReadByte f#unsigned+1
							bone8 = Node_array[Bone8]
							bone1 = B1_array[v].Bone1
							bone2 = B1_array[v].Bone2
							bone3 = B1_array[v].Bone3
							bone4 = B1_array[v].Bone4
							B1_Array[v] = (Bone_Info_Struct bone1:bone1 bone2:bone2 bone3:bone3 bone4:bone4 bone5:bone5 bone6:bone6 bone7:bone7 bone8:bone8)
							)
							(AttrArr[attr].vertType == 268):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							bone5 = ReadBELong f +1
							bone5 = Node_array[Bone5]
							bone6 = ReadBELong f +1
							bone6 = Node_array[Bone6]
							bone7 = 1
							bone8 = 1
							bone1 = B1_array[v].Bone1
							bone2 = B1_array[v].Bone2
							bone3 = B1_array[v].Bone3
							bone4 = B1_array[v].Bone4
							B1_Array[v] = (Bone_Info_Struct bone1:bone1 bone2:bone2 bone3:bone3 bone4:bone4 bone5:bone5 bone6:bone6 bone7:bone7 bone8:bone8)
							)
							(AttrArr[attr].vertType == 272):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							bone5 = ReadBELong f +1
							bone5 = Node_array[Bone5]
							bone6 = ReadBELong f +1
							bone6 = Node_array[Bone6]
							bone7 = ReadBELong f +1
							bone7 = Node_array[Bone7]
							bone8 = ReadBELong f +1
							bone8 = Node_array[Bone8]
							bone1 = B1_array[v].Bone1
							bone2 = B1_array[v].Bone2
							bone3 = B1_array[v].Bone3
							bone4 = B1_array[v].Bone4
							B1_Array[v] = (Bone_Info_Struct bone1:bone1 bone2:bone2 bone3:bone3 bone4:bone4 bone5:bone5 bone6:bone6 bone7:bone7 bone8:bone8)
							)
							(AttrArr[attr].vertType == 274):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							bone5 = ReadBELong f +1
							bone5 = Node_array[Bone5]
							bone6 = ReadBELong f +1
							bone6 = Node_array[Bone6]
							bone7 = ReadBELong f +1
							bone7 = Node_array[Bone7]
							bone8 = ReadBELong f +1
							bone8 = Node_array[Bone8]
							bone1 = B1_array[v].Bone1
							bone2 = B1_array[v].Bone2
							bone3 = B1_array[v].Bone3
							bone4 = B1_array[v].Bone4
							B1_Array[v] = (Bone_Info_Struct bone1:bone1 bone2:bone2 bone3:bone3 bone4:bone4 bone5:bone5 bone6:bone6 bone7:bone7 bone8:bone8)
							)
						)
						fseek f vertStart#seek_set
					)
					-- BlendWeight Info --
					(AttrArr[attr].attName == "_w0"):( 
						case of (
							default: (append W1_Array (Weight_Info_Struct weight1:1 weight2:0 weight3:0 weight4:0 weight5:0 weight6:0 weight7:0 weight8:0)) 
							(AttrArr[attr].vertType == 4):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							weight1 = (ReadByte f #unsigned) as float / 255
							weight2 = (ReadByte f #unsigned) as float / 255
							weight3 = 0
							weight4 = 0
							weight5 = 0
							weight6 = 0
							weight7 = 0
							weight8 = 0
							append W1_Array (Weight_Info_Struct weight1:weight1 weight2:weight2 weight3:weight3 weight4:weight4 weight5:weight5 weight6:weight6 weight7:weight7 weight8:weight8)
							)
							(AttrArr[attr].vertType == 10):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							weight1 = (ReadByte f #unsigned) as float / 255
							weight2 = (ReadByte f #unsigned) as float / 255
							weight3 = (ReadByte f #unsigned) as float / 255
							weight4 = (ReadByte f #unsigned) as float / 255
							weight5 = 0
							weight6 = 0
							weight7 = 0
							weight8 = 0
							if weight4 >= 1 do(weight4 = 0)
							append W1_Array (Weight_Info_Struct weight1:weight1 weight2:weight2 weight3:weight3 weight4:weight4 weight5:weight5 weight6:weight6 weight7:weight7 weight8:weight8)
							)
							(AttrArr[attr].vertType == 2061):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							weight1 = ReadBEFloat f
							weight2 = ReadBEFloat f
							weight3 = 0
							weight4 = 0
							weight5 = 0
							weight6 = 0
							weight7 = 0
							weight8 = 0
							append W1_Array (Weight_Info_Struct weight1:weight1 weight2:weight2 weight3:weight3 weight4:weight4 weight5:weight5 weight6:weight6 weight7:weight7 weight8:weight8)
							)
							(AttrArr[attr].vertType == 2065):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							weight1 = ReadBEFloat f
							weight2 = ReadBEFloat f
							weight3 = ReadBEFloat f
							weight4 = ReadBEFloat f
							weight5 = 0
							weight6 = 0
							weight7 = 0
							weight8 = 0
							append W1_Array (Weight_Info_Struct weight1:weight1 weight2:weight2 weight3:weight3 weight4:weight4 weight5:weight5 weight6:weight6 weight7:weight7 weight8:weight8)
							)
							(AttrArr[attr].vertType == 2067):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							weight1 = ReadBEFloat f
							weight2 = ReadBEFloat f
							weight3 = ReadBEFloat f
							weight4 = ReadBEFloat f
							weight5 = 0
							weight6 = 0
							weight7 = 0
							weight8 = 0
							append W1_Array (Weight_Info_Struct weight1:weight1 weight2:weight2 weight3:weight3 weight4:weight4 weight5:weight5 weight6:weight6 weight7:weight7 weight8:weight8)
							)
						)
						fseek f vertStart#seek_set
					)
					(AttrArr[attr].attName == "_w1"):( 
						case of (
							default: (append W1_Array (Weight_Info_Struct weight1:1 weight2:0 weight3:0 weight4:0 weight5:0 weight6:0 weight7:0 weight8:0)) 
							(AttrArr[attr].vertType == 4):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							weight5 = (ReadByte f #unsigned) as float / 255
							weight6 = (ReadByte f #unsigned) as float / 255
							weight7 = 0
							weight8 = 0
							weight1 = W1_array[v].Weight1
							weight2 = W1_array[v].Weight2
							weight3 = W1_array[v].Weight3
							weight4 = W1_array[v].Weight4
							W1_Array[v] = (Weight_Info_Struct weight1:weight1 weight2:weight2 weight3:weight3 weight4:weight4 weight5:weight5 weight6:weight6 weight7:weight7 weight8:weight8)
							)
							(AttrArr[attr].vertType == 10):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							weight5 = (ReadByte f #unsigned) as float / 255
							weight6 = (ReadByte f #unsigned) as float / 255
							weight7 = (ReadByte f #unsigned) as float / 255
							weight8 = (ReadByte f #unsigned) as float / 255
							weight1 = W1_array[v].Weight1
							weight2 = W1_array[v].Weight2
							weight3 = W1_array[v].Weight3
							weight4 = W1_array[v].Weight4
							if weight5 >= 1 do(weight5 = 0)
							W1_Array[v] = (Weight_Info_Struct weight1:weight1 weight2:weight2 weight3:weight3 weight4:weight4 weight5:weight5 weight6:weight6 weight7:weight7 weight8:weight8)
							)
							(AttrArr[attr].vertType == 2061):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							weight5 = ReadBEFloat f
							weight6 = ReadBEFloat f
							weight7 = 0
							weight8 = 0
							weight1 = W1_array[v].Weight1
							weight2 = W1_array[v].Weight2
							weight3 = W1_array[v].Weight3
							weight4 = W1_array[v].Weight4
							W1_Array[v] = (Weight_Info_Struct weight1:weight1 weight2:weight2 weight3:weight3 weight4:weight4 weight5:weight5 weight6:weight6 weight7:weight7 weight8:weight8)
							)
							(AttrArr[attr].vertType == 2065):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							weight5 = ReadBEFloat f
							weight6 = ReadBEFloat f
							weight7 = ReadBEFloat f
							weight8 = ReadBEFloat f
							weight1 = W1_array[v].Weight1
							weight2 = W1_array[v].Weight2
							weight3 = W1_array[v].Weight3
							weight4 = W1_array[v].Weight4
							W1_Array[v] = (Weight_Info_Struct weight1:weight1 weight2:weight2 weight3:weight3 weight4:weight4 weight5:weight5 weight6:weight6 weight7:weight7 weight8:weight8)
							)
							(AttrArr[attr].vertType == 2067):(
							fseek f (AttrArr[attr].buffOff)#seek_cur
							weight5 = ReadBEFloat f
							weight6 = ReadBEFloat f
							weight7 = ReadBEFloat f
							weight8 = ReadBEFloat f
							weight1 = W1_array[v].Weight1
							weight2 = W1_array[v].Weight2
							weight3 = W1_array[v].Weight3
							weight4 = W1_array[v].Weight4
							W1_Array[v] = (Weight_Info_Struct weight1:weight1 weight2:weight2 weight3:weight3 weight4:weight4 weight5:weight5 weight6:weight6 weight7:weight7 weight8:weight8)
							)
						)
						fseek f vertStart#seek_set
					)
				) -- Close Case of For Attributes
			) -- Close Attributes Loop
			fseek f BuffArr[1].StrideSize#seek_cur
		) -- Close Vert Read Loop
		)

		If Color_Array.count != Vert_Array.count Do (
			For ca = 1 to Vert_array.count Do (
				append Color_Array[255,255,255]
			)
		)

		for b = 1 to W1_Array.count Do (
			w = (weight_data boneids:#() weights:#())
			maxweight = 0
			
			if(W1_array[b].Weight1 != 0) then
				maxweight = maxweight + W1_array[b].Weight1
			if(W1_array[b].Weight2 != 0) then
				maxweight = maxweight + W1_array[b].Weight2
			if(W1_array[b].Weight3 != 0) then
				maxweight = maxweight + W1_array[b].Weight3
			if(W1_array[b].Weight4 != 0) then
				maxweight = maxweight + W1_array[b].Weight4
			if(W1_array[b].Weight5 != 0) then
				maxweight = maxweight + W1_array[b].Weight5
			if(W1_array[b].Weight6 != 0) then
				maxweight = maxweight + W1_array[b].Weight6
			if(W1_array[b].Weight7 != 0) then
				maxweight = maxweight + W1_array[b].Weight7
			if(W1_array[b].Weight8 != 0) then
				maxweight = maxweight + W1_array[b].Weight8
				
			if(maxweight != 0) then
			(
				if(W1_array[b].Weight1 != 0) then
				(
					w1 = W1_array[b].Weight1 as float
					append w.boneids (B1_array[b].Bone1)
					append w.weights (w1)
				)
				if(W1_array[b].Weight2 != 0) then
				(
					w2 = W1_array[b].Weight2 as float
					append w.boneids (B1_array[b].Bone2)
					append w.weights (w2)
				)
				if(W1_array[b].Weight3 != 0) then
				(
					w3 = W1_array[b].Weight3 as float
					append w.boneids (B1_array[b].Bone3)
					append w.weights (w3)
				)
				if(W1_array[b].Weight4 != 0) then
				(
					w4 = W1_array[b].Weight4 as float
					append w.boneids (B1_array[b].Bone4)
					append w.weights (w4)
				)
				if(W1_array[b].Weight5 != 0) then
				(
					w5 = W1_array[b].Weight5 as float
					append w.boneids (B1_array[b].Bone5)
					append w.weights (w5)
				)
				if(W1_array[b].Weight6 != 0) then
				(
					w6 = W1_array[b].Weight6 as float
					append w.boneids (B1_array[b].Bone6)
					append w.weights (w6)
				)
				if(W1_array[b].Weight7 != 0) then
				(
					w7 = W1_array[b].Weight7 as float
					append w.boneids (B1_array[b].Bone7)
					append w.weights (w7)
				)
				if(W1_array[b].Weight8 != 0) then
				(
					w8 = W1_array[b].Weight8 as float
					append w.boneids (B1_array[b].Bone8)
					append w.weights (w8)
				)
			)
			append Weight_array w
		)

		fseek f FSHPArr[m].lodMdlOff#seek_set
	if LODs == 1 do(FSHPArr[m].lodMdlCount =  1) 
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
				For face = 1 to FaceCount Do (
				fa = ((ReadBEShort f) + 1 + PolyStart)
				fb = ((ReadBEShort f) + 1 + PolyStart)
				fc = ((ReadBEShort f) + 1 + PolyStart)
				append Face_Array[fa,fb,fc]
				)
			)
			(lodmdl_info.faceType == 9):(
				FaceCount = (FaceCount/12)
				For face = 1 to FaceCount Do (
					fa = ((ReadBELong f) + 1 + PolyStart)
					fb = ((ReadBELong f) + 1 + PolyStart)
					fc = ((ReadBELong f) + 1 + PolyStart)
					append Face_Array[fa,fb,fc]
				)
			)
		)

		BoneCount = BoneArray.count
		mat = standardMaterial()
		mat.name = (FMATNameArr[FSHPArr[m].fmatIndx] as string)
		mat.showinviewport = true
		mat.twosided = false
		fseek f (FMATArr[FSHPArr[m].fmatIndx].texSelOff)#seek_set
		TextureNameOffset = readoffset f
		fseek f TextureNameOffset#seek_set
		TextureName = readstring f
		if TexFormat == 2 then (tm = Bitmaptexture filename:(p + TextureName as string + ".png")) else (tm = Bitmaptexture filename:(p + TextureName as string + ".dds"))
		tm.alphasource = 0
		mat.diffuseMap = tm
		mat.opacityMap = tm
		mat.opacityMap.monoOutput = 1

		msh = mesh vertices:Vert_array faces:Face_array
		msh.numTVerts = Vert_Array.count
		setNumCPVVerts msh msh.numTVerts
		setCVertMode msh true
		setShadeCVerts msh true
		defaultVCFaces msh
		buildTVFaces msh
		for j = 1 to Color_Array.count do setvertcolor msh j Color_array[j]
		If Vert_Array.count == UV_Array.count Do (
			for j = 1 to Vert_array.count do setTVert msh j UV_array[j]
			for j = 1 to Face_array.count do setTVFace msh j Face_array[j]
		)
		for j = 1 to msh.numfaces do setFaceSmoothGroup msh j 1
			
		if FSHPArr[m].lodMdlCount == 1 then(msh.name = (MeshName)) else (msh.name = (MeshName + " (LOD: " + l as string + ")"))
		msh.material = mat
		
 		max modify mode
 		select msh

		addmodifier msh (Edit_Normals ()) ui:off
		msh.Edit_Normals.MakeExplicit selection:#{1..Normal_array.count}
		EN_convertVS = msh.Edit_Normals.ConvertVertexSelection
		EN_setNormal = msh.Edit_Normals.SetNormal
		normID = #{}
		for v = 1 to Normal_array.count do
		(
			free normID
			EN_convertVS #{v} &normID
			for id in normID do EN_setNormal id Normal_array[v]
		)

		if BoneCount > 0 do(
				if FSHPArr[m].matrFlag == 0 then(
					$.transform = BoneFixArray[FSHPArr[m].fsklIndx]
					if RigModel != 2 do(
					skinMod = skin ()
					addModifier msh skinMod
					maxbone = getnodebyname BoneArray[FSHPArr[m].fsklIndx].name
					skinOps.addBone skinMod maxbone 0
					)
				) else ( if RigModel != 2 do(
				skinMod = skin ()
				boneIDMap = #()
				addModifier msh skinMod
				msh.Skin.weightAllVertices = false

				if FSHPArr[m].matrFlag == 1 do(
					for b = 1 to BoneCount do(
						select BoneArray[b]
						$.transform = matrix3 [1,0,0] [0,1,0] [0,0,1] [0,0,0]
					)
					
					select msh
				)

				for i = 1 to BoneCount do
				(
					maxbone = getnodebyname BoneArray[i].name
					if i != BoneCount then (
						skinOps.addBone skinMod maxbone 0
					)else(
						skinOps.addBone skinMod maxbone 1
					)
				)
				
				local numSkinBones = skinOps.GetNumberBones skinMod
				for i = 1 to numSkinBones do
				(
					local boneName = skinOps.GetBoneName skinMod i 0
					for j = 1 to BoneCount do
					(
						if boneName == BoneArray[j].Name then
						(
							boneIDMap[j] = i
							j = BoneCount + 1
						)
					)
				) -- Thanks to sunnydavis for the fix!
				
				modPanel.setCurrentObject skinMod

			for i = 1 to Vert_array.count do(
				skinOps.SetVertexWeights skinMod i 1 1
				skinOps.unnormalizeVertex skinMod i true 
				skinOps.SetVertexWeights skinMod i 1 0
			)
				skinOps.RemoveZeroWeights skinMod
			for i = 1 to Vert_array.count do(
				skinOps.unnormalizeVertex skinMod i false
			)

				for i = 1 to Weight_array.count do (
					w = Weight_array[i]
					bi = #() --bone index array
					wv = #() --weight value array
					
					for j = 1 to w.boneids.count do
					(
						boneid = w.boneids[j]
						weight = w.weights[j]
						append bi boneIDMap[boneid]
						append wv weight
					)   
					skinOps.ReplaceVertexWeights skinMod i bi wv
				)

				if FSHPArr[m].matrFlag == 1 do(
					for b = 1 to BoneCount do(
						select BoneArray[b]
						$.transform = BoneFixArray[b]
					)
				)

			)
			)
		)

	if UVLayers == 1 do(
	if UV2_array.count > 1 do(
		mat = standardMaterial()
		mat.name = (FMATNameArr[FSHPArr[m].fmatIndx] as string)
		mat.showinviewport = true
		mat.twosided = false
		fseek f (FMATArr[FSHPArr[m].fmatIndx].texSelOff)#seek_set
		TextureNameOffset = readoffset f
		fseek f TextureNameOffset#seek_set
		TextureName = readstring f
		if TexFormat == 2 then (tm = Bitmaptexture filename:(p + TextureName as string + ".png")) else (tm = Bitmaptexture filename:(p + TextureName as string + ".dds"))
		tm.alphasource = 0
		mat.diffuseMap = tm
		mat.opacityMap = tm
		mat.opacityMap.monoOutput = 1
		
		msh = mesh vertices:Vert_array faces:Face_array
		msh.numTVerts = Vert_Array.count
		setNumCPVVerts msh msh.numTVerts
		setCVertMode msh true
		setShadeCVerts msh true
		defaultVCFaces msh
		buildTVFaces msh
		for j = 1 to Color_Array.count do setvertcolor msh j Color_array[j]
		If Vert_Array.count == UV2_Array.count Do (
			for j = 1 to Vert_array.count do setTVert msh j UV2_array[j]
			for j = 1 to Face_array.count do setTVFace msh j Face_array[j]
		)
		for j = 1 to msh.numfaces do setFaceSmoothGroup msh j 1
			
		if FSHPArr[m].lodMdlCount == 1 then(msh.name = (MeshName) + " Layer 2") else (msh.name = (MeshName + " Layer 2" + " (LOD: " + l as string + ")"))
		msh.material = mat
		
 		max modify mode
 		select msh
		
		addmodifier msh (Edit_Normals ()) ui:off
		msh.Edit_Normals.MakeExplicit selection:#{1..Normal_array.count}
		EN_convertVS = msh.Edit_Normals.ConvertVertexSelection
		EN_setNormal = msh.Edit_Normals.SetNormal
		normID = #{}
		for v = 1 to Normal_array.count do
		(
			free normID
			EN_convertVS #{v} &normID
			for id in normID do EN_setNormal id Normal_array[v]
		)

		if BoneCount > 0 do(
				if FSHPArr[m].matrFlag == 0 then(
					$.transform = BoneFixArray[FSHPArr[m].fsklIndx]
					if RigModel != 2 do(
					skinMod = skin ()
					addModifier msh skinMod
					maxbone = getnodebyname BoneArray[FSHPArr[m].fsklIndx].name
					skinOps.addBone skinMod maxbone 0
					)
				) else ( if RigModel != 2 do(
				skinMod = skin ()
				boneIDMap = #()
				addModifier msh skinMod
				msh.Skin.weightAllVertices = false

				if FSHPArr[m].matrFlag == 1 do(
					for b = 1 to BoneCount do(
						select BoneArray[b]
						$.transform = matrix3 [1,0,0] [0,1,0] [0,0,1] [0,0,0]
					)
					
					select msh
				)

				for i = 1 to BoneCount do
				(
					maxbone = getnodebyname BoneArray[i].name
					if i != BoneCount then (
						skinOps.addBone skinMod maxbone 0
					)else(
						skinOps.addBone skinMod maxbone 1
					)
				)
				
				local numSkinBones = skinOps.GetNumberBones skinMod
				for i = 1 to numSkinBones do
				(
					local boneName = skinOps.GetBoneName skinMod i 0
					for j = 1 to BoneCount do
					(
						if boneName == BoneArray[j].Name then
						(
							boneIDMap[j] = i
							j = BoneCount + 1
						)
					)
				) -- Thanks to sunnydavis for the fix!
				
				modPanel.setCurrentObject skinMod

			for i = 1 to Vert_array.count do(
				skinOps.SetVertexWeights skinMod i 1 1
				skinOps.unnormalizeVertex skinMod i true 
				skinOps.SetVertexWeights skinMod i 1 0
			)
				skinOps.RemoveZeroWeights skinMod
			for i = 1 to Vert_array.count do(
				skinOps.unnormalizeVertex skinMod i false
			)

				for i = 1 to Weight_array.count do (
					w = Weight_array[i]
					bi = #() --bone index array
					wv = #() --weight value array
					
					for j = 1 to w.boneids.count do
					(
						boneid = w.boneids[j]
						weight = w.weights[j]
						append bi boneIDMap[boneid]
						append wv weight
					)   
					skinOps.ReplaceVertexWeights skinMod i bi wv
				)

				if FSHPArr[m].matrFlag == 1 do(
					for b = 1 to BoneCount do(
						select BoneArray[b]
						$.transform = BoneFixArray[b]
					)
				)

			)
			)
		)

	)

	if UV3_array.count > 1 do(
		mat = standardMaterial()
		mat.name = (FMATNameArr[FSHPArr[m].fmatIndx] as string)
		mat.showinviewport = true
		mat.twosided = false
		fseek f (FMATArr[FSHPArr[m].fmatIndx].texSelOff)#seek_set
		TextureNameOffset = readoffset f
		fseek f TextureNameOffset#seek_set
		TextureName = readstring f
		if TexFormat == 2 then (tm = Bitmaptexture filename:(p + TextureName as string + ".png")) else (tm = Bitmaptexture filename:(p + TextureName as string + ".dds"))
		tm.alphasource = 0
		mat.diffuseMap = tm
		mat.opacityMap = tm
		mat.opacityMap.monoOutput = 1
		
		msh = mesh vertices:Vert_array faces:Face_array
		msh.numTVerts = Vert_Array.count
		setNumCPVVerts msh msh.numTVerts
		setCVertMode msh true
		setShadeCVerts msh true
		defaultVCFaces msh
		buildTVFaces msh
		for j = 1 to Color_Array.count do setvertcolor msh j Color_array[j]
		If Vert_Array.count == UV3_Array.count Do (
			for j = 1 to Vert_array.count do setTVert msh j UV3_array[j]
			for j = 1 to Face_array.count do setTVFace msh j Face_array[j]
		)
		for j = 1 to msh.numfaces do setFaceSmoothGroup msh j 1
			
		if FSHPArr[m].lodMdlCount == 1 then(msh.name = (MeshName) + " Layer 3") else (msh.name = (MeshName + " Layer 3" + " (LOD: " + l as string + ")"))
		msh.material = mat

 		max modify mode
 		select msh
		
		addmodifier msh (Edit_Normals ()) ui:off
		msh.Edit_Normals.MakeExplicit selection:#{1..Normal_array.count}
		EN_convertVS = msh.Edit_Normals.ConvertVertexSelection
		EN_setNormal = msh.Edit_Normals.SetNormal
		normID = #{}
		for v = 1 to Normal_array.count do
		(
			free normID
			EN_convertVS #{v} &normID
			for id in normID do EN_setNormal id Normal_array[v]
		)

		if BoneCount > 0 do(
				if FSHPArr[m].matrFlag == 0 then(
					$.transform = BoneFixArray[FSHPArr[m].fsklIndx]
					if RigModel != 2 do(
					skinMod = skin ()
					addModifier msh skinMod
					maxbone = getnodebyname BoneArray[FSHPArr[m].fsklIndx].name
					skinOps.addBone skinMod maxbone 0
					)
				) else ( if RigModel != 2 do(
				skinMod = skin ()
				boneIDMap = #()
				addModifier msh skinMod
				msh.Skin.weightAllVertices = false

				if FSHPArr[m].matrFlag == 1 do(
					for b = 1 to BoneCount do(
						select BoneArray[b]
						$.transform = matrix3 [1,0,0] [0,1,0] [0,0,1] [0,0,0]
					)
					
					select msh
				)

				for i = 1 to BoneCount do
				(
					maxbone = getnodebyname BoneArray[i].name
					if i != BoneCount then (
						skinOps.addBone skinMod maxbone 0
					)else(
						skinOps.addBone skinMod maxbone 1
					)
				)
				
				local numSkinBones = skinOps.GetNumberBones skinMod
				for i = 1 to numSkinBones do
				(
					local boneName = skinOps.GetBoneName skinMod i 0
					for j = 1 to BoneCount do
					(
						if boneName == BoneArray[j].Name then
						(
							boneIDMap[j] = i
							j = BoneCount + 1
						)
					)
				) -- Thanks to sunnydavis for the fix!
				
				modPanel.setCurrentObject skinMod

			for i = 1 to Vert_array.count do(
				skinOps.SetVertexWeights skinMod i 1 1
				skinOps.unnormalizeVertex skinMod i true 
				skinOps.SetVertexWeights skinMod i 1 0
			)
				skinOps.RemoveZeroWeights skinMod
			for i = 1 to Vert_array.count do(
				skinOps.unnormalizeVertex skinMod i false
			)

				for i = 1 to Weight_array.count do (
					w = Weight_array[i]
					bi = #() --bone index array
					wv = #() --weight value array
					
					for j = 1 to w.boneids.count do
					(
						boneid = w.boneids[j]
						weight = w.weights[j]
						append bi boneIDMap[boneid]
						append wv weight
					)   
					skinOps.ReplaceVertexWeights skinMod i bi wv
				)

				if FSHPArr[m].matrFlag == 1 do(
					for b = 1 to BoneCount do(
						select BoneArray[b]
						$.transform = BoneFixArray[b]
					)
				)

			)
			)
		)

	)
	
	if UV4_array.count > 1 do(
		mat = standardMaterial()
		mat.name = (FMATNameArr[FSHPArr[m].fmatIndx] as string)
		mat.showinviewport = true
		mat.twosided = false
		fseek f (FMATArr[FSHPArr[m].fmatIndx].texSelOff)#seek_set
		TextureNameOffset = readoffset f
		fseek f TextureNameOffset#seek_set
		TextureName = readstring f
		if TexFormat == 2 then (tm = Bitmaptexture filename:(p + TextureName as string + ".png")) else (tm = Bitmaptexture filename:(p + TextureName as string + ".dds"))
		tm.alphasource = 0
		mat.diffuseMap = tm
		mat.opacityMap = tm
		mat.opacityMap.monoOutput = 1
		
		msh = mesh vertices:Vert_array faces:Face_array
		msh.numTVerts = Vert_Array.count
		setNumCPVVerts msh msh.numTVerts
		setCVertMode msh true
		setShadeCVerts msh true
		defaultVCFaces msh
		buildTVFaces msh
		for j = 1 to Color_Array.count do setvertcolor msh j Color_array[j]
		If Vert_Array.count == UV4_Array.count Do (
			for j = 1 to Vert_array.count do setTVert msh j UV4_array[j]
			for j = 1 to Face_array.count do setTVFace msh j Face_array[j]
		)
		for j = 1 to msh.numfaces do setFaceSmoothGroup msh j 1
			
		if FSHPArr[m].lodMdlCount == 1 then(msh.name = (MeshName) + " Layer 4") else (msh.name = (MeshName + " Layer 4" + " (LOD: " + l as string + ")"))
		msh.material = mat

 		max modify mode
 		select msh
		
		addmodifier msh (Edit_Normals ()) ui:off
		msh.Edit_Normals.MakeExplicit selection:#{1..Normal_array.count}
		EN_convertVS = msh.Edit_Normals.ConvertVertexSelection
		EN_setNormal = msh.Edit_Normals.SetNormal
		normID = #{}
		for v = 1 to Normal_array.count do
		(
			free normID
			EN_convertVS #{v} &normID
			for id in normID do EN_setNormal id Normal_array[v]
		)

		if BoneCount > 0 do(
				if FSHPArr[m].matrFlag == 0 then(
					$.transform = BoneFixArray[FSHPArr[m].fsklIndx]
					if RigModel != 2 do(
					skinMod = skin ()
					addModifier msh skinMod
					maxbone = getnodebyname BoneArray[FSHPArr[m].fsklIndx].name
					skinOps.addBone skinMod maxbone 0
					)
				) else ( if RigModel != 2 do(
				skinMod = skin ()
				boneIDMap = #()
				addModifier msh skinMod
				msh.Skin.weightAllVertices = false

				if FSHPArr[m].matrFlag == 1 do(
					for b = 1 to BoneCount do(
						select BoneArray[b]
						$.transform = matrix3 [1,0,0] [0,1,0] [0,0,1] [0,0,0]
					)
					
					select msh
				)

				for i = 1 to BoneCount do
				(
					maxbone = getnodebyname BoneArray[i].name
					if i != BoneCount then (
						skinOps.addBone skinMod maxbone 0
					)else(
						skinOps.addBone skinMod maxbone 1
					)
				)
				
				local numSkinBones = skinOps.GetNumberBones skinMod
				for i = 1 to numSkinBones do
				(
					local boneName = skinOps.GetBoneName skinMod i 0
					for j = 1 to BoneCount do
					(
						if boneName == BoneArray[j].Name then
						(
							boneIDMap[j] = i
							j = BoneCount + 1
						)
					)
				) -- Thanks to sunnydavis for the fix!
				
				modPanel.setCurrentObject skinMod

			for i = 1 to Vert_array.count do(
				skinOps.SetVertexWeights skinMod i 1 1
				skinOps.unnormalizeVertex skinMod i true 
				skinOps.SetVertexWeights skinMod i 1 0
			)
				skinOps.RemoveZeroWeights skinMod
			for i = 1 to Vert_array.count do(
				skinOps.unnormalizeVertex skinMod i false
			)

				for i = 1 to Weight_array.count do (
					w = Weight_array[i]
					bi = #() --bone index array
					wv = #() --weight value array
					
					for j = 1 to w.boneids.count do
					(
						boneid = w.boneids[j]
						weight = w.weights[j]
						append bi boneIDMap[boneid]
						append wv weight
					)   
					skinOps.ReplaceVertexWeights skinMod i bi wv
				)

				if FSHPArr[m].matrFlag == 1 do(
					for b = 1 to BoneCount do(
						select BoneArray[b]
						$.transform = BoneFixArray[b]
					)
				)

			)
			)
		)

	)
	
	if UV5_array.count > 1 do(
		mat = standardMaterial()
		mat.name = (FMATNameArr[FSHPArr[m].fmatIndx] as string)
		mat.showinviewport = true
		mat.twosided = false
		fseek f (FMATArr[FSHPArr[m].fmatIndx].texSelOff)#seek_set
		TextureNameOffset = readoffset f
		fseek f TextureNameOffset#seek_set
		TextureName = readstring f
		if TexFormat == 2 then (tm = Bitmaptexture filename:(p + TextureName as string + ".png")) else (tm = Bitmaptexture filename:(p + TextureName as string + ".dds"))
		tm.alphasource = 0
		mat.diffuseMap = tm
		mat.opacityMap = tm
		mat.opacityMap.monoOutput = 1
		
		msh = mesh vertices:Vert_array faces:Face_array
		msh.numTVerts = Vert_Array.count
		setNumCPVVerts msh msh.numTVerts
		setCVertMode msh true
		setShadeCVerts msh true
		defaultVCFaces msh
		buildTVFaces msh
		for j = 1 to Color_Array.count do setvertcolor msh j Color_array[j]
		If Vert_Array.count == UV5_Array.count Do (
			for j = 1 to Vert_array.count do setTVert msh j UV5_array[j]
			for j = 1 to Face_array.count do setTVFace msh j Face_array[j]
		)
		for j = 1 to msh.numfaces do setFaceSmoothGroup msh j 1
			
		if FSHPArr[m].lodMdlCount == 1 then(msh.name = (MeshName) + " Layer 5") else (msh.name = (MeshName + " Layer 5" + " (LOD: " + l as string + ")"))
		msh.material = mat

 		max modify mode
 		select msh
		
		addmodifier msh (Edit_Normals ()) ui:off
		msh.Edit_Normals.MakeExplicit selection:#{1..Normal_array.count}
		EN_convertVS = msh.Edit_Normals.ConvertVertexSelection
		EN_setNormal = msh.Edit_Normals.SetNormal
		normID = #{}
		for v = 1 to Normal_array.count do
		(
			free normID
			EN_convertVS #{v} &normID
			for id in normID do EN_setNormal id Normal_array[v]
		)

		if BoneCount > 0 do(
				if FSHPArr[m].matrFlag == 0 then(
					$.transform = BoneFixArray[FSHPArr[m].fsklIndx]
					if RigModel != 2 do(
					skinMod = skin ()
					addModifier msh skinMod
					maxbone = getnodebyname BoneArray[FSHPArr[m].fsklIndx].name
					skinOps.addBone skinMod maxbone 0
					)
				) else ( if RigModel != 2 do(
				skinMod = skin ()
				boneIDMap = #()
				addModifier msh skinMod
				msh.Skin.weightAllVertices = false

				if FSHPArr[m].matrFlag == 1 do(
					for b = 1 to BoneCount do(
						select BoneArray[b]
						$.transform = matrix3 [1,0,0] [0,1,0] [0,0,1] [0,0,0]
					)
					
					select msh
				)

				for i = 1 to BoneCount do
				(
					maxbone = getnodebyname BoneArray[i].name
					if i != BoneCount then (
						skinOps.addBone skinMod maxbone 0
					)else(
						skinOps.addBone skinMod maxbone 1
					)
				)
				
				local numSkinBones = skinOps.GetNumberBones skinMod
				for i = 1 to numSkinBones do
				(
					local boneName = skinOps.GetBoneName skinMod i 0
					for j = 1 to BoneCount do
					(
						if boneName == BoneArray[j].Name then
						(
							boneIDMap[j] = i
							j = BoneCount + 1
						)
					)
				) -- Thanks to sunnydavis for the fix!
				
				modPanel.setCurrentObject skinMod

			for i = 1 to Vert_array.count do(
				skinOps.SetVertexWeights skinMod i 1 1
				skinOps.unnormalizeVertex skinMod i true 
				skinOps.SetVertexWeights skinMod i 1 0
			)
				skinOps.RemoveZeroWeights skinMod
			for i = 1 to Vert_array.count do(
				skinOps.unnormalizeVertex skinMod i false
			)

				for i = 1 to Weight_array.count do (
					w = Weight_array[i]
					bi = #() --bone index array
					wv = #() --weight value array
					
					for j = 1 to w.boneids.count do
					(
						boneid = w.boneids[j]
						weight = w.weights[j]
						append bi boneIDMap[boneid]
						append wv weight
					)   
					skinOps.ReplaceVertexWeights skinMod i bi wv
				)

				if FSHPArr[m].matrFlag == 1 do(
					for b = 1 to BoneCount do(
						select BoneArray[b]
						$.transform = BoneFixArray[b]
					)
				)

			)
			)
		)

	)
	)
	
	if UVLayers == 2 do(
		if UV2_array.count > 0 do(
		meshop.setNumMaps msh 3 keep:true
		for i = 1 to UV2_array.count do (
				meshop.setMapVert msh 2 i UV2_array[i]
			)
		)
		if UV3_array.count > 0 do(
		meshop.setNumMaps msh 4 keep:true
		for i = 1 to UV3_array.count do (
				meshop.setMapVert msh 3 i UV3_array[i]
			)
		)
		if UV4_array.count > 0 do(
		meshop.setNumMaps msh 5 keep:true
		for i = 1 to UV4_array.count do (
				meshop.setMapVert msh 4 i UV4_array[i]
			)
		)
		if UV5_array.count > 0 do(
		meshop.setNumMaps msh 6 keep:true
		for i = 1 to UV5_array.count do (
				meshop.setMapVert msh 5 i UV5_array[i]
			)
		)
	)

	fseek f LODRet #seek_set

	)
	)

	clearSelection()

Print ("Done! ("+((((timestamp())-st)*0.001)as string)+" Seconds)")

)
)
)


CreateDialog BFRESImporter


-- Exit 3DSMax.
quitMax #noprompt