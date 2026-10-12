using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class PlayerDecorationManager : Singleton<PlayerDecorationManager>
{
	[SerializeField]
	private Transform decorationParent;

	[SerializeField]
	private List<DecorationData> Decorations;

	private List<Vector3> Directions = new List<Vector3>
	{
		Vector3.left,
		Vector3.right,
		Vector3.up,
		Vector3.down
	};

	public void UpdateShipDecorations(List<Vector3> coresPoss)
	{
		StartCoroutine(IUpdateShipDecorations(coresPoss));
	}

	private IEnumerator IUpdateShipDecorations(List<Vector3> coresPoss)
	{
		yield return new WaitForEndOfFrame();
		Dictionary<Vector3, List<Vector3>> emptySpots = GetEmptySpots(coresPoss);
		List<Vector3> list = new List<Vector3>();
		foreach (DecorationData decoration in Decorations)
		{
			if (coresPoss.Contains(decoration.pos))
			{
				list.Add(decoration.pos);
			}
			if (!HasNeighboringCore(decoration.pos, coresPoss))
			{
				list.Add(decoration.pos);
			}
		}
		foreach (Vector3 item in list)
		{
			DecorationData decorationAt = GetDecorationAt(item);
			if (decorationAt.type == PrefabTypes.Decoration_Engine)
			{
				SceneSingleton<PlayerMovement>.Instance.RemoveEngine(decorationAt.obj, GetEngineDirection(decorationAt.obj));
			}
			decorationAt.obj.SetActive(value: false);
			Decorations.Remove(decorationAt);
		}
		foreach (Vector3 key in emptySpots.Keys)
		{
			switch (emptySpots[key].Count)
			{
			case 4:
				SpawnDec4Sides(key, emptySpots[key]);
				break;
			case 3:
				SpawnDec3Sides(key, emptySpots[key]);
				break;
			case 2:
				SpawnDec2Sides(key, emptySpots[key]);
				break;
			case 1:
				SpawnDec1Sides(key, emptySpots[key]);
				break;
			}
		}
	}

	private bool HasNeighboringCore(Vector3 decorationPos, List<Vector3> cores)
	{
		foreach (Vector3 direction in Directions)
		{
			Vector3 item = decorationPos + direction;
			if (cores.Contains(item))
			{
				return true;
			}
		}
		return false;
	}

	private Dictionary<Vector3, List<Vector3>> GetEmptySpots(List<Vector3> cores)
	{
		Dictionary<Vector3, List<Vector3>> dictionary = new Dictionary<Vector3, List<Vector3>>();
		foreach (Vector3 core in cores)
		{
			foreach (Vector3 direction in Directions)
			{
				Vector3 vector = core + direction;
				if (!cores.Contains(vector))
				{
					if (!dictionary.ContainsKey(vector))
					{
						dictionary.Add(vector, new List<Vector3>());
					}
					dictionary[vector].Add(direction);
				}
			}
		}
		return dictionary;
	}

	private void SpawnDec4Sides(Vector3 pos, List<Vector3> neighbors)
	{
		DecorationData decorationAt = GetDecorationAt(pos);
		if (decorationAt == null)
		{
			decorationAt = new DecorationData();
			decorationAt.pos = pos;
			decorationAt.type = PrefabTypes.Decoration_4Sides;
			decorationAt.obj = MasterPool.GetPos(PrefabTypes.Decoration_4Sides, decorationParent, pos);
			decorationAt.neighborCores = new List<Vector3>(neighbors);
			Decorations.Add(decorationAt);
		}
		else if (decorationAt.type != PrefabTypes.Decoration_4Sides)
		{
			if (decorationAt.type == PrefabTypes.Decoration_Engine)
			{
				SceneSingleton<PlayerMovement>.Instance.RemoveEngine(decorationAt.obj, GetEngineDirection(decorationAt.obj));
			}
			decorationAt.type = (decorationAt.type = PrefabTypes.Decoration_4Sides);
			decorationAt.obj.SetActive(value: false);
			decorationAt.obj = MasterPool.GetPos(PrefabTypes.Decoration_4Sides, decorationParent, pos);
			decorationAt.neighborCores = new List<Vector3>(neighbors);
		}
	}

	private void SpawnDec3Sides(Vector3 pos, List<Vector3> neighbors)
	{
		DecorationData decorationAt = GetDecorationAt(pos);
		if (decorationAt == null)
		{
			decorationAt = new DecorationData();
			decorationAt.pos = pos;
			decorationAt.type = PrefabTypes.Decoration_3Sides;
			decorationAt.obj = MasterPool.GetPos(PrefabTypes.Decoration_3Sides, decorationParent, pos);
			decorationAt.neighborCores = new List<Vector3>(neighbors);
			decorationAt.obj.transform.rotation = GetRot3Sides(decorationAt.neighborCores);
			Decorations.Add(decorationAt);
			return;
		}
		if (decorationAt.type != PrefabTypes.Decoration_3Sides)
		{
			if (decorationAt.type == PrefabTypes.Decoration_Engine)
			{
				SceneSingleton<PlayerMovement>.Instance.RemoveEngine(decorationAt.obj, GetEngineDirection(decorationAt.obj));
			}
			decorationAt.type = (decorationAt.type = PrefabTypes.Decoration_3Sides);
			decorationAt.obj.SetActive(value: false);
			decorationAt.obj = MasterPool.GetPos(PrefabTypes.Decoration_3Sides, decorationParent, pos);
		}
		decorationAt.neighborCores = new List<Vector3>(neighbors);
		decorationAt.obj.transform.rotation = GetRot3Sides(decorationAt.neighborCores);
	}

	private void SpawnDec2Sides(Vector3 pos, List<Vector3> neighbors)
	{
		DecorationData decorationData = GetDecorationAt(pos);
		if (decorationData == null)
		{
			decorationData = new DecorationData();
			decorationData.pos = pos;
			decorationData.type = PrefabTypes.Decoration_2Sides;
			decorationData.obj = MasterPool.GetPos(PrefabTypes.Decoration_2Sides, decorationParent, pos);
			decorationData.neighborCores = new List<Vector3>(neighbors);
			decorationData.obj.transform.rotation = GetRot2Sides(decorationData.neighborCores);
			Decorations.Add(decorationData);
		}
		else
		{
			if (decorationData.type != PrefabTypes.Decoration_2Sides)
			{
				if (decorationData.type == PrefabTypes.Decoration_Engine)
				{
					SceneSingleton<PlayerMovement>.Instance.RemoveEngine(decorationData.obj, GetEngineDirection(decorationData.obj));
				}
				decorationData.type = (decorationData.type = PrefabTypes.Decoration_2Sides);
				decorationData.obj.SetActive(value: false);
				decorationData.obj = MasterPool.GetPos(PrefabTypes.Decoration_2Sides, decorationParent, pos);
			}
			decorationData.neighborCores = new List<Vector3>(neighbors);
			decorationData.obj.transform.rotation = GetRot2Sides(decorationData.neighborCores);
		}
		if ((decorationData.neighborCores.Contains(Vector3.down) && decorationData.neighborCores.Contains(Vector3.up)) || (decorationData.neighborCores.Contains(Vector3.right) && decorationData.neighborCores.Contains(Vector3.left)))
		{
			decorationData.obj.SetActive(value: false);
		}
	}

	private void SpawnDec1Sides(Vector3 pos, List<Vector3> neighbors)
	{
		DecorationData decorationAt = GetDecorationAt(pos);
		if (decorationAt == null)
		{
			decorationAt = new DecorationData();
			decorationAt.pos = pos;
			if (Random.value > 0.25f)
			{
				decorationAt.type = PrefabTypes.Decoration_Engine;
			}
			else
			{
				decorationAt.type = PrefabTypes.Decoration_Antenna;
			}
			decorationAt.neighborCores = new List<Vector3>(neighbors);
			decorationAt.obj = MasterPool.GetPos(decorationAt.type, decorationParent, pos);
			decorationAt.obj.transform.rotation = GetRot1Sides(decorationAt.neighborCores);
			Decorations.Add(decorationAt);
			if (decorationAt.type == PrefabTypes.Decoration_Engine)
			{
				SceneSingleton<PlayerMovement>.Instance.AddEngine(decorationAt.obj, GetEngineDirection(decorationAt.obj));
			}
			return;
		}
		bool flag = false;
		if (decorationAt.type != PrefabTypes.Decoration_Engine && decorationAt.type != PrefabTypes.Decoration_Antenna)
		{
			if (Random.value > 0.25f)
			{
				decorationAt.type = PrefabTypes.Decoration_Engine;
			}
			else
			{
				decorationAt.type = PrefabTypes.Decoration_Antenna;
			}
			decorationAt.obj.SetActive(value: false);
			decorationAt.obj = MasterPool.GetPos(decorationAt.type, decorationParent, pos);
			flag = true;
		}
		decorationAt.neighborCores = new List<Vector3>(neighbors);
		decorationAt.obj.transform.rotation = GetRot1Sides(decorationAt.neighborCores);
		if (flag && decorationAt.type == PrefabTypes.Decoration_Engine)
		{
			SceneSingleton<PlayerMovement>.Instance.AddEngine(decorationAt.obj, GetEngineDirection(decorationAt.obj));
		}
	}

	private Quaternion GetRot3Sides(List<Vector3> neighbors)
	{
		if (neighbors.Count != 3)
		{
			Debug.LogError("GetRot1Sides neighbors are not three !!, neighbors.Count: " + neighbors.Count);
			return Quaternion.identity;
		}
		if (!neighbors.Contains(Vector3.down))
		{
			return Quaternion.Euler(0f, 0f, 180f);
		}
		if (!neighbors.Contains(Vector3.right))
		{
			return Quaternion.Euler(0f, 0f, -90f);
		}
		if (!neighbors.Contains(Vector3.left))
		{
			return Quaternion.Euler(0f, 0f, 90f);
		}
		if (!neighbors.Contains(Vector3.up))
		{
			return Quaternion.Euler(0f, 0f, 0f);
		}
		Debug.LogError("neighbor not found: " + neighbors[0].ToString() + " - " + neighbors[1].ToString() + " - " + neighbors[2].ToString());
		return Quaternion.identity;
	}

	private Quaternion GetRot2Sides(List<Vector3> neighbors)
	{
		if (neighbors.Count != 2)
		{
			Debug.LogError("GetRot1Sides neighbors are not 2 neighbor!!, neighbors.Count: " + neighbors.Count);
			return Quaternion.identity;
		}
		if (neighbors.Contains(Vector3.up) && neighbors.Contains(Vector3.right))
		{
			return Quaternion.Euler(0f, 0f, 90f);
		}
		if (neighbors.Contains(Vector3.up) && neighbors.Contains(Vector3.left))
		{
			return Quaternion.Euler(0f, 0f, 180f);
		}
		if (neighbors.Contains(Vector3.down) && neighbors.Contains(Vector3.right))
		{
			return Quaternion.Euler(0f, 0f, 0f);
		}
		if (neighbors.Contains(Vector3.down) && neighbors.Contains(Vector3.left))
		{
			return Quaternion.Euler(0f, 0f, -90f);
		}
		if ((neighbors.Contains(Vector3.down) && neighbors.Contains(Vector3.up)) || (neighbors.Contains(Vector3.right) && neighbors.Contains(Vector3.left)))
		{
			return Quaternion.identity;
		}
		Debug.LogError("neighbor not found: " + neighbors[0].ToString() + " - " + neighbors[1].ToString());
		return Quaternion.identity;
	}

	private Quaternion GetRot1Sides(List<Vector3> neighbors)
	{
		if (neighbors.Count != 1)
		{
			Debug.LogError("GetRot1Sides neighbors has more than one neighbor!!, neighbors.Count: " + neighbors.Count);
			return Quaternion.identity;
		}
		if (neighbors.Contains(Vector3.down))
		{
			return Quaternion.Euler(0f, 0f, 0f);
		}
		if (neighbors.Contains(Vector3.right))
		{
			return Quaternion.Euler(0f, 0f, 90f);
		}
		if (neighbors.Contains(Vector3.left))
		{
			return Quaternion.Euler(0f, 0f, -90f);
		}
		if (neighbors.Contains(Vector3.up))
		{
			return Quaternion.Euler(0f, 0f, 180f);
		}
		Debug.LogError("neighbor not found: " + neighbors[0].ToString());
		return Quaternion.identity;
	}

	private Vector3 GetEngineDirection(GameObject engineObj)
	{
		if (engineObj.transform.eulerAngles.z == 0f)
		{
			return Vector3.down;
		}
		if (engineObj.transform.eulerAngles.z == 90f)
		{
			return Vector3.right;
		}
		if (engineObj.transform.eulerAngles.z == 270f)
		{
			return Vector3.left;
		}
		if (engineObj.transform.eulerAngles.z == 180f)
		{
			return Vector3.up;
		}
		Debug.LogError("Didn't determin the rot of the engine, Rot Z: " + engineObj.transform.eulerAngles.z, engineObj);
		return Vector3.zero;
	}

	private DecorationData GetDecorationAt(Vector3 pos)
	{
		foreach (DecorationData decoration in Decorations)
		{
			if (object.Equals(decoration.pos, pos))
			{
				return decoration;
			}
		}
		return null;
	}

	public void RemoveAll()
	{
		foreach (DecorationData decoration in Decorations)
		{
			decoration.obj.SetActive(value: false);
		}
	}
}
