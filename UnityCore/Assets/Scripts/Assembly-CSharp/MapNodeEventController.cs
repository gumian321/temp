using UnityEngine;

public abstract class MapNodeEventController : MonoBehaviour, IMapNode
{
	private MapNodesManager mapNodesManager;

	private Vector3 eventPos;

	public abstract void ActivateNode();

	public abstract void DeactivateNode();

	public virtual void DestroyEvent()
	{
		mapNodesManager.EventDestroyedAt(eventPos);
	}

	public void SetEvent(MapNodesManager manager, Vector3 pos)
	{
		mapNodesManager = manager;
		eventPos = pos;
	}
}
