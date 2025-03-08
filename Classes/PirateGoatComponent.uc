class PirateGoatComponent extends GGMutatorComponent;

var GGGoat gMe;
var GGMutator myMut;

var StaticMeshComponent hatMesh;
var SkeletalMeshComponent breadMesh;
var CursedCompass compass;

var SoundCue newTargetSound;
var ParticleSystem newTargetEffect;
var SoundCue goldDropSound;
var ParticleSystem goldDropEffect;

var float compassRadius;
var Actor mostDesiredItem;
var float targetRefreshRate;
var array<Actor> possibleTargets;
var bool shouldRefreshTargets;
var int totalGoldCount;
var bool isRightClicking;

var float sightRadius;
var float forceConeHalfAngle;

/**
 * See super.
 */
function AttachToPlayer( GGGoat goat, optional GGMutator owningMutator )
{
	super.AttachToPlayer(goat, owningMutator);

	if(mGoat != none)
	{
		gMe=goat;
		myMut=owningMutator;

		hatMesh.SetLightEnvironment( gMe.mesh.LightEnvironment );
		gMe.mesh.AttachComponentToSocket( hatMesh, 'hairSocket' );
		breadMesh.SetLightEnvironment( gMe.mesh.LightEnvironment );
		gMe.mesh.AttachComponentToSocket( breadMesh, 'ArmorHead' );

		compass=gMe.Spawn(class'CursedCompass', gMe,,,,, true);
	}
}

function KeyState( name newKey, EKeyState keyState, PlayerController PCOwner )
{
	local GGPlayerInputGame localInput;

	if(PCOwner != gMe.Controller)
		return;

	localInput = GGPlayerInputGame( PCOwner.PlayerInput );

	if( keyState == KS_Down )
	{
		if( localInput.IsKeyIsPressed( "GBA_FreeLook", string( newKey ) ) )
		{
			isRightClicking=true;
			if(gMe.mGrabbedItem != none && GetName(gMe.mGrabbedItem) == GetName(mostDesiredItem))
			{
				MakeItGold(gMe.mGrabbedItem);
			}
		}
		if( localInput.IsKeyIsPressed( "GBA_Baa", string( newKey ) ) )
		{
			//if right click
			if(isRightClicking)
			{
				GetNewTarget();
			}
		}
	}
	else if( keyState == KS_Up )
	{
		if( localInput.IsKeyIsPressed( "GBA_FreeLook", string( newKey ) ) )
		{
			isRightClicking=false;
		}
	}
}

simulated event TickMutatorComponent( float delta )
{
	super.TickMutatorComponent( delta );

	SetCompassPositionAndRotation();
	UpdateCharismAura();
}

function SetCompassPositionAndRotation()
{
	local vector pos, dir;
	local rotator newRot;
	local float r;

	r=gMe.GetCollisionRadius();
	newRot.Yaw = rotator( gMe.Mesh.GetBoneAxis( gMe.mStandUpBoneName, AXIS_X ) ).Yaw;
	dir=Normal(Vector(newRot));
	pos=gMe.Mesh.GetPosition() + (dir*2*r << rot(0, 8000, 0));

	compass.SetLocation(pos);
	compass.SetRotation(Rotator(dir));
}

function UpdateCharismAura()
{
	local GGNPc npc;
	local GGAIController aic;
	local vector runDirection, npcDirection;
	local float dotTreshold;

	if(gMe.mIsSprinting)
	{
		//Force panic the NPCs in front of you when you run
		runDirection = Normal( vector( gMe.Rotation ) );
		dotTreshold = Cos( forceConeHalfAngle );
		foreach gMe.CollidingActors( class'GGNPc', npc, sightRadius, gMe.Location )
		{
			npcDirection = Normal( npc.Location - gMe.Location );
			if( npcDirection dot runDirection > dotTreshold )
			{
				aic = GGAIController(npc.Controller);
				if(!aic.IsInState('StartPanic'))
				{
					aic.mLastSeenGoat=gMe;
					aic.Panic();
				}
			}
		}
	}
	else
	{
		// NPCs don't notice you when you walk
		foreach gMe.CollidingActors( class'GGNPc', npc, sightRadius, gMe.Location )
		{
			aic = GGAIController(npc.Controller);
			if(aic.mLastSeenGoat==gMe)
			{
				aic.mLastSeenGoat=none;
			}
		}
	}
}

function MakeItGold(Actor act)
{
	local vector spawnLocation;
	local rotator spawnRotation;
	local GoldCoin newGoldCoin;
	local GGKactor kact;
	local int goldCount, i;
	local float r, h;

	kact=GGKactor(act);
	if(kact == none)
	{
		return;
	}

	spawnLocation=kact.Location;
	gMe.PlaySound( goldDropSound );
	gMe.WorldInfo.MyEmitterPool.SpawnEmitter(goldDropEffect, spawnLocation, spawnRotation);

	kact.GetBoundingCylinder(r, h);
	goldCount=(sqrt(r*r+h*h)/10.f) + 1;
	kact.ShutDown();
	kact.Destroy();
	for(i=0 ; i<goldCount ; i++)
	{
		newGoldCoin = gMe.Spawn( class'GoldCoin',,, spawnLocation, spawnRotation );
		newGoldCoin.CollisionComponent.WakeRigidBody();
		spawnLocation.Z+=-5.f;
	}
	totalGoldCount += goldCount;
	if(totalGoldCount >= 100)
	{
		class'PirateMerchant'.static.UnlockPirateMerchant();
	}
}

function GetNewTarget()
{
	local Actor hitActor, newTarget;
	local float minDist, newDist;

	minDist = -1;
	foreach gMe.CollidingActors(class'Actor', hitActor, compassRadius, gMe.Location)
	{
		if(hitActor == gMe || GGNpcParrot(hitActor) != none || hitActor.bPendingDelete || hitActor.bHidden)
		{
			continue;
		}
		if(GGKactor(hitActor) != none || GGPawn(hitActor) != none || GGSVehicle(hitActor) != none || GGPickUpActor(hitActor) != none)
		{
			newDist=VSize(hitActor.Location-gMe.Location);
			if(minDist == -1 || newDist < minDist)
			{
				minDist=newDist;
				newTarget=hitActor;
			}
		}
	}
	if(newTarget != none)
	{
		newTarget.PlaySound( newTargetSound );
		newTarget.WorldInfo.MyEmitterPool.SpawnEmitter(newTargetEffect, newTarget.Location, rot(0, 0, 0), newTarget);
		mostDesiredItem=newTarget;
		shouldRefreshTargets=true;
		UpdateCurrentTarget();
	}
}

function UpdateCurrentTarget()
{
	local Actor newTarget, hitActor;
	local float minDist, newDist;

	if(shouldRefreshTargets)
	{
		GetPossibleTargets();
		shouldRefreshTargets=false;
	}

	if(mostDesiredItem == none)
	{
		if(gMe.IsTimerActive(NameOf(UpdateCurrentTarget), self))
		{
			gMe.ClearTimer(NameOf(UpdateCurrentTarget), self);
		}
		return;
	}

	minDist = -1;
	foreach possibleTargets(hitActor)
	{
		if(hitActor == gMe || hitActor.bPendingDelete || hitActor.bHidden)
		{
			shouldRefreshTargets=true;
			continue;
		}

		newDist=VSize(hitActor.Location-gMe.Location);
		if(minDist == -1 || newDist < minDist)
		{
			minDist=newDist;
			newTarget=hitActor;
		}
	}
	compass.SetTarget(newTarget);
	gMe.SetTimer(targetRefreshRate, false, NameOf(UpdateCurrentTarget), self);
}

function GetPossibleTargets()
{
	local string desiredItemName, actName;
	local Actor hitActor;

	possibleTargets.Length=0;
	if(mostDesiredItem == none)
	{
		return;
	}

	desiredItemName=GetName(mostDesiredItem);
	foreach gMe.AllActors(class'Actor', hitActor)
	{
		if(hitActor == gMe || hitActor.bPendingDelete || hitActor.bHidden)
		{
			continue;
		}
		if(GGKactor(hitActor) != none || GGPawn(hitActor) != none || GGSVehicle(hitActor) != none || GGPickUpActor(hitActor) != none)
		{
			actName=GetName(hitActor);
			if(desiredItemName == actName)
			{
				possibleTargets.AddItem(hitActor);
			}
		}
	}
}

function string GetName(Actor act)
{
	local GGScoreActorInterface scoreAct;
	local string actName;
	local array<string> subStr;
	local int spacePos;

	scoreAct=GGScoreActorInterface(act);
	if(scoreAct != none)
	{
		actName=scoreAct.GetActorName();
		if(GGCraftedFoodActor(act) != none)
		{
			spacePos=InStr(actName, " ");
			if(spacePos != -1)
			{
				actName=Right(actName, Len(actName) - spacePos - 1);
			}
		}
	}
	else
	{
		actName=string(act.name);
		ParseStringIntoArray(actName, subStr, "_", true);
		actName=subStr[0];
	}
	//Fix trophies detection
	if(GGCollectibleActor(act) != none && actName == "")
	{
		actName="Goat Trophie";
	}

	//myMut.WorldInfo.Game.Broadcast(myMut, "scoreAct=" $ scoreAct $ ", actName='" $ actName $ "'");
	return actName;
}

defaultproperties
{
	compassRadius=1000.f
	targetRefreshRate=1.f
	sightRadius=1000.0f
	forceConeHalfAngle=0.30

	Begin Object class=StaticMeshComponent Name=StaticMeshComp1
		StaticMesh=StaticMesh'Hats.Mesh.Turban'
	End Object
	hatMesh=StaticMeshComp1

	Begin Object class=SkeletalMeshComponent Name=SkeletalMeshComp1
		SkeletalMesh=SkeletalMesh'Goat_Zombie.Mesh.GoatBeard'
		PhysicsAsset=PhysicsAsset'Goat_Zombie.Mesh.GoatBeard_Physics'
			bHasPhysicsAssetInstance=true
			bCacheAnimSequenceNodes=false
			AlwaysLoadOnClient=true
			AlwaysLoadOnServer=true
			bOwnerNoSee=false
			CastShadow=true
			BlockRigidBody=true
			CollideActors=true
			bUpdateSkelWhenNotRendered=false
			bIgnoreControllersWhenNotRendered=true
			bUpdateKinematicBonesFromAnimation=true
			bCastDynamicShadow=true
			RBChannel=RBCC_Untitled3
			RBCollideWithChannels=(Untitled1=false,Untitled2=false,Untitled3=true,Vehicle=true)
			bOverrideAttachmentOwnerVisibility=true
			bAcceptsDynamicDecals=false
			TickGroup=TG_PreAsyncWork
			MinDistFactorForKinematicUpdate=0.0
			bChartDistanceFactor=true
			RBDominanceGroup=15
			bSyncActorLocationToRootRigidBody=true
			bNotifyRigidBodyCollision=true
			ScriptRigidBodyCollisionThreshold=1
	        BlockActors=TRUE
			AlwaysCheckCollision=TRUE
	End Object
	breadMesh=SkeletalMeshComp1

	newTargetSound=SoundCue'Goat_Sounds.Effect_slot_machine_wheel_stop_01_Cue'
	newTargetEffect=ParticleSystem'Zombie_Particles.Particles.Disintegration_ParticleSystem'
	goldDropSound=SoundCue'Zombie_Sounds.ZombieGameMode.Goat_PickUp_Particle_Sound_Cue'
	goldDropEffect=ParticleSystem'MMO_Effects.Effects.Effects_Levelup_01'
}