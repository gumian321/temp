using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class MasterPool : MonoBehaviour
{
	private readonly string PrefabsPath = "Prefabs";

	private static Transform MasterPoolTransform;

	private static Dictionary<PrefabTypes, GameObject> PrefabsReference = new Dictionary<PrefabTypes, GameObject>();

	private static Dictionary<PrefabTypes, List<GameObject>> PrefabsPools = new Dictionary<PrefabTypes, List<GameObject>>();

	private static Dictionary<PrefabTypes, Transform> PrefabsParents = new Dictionary<PrefabTypes, Transform>();

	private void Awake()
	{
		MasterPoolTransform = base.transform;
		SetPrefabsData();
	}

	private void SetPrefabsData()
	{
		PrefabsReference.Clear();
		PrefabsPools.Clear();
		PrefabsParents.Clear();
		List<GameObject> list = new List<GameObject>();
		list.AddRange(Resources.LoadAll<GameObject>(PrefabsPath));
		PrefabTypes[] array = Enum.GetValues(typeof(PrefabTypes)) as PrefabTypes[];
		for (int i = 0; i < array.Length; i++)
		{
			PrefabTypes key = array[i];
			foreach (GameObject item in list)
			{
				if (string.Equals(key.ToString(), item.name))
				{
					PrefabsReference.Add(key, item);
					PrefabsPools.Add(key, new List<GameObject>());
				}
			}
		}
	}

	private IEnumerator UpdateNames()
	{
		while (true)
		{
			yield return new WaitForSeconds(0.25f);
			foreach (PrefabTypes key in PrefabsParents.Keys)
			{
				UpdateNameAnalysis(key);
			}
		}
	}

	private void UpdateNameAnalysis(PrefabTypes type)
	{
		int num = 0;
		int num2 = 0;
		List<GameObject> list = new List<GameObject>(PrefabsPools[type]);
		PrefabsPools[type].Clear();
		for (int i = 0; i < list.Count; i++)
		{
			if (list[i] != null)
			{
				PrefabsPools[type].Add(list[i]);
			}
		}
		foreach (GameObject item in PrefabsPools[type])
		{
			if (item.gameObject.activeSelf)
			{
				num++;
			}
			else
			{
				num2++;
			}
		}
		PrefabsParents[type].name = type.ToString() + " (A:" + num + " ,D:" + num2 + ")";
	}

	public static GameObject GetPos(PrefabTypes type, Transform parent, Vector3 position = default(Vector3), Quaternion rotation = default(Quaternion))
	{
		GameObject obj = Get(type, parent);
		obj.transform.localPosition = position;
		obj.transform.localRotation = rotation;
		return obj;
	}

	public static GameObject GetPos(PrefabTypes type, Vector3 position = default(Vector3), Quaternion rotation = default(Quaternion))
	{
		GameObject obj = Get(type);
		obj.transform.position = position;
		obj.transform.rotation = rotation;
		return obj;
	}

	public static GameObject Get(PrefabTypes type, Transform parent = null)
	{
		if (!PrefabsPools.ContainsKey(type))
		{
			Debug.LogError("the PrefabType: (" + type.ToString() + ") don't have prefab in MasterPool, check if you have a prefabe with the same name in Resources/Prefabs");
			return null;
		}
		List<GameObject> list = new List<GameObject>(PrefabsPools[type]);
		PrefabsPools[type].Clear();
		for (int i = 0; i < list.Count; i++)
		{
			if (list[i] != null)
			{
				PrefabsPools[type].Add(list[i]);
			}
		}
		foreach (GameObject item in PrefabsPools[type])
		{
			if (!item.activeSelf)
			{
				item.SetActive(value: true);
				if (parent != null)
				{
					item.transform.SetParent(parent);
				}
				return item;
			}
		}
		GameObject gameObject = CreateNew(type, parent);
		PrefabsPools[type].Add(gameObject);
		return gameObject;
	}

	public static GameObject CreateNew(PrefabTypes type, Transform parent = null)
	{
		if (!PrefabsReference.ContainsKey(type))
		{
			Debug.LogError("the PrefabType: (" + type.ToString() + ") don't have prefab in MasterPool, check if you have a prefabe with the same name in Resources/Prefabs");
			return null;
		}
		GameObject obj = UnityEngine.Object.Instantiate(PrefabsReference[type]);
		SetToParent(obj, type, parent);
		return obj;
	}

	public static void ReturnToPoolTransform(GameObject usedObj, PrefabTypes type, bool setActive = false)
	{
		if (!PrefabsParents.ContainsKey(type))
		{
			Debug.LogError("PrefabsParents don't have type: " + type);
			return;
		}
		usedObj.transform.SetParent(PrefabsParents[type]);
		usedObj.SetActive(setActive);
	}

	private static void SetToParent(GameObject NewObj, PrefabTypes type, Transform parent = null)
	{
		if (!PrefabsParents.ContainsKey(type))
		{
			GameObject gameObject = new GameObject(type.ToString());
			gameObject.transform.SetParent(MasterPoolTransform);
			PrefabsParents.Add(type, gameObject.transform);
		}
		if (parent == null)
		{
			NewObj.transform.SetParent(PrefabsParents[type]);
			return;
		}
		NewObj.transform.SetParent(parent);
		NewObj.transform.position = parent.position;
	}
}
