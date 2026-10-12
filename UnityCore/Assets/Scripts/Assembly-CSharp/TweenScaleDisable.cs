using UnityEngine;

public class TweenScaleDisable : MonoBehaviour
{
	[SerializeField]
	private bool destroyAfterDuration;

	[SerializeField]
	private float duration;

	[SerializeField]
	private TweenDuration disableDuration = TweenDuration.Short;

	private void OnEnable()
	{
		Invoke("Disable", duration);
	}

	private void Disable()
	{
		TweenController.Scale(base.transform, 1f, 0f, disableDuration, ignoreTimeScale: false, () =>
		{
			if (destroyAfterDuration)
			{
				Object.Destroy(base.gameObject);
			}
			else
			{
				base.gameObject.SetActive(value: false);
			}
		});
	}
}
