class PirateParrot extends GGMutator;

struct AnnoyedNPCInfo{
	var GGPawn parrot;
	var GGAIController contr;
	var float oldAttackRange;
	var ProtectInfo oldProtectInfo;
};

var float annoyRadius;
var array<AnnoyedNPCInfo> annoyedNPCs;
var array<AnnoyedNPCInfo> unannoyedNPCs;

//Annoy target NPC
function AnnoyNPC(GGNpc npc, GGPawn parrot)
{
	local AnnoyedNPCInfo aNPCInf;

	aNPCInf.parrot=parrot;
	aNPCInf.contr=GGAIController(npc.Controller);
	if(!npc.mIsRagdoll && aNPCInf.contr != none && GGAIControllerParrot(aNPCInf.contr) == none)
	{
		if(annoyedNPCs.Find('contr', aNPCInf.contr) == INDEX_NONE)
		{
			npc.PlaySoundFromAnimationInfoStruct( npc.mAngryAnimationInfo );
			aNPCInf.oldAttackRange=npc.mAttackRange;
			aNPCInf.oldProtectInfo=aNPCInf.contr.mCurrentlyProtecting;
			annoyedNPCs.AddItem(aNPCInf);
		}
	}
}

event Tick( float deltaTime )
{
	local AnnoyedNPCInfo aNPCInf;
	local int index;

	super.Tick( deltaTime );

	//Make annoyed NPCs run at the parrot
	unannoyedNPCs.Length=0;
	//gMe.WorldInfo.Game.Broadcast(gMe, "annoyedNPCs.Length=" $ annoyedNPCs.Length);
	foreach annoyedNPCs(aNPCInf)
	{
		ControlAnnoyedNPC(aNPCInf);
	}
	//Remove NPCs that are not annoyed any more
	foreach unannoyedNPCs(aNPCInf)
	{
		aNPCInf.contr.EndAttack();
		aNPCInf.contr.mPawnToAttack=none;
		aNPCInf.contr.mMyPawn.mAttackRange=aNPCInf.oldAttackRange;
		aNPCInf.contr.mAttackIntervalInfo.LastTimeStamp=0.f;
		aNPCInf.contr.mCurrentlyProtecting=aNPCInf.oldProtectInfo;
		index=annoyedNPCs.Find('contr', aNPCInf.contr);
		annoyedNPCs.Remove(index, 1);
	}
}

function ControlAnnoyedNPC(AnnoyedNPCInfo aNPCInf)
{
	local GGNpc annoyedNpc;
	local GGAIControllerParrot parrotCont;
	local GGAIController annoyedNpcController;
	local float distToParrot, r, r2;
	local vector dir;

	annoyedNpcController=aNPCInf.contr;
	annoyedNpc=annoyedNpcController.mMyPawn;
	dir=aNPCInf.parrot.Location - annoyedNpc.Location;
	dir.Z=0.f;
	distToParrot=VSize(dir);

	r=aNPCInf.parrot.GetCollisionRadius();
	r2=annoyedNpc.GetCollisionRadius();
	if(!annoyedNpc.mIsRagdoll && distToParrot < r+r2)
	{
		annoyedNpc.SetRagdoll(true);
	}

	parrotCont=GGAIControllerParrot(aNPCInf.parrot.Controller);
	if(annoyedNpc.mIsRagdoll || distToParrot > annoyRadius*2.f || parrotCont == none || !parrotCont.createDiversion)
	{
		unannoyedNPCs.AddItem(aNPCInf);
		return;
	}

	annoyedNpcController.mCurrentlyProtecting.ProtectItem=annoyedNpc;
	annoyedNpcController.mCurrentlyProtecting.ProtectRadius=annoyRadius*2.f;
	annoyedNpcController.mPawnToAttack=aNPCInf.parrot;
	annoyedNpc.mAttackRange=0.f;
	annoyedNpcController.mAttackIntervalInfo.LastTimeStamp=WorldInfo.TimeSeconds + 10.f;

	annoyedNpcController.UnlockDesiredRotation();
	annoyedNpc.SetDesiredRotation( rotator( Normal2D( aNPCInf.parrot.Location - annoyedNpc.Location ) ) );
	annoyedNpc.LockDesiredRotation( true );
	if(annoyedNpcController.mCurrentState != 'ProtectItem')
	{
		annoyedNpcController.GotoState('ProtectItem');
	}
	if(annoyedNpcController.IsTimerActive( 'DelayedGoToProtect' ))
	{
		annoyedNpcController.ClearTimer( 'DelayedGoToProtect' );
		annoyedNpcController.DelayedGoToProtect();
	}
}

DefaultProperties
{
	mMutatorComponentClass=class'PirateParrotComponent'

	annoyRadius=1000.f
}