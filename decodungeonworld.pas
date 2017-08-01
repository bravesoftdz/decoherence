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

{ contains definitions for most abstract World entity }

unit decodungeonworld;

{$INCLUDE compilerconfig.inc}
interface

uses classes, fgl, CastleVectors,
  X3DNodes, CastleScene,
  DecoDungeonGenerator, DecoAbstractGenerator, DecoAbstractWorld3d,
  DecoDungeonTiles,
  DecoNav,
  DecoNavigation, DecoGlobal;


{list of "normal" tiles}
type TTilesList = specialize TFPGObjectList<DTileMap>;

//type TContainer = TTransformNode;//{$IFDEF UseSwitches}TSwitchNode{$ELSE}TTransformNode{$ENDIF}

type
  {Dungeon world builds and manages any indoor tiled location}
  DDungeonWorld = class(DAbstractWorldManaged)
  private
    {some ugly fix for coordinate uninitialized at the beginning of the world}
    const UninitializedCoordinate = -1000000;
  private
    px,py,pz,px0,py0,pz0: TIntCoordinate;
    {converts x,y,z to px,py,pz and returns true if changed
     *time-critical procedure}
    function UpdatePlayerCoordinates(x,y,z: float): boolean; {$IFDEF SUPPORTS_INLINE}inline;{$ENDIF}
    {Manages tiles (show/hide/trigger events) *time-critical procedure}
    Procedure ManageTiles; {$IFDEF SUPPORTS_INLINE}inline;{$ENDIF}
  public
    const myscale = 3;
  public
    {scale used to define a tile size. Usually 1 is man-height.
      CAUTION this scale must correspond to tiles model scale, otherwise it'll mess everything up}
    WorldScale: float;
  protected
    {neighbours array}
    Neighbours: TNeighboursMapArray;
    {sequential set of tiles, to be added to the world during "build"}
    Steps: TGeneratorStepsArray;
    {assembles MapTiles from Tiles 3d, adding transforms nodes according to generator steps}
    procedure BuildTransforms; override;
  public
    {all-purpose map of the current world, also contains minimap image}
    Map: DMap;

    {Detects if the current tile has been changed and launches manage_tiles
     position is CAMERA.position}
    Procedure Manage(position: TVector3Single); override;
    {Sorts tiles into chunks}
    //Procedure chunk_n_slice; override;
    {loads the world from a running generator}
    procedure Load(Generator: DAbstractGenerator); override;
    {loads the world from a saved file}
    procedure Load(URL: string); override;

    {loads word scenes into scene manager}
    Procedure Activate; override;

    constructor create; override;
    destructor destroy; override;
  public
    procedure BuildNav; override;
  end;


{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
implementation
uses sysutils, CastleFilesUtils, CastleLog;

procedure DDungeonWorld.ManageTiles; {$IFDEF SUPPORTS_INLINE}inline;{$ENDIF}
begin
  {$WARNING dummy}
end;

{----------------------------------------------------------------------------}

function DDungeonWorld.UpdatePlayerCoordinates(x,y,z: float): boolean; {$IFDEF SUPPORTS_INLINE}inline;{$ENDIF}
//var nx,ny,nz: TIntCoordinate;
begin
  {todo: may be optimized, at the moment we have here: 6 assignments,
   using nx,ny,nz we will have *MORE* work *IF* the tile has changed,
   but only 3 assignments otherwise}
  px0 := px;
  py0 := py;
  pz0 := pz;
  px := round( x/WorldScale);
  py := round(-y/WorldScale);     //pay attention: y-coordinate is inversed!
  pz := round(-(z-1)/WorldScale); //pay attention: z-coordinate is inversed and shifted!
  if px<0 then px :=0 else if px>map.sizex-1 then px := map.sizex-1;
  if py<0 then py :=0 else if py>map.sizey-1 then py := map.sizey-1;
  if pz<0 then pz :=0 else if pz>map.sizez-1 then pz := map.sizez-1;
  if (px<>px0) or (py<>py0) or (pz<>pz0) then {begin}
    {current tile has changed}
    result := true
  {end}
  else
    {current tile hasn't changed}
    result := false;
end;

{----------------------------------------------------------------------------}

procedure DDungeonWorld.Manage(position: TVector3Single);
begin
  if FirstRender then begin
    {$warning reset all tiles visibility here}
    LastRender := now;
    FirstRender := false;
  end;

  if UpdatePlayerCoordinates(position[0],position[1],position[2]) then
    ManageTiles;
end;

{----------------------------------------------------------------------------}

procedure DDungeonWorld.Load(Generator: DAbstractGenerator);
var DG: D3dDungeonGenerator;
begin
  DG := Generator as D3dDungeonGenerator;
  fSeed := drnd.Random32bit; //todo: maybe other algorithm
  Map := DG.ExportMap;
  Groups := DG.ExportGroups;
  Neighbours := DG.ExportNeighbours;
  WorldElementsURL := DG.ExportTiles;
  Steps := DG.ExportSteps;
  {$hint WorldScale must support different scales}
  {$Warning this is ugly}
  WorldScale := TileScale*MyScale;
  {yes, we load tiles twice in this case (once in the generator and now here),
   however, loading from generator is *not* a normal case
   (used mostly for testing in pre-alpha), so such redundancy will be ok
   normally World should load from a file and loading tiles will happen only once}
end;


{----------------------------------------------------------------------------}

procedure DDungeonWorld.Load(URL: string);
begin
  {$Warning dummy}
end;

{----------------------------------------------------------------------------}

procedure DDungeonWorld.Activate;
var
  StartX,StartY,StartZ: integer;
begin
  inherited;
  {$HINT navigation set_nav}
  Camera.SetView(Vector3(0,0,1),Vector3(0,1,0),Vector3(0,0,1),Vector3(0,0,1),true);

  StartX := 4;
  StartY := 4;
  StartZ := 0;
  {$Warning this is ugly}
  Camera.Position := Vector3((StartX)*WorldScale,-(StartY)*WorldScale,-(StartZ)*WorldScale+PlayerHeight*MyScale);
  Camera.MoveSpeed := 1*WorldScale;
  Camera.PreferredHeight := PlayerHeight*myscale;
  {$WARNING to be managed by the world}
end;

{----------------------------------------------------------------------------}

procedure DDungeonWorld.BuildTransforms;
var i: integer;
  Transform: TTransformNode;
begin
  WorldObjects := TTransformList.Create(false); //scene will take care of freeing
  for i := 0 to high(steps) do begin
    Transform := TTransformNode.Create;
    //put current tile into the world. Pay attention to y and z coordinate inversion.
    Transform.translation := Vector3(WorldScale*(Steps[i].x),-WorldScale*(Steps[i].y),-WorldScale*(steps[i].z));
    {$Warning this is ugly}
    Transform.scale := Vector3(MyScale,MyScale,MyScale);
    AddRecoursive(Transform,WorldElements3d[Steps[i].Tile]);
    WorldObjects.Add(Transform);
  end;
end;

{----------------------------------------------------------------------------}

constructor DDungeonWorld.create;
begin
  inherited;
  px := UninitializedCoordinate;
  py := UninitializedCoordinate;
  pz := UninitializedCoordinate;
  px0 := UninitializedCoordinate;        //we use px0 := px at the moment, so these are not needed, but it might change in future
  py0 := UninitializedCoordinate;
  pz0 := UninitializedCoordinate;
end;

{----------------------------------------------------------------------------}

procedure DDungeonWorld.BuildNav;
var ix,iy,iz: TIntCoordinate;
    tmpNav: DNavPt;
begin
  if Nav<>nil then begin
    WriteLnLog('DDungeonWorld.BuildNav','WARNING: Nav is not nil! Freeing');
    FreeAndNil(Nav);
  end;
  Nav := TNavList.create;

  for iz := 0 to Map.SizeZ-1 do
    for ix := 0 to Map.SizeX-1 do
      for iy := 0 to Map.SizeZ-1 do if isPassable(Map.Map[ix,iy,iz].base) then begin
        tmpNav.x := ix;
        tmpNav.y := iy;
        tmpNav.z := iz;
        Nav.Add(tmpNav);
      end;

  WriteLnLog('DDungeonWorld.BuildNav','Navigation Graph created, nodes: '+inttostr(Nav.Count));
end;

{----------------------------------------------------------------------------}

destructor DDungeonWorld.Destroy;
begin
  {$hint freeandnil(window.scenemanager)?}
  
  //free basic map parameters
  FreeAndNil(Map);
  FreeAndNil(Nav);
  FreeAndNil(Groups);
  FreeNeighboursMap(Neighbours);

  inherited;
end;

end.

