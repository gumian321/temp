using UnityEngine;

public class MainMenuSceneObject : MonoBehaviour
{
	[SerializeField]
	private float speed = 1f;

	private Vector3 endTarget;

	public void SetObject(Vector3 start, Vector3 end)
	{
		base.transform.position = start;
		endTarget = end;
		RotateToTarget(end);
	}

	private void Update()
	{
		base.transform.Translate(Vector3.right * speed * Time.unscaledDeltaTime);
		if (Vector3.Distance(base.transform.position, endTarget) < 0.5f)
		{
			SceneSingleton<MainMenuSceneAnimator>.Instance.SpawnAnotherObject();
			Object.Destroy(base.gameObject);
		}
	}

	public void RotateToTarget(Vector3 target)
	{
		Vector3 vector = base.transform.position - target;
		Quaternion rotation = Quaternion.AngleAxis(Mathf.Atan2(vector.y, vector.x) * 57.29578f + 180f, Vector3.forward);
		base.transform.rotation = rotation;
	}
}
