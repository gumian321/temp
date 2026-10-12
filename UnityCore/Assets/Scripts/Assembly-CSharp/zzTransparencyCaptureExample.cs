using System.Collections;
using UnityEngine;

public class zzTransparencyCaptureExample : MonoBehaviour
{
	public Texture2D capturedImage;

	public Transform cameraTransform;

	private Vector3 lastMousePosition;

	private void Start()
	{
		lastMousePosition = Input.mousePosition;
	}

	public IEnumerator capture()
	{
		Rect lRect = new Rect(0f, 0f, Screen.width, Screen.height);
		if ((bool)capturedImage)
		{
			Object.Destroy(capturedImage);
		}
		yield return new WaitForEndOfFrame();
		capturedImage = zzTransparencyCapture.capture(lRect);
	}

	public void Update()
	{
		if (Input.GetKeyDown(KeyCode.C))
		{
			StartCoroutine(capture());
		}
		if (Input.GetKeyDown(KeyCode.S))
		{
			Object.Destroy(capturedImage);
		}
		Vector3 translation = Input.mousePosition - lastMousePosition;
		translation *= 0.15f;
		cameraTransform.Translate(translation);
		lastMousePosition = Input.mousePosition;
	}

	private void OnGUI()
	{
		if ((bool)capturedImage)
		{
			GUI.DrawTexture(new Rect((float)Screen.width * 0.1f, (float)Screen.height * 0.1f, (float)Screen.width * 0.8f, (float)Screen.height * 0.8f), capturedImage, ScaleMode.ScaleToFit, alphaBlend: true);
			GUI.color = Color.green;
			GUILayout.Label("press S to clear");
		}
		GUI.color = Color.black;
		GUILayout.Label("Press C to do transparent capturing, please capture those boxes");
		GUILayout.Label("The result won't include background color, and the transparency (alpha value) in scene objects, is also can be captured");
	}
}
