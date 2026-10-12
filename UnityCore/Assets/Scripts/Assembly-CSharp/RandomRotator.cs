using UnityEngine;

public class RandomRotator : MonoBehaviour
{
	[SerializeField]
	private Vector3 rotateVector;

	private void OnEnable()
	{
		float num = Random.Range(0f, 360f);
		base.transform.eulerAngles = rotateVector * num;
	}
}
