using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ScrapsManager : SceneSingleton<ScrapsManager>, IPickable
{
	private List<Transform> scrapsList = new List<Transform>();

	[SerializeField]
	private float deSpawnRate = 75f;

	[SerializeField]
	private float countToStartDespawning = 40f;

	[SerializeField]
	private int scrapsCap = 250;

	private Transform playerTransform;

	[SerializeField]
	private RadarConfiguration radarConfiguration;

	private bool isCollecting = true;

	private bool isGettingPickable;

	private void Start()
	{
		playerTransform = SceneSingleton<PlayerManager>.Instance.GetPlayerTransform();
		StartCoroutine(ScrapRemover());
	}

	private void OnDisable()
	{
		StopAllCoroutines();
	}

	public void SetCollectingState(bool flag)
	{
		isCollecting = flag;
	}

	public Transform GetPickable(Vector2 pos, float range)
	{
		if (!isCollecting)
		{
			return null;
		}
		if (isGettingPickable)
		{
			return null;
		}
		isGettingPickable = true;
		Transform target = radarConfiguration.GetTarget(scrapsList, pos, range);
		scrapsList.Remove(target);
		isGettingPickable = false;
		return target;
	}

	public void ReturnPickable(Transform pickable)
	{
		ObjectSystem.ReScale(pickable, 1f);
		scrapsList.Add(pickable);
		MasterPool.ReturnToPoolTransform(pickable.gameObject, PrefabTypes.Object_Scrap, setActive: true);
	}

	public void CollectPickable(Transform pickable)
	{
		SceneSingleton<InGameEconomySystem>.Instance.AddScraps(1);
		Singleton<GameAchievementsManager>.Instance?.Add_ScrapsCollected();
		MasterPool.ReturnToPoolTransform(pickable.gameObject, PrefabTypes.Object_Scrap);
	}

	public void SpawnScraps(Vector2 pos, int scrapCount, List<Sprite> scrapSpritesList, bool ignoreTimeScale = false)
	{
		if (scrapCount == 0 || scrapsList.Count >= scrapsCap)
		{
			return;
		}
		foreach (Transform item in TweenController.ScatterItems(pos, scrapCount, PrefabTypes.Object_Scrap, (Transform newScrap) =>
		{
			scrapsList.Add(newScrap);
		}, ignoreTimeScale))
		{
			item.GetComponent<SpriteRenderer>().sprite = scrapSpritesList[Random.Range(0, scrapSpritesList.Count)];
		}
	}

	public void RotateAngle(Transform obj, float angle)
	{
		Vector3 zero = Vector3.zero;
		zero.z = angle;
		obj.eulerAngles = zero;
	}

	private IEnumerator ScrapRemover()
	{
		while (true)
		{
			yield return new WaitForSeconds(0.25f);
			if (!((float)scrapsList.Count > countToStartDespawning))
			{
				continue;
			}
			List<Transform> list = new List<Transform>();
			int num = 0;
			foreach (Transform scraps in scrapsList)
			{
				if (Vector2.Distance(scraps.position, playerTransform.position) > deSpawnRate)
				{
					list.Add(scraps);
					num++;
				}
				if (num > 5)
				{
					break;
				}
			}
			foreach (Transform item in list)
			{
				scrapsList.Remove(item);
				MasterPool.ReturnToPoolTransform(item.gameObject, PrefabTypes.Object_Scrap);
			}
		}
	}
}
