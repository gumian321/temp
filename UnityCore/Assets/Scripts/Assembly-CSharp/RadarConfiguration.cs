using System.Collections.Generic;
using UnityEngine;

public abstract class RadarConfiguration : ScriptableObject
{
	public bool priortizeShield = true;

	public List<Transform> GetShieldedTargets(List<Transform> targetsList)
	{
		List<Transform> list = new List<Transform>();
		foreach (Transform targets in targetsList)
		{
			if (Singleton<DetectionDataStore>.Instance.IsShieldLayer(targets.gameObject) && !targets.GetComponent<ShieldController>().IsShieldDestroyed())
			{
				list.Add(targets);
			}
		}
		if (list.Count == 0)
		{
			return targetsList;
		}
		return list;
	}

	public List<Transform> GetRangeTargets(List<Transform> targetsList, Vector2 radarPos, float range)
	{
		List<Transform> list = new List<Transform>();
		foreach (Transform targets in targetsList)
		{
			if (Vector2.Distance(targets.position, radarPos) < range)
			{
				list.Add(targets);
			}
		}
		return list;
	}

	protected List<Transform> FilterTargetList(List<Transform> targetsList, Vector2 radarPos = default(Vector2), float range = -1f)
	{
		List<Transform> list = new List<Transform>();
		foreach (Transform targets in targetsList)
		{
			if (!(targets == null) && targets.gameObject.activeInHierarchy)
			{
				list.Add(targets);
			}
		}
		if (list.Count == 0)
		{
			return list;
		}
		if (priortizeShield)
		{
			list = GetShieldedTargets(list);
		}
		if (range != -1f)
		{
			list = GetRangeTargets(list, radarPos, range);
		}
		return list;
	}

	public virtual Transform GetTarget(List<Transform> targetsList, Vector2 radarPos = default(Vector2), float range = -1f)
	{
		targetsList = FilterTargetList(targetsList, radarPos, range);
		Transform result = null;
		SetUpConfiguration();
		foreach (Transform targets in targetsList)
		{
			if (!(targets == null) && RunConfigurationTargetTest(targets, radarPos))
			{
				result = targets;
			}
		}
		return result;
	}

	public abstract void SetUpConfiguration();

	public abstract bool RunConfigurationTargetTest(Transform target, Vector2 radarPos);
}
