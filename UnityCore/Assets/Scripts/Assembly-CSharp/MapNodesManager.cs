using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class MapNodesManager : SceneSingleton<MapNodesManager>
{
	private Transform playerTransform;

	[SerializeField]
	private float xLimit;

	[SerializeField]
	private float yLimit;

	[SerializeField]
	private int distanceBetweenNodes;

	[Space]
	[SerializeField]
	private List<Vector3> destroyedEventsList = new List<Vector3>();

	private Dictionary<Vector3, IMapNode> mapNodes = new Dictionary<Vector3, IMapNode>();

	private Dictionary<Vector3, PrefabTypes> mapNodeType = new Dictionary<Vector3, PrefabTypes>();

	[SerializeField]
	private List<PrefabTypes> mapEventsList;

	[SerializeField]
	private int xOffset;

	[SerializeField]
	private int yOffset;

	[SerializeField]
	private bool emptyFirstLayerMapNodes;

	[SerializeField]
	private List<Vector3> emptyEventsPoss = new List<Vector3>();

	private DetectionDataStore detectionDataStore;

	[Space]
	[SerializeField]
	private List<PrefabTypes> easyEventsType;

	[SerializeField]
	private List<Vector3> easyEvents;

	private int eventsIndex = -1;

	private void OnTriggerExit2D(Collider2D other)
	{
		if (detectionDataStore.IsMapNodeLayer(other.gameObject))
		{
			UpdateEvents();
		}
	}

	public void Setup(MissionAIConfiguration aIConfiguration)
	{
		playerTransform = SceneSingleton<PlayerManager>.Instance.GetPlayerTransform();
		detectionDataStore = Singleton<DetectionDataStore>.Instance;
		distanceBetweenNodes = aIConfiguration.distanceBetweenNodes;
		xOffset = aIConfiguration.xOffset;
		yOffset = aIConfiguration.yOffset;
		emptyFirstLayerMapNodes = aIConfiguration.emptyFirstLayerMapNodes;
		mapEventsList = new List<PrefabTypes>(aIConfiguration.mapEventsList);
		xLimit = (float)distanceBetweenNodes + (float)distanceBetweenNodes * 0.5f;
		yLimit = (float)distanceBetweenNodes + (float)distanceBetweenNodes * 0.5f;
		emptyEventsPoss.Clear();
		emptyEventsPoss.Add(new Vector3((float)xOffset + (float)distanceBetweenNodes * 0.5f, (float)yOffset + (float)distanceBetweenNodes * 0.5f));
		emptyEventsPoss.Add(new Vector3((float)xOffset + (float)distanceBetweenNodes * 0.5f, (float)(-yOffset) + (float)(-distanceBetweenNodes) * 0.5f));
		emptyEventsPoss.Add(new Vector3((float)(-xOffset) + (float)(-distanceBetweenNodes) * 0.5f, (float)yOffset + (float)distanceBetweenNodes * 0.5f));
		emptyEventsPoss.Add(new Vector3((float)(-xOffset) + (float)(-distanceBetweenNodes) * 0.5f, (float)(-yOffset) + (float)(-distanceBetweenNodes) * 0.5f));
		easyEvents.Clear();
		easyEvents.AddRange(emptyEventsPoss);
		easyEvents.Add(new Vector3((float)distanceBetweenNodes + ((float)xOffset + (float)distanceBetweenNodes * 0.5f), (float)yOffset + (float)distanceBetweenNodes * 0.5f));
		easyEvents.Add(new Vector3((float)distanceBetweenNodes + ((float)xOffset + (float)distanceBetweenNodes * 0.5f), (float)(-yOffset) - (float)distanceBetweenNodes * 0.5f));
		UpdateEvents();
	}

	private void UpdateEvents()
	{
		if (xLimit == 0f)
		{
			return;
		}
		Vector3 playerGridedPos = GetPlayerGridedPos();
		List<Vector3> list = new List<Vector3>();
		for (float num = 0f - xLimit; num <= xLimit; num += (float)distanceBetweenNodes)
		{
			for (float num2 = 0f - yLimit; num2 <= yLimit; num2 += (float)distanceBetweenNodes)
			{
				Vector3 vector = new Vector3(num, num2, 0f) + playerGridedPos;
				if (vector.x > 0f)
				{
					vector.x += xOffset;
				}
				if (vector.x < 0f)
				{
					vector.x -= xOffset;
				}
				if (vector.y > 0f)
				{
					vector.y += yOffset;
				}
				if (vector.y < 0f)
				{
					vector.y -= yOffset;
				}
				if (!object.Equals(vector, Vector3.zero))
				{
					list.Add(vector);
				}
			}
		}
		List<Vector3> list2 = new List<Vector3>();
		foreach (Vector3 key in mapNodes.Keys)
		{
			if (!list.Contains(key))
			{
				list2.Add(key);
			}
		}
		foreach (Vector3 item in list2)
		{
			mapNodes[item].DeactivateNode();
			mapNodes.Remove(item);
		}
		StartCoroutine(SpawnEvents(list));
	}

	private IEnumerator SpawnEvents(List<Vector3> eventsPoss)
	{
		yield return new WaitForEndOfFrame();
		foreach (Vector3 item in eventsPoss)
		{
			if (!mapNodes.ContainsKey(item))
			{
				SpawnMapNode(item);
			}
		}
	}

	private void SpawnMapNode(Vector3 pos)
	{
		if (!mapNodes.ContainsKey(pos) && !destroyedEventsList.Contains(pos))
		{
			IMapNode component = MasterPool.GetPos(GetMapNodeType(pos), GetRandPos(pos)).GetComponent<IMapNode>();
			component.ActivateNode();
			component.SetEvent(this, pos);
			mapNodes.Add(pos, component);
		}
	}

	private Vector3 GetPlayerGridedPos()
	{
		float x = Mathf.RoundToInt(playerTransform.position.x / (float)distanceBetweenNodes) * distanceBetweenNodes;
		float y = playerTransform.position.y;
		y /= (float)distanceBetweenNodes;
		y = Mathf.RoundToInt(y) * distanceBetweenNodes;
		return new Vector3(x, y, 0f);
	}

	private PrefabTypes GetMapNodeType(Vector3 pos)
	{
		if (!mapNodeType.ContainsKey(pos))
		{
			PrefabTypes mapEvent = GetMapEvent(pos);
			mapNodeType.Add(pos, mapEvent);
			return mapEvent;
		}
		return mapNodeType[pos];
	}

	private PrefabTypes GetMapEvent(Vector3 pos)
	{
		if (easyEvents.Contains(pos))
		{
			return easyEventsType[Random.Range(0, easyEventsType.Count)];
		}
		if (emptyFirstLayerMapNodes && emptyEventsPoss.Contains(pos))
		{
			return PrefabTypes.MapEvents_Empty;
		}
		eventsIndex++;
		if (eventsIndex >= mapEventsList.Count)
		{
			eventsIndex = 0;
			mapEventsList = Randomizer.Randomize(mapEventsList);
		}
		return mapEventsList[eventsIndex];
	}

	public void EventDestroyedAt(Vector3 pos)
	{
		if (destroyedEventsList.Contains(pos))
		{
			Vector3 vector = pos;
			Debug.LogError("DestroyedEventsList already has: " + vector.ToString());
		}
		else
		{
			destroyedEventsList.Add(pos);
		}
	}

	private Vector2 GetRandPos(Vector2 pos)
	{
		return pos + Random.insideUnitCircle * 5f;
	}
}
