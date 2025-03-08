class PirateMerchantComponent extends GGMutatorComponent;

var GGGoat gMe;
var PirateMerchant myMut;

var int goldCoins;
var float collectRadius;
var SoundCue collectSound;
var AudioComponent collectAC;
var float buyRadius;

var name lastKey;
var float doubleKeypressTime;
var bool tooLate;

/**
 * See super.
 */
function AttachToPlayer( GGGoat goat, optional GGMutator owningMutator )
{
	super.AttachToPlayer(goat, owningMutator);

	if(mGoat != none)
	{
		gMe=goat;
		myMut=PirateMerchant(owningMutator);
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
		if(newKey == lastKey)
		{
			//myMut.WorldInfo.Game.Broadcast(myMut, "double keypress detected : " $ newKey);
			if(!tooLate)
			{
				if(localInput.IsKeyIsPressed("GBA_Baa", string( newKey )))
				{
					TryToBuyItem();
				}

				if(localInput.IsKeyIsPressed("RightMouseButton", string( newKey ))|| newKey == 'XboxTypeS_LeftTrigger')
				{
					CollectGold();
				}
				newKey = '';
			}
		}
		lastKey = newKey;

		//Detect if double keypress is valid
		if( gMe.IsTimerActive( NameOf( DoubleKeyPressFail ) ) )
		{
			gMe.ClearTimer( NameOf( DoubleKeyPressFail ) );
		}
		gMe.SetTimer( doubleKeypressTime * myMut.WorldInfo.Game.GameSpeed, false, NameOf( DoubleKeyPressFail ), self);
		tooLate=false;
	}
}

function DoubleKeyPressFail()
{
	tooLate=true;
}

function CollectGold()
{
	local GoldCoin gc;
	local bool goldFound;

	if(gMe.mIsRagdoll)
		return;

	goldFound=false;
	foreach myMut.CollidingActors(class'GoldCoin', gc, collectRadius + gMe.GetCollisionRadius(), gMe.Location)
	{
		goldCoins++;
		gc.Shutdown();
		gc.Destroy();
		goldFound=true;
	}

	if(goldFound)
	{
		if(collectAC == none || collectAC.IsPendingKill())
		{
			collectAC = gMe.CreateAudioComponent(collectSound, false);
		}

		if(!collectAC.IsPlaying())
		{
			collectAC.Play();
		}
		if(gMe.IsTimerActive(NameOf(StopCollectSound), self))
		{
			gMe.ClearTimer(NameOf(StopCollectSound), self);
		}
		gMe.SetTimer(1.0f, false, NameOf(StopCollectSound), self);
	}
}

function StopCollectSound()
{
	collectAC.Stop();
}

function TryToBuyItem()
{
	local GGNpc newNpc, merchant;
	local int index;
	local float minDist, dist;

	if(gMe.mIsRagdoll || goldCoins == 0)
		return;

	minDist = -1;
	foreach myMut.VisibleCollidingActors(class'GGNpc', newNpc, buyRadius + gMe.GetCollisionRadius(), gMe.Location)
	{
		if(newNpc.mIsRagdoll || GGAIController(newNpc.Controller) == none || GGNpcParrot(newNpc) != none)
			continue;

		dist = VSize(newNpc.Location - gMe.Location);
		if(minDist == -1 || dist < minDist)
		{
			minDist = dist;
			merchant = newNpc;
		}
	}

	if(merchant == none)
		return;

	index = myMut.GetMerchantIndex(merchant);
	if(index != INDEX_NONE)
	{
  		goldCoins = myMut.BuyItem(index, goldCoins);
	}
	else
	{
		myMut.MakeMerchant(merchant);
	}
}

simulated event PostRenderFor( PlayerController PC, Canvas c, vector cameraPosition, vector cameraDir )
{
	local vector locationToUse, speechScreenLocation;
	local bool isCloseEnough, isOnScreen, isVisible;
	local float cameraDistScale, cameraDist, cameraDistMax, cameraDistMin, speechScale;

	locationToUse = gMe.mesh.GetBoneLocation( myMut.mNameTagBoneName );

	if( IsZero( locationToUse ) )
	{
		locationToUse = gMe.Location;
	}

	if(gMe.mesh.DetailMode > class'WorldInfo'.static.GetWorldInfo().GetDetailMode() )
	{
		return;
	}

	cameraDist = VSize( cameraPosition - locationToUse );
	cameraDistMin = 500.0f;
	cameraDistMax = 4000.0f;
	cameraDistScale = myMut.GetScaleFromDistance( cameraDist, cameraDistMin, cameraDistMax );

	isCloseEnough = cameraDist < cameraDistMax;
	isOnScreen = cameraDir dot Normal( locationToUse - cameraPosition ) > 0.0f;

	if( isOnScreen && isCloseEnough )
	{
		// An extra check here as LastRenderTime is for all viewports (coop).
		isVisible = myMut.FastTrace( locationToUse + myMut.mSpeechBubbleOffset, cameraPosition );
	}

	c.Font = Font'UI_Fonts.InGameFont';
	c.PushDepthSortKey( int( cameraDist ) );

	if( isOnScreen && isCloseEnough && isVisible )
	{
		// The scale from distance must be at least 0.2 but the scale from time can go all the way to 0.
		speechScale = FMax( 0.2f, cameraDistScale );
		speechScreenLocation = c.Project( locationToUse + myMut.mSpeechBubbleOffset );
		myMut.RenderSpeechBubble( c, speechScreenLocation, speechScale, goldCoins);
		//WorldInfo.Game.Broadcast(self, "RenderSpeechBubble=" $ battlePlayers[i].gpawn);
	}

	c.PopDepthSortKey();
}

defaultproperties
{
	buyRadius=200.f
	collectRadius=200.f

	doubleKeypressTime=0.2f

	collectSound=SoundCue'Zombie_Sounds.Misc.CoinVolume_Swimming_Cue'
}