class CursedCompass extends Actor;

var CursedCompassNeedle mNeedle;

event PostBeginPlay()
{
	local StaticMeshComponent smc;

	Super.PostBeginPlay();

	SetPhysics(PHYS_None);
	SetCollisionType(COLLIDE_NoCollision);
	foreach AllOwnedComponents(class'StaticMeshComponent', smc)
	{
		smc.SetLightEnvironment( GGGoat(Owner).mesh.LightEnvironment );
		smc.SetActorCollision(false, false);
		smc.SetBlockRigidBody(false);
		smc.SetNotifyRigidBodyCollision(false);
	}

	mNeedle=Spawn(class'CursedCompassNeedle', Owner,, Location,,, true);
	mNeedle.SetBase(self);
}

function SetTarget(Actor act)
{
	mNeedle.SetTarget(act);
}

event Destroyed()
{
	mNeedle.Destroy();
	Super.Destroyed();
}

DefaultProperties
{
	bNoDelete=false
	bStatic=false
	bIgnoreBaseRotation=true
	mBlockCamera=false

	Begin Object class=StaticMeshComponent Name=StaticMeshComp0
		StaticMesh=StaticMesh'Props_01.Mesh.DartBoard01_fbx'
		Scale3D=(X=0.15f, Y=0.15f, Z=0.15f)
		Rotation=(Pitch=0, Yaw=0, Roll=-16384)
	End Object
	Components.Add(StaticMeshComp0);

	Begin Object class=StaticMeshComponent Name=StaticMeshComp1
		StaticMesh=StaticMesh'Goat_Props_01.Mesh.RingIndustry_Small_02'
		Scale3D=(X=0.012f, Y=0.012f, Z=0.012f)
	End Object
	Components.Add(StaticMeshComp1);

	Begin Object class=StaticMeshComponent Name=StaticMeshComp2
		StaticMesh=StaticMesh'Living_Room_01.Mesh.House_Ashtray'
		Materials(0)=Material'House_01.Materials.Window_Mat_01'
		Scale3D=(X=1.f, Y=1.f, Z=-0.2f)
		Translation=(X=0.f, Y=0.f, Z=1.f)
	End Object
	Components.Add(StaticMeshComp2);
}