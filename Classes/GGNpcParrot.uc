class GGNpcParrot extends GGNpcZombie;

simulated event PostBeginPlay()
{
	Controller=Controller(Owner);//Hack to avoid spawning a useless zombie controller
	super.PostBeginPlay();
	Controller=none;
}

/**
 * Human readable name of this actor.
 */
function string GetActorName()
{
	return "Parrot";
}

/**
 * How much score this actor gives.
 */
function int GetScore()
{
	return 0;
}

// If hurt by player, move away
event TakeDamage( int damage, Controller instigatedBy, vector hitLocation, vector momentum, class< DamageType > damageType, optional TraceHitInfo hitInfo, optional Actor damageCauser )
{
	super.TakeDamage(damage, instigatedBy, hitLocation, momentum, damageType, hitInfo, damageCauser );

	if(class< GGDamageTypeAbility >(damageType) != none)
	{
		GGAIControllerParrot(Controller).AvoidActor(damageCauser);
	}
}

// Parrot can't ragdoll
function SetRagdoll(bool ragdoll);

// Grab cancel diversion
function OnGrabbed( Actor grabbedByActor )
{
	super.OnGrabbed(grabbedByActor);

	GGAIControllerParrot(Controller).StopDiversion();
}

// Negate some zombie functions
function EnableMindControlEffect(bool enable, controller inst);
function NPCDied(optional controller instigatedBy, optional class<DamageType> dmgType);
function TurnIntoIce(Controller instigatedBy);
function PlayZombieSound( optional bool chaseSound, optional bool attackSound );
function SetRandomVisuals();
function SetVisualsFromNormalNPC( GGNpc normalNpc );
function SetUpRagdolledLimbs();

DefaultProperties
{
	Begin Object name=WPawnSkeletalMeshComponent
		SkeletalMesh=SkeletalMesh'MMO_Dodo.Mesh.Dodo_01'
		AnimSets(0)=AnimSet'MMO_Dodo.Anim.Dodo_Anim_01'
		Materials(0)=none
		AnimTreeTemplate=AnimTree'goat.Anim.Goat_AnimTree'
		PhysicsAsset=PhysicsAsset'MMO_Dodo.Mesh.Dodo_Physics_01'
		Translation=(Z=-32)
		MaxDrawDistance=10000
	End Object
	mesh=WPawnSkeletalMeshComponent
	Components.Add(WPawnSkeletalMeshComponent)

	mDefaultAnimationInfo=(AnimationNames=(Idle),AnimationRate=1.0f,MovementSpeed=1200.0f,LoopAnimation=true)
	mPanicAtWallAnimationInfo=(AnimationNames=(Idle),AnimationRate=1.0f,MovementSpeed=1200.0f,LoopAnimation=true)
	mPanicAnimationInfo=(AnimationNames=(Run),AnimationRate=1.0f,MovementSpeed=1200.0f,LoopAnimation=true)
	mIdleAnimationInfo=(AnimationNames=(Idle),AnimationRate=1.0f,MovementSpeed=1200.0f,LoopAnimation=true)
	mRunAnimationInfo=(AnimationNames=(Run),AnimationRate=1.0f,MovementSpeed=1200.0f,LoopAnimation=true);
	mZombieRunningAnimNodeName="Run"

	mKnockedOverSounds.Empty
	mKnockedOverSounds.Add(SoundCue'MMO_NPC_SND.Cue.NPC_Dodo_Hurt_Cue')
	mAllKnockedOverSounds.Empty
	mAllKnockedOverSounds.Add(SoundCue'MMO_NPC_SND.Cue.NPC_Dodo_Hurt_Cue')
	mImpactSound=none
	mTurnSound=none
	mSetRandomVisuals=false
	mFastOrSlowMethod=EZFSM_ForceSlow
	mGroundSpeedForward=1200.f
	mFastZombieMoveSpeed=1200.f
	AirSpeed=1200.f
	mCanDie=false
	mDisabledLimbs.Empty

	SightRadius=0.0f
	HearingThreshold=0.0f

	mStandUpDelay=0.f

	mAttackRange=0.0f;
	mAttackMomentum=0.0f

	mTimesKnockedByGoatStayDownLimit=1000000.f
}