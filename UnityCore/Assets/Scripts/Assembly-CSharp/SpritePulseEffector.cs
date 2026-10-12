using UnityEngine;

public class SpritePulseEffector : MonoBehaviour
{
	private SpriteRenderer spriteRenderer;

	private bool isEffectRunning;

	[SerializeField]
	private Color effectColor;

	[SerializeField]
	private bool useSetEffectColor;

	private Color currentColor;

	[SerializeField]
	private float effectTime = 0.05f;

	private float effectTimer;

	private void Awake()
	{
		spriteRenderer = GetComponent<SpriteRenderer>();
	}

	private void OnEnable()
	{
		StopEffect();
	}

	public void StartEffect(Color effectColor)
	{
		effectTimer = Time.time + effectTime;
		if (useSetEffectColor)
		{
			effectColor = this.effectColor;
		}
		effectColor.a = spriteRenderer.color.a;
		if (isEffectRunning)
		{
			if (effectColor != spriteRenderer.color)
			{
				spriteRenderer.color = effectColor;
			}
		}
		else
		{
			currentColor = spriteRenderer.color;
			spriteRenderer.color = effectColor;
			isEffectRunning = true;
		}
	}

	public void StopEffect()
	{
		if (isEffectRunning)
		{
			isEffectRunning = false;
			spriteRenderer.color = currentColor;
		}
	}

	private void FixedUpdate()
	{
		if (isEffectRunning && effectTimer < Time.time)
		{
			StopEffect();
		}
	}
}
