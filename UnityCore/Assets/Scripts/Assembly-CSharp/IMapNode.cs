using UnityEngine;

public interface IMapNode
{
	void ActivateNode();

	void DeactivateNode();

	void SetEvent(MapNodesManager manager, Vector3 pos);
}
