class GGAIControllerParrot extends GGAIControllerPassiveGoat;

var GGNpcParrot parrot;
var GGGoat petOwner;
var PirateParrot petOwnerMut;
var PirateParrotComponent petOwnerComp;
var float maxDistToOwner;

var bool isArrived;
var float mDestinationOffset;
var kActorSpawnable destActor;
var vector targetPoint;
var float flightHeight;
var bool createDiversion;

var bool isAvoiding;
var float avoidTime;
var float stuckTime;

/**
 * Cache the NPC and mOriginalPosition
 */
event Possess(Pawn inPawn, bool bVehicleTransition)
{
	local ProtectInfo destination;

	super.Possess(inPawn, bVehicleTransition);

	if(mMyPawn == none)
		return;
	//WorldInfo.Game.Broadcast(self, "#" $ self $ " Possess " $ mMyPawn);
	mMyPawn.mProtectItems.Length=0;
	if(destActor == none || destActor.bPendingDelete)
	{
		destActor = Spawn(class'kActorSpawnable', mMyPawn,,,,,true);
		destActor.SetHidden(true);
		destActor.SetPhysics(PHYS_None);
		destActor.CollisionComponent=none;
	}
	//WorldInfo.Game.Broadcast(self, mMyPawn $ " destActor=" $ destActor);
	destActor.SetLocation(mMyPawn.Location);
	destination.ProtectItem = mMyPawn;
	destination.ProtectRadius = 1000000.f;
	mMyPawn.mProtectItems.AddItem(destination);
	//WorldInfo.Game.Broadcast(self, mMyPawn $ " mMyPawn.mProtectItems[0].ProtectItem=" $ mMyPawn.mProtectItems[0].ProtectItem);
	StandUp();
}

event UnPossess()
{
	//WorldInfo.Game.Broadcast(self, "#" $ self $ " Unpossess " $ mMyPawn);
	if(destActor != none)
	{
		destActor.ShutDown();
		destActor.Destroy();
	}

	super.UnPossess();
	mMyPawn=none;
}

function BePetOf(PirateParrotComponent newPetOwnerComp)
{
	local Controller oldController;
	local vector spawnLoc;

	petOwnerComp=newPetOwnerComp;
	petOwner=newPetOwnerComp.gMe;
	petOwnerMut=PirateParrot(newPetOwnerComp.myMut);
	if(parrot == none || parrot.bPendingDelete)
	{
		spawnLoc=petOwner.Location;
		spawnLoc.Z+=flightHeight;
		parrot=Spawn(class'GGNpcParrot', self,, spawnLoc,,, true);
		//WorldInfo.Game.Broadcast(self, "#" $ self $ " new parrot created " $ parrot);
	}
	oldController=parrot.Controller;
	if(oldController == self)
	{
		return;
	}
	//myMut.WorldInfo.Game.Broadcast(myMut, "oldController=" $ oldController);
	if(oldController != none)
	{
		oldController.Unpossess();
		if(PlayerController(oldController) == none)
		{
			oldController.Destroy();
		}
	}
	Possess(parrot, false);
}

event Tick( float deltaTime )
{
	//local float speed, max_speed;

	Super.Tick( deltaTime );

	//WorldInfo.Game.Broadcast(self, mMyPawn $ " state=" $ mCurrentState $ "/getState=" $ GetStateName());

	if(petOwner == none)
	{
		return;
	}

	if(mMyPawn == none || mMyPawn.bPendingDelete)
	{
		BePetOf(petOwnerComp);
	}

	if(mMyPawn.Physics != PHYS_Flying)
	{
		mMyPawn.SetPhysics(PHYS_Flying);
	}

	if(!mMyPawn.mIsRagdoll)
	{
		//Fix NPC with no collisions
		if(mMyPawn.CollisionComponent == none)
		{
			mMyPawn.CollisionComponent = mMyPawn.Mesh;
		}

		//Fix NPC rotation
		UnlockDesiredRotation();

		//Fix random movement state
		if(mCurrentState == '')
		{
			//WorldInfo.Game.Broadcast(self, mMyPawn $ " no state detected");
			GoToState('FollowOwner');
		}

		//Try to avoid for 1s max
		if(isAvoiding)
		{
			avoidTime+=deltaTime;
			if(avoidTime >= 1.f)
			{
				StopAvoiding();
			}
		}

		CheckDistToOwner();
		UpdateFollowOwner();
		//Force speed reduction when close to target
		/*speed=VSize(mMyPawn.Velocity);
		max_speed=VSize(mMyPawn.Location-destActor.Location) * 2.f;
		if(speed > max_speed)
		{
			mMyPawn.Velocity.X*=max_speed/speed;
			mMyPawn.Velocity.Y*=max_speed/speed;
			mMyPawn.Velocity.Z*=max_speed/speed;
		}*/
		//WorldInfo.Game.Broadcast(self, mMyPawn $ "(" $ mMyPawn.Physics $ ")");
		//WorldInfo.Game.Broadcast(self, mMyPawn $ "(" $ mMyPawn.mCurrentAnimationInfo.AnimationNames[0] $ ")");
		//WorldInfo.Game.Broadcast(self, mMyPawn $ "(" $ mCurrentState $ ")");
		SimulateMovement();
		if(IsZero(mMyPawn.Velocity))
		{
			if(isArrived && !mMyPawn.isCurrentAnimationInfoStruct( mMyPawn.mDefaultAnimationInfo ) )
			{
				mMyPawn.SetAnimationInfoStruct( mMyPawn.mDefaultAnimationInfo );
			}
			// May be stuck, try to avoid
			if(VSize(destActor.Location - mMyPawn.Location) > mDestinationOffset * 1.5f)
			{
				stuckTime += deltaTime;
				if(stuckTime >= 1.f)
				{
					AvoidActor(destActor);
					stuckTime=0.f;
				}
			}
			else
			{
				stuckTime=0.f;
			}
		}
		else
		{
			stuckTime=0.f;
			if( !mMyPawn.isCurrentAnimationInfoStruct( mMyPawn.mRunAnimationInfo ) )
			{
				mMyPawn.SetAnimationInfoStruct( mMyPawn.mRunAnimationInfo );
			}
		}
	}
	else
	{
		mMyPawn.StandUp();
	}
}
// Haxx to make the parrot actually move... It's not moving correctly since the Payday update ?!?
function SimulateMovement()
{
	local float speed;

	speed=FMin(VSize(mMyPawn.Location-destActor.Location) * 2.f, mMyPawn.mGroundSpeedForward);

	mMyPawn.Velocity=isArrived?vect(0, 0, 0):Normal(destActor.Location - mMyPawn.Location) * speed;
}

function UpdateFollowOwner()
{
	local vector dir, dest;
	local rotator newRot;
	local float r, dist;

	if(createDiversion || isAvoiding)
	{
		dest=targetPoint;
		dist=VSize(mMyPawn.Location-dest);
	}
	else
	{
		r=petOwner.GetCollisionRadius();
		newRot.Yaw = rotator( petOwner.Mesh.GetBoneAxis( petOwner.mStandUpBoneName, AXIS_X ) ).Yaw;
		dir=Normal(Vector(newRot));
		dest=petOwner.mesh.GetPosition() + (dir*(3*r + mMyPawn.GetCollisionRadius()) << rot(0, -24000, 0));
		dest.Z+=petOwner.GetCollisionHeight() + flightHeight;
		dist=VSize2D(mMyPawn.Location-dest);
	}

	if(dist < mDestinationOffset)
	{
		dest=mMyPawn.Location;
		if(!isArrived)
		{
			isArrived=true;//WorldInfo.Game.Broadcast(self, "#" $  mMyPawn $ " isArrived=" $ isArrived);
			mMyPawn.ZeroMovementVariables();
		}
	}
	else if(dist > mDestinationOffset * 1.5f)
	{
		if(isArrived)
		{
			isArrived=false;//WorldInfo.Game.Broadcast(self, "#" $  mMyPawn $ " isArrived=" $ isArrived);
		}
	}

	//DrawDebugLine (mMyPawn.Location, dest, 0, 0, 0,);
	//WorldInfo.Game.Broadcast(self, " dest=" $ dest $ " diversion=" $ createDiversion $ " avoid=" $ isAvoiding);
	destActor.SetLocation(dest);//DrawDebugSphere(destActor.Location, 10, 8, 0, 0, 255);
	if(!isArrived)
	{
		Pawn.SetDesiredRotation( rotator( Normal2D( destActor.Location - Pawn.Location ) ) );
	}
	mMyPawn.LockDesiredRotation( true );
}

//If the player move too far away, stop diversion and/or start passing through walls
function CheckDistToOwner()
{
	local vector dist, pos;

	dist=mMyPawn.Location - petOwner.Location;
	if(VSize(dist) > maxDistToOwner)
	{
		StopDiversion();
		StopAvoiding();
		pos=petOwner.Location + (Normal(dist) * maxDistToOwner * 9.f/10.f);
		mMyPawn.SetLocation(pos);//WorldInfo.Game.Broadcast(self, mMyPawn $ " too far: Teleport");
	}
}

function StartDiversion()
{
	StopDiversion();
	ApplyDiversion(true);

	createDiversion=true;//WorldInfo.Game.Broadcast(self, mMyPawn $ " start Diversion");
}

function StopDiversion()
{
	if(IsTimerActive(NameOf(ApplyDiversion)))
	{
		ClearTimer(NameOf(ApplyDiversion));
	}
	createDiversion=false;
}

function bool ShouldIgnoreActor(Actor act)
{
	return act == none
		|| Volume(act) != none
		|| GGApexDestructibleActor(act) != none;
}

function AvoidActor(Actor act)
{
	local vector dir;

	if(isAvoiding || ShouldIgnoreActor(act))
	{
		return;
	}

	dir=Normal(mMyPawn.Location - act.Location);
	dir.Z+=1.f;
	targetPoint=mMyPawn.Location + (dir * 1000.f);
	isAvoiding=true;//WorldInfo.Game.Broadcast(self, mMyPawn $ " start Avoiding " $ act);
}

function StopAvoiding()
{
	avoidTime=0.f;
	isAvoiding=false;
}

//Periodically do the diversion effects
function ApplyDiversion(optional bool isFirst)
{
	RandomizeFlight(isFirst);
	AnnoyNPCs();
	//WorldInfo.Game.Broadcast(self, " sound=" $ mMyPawn.mKnockedOverSounds[0]);
	mMyPawn.PlaySound(mMyPawn.mKnockedOverSounds[0],,,, mMyPawn.Location);
	SetTimer(RandRange(0.5f, 2.f), false, NameOf(ApplyDiversion));
}

//Gives a new random direction away from the player
function RandomizeFlight(bool isFirst)
{
	local rotator angle;
	local vector dir, dest;
	local Actor hitActor;
	local vector hitLocation, hitNormal, traceEnd, traceStart;

	dir=isFirst?vector(petOwner.Rotation):mMyPawn.Location - petOwner.Location;
	dir.Z=0;
	angle=rotator(Normal(dir));
	angle.Yaw+=RandRange(-4000.f, 4000.f);
	dest=mMyPawn.Location + (Normal(Vector(angle)) * 1000.f);
	traceStart=dest;
	traceEnd=dest;
	traceStart.Z=10000.f;
	traceEnd.Z=-3000;

	hitActor = Trace( hitLocation, hitNormal, traceEnd, traceStart, true, mMyPawn.GetCollisionExtent() );
	if( hitActor == none )
	{
		hitLocation = traceEnd;
	}
	hitLocation.Z+=flightHeight;
	targetPoint=hitLocation;
}

//Annoy nearby people so they run after the parrot
function AnnoyNPCs()
{
	local GGNpc npc;

	foreach CollidingActors( class'GGNpc', npc, petOwnerMut.annoyRadius, mMyPawn.Location )
	{
		petOwnerMut.AnnoyNPC(npc, mMyPawn);
	}
}

/**
 * Called when a collision between two actors occur
 */
function OnCollision( Actor actor0, Actor actor1 )
{
	//Try to avoid dead ends during flight
	if(actor0 == mMyPawn && actor1 != petOwner)
	{
		if(GGApexDestructibleActor(actor1) != none)
		{
			actor1.TakeDamage(1000000, self, mMyPawn.Location, mMyPawn.Velocity, class'GGDamageTypeCollision',, mMyPawn);
		}
		AvoidActor(actor1);
	}
}

function StartProtectingItem( ProtectInfo protectInformation, GGPawn threat );

/**
 * Attacks mPawnToAttack using mMyPawn.mAttackMomentum
 * called when our pawn needs to protect and item from a given pawn
 */
function AttackPawn();

state FollowOwner extends MasterState
{
Begin:
	//WorldInfo.Game.Broadcast(self, mMyPawn $ " FollowOwner");
	mMyPawn.ZeroMovementVariables();
	while(mMyPawn != none && destActor != none)
	{
		if(!isArrived)
		{
			MoveToward (destActor);
		}
		else
		{
			MoveToward (mMyPawn,, mDestinationOffset);// Ugly hack to prevent "runnaway loop" error
		}
	}
	mMyPawn.ZeroMovementVariables();
}

/**
 * Helper function to determine if the last seen goat is near a given protect item
 * @param  protectInformation - The protectInfo to check against
 * @return true / false depending on if the goat is near or not
 */
function bool GoatNearProtectItem( ProtectInfo protectInformation )
{
	//WorldInfo.Game.Broadcast(self, mMyPawn $ " mProtectItems[0]=" $ mMyPawn.mProtectItems[0].ProtectItem);
	//WorldInfo.Game.Broadcast(self, mMyPawn $ " ProtectItem=" $ protectInformation.ProtectItem);

	if( protectInformation.ProtectItem == None || mVisibleEnemies.Length == 0 )
	{
		return false;
	}
	else
	{
		return true;
	}
}

/**
 * Helper function to determine if our pawn is close to a protect item, called when we arrive at a pathnode
 * @param currentlyAtNode - The pathNode our pawn just arrived at
 * @param out_ProctectInformation - The info about the protect item we are near if any
 * @return true / false depending on if the pawn is near or not
 */
function bool NearProtectItem( PathNode currentlyAtNode, out ProtectInfo out_ProctectInformation )
{
	out_ProctectInformation=mMyPawn.mProtectItems[0];
	return true;
}

function bool IsValidEnemy( Pawn newEnemy )
{
	return false;
}

/**
 * Helper functioner for determining if the goat is in range of uur sightradius
 * if other is not specified mLastSeenGoat is checked against
 */
function bool PawnInRange( optional Pawn other )
{
	if(mMyPawn.mIsRagdoll)
	{
		return false;
	}
	else
	{
		return super.PawnInRange(other);
	}
}

function bool CanReturnToOrginalPosition()
{
	return false;
}

/**
 * Go back to where the position we spawned on
 */
function ReturnToOriginalPosition()
{
	GotoState( 'FollowOwner' );
}

/**
 * Helper function for when we see the goat to determine if it is carrying a scary object
 */
function bool GoatCarryingDangerItem()
{
	return false;
}

function bool PawnUsesScriptedRoute()
{
	return false;
}

//--------------------------------------------------------------//
//			GGNotificationInterface								//
//--------------------------------------------------------------//

/**
 * Called when an actor begins to ragdoll
 */
function OnRagdoll( Actor ragdolledActor, bool isRagdoll )
{
	if(ragdolledActor == mMyPawn)
	{
		//The parrot can't ragdoll
		if(isRagdoll)
		{
			mMyPawn.StandUp();
		}
	}
}

DefaultProperties
{
	mDestinationOffset=40.0f
	maxDistToOwner=5000.f
	flightHeight=50.f

	mIgnoreGoatMaus=true

	bIsPlayer=true

	mAttackIntervalInfo=(Min=1.f,Max=1.f,CurrentInterval=1.f)
	mCheckProtItemsThreatIntervalInfo=(Min=1.f,Max=1.f,CurrentInterval=1.f)
	mVisibilityCheckIntervalInfo=(Min=1.f,Max=1.f,CurrentInterval=1.f)
}