using System.Collections.Generic;
using UnityEngine;

public class LineRendererSpriteAnimator : MonoBehaviour
{
	private LineRenderer lineRenderer;

	[SerializeField]
	private List<Texture> spritesList;

	private int spriteIndex;

	[SerializeField]
	private float changeRate = 0.5f;

	private float timer;

	private void Awake()
	{
		lineRenderer = GetComponent<LineRenderer>();
		timer = Time.time + changeRate;
	}

	private void Update()
	{
		if (timer < Time.time)
		{
			spriteIndex++;
			if (spriteIndex >= spritesList.Count)
			{
				spriteIndex = 0;
			}
			lineRenderer.material.SetTexture("_MainTex", spritesList[spriteIndex]);
			timer = Time.time + changeRate;
		}
	}
}
