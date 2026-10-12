using UnityEngine;

public class EmptyMapNode : MonoBehaviour, IMapNode
{
	private MapNodesManager mapNodesManager;

	private Vector3 eventPos;

	public void ActivateNode()
	{
	}

	public void DeactivateNode()
	{
		MasterPool.ReturnToPoolTransform(base.gameObject, PrefabTypes.MapEvents_Empty);
	}

	public void SetEvent(MapNodesManager manager, Vector3 pos)
	{
		mapNodesManager = manager;
		eventPos = pos;
	}
}
