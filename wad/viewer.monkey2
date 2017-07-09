#Import "<std>"
#Import "<mojo>"
#Import "<mojox>"
Using std..
Using mojo..
Using mojox..

#Import "assets/"

#Import "wad.monkey2"

Class MainWindow Extends Window
	Field title:String
	Field textureList:TextureList
	Field scroller:ScrollBar
	Field tree:TreeView
	Field filter:TextField
	Field menuBar:MenuBar
	
	Method New()
		Super.New("Initializing",1280*0.85,720*0.85,WindowFlags.Resizable)
		
		'Check assets
		If Not GetFileType(AppDir()+"/assets")=FileType.Directory Then
			Notify("Missing assets","~qassets~q folder missing",True)
			App.Terminate()
		Endif
		
		If Not GetFileType(AppDir()+"/assets/fonts")=FileType.Directory Then
			Notify("Missing assets","~qfonts~q folder missing",True)
			App.Terminate()
		Endif
		
		If Not GetFileType(AppDir()+"/assets/shaders")=FileType.Directory Then
			Notify("Missing assets","~qshaders~q folder missing",True)
			App.Terminate()
		Endif
		
		If Not GetFileType(AppDir()+"/assets/themes")=FileType.Directory Then
			Notify("Missing assets","~qthemes~q folder missing",True)
			App.Terminate()
		Endif
		
		If Not GetFileType(AppDir()+"/assets/themes/default.json")=FileType.File Then
			Notify("Missing assets","~qdefault~q theme missing",True)
			App.Terminate()
		Endif
		
		If Not GetFileType(AppDir()+"/d3dcompiler_47.dll")=FileType.File Then
			Notify("Warning","~qd3dcompiler_47.dll~q is missing.~nThe application may still run but it is recommended you keep this DLL in the same folder.")
		Endif
		
		title="Hezkore's Wad manager"
		#If __CONFIG__="debug"
			title+=" (DEBUG MODE)"
		#Endif
		
		Self.Title=title
		
		'RenderStyle.DefaultFont=App.Theme.GetFont("fixedWidth")
		
		'Load a basic Wad
		'myWad=New Wad("G:/Projects/Monkey 2/quake toolbox/wad/BASE.WAD")
		'myWad=New Wad
		
		'Add our own texture
		'Local ourTex:WadTexture=myWad.AddTexture("G:/Projects/Monkey 2/quake toolbox/wad/test.png")
		
		'Save to a new Wad
		'myWad.Save("G:/Projects/Monkey 2/quake toolbox/wad/test.wad")
		
		Local dockingView:=New DockingView
		
		Local fileMenu:=New Menu( "File" )
		
		#rem
		Local recentFiles:=New Menu( "Recent Files..." )
		recentFiles.AddAction( "File1" )
		recentFiles.AddAction( "File2" )
		recentFiles.AddAction( "File3" )
		recentFiles.AddAction( "File4" )
		recentFiles.AddAction( "File5" )
		#End
		
		fileMenu.AddAction( "Open" ).Triggered=Lambda()
			Local file:String=RequestFile("Select Wad","Wad files:wad;All Files:*",False,AppDir())
			If file Then textureList.OpenWad(file)
		End
		
		'fileMenu.AddSubMenu( recentFiles )
		
		fileMenu.AddAction( "Save" ).Triggered=Lambda()
			textureList.Save()
		End
		
		fileMenu.AddAction( "Save As.." ).Triggered=Lambda()
			textureList.SaveAs()
		End
		
		fileMenu.AddSeparator()

		fileMenu.AddAction( "Close" ).Triggered=Lambda()
			textureList.CloseWad()
		End
		
		fileMenu.AddAction( "Quit" ).Triggered=Lambda()
			App.Terminate()
		End
		
		#rem
		Local editMenu:=New Menu( "Edit" )

		editMenu.AddAction( "Cut" ).Triggered=Lambda()
			Alert( "Cut Selected..." )
		End
		
		editMenu.AddAction( "Copy" ).Triggered=Lambda()
			Alert( "Copy Selected..." )
		End
		
		editMenu.AddAction( "Paste" ).Triggered=Lambda()
			Alert( "Paste Selected..." )
		End
		#end
		
		menuBar=New MenuBar
		menuBar.AddMenu(fileMenu)
		'menuBar.AddMenu(editMenu)
		
		UpdateWindow(False)
		
		dockingView.AddView(menuBar,"top")
		
		tree=New TreeView()
		dockingView.AddView(tree,"left",RenderStyle.DefaultFont.TextWidth("WLONGLONGLONGLONGW"),True)
		
		'tree.NodeExpanded+=Lambda(node:TreeView.Node)
			'Alert( "Node expanded: node.Text=~q"+node.Text+"~q" )
		'End
		
		'tree.NodeCollapsed+=Lambda(node:TreeView.Node)
			'Alert( "Node collapsed: node.Text=~q"+node.Text+"~q" )
		'End
		
		Local filterDock:=New DockingView
		
		Local filterIconImage:=Image.Load("asset::themes/filter.png")
		If Not filterIconImage Then
			Print "Unable to load filter icon!"
		Else
			filterIconImage.Color=App.Theme.GetColor("knob")
		Endif
		Local filterIcon:=New Label("",filterIconImage)
		filterDock.AddView(filterIcon,"left")
		
		filter=New TextField("Search here")
		filter.MaxSize=New Vec2i(0,0)
		filter.MaxLength=1000000000
		filter.Style=GetStyle("SearchField")
		Local c:Color=filter.RenderStyle.TextColor
		filter.RenderStyle.TextColor=New Color(c.r,c.g,c.b,0.15)
		filter.CursorType=CursorType.IBeam
		filterDock.AddView(filter,"left",Null,True)
		
		dockingView.AddView(filterDock,"bottom")
		
		filter.CursorMoved=Lambda()
			If filter.RenderStyle.TextColor.A<1 Then
				filter.RenderStyle.TextColor=New Color(c.r,c.g,c.b,c.a)
				filter.Text=Null
			Endif
		End
		
		scroller=New ScrollBar(Axis.Y)
		dockingView.AddView(scroller,"right","16")
		
		textureList=New TextureList(self)
		
		dockingView.ContentView=textureList
		ContentView=dockingView
		dockingView.ContentView.MakeKeyView()
		
		App.FileDropped=OnFileDrop
		
		If AppArgs() And AppArgs().Length>1 Then
			textureList.OpenWad(AppArgs()[1])
		Else
			If GetFileType("F:\Games\Quake\gfx\BASE.WAD")=FileType.File Then
				textureList.OpenWad("F:\Games\Quake\gfx\BASE.WAD")
			Endif
		Endif
	End
	
	Method OnRender(canvas:Canvas) Override
		App.RequestRender()
	End
	
	Method OnFileDrop(path:String)
		Select ExtractExt(path.ToLower())
			Case ".wad"
				textureList.OpenWad(path)
			Case ".png",".bmp",".jpg",".jpeg"
				textureList.AddTexture(path)
			Default Alert("Unknown filetype")
		End
	End
	
End

Class TextureList Extends View
	Field parent:MainWindow
	Field myWad:Wad
	Field texSize:Int=128
	Field texSpace:Int=16
	Field texNameSize:Float=1.25
	Field lastViewport:Recti
	Field hoverTex:WadImage
	Field clickTex:WadImage
	Field lastTex:WadImage
	Field scrollToTex:WadImage
	Field ajustedMoved:Bool=True
	Field clickW:Float
	Field clickH:Float
	Field clickX:Float
	Field clickY:Float
	Field mouseX:Int
	Field mouseY:Int
	Field mouseDown:Int
	
	Field progress:ProgressDialog
	Field progressHideTimeout:Int
	
	Field imageInspector:ImageInspector
	
	Field editMenu:Menu
	
	Method New(owner:MainWindow)
		Super.New()
		parent=owner
		WadError=Error
		WadWarning=Warning
		
		RenderStyle.Font=App.Theme.GetFont("fixedWidth")
		
		'Setup tree actions
		parent.tree.NodeClicked+=Lambda(node:TreeView.Node)
			'Alert( "Node clicked: node.Text=~q"+node.Text+"~q" )
			If node.Children then
				'This is def. a picture!
				If myWad Then
					For Local wI:WadImage=Eachin myWad.images
						If wI.name=node.Text Then
							lastTex=wI
							hoverTex=wI
							ScrollTo(lastTex)
							
							For Local n:TreeView.Node=Eachin parent.tree.RootNode.Children
								n.Selected=False
								For Local n2:TreeView.Node=Eachin n.Children
									n2.Selected=False
								Next
							Next
							
							node.Selected=True
							If node.Expanded Then
								'node.Expanded=False
							Else
								'node.Expanded=True
							Endif
							
							Exit
						Endif
					Next
				Endif
			Else
				'Some info then
				Select node.Text.Split(":")[0]
					Case "mipmap"
						ShowImage(myWad.GetImage(node.Parent.Text),Int(node.Text.Split(": ")[1]))
				End
			Endif
		End
		
		parent.tree.NodeRightClicked+=Lambda(node:TreeView.Node)
			parent.tree.NodeClicked(node)
			Local me:MouseEvent=New MouseEvent(EventType.MouseRightClick,Null,Mouse.Location,MouseButton.Right,New Vec2i,Modifier.None,0)
			MouseMenu(me)
		End
		
		'Setup edit menu
		editMenu=New Menu("Edit")
		
		editMenu.AddAction("Rename").Triggered=Lambda()
			Local newName:String=RequestName(lastTex.name,"New name for ~q"+lastTex.name+"~q")
			If newName Then
				lastTex.name=newName.Left(16)
				UpdateTree()
			Endif
		End
		
		editMenu.AddAction("Export").Triggered=Lambda()
			Export()
		End
		
		editMenu.AddAction("Import").Triggered=Lambda()
			AddTexture(RequestFile("Import texture","Image file:png,bmp,jpg,jpeg;All files:*",False,AppDir()))
		End
		
		editMenu.AddSeparator()
		editMenu.AddAction("Remove").Triggered=Lambda()
			lastTex.Remove()
			UpdateTree()
		End
		
		parent.menuBar.AddMenu(editMenu)
	End
	
	Method ShowImage(image:WadImage,mipmap:Int=0)
		If Not image Or mipmap<0 Then Return
		If Not imageInspector Then
			imageInspector=New ImageInspector
			imageInspector.parent=Self
		Endif
		If Not imageInspector.Active Then imageInspector.Open()
		
		imageInspector.Load(image)
		imageInspector.Mipmap=mipmap
		App.UpdateWindows()
	End
	
	Method Export()
		If Not lastTex Then Return
		
		Local mip:Int
		Local exportName:String=lastTex.name
		
		If lastTex.CountMipmaps()>1 Then
			mip=RequestInt("0-"+(lastTex.CountMipmaps()-1),"What mipmap to export?",0,-1,0,lastTex.CountMipmaps()-1)
			If mip<0 Then Return
			If mip>0 Then exportName+="_mip"+mip
		Endif
		
		lastTex.Export(RequestFile("Export ~q"+lastTex.name+"~q","Image file:png;All files:*",True,exportName+".png"),mip)	
	End
	
	Method MouseMenu(event:MouseEvent)
		If event.View=Self Then lastTex=hoverTex
		If Not lastTex Then Return
		
		editMenu.Open()
		
		event.Eat()
	End
	
	Function RequestName:String( message:String="Enter a string:",title:String="String requester" )
		Assert( Fiber.Current()<>Fiber.Main(),"RequestString cannot be used from the main fiber" )
	
		Local future:=New Future<String>
		
		Local textField:=New TextField(message)
		textField.CursorType=CursorType.IBeam
		textField.MaxLength=16
		
		Local dialog:=New Dialog(title)
		dialog.MaxSize=New Vec2i(320,0)
		
		dialog.ContentView=textField
		
		Local okay:=dialog.AddAction("Okay")
		okay.Triggered=Lambda()
			future.Set(textField.Text)
		End
		
		Local cancel:=dialog.AddAction("Cancel")
		cancel.Triggered=Lambda()
			future.Set("")
		End
		
		textField.Entered=okay.Trigger
		textField.Escaped=cancel.Trigger
		
		dialog.Open()
		textField.MakeKeyView()
		App.BeginModal( dialog )
		Local str:=future.Get()
		App.EndModal()
		dialog.Close()
		Return str
	End
	
	Method Save()
		If Not myWad Then
			Alert("No Wad to save","Warning!")
			Return
		Endif
		
		If myWad.filePath Then
			ShowProgress("Saving ~q"+myWad.filePath+"~q")
			myWad.Save(myWad.filePath)
		Else
			If Not SaveAs() Then Return
		Endif
		myWad.name=StripDir(StripExt(myWad.filePath))
		parent.Title=parent.title+" ["+myWad.filePath+"]"
	End
	
	Method SaveAs:Bool()
		If Not myWad Then
			Alert("No Wad to save","Warning!")
			Return False
		Endif
		
		Local file:String=RequestFile("Save Wad As..","Wad files:wad;All files:*",True,myWad.name+".wad")
		If file Then
			myWad.name=StripDir(StripExt(file))
			ShowProgress("Saving ~q"+file+"~q")
			myWad.Save(file)
			parent.Title=parent.title+" ["+myWad.filePath+"]"
			Return True
		Endif
		Return False
	End
	
	Method Error:Void(message:String)
		Alert(message,"Error!")
		App.UpdateWindows()
	End
	
	Method Warning:Void(message:String)
		Alert(message,"Warning!")
		'App.UpdateWindows()
	End
	
	Method ShowProgress(text:String)
		If Not progress Then
			#If __CONFIG__="debug"
				progress=New ProgressDialog("Loading (SLOW IN DEBUG MODE)")
			#Else
				progress=New ProgressDialog("Loading")
			#Endif
		Endif
		
		progressHideTimeout=0
		progress.Text=text
		If Not progress.Active Then progress.Open()
		App.UpdateWindows()
	End
	
	Method SelectTreeNode(img:WadImage)
		If Not img Or Not myWad Then Return
		For Local n:TreeView.Node=Eachin parent.tree.RootNode.Children
			
			If n.Text=img.name Then
				n.Expanded=True
				n.Selected=True
				parent.tree.EnsureVisible(n.Rect)
			Else
				If Not n.Text.StartsWith("[") And Not n.Text.EndsWith("]") Then
					n.Expanded=False
				Endif
				n.Selected=False
			Endif
			
			For Local n2:TreeView.Node=Eachin n.Children
				If n2.Text=img.name Then
					n.Expanded=True
					n2.Expanded=True
					n2.Selected=True
					parent.tree.EnsureVisible(n2.Rect)
				Else
					n2.Expanded=False
					n2.Selected=False
				Endif
			Next
			
		Next
	End
	
	Method GetTreeNode:TreeView.Node(name:String)
		name.ToLower()
		For Local n:TreeView.Node=Eachin parent.tree.RootNode.Children
			If n.Text.ToLower()=name Then
				n.Expanded=True
				Return n
			Endif
		Next
		
		Local n:=New TreeView.Node(name,parent.tree.RootNode) 
		n.Expanded=True
		Return n
	End
	
	Method UpdateTree()
		parent.tree.RootNode.RemoveAllChildren()
		If myWad Then
			parent.tree.RootNode.Text=myWad.name
		Else
			parent.tree.RootNode.Text=Null
			Return
		Endif
		Local tree:=parent.tree 'Shortcut!
		tree.RootNode.Expanded=True
		tree.RootNodeVisible=False
		
		Local node:TreeView.Node
		
		For Local i:Int=0 Until myWad.CountImages()
			If myWad.GetImage(i) Then
				
				'Group with animations?
				If IsGroup(myWad.GetImage(i).name) Then
					node=New TreeView.Node(myWad.GetImage(i).name,GetTreeNode(IsGroup(myWad.GetImage(i).name)))
				Else
					node=New TreeView.Node(myWad.GetImage(i).name,tree.RootNode)
				Endif
				
				'Info
				New TreeView.Node("type: "+TranslateType(myWad.GetImage(i).type),node)
				New TreeView.Node("width: "+myWad.GetImage(i).width,node)
				New TreeView.Node("height: "+myWad.GetImage(i).width,node)
				
				For Local mip:Int=1 Until myWad.GetImage(i).CountMipmaps()
					New TreeView.Node("mipmap: "+mip,node)
				Next
					
			Endif
		Next
		
		App.UpdateWindows()
	End
	
	Method IsGroup:String(name:String)
		If name.StartsWith("+") Then Return "["+name.Right(name.Length-2)+"]"
		If name.StartsWith("*") Then Return "[liquid]"
		If name.StartsWith("sky") Then Return "[sky]"
		Return Null
	End
	
	Method TranslateType:String(type:String)
		Select type
			Case "@" Return "Palette"
			Case "B" Return "Picture"
			Case "D" Return "Texture"
		End
		Return "Unknown"
	End
	
	Method ScrollTo(img:WadImage)
		scrollToTex=img
		OnRender(Null)
	End
	
	Method OpenWad(path:String)
		ShowProgress("Loading ~q"+StripDir(path)+"~q")
		parent.Title=parent.title+" ["+path+"]"
		myWad=New Wad(path)
		UpdateTree()
		hoverTex=Null
		clickTex=Null
		lastTex=Null
	End
	
	Method CloseWad()
		myWad=Null
		myWad=New Wad
		UpdateTree()
		hoverTex=Null
		clickTex=Null
		lastTex=Null
	End
	
	Method AddTexture(path:String)
		If Not path Then Return
		ShowProgress("Adding: ~q"+StripDir(path)+"~q")
		If myWad.AddTexture(path) Then
			lastTex=myWad.GetLastImage()
			OnRender(Null)
			If hoverTex Then
				myWad.GetLastImage().Move(hoverTex.GetIndex()-myWad.GetLastImage().GetIndex())
			Endif
			UpdateTree()
		Endif
	End
	
	Method OnRender(canvas:Canvas) Override
		parent.scroller.Minimum=0
		
		If progress And progress.Active And progressHideTimeout>=5 Then progress.Close()
		progressHideTimeout+=1
		If Not myWad Then Return
		
		
		If canvas Then lastViewport=canvas.Viewport
		
		Local sizeName:Float=RenderStyle.DefaultFont.Height*texNameSize
		Local fontH:Float=RenderStyle.DefaultFont.Height*texNameSize
		Local size:Float=texSize
		Local border:Int=texSpace/4.0
		Local space:Int=texSpace
		Local totalSize:Int=texSize+texSpace
		Local horiCount:Float=Max(Float(lastViewport.Width-texSpace)/Float(totalSize),1.0)
		Local extraSize:Float=Floor(horiCount)-horiCount
		Local vertiCount:Int
		Local count:Int
		Local drawCount:int
		Local x:Float
		Local y:Float=space
		If canvas Then y-=parent.scroller.Value
		Local xOff:Float
		Local yOff:Float
		Local xAllOff:Float
		Local yAllOff:Float
		Local w:Float
		Local h:Float
		Local ratio:Float
		Local adjSpace:Float=space*(1+(extraSize*-1))
		
		hoverTex=Null
		
		For Local i:Int=0 Until myWad.CountImages()
			If Not myWad.GetImage(i) Or myWad.GetImage(i).width<=0 Or myWad.GetImage(i).height<=0 Then Continue
			
			'Is this the texture we're supposed to scroll to?
			If scrollToTex And myWad.GetImage(i)=scrollToTex Then
				parent.scroller.Value=y-lastViewport.Height/2+totalSize/2
			Endif
			
			'Filter out texture names
			If parent.filter.Text And parent.filter.RenderStyle.TextColor.A>0.15 Then
				If myWad.GetImage(i).name.ToLower().Contains(parent.filter.Text.ToLower()) Then
				Else
					Continue
				Endif
			Endif
			
			ratio=Float(myWad.GetImage(i).width)/Float(myWad.GetImage(i).height)
			If myWad.GetImage(i).width>myWad.GetImage(i).height Then
				w=size
				h=size/ratio
			Else
				w=size*ratio
				h=size
			Endif
			
			x=space+(Float(count)/(horiCount+extraSize))*Float(lastViewport.Width-texSpace)
			xAllOff=0
			yAllOff=0
			xOff=size/2-w/2
			yOff=size/2-h/2
			
			If x>0 And y+totalSize+sizeName>0 And x<lastViewport.Width And y<lastViewport.Height Or canvas=Null Then
				If Not canvas Then y-=parent.scroller.Value
				If mouseX>x-adjSpace/1.5 And mouseX<x+size+adjSpace/1.5 And mouseY>y-adjSpace/1.5 And mouseY<y+size+sizeName+adjSpace/2 Then
					If mouseDown Then
						If Not clickTex Then
							clickTex=myWad.GetImage(i)
							clickW=w
							clickH=h
							clickX=x+xOff-mouseX
							clickY=y+yOff-mouseY
							lastTex=clickTex
							SelectTreeNode(clickTex)
						Endif
					Endif
					
					If Not hoverTex Then hoverTex=myWad.GetImage(i)
					If hoverTex=clickTex Then hoverTex=Null
				Endif
				If Not canvas Then y+=parent.scroller.Value
				
				If canvas Then
					canvas.Color=New Color(0,0,0,0.25)
					
					If myWad.GetImage(i)=hoverTex Then
						If clickTex Then
							If ajustedMoved Then
								canvas.Color=New Color(1,0,1,0.15)
							Else
								canvas.Color=New Color(1,0,0,0.15)
							Endif
						Else
							canvas.Color=New Color(1,1,1,0.15)
						Endif
					Endif
					
					If Not myWad.GetImage(i).MojoImage() Then Continue
					
					If myWad.GetImage(i)=lastTex Then canvas.Color=New Color(1,1,1,0.5)
					If myWad.GetImage(i)=clickTex Then canvas.Color=New Color(0,1,1,0.5)
					
					canvas.DrawRect(x-border+xAllOff,y-border+yAllOff,totalSize-border*2,totalSize-border*2+sizeName)
					canvas.Color=Color.White
					canvas.BlendMode=BlendMode.Opaque
					canvas.DrawRect(x+xOff+xAllOff,y+yOff+yAllOff,w,h,myWad.GetImage(i).MojoImage())
					canvas.BlendMode=BlendMode.Alpha
					SetScissor(canvas,x,y+size,size,sizeName+fontH)
					canvas.Color=Color.Black
					canvas.DrawText(myWad.GetImage(i).name,x+size/2+xAllOff+1,y+size+sizeName/2+fontH/2+yAllOff,0.5,1)
					canvas.DrawText(myWad.GetImage(i).name,x+size/2+xAllOff-1,y+size+sizeName/2+fontH/2+yAllOff,0.5,1)
					canvas.DrawText(myWad.GetImage(i).name,x+size/2+xAllOff,y+size+sizeName/2+fontH/2+yAllOff+1,0.5,1)
					canvas.DrawText(myWad.GetImage(i).name,x+size/2+xAllOff,y+size+sizeName/2+fontH/2+yAllOff-1,0.5,1)
					canvas.Color=Color.White
					canvas.DrawText(myWad.GetImage(i).name,x+size/2+xAllOff,y+size+sizeName/2+fontH/2+yAllOff,0.5,1)
					ResetScissor(canvas)
				Endif
				
				drawCount+=1
			Endif
			
			count+=1
			If count>horiCount-1 Then
				count=0
				y+=totalSize+sizeName
				vertiCount+=1
			Endif
			
		Next
		
		'We're done scrolling now!
		scrollToTex=Null
		
		'Draw preview image of dragging texture
		If hoverTex And clickTex And canvas Then
			canvas.Alpha=0.75
			canvas.DrawRect(mouseX+clickX,mouseY+clickY,clickW,clickH,clickTex.MojoImage())
			canvas.Alpha=1
		Endif
		
		'Dirty scroller!
		If (totalSize+sizeName)*(vertiCount+1)>lastViewport.Height Then
			parent.scroller.Maximum=y+parent.scroller.Value-lastViewport.Height+totalSize+sizeName
		Else
			parent.scroller.Value=0
			parent.scroller.Maximum=0
		Endif
		
		'Debug warning
		#If __CONFIG__="debug"
			If canvas Then
				canvas.Color=Color.Red
				canvas.DrawText("DEBUG MODE",1,1)
			Endif
		#Endif
	End
	
	Function SetScissor(canvas:Canvas,x:Float,y:Float,width:Float,height:Float)
		canvas.Scissor=New Recti(x,y,x+width,y+height)
	End
	
	Function ResetScissor(canvas:Canvas)
		canvas.Scissor=canvas.Viewport
	End
	
	Method OnKeyEvent(event:KeyEvent) Override
		Select event.Type
			
			Case EventType.KeyDown
				Select event.Key
					Case Key.KeyDelete,Key.Backspace
						If lastTex Then
							lastTex.Remove()
							lastTex=Null
							hoverTex=Null
							clickTex=Null
							UpdateTree()
						Endif
						
					Case Key.LeftShift,Key.RightShift
						ajustedMoved=False
				End
				
			Case EventType.KeyUp
				Select event.Key
					Case Key.LeftShift,Key.RightShift
						ajustedMoved=True
				End
		End
	End
	
	Method OnKeyViewChanged(oldKeyView:View,newKeyView:View) Override
		If newKeyView=parent.filter Then
			clickTex=Null
			hoverTex=Null
			lastTex=Null	
		End
		
		If newKeyView=parent.tree Then MakeKeyView()
	End
	
	Method OnMouseEvent(event:MouseEvent) Override
		
		Select event.Type
			Case EventType.MouseWheel
				parent.scroller.Value-=event.Wheel.Y*texSize*0.75
			
			Case EventType.MouseMove
				mouseX=event.Location.x
				mouseY=event.Location.y
				
			Case EventType.MouseDoubleClick
				'Print "ASP!"
				ShowImage(lastTex)
				
			Case EventType.MouseDown
				Select event.Button
					Case MouseButton.Left
						MakeKeyView()
						mouseDown=True
				End
				
			Case EventType.MouseUp
				Select event.Button
					Case MouseButton.Left
						mouseDown=False
						
						If hoverTex And clickTex Then
							clickTex.Move(hoverTex.GetIndex()-clickTex.GetIndex(),ajustedMoved)
							UpdateTree()
							SelectTreeNode(clickTex)
						Endif
						
						clickTex=Null
					Case MouseButton.Right
						SelectTreeNode(hoverTex)
						MouseMenu(event)
				End
		End
	End
End

Class WadImageRenderer Extends View
	Field parent:ImageInspector
	Field wadImage:WadImage
	Field mipmap:Int
	Field mojoImage:Image
	'Field animFrame:Int
	Field animMs:Int
	Field lastMs:Int
	Field animSpeed:Int=200
	
	Method New()
		
	End
	
	Method Load(wadImage:WadImage)
		mojoImage=Null
		
		For Local wI:WadImage=Eachin parent.parent.myWad.images
			wI.FindNextFrame()
		Next
		
		Self.wadImage=wadImage
		lastMs=Millisecs()
	End
	
	Method OnRender(canvas:Canvas) Override
		If Not wadImage Or Not wadImage.MojoImage(mipmap) Then Return
		canvas.Translate(wadImage.width/2,wadImage.height/2)
		
		animMs+=Millisecs()-lastMs
		If animMs>=animSpeed Then
			animMs-=animSpeed
			If wadImage.nextImage Then wadImage=wadImage.nextImage
		Endif
		
		mojoImage=wadImage.MojoImage(mipmap)
		If mojoImage Then
			canvas.BlendMode=BlendMode.Opaque
			canvas.DrawImage(mojoImage,-wadImage.width/2,-wadImage.height/2)
			canvas.BlendMode=BlendMode.Alpha
		Endif
		lastMs=Millisecs()
	End
	
	Method OnMeasure:Vec2i() Override
		If Not wadImage Then Return New Vec2i(2,2)
		Return New Vec2i(wadImage.width,wadImage.height)
	End
	
End

Class ImageInspector Extends Dialog
	Field parent:TextureList
	Field image:WadImageRenderer
	Field docker:DockingView
	Field label:Label
	
	Method New()
		Super.New("Image Inspector")
		
		label=New Label("")
		label.Layout="float"
		label.TextGravity=New Vec2f(0.5,0.5)
		label.Gravity=New Vec2f(0.5,0.5)
		
		image=New WadImageRenderer
		image.parent=Self
		image.Layout="float"
		image.Gravity=New Vec2f(0.5,0.5)
		
		docker=New DockingView
		
		docker.AddView(label,"top")
		
		docker.AddView(image,"top")
		
		ContentView=docker
	End
	
	Method Load(wadImage:WadImage)
		label.Text=wadImage.name+"~n"+wadImage.width+"x"+wadImage.height
		image.Load(wadImage)
		
		'Rescale our little window
		Local size:=MeasureLayoutSize()
		Local origin:=(Window.Rect.Size-size)/2
		Frame=New Recti(origin,origin+size)
	End
	
	Property Mipmap:Int()
		Return image.mipmap
	Setter(mipmap:Int)
		image.mipmap=mipmap
	End
	
	Property Image:WadImage()
		Return image.wadImage
	Setter(wadImage:WadImage)
		image.Load(wadImage)
	End
End

Function Main()
	New AppInstance
	New MainWindow
	App.Run()
End