using System.Collections;
using UnityEngine;

public class TransparencyCaptureToFile : MonoBehaviour
{
	public IEnumerator capture()
	{
		yield return new WaitForEndOfFrame();
		zzTransparencyCapture.captureScreenshot("capture.png");
	}

	public void Update()
	{
		if (Input.GetKeyDown(KeyCode.C))
		{
			StartCoroutine(capture());
		}
	}
}
