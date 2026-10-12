using UnityEngine;

public class HideUI : MonoBehaviour
{
	[SerializeField]
	private CanvasGroup canvasGroup;

	[SerializeField]
	private bool hideUI;

	[SerializeField]
	private KeyCode toggleHideUI;

	private void Start()
	{
		if (hideUI)
		{
			canvasGroup.alpha = 0f;
		}
	}

	private void Update()
	{
		if (Input.GetKeyDown(toggleHideUI))
		{
			if (hideUI)
			{
				canvasGroup.alpha = 0f;
			}
			else
			{
				canvasGroup.alpha = 1f;
			}
			hideUI = !hideUI;
		}
	}
}
