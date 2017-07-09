#Import "<std>"
#Import "<mojo>"

Using std..
Using mojo..

'=LOADER
Const TYPE_PALETTE:String=String.FromChar(64)
Const TYPE_QTEX:String=String.FromChar(65)
Const TYPE_QPIC:String=String.FromChar(66)
Const TYPE_SOUND:String=String.FromChar(67)
Const TYPE_MIPTEX:String=String.FromChar(68)

Global WadError:Void(message:String)
Global WadWarning:Void(message:String)

Class Wad
	Field data:DataBuffer	'Entire Wad file
	Field dataOffset:Int	'For easy reading
	
	Field name:String
	Field filePath:String
	
	Field palette:WadPalette
	
	Field magic:String="WAD2"
	Field numEntries:Int	'Number of entries
	Field dirOffset:Int		'Position of WAD directory in file
	
	'Store all Wad entries here
	Field entries:WadEntry[]
	
	'Store all image based classes here
	Field images:WadImage[]
	
	Method New()
		'Add a basic palette
		palette=New WadPalette
	End
	
	'Quick way to load Wad at creation
	Method New(path:String)
		Load(path)
	End
	
	'Manually load Wad
	Method Load(path:String)
		path=path.Replace("\","/") 'Cleanup
		
		'Read data from file
		data=DataBuffer.Load(path)
		If Not data Then
			WadError("Unable to load Wad: "+path)
			Return 
		Endif
		
		'Reset offset
		dataOffset=0
		
		'Is magic correct?
		If ReadString(magic.Length)=magic Then
			'Print "Loading Wad: "+StripDir(path)
		Else
			WadError(StripDir(path)+" is not a Wad file!")
			Return
		Endif
		
		Local i:Int 'We'll need this later
		
		'Get info
		numEntries=ReadInt()
		dirOffset=ReadInt()
		
		'Get all the Wad entries
		entries=New WadEntry[numEntries]
		dataOffset=dirOffset 'Make sure we're at the correct offset!
		For i=0 Until entries.Length
			'Create a new entry and set this Wad as parent
			entries[i]=New WadEntry(Self)
		Next
		
		'Make sure we have a palette ready
		palette=New WadPalette
		
		'Process the data for all Wad entries
		images=New WadImage[numEntries]
		'Data offset is applied later
		For i=0 Until entries.Length
			entries[i].Process(i)
		Next
		
		'Try to link animated texture together
		For Local wI:WadImage=Eachin images
			wI.FindNextFrame()
		Next
		
		'Generate images if needed
		For Local wI:WadImage=Eachin images
			wI.GenerateImage()
		Next
		
		Self.name=StripDir(StripExt(path))
		Self.filePath=path
	End
	
	'Save Wad
	Method Save(path:String)
		If Not path Then Return
		CreateFile(path,True)
		Local file:Stream=Stream.Open(path,"rw")
		If Not file Then
			WadError("Unable to save Wad: "+path)
			Return
		Else
			'Print "Saving Wad: "+path
		Endif
		
		Local i:Int
		Local dirOffsetWritePos:UInt
		Local dirOffsetWadPos:UInt
		
		'Write header stuff
		numEntries=images.Length
		file.WriteString(magic) 'magic
		file.WriteInt(numEntries) 'number of textures
		dirOffsetWritePos=file.Position
		file.WriteInt(0) 'Write 0 for now, later fill in with dirOffset 
		
		'Write all the textures and prepare their entires
		entries=New WadEntry[numEntries]
		For i=0 Until numEntries
			entries[i]=New WadEntry
			entries[i].parent=Self
			images[i].parent=entries[i]
			
			images[i].Write(file)
		Next
		
		'Now we write dirOffset
		Local oldPos:UInt=file.Position
		dirOffsetWadPos=file.Position
		file.Seek(dirOffsetWritePos)
		file.WriteInt(dirOffsetWadPos)
		file.Seek(oldPos)
		
		'Write entry dir
		For i=0 Until entries.Length
			entries[i].Write(file)
		Next
		
		'Finshed!
		file.Close()
	End
	
	'Fetching a texture
	Method GetImage:WadImage(index:Int)
		Return images[index]
	End
	
	Method GetImage:WadImage(name:String)
		name=name.ToLower()
		
		For Local t:WadImage=Eachin images
			If t.name.ToLower()=name Then Return t
		Next
		
		Return Null
	End
	
	Method GetFirstImage:WadImage()
		Return images[0]
	End
	
	Method GetLastImage:WadImage()
		Return images[images.Length-1]
	End
	
	Method CountImages:Int()
		If Not images Then Return 0
		Local count:Int
		For Local i:Int=0 Until images.Length
			If images[i] Then count+=1
		Next
		Return count
	End
	
	'Adding own textures
	Method AddTexture:WadImage(path:String)
		'Does a similar name exist?
		Local newTexName:String=StripDir(StripExt(path)).Left(16).ToLower()
		
		If images And images.Length>0 Then
			For Local t:WadImage=Eachin images
				If Not t Then Continue
				If t.name.ToLower()=newTexName Then
					WadError("A texture with the name ~q"+newTexName+"~q already exists")
					Return Null
				Endif
			Next
		Endif
		
		'Make space for our new texture
		images=images.Resize(images.Length+1)
		images[images.Length-1]=New WadTexture
		Local nT:=images[images.Length-1]
		Local pix:Pixmap=Pixmap.Load(path)
		If Not pix Then
			WadError("Unable to load texture: "+path)
			Return Null
		Endif
		
		nT.parent=New WadEntry
		nT.parent.parent=Self
		nT.name=newTexName
		nT.width=ValidImageSize(pix.Width)
		nT.height=ValidImageSize(pix.Height)
		nT.pixels=New UInt[nT.width,nT.height,nT.mipOffset.Length]
		
		'Was size changed?
		If nT.width<>pix.Width Or nT.height<>pix.Height Then
			WadWarning("~q"+nT.name+"~q "+pix.Width+"x"+pix.Height+" was cropped to "+nT.width+"x"+nT.height)
		Endif
		
		Local rX:Float
		Local rY:Float
		
		For Local mip:Int=0 Until nT.mipOffset.Length
		For Local x:Int=0 Until nT.GetMipSize(nT.width,mip)
		For Local y:Int=0 Until nT.GetMipSize(nT.height,mip)
			
			rX=Float(x)/Float(nT.GetMipSize(nT.width,mip))
			rY=Float(y)/Float(nT.GetMipSize(nT.height,mip))
			
			If mip=0 Then
				rX*=pix.Width
				rY*=pix.Height
				nT.pixels[x,y,0]=palette.GetSimilar(pix.GetPixelARGB(rX,rY))
			Else
				rX*=nT.width
				rY*=nT.height
				nT.pixels[x,y,mip]=nT.pixels[rX,rY,0]
			Endif
		Next
		Next
		Next
		
		nT.GenerateImage()
		Return nT
	End
	
	Method ValidImageSize:Int(size:Int)
		Local v:Int
		For Local i:Int=1 To 8
			If i=1 Then v=1
			v*=2
			
			'Return same size
			If v=size Then Return size
			
			'Return next best size
			If v>size Then Return v/2
		Next
		
		Return v
	End
	
	'For easy data reading
	Method ReadString:String(len:Int)
		dataOffset+=len
		Return data.PeekString(dataOffset-len,len)
	End
	
	Method ReadByte:Byte()
		dataOffset+=1
		Return data.PeekByte(dataOffset-1)
	End
	
	Method ReadUByte:UByte()
		dataOffset+=1
		Return data.PeekUByte(dataOffset-1)
	End
	
	Method ReadShort:Short()
		dataOffset+=2
		Return data.PeekShort(dataOffset-2)
	End
	
	Method ReadInt:Int()
		dataOffset+=4
		Return data.PeekInt(dataOffset-4)
	End
	
	Method ReadUInt:UInt()
		dataOffset+=4
		Return data.PeekUInt(dataOffset-4)
	End
	
	Method ReadLong:Long()
		dataOffset+=8
		Return data.PeekLong(dataOffset-8)
	End
End

Class WadEntry
	Field parent:Wad			'Parent Wad file
	Field offset:Int			'Position of the entry in WAD
	Field dsize:Int				'Size of the entry in WAD file
	Field size:Int				'Size of the entry in memory
	Field type:String			'Type of entry
	Field compression:String	'Compression. 0 if none.
	Field padding:Short		'Padding!
	Field name:String			'1 to 16 characters, '\0'-padded (null terminated)
	
	Method Write(file:Stream)
		'Print "Writing entry: "+name
		file.WriteInt(offset)
		file.WriteInt(dsize)
		file.WriteInt(size)
		file.WriteByte(68) 'Type
		file.WriteByte(0) 'Compression
		file.WriteShort(666) 'Padding
		
		file.WriteString(PadName(name))
	End
	
	Method New()
	End
	
	Method New(owner:Wad)
		parent=owner
		'Read entry data
		offset=parent.ReadInt()
		dsize=parent.ReadInt()
		size=parent.ReadInt()
		type=parent.ReadString(1)
		compression=parent.ReadString(1)
		padding=parent.ReadShort()
		name=parent.ReadString(16).Split(String.FromChar(0))[0]
		
		If compression<>String.FromChar(0) Then
			WadWarning("Compression: "+compression+" for entry: "+name+" is not supported")
		Else
			compression=Null
		Endif
	End
	
	Method Process(index:Int)
		'Print "Reading Wad entry: "+name
		
		Select type
			Case TYPE_MIPTEX
				parent.images[index]=New WadTexture(Self)
				
			Case TYPE_QPIC
				parent.images[index]=New WadPicture(Self)
				
			Case TYPE_PALETTE
				parent.images[index]=New WadPaletteImage(Self)
				
			Default
				WadWarning(name+" is unknown type: "+type)
		End
	End
	
	Function PadName:String(name:String)
		While name.Length<16
			name+=String.FromChar(0)
		Wend
		Return name.Left(16)
	End
End

Class WadImage
	Field parent:WadEntry
	Field width:Int
	Field height:Int
	Field pixels:UInt[,,]
	Field mipOffset:=New UInt[4]
	Field pixmap:Pixmap[]
	Field image:Image[]
	Field name:String
	Field type:String
	Field nextImage:WadImage
	
	Method Write(file:Stream) Abstract
	Method GenerateImage() Abstract
	
	Method FrameNumber:Int()
		If Not name.StartsWith("+") Then Return Null
		
		If IsDigit(name[1]) Then
			Return Int(name.Mid(1,1))
		Else
			Select name.Mid(1,1).ToLower()
				Case "a" Return 0
				Case "b" Return 1
				Case "c" Return 2
				Case "d" Return 3
				Case "e" Return 4
				Case "f" Return 5
				Case "g" Return 6
				Case "h" Return 7
				Case "i" Return 8
				Case "j" Return 9
				'Only 10 frames are supported by Quake!
				'Case "k" Return 10
				'Case "l" Return 11
				'Case "m" Return 12
				'Case "n" Return 13
			End
		Endif
		
		Return Null
	End
	
	Method AnimationMode:Int()
		If IsDigit(name[1]) Then Return 0
		Return 1
	End
	
	Method AnimationName:String()
		If Not name.StartsWith("+") Then Return Null
		Return name.Right(name.Length-2)
	End
	
	Method FindNextFrame()
		'Is this even part of an animation?
		If Not name.StartsWith("+") Then
			nextImage=Null
			Return
		Endif
		
		Local found:WadImage
		'Find NEXT frame
		For Local wI:WadImage=Eachin parent.parent.images
			If Not wI.name.StartsWith("+") Then Continue
			If wI.AnimationName()<>Self.AnimationName() Then Continue
			If wI.AnimationMode()<>Self.AnimationMode() Then Continue
			If wI.FrameNumber()<=Self.FrameNumber() Then Continue
			If found And wI.FrameNumber()>found.FrameNumber() Then Continue
			found=wI
		Next
		
		'Did we find a frame?
		If found Then
			nextImage=found
		Else
			'Nope! Look for animation start
			For Local wI:WadImage=Eachin parent.parent.images
				If Not wI.name.StartsWith("+") Then Continue
				If wI.AnimationName()<>Self.AnimationName() Then Continue
				If wI.AnimationMode()<>Self.AnimationMode() Then Continue
				If wI.FrameNumber()>=Self.FrameNumber() Then Continue
				If found And wI.FrameNumber()>found.FrameNumber() Then Continue
				found=wI
			Next
			nextImage=found
		Endif
	End
	
	Method Export:Bool(path:String,mipmap:Int=0)
		If Not path Then Return False
		If Not pixmap Or mipmap>=pixmap.Length Or Not pixmap[mipmap] Then
			WadWarning("Nothing to export")
			Return False
		Endif
		
		Return pixmap[mipmap].Save(path)
	End
	
	Method MojoImage:Image(mipmap:Int=0)
		If mipmap>=pixmap.Length Or Not pixmap[mipmap] Then Return Null
		If image.Length<pixmap.Length Then image=New Image[pixmap.Length]
		If Not image[mipmap] Then
			image[mipmap]=New Image(pixmap[mipmap])
			image[mipmap].TextureFilter=TextureFilter.Nearest
		Endif
		Return image[mipmap]
	End
	
	Method CountMipmaps:Int()
		Local count:Int
		For Local i:Int=0 Until pixmap.Length
			If pixmap[i] Then count+=1
		Next
		Return count
	End
	
	Method GetIndex:Int()
		If Not parent Or Not parent.parent Or Not parent.parent.images Then Return Null
		For Local i:Int=0 Until parent.parent.images.Length
			If parent.parent.images[i]=Self Then Return i
		Next
		WadWarning("Unable to get index!")
		Return Null
	End
	
	Method Move(order:Int,adjusted:Bool=True)
		If order=0 Then Return
		Local mySlot:Int=GetIndex()
		If adjusted Then
			For Local i:Int=1 To Abs(order)
				parent.parent.images[mySlot].Move(Sgn(order),False)
				mySlot+=Sgn(order)
			Next
		Else
			Local replacingTex:WadImage=parent.parent.images[mySlot+order]
			parent.parent.images[mySlot+order]=Self
			parent.parent.images[mySlot]=replacingTex
		Endif
	End
	
	Method MoveFirst()
		Move(-GetIndex())
	End
	
	Method MoveLast()
		Move(parent.parent.images.Length-1-GetIndex())
	End
	
	Method Remove()
		Local mySlot:Int=GetIndex()
		For Local i:Int=mySlot+1 Until parent.parent.images.Length
			parent.parent.images[i].Move(-1,False)
		Next
		parent.parent.images=parent.parent.images.Resize(parent.parent.images.Length-1)
		
		pixmap=Null
		image=Null
		parent=Null
	End
	
	Function GetMipSize:Int(size:Int,mip:Int)
		Select mip
			Case 1 Return size/2
			Case 2 Return size/4
			Case 3 Return size/8
		End
		Return size
	End
End

Private
Class WadPaletteImage Extends WadImage
	
	Method Write(file:Stream) Override
		WadError("Saving palette images isn't supported yet!")
	End
	
	Method New(owner:WadEntry)
		parent=owner
		parent.parent.dataOffset=parent.offset
		name=parent.name
		type=parent.type
		
		width=256
		height=256
		
		'Prepare REAL palette
		parent.parent.palette.palette=New UInt[256*3]
		
		'Pixels
		'Self.pixels=New Int[width/16,width/16,1]
		
		Local x:Int
		Local y:Int
		For x=0 Until width
			parent.parent.palette.palette[x*3]=parent.parent.ReadUByte()
			parent.parent.palette.palette[x*3+1]=parent.parent.ReadUByte()
			parent.parent.palette.palette[x*3+2]=parent.parent.ReadUByte()
		Next
		
		'GenerateImage()
	End
	
	Method GenerateImage() Override
		pixmap=New Pixmap[1]
		pixmap[0]=New Pixmap(width/16,width/16)
		
		Local x:Int
		Local dX:Int
		Local dY:Int
		
		For x=0 Until width
			pixmap[0].SetPixelARGB(dX,dY,parent.parent.palette.GetARGB(x))
			
			dX+=1
			If dX>=pixmap[0].Width Then
				dX=0
				dY+=1
			Endif
		Next
		
		'pixmap[0].Save("G:\Projects\Monkey 2\quake toolbox\wad\test.png")
	End
End

Class WadTexture Extends WadImage
	
	Method Write(file:Stream) Override
		'Print "Writing tex: "+name
		parent.offset=file.Position
		parent.type=type
		parent.name=name
		
		file.WriteString(parent.PadName(name))
		
		'Size
		file.WriteInt(width)
		file.WriteInt(height)
		
		'Reserve mipmap offsets
		Local mipStart:Int=file.Position
		For Local i:Int=0 Until mipOffset.Length
			file.WriteInt(0)
		Next
		
		'Pixels
		Local x:Int
		Local y:Int
		For Local mip:Int=0 Until mipOffset.Length
			mipOffset[mip]=file.Position-parent.offset
			
			For y=0 Until GetMipSize(height,mip)
			For x=0 Until GetMipSize(width,mip)
				file.WriteUByte(pixels[x,y,mip])
			Next
			Next
		Next
		
		'Fill in mipmap offsets
		Local lastPos:Int=file.Position
		file.Seek(mipStart)
		For Local i:Int=0 Until mipOffset.Length
			file.WriteInt(mipOffset[i])
		Next
		file.Seek(lastPos)
		
		'Store sizes
		parent.size=file.Position-parent.offset
		parent.dsize=file.Position-parent.offset
	End
	
	Method New()
	End
	
	Method New(owner:WadEntry)
		parent=owner
		parent.parent.dataOffset=parent.offset
		type=parent.type
		
		name=parent.parent.ReadString(16).Split(String.FromChar(0))[0]
		If Not name Then name="No_name"
		
		width=parent.parent.ReadInt()
		height=parent.parent.ReadInt()
		
		If width>1024*4 Or height>1024*4 Then
			WadWarning("Skipping ~q"+name+"~q due to odd image size")
			width=0
			height=0
			Return
		Endif
		
		pixels=New UInt[width,height,mipOffset.Length]
		For Local i:Int=0 Until mipOffset.Length
			mipOffset[i]=parent.parent.ReadUInt()
		Next
		
		'Pixels
		Local x:Int
		Local y:Int
		
		For Local mip:Int=0 Until mipOffset.Length
			parent.parent.dataOffset=parent.offset+mipOffset[mip]
			
			For y=0 Until GetMipSize(height,mip)
			For x=0 Until GetMipSize(width,mip)
				pixels[x,y,mip]=parent.parent.ReadUByte()
			Next
			Next
		Next
		
		'GenerateImage()
	End
	
	Method GenerateImage() Override
		If width<=0 Or height<=0 Then Return
		
		pixmap=New Pixmap[mipOffset.Length]
		For Local i:Int=0 Until mipOffset.Length
			pixmap[i]=New Pixmap(GetMipSize(width,i),GetMipSize(height,i))
		Next
		
		Local x:Int
		Local y:Int
		Local p:Ubyte
		For Local mip:Int=0 Until mipOffset.Length
		For y=0 Until GetMipSize(height,mip)
		For x=0 Until GetMipSize(width,mip)
			p=pixels[x,y,mip]
			If p Then
				pixmap[mip].SetPixelARGB(x,y,parent.parent.palette.GetARGB(p))
			Else
				pixmap[mip].SetPixelARGB(x,y,0)
			Endif
		Next
		Next
		Next
	End
End

Class WadPicture Extends WadImage
	
	Method Write(file:Stream) Override
		WadError("Saving images isn't supported yet!")
	End
	
	Method New(owner:WadEntry)
		parent=owner
		parent.parent.dataOffset=parent.offset
		name=parent.name
		type=parent.type
		
		width=parent.parent.ReadInt()
		height=parent.parent.ReadInt()
		
		'Pixels
		pixels=New UInt[width,height,1]
		Local x:Int
		Local y:Int
		
		For y=0 Until height
		For x=0 Until width
			pixels[x,y,0]=parent.parent.ReadUByte()
		Next
		Next
		
		'GenerateImage()
	End
	
	Method GenerateImage() Override
		pixmap=New Pixmap[1]
		pixmap[0]=New Pixmap(width,height)
		
		Local x:Int
		Local y:Int
		Local p:Ubyte
		For y=0 Until height
		For x=0 Until width
			p=pixels[x,y,0]
			If p Then
				pixmap[0].SetPixelARGB(x,y,parent.parent.palette.GetARGB(p))
			Else
				pixmap[0].SetPixelARGB(x,y,0)
			Endif
		Next
		Next
	End
End
Public

Class WadPalette
	Field palette:UInt[]
	
	Method GetARGB:UInt(index:Int)
		If Not palette Then palette=defPalette
		If index*3+2>palette.Length Then Return -1
		Return (255 Shl 24) | (palette[index*3] Shl 16) | (palette[index*3+1] Shl 8) | palette[index*3+2]
	End
	
	Method GetSimilar:UByte(ARGB:UInt)
		If Not palette Then palette=defPalette
		Local a:=(ARGB Shr 24 & $ff)
		If a<128 Then Return 0
		
		Local r:Int=(ARGB Shr 16 & $ff)
		Local g:Int=(ARGB Shr 8 & $ff)
		Local b:Int=(ARGB & $ff)
		Local rP:Int
		Local gP:Int
		Local bP:Int
		Local bestMatch:UByte
		Local bestMatchScore:Int=-1
		Local score:Int
		Local i:int
		
		'Find 100% match
		For i=0 Until palette.Length/3
			rP=palette[i*3]
			gP=palette[i*3+1]
			bP=palette[i*3+2]
			
			If r=rP And g=gP And b=bP Then Return i
		Next
		
		'Find next best
		For i=0 Until palette.Length/3
			rP=palette[i*3]
			gP=palette[i*3+1]
			bP=palette[i*3+2]
			
			'Very good match
			If r>=rP-1 And g>=gP-1 And b>=bP-1 And r<=rP+1 And g<=gP+1 And b<=bP+1 Then Return i
			
			'Similar
			score=Abs(rP-r)+Abs(gP-g)+Abs(bP-b)
			If score<=bestMatchScore Or bestMatchScore<0 Then
				bestMatchScore=score
				bestMatch=i
			Endif
		Next
		
		Return bestMatch
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

'=EXAMPLE
#rem
Class MyWindow Extends Window
	Field myWad:Wad
	
	Method New(title:String="Quake Wad manager",width:Int=640,height:Int=480,flags:WindowFlags=Null)
		Super.New(title,width,height,flags )
		
		'Load a basic Wad
		'myWad=New Wad("G:/Projects/Monkey 2/quake toolbox/wad/BASE.WAD")
		myWad=New Wad
		
		'Add our own texture
		Local ourTex:WadTexture=myWad.AddTexture("G:/Projects/Monkey 2/quake toolbox/wad/test.png")
		
		'Save to a new Wad
		myWad.Save("G:/Projects/Monkey 2/quake toolbox/wad/test.wad")
		
		App.Terminate()
	End

	Method OnRender(canvas:Canvas) Override
		App.RequestRender()
		
	End
End

Function Main()
	New AppInstance
	New MyWindow
	App.Run()
End
#endrem