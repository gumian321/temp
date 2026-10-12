using UnityEngine;

public abstract class FieldMapNode : MonoBehaviour, IMapNode
{
	protected MapNodesManager mapNodesManager;

	protected Vector3 eventPos;

	[Space]
	[Header("Feild Data")]
	[SerializeField]
	protected int maxFieldCount;

	[SerializeField]
	protected int minFieldCount;

	[Space]
	[SerializeField]
	protected int maxFieldArea;

	[SerializeField]
	protected int minFieldArea;

	[Space]
	[SerializeField]
	protected GameObject destroyedMapIcon;

	protected int fieldArea;

	public virtual void ActivateNode()
	{
		destroyedMapIcon.SetActive(value: false);
		SpawnField();
	}

	public virtual void DeactivateNode()
	{
		base.gameObject.SetActive(value: false);
	}

	public abstract void SpawnField();

	public void SetEvent(MapNodesManager manager, Vector3 pos)
	{
		mapNodesManager = manager;
		eventPos = pos;
	}

	public void FieldDestroyed()
	{
		if (mapNodesManager != null)
		{
			mapNodesManager.EventDestroyedAt(eventPos);
		}
		destroyedMapIcon.SetActive(value: true);
	}
}
