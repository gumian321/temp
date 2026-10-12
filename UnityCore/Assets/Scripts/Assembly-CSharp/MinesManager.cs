using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class MinesManager : SceneSingleton<MinesManager>
{
	private Dictionary<float, List<MineController>> minesList = new Dictionary<float, List<MineController>>();

	[SerializeField]
	private float timeToDespawnMines = 7f;

	[SerializeField]
	private List<MinesList> mines;

	private void Start()
	{
		minesList = new Dictionary<float, List<MineController>>();
		StartCoroutine(MinesRemover());
	}

	private void Update()
	{
		mines.Clear();
		foreach (float key in minesList.Keys)
		{
			mines.Add(new MinesList(key, minesList[key]));
		}
	}

	public void AddMinesList(List<MineController> list)
	{
		float num = Time.time;
		if (minesList.ContainsKey(num))
		{
			num += Random.Range(0.001f, 0.1f);
		}
		minesList.Add(num, list);
	}

	public void RemoveMine(MineController mc)
	{
		foreach (float key in minesList.Keys)
		{
			if (minesList[key].Contains(mc))
			{
				minesList[key].Remove(mc);
			}
		}
	}

	private void OnDisable()
	{
		StopAllCoroutines();
	}

	private IEnumerator MinesRemover()
	{
		while (true)
		{
			yield return new WaitForSeconds(0.25f);
			Dictionary<float, List<MineController>> dictionary = new Dictionary<float, List<MineController>>();
			foreach (float key in minesList.Keys)
			{
				if (key + timeToDespawnMines < Time.time)
				{
					dictionary.Add(key, minesList[key]);
				}
			}
			foreach (float key2 in dictionary.Keys)
			{
				foreach (MineController item in minesList[key2])
				{
					MasterPool.ReturnToPoolTransform(item.gameObject, PrefabTypes.Object_Mine);
				}
				minesList.Remove(key2);
			}
		}
	}
}
