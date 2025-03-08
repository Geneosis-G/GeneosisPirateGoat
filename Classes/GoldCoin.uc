class GoldCoin extends GGKActor
	placeable;
	
function int GetScore()
{
	return 1;
}

/**
 * Access to the in game name of this actor
 */
function string GetActorName()
{
	return "Gold Coin";
}

DefaultProperties
{
	Begin Object name=StaticMeshComponent0
		StaticMesh=StaticMesh'MMO_Pizza.Mesh.pizza'
		Materials(0)=Material'goat.Materials.GoldenGoat_Mat'
		Rotation=(Pitch=0, Yaw=0, Roll=-16384)
		Scale3D=(X=0.2f,Y=0.2f,Z=0.2f)
	End Object

	bNoDelete=false
	bStatic=false
}