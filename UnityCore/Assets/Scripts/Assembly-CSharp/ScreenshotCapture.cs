using System.Collections;
using System.IO;
using UnityEngine;

public class ScreenshotCapture : MonoBehaviour
{
	private Texture2D capturedImage;

	[SerializeField]
	private string path;

	[SerializeField]
	private string photoName;

	[SerializeField]
	private float timeScale;

	[SerializeField]
	private KeyCode screenshotKey;

	private string phoName => photoName + RandomID();

	private void Start()
	{
		Time.timeScale = timeScale;
	}

	private void Update()
	{
		if (Input.GetKeyDown(screenshotKey))
		{
			StartCoroutine(capture());
		}
	}

	private IEnumerator capture()
	{
		Rect lRect = new Rect(0f, 0f, Screen.width, Screen.height);
		if ((bool)capturedImage)
		{
			Object.Destroy(capturedImage);
		}
		yield return new WaitForEndOfFrame();
		capturedImage = zzTransparencyCapture.capture(lRect);
		byte[] bytes = capturedImage.EncodeToPNG();
		File.WriteAllBytes(path + "/" + phoName + ".png", bytes);
	}

	private string RandomID()
	{
		string text = "";
		int num = 10;
		for (int i = 0; i < num; i++)
		{
			text += Random.Range(0, 10);
		}
		return text;
	}
}
