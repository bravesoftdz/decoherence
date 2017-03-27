{Copyright (C) 2012-2017 Yevhen Loza

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <http://www.gnu.org/licenses/>.}

{---------------------------------------------------------------------------}

{ Contains definition for a dungeon tile and loading/parsing procedures }
unit decodungeontiles;

{$INCLUDE compilerconfig.inc}
interface

uses classes, castleImages,
  decoglobal;

const TileScale = 2;

type
  { defines "what face is this"
   tfNone is compatible to any tile
   tfWall is compatible to any wall
   >=tfFree is compatible only to exactly the same face id >=tfFree
   At the moment, floors follow the same logic, but they are used only
   for internal purposes (there is no actual floor docking).
   Theoretically there can be tiles with open/compatible ceiling and/or floor elements
   and it should work as expected without any additional modifications}
  TTileFace = -1..4;//byte;//(tfNone, tfWall, tfFree1, tfFree2...);
const tfNone = 0;
      tfWall = 1;
      tfFree = 2;//(use isPassable to detect tfFree, howerer all tfFree are "tfFree + 0..n")
      tfInacceptible = -1;
{should be only 3/4 varians + kind (TFGPlist)}

type
  {Kind of the tile base,
   tkNone is not assigned tile (can be assigned by generator),
   tkFree is a passable tile,
   tkWall is unused yet,
   tkUp/tkDown are stairs up-down tiles,
   tkInacceptible is an internal type (acceptible error returned by some routines)}
  TTileKind = (tkNone, tkFree, tkWall, tkUp, tkDown, tkInacceptible);

type
  { This is a rectagonal grid with 4 angles + floor + ceiling
   Yes it's theoretically possible to make a hexagonal/other map}
  TAngle = (aTop,aRight,aBottom,aLeft,aUp,aDown);
const
  THorizontalAngle: set of TAngle = [aTop,aRight,aBottom,aLeft];
  {well... 2-abundance is obsolete, really.
   I was making it in order to protect the code from errors
   when writing a lot of code without being able to visually test
   if it produces a correct (intended) result, so I had to introduce
   a lot of internal checks including 2-abundance...
   It both consumes additional memory and requires more CPU time.
   Maybe, some day this should be simplified and rewritten to remove abundance.
   But for now it works and that is all I want :)
   WARNING, if someone who is not "me" will try to rewrite the 2-abundance,
   be careful, because it is used not only to validate the tiles docking,
   but for a lot of other purposes in the generation algorithm
   (maybe in pathfinding and tile management too).
   It can't be done as easy as I'd wanted :) Otherwise, I'd have done it long ago...
   So change it only in case you're absolutely sure what you are doing. }
type
  { 1x1x1 tile with some base and free/blocked faces }
  BasicTile = {packed} record
    base: TTileKind;
    faces: array [TAngle] of TTileFace; //this is 2x redundant!
  end;

//inacceptible tile, used as "return"
const
  InacceptibleTile: BasicTile =
    (base: tkInacceptible;
     faces: (tfInacceptible,tfInacceptible,tfInacceptible,tfInacceptible,tfInacceptible,tfInacceptible));

type
  {common routines shared by TileMap and DungeonMap}
  DMap = class (TObject)
    public
      {size of this map}
      sizex,sizey,sizez: byte;
      {internal map of this tile}
      Map: array of array of array of BasicTile;

      {images of this tile/map 0..sizez-1}
      img: array of TRGBAlphaImage;

      {sets the size of the tile and adjusts memory}
      procedure setsize(tx: integer = 1; ty: integer = 1; tz: integer = 1);
      {distribute memory according to tilesizex,tilesizey,tilesizez}
      procedure GetMapMemory;
      {empties the map with walls at borders}
      procedure EmptyMap(initToFree: boolean);
      {checks if tx,ty,tz are correct for this tile}
      function IsSafe(tx,ty,tz: integer): boolean; {$IFDEF SUPPORTS_INLINE}inline;{$ENDIF}
      function IsSafe(tx,ty: integer): boolean; {$IFDEF SUPPORTS_INLINE}inline;{$ENDIF}
      {safe way to get BasicTile
       (checks if tx,ty,tz are within the Tile size and returns tkInacceptible otherwise) }
      function MapSafe(tx,ty,tz: integer): BasicTile; {$IFDEF SUPPORTS_INLINE}inline;{$ENDIF}
      { safe way to get Tile base
       (checks if tx,ty,tz are within the Tile size and returns tkInacceptible otherwise) }
      function MapSafeBase(tx,ty,tz: integer): TTileKind; {$IFDEF SUPPORTS_INLINE}inline;{$ENDIF}
      { safe way to get Tile Face
        (checks if tx,ty,tz are within the Tile size and returns tfInacceptible otherwise) }
      function MapSafeFace(tx,ty,tz: integer; face: TAngle): TTileFace; {$IFDEF SUPPORTS_INLINE}inline;{$ENDIF}

      destructor destroy; override;
      {frees the minimap memory (careful)}
      procedure FreeMinimap;
end;

type
  {A large tile used in dungeon generation. With a set of Basic_Tile_type
   and additional parameters and procedures
   todo: split DTile and DGenerationTile}
  DTileMap = class (DMap)
    private
      fReady: boolean;
    public
      {name of this tile for debugging}
      TileName: string;
      {if this tile is a blocker?}
      blocker: boolean;

      {is the tile ready to work (loaded and parsed correctly)?}
      property Ready: boolean read fReady write fReady;
      constructor Load(URL: string);// override;
end;

//var MaxTileTypes: integer;
    //TilesList: TStringList;

{ convert TTileKind to a string for saving }
function TileKindToStr(value: TTileKind): string;
{ convert a string to TTileKind for loading }
function StrToTileKind(value: string): TTileKind;

function TileFaceToStr(value: TTileFace): string;
function StrToTileFace(value: string): TTileFace;
function AngleToStr(value: TAngle): string;
function StrToAngle(value: string): TAngle;

{check if this tile is Passable - in a safe way}
function isPassable(value: TTileFace): boolean; {$IFDEF SUPPORTS_INLINE}inline;{$ENDIF}
function isPassable(value: TTileKind): boolean; {$IFDEF SUPPORTS_INLINE}inline;{$ENDIF}
{determine x/y shifts introduced by current Angle}
function a_dx(Angle: TAngle): integer; {$IFDEF SUPPORTS_INLINE}inline;{$ENDIF}
function a_dy(Angle: Tangle): integer; {$IFDEF SUPPORTS_INLINE}inline;{$ENDIF}
function a_dz(Angle: Tangle): integer; {$IFDEF SUPPORTS_INLINE}inline;{$ENDIF}
{inverse function - calculate angle based on dx,dy}
function getAngle(ddx,ddy: integer): TAngle; {$IFDEF SUPPORTS_INLINE}inline;{$ENDIF}
{inverts Angle to the opposite of the pair}
function InvertAngle(Angle: TAngle): TAngle; {$IFDEF SUPPORTS_INLINE}inline;{$ENDIF}

procedure LoadTiles;
procedure destroyTiles;
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
implementation
uses sysUtils, CastleURIUtils, CastleLog,
  DOM, CastleXMLUtils;

function TileKindToStr(value: TTileKind): string;
begin
  case Value of
    tkNone: result := 'NA';
    tkFree: result := 'FREE';
    tkUP: result := 'UP';
    tkDown: result := 'DOWN';
    tkWall: result := 'WALL';
    tkInacceptible: raise exception.Create('tkInacceptible in TileKindToStr');  //this one shouldn't appear in string
    else raise exception.Create('Unknown TileKind in TileKindToStr');
  end;
end;
function StrToTileKind(value: string): TTileKind;
begin
  case value of
    'NA': result := tkNone;
    'FREE': result := tkFree;
    'UP': result := tkUp;
    'DOWN': result := tkDown;
    'WALL': result := tkWall;
    'ERROR':  raise exception.Create('tkInacceptible in StrToTileKind');  //this one shouldn't appear in string
    else raise exception.Create('Unknown TileKind in StrToTileKind');
  end;
end;

{---------------------------------------------------------------------------}

function TileFaceToStr(value: TTileFace): string;
begin
  case Value of
    tfNone: Result := 'none';
    tfWall: Result := 'wall';
    tfFree..high(TTileFace): Result := IntToStr(value);
    else raise exception.create('Unknown TTileFace value in TileFaceToStr');
  end;
end;
function StrToTileFace(value: string): TTileFace;
begin
  case value of
    'none': Result := tfNone;
    'wall': result := tfWall;
    else Result := StrToInt(value);
  end;
end;

{---------------------------------------------------------------------------}

function AngleToStr(value: TAngle): string;
begin
  case value of
    aTop:    Result := 'top';
    aBottom: Result := 'bottom';
    aLeft:   Result := 'left';
    aRight:  Result := 'right';
    aUp:     Result := 'up';
    aDown:   Result := 'down';
  end;
end;
function StrToAngle(value: string): TAngle;
begin
  case value of
    'top':    Result := aTop;
    'bottom': Result := aBottom;
    'left':   Result := aLeft;
    'right':  Result := aRight;
    'up':     Result := aUp;
    'down':   Result := aDown;
  end;
end;

{---------------------------------------------------------------------------}

function isPassable(value: TTileFace): boolean; {$IFDEF SUPPORTS_INLINE}inline;{$ENDIF}
begin
  if value >= tfFree then result := true else result := false;
end;
function isPassable(value: TTileKind): boolean; {$IFDEF SUPPORTS_INLINE}inline;{$ENDIF}
begin
  if (value = tkFree) or (value = tkUp) or (value = tkDown) then
    result := true
  else
    result := false;
end;

{----------------------------------------------------------------------}

function a_dx(Angle: TAngle): integer; {$IFDEF SUPPORTS_INLINE}inline;{$ENDIF}
begin
  case Angle of
    aLeft:  Result := -1;
    aRight: Result := +1;
    else    Result := 0;
  end;
end;
function a_dy(Angle: Tangle): integer; {$IFDEF SUPPORTS_INLINE}inline;{$ENDIF}
begin
  case Angle of
    aTop:    Result := -1;
    aBottom: Result := +1;
    else     Result := 0;
  end;
end;
function a_dz(Angle: Tangle): integer; {$IFDEF SUPPORTS_INLINE}inline;{$ENDIF}
begin
  case Angle of
    aUp:   Result := -1;
    aDown: Result := +1;
    else   Result := 0;
  end;
end;

{----------------------------------------------------------------------}

function getAngle(ddx,ddy: integer): TAngle; {$IFDEF SUPPORTS_INLINE}inline;{$ENDIF}
begin
  if ddy<0 then Result := aTop else
  if ddy>0 then Result := aBottom else
  if ddx<0 then Result := aLeft else
  if ddx>0 then Result := aRight;
end;

{----------------------------------------------------------------------}

function InvertAngle(Angle: TAngle): TAngle; {$IFDEF SUPPORTS_INLINE}inline;{$ENDIF}
begin
  case Angle of
    aTop:    Result := aBottom;
    aBottom: Result := aTop;
    aLeft:   Result := aRight;
    aRight:  Result := aLeft;
    aUp:     Result := aDown;
    aDown:   REsult := aUp;
    else raise Exception.create('Unknown Angle in DecoDungeonTiles.InvertAngle');
  end;
end;

{======================== DTILE TYPE ==========================================}

constructor DTileMap.Load(URL: string);
var TileDOC: TXMLDocument;
    RootNode,WorkNode,ValueNode: TDOMElement;
    Iterator: TXMLElementIterator;
    jx,jy,jz: integer;
    j: TAngle;
begin
  //inherited;
  TileName := DeleteURIExt(ExtractURIName(URL));
  WriteLnLog('DTileMap.Load',URL);

  {todo: clear the tile with base = tkInacceptible
   and check that all tile elements are loaded and give an error otherwise
   Unexpected errors might occur on damaged game data }

  TileDoc := nil;
  try
    TileDOC := URLReadXML(URL);
    RootNode := TileDOC.DocumentElement;
    WorkNode := RootNode.ChildElement('Size');
    SizeX := WorkNode.AttributeInteger('size_x');
    SizeY := WorkNode.AttributeInteger('size_y');
    SizeZ := WorkNode.AttributeInteger('size_z');
    SetSize(Sizex,SizeY,SizeZ);
    blocker := WorkNode.AttributeBoolean('blocker');

    Iterator := RootNode.ChildrenIterator;
    try
      while Iterator.GetNext do if Iterator.current.NodeName = UTF8decode('Tile') then
      begin
        ValueNode := Iterator.current;
        jx := ValueNode.AttributeInteger('x');
        jy := ValueNode.AttributeInteger('y');
        jz := ValueNode.AttributeInteger('z');
        WorkNode := ValueNode.ChildElement('base', true);
        Map[jx,jy,jz].base := StrToTileKind(WorkNode.AttributeString('tile_kind'));
        WorkNode := ValueNode.ChildElement('faces', true);
        for j in TAngle do
           Map[jx,jy,jz].faces[j] := StrToTileFace(WorkNode.AttributeString(AngleToStr(j)));
      end;
    finally
      FreeAndNil(Iterator);
    end;
    fReady := true;
  except
    fReady := false;
  end;
  FreeAndNil(TileDOC);

  if not Ready then
    raise Exception.create('Fatal Error in DTileMap.Load! Unable to open file '+TileName);

  setLength(img,sizez);
  for jz := 0 to sizez-1 do
    img[jz] := LoadImage(ChangeURIExt(URL,'_'+inttostr(jz)+'.png'),[TRGBAlphaImage]) as TRGBAlphaImage;
end;

{----------------------------------------------------------------------------}

procedure DMap.FreeMinimap;
var jz: integer;
begin
  if length(img)>0 then
  for jz := 0 to length(img)-1 do
    FreeAndNil(img[jz]);
end;

destructor DMap.destroy;
begin
  FreeMinimap;
  inherited;
end;

{----------------------------------------------------------------------------}

procedure DMap.setsize(tx: integer = 1; ty: integer = 1; tz: integer = 1);
begin
  sizex := tx;
  sizey := ty;
  sizez := tz;
  //initialize the dynamic arrays
  if (sizex<>0) and (sizey<>0) and (sizez<>0) then
    //in case this is a normal tile...
    GetMapMemory
  else
    //in case this is a "blocker" tile we still need a complete 1x1x1 base
    raise exception.Create('DMap.setsize: Tilesize is zero!');
end;

{----------------------------------------------------------------------------}

procedure DMap.GetMapMemory;
var ix,iy: integer;
begin
  {set length of 3d dynamic array}
  setlength(Map,sizex);
  for ix := 0 to sizex-1 do begin
    setlength(Map[ix],sizey);
    for iy := 0 to sizey-1 do
      setlength(Map[ix,iy],sizez);
  end;
end;

{----------------------------------------------------------------------------}

procedure DMap.EmptyMap(initToFree: boolean);
var jx,jy,jz: integer;
    a: TAngle;
begin
  for jx := 0 to SizeX-1 do
    for jy := 0 to SizeY-1 do
      for jz := 0 to SizeZ-1 do with Map[jx,jy,jz] do begin
        if initToFree then begin
          base := tkFree;
          for a in TAngle do faces[a] := tfFree;
        end else begin
          base := tkNone;
          for a in TAngle do faces[a] := tfNone;
        end;
        {if this tile is at border then make corresponding walls around it}
        if jx = 0       then faces[aLeft]   := tfWall;
        if jy = 0       then faces[aTop]    := tfWall;
        if jx = SizeX-1 then faces[aRight]  := tfWall;
        if jy = SizeY-1 then faces[aBottom] := tfWall;
        if jz = 0       then faces[aUp]     := tfWall;
        if jz = SizeZ-1 then faces[aDown]   := tfWall;
      end
end;

{-------------------------------------------------------------------------}

function DMap.IsSafe(tx,ty,tz: integer): boolean; {$IFDEF SUPPORTS_INLINE}inline;{$ENDIF}
begin
  if (tx >= 0)    and (ty >= 0)    and (tz >= 0)        and
     (tx < Sizex) and (ty < SizeY) and (tz < SizeZ)
  then
    result := true
  else
    result := false;
end;
function DMap.IsSafe(tx,ty: integer): boolean; {$IFDEF SUPPORTS_INLINE}inline;{$ENDIF}
begin
  if (tx >= 0)    and (ty >= 0)        and
     (tx < Sizex) and (ty < SizeY)
  then
    result := true
  else
    result := false;
end;

{--------------------------------------------------------------------}

Function DMap.MapSafe(tx,ty,tz: integer): BasicTile; {$IFDEF SUPPORTS_INLINE}inline;{$ENDIF}
begin
  if IsSafe(tx,ty,tz) then
    result := Map[tx,ty,tz]
  else
    result := InacceptibleTile; //this is a bit slower, but more bug-proof
end;
Function DMap.MapSafeBase(tx,ty,tz: integer): TTileKind; {$IFDEF SUPPORTS_INLINE}inline;{$ENDIF}
begin
  if IsSafe(tx,ty,tz) then
    result := Map[tx,ty,tz].base
  else
    result := tkInacceptible;
end;
Function DMap.MapSafeFace(tx,ty,tz: integer; face: TAngle): TTileFace; {$IFDEF SUPPORTS_INLINE}inline;{$ENDIF}
begin
  if IsSafe(tx,ty,tz) then
    result := Map[tx,ty,tz].faces[face]
  else
    result := tfInacceptible;
end;


{=============================================================================}

procedure LoadTiles; deprecated;
begin
  WriteLnLog('decodungeontiles','Load tiles started...');
  //dummy
end;

{----------------------------------------------------------------------------}

procedure DestroyTiles; deprecated;
begin
  //dummy
end;

end.

