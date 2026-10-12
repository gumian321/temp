using System;
using System.Collections.Generic;
using UnityEngine;

[Serializable]
internal class DecorationData
{
	public PrefabTypes type;

	public Vector3 pos;

	public GameObject obj;

	public List<Vector3> neighborCores = new List<Vector3>();
}
