Namespace myapp

#Import "<std>"
#Import "<mojo>"
#Import "<mojo3d>"
#Import "<mojo3d-physics>"

#Import "assets/"

Using std..
Using mojo..
Using mojo3d..

Function Pow2Size:Int(n:Int)
	Local t:Int=1
	While t<n
		t*=2
	Wend
	Return t
End

Function GenRGB:UInt(r:Int,g:Int,b:Int,a:Int=255)
	Return (a Shl 24) | (r Shl 16) | (g Shl 8) | b
End

'http://www.gamers.org/dEngine/quake/spec/quake-spec34/qkspec_4.htm

Class Bsp Extends BspReader
	Const SCALE:Float=0.075
	
	Field data:DataBuffer
	Field dataOffset:UInt
	
	Field header:BspHeader
	Field mipTexHeader:BspMipHeader
	Field entities:=New List<BspEntity>
	Field planes:BspPlane[]
	Field vertices:BspVertex[]
	Field surfaces:BspSurface[]
	Field faces:BspFace[]
	Field edges:BspEdge[]
	Field ledges:BspLedge[]
	Field models:BspModel[]
	Field mipTexs:BspMipTex[]
	Field palette:=New BspPalette
	Field animSpeed:Float=5.6
	Field lastAnimFrame:Int
	Field animTimeOffset:Double
	Field lightMapPixmap:Pixmap
	Field lightmapTexture:Texture
	Field lightMapStart:Vec2i
	Field lightMapMaxH:Int
	
	Field modelMipTexs:Stack<BspMipTex>[]
	
	'Default texture flags for all textures
	Field textureFlags:=TextureFlags.WrapST|TextureFlags.Mipmap
	
	Function Load:Bsp(path:String)
		Local nB:=New Bsp
		nB.parentBsp=nB
		
		nB.data=DataBuffer.Load(path)
		If Not nB.data Then
			Print "Unable to load Bsp: ~q"+path+"~q"
			Return Null
		Endif
		
		nB.Process()
		
		Return nB
	End
	
	Method Process()
		Local num:Int
		Local i:Int
		
		'Get header and entry data
		Self.header=New BspHeader(Self)
		
		'Process entities
		Self.header.entities.JumpTo()
		Local entStr:String=ReadString(Self.header.entities.size) 'Get entire string
		Local entSplit:=entStr.Split("{") 'Split each entity
		For i=0 Until entSplit.Length 'Create a new entity from each split
			Self.entities.AddLast(New BspEntity(entSplit[i],Self))
		Next
		
		Print "Entities: "+Self.entities.Count()
		
		'Process planes
		num=Self.header.planes.Count(BspPlane.Size())
		Print "Planes: "+num
		Self.planes=New BspPlane[num]
		Self.header.planes.JumpTo()
		For i=0 Until num
			Self.planes[i]=New BspPlane(Self)
		Next
		
		'Process vertices
		num=Self.header.vertices.Count(BspVertex.Size())
		Print "Vertices: "+num
		Self.vertices=New BspVertex[num]
		Self.header.vertices.JumpTo()
		For i=0 Until num
			Self.vertices[i]=New BspVertex(Self)
		Next
		
		'Process surface info
		num=Self.header.texInfo.Count(BspSurface.Size())
		Print "Surfaces: "+num
		Self.surfaces=New BspSurface[num]
		Self.header.texInfo.JumpTo()
		For i=0 Until num
			Self.surfaces[i]=New BspSurface(Self)
		Next
		
		'Process faces
		num=Self.header.faces.Count(BspFace.Size())
		Print "Faces: "+num
		Self.faces=New BspFace[num]
		Self.header.faces.JumpTo()
		For i=0 Until num
			Self.faces[i]=New BspFace(Self)
		Next
		
		'Process edges
		num=Self.header.edges.Count(BspEdge.Size())
		Print "Edges: "+num
		Self.edges=New BspEdge[num]
		Self.header.edges.JumpTo()
		For i = 0 Until num
			Self.edges[i]=New BspEdge(Self)
		Next
		
		'Process ledges
		num=Self.header.ledges.Count(BspLedge.Size())
		Print "Ledges: "+num
		Self.ledges=New BspLedge[num]
		Self.header.ledges.JumpTo()
		For i=0 Until num
			Self.ledges[i]=New BspLedge(Self)
		Next
		
		'Process models
		num=Self.header.models.Count(BspModel.Size())
		Print "Models: "+num
		Self.models = New BspModel[num]
		Self.header.models.JumpTo()
		For i=0 Until num
			Self.models[i]=New BspModel(Self)
		Next
		
		Self.modelMipTexs=New Stack<BspMipTex>[num]
		For i=0 Until num
			Self.modelMipTexs[i]=New Stack<BspMipTex>
		Next
		
		'Read lightmaps
		For i=0 Until Self.faces.Length 'Store lightmap parts in big picture
			Self.faces[i].CalcLightmapSize()
			Self.faces[i].MakeLightmap()
		Next
		Self.lightmapTexture=New Texture(Self.lightMapPixmap,TextureFlags.FilterMipmap)
		
		'lightMapPixmap.Save("C:\Users\vital\Desktop\light.png")
		
		'Process mipmap headers
		Self.header.mipTex.JumpTo()
		Self.mipTexHeader=New BspMipHeader(Self)
		num=Self.mipTexHeader.Count
		Print "MipTexs: "+num
		
		'Process miptexs from mipmap header
		num=Self.mipTexHeader.Count
		Self.mipTexs=New BspMipTex[num]
		For i=0 Until num
			Self.mipTexs[i]=New BspMipTex(Self,i)
			Self.mipTexs[i].Generate()
		Next
		For i=0 Until num 'Find animations!
			If Not Self.mipTexs[i] Then Continue
			Self.mipTexs[i].FindAnimation()
		Next
		
		'Cleanup
		GCCollect()
		ResetAnimTime()
	End
	
	Method ResetAnimTime()
		animTimeOffset=Now()
	End
	
	Method Update()
		'Get animation time
		Local n:Int=Floor((Now()-animTimeOffset)*animSpeed)
		Local tmpM:QuakeMaterial
		
		'Time to update animations
		If lastAnimFrame<n Then 
			
			'Reset all updatedFrame flags
			For Local m:=Eachin Self.mipTexs
				m.updatedFrame=False
			Next
			
			'Do animations
			For Local i:Int=0 Until Self.modelMipTexs.Length
			For Local m:=Eachin Self.modelMipTexs[i]
				If m.updatedFrame Then Continue
				If Not m.material Or Not m.nextAnimation Then Continue
				
				If Not m.curAnimation Then m.curAnimation=m
				
				m.updatedFrame=True
				tmpM=Cast<QuakeMaterial>(m.material)
				If Not tmpM Then Continue
				
				For Local u:Int=0 Until n-lastAnimFrame
					m.curAnimation=m.curAnimation.nextAnimation
				Next
				
				tmpM.EmissiveTexture=m.curAnimation.texture
			Next
			Next
			
			lastAnimFrame=n
		Endif
	End
End

Class BspMipTex Extends BspReader
	Field name:String
	Field width:Int
	Field height:Int
	Field offset1:Int
	Field offset2:Int
	Field offset4:Int
	Field offset8:Int
	
	Field id:Int
	Field pix:Pixmap
	Field pixels:UByte[,]
	Field texture:Texture
	Field nextAnimation:BspMipTex
	Field curAnimation:BspMipTex
	Field ownFrame:Int
	Field material:Material
	Field updatedFrame:Bool
	
	Field masked:Bool
	
	Method FindAnimation()
		If Not name.StartsWith("+") Then
			nextAnimation=Null
			ownFrame=0
			Return
		Endif
		
		'Find our frame number
		ownFrame=Int(name.Mid(1,1))
		
		'Next expected frame name
		Local findName:String="+"+(ownFrame+1)+name.Slice(2)
		
		'Does a texture with this name exist?
		For Local m:=Eachin parentBsp.mipTexs
			If m.name=findName Then
				'It does!
				nextAnimation=m
				'Print name+" turns into "+nextAnimation.name
				Return 'We're done here
			End
		Next
		
		'No match was found, find lowest frame
		For Local i:Int=0 Until ownFrame
			findName="+"+i+name.Slice(2)
			
			For Local m:=Eachin parentBsp.mipTexs
				If m.name=findName Then
					nextAnimation=m
					'Print name+" loops back to "+nextAnimation.name
					Return
				End
			Next
			
		Next
		
		Print name+" is animation but has no frames"
		nextAnimation=Null
	End
	
	Method Generate()
		JumpTo()
		If width<=1 Or height<=1 Or width>1024*4 Or height>1024*4 Then
			Print "Invalid texture size: "+width+"x"+height
			Return
		Endif
		
		'Does this texture use a mask?
		If name.StartsWith("{") Then masked=True
		
		Local pal:=parentBsp.palette
		Local pixel:UByte
		pix=New Pixmap(width,height)
		pixels=New UByte[width,height]
		
		For Local y:Int=0 Until height
		For Local x:Int=0 Until width
			pixel=ReadUByte()
			pixels[x,y]=pixel
			
			If masked Then
				If pixel>=255 Then 
					pix.SetPixelARGB(x,y,0)
				Else
					pix.SetPixelARGB(x,y,pal.GetARGB(pixel))
				Endif
			Else
				pix.SetPixelARGB(x,y,pal.GetARGB(pixel))
			Endif
			
		Next
		Next
		
		'Just add a normal texture
		If Not texture Then texture=New Texture(pix,parentBsp.textureFlags)
		
		'Enable liquids
		If name.StartsWith("*") Then
			Local mat:=New PbrMaterial(Color.Black,1,1)
			mat.Shader=Shader.GetShader("q1_water")
			mat.EmissiveTexture=texture
			mat.EmissiveFactor=Color.White
			material=mat
		Endif
		
		'Sky
		If name.StartsWith("sky") Then
			Local mat:=New PbrMaterial(Color.Black,1,1)
			mat.Shader=Shader.GetShader("q1_sky")
			mat.EmissiveTexture=texture
			mat.EmissiveFactor=Color.White
			material=mat
		Endif
		
		'Just add a normal Quake material
		If Not material Then
			Local mat:=New QuakeMaterial(Color.Black,1,1)
			mat.EmissiveTexture=texture
			mat.EmissiveFactor=Color.White
			mat.LightmapTexture=parentBsp.lightmapTexture
			mat.UseMask=masked
			material=mat
		Endif
		
		'Debug save
		'pix.Save("C:\Users\vital\Desktop\output\"+name+".png")
	End
	
	Method New(parent:Bsp,id:Int)
		Self.parentBsp=parent
		Self.id=id
		
		JumpToHeader()
		
		name=ReadString(16).Split(String.FromChar(0))[0]
		width=ReadInt()
		height=ReadInt()
		offset1=ReadInt()
		offset2=ReadInt()
		offset4=ReadInt()
		offset8=ReadInt()
	End
	
	Method JumpTo()
		parentBsp.dataOffset=parentBsp.header.mipTex.position
		parentBsp.dataOffset+=parentBsp.mipTexHeader.offset[id]
		parentBsp.dataOffset+=parentBsp.mipTexs[id].offset1
	End
	
	Method JumpToHeader()
		parentBsp.dataOffset=parentBsp.header.mipTex.position
		parentBsp.dataOffset+=parentBsp.mipTexHeader.offset[id]
	End
	
	Function Size:Int()
		Return 16+(4*6)
	End
End

Class QuakeMaterial Extends Material
	Method New()
		Super.New(Shader.Open("q1_material" ) )
		
		ColorTexture=Texture.ColorTexture( Color.White )
		ColorFactor=Color.White
		
		EmissiveTexture=Texture.ColorTexture( Color.White )
		EmissiveFactor=Color.Black
	
		MetalnessTexture=Texture.ColorTexture( Color.White )
		MetalnessFactor=1.0
		
		RoughnessTexture=Texture.ColorTexture( Color.White )
		RoughnessFactor=1.0
		
		OcclusionTexture=Texture.ColorTexture( Color.White )
		
		LightmapTexture=Texture.ColorTexture( Color.White )
		
		UseMask=False
		
		NormalTexture=Texture.ColorTexture( New Color( 0.5,0.5,1.0,0.0 ) )
	End
	
	Method New(material:QuakeMaterial)
		Super.New(material)
	End
	
	Method New(color:Color,metalness:Float=0.0,roughness:Float=1.0)
		Self.New()
		
		ColorFactor=color
		MetalnessFactor=metalness
		RoughnessFactor=roughness
	End
	
	Method Copy:QuakeMaterial() Override
		Return New QuakeMaterial( Self )
	End
	
	Property UseMask:Float()
		Return Uniforms.GetFloat( "UseMask" )
	Setter( enabled:Float )
		Uniforms.SetFloat( "UseMask",enabled )
	End
	
	
	Property ColorTexture:Texture()
		Return Uniforms.GetTexture( "ColorTexture" )
	Setter( texture:Texture )
		Uniforms.SetTexture( "ColorTexture",texture )
	End
	
	Property ColorFactor:Color()
		Return Uniforms.GetColor( "ColorFactor" )
	Setter( color:Color )
		Uniforms.SetColor( "ColorFactor",color )
	End
	
	Property EmissiveTexture:Texture()
		Return Uniforms.GetTexture( "EmissiveTexture" )
	Setter( texture:Texture )
		Uniforms.SetTexture( "EmissiveTexture",texture )
	End
	
	Property EmissiveFactor:Color()
		Return Uniforms.GetColor( "EmissiveFactor" )
	Setter( color:Color )
		Uniforms.SetColor( "EmissiveFactor",color )
	End
	
	Property MetalnessTexture:Texture()
		Return Uniforms.GetTexture( "MetalnessTexture" )
	Setter( texture:Texture )
		Uniforms.SetTexture( "MetalnessTexture",texture )
	End

	Property MetalnessFactor:Float()
		Return Uniforms.GetFloat( "MetalnessFactor" )
	Setter( factor:Float )
		Uniforms.SetFloat( "MetalnessFactor",factor )
	End
	
	Property RoughnessTexture:Texture()
		Return Uniforms.GetTexture( "RoughnessTexture" )
	Setter( texture:Texture )
		Uniforms.SetTexture( "RoughnessTexture",texture )
	End
	
	Property RoughnessFactor:Float()
		Return Uniforms.GetFloat( "RoughnessFactor" )
	Setter( factor:Float )
		Uniforms.SetFloat( "RoughnessFactor",factor )
	End

	Property OcclusionTexture:Texture()
		Return Uniforms.GetTexture( "occlusion" )
	Setter( texture:Texture )
		Uniforms.SetTexture( "OcclusionTexture",texture )
	End
	
	Property LightmapTexture:Texture()
		Return Uniforms.GetTexture( "LightmapTexture" )
	Setter( texture:Texture )
		Uniforms.SetTexture( "LightmapTexture",texture )
	End
	
	Property NormalTexture:Texture()
		Return Uniforms.GetTexture( "NormalTexture" )
	Setter( texture:Texture )
		Uniforms.SetTexture( "NormalTexture",texture )
	End
End

Class BspMipHeader Extends BspReader
	Field numTex:Int
	Field offset:Int[]
	
	Field count:Int
	
	Property Count:Int()
		Return count
	End
	
	Method New(parent:Bsp)
		Self.parentBsp=parent
		
		numTex=ReadInt()
		offset=New Int[numTex]
		For Local i:Int=0 Until numTex
			offset[i]=ReadInt()
			count+=1
		Next
	End
End


Class BspSurface Extends BspReader
	Field vectorS:Vec3f
	Field distS:Float
	Field vectorT:Vec3f
	Field distT:Float
	Field textureID:Int
	Field animated:Int
	
	Method New(parent:Bsp)
		Self.parentBsp=parent
		
		vectorS=ReadVec3f()/parentBsp.SCALE
		distS=ReadFloat()
		vectorT=ReadVec3f()/parentBsp.SCALE
		distT=ReadFloat()
		textureID=ReadInt()
		animated=ReadInt()
	End
	
	Function Size:Int()
		Return (4*2)+(4*2)+((4*3)*2)
	End
End

Class BspBox Extends BspReader
	Field minimum:Vec3f
	Field maximum:Vec3f
	
	Method New(parent:Bsp)
		Self.parentBsp=parent
		
		minimum=ReadVec3f()
		maximum=ReadVec3f()
	End
	
	Function Size:Int()
		Return (4*3)*2
	End
End

Class BspModel Extends BspReader
	Field box:BspBox
	Field origin:Vec3f
	Field node0:Int
	Field node1:Int
	Field node2:Int
	Field node3:Int
	Field numLeafs:Int
	Field faceID:Int
	Field faceNum:Int
	
	Method New(parent:Bsp)
		Self.parentBsp=parent
		
		box=New BspBox(parent)
		origin=ReadVec3f()*parentBsp.SCALE
		node0=ReadInt()
		node1=ReadInt()
		node2=ReadInt()
		node3=ReadInt()
		numLeafs=ReadInt()
		faceID=ReadInt()
		faceNum=ReadInt()
	End
	
	Function Size:Int()
		Return (4*7)+BspBox.Size()+(4*3)
	End
End


Class BspLedge Extends BspReader
	Field edge:Int
	
	Method New(parent:Bsp)
		Self.parentBsp=parent
		
		edge=ReadInt()
	End
	
	Function Size:Int()
		Return 4
	End
End

Class BspEdge Extends BspReader
	Field vertex0:UShort
	Field vertex1:UShort
	
	Method New(parent:Bsp)
		Self.parentBsp=parent
		
		vertex0=ReadUShort()
		vertex1=ReadUShort()
	End
	
	Function Size:Int()
		Return 2*2
	End
End

Class BspVertex Extends BspReader
	Field x:Double
	Field y:Double
	Field z:Double
	
	Method New(parent:Bsp)
		Self.parentBsp=parent
		
		x=ReadFloat()*parentBsp.SCALE
		y=ReadFloat()*parentBsp.SCALE
		z=ReadFloat()*parentBsp.SCALE
	End
	
	Function Size:Int()
		Return 4*3
	End
	
	Method Dot:Double(v:Vec3f)
		Local vec:=New Vec3f(x,y,z)
		Return vec.Dot(v)
	End
End

Class BspPlane Extends BspReader
	Field normal:Vec3f
	Field dist:Float
	Field type:Int
	
	Method New(parent:Bsp)
		Self.parentBsp=parent
		Local tmpN:Vec3f=ReadVec3f()
		normal.x=tmpN.y
		normal.y=tmpN.z
		normal.z=tmpN.x
		dist=ReadFloat()
		type=ReadInt()
	End
	
	Function Size:Int()
		Return 4+4+(4*3)
	End
End

Class BspEntity
	Field data:=New Map<String,String>
	Field rawData:String
	Field className:String
	Field origin:Vec3<Int>
	Field angle:Double
	Field model:Int
	Field parentBsp:Bsp
	
	Property Angle:Double()
		Return angle
	End
	
	Property Radians:Double()
		Return angle*(Pi/180.0)
	End
	
	Method New(str:String,parent:Bsp)
		Self.parentBsp=parent
		
		'Construct from data string
		data.Clear()
		
		'Clean up!
		str=str.Replace("~r","").Replace("~n","").Trim()
		If str.EndsWith("}") Then str=str.Slice(0,-1)
		
		'Read data
		Local dataSplit:=str.Split("~q") 'Split from "
		Local dataStep:Byte
		Local lastKey:String
		Local lastValue:String
		Local vecSplit:String[]
		
		For Local i:Int=1 Until dataSplit.Length Step 2
			Select dataStep
				Case 0
					'Key
					lastKey=dataSplit[i].ToLower()
					
				Case 1
					'Value
					lastValue=dataSplit[i]
					
					'Process and quick access
					Select lastKey
						Case ""
							Print "Empty key"
							lastValue=Null
						Case "classname"
							Self.className=lastValue.ToLower()
						Case "origin"
							vecSplit=lastValue.Split(" ")
							origin.X=-Int(vecSplit[1])
							origin.Y=Int(vecSplit[2])
							origin.Z=Int(vecSplit[0])
							origin*=parentBsp.SCALE
						Case "angle"
							angle=Int(lastValue)
						Case "model"
							If lastValue.StartsWith("*") Then
								model=Int(lastValue.Slice(1))
							Else
								model=Int(lastValue)
							Endif
					End
					
					'Add to data map
					If lastValue Then
						data.Add(lastKey,lastValue)
					Else
						Print "Empty value: "+lastKey
					Endif
			End
			dataStep~=1
		Next
		
		'Store data
		rawData=str
	End
	
	Method GetVector:Int[](key:String)
		If data.Contains(key) Then
			Local split:=String(data.Get(key)).Split(" ")
			Local vec:=New Int[split.Length]
			
			For Local i:Int = 0 Until vec.Length
				vec[(vec.Length+i-1) Mod vec.Length]=Int(split[i])
			Next
			vec[0]=-vec[0]
			
			Return vec
		Endif
		
		Return Null
	End
	
End

'Generic class for reading stuff
Class BspReader
	Field parentBsp:Bsp
	
	Method ReadString:String(count:Int)
		If Not parentBsp Then RuntimeError("No parent");Return Null
		parentBsp.dataOffset+=count
		Return parentBsp.data.PeekString(parentBsp.dataOffset-count,count)
	End
	
	Method ReadShort:Short()
		If Not parentBsp Then RuntimeError("No parent");Return 0
		parentBsp.dataOffset+=2
		Return parentBsp.data.PeekShort(parentBsp.dataOffset-2)
	End
	
	Method ReadUShort:UShort()
		If Not parentBsp Then RuntimeError("No parent");Return 0
		parentBsp.dataOffset+=2
		Return parentBsp.data.PeekUShort(parentBsp.dataOffset-2)
	End
	
	Method ReadUByte:UByte()
		If Not parentBsp Then RuntimeError("No parent");Return 0
		parentBsp.dataOffset+=1
		Return parentBsp.data.PeekUByte(parentBsp.dataOffset-1)
	End
	
	Method ReadByte:Byte()
		If Not parentBsp Then RuntimeError("No parent");Return 0
		parentBsp.dataOffset+=1
		Return parentBsp.data.PeekByte(parentBsp.dataOffset-1)
	End
	
	Method ReadInt:Int()
		If Not parentBsp Then RuntimeError("No parent");Return 0
		parentBsp.dataOffset+=4
		Return parentBsp.data.PeekInt(parentBsp.dataOffset-4)
	End
	
	Method ReadUInt:UInt()
		If Not parentBsp Then RuntimeError("No parent");Return 0
		parentBsp.dataOffset+=4
		Return parentBsp.data.PeekUInt(parentBsp.dataOffset-4)
	End
	
	Method ReadFloat:Float()
		If Not parentBsp Then RuntimeError("No parent");Return 0
		parentBsp.dataOffset+=4
		Return parentBsp.data.PeekFloat(parentBsp.dataOffset-4)
	End
	
	Method ReadVec3f:Vec3f()
		Local nX:Float=ReadFloat()
		Local nY:Float=ReadFloat()
		Local nZ:Float=ReadFloat()
		Return New Vec3f(nX,nY,nZ)
	End
End

Class BspHeader Extends BspReader
	Field version:Int
	Field entities:BspEntry
	Field planes:BspEntry
	Field mipTex:BspEntry
	Field vertices:BspEntry
	Field visiList:BspEntry
	Field nodes:BspEntry
	Field texInfo:BspEntry
	Field faces:BspEntry
	Field lightMaps:BspEntry
	Field clipNodes:BspEntry
	Field leaves:BspEntry
	Field lfaces:BspEntry
	Field edges:BspEntry
	Field ledges:BspEntry
	Field models:BspEntry
	
	Method New(parent:Bsp)
		parentBsp=parent
		
		'Get version
		version=ReadInt()
		If version="29" Then
			Print "Bsp version: "+version+" (correct)"
		Else
			Print "Bsp version: "+version+" (incorrect)"
		Endif
		
		'Read a bunch of entry data
		entities=ReadEntry()
		planes=ReadEntry()
		mipTex=ReadEntry()
		vertices=ReadEntry()
		visiList=ReadEntry()
		nodes=ReadEntry()
		texInfo=ReadEntry()
		faces=ReadEntry()
		lightMaps=ReadEntry()
		clipNodes=ReadEntry()
		leaves=ReadEntry()
		lfaces=ReadEntry()
		edges=ReadEntry()
		ledges=ReadEntry()
		models=ReadEntry()
	End
	
	Method ReadEntry:BspEntry()
		Return New BspEntry(parentBsp)
	End
End

Class BspEntry Extends BspReader
	Field position:Int 'Position in data buffer
	Field size:Int 'Total size of entryMethod 
	
	Method New(parent:Bsp)
		parentBsp=parent
		position=ReadInt()
		size=ReadInt()
	End
	
	Method Count:Int(typeSize:Int)
		Return size/typeSize
	End
	
	Method JumpTo()
		parentBsp.dataOffset=position
	End
End

Class BspPalette
	Field palette:UInt[]
	
	Method GetARGB:UInt(index:Int)
		If Not palette Then palette=defPalette
		If index*3+2>palette.Length Then Return -1
		Return (255 Shl 24) | (palette[index*3] Shl 16) | (palette[index*3+1] Shl 8) | palette[index*3+2]
	End
	
	Global defPalette:=New UInt[](0,0,0,
		15,15,15,
		31,31,31,
		47,47,47,
		63,63,63,
		75,75,75,
		91,91,91,
		107,107,107,
		123,123,123,
		139,139,139,
		155,155,155,
		171,171,171,
		187,187,187,
		203,203,203,
		219,219,219,
		235,235,235,
		15,11,7,
		23,15,11,
		31,23,11,
		39,27,15,
		47,35,19,
		55,43,23,
		63,47,23,
		75,55,27,
		83,59,27,
		91,67,31,
		99,75,31,
		107,83,31,
		115,87,31,
		123,95,35,
		131,103,35,
		143,111,35,
		11,11,15,
		19,19,27,
		27,27,39,
		39,39,51,
		47,47,63,
		55,55,75,
		63,63,87,
		71,71,103,
		79,79,115,
		91,91,127,
		99,99,139,
		107,107,151,
		115,115,163,
		123,123,175,
		131,131,187,
		139,139,203,
		0,0,0,
		7,7,0,
		11,11,0,
		19,19,0,
		27,27,0,
		35,35,0,
		43,43,7,
		47,47,7,
		55,55,7,
		63,63,7,
		71,71,7,
		75,75,11,
		83,83,11,
		91,91,11,
		99,99,11,
		107,107,15,
		7,0,0,
		15,0,0,
		23,0,0,
		31,0,0,
		39,0,0,
		47,0,0,
		55,0,0,
		63,0,0,
		71,0,0,
		79,0,0,
		87,0,0,
		95,0,0,
		103,0,0,
		111,0,0,
		119,0,0,
		127,0,0,
		19,19,0,
		27,27,0,
		35,35,0,
		47,43,0,
		55,47,0,
		67,55,0,
		75,59,7,
		87,67,7,
		95,71,7,
		107,75,11,
		119,83,15,
		131,87,19,
		139,91,19,
		151,95,27,
		163,99,31,
		175,103,35,
		35,19,7,
		47,23,11,
		59,31,15,
		75,35,19,
		87,43,23,
		99,47,31,
		115,55,35,
		127,59,43,
		143,67,51,
		159,79,51,
		175,99,47,
		191,119,47,
		207,143,43,
		223,171,39,
		239,203,31,
		255,243,27,
		11,7,0,
		27,19,0,
		43,35,15,
		55,43,19,
		71,51,27,
		83,55,35,
		99,63,43,
		111,71,51,
		127,83,63,
		139,95,71,
		155,107,83,
		167,123,95,
		183,135,107,
		195,147,123,
		211,163,139,
		227,179,151,
		171,139,163,
		159,127,151,
		147,115,135,
		139,103,123,
		127,91,111,
		119,83,99,
		107,75,87,
		95,63,75,
		87,55,67,
		75,47,55,
		67,39,47,
		55,31,35,
		43,23,27,
		35,19,19,
		23,11,11,
		15,7,7,
		187,115,159,
		175,107,143,
		163,95,131,
		151,87,119,
		139,79,107,
		127,75,95,
		115,67,83,
		107,59,75,
		95,51,63,
		83,43,55,
		71,35,43,
		59,31,35,
		47,23,27,
		35,19,19,
		23,11,11,
		15,7,7,
		219,195,187,
		203,179,167,
		191,163,155,
		175,151,139,
		163,135,123,
		151,123,111,
		135,111,95,
		123,99,83,
		107,87,71,
		95,75,59,
		83,63,51,
		67,51,39,
		55,43,31,
		39,31,23,
		27,19,15,
		15,11,7,
		111,131,123,
		103,123,111,
		95,115,103,
		87,107,95,
		79,99,87,
		71,91,79,
		63,83,71,
		55,75,63,
		47,67,55,
		43,59,47,
		35,51,39,
		31,43,31,
		23,35,23,
		15,27,19,
		11,19,11,
		7,11,7,
		255,243,27,
		239,223,23,
		219,203,19,
		203,183,15,
		187,167,15,
		171,151,11,
		155,131,7,
		139,115,7,
		123,99,7,
		107,83,0,
		91,71,0,
		75,55,0,
		59,43,0,
		43,31,0,
		27,15,0,
		11,7,0,
		0,0,255,
		11,11,239,
		19,19,223,
		27,27,207,
		35,35,191,
		43,43,175,
		47,47,159,
		47,47,143,
		47,47,127,
		47,47,111,
		47,47,95,
		43,43,79,
		35,35,63,
		27,27,47,
		19,19,31,
		11,11,15,
		43,0,0,
		59,0,0,
		75,7,0,
		95,7,0,
		111,15,0,
		127,23,7,
		147,31,7,
		163,39,11,
		183,51,15,
		195,75,27,
		207,99,43,
		219,127,59,
		227,151,79,
		231,171,95,
		239,191,119,
		247,211,139,
		167,123,59,
		183,155,55,
		199,195,55,
		231,227,87,
		127,191,255,
		171,231,255,
		215,255,255,
		103,0,0,
		139,0,0,
		179,0,0,
		215,0,0,
		255,0,0,
		255,243,147,
		255,247,199,
		255,255,255,
		159, 91, 83)
End

Class BspFace Extends BspReader
	Const LIGHT_PAD:Int=1
	
	Field planeID:UShort
	
	Field side:UShort
	Field ledgeID:Int
	
	Field ledgeNum:Short
	Field texInfoID:Short
	
	Field typeLight:Byte
	Field baseLight:Byte
	Field light:=New Byte[2]
	Field lightMap:Int
	
	'Lightmap stuff
	Field doneLightmap:Bool
	Field lightDist:Vec2f
	Field lightMinUV:Vec2f
	Field lightMaxUV:Vec2f
	Field lightS:Float
	Field lightT:Float
	Field lightMapSize:Vec2i
	Field lightMapPos:Vec2f
	
	Method MakeLightmap()
		If Self.lightMap<0 Then Return
		If lightMapSize.x<=0 Or lightMapSize.y<=0 Then Return
		
		parentBsp.header.lightMaps.JumpTo()
		
		'Start of a new lightmap
		If Not parentBsp.lightMapPixmap Then
			Local pixSize:Int=Pow2Size(Sqrt(parentBsp.header.lightMaps.size)*2)
			parentBsp.lightMapPixmap=New Pixmap(pixSize,pixSize)
			
			'Next part start
			parentBsp.lightMapStart=New Vec2i(LIGHT_PAD,LIGHT_PAD)
		Endif
		
		'Will this part will be outside of the pixmap?
		If parentBsp.lightMapStart.x+lightMapSize.x>=parentBsp.lightMapPixmap.Width Then
			'Place it a row below
			parentBsp.lightMapStart.x=LIGHT_PAD
			parentBsp.lightMapStart.y+=parentBsp.lightMapMaxH
			parentBsp.lightMapMaxH=0
		Endif
		
		'Set this lightmap parts start
		Self.lightMapPos.x=parentBsp.lightMapStart.x
		Self.lightMapPos.y=parentBsp.lightMapStart.y
		
		Local x:Int
		Local y:Int
		Local cI:Int
		Local color:UByte
		Local pix:=parentBsp.lightMapPixmap
		Local start:=parentBsp.lightMapStart
		Local argb:UInt
		
		For y=start.y To start.y+lightMapSize.y
		For x=start.x To start.x+lightMapSize.x
			color=parentBsp.data.PeekByte(parentBsp.dataOffset+lightMap+cI)
			argb=GenRGB(color, color, color)
			
			'Are we out of space?!
			If y>=parentBsp.lightMapPixmap.Height Then Return
				
			pix.SetPixelARGB(x,y,argb)
			
			'Padding
			If LIGHT_PAD Then
				If x=start.x Then pix.SetPixelARGB(x-1,y,argb)
				If x=start.x+lightMapSize.x-1 Then pix.SetPixelARGB(x+1,y,argb)
				
				If y=start.y Then pix.SetPixelARGB(x,y-1,argb)
				If y=start.y+lightMapSize.y-1 Then pix.SetPixelARGB(x,y+1,argb)
				
				If x=start.x And y=start.y Then pix.SetPixelARGB(x-1,y-1,argb)
				If x=start.x+lightMapSize.x-1 And y=start.y Then pix.SetPixelARGB(x+1,y-1,argb)
				If x=start.x+lightMapSize.x-1 And y=start.y+lightMapSize.y-1 Then pix.SetPixelARGB(x+1,y+1,argb)
				If x=start.x And y=start.y+lightMapSize.y-1 Then pix.SetPixelARGB(x-1,y+1,argb)
			Endif
			
			cI+=1
		Next
		Next
		
		'Set next start position
		parentBsp.lightMapStart.x+=lightMapSize.x+LIGHT_PAD*2
		
		'Was this part tallest?
		If parentBsp.lightMapMaxH<Self.lightMapSize.y+LIGHT_PAD Then
			parentBsp.lightMapMaxH=Self.lightMapSize.y+LIGHT_PAD
		Endif
	End
	
	Method CalcLightmapSize:Vec2i()
		If Self.lightMap<0 Then Return New Vec2i
		
		If doneLightmap Then
			'Return same if already calculated
			Return lightMapSize
		Else
			'Being a new calculation!
			lightMapSize=New Vec2i
			doneLightmap=True
		Endif
		
		'Get the vertex data from all edges
		Local ledge:BspLedge
		Local edge:BspEdge
		Local vert:BspVertex
		Local surface:BspSurface=parentBsp.surfaces[Abs(Self.texInfoID)]
		
		For Local eNr:Int=Self.ledgeID Until Self.ledgeID+Self.ledgeNum 'Go through edges
			ledge=parentBsp.ledges[Abs(eNr)] 'Get ledge
			edge=parentBsp.edges[Abs(ledge.edge)] 'Get edge via ledge
			
			If ledge.edge<0 Then
				If edge.vertex0>=parentBsp.vertices.Length Then Return New Vec2i
				vert=parentBsp.vertices[edge.vertex0]
			Else
				If edge.vertex1>=parentBsp.vertices.Length Then Return New Vec2i
				vert=parentBsp.vertices[edge.vertex1]
			Endif
			
			lightS=vert.Dot(surface.vectorS)+surface.distS
			lightT=vert.Dot(surface.vectorT)+surface.distT
			
			If (eNr=Self.ledgeID) Then
				'Starting point
				lightMinUV.x=lightS
				lightMinUV.y=lightT
				lightMaxUV.x=lightS
				lightMaxUV.y=lightT
			Else
				'Is this a new minimum?
				If lightS<lightMinUV.x Then lightMinUV.x=lightS
				If lightT<lightMinUV.y Then lightMinUV.y=lightT
				
				'Is this a new maximum
				If lightS>lightMaxUV.x Then lightMaxUV.x=lightS
				If lightT>lightMaxUV.y Then lightMaxUV.y=lightT
			End If
		Next
		
		'Get distances
		lightDist.x=Ceil(lightMaxUV.x)-Floor(lightMinUV.x)
		lightDist.y=Ceil(lightMaxUV.y)-Floor(lightMinUV.y)
		
		'Lightmap part size
		lightMapSize.x=lightDist.x/16
		lightMapSize.y=lightDist.y/16
		
		Return lightMapSize
	End
	
	Method New(parent:Bsp)
		Self.parentBsp=parent
		
		planeID=ReadUShort()
		side=ReadUShort()
		ledgeID=ReadInt()
		ledgeNum=ReadShort()
		texInfoID=ReadShort()
		typeLight=ReadByte()
		baseLight=ReadByte()
		light[0]=ReadByte()
		light[1]=ReadByte()
		lightMap=ReadInt()
	End
	
	Function Size:Int()
		Return (2*4)+(4*2)+4
	End
End

'Extend Mesh to support Bsp
Class Mesh Extension
	Function CreateFromBsp:Mesh(bsp:Bsp,id:Int=0)
		'Get the bsp model specified
		Local model:BspModel=bsp.models[id]
		Local mesh:Mesh=New Mesh
		
		If model Then
			'Print "Generating model: "+id
		Else
			Print "No model to generate at id: "+id
			Return Null
		Endif
		
		Local face:BspFace
		Local faceNr:Int
		Local edge:BspEdge
		Local edgeNr:Int
		Local ledge:BspLedge
		Local plane:BspPlane
		Local surface:BspSurface
		Local vert:BspVertex
		Local vertCount:Int
		Local vertCountNew:Int
		
		Local s:Double
		Local t:Double
		Local lightU:Double
		Local lightV:Double
		
		Local triV:Int
		
		Local i:Int
		Local mipUsed:Bool
		
		bsp.modelMipTexs[id].Clear()
		
		'Go through faces
		For faceNr=model.faceID Until model.faceID+model.faceNum
			'Print "Face: "+faceNr
			face=bsp.faces[faceNr]
			plane=bsp.planes[face.planeID]
			surface=bsp.surfaces[face.texInfoID]
			
			'Reset new vertex counter
			vertCountNew=0
			
			'Go through edges
			For edgeNr=face.ledgeID Until face.ledgeID+face.ledgeNum
				'Print "Edge: "+edgeNr
				ledge=bsp.ledges[edgeNr] 'Get ledge
				edge=bsp.edges[Abs(ledge.edge)] 'Get edge via ledge
				
				'Select vertex
				If ledge.edge<0 Then
					vert=bsp.vertices[edge.vertex0]
				Else
					vert=bsp.vertices[edge.vertex1]
				Endif
				
				'Make vertex
				Local v:=New Vertex3f(-vert.y, vert.z, vert.x, s, t)
				
				'Prepare UV
				s=vert.Dot(surface.vectorS)+surface.distS
				t=vert.Dot(surface.vectorT)+surface.distT
				
				'Lightmap UV
				If face.lightMap>=0 Then
					lightU=(s-face.lightMinUV.x)/face.lightDist.x
					lightV=(t-face.lightMinUV.y)/face.lightDist.y
					
					lightU=(face.lightMapPos.x + lightU * face.lightMapSize.x)/Double(bsp.lightMapPixmap.Width)
					lightV=(face.lightMapPos.y + lightV * face.lightMapSize.y)/Double(bsp.lightMapPixmap.Height)
					
					v.texCoord1.x=lightU
					v.texCoord1.y=lightV
				EndIf
				
				'Texture UV
				s/=bsp.mipTexs[surface.textureID].width
				t/=bsp.mipTexs[surface.textureID].height
				v.texCoord0.x=s
				v.texCoord0.y=t
				
				'Normals
				v.normal=plane.normal
				
				'Add vertex to mesh
				mesh.AddVertex(v)
				
				'Count!
				vertCount+=1
				vertCountNew+=1
			Next
			
			'Is this a new texture?
			mipUsed=False
			For i=0 Until bsp.modelMipTexs[id].Length
				If bsp.modelMipTexs[id][i].id=surface.textureID Then
					mipUsed=True
					Exit
				Endif
			Next
			
			'Yep! New texture
			If Not mipUsed Then
				'Prepare mesh that we're using another material
				If i>=mesh.NumMaterials Then mesh.AddMaterials(1)
				'Add the new texture
				bsp.modelMipTexs[id].Push(bsp.mipTexs[surface.textureID])
				i=bsp.modelMipTexs[id].Length-1
			Endif
			
			'Make Tris
			For triV=vertCount-vertCountNew Until vertCount-2
				mesh.AddTriangle(vertCount-vertCountNew,triV+1,triV+2,i)
			Next
			
		Next
		
		Return mesh
	End
End

'Extend Model to support Bsp
Class Model Extension
	Function CreateFromBsp:Model(bsp:Bsp,id:Int=0,parent:Entity=Null)
		Local mesh:=mojo3d.graphics.Mesh.CreateFromBsp(bsp,id)
		Local model:=New Model(mesh,New PbrMaterial,parent)
		
		'Apply materials
		model.Materials=New Material[bsp.modelMipTexs[id].Length]
		For Local i:Int=0 Until model.Materials.Length
			model.Materials[i]=bsp.modelMipTexs[id][i].material
		Next
		
		Return model
	End
End

'=EXAMPLE=
Class MyWindow Extends Window
	Field scene:Scene
	Field camera:Camera
	Field light:Light
	Field bsp:Bsp
	Field map:Model[]
	Field fog:FogEffect
	Field testBall:Model
	Field testBallCol:Collider
	Field testBallBody:RigidBody
	Field testBox:Model
	Field showInfo:Int=True
	
	Method New(title:String="Bsp Loader",width:Int=1280/1.5,height:Int=720/1.5,flags:WindowFlags=WindowFlags.Resizable)
		Super.New(title,width,height,flags)
		
		scene=Scene.GetCurrent()
		scene.ClearColor=Color.Black
		scene.AmbientLight=Color.Black
		
		'Set env texture to black
		Local pixmap:=New Pixmap(4,3)
		pixmap.Clear(Color.Black)
		Scene.GetCurrent().EnvTexture=New Texture(pixmap,TextureFlags.Cubemap)
		
		'create camera
		camera=New Camera
		camera.Near=0.1
		camera.Far=2500
		
		'fog effect
		fog=New FogEffect
		fog.Color=scene.ClearColor
		fog.Near=camera.Far-500
		fog.Far=camera.Far
		
		'create light
		light=New Light
		light.RotateX( Pi/2 )	'aim directional light 'down' - Pi/2=90 degrees.
		
		'Load our BSP
		Self.OpenBsp("asset::start.bsp")
		
		'Test box
		'Local mat:=New PbrMaterial(Color.Black,0,1)
		'mat.EmissiveFactor=Color.White
		'mat.EmissiveTexture=Texture.Load("asset::textures/test.png",bsp.textureFlags)
		'testBox=Model.CreateBox(New Boxf(0,0,5,5,-5,-5),1,1,1,mat)
		
		'Test physics
		'Local collider:=New MeshCollider(map[0].Mesh)
		'Local body:=New RigidBody(0,collider,map[0])
		
		'testBall=Model.CreateSphere(20,24,12,New PbrMaterial(Color.Yellow))
		'testBall.Move(-500,200,500)
		'testBallCol=New SphereCollider(20)
		'testBallBody=New RigidBody(1,testBallCol,testBall)
		
		'For Local m:=Eachin bsp.mipTexs
		'	Cast<PbrMaterial>(m.material).EmissiveTexture=Texture.Load("C:\Users\vital\Desktop\light.png",bsp.textureFlags)
			'Cast<PbrMaterial>(m.material).ColorFactor=Color.White
		'Next
		
		'DEBUG DISABLE TEXTUYRES
		Local tmpM:QuakeMaterial
		
		For Local m:=Eachin bsp.mipTexs
			If Not m.material Then Continue
			tmpM=Cast<QuakeMaterial>(m.material)
			If Not tmpM Then Continue
			tmpM.EmissiveTexture=Texture.ColorTexture(Color.White)
		Next
	End
	
	Method OpenBsp(path:String)
		bsp=Bsp.Load(path)
		
		'Remove all old models
		If map Then
			For Local m:Model=Eachin map
				If m Then m.Destroy()
			Next
		Endif
		
		If bsp Then
			'Prepare model array
			map=New Model[bsp.models.Length]
			
			camera.SetPosition(New Vec3f(0,0,0))
			camera.SetRotation(New Vec3f(0,0,0))
			
			'Load world model
			map[0]=Model.CreateFromBsp(bsp,0)
			
			'Do entity stuff
			For Local e:BspEntity=Eachin bsp.entities
				'Set start position
				If e.className="info_player_start" Then
					camera.SetPosition(e.origin)
					camera.MoveY(2)
					camera.SetRotation(0,e.Radians,0)
				Endif
				
				'Make entity models
				If e.model And Not e.className.StartsWith("trigger_") Then
					map[e.model]=Model.CreateFromBsp(bsp,e.model)
				Endif
				
			Next
			
		Endif
	End
	
	Method OnRender(canvas:Canvas) Override
		If Keyboard.KeyHit(Key.F8) Then
			Local file:=RequestFile("Select Bsp","Bsp files:bsp;All files:*",False)
			If file Then OpenBsp(file)
		Endif
		
		RequestRender()
		Fly(camera,Self)
		
		'light.Position=camera.Position
		scene.Render(canvas,camera)
		bsp.Update()
		'World.GetDefault().Update()
		'map.Rotate(.001,.002,.003)
		If showInfo Then 
			canvas.DrawText("FPS: "+App.FPS,0,0)
			canvas.DrawText("F8 Load Bsp",0,canvas.Font.Height)
			canvas.DrawText("F5 Reload Shaders",0,canvas.Font.Height*2)
			canvas.DrawText("F2 Disable Textures",0,canvas.Font.Height*3)
			canvas.DrawText("F3 Enable Textures",0,canvas.Font.Height*4)
		Endif
		
		If Keyboard.KeyHit(Key.F1) Then showInfo~=1
		
		If Keyboard.KeyHit(Key.F2) Then
			Local tmpM:QuakeMaterial
			
			For Local m:=Eachin bsp.mipTexs
				If Not m.material Then Continue
				tmpM=Cast<QuakeMaterial>(m.material)
				If Not tmpM Then Continue
				tmpM.EmissiveTexture=Texture.ColorTexture(Color.White)
			Next
		Endif
		
		If Keyboard.KeyHit(Key.F3) Then
			Local tmpM:QuakeMaterial
			
			For Local m:=Eachin bsp.mipTexs
				If Not m.material Then Continue
				tmpM=Cast<QuakeMaterial>(m.material)
				If Not tmpM Then Continue
				tmpM.EmissiveTexture=m.texture
			Next
		Endif
		
		If Keyboard.KeyHit(Key.F5) Then
			canvas.Color=Color.Black
			canvas.DrawRect(canvas.Viewport)
			Local lastShader:Shader
			
			For Local m:=Eachin bsp.mipTexs
				If Not m.material Then Continue
				
				If lastShader And m.material.Shader.Name=lastShader.Name Then
					m.material.Shader=lastShader
				Else
					m.material.Shader=New Shader(m.material.Shader.Name,LoadString("asset::shaders/"+m.material.Shader.Name+".glsl"))
					lastShader=m.material.Shader
				Endif
			Next
			
			bsp.ResetAnimTime()
			GCCollect()
			Keyboard.FlushChars()
			
			canvas.Color=Color.Red
			canvas.DrawText("Reloading shaders...",0,0)
			canvas.Color=Color.White
		Endif
	End
	
End

Function Main()
	New AppInstance
	New MyWindow
	App.Run()
End

Function Fly(entity:Entity,view:View,speed:Float=0.25)
	If Keyboard.KeyDown(Key.LeftShift) Or Keyboard.KeyDown(Key.RightShift) Then speed*=0.5
	
	If Keyboard.KeyDown(Key.Left)
		entity.RotateY(.05,True)
	ElseIf Keyboard.KeyDown(Key.Right)
		entity.RotateY(-.05,True)
	Endif
	
	If Keyboard.KeyDown(Key.Up)
		entity.RotateX(-.05)
	ElseIf Keyboard.KeyDown(Key.Down)
		entity.RotateX(.05)
	Endif
	
	If Keyboard.KeyDown(Key.W)
		entity.MoveZ(speed)
	ElseIf Keyboard.KeyDown(Key.S)
		entity.MoveZ(-speed)
	Endif
	
	If Keyboard.KeyDown(Key.D)
		entity.MoveX(speed)
	ElseIf Keyboard.KeyDown(Key.A)
		entity.MoveX(-speed)
	Endif
	
	If Keyboard.KeyDown(Key.Space)
		entity.MoveY(speed)
	ElseIf Keyboard.KeyDown(Key.LeftControl) Or Keyboard.KeyDown(Key.C)
		entity.MoveY(-speed)
	Endif
	
End
