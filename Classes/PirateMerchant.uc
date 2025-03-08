class PirateMerchant extends GGMutator
	config(Geneosis);

var config bool isPirateMerchantUnlocked;
var SoundCue buySound;

var bool postRenderSet;
var array<PirateMerchantComponent> mComponents;

var vector mSpeechBubbleOffset;
var float mSpeechBubbleLength;
var float mSpeechBubbleHeight;
var() name mNameTagBoneName;

struct MerchantInfo{
	var GGNpc npc;
	var PreviewItem preview;
	var int prize;
};
var array<MerchantInfo> merchants;

/**
 * if the mutator should be selectable in the Custom Game Menu.
 */
static function bool IsUnlocked( optional out array<AchievementDetails> out_CachedAchievements )
{
	return default.isPirateMerchantUnlocked;
}

function ModifyPlayer(Pawn Other)
{
	local GGGoat goat;
	local PirateMerchantComponent merchComp;

	super.ModifyPlayer( other );

	goat = GGGoat( other );
	if( goat != none )
	{
		merchComp=PirateMerchantComponent(GGGameInfo( class'WorldInfo'.static.GetWorldInfo().Game ).FindMutatorComponent(class'PirateMerchantComponent', goat.mCachedSlotNr));
		if(merchComp != none && mComponents.Find(merchComp) == INDEX_NONE)
		{
			mComponents.AddItem(merchComp);
			if( !WorldInfo.bStartup )
			{
				SetPostRenderFor();
			}
			else
			{
				SetTimer( 1.0f, false, NameOf( SetPostRenderFor ));
			}
		}
	}
}

/**
 * Unlock the mutator
 */
static function UnlockPirateMerchant()
{
	if(!default.isPirateMerchantUnlocked)
	{
		PostJuice( "Unlocked Pirate Merchant" );
		default.isPirateMerchantUnlocked=true;
		static.StaticSaveConfig();
	}
}

function static PostJuice( string text )
{
	local GGGameInfo GGGI;
	local GGPlayerControllerGame GGPCG;
	local GGHUD localHUD;

	GGGI = GGGameInfo( class'WorldInfo'.static.GetWorldInfo().Game );
	GGPCG = GGPlayerControllerGame( GGGI.GetALocalPlayerController() );

	localHUD = GGHUD( GGPCG.myHUD );

	if( localHUD != none && localHUD.mHUDMovie != none )
	{
		localHUD.mHUDMovie.AddJuice( text );
	}
}

/**
 * Sets post render for on all local player controllers.
 */
function SetPostRenderFor()
{
	local PlayerController PC;

	if(postRenderSet)
		return;

	postRenderSet=true;
	foreach WorldInfo.LocalPlayerControllers( class'PlayerController', PC )
	{
		if( GGHUD( PC.myHUD ) == none )
		{
			// OKAY! THIS IS REALLY LAZY! This assume all PC's is initialized at the same time
			SetTimer( 0.5f, false, NameOf( SetPostRenderFor ));
			postRenderSet=false;
			break;
		}
		GGHUD( PC.myHUD ).mPostRenderActorsToAdd.AddItem( self );
	}
}

simulated event PostRenderFor( PlayerController PC, Canvas c, vector cameraPosition, vector cameraDir )
{
	local PirateMerchantComponent PMC;
	local vector locationToUse, speechScreenLocation;
	local bool isCloseEnough, isOnScreen, isVisible;
	local float cameraDistScale, cameraDist, cameraDistMax, cameraDistMin, speechScale;
	local int i;
	//WorldInfo.Game.Broadcast(self, "PostRenderFor=" $ PC $ " Length=" $ battlePlayers.Length);
	for(i = 0 ; i<merchants.Length ; i++)
	{
		locationToUse = merchants[i].npc.mesh.GetBoneLocation( mNameTagBoneName );

		if( IsZero( locationToUse ) )
		{
			locationToUse = merchants[i].npc.Location;
		}

		if( merchants[i].npc.mesh.DetailMode > class'WorldInfo'.static.GetWorldInfo().GetDetailMode() )
		{
			return;
		}

		cameraDist = VSize( cameraPosition - locationToUse );
		cameraDistMin = 500.0f;
		cameraDistMax = 4000.0f;
		cameraDistScale = GetScaleFromDistance( cameraDist, cameraDistMin, cameraDistMax );

		isCloseEnough = cameraDist < cameraDistMax;
		isOnScreen = cameraDir dot Normal( locationToUse - cameraPosition ) > 0.0f;

		if( isOnScreen && isCloseEnough )
		{
			// An extra check here as LastRenderTime is for all viewports (coop).
			isVisible = FastTrace( locationToUse + mSpeechBubbleOffset, cameraPosition );
		}

		c.Font = Font'UI_Fonts.InGameFont';
		c.PushDepthSortKey( int( cameraDist ) );

		if( isOnScreen && isCloseEnough && isVisible )
		{
			// The scale from distance must be at least 0.2 but the scale from time can go all the way to 0.
			speechScale = FMax( 0.2f, cameraDistScale );
			speechScreenLocation = c.Project( locationToUse + mSpeechBubbleOffset );
			RenderSpeechBubble( c, speechScreenLocation, speechScale, merchants[i].prize);
			//WorldInfo.Game.Broadcast(self, "RenderSpeechBubble=" $ battlePlayers[i].gpawn);
		}

		c.PopDepthSortKey();
	}

	foreach mComponents(PMC)
	{
		PMC.PostRenderFor(PC, c, cameraPosition, cameraDir);
	}
}

function float GetScaleFromDistance( float cameraDist, float cameraDistMin, float cameraDistMax )
{
	return FClamp( 1.0f - ( ( FMax( cameraDist, cameraDistMin ) - cameraDistMin ) / ( cameraDistMax - cameraDistMin ) ), 0.0f, 1.0f );
}

function RenderSpeechBubble( Canvas c, vector screenLocation, float screenScale, int prize)
{
	local FontRenderInfo renderInfo;
	local float textScale, XL, YL, maxTextScale;
	local string message;

	renderInfo.bClipText = true;

	maxTextScale = 1.f;
	textScale = Lerp( 0.0f, maxTextScale, screenScale );

	message = prize @ "GC";
	c.DrawColor = MakeColor(255, 255, 255, 255);

	c.TextSize(message, XL, YL, textScale, textScale);
	c.SetPos(screenLocation.X, screenLocation.Y + ( mSpeechBubbleHeight * screenScale ) / 2.f);
	c.DrawAlignedShadowText(message,, textScale, textScale, renderInfo,,, 0.5f, 1.0f);
}

function int GetMerchantIndex(GGNpc npc)
{
	return merchants.Find('npc', npc);
}

function int BuyItem(int index, int money)
{
	local SoldKActor newItem;
	//WorldInfo.Game.Broadcast(self, "BuyItem(" $ index $ ", " $ money $ ")");
	if(money < merchants[index].prize)
		return money;

	newItem = Spawn(class'SoldKActor',,, merchants[index].npc.Location + Normal(vector(merchants[index].npc.Rotation)) * 100.f, merchants[index].npc.Rotation,, true);
	newItem.ChangeSkin(merchants[index].preview.StaticMeshComponent);

	merchants[index].npc.PlaySound(buySound);
	return money - merchants[index].prize;
}

function MakeMerchant(GGNpc npc)
{
	local MerchantInfo newItem;
	local GGKactor newKactor;
	//WorldInfo.Game.Broadcast(self, "MakeMerchant(" $ npc $ ")");
	newKactor = GetRandomKActor();
	if(newKactor == none)
		return;

	newItem.npc = npc;
	newItem.preview = Spawn(class'PreviewItem');
	newItem.preview.InitPreviewItem(newKactor.StaticMeshComponent, npc, self);
	newItem.prize = GetGoldPrize(newKactor);
	merchants.AddItem(newItem);
}

function GGKActor GetRandomKActor()
{
	local GGKactor hitKAct;
	local int N, r;

	//Count valid actors
	N=0;
	foreach AllActors( class'GGKactor', hitKAct )
	{
		N++;
	}

	//Get random actor
	r=Rand(N);
	N=0;
	foreach AllActors( class'GGKactor', hitKAct )
	{
		if(N == r)
		{
			return hitKAct;
		}

		N++;
	}

	return none;
}

function int GetGoldPrize(GGKactor kact)
{
	local float r, h;

	kact.GetBoundingCylinder(r, h);
	return (sqrt(r*r+h*h)/10.f) + 1;
}

event Tick( float deltaTime )
{
	super.Tick( deltaTime );

	ManageMerchants();
}

function ManageMerchants()
{
	local int i;

	//Clean fighter list and lock players during countdown
	for(i = 0 ; i<merchants.Length ; i = i)
	{
		if(merchants[i].npc == none || merchants[i].npc.bPendingDelete)
		{
			merchants[i].preview.Shutdown();
			merchants[i].preview.Destroy();
			merchants.Remove(i, 1);
		}
		else
		{
			i++;
		}
	}
}

DefaultProperties
{
	mMutatorComponentClass=class'PirateMerchantComponent'

	bPostRenderIfNotVisible=true

	mNameTagBoneName=Head

	mSpeechBubbleOffset=(X=0.0f,Y=0.0f,Z=80.0f)

	mSpeechBubbleLength=80.f;
	mSpeechBubbleHeight=30.f;

	buySound=SoundCue'Zombie_Goat_Sounds.HangGlideGoat.HangGlideGoat_Chute_Detach_Cue'
}