class CursedCompassNeedle extends Actor;

var Actor target;
var rotator randomDir;
var int rotOffset;
var float rotationInterpSpeed;

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

	SetTarget(none);
}

function SetTarget(Actor act)
{
	target=act;
	if(target != none)
	{
		if(IsTimerActive(NameOf(RandomizeDir)))
		{
			ClearTimer(NameOf(RandomizeDir));
		}
	}
	else
	{
		if(!IsTimerActive(NameOf(RandomizeDir)))
		{
			RandomizeDir();
		}
	}
}

event Tick( float deltaTime )
{
	super.Tick( deltaTime );

	if(target != none && (target.bPendingDelete || target.bHidden))
	{
		SetTarget(none);
	}

	UpdateRotation(deltaTime);
}

function UpdateRotation(float deltaTime)
{
	local rotator desiredRotation;
	local vector dir;

	desiredRotation=randomDir;
	if(target != none)
	{
		dir=target.Location - Location;
		dir.Z=0;
		desiredRotation=Rotator(Normal(dir));
	}
	desiredRotation.Yaw = desiredRotation.Yaw + rotOffset;

	SetRotation(RInterpTo( Rotation, desiredRotation, deltaTime, rotationInterpSpeed, false ));
}

function RandomizeDir()
{
	randomDir.Yaw=Rand(65536);
	SetTimer(RandRange(1, 3), false, NameOf(RandomizeDir));
}

DefaultProperties
{
	rotationInterpSpeed=10.f
	rotOffset=16384;

	bNoDelete=false
	bStatic=false
	bIgnoreBaseRotation=true
	mBlockCamera=false

	Begin Object class=StaticMeshComponent Name=StaticMeshComp0
		StaticMesh=StaticMesh'MMO_Props_01.Mesh.Weapons_Sword_01'
		Scale3D=(X=0.07f, Y=0.07f, Z=0.07f)
		Rotation=(Pitch=0, Yaw=0, Roll=-16384)
		Translation=(X=0.f, Y=6.f, Z=0.f)
	End Object
	Components.Add(StaticMeshComp0);

	Begin Object class=StaticMeshComponent Name=StaticMeshComp1
		StaticMesh=StaticMesh'Checkpoint.Mesh.Checkpoint_Arrow_01'
		Scale3D=(X=0.07f, Y=0.07f, Z=0.07f)
		Rotation=(Pitch=0, Yaw=-16384, Roll=0)
		Translation=(X=0.f, Y=0.f, Z=-10.f)
	End Object
	Components.Add(StaticMeshComp1);
}