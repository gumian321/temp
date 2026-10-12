using UnityEngine;

public class MapIconFixedRotation : MonoBehaviour
{
	private Transform trans;

	private void Start()
	{
		trans = base.transform;
	}

	private void FixedUpdate()
	{
		trans.rotation = Quaternion.identity;
	}
}
