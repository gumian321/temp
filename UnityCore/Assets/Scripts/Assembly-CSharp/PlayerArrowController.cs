using TMPro;
using UnityEngine;

public class PlayerArrowController : MonoBehaviour
{
	[SerializeField]
	private SpriteRenderer arrowSpriteRenderer;

	[SerializeField]
	private SpriteRenderer IconSpriteRenderer;

	[SerializeField]
	private TextMeshPro distanceText;

	private Transform targetTransform;

	private Transform playerTransform;

	private float rangeInRadar = 40f;

	private float arrowAlpha = 0.6f;

	private bool isArrowActive;

	private bool isActivated;

	public void StartArrow(Transform targetTransform, Sprite arrowSprite, Color arrowColor)
	{
		if (!(targetTransform == null))
		{
			ActivateArrow();
			IconSpriteRenderer.sprite = arrowSprite;
			arrowSpriteRenderer.color = arrowColor;
			ImageSystem.Alphalizer(arrowSpriteRenderer, arrowAlpha);
			IconSpriteRenderer.color = arrowColor;
			ImageSystem.Alphalizer(IconSpriteRenderer, arrowAlpha);
			distanceText.color = arrowColor;
			this.targetTransform = targetTransform;
			ObjectSystem.SnapRotateToTarget(base.transform, targetTransform.position);
			playerTransform = SceneSingleton<PlayerManager>.Instance.GetPlayerTransform();
			isArrowActive = true;
		}
	}

	private void FixedUpdate()
	{
		if (!isArrowActive)
		{
			return;
		}
		if (targetTransform == null || playerTransform == null)
		{
			Object.Destroy(base.gameObject);
			return;
		}
		if (!targetTransform.gameObject.activeSelf)
		{
			Object.Destroy(base.gameObject);
			return;
		}
		float num = Vector3.Distance(targetTransform.position, playerTransform.position);
		if (num > rangeInRadar)
		{
			distanceText.text = (int)num + "m";
			ObjectSystem.RotateToTarget(base.transform, targetTransform.position);
			ActivateArrow();
		}
		else
		{
			DisableArrow();
		}
	}

	private void DisableArrow()
	{
		if (isActivated)
		{
			isActivated = false;
			arrowSpriteRenderer.gameObject.SetActive(value: false);
			IconSpriteRenderer.gameObject.SetActive(value: false);
			distanceText.gameObject.SetActive(value: false);
		}
	}

	private void ActivateArrow()
	{
		if (!isActivated)
		{
			isActivated = true;
			arrowSpriteRenderer.gameObject.SetActive(value: true);
			IconSpriteRenderer.gameObject.SetActive(value: true);
			distanceText.gameObject.SetActive(value: true);
		}
	}
}
