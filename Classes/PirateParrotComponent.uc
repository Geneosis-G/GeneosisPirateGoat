class PirateParrotComponent extends GGMutatorComponent;

var GGGoat gMe;
var GGMutator myMut;

var GGAIControllerParrot petController;

var bool isLickPressed;

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

		petController=gMe.Spawn(class'GGAIControllerParrot');
		petController.BePetOf(self);
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
		if( localInput.IsKeyIsPressed( "GBA_Baa", string( newKey ) ) )
		{
			if(isLickPressed)
			{
				CreateDiversion();
			}
		}

		if( localInput.IsKeyIsPressed( "GBA_AbilityBite", string( newKey ) ) )
		{
			isLickPressed=true;
		}
	}
	else if( keyState == KS_Up )
	{
		if( localInput.IsKeyIsPressed( "GBA_AbilityBite", string( newKey ) ) )
		{
			isLickPressed=false;
		}
	}
}

function CreateDiversion()
{
	//myMut.WorldInfo.Game.Broadcast(myMut, "Diversion!");
	petController.StartDiversion();
}

defaultproperties
{

}