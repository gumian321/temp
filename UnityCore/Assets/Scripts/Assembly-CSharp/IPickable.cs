using UnityEngine;

public interface IPickable
{
	void SetCollectingState(bool flag);

	Transform GetPickable(Vector2 pos, float range);

	void ReturnPickable(Transform pickable);

	void CollectPickable(Transform pickable);
}
