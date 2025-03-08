class SoldKActor extends GGKActor
placeable;

function ChangeSkin(StaticMeshComponent comp)
{
	local MaterialInterface mat;
	local int index;

	SetStaticMesh(comp.StaticMesh, comp.Translation, comp.Rotation, comp.Scale3D * 10.f);
	foreach comp.Materials(mat, index)
	{
		StaticMeshComponent.SetMaterial(index, mat);
	}
	CollisionComponent.WakeRigidBody();
}

DefaultProperties
{
	bStatic=false
	bNoDelete=false
}