using UnityEngine;

public class AutoRotator : MonoBehaviour
{
	[SerializeField]
	private bool IsRotating = true;

	[SerializeField]
	private float speed = 25f;

	public void SetIsRotating(bool IsRotating)
	{
		this.IsRotating = IsRotating;
	}

	public void SetRandomSpeed(float speed)
	{
		int num = ((Random.Range(0, 100) <= 50) ? 1 : (-1));
		this.speed = Random.Range(speed / 2f, speed) * (float)num;
	}

	private void FixedUpdate()
	{
		if (IsRotating)
		{
			base.transform.Rotate(0f, 0f, speed * Time.deltaTime);
		}
	}
}
