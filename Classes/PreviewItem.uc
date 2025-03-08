class PreviewItem extends GGPickUpActor
	placeable;

var GGNpc myNpc;
var PirateMerchant myMut;

function InitPreviewItem(StaticMeshComponent comp, GGNpc npc, PirateMerchant mut)
{
	local MaterialInterface mat;
	local int index;

	myNpc = npc;
	myMut = mut;

	SetStaticMesh(comp.StaticMesh, comp.Translation, comp.Rotation, comp.Scale3D * 0.1f);
	foreach comp.Materials(mat, index)
	{
		StaticMeshComponent.SetMaterial(index, mat);
	}
}

function PickedUp( GGGoat byGoat );

event Tick( float deltaTime )
{
	local vector locationToUse;

	super.Tick( deltaTime );

	locationToUse = myNpc.mesh.GetBoneLocation( myMut.mNameTagBoneName );
	if( IsZero( locationToUse ) )
	{
		locationToUse = myNpc.Location;
	}

	SetLocation(locationToUse + vect(0, 0, 30));
}

DefaultProperties
{
	Begin Object  name=StaticMeshComponent0
		StaticMesh=StaticMesh'goat.Mesh.Gloria_01'
		Rotation=(Pitch=16384,Yaw=0,Roll=0)
		Scale=4
	End Object

	mWobbleRotationSpeed=20000.0f
	CollisionComponent=none
	mBlockCamera=false
}