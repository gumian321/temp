using UnityEngine;

public class BackgroundsManager : MonoBehaviour
{
	[SerializeField]
	private Material Mat;

	[SerializeField]
	private float movingSpeed;

	private Transform player;

	private Vector2 startOffset;

	private MeshRenderer meshRenderer;

	private void Start()
	{
		meshRenderer = GetComponent<MeshRenderer>();
		player = SceneSingleton<PlayerManager>.Instance.GetPlayerTransform();
		startOffset = Mat.mainTextureOffset;
	}

	public void ChangeMaterial(Material mat)
	{
		mat.mainTextureOffset = Mat.mainTextureOffset;
		Mat.mainTextureOffset = startOffset;
		meshRenderer.material = mat;
		Mat = mat;
	}

	private void OnDisable()
	{
		Mat.mainTextureOffset = startOffset;
	}

	private void Update()
	{
		Vector2 mainTextureOffset = Mat.mainTextureOffset;
		mainTextureOffset.x = player.position.x / player.localScale.x * movingSpeed * -1f;
		mainTextureOffset.y = player.position.y / player.localScale.y * movingSpeed * -1f;
		Mat.mainTextureOffset = mainTextureOffset;
	}
}
